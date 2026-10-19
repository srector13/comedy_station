import CoreGraphics
import Foundation
import MusicKit

/// The live catalog: MusicKit requests, the comedy filter, and a small
/// in-memory cache so going back and forth between pages doesn't refetch.
actor MusicKitCatalog: CatalogProviding {
    private var cache = ResponseCache(lifetime: 10 * 60)
    /// The person's TMDB key, from Settings, for New and Popular Specials.
    private let tmdbKeys: any KeyStoring

    init(tmdbKeys: any KeyStoring = KeychainKeyStore.tmdb) {
        self.tmdbKeys = tmdbKeys
    }

    func suggestions(for term: String) async throws -> [SearchSuggestion] {
        let suggestions: [SearchSuggestion] = try await suggestionsResponse(for: term).topResults.compactMap { result in
            switch result {
            case .artist(let artist): .comedian(ComedyArtist(artist))
            case .album(let album): .special(ComedyAlbum(album))
            default: nil
            }
        }
        return ComedyFilter.keep(suggestions)
    }

    /// Search as you type. A half-typed name ("mark nor") ranks musicians
    /// first, so after the comedy filter little or nothing is left. When
    /// that happens, Apple's completions of the term ("mark normand") are
    /// searched too and their comedy results added after.
    func search(_ term: String) async throws -> SearchResults {
        try await cached("search:\(term.lowercased())") {
            var found = try await results(for: term)
            guard found.headlineCount < 3 else { return found }
            let completions = ((try? await suggestionsResponse(for: term).suggestions) ?? [])
                .map(\.searchTerm)
                .filter { $0.caseInsensitiveCompare(term) != .orderedSame }
            for completion in completions.prefix(2) {
                if let more = try? await results(for: completion) {
                    found.merge(more)
                }
            }
            return found
        }
    }

    /// One catalog search, through the comedy filter.
    private func results(for term: String) async throws -> SearchResults {
        try await cached("results:\(term.lowercased())") {
            var request = MusicCatalogSearchRequest(term: term, types: [Artist.self, Album.self, Song.self])
            request.limit = 25
            let response = try await request.response()
            let bits = try await comedyBits(Array(response.songs))
            return SearchResults(
                comedians: ComedyFilter.keep(response.artists.map(ComedyArtist.init)),
                specials: ComedyFilter.keep(response.albums.map(ComedyAlbum.init)),
                bits: bits
            )
        }
    }

    private func suggestionsResponse(for term: String) async throws -> MusicCatalogSearchSuggestionsResponse {
        try await cached("suggestions:\(term.lowercased())") {
            var request = MusicCatalogSearchSuggestionsRequest(term: term, includingTopResultsOfTypes: [Artist.self, Album.self])
            request.limit = 10
            return try await request.response()
        }
    }

    func album(id: String) async throws -> AlbumDetail {
        try await cached("album:\(id)") {
            var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(id))
            request.properties = [.tracks, .artists]
            guard let album = try await request.response().items.first else { throw CatalogError.notFound }
            guard ComedyFilter.isComedy(album.genreNames) else { throw CatalogError.notComedy }

            let tracks: [ComedyTrack] = (album.tracks ?? []).compactMap { track in
                guard case .song(let song) = track else { return nil }
                return ComedyTrack(song, album: album)
            }
            return AlbumDetail(
                album: ComedyAlbum(album),
                tracks: tracks,
                editorialNotes: (album.editorialNotes?.standard ?? album.editorialNotes?.short).map(Format.plainText),
                copyright: album.copyright
            )
        }
    }

    func artist(id: String) async throws -> ArtistDetail {
        try await cached("artist:\(id)") {
            var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: MusicItemID(id))
            request.properties = [.albums, .topSongs, .similarArtists, .latestRelease, .featuredAlbums]
            guard let artist = try await request.response().items.first else { throw CatalogError.notFound }
            guard ComedyFilter.isComedy(artist.genreNames) else { throw CatalogError.notComedy }

            let specials = ComedyFilter.keep((artist.albums ?? []).map(ComedyAlbum.init))
                .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            let latest = artist.latestRelease.map(ComedyAlbum.init).flatMap { ComedyFilter.isComedy($0.genreNames) ? $0 : nil }
            let featured = latest
                ?? ComedyFilter.keep((artist.featuredAlbums ?? []).map(ComedyAlbum.init)).first
                ?? specials.first
            let topBits = try await comedyBits(Array((artist.topSongs ?? []).prefix(10)))
            return ArtistDetail(
                artist: ComedyArtist(artist),
                featured: featured,
                specials: specials,
                topBits: topBits,
                similar: ComedyFilter.keep((artist.similarArtists ?? []).map(ComedyArtist.init))
            )
        }
    }

    func comedian(id: String) async throws -> ComedyArtist {
        try await cached("comedian:\(id)") {
            let request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: MusicItemID(id))
            guard let artist = try await request.response().items.first else { throw CatalogError.notFound }
            let comedian = ComedyArtist(artist)
            guard ComedyFilter.isComedy(comedian.genreNames) else { throw CatalogError.notComedy }
            return comedian
        }
    }

    /// Home and Browse. With a TMDB key, new and popular specials come from
    /// TMDB, as their Apple Music versions. Bits and playlists come from
    /// Apple's Comedy chart, which also fills in for TMDB. Where neither has
    /// any comedy, searches for comedy fill that section instead.
    func charts() async throws -> ComedyCharts {
        let tmdbKey = tmdbKeys.load()
        return try await cached("charts:\(tmdbKey ?? "")") {
            var charts = ComedyCharts()
            var notes: [String] = []
            do {
                // Genre ID 3 is used here and only here (rule 3); every
                // result still goes through the genre-name filter.
                let genreRequest = MusicCatalogResourceRequest<Genre>(matching: \.id, equalTo: MusicItemID(ComedyFilter.comedyGenreID))
                guard let comedy = try await genreRequest.response().items.first else { throw CatalogError.notFound }
                var request = MusicCatalogChartsRequest(genre: comedy, kinds: [.mostPlayed], types: [Album.self, Song.self])
                request.limit = 40
                let response = try await request.response()
                let albums = response.albumCharts.flatMap(\.items)
                let songs = response.songCharts.flatMap(\.items)
                charts.topSpecials = ComedyFilter.keep(albums.map(ComedyAlbum.init))
                charts.topBits = try await comedyBits(songs)
                notes.append("The Comedy chart had \(albums.count) albums and \(songs.count) songs; \(charts.topSpecials.count) and \(charts.topBits.count) were comedy.")
                // Playlists on their own, so a chart without them can't
                // sink the rest.
                var playlistRequest = MusicCatalogChartsRequest(genre: comedy, kinds: [.mostPlayed], types: [Playlist.self])
                playlistRequest.limit = 20
                if let playlistResponse = try? await playlistRequest.response() {
                    charts.playlists = playlistResponse.playlistCharts.flatMap(\.items).map(ComedyPlaylist.init)
                }
            } catch {
                if let setup = MusicKitSetupError(error) { throw setup }
                notes.append("The Comedy chart didn't load (\(error.localizedDescription)).")
            }
            if let tmdbKey {
                let external = await tmdbSpecials(TMDBClient(key: tmdbKey))
                charts.newReleases = external.new
                // A handful at least, or Apple's chart reads better.
                if external.popular.count >= 4 {
                    charts.topSpecials = external.popular
                    charts.specialsSource = .popular
                }
            }
            if charts.topSpecials.isEmpty || charts.topBits.isEmpty {
                let found = await searchedComedy()
                if charts.topSpecials.isEmpty {
                    charts.topSpecials = found.specials
                    charts.specialsSource = .search
                }
                if charts.topBits.isEmpty {
                    charts.topBits = found.bits
                    charts.bitsSource = .search
                }
            }
            guard !charts.isEmpty else {
                throw CatalogError.noComedy(notes.joined(separator: " "))
            }
            return charts
        }
    }

    // MARK: TMDB

    /// TMDB's new (last four months) and popular (last three years)
    /// stand-up specials, each as its Apple Music version. Specials without
    /// one are left out, and so is everything when TMDB can't be reached.
    private func tmdbSpecials(_ client: TMDBClient) async -> (new: [ComedyAlbum], popular: [ComedyAlbum]) {
        do {
            let keyword = try await cached("tmdb:keyword") { try await client.standUpKeywordID() }
            let now = Date.now
            async let recent = client.specials(keyword: keyword, from: now.addingTimeInterval(-120 * 86_400), to: now)
            async let popular = client.specials(keyword: keyword, from: now.addingTimeInterval(-3 * 365 * 86_400), to: now)
            let (newOnes, popularOnes) = try await (recent, popular)
            let new = await appleMusicVersions(of: Array(newOnes.prefix(20)), client: client)
                .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            return (new, await appleMusicVersions(of: Array(popularOnes.prefix(20)), client: client))
        } catch {
            return ([], [])
        }
    }

    /// The Apple Music versions of specials, in the specials' order, six
    /// lookups at a time.
    private func appleMusicVersions(of specials: [TMDBSpecial], client: TMDBClient) async -> [ComedyAlbum] {
        var found: [Int: ComedyAlbum] = [:]
        await withTaskGroup(of: (Int, ComedyAlbum?).self) { group in
            var next = 0
            func addNext() {
                guard next < specials.count else { return }
                let index = next, special = specials[index]
                group.addTask { (index, await self.appleMusicVersion(of: special, client: client)) }
                next += 1
            }
            for _ in 0..<6 { addNext() }
            for await (index, album) in group {
                found[index] = album
                addNext()
            }
        }
        var seen = Set<String>()
        return specials.indices.compactMap { found[$0] }.filter { seen.insert($0.id).inserted }
    }

    private func appleMusicVersion(of special: TMDBSpecial, client: TMDBClient) async -> ComedyAlbum? {
        var comedian = special.titleParts?.comedian
        let title = special.titleParts?.title ?? special.title
        if comedian == nil {
            comedian = try? await cached("tmdb:comedian:\(special.id)") { try await client.comedian(ofSpecial: special.id) }
        }
        guard let comedian, let found = try? await results(for: "\(comedian) \(title)") else { return nil }
        return SpecialMatcher.best(comedian: comedian, title: title, released: special.releaseDate, in: found.specials)
    }

    /// Comedy found by searching the catalog, for a chart section that has
    /// none. Every result goes through the comedy filter.
    private func searchedComedy() async -> SearchResults {
        var found = SearchResults()
        for term in ["stand-up comedy", "comedy special", "live stand-up"] {
            if let more = try? await results(for: term) {
                found.merge(more)
            }
        }
        return found
    }

    func playlist(id: String) async throws -> PlaylistDetail {
        try await cached("playlist:\(id)") {
            var request = MusicCatalogResourceRequest<Playlist>(matching: \.id, equalTo: MusicItemID(id))
            request.properties = [.tracks]
            guard let playlist = try await request.response().items.first else { throw CatalogError.notFound }
            let songs: [Song] = (playlist.tracks ?? []).compactMap { track in
                if case .song(let song) = track { song } else { nil }
            }
            return PlaylistDetail(playlist: ComedyPlaylist(playlist), tracks: try await comedyBits(songs))
        }
    }

    // MARK: Helpers

    /// The songs that are on a comedy album. One batched request loads every
    /// song's albums; a song whose albums don't load is dropped.
    private func comedyBits(_ songs: [Song]) async throws -> [ComedyTrack] {
        guard !songs.isEmpty else { return [] }
        var request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: songs.map(\.id))
        request.properties = [.albums]
        let loaded = try await request.response().items
        let byID = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let bits: [ComedyTrack] = songs.compactMap { song in
            guard let full = byID[song.id], let albums = full.albums, !albums.isEmpty else { return nil }
            // A song can be on several albums (a special and a compilation):
            // it counts if any of them is comedy.
            let album = albums.first { ComedyFilter.isComedy($0.genreNames) } ?? albums.first
            return ComedyTrack(full, album: album)
        }
        return ComedyFilter.keep(bits)
    }

    private func cached<Value: Sendable>(_ key: String, load: () async throws -> Value) async throws -> Value {
        if let hit: Value = cache.value(for: key) {
            return hit
        }
        do {
            let value = try await load()
            cache.store(value, for: key)
            return value
        } catch {
            // Say why, and how this copy is signed, rather than MusicKit's
            // bare "Failed to request developer token".
            if let setup = MusicKitSetupError(error) { throw setup }
            throw error
        }
    }
}

