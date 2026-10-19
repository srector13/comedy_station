import Foundation

/// `MockData` behind the catalog protocol, run through the same
/// `ComedyFilter` as the live catalog.
struct MockCatalog: CatalogProviding {
    func suggestions(for term: String) async throws -> [SearchSuggestion] {
        let albums = matchingAlbums(term)
        let hits = ComedyFilter.comedians(matchingArtists(term), specials: albums).map(SearchSuggestion.comedian) + albums.map(SearchSuggestion.special)
        return Array(ComedyFilter.keep(hits).prefix(6))
    }

    func search(_ term: String) async throws -> SearchResults {
        let bits = MockData.tracks.values.joined().filter {
            $0.title.localizedCaseInsensitiveContains(term) || $0.artistName.localizedCaseInsensitiveContains(term)
        }
        let albums = matchingAlbums(term)
        return SearchResults(
            comedians: ComedyFilter.comedians(matchingArtists(term), specials: albums),
            specials: ComedyFilter.keep(albums),
            bits: Array(ComedyFilter.keep(bits.sorted { $0.id < $1.id }).prefix(12))
        )
    }

    func album(id: String) async throws -> AlbumDetail {
        guard let album = MockData.album(id: id) else { throw CatalogError.notFound }
        guard ComedyFilter.isComedy(album.genreNames) else { throw CatalogError.notComedy }
        return AlbumDetail(
            album: album,
            tracks: MockData.tracks[id] ?? [],
            editorialNotes: MockData.editorialNotes[id],
            copyright: "℗ \(Format.year(album.releaseDate) ?? "2025") Standup Sample Records"
        )
    }

    func artist(id: String) async throws -> ArtistDetail {
        guard let found = MockData.artist(id: id) else { throw CatalogError.notFound }
        let specials = ComedyFilter.keep(MockData.albums.filter { $0.artistID == id })
            .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
        guard let artist = ComedyFilter.comedian(found, specials: specials) else { throw CatalogError.notComedy }
        // A few bits from each special, plus the pop-compilation decoy for Maya.
        var candidates: [ComedyTrack] = []
        for album in MockData.albums where album.artistID == id {
            candidates += (MockData.tracks[album.id] ?? []).dropFirst().prefix(3)
        }
        candidates += (MockData.tracks["mock-al-summer"] ?? []).filter { $0.artistName == artist.name }
        return ArtistDetail(
            artist: artist,
            featured: specials.first,
            specials: specials,
            topBits: Array(ComedyFilter.keep(candidates).prefix(5)),
            similar: ComedyFilter.keep(MockData.similar(to: id))
        )
    }

    func comedian(id: String) async throws -> ComedyArtist {
        guard let artist = MockData.artist(id: id) else { throw CatalogError.notFound }
        guard let comedian = ComedyFilter.comedian(artist, specials: MockData.albums.filter { $0.artistID == id }) else { throw CatalogError.notComedy }
        return comedian
    }

    func charts() async throws -> ComedyCharts {
        let albums = MockData.chartAlbumIDs.compactMap(MockData.album(id:))
        let bits = MockData.chartBitPicks.compactMap { MockData.tracks["mock-al-\($0.0)"]?[safe: $0.1] }
        return ComedyCharts(
            topSpecials: ComedyFilter.keep(albums),
            topBits: ComedyFilter.keep(bits),
            playlists: MockData.playlists
        )
    }

    /// Home's TMDB shelves, as if TMDB had named the sample specials.
    func discover(_ shelf: DiscoverShelf) async throws -> [ComedyAlbum] {
        let specials = ComedyFilter.keep(MockData.albums)
        switch shelf {
        case .new:
            return Array(specials.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }.prefix(8))
        case .popular:
            return ComedyFilter.keep(MockData.chartAlbumIDs.compactMap(MockData.album(id:)))
        case .essential:
            return Array(specials.sorted { ($0.releaseDate ?? .distantPast) < ($1.releaseDate ?? .distantPast) }.prefix(8))
        }
    }

    func trendingComedians() async throws -> [ComedyArtist] {
        ComedyFilter.comedians(MockData.comedians, specials: MockData.albums)
    }

    func playlist(id: String) async throws -> PlaylistDetail {
        guard let playlist = MockData.playlists.first(where: { $0.id == id }) else { throw CatalogError.notFound }
        return PlaylistDetail(playlist: playlist, tracks: ComedyFilter.keep(MockData.playlistTracks(id)))
    }

    /// A `-StandupRoute` launch value ("album:<id>" or "artist:<id>") as a
    /// route into mock data.
    static func route(for value: String) -> Route? {
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "album": return MockData.album(id: parts[1]).map(Route.album)
        case "artist": return MockData.artist(id: parts[1]).map(Route.artist)
        case "playlist": return MockData.playlists.first { $0.id == parts[1] }.map(Route.playlist)
        default: return nil
        }
    }

    private func matchingArtists(_ term: String) -> [ComedyArtist] {
        MockData.comedians.filter { $0.name.localizedCaseInsensitiveContains(term) }
    }

    private func matchingAlbums(_ term: String) -> [ComedyAlbum] {
        MockData.albums.filter {
            $0.title.localizedCaseInsensitiveContains(term) || $0.artistName.localizedCaseInsensitiveContains(term)
        }
    }
}
