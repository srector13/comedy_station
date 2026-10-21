import Foundation

/// Spotify's side of mock mode: two comedians with two specials each, and a
/// pop act the comedy filter keeps out. IDs are Spotify URIs, as live.
enum MockSpotify {
    static let comedians = [
        ComedyArtist(id: "spotify:artist:mock-lena", name: "Lena Brooks", artwork: ArtworkRef(generatedFor: "spotify:artist:mock-lena"), genreNames: ["comedy", "stand-up comedy"]),
        ComedyArtist(id: "spotify:artist:mock-dj", name: "DJ Nightlife", artwork: ArtworkRef(generatedFor: "spotify:artist:mock-dj"), genreNames: ["dance pop"]),
        ComedyArtist(id: "spotify:artist:mock-theo", name: "Theo Park", artwork: ArtworkRef(generatedFor: "spotify:artist:mock-theo"), genreNames: ["comedy"]),
    ]

    static let albums = [
        album("small-talk", "Small Talk Champion", by: comedians[0], released: "2025-09-12", bits: ["Intro", "Elevator Etiquette", "The Group Text", "Hotel Breakfast", "My Dentist Is a Comedian", "Goodnight"]),
        album("overbooked", "Overbooked", by: comedians[0], released: "2023-04-21", bits: ["Gate Change", "Middle Seat", "Lost Luggage", "Customs", "Home"]),
        album("party-mix", "Party Mix", by: comedians[1], released: "2025-01-01", bits: ["Lights Up", "All Night"]),
        album("late-checkout", "Late Checkout", by: comedians[2], released: "2024-11-08", bits: ["Do Not Disturb", "Ice Machine", "Minibar Math", "Checkout Time"]),
        album("group-project", "Group Project", by: comedians[2], released: "2022-06-03", bits: ["Roll Call", "The Slacker", "Presentation Day"]),
    ]

    static func tracks(of albumID: String) -> [ComedyTrack] {
        trackLists[albumID] ?? []
    }

    private static var trackLists: [String: [ComedyTrack]] {
        Dictionary(uniqueKeysWithValues: albums.map { ($0.album.id, $0.tracks) })
    }

    private static func album(_ slug: String, _ title: String, by artist: ComedyArtist, released: String, bits: [String]) -> (album: ComedyAlbum, tracks: [ComedyTrack]) {
        let id = "spotify:album:mock-\(slug)"
        let album = ComedyAlbum(
            id: id, title: title, artistName: artist.name, artistID: artist.id,
            artwork: ArtworkRef(generatedFor: id), releaseDate: TMDBClient.day(from: released),
            trackCount: bits.count, genreNames: artist.genreNames, isExplicit: true
        )
        let tracks = bits.enumerated().map { index, title in
            ComedyTrack(
                id: "spotify:track:mock-\(slug)-\(index + 1)", title: title, artistName: artist.name,
                albumID: id, albumTitle: album.title, duration: TimeInterval(150 + index * 37), trackNumber: index + 1,
                artwork: album.artwork, isExplicit: true, albumGenreNames: artist.genreNames
            )
        }
        return (album, tracks)
    }
}

/// `MockSpotify` behind the catalog protocol, through the comedy filter.
struct MockSpotifyCatalog: CatalogProviding {
    private func matches(_ text: String, _ term: String) -> Bool {
        term.split(separator: " ").allSatisfy { text.localizedCaseInsensitiveContains($0) }
    }

    func suggestions(for term: String) async throws -> [SearchSuggestion] {
        let found = try await search(term)
        return found.comedians.map(SearchSuggestion.comedian) + found.specials.prefix(3).map(SearchSuggestion.special)
    }

    func search(_ term: String) async throws -> SearchResults {
        let albums = MockSpotify.albums.map(\.album)
        let bits = albums.flatMap { MockSpotify.tracks(of: $0.id) }
        return SearchResults(
            comedians: ComedyFilter.keep(MockSpotify.comedians.filter { matches($0.name, term) }),
            specials: ComedyFilter.keep(albums.filter { matches($0.title, term) || matches($0.artistName, term) }),
            bits: ComedyFilter.keep(bits.filter { matches($0.title, term) || matches($0.artistName, term) })
        )
    }

    func album(id: String) async throws -> AlbumDetail {
        guard let album = MockSpotify.albums.map(\.album).first(where: { $0.id == id }) else { throw CatalogError.notFound }
        guard ComedyFilter.isComedy(album.genreNames) else { throw CatalogError.notComedy }
        return AlbumDetail(album: album, tracks: MockSpotify.tracks(of: id), editorialNotes: nil, copyright: "℗ Standup Sample Records")
    }

    func artist(id: String) async throws -> ArtistDetail {
        let comedian = try await comedian(id: id)
        let specials = MockSpotify.albums.map(\.album).filter { $0.artistID == id }
            .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
        return ArtistDetail(artist: comedian, featured: specials.first, specials: specials, topBits: [], similar: [])
    }

    func comedian(id: String) async throws -> ComedyArtist {
        guard let artist = MockSpotify.comedians.first(where: { $0.id == id }) else { throw CatalogError.notFound }
        guard ComedyFilter.isComedy(artist.genreNames) else { throw CatalogError.notComedy }
        return artist
    }

    func charts() async throws -> ComedyCharts {
        ComedyCharts()
    }

    /// Home's shelves for the Spotify route, as if TMDB had named these.
    func discover(_ shelf: DiscoverShelf) async throws -> [ComedyAlbum] {
        let specials = ComedyFilter.keep(MockSpotify.albums.map(\.album))
        return switch shelf {
        case .new, .popular: specials.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
        case .essential: specials.sorted { ($0.releaseDate ?? .distantPast) < ($1.releaseDate ?? .distantPast) }
        }
    }

    func trendingComedians() async throws -> [ComedyArtist] {
        ComedyFilter.keep(MockSpotify.comedians)
    }

    func playlist(id: String) async throws -> PlaylistDetail {
        throw CatalogError.notFound
    }
}