// MARK: MusicKit to app models

extension ArtworkRef {
    init(_ artwork: Artwork?, id: MusicItemID) {
        let probe = artwork?.url(width: Self.probeSide, height: Self.probeSide)?.absoluteString
        self.init(
            template: probe.map(Self.template(fromProbe:)),
            backgroundRGB: artwork?.backgroundColor.flatMap(Self.rgb),
            seed: Self.seed(for: id.rawValue)
        )
    }

    private static func rgb(_ color: CGColor) -> Int? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let components = color.converted(to: srgb, intent: .defaultIntent, options: nil)?.components,
              components.count >= 3
        else { return nil }
        let byte = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return byte(components[0]) << 16 | byte(components[1]) << 8 | byte(components[2])
    }
}

extension ComedyArtist {
    init(_ artist: Artist) {
        self.init(
            id: artist.id.rawValue,
            name: artist.name,
            artwork: ArtworkRef(artist.artwork, id: artist.id),
            genreNames: artist.genreNames ?? []
        )
    }
}

extension ComedyPlaylist {
    init(_ playlist: Playlist) {
        self.init(
            id: playlist.id.rawValue,
            name: playlist.name,
            curatorName: playlist.curatorName,
            artwork: ArtworkRef(playlist.artwork, id: playlist.id),
            summary: (playlist.shortDescription ?? playlist.standardDescription).map(Format.plainText)
        )
    }
}

extension ComedyAlbum {
    init(_ album: Album) {
        self.init(
            id: album.id.rawValue,
            title: album.title,
            artistName: album.artistName,
            artistID: album.artists?.first?.id.rawValue,
            artwork: ArtworkRef(album.artwork, id: album.id),
            releaseDate: album.releaseDate,
            trackCount: album.trackCount,
            genreNames: album.genreNames,
            isExplicit: album.contentRating == .explicit
        )
    }
}

extension ComedyTrack {
    init(_ song: Song, album: Album?) {
        self.init(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            albumID: album?.id.rawValue,
            albumTitle: album?.title ?? song.albumTitle,
            duration: song.duration,
            trackNumber: song.trackNumber,
            artwork: ArtworkRef(song.artwork ?? album?.artwork, id: album?.id ?? song.id),
            isExplicit: song.contentRating == .explicit,
            albumGenreNames: album?.genreNames ?? []
        )
    }
}
