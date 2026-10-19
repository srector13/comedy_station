import Foundation

/// Spotify's catalog as the app sees it: comedy only (rule 3). Spotify puts
/// genres on artists, not albums or tracks, so a special or bit counts when
/// its comedian does: by their Spotify genres, or, when Spotify lists none
/// (it has been returning fewer), by a comedian of the same name on Apple
/// Music. Anything unconfirmed is left out.
actor SpotifyCatalog: CatalogProviding {
    private let api: SpotifyWebAPI
    /// Confirms comedians Spotify has no genres for.
    private let appleMusic: any CatalogProviding
    private var cache = ResponseCache(lifetime: 10 * 60)

    init(api: SpotifyWebAPI, appleMusic: any CatalogProviding) {
        self.api = api
        self.appleMusic = appleMusic
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

    /// Home and Browse stay Apple Music's (and TMDB's): Spotify's
    /// Development Mode has no charts or browse categories.
    func charts() async throws -> ComedyCharts {
        ComedyCharts()
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
        return await isComedianOnAppleMusic(artist.name) ? ["Comedy"] : nil
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

    /// Whether Apple Music has a comedian of this name.
    private func isComedianOnAppleMusic(_ name: String) async -> Bool {
        let key = "apple-comedian:\(name.lowercased())"
        if let known: Bool = cache.value(for: key) {
            return known
        }
        let found = (try? await appleMusic.search(name))?.comedians ?? []
        let target = SpecialMatcher.normalized(name)
        let isComedian = found.contains { SpecialMatcher.normalized($0.name) == target }
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
