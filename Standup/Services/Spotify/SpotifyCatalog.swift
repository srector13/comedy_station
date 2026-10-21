import Foundation

/// Spotify's catalog as the app sees it: comedy only (rule 3). Spotify puts
/// genres on artists, not albums or tracks, so a special or bit counts when
/// its comedian does: by their Spotify genres, or, when Spotify lists none,
/// by `confirming` (iTunes Search in the app). Anything unconfirmed is left
/// out.
///
/// For the Spotify route, Home's TMDB shelves are matched to Spotify here,
/// as `MusicKitCatalog` matches them to Apple Music.
actor SpotifyCatalog: CatalogProviding {
    private let api: SpotifyWebAPI
    /// Confirms comedians Spotify has no genres for.
    private let confirming: any ComedianConfirming
    private let tmdb: (any TMDBListing)?
    private var cache = ResponseCache(lifetime: 10 * 60)
    /// TMDB specials already matched to Spotify, kept between launches.
    private var matches: SpecialMatchStore

    /// How many of a shelf's TMDB specials are looked for on Spotify,
    /// which limits how fast an app in Development Mode may ask.
    static let shelfLimit = 30

    init(api: SpotifyWebAPI, confirming: any ComedianConfirming, tmdb: (any TMDBListing)? = nil, matchesURL: URL? = SpecialMatchStore.spotifyURL) {
        self.api = api
        self.confirming = confirming
        self.tmdb = tmdb
        matches = SpecialMatchStore(url: matchesURL)
    }

    // MARK: Search

    func suggestions(for term: String) async throws -> [SearchSuggestion] {
        let found = try await search(term)
        let hits = found.comedians.prefix(3).map(SearchSuggestion.comedian) + found.specials.prefix(3).map(SearchSuggestion.special)
        return ComedyFilter.keep(hits)
    }

    /// Two pages of ten (Development Mode's limit), through the filter.
    func search(_ term: String) async throws -> SearchResults {
        try await cached("search:\(term.lowercased())") {
            var found = SearchResults()
            for offset in [0, SpotifyWebAPI.searchLimit] {
                let response = try await api.search(term, offset: offset)
                found.merge(try await comedy(in: response))
            }
            return found
        }
    }

    private func comedy(in response: SpotifyWebAPI.SearchResponse) async throws -> SearchResults {
        var results = SearchResults()
        for artist in response.artists?.items ?? [] {
            if let genres = await comedyGenres(of: artist) {
                results.comedians.append(ComedyArtist(spotify: artist, genreNames: genres))
            }
        }
        for album in response.albums?.items ?? [] {
            if let genres = await comedyGenres(ofArtist: album.artists.first) {
                results.specials.append(ComedyAlbum(spotify: album, genreNames: genres))
            }
        }
        for track in response.tracks?.items ?? [] {
            if let genres = await comedyGenres(ofArtist: track.album.artists.first) {
                results.bits.append(ComedyTrack(spotify: track, albumGenreNames: genres))
            }
        }
        return SearchResults(
            comedians: ComedyFilter.keep(results.comedians),
            specials: ComedyFilter.keep(results.specials),
            bits: ComedyFilter.keep(results.bits)
        )
    }

    // MARK: Pages

    func album(id: String) async throws -> AlbumDetail {
        try await cached("album:\(id)") {
            let album = try await api.album(id)
            guard let genres = await comedyGenres(ofArtist: album.artists.first) else { throw CatalogError.notComedy }
            let simple = album.simple
            let tracks = (album.tracks?.items ?? []).map { ComedyTrack(spotify: $0, album: simple, albumGenreNames: genres) }
            return AlbumDetail(
                album: ComedyAlbum(spotify: simple, genreNames: genres),
                tracks: ComedyFilter.keep(tracks),
                editorialNotes: nil,
                copyright: album.copyrights?.first?.text
            )
        }
    }

    /// A comedian and their specials. Spotify's Development Mode has no top
    /// tracks or related artists, so those stay empty.
    func artist(id: String) async throws -> ArtistDetail {
        try await cached("artist:\(id)") {
            let comedian = try await comedian(id: id)
            let albums = (try? await api.artistAlbums(id)) ?? []
            let specials = ComedyFilter.keep(albums.map { ComedyAlbum(spotify: $0, genreNames: comedian.genreNames) })
                .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            return ArtistDetail(artist: comedian, featured: specials.first, specials: specials, topBits: [], similar: [])
        }
    }

    func comedian(id: String) async throws -> ComedyArtist {
        try await cached("comedian:\(id)") {
            let artist = try await api.artist(id)
            guard let genres = await comedyGenres(of: artist) else { throw CatalogError.notComedy }
            return ComedyArtist(spotify: artist, genreNames: genres)
        }
    }

    /// Spotify's Development Mode has no charts or browse categories, so
    /// Browse stays Apple Music's.
    func charts() async throws -> ComedyCharts {
        ComedyCharts()
    }

    // MARK: Home

    /// A Home shelf: TMDB's specials for it, each as its Spotify album.
    /// Specials without one are left out.
    func discover(_ shelf: DiscoverShelf) async throws -> [ComedyAlbum] {
        guard let tmdb, let key = tmdb.key else { return [] }
        return try await cached("discover:\(shelf.rawValue):\(key)") {
            let specials = Array(try await tmdb.specials(for: shelf).prefix(Self.shelfLimit))
            var albums = await inOrder(specials, width: 3) { [self] special in
                await spotifyVersion(of: special, tmdb: tmdb)
            }
            var seen = Set<String>()
            albums = albums.filter { seen.insert($0.id).inserted }
            if shelf == .new {
                albums.sort { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            }
            matches.save()
            return albums
        }
    }

    /// The comedians behind TMDB's new and popular specials, as Spotify
    /// artists.
    func trendingComedians() async throws -> [ComedyArtist] {
        guard let tmdb, let key = tmdb.key else { return [] }
        return try await cached("discover:comedians:\(key)") {
            let names = await tmdb.trendingNames()
            var ids = Set<String>()
            let comedians = await inOrder(names, width: 3) { [self] name in await spotifyComedian(named: name) }
            return Array(comedians.filter { ids.insert($0.id).inserted }.prefix(15))
        }
    }

    /// A special's Spotify album: searched by comedian and title, matched
    /// by `SpecialMatcher`, then through the comedy check. Answers are
    /// remembered, except when Spotify couldn't be asked or the comedian
    /// couldn't be confirmed.
    private func spotifyVersion(of special: TMDBSpecial, tmdb: any TMDBListing) async -> ComedyAlbum? {
        if let known = matches.lookup(special.id) {
            return known
        }
        guard let comedian = await tmdb.comedianName(of: special) else { return nil }
        let title = special.titleParts?.title ?? special.title
        guard let response = try? await api.search("\(comedian) \(title)", types: "album") else { return nil }
        let found = response.albums?.items ?? []
        let candidates = found.map { ComedyAlbum(spotify: $0, genreNames: []) }
        guard var match = SpecialMatcher.best(comedian: comedian, title: title, released: special.releaseDate, in: candidates) else {
            matches.record(nil, for: special.id)
            return nil
        }
        let artist = found.first { $0.uri == match.id }?.artists.first
        guard let genres = await comedyGenres(ofArtist: artist) else { return nil }
        match.genreNames = genres
        matches.record(match, for: special.id)
        return match
    }

    /// The Spotify artist with exactly this name, if a comedian.
    private func spotifyComedian(named name: String) async -> ComedyArtist? {
        guard let response = try? await api.search(name, types: "artist") else { return nil }
        let target = SpecialMatcher.normalized(name)
        guard let artist = response.artists?.items.first(where: { SpecialMatcher.normalized($0.name) == target }),
              let genres = await comedyGenres(of: artist)
        else { return nil }
        return ComedyArtist(spotify: artist, genreNames: genres)
    }

    func playlist(id: String) async throws -> PlaylistDetail {
        throw CatalogError.notFound
    }

    // MARK: Is this a comedian?

    /// The genres to tag a comedian's items with, or nil when they aren't
    /// one (or it can't be confirmed).
    private func comedyGenres(of artist: SpotifyWebAPI.Artist) async -> [String]? {
        let genres = artist.genres ?? []
        if !genres.isEmpty {
            return ComedyFilter.isComedy(genres) ? genres : nil
        }
        return await isConfirmedComedian(artist.name) ? ["Comedy"] : nil
    }

    private func comedyGenres(ofArtist artist: SpotifyWebAPI.SimpleArtist?) async -> [String]? {
        guard let artist else { return nil }
        let key = "genres:\(artist.uri)"
        if let known: [String]? = cache.value(for: key) {
            return known
        }
        guard let full = try? await api.artist(artist.uri) else { return nil }
        let genres = await comedyGenres(of: full)
        cache.store(genres, for: key)
        return genres
    }

    /// Whether `confirming` knows a comedian of this name. Only answers
    /// are kept, so one it couldn't give is asked for again.
    private func isConfirmedComedian(_ name: String) async -> Bool {
        let key = "confirmed:\(SpecialMatcher.normalized(name))"
        if let known: Bool = cache.value(for: key) {
            return known
        }
        guard let isComedian = await confirming.isComedian(named: name) else { return false }
        cache.store(isComedian, for: key)
        return isComedian
    }

    private func cached<Value: Sendable>(_ key: String, load: () async throws -> Value) async throws -> Value {
        if let hit: Value = cache.value(for: key) {
            return hit
        }
        let value = try await load()
        cache.store(value, for: key)
        return value
    }
}
