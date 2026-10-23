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
    /// Artists' comedy genres, by URI, for as long as the app runs: an
    /// artist's genres rarely change, and Development Mode has no request
    /// for several artists at once, so each is one request.
    private var comedianGenres: [String: [String]] = [:]
    /// Artists found not to be comedians.
    private var notComedians: Set<String> = []
    /// Comedians confirmed (or not) by `confirming`, by normalized name.
    private var confirmed: [String: Bool] = [:]

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

    /// Two pages of ten (Development Mode's limit), asked for together,
    /// through the filter.
    func search(_ term: String) async throws -> SearchResults {
        try await cached("search:\(term.lowercased())") { [api] in
            async let first = api.search(term, offset: 0)
            async let second = api.search(term, offset: SpotifyWebAPI.searchLimit)
            var found = try await comedy(in: first)
            found.merge(try await comedy(in: second))
            return found
        }
    }

    private func comedy(in response: SpotifyWebAPI.SearchResponse) async throws -> SearchResults {
        // The albums' and tracks' artists, looked up a few at a time first.
        await lookUpGenres(of: (response.albums?.items ?? []).compactMap(\.artists.first) + (response.tracks?.items ?? []).compactMap(\.album.artists.first))
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
    /// Browse's charts and playlists stay Apple Music's.
    func charts() async throws -> ComedyCharts {
        ComedyCharts()
    }

    // MARK: Home

    /// A Home shelf: TMDB's specials for it, each as its Spotify album.
    /// Specials without one are left out.
    func discover(_ shelf: DiscoverShelf) async throws -> [ComedyAlbum] {
        guard let tmdb else { return [] }
        return try await matched("discover:\(shelf.rawValue)", newestFirst: shelf == .new) { try await tmdb.specials(for: shelf) }
    }

    /// Streaming services, then decades.
    func browseCategories() async throws -> [BrowseCategory] {
        guard let tmdb, tmdb.access != nil else { return [] }
        return ((try? await tmdb.streamingServices()) ?? []) + BrowseCategory.decades
    }

    func browse(_ category: BrowseCategory) async throws -> [ComedyAlbum] {
        guard let tmdb else { return [] }
        return try await matched("browse:\(category.id)", newestFirst: false) { try await tmdb.specials(in: category) }
    }

    /// The first `shelfLimit` of TMDB's specials for a list, each as its
    /// Spotify album, in the list's order (or newest first). Specials
    /// without one are left out.
    private func matched(_ name: String, newestFirst: Bool, specials: () async throws -> [TMDBSpecial]) async throws -> [ComedyAlbum] {
        guard let tmdb, let access = tmdb.access else { return [] }
        return try await cached("\(name):\(access.cacheID)") {
            let list = Array(try await specials().prefix(Self.shelfLimit))
            var albums = await inOrder(list, width: 3) { [self] special in
                await spotifyVersion(of: special, tmdb: tmdb)
            }
            var seen = Set<String>()
            albums = albums.filter { seen.insert($0.id).inserted }
            if newestFirst {
                albums.sort { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            }
            matches.save()
            return albums
        }
    }

    /// The comedians behind TMDB's new and popular specials, as Spotify
    /// artists.
    func trendingComedians() async throws -> [ComedyArtist] {
        guard let tmdb, let access = tmdb.access else { return [] }
        return try await cached("discover:comedians:\(access.cacheID)") {
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

    /// Only answers are kept: an artist that couldn't be loaded is asked
    /// for again.
    private func comedyGenres(ofArtist artist: SpotifyWebAPI.SimpleArtist?) async -> [String]? {
        guard let artist else { return nil }
        if let known = comedianGenres[artist.uri] {
            return known
        }
        if notComedians.contains(artist.uri) {
            return nil
        }
        guard let full = try? await cached("artist:\(artist.uri)", load: { try await api.artist(artist.uri) }) else { return nil }
        let genres = await comedyGenres(of: full)
        if let genres {
            comedianGenres[artist.uri] = genres
        } else {
            notComedians.insert(artist.uri)
        }
        return genres
    }

    /// Looks up the genres of artists not known yet, four at a time.
    private func lookUpGenres(of artists: [SpotifyWebAPI.SimpleArtist]) async {
        var seen = Set<String>()
        let unknown = artists.filter { comedianGenres[$0.uri] == nil && !notComedians.contains($0.uri) && seen.insert($0.uri).inserted }
        guard unknown.count > 1 else { return }
        _ = await inOrder(unknown, width: 4) { [self] artist in
            await comedyGenres(ofArtist: artist)
        }
    }

    /// Whether `confirming` knows a comedian of this name. Only answers
    /// are kept, so one it couldn't give is asked for again.
    private func isConfirmedComedian(_ name: String) async -> Bool {
        let key = SpecialMatcher.normalized(name)
        if let known = confirmed[key] {
            return known
        }
        guard let isComedian = await confirming.isComedian(named: name) else { return false }
        confirmed[key] = isComedian
        return isComedian
    }

    private func cached<Value: Sendable>(_ key: String, load: () async throws -> Value) async throws -> Value {
        if let hit: Value = cache.value(for: key) {
            return hit
        }
        // Already on its way: wait for that answer. If that load was
        // cancelled (its screen went away) and this ask wasn't, load here.
        if cache.isLoading(key) {
            do {
                let shared = try await withCheckedThrowingContinuation { cache.wait(for: key, $0) }
                if let shared = shared as? Value {
                    return shared
                }
            } catch let error where ResponseCache.isCancellation(error) && !Task.isCancelled {}
        }
        cache.startLoading(key)
        do {
            let value = try await load()
            cache.finishLoading(key, with: .success(value))
            return value
        } catch {
            cache.finishLoading(key, with: .failure(error))
            throw error
        }
    }
}
