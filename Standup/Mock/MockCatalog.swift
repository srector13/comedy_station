import Foundation

/// `MockData` behind the catalog protocol, run through the same
/// `ComedyFilter` as the live catalog.
struct MockCatalog: CatalogProviding {
    func suggestions(for term: String) async throws -> [SearchSuggestion] {
        let hits = matchingArtists(term).map(SearchSuggestion.comedian) + matchingAlbums(term).map(SearchSuggestion.special)
        return Array(ComedyFilter.keep(hits).prefix(6))
    }

    func search(_ term: String) async throws -> SearchResults {
        let bits = MockData.tracks.values.joined().filter {
            $0.title.localizedCaseInsensitiveContains(term) || $0.artistName.localizedCaseInsensitiveContains(term)
        }
        return SearchResults(
            comedians: ComedyFilter.keep(matchingArtists(term)),
            specials: ComedyFilter.keep(matchingAlbums(term)),
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
        guard let artist = MockData.artist(id: id) else { throw CatalogError.notFound }
        guard ComedyFilter.isComedy(artist.genreNames) else { throw CatalogError.notComedy }
        let specials = ComedyFilter.keep(MockData.albums.filter { $0.artistID == id })
            .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
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

    /// A `-StandupRoute` launch value ("album:<id>" or "artist:<id>") as a
    /// route into mock data.
    static func route(for value: String) -> Route? {
        let parts = value.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "album": return MockData.album(id: parts[1]).map(Route.album)
        case "artist": return MockData.artist(id: parts[1]).map(Route.artist)
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
