import SwiftUI

/// A catalog as the app sees it (Apple Music's, Spotify's, or both through
/// `RoutingCatalog`): comedy only. Every method returns results that
/// already passed `ComedyFilter`.
protocol CatalogProviding: Sendable {
    func suggestions(for term: String) async throws -> [SearchSuggestion]
    func search(_ term: String) async throws -> SearchResults
    /// Search one service (the Search tab's switch).
    func suggestions(for term: String, in provider: Provider) async throws -> [SearchSuggestion]
    func search(_ term: String, in provider: Provider) async throws -> SearchResults
    /// A Home shelf of specials from TMDB; empty without a TMDB key.
    func discover(_ shelf: DiscoverShelf) async throws -> [ComedyAlbum]
    /// The comedians behind TMDB's new and popular specials; empty without
    /// a TMDB key.
    func trendingComedians() async throws -> [ComedyArtist]
    /// Home's TMDB shelves and comedians as one service's versions (the
    /// service picked on first launch).
    func discover(_ shelf: DiscoverShelf, in provider: Provider) async throws -> [ComedyAlbum]
    func trendingComedians(in provider: Provider) async throws -> [ComedyArtist]
    func album(id: String) async throws -> AlbumDetail
    func artist(id: String) async throws -> ArtistDetail
    /// Just the comedian (name, artwork, genres), without their page.
    func comedian(id: String) async throws -> ComedyArtist
    /// The Comedy charts: top specials, top bits, playlists.
    func charts() async throws -> ComedyCharts
    func playlist(id: String) async throws -> PlaylistDetail
}

extension CatalogProviding {
    /// A catalog of one service searches itself whichever is asked for.
    func suggestions(for term: String, in provider: Provider) async throws -> [SearchSuggestion] {
        try await suggestions(for: term)
    }

    func search(_ term: String, in provider: Provider) async throws -> SearchResults {
        try await search(term)
    }

    /// A catalog without TMDB has no shelves.
    func discover(_ shelf: DiscoverShelf) async throws -> [ComedyAlbum] {
        []
    }

    func trendingComedians() async throws -> [ComedyArtist] {
        []
    }

    func discover(_ shelf: DiscoverShelf, in provider: Provider) async throws -> [ComedyAlbum] {
        try await discover(shelf)
    }

    func trendingComedians(in provider: Provider) async throws -> [ComedyArtist] {
        try await trendingComedians()
    }
}

/// Sends each request to the service its item comes from: Spotify URIs to
/// Spotify, everything else to Apple Music, which also keeps Browse and
/// playlists. Search and Home's shelves go to the service asked for.
struct RoutingCatalog: CatalogProviding {
    let appleMusic: any CatalogProviding
    let spotify: any CatalogProviding

    private func catalog(for id: String) -> any CatalogProviding {
        Provider.of(id) == .spotify ? spotify : appleMusic
    }

    private func catalog(for provider: Provider) -> any CatalogProviding {
        provider == .spotify ? spotify : appleMusic
    }

    func suggestions(for term: String) async throws -> [SearchSuggestion] {
        try await appleMusic.suggestions(for: term)
    }

    func search(_ term: String) async throws -> SearchResults {
        try await appleMusic.search(term)
    }

    func suggestions(for term: String, in provider: Provider) async throws -> [SearchSuggestion] {
        try await catalog(for: provider).suggestions(for: term)
    }

    func search(_ term: String, in provider: Provider) async throws -> SearchResults {
        try await catalog(for: provider).search(term)
    }

    func album(id: String) async throws -> AlbumDetail {
        try await catalog(for: id).album(id: id)
    }

    func artist(id: String) async throws -> ArtistDetail {
        try await catalog(for: id).artist(id: id)
    }

    func comedian(id: String) async throws -> ComedyArtist {
        try await catalog(for: id).comedian(id: id)
    }

    func charts() async throws -> ComedyCharts {
        try await appleMusic.charts()
    }

    func discover(_ shelf: DiscoverShelf) async throws -> [ComedyAlbum] {
        try await appleMusic.discover(shelf)
    }

    func trendingComedians() async throws -> [ComedyArtist] {
        try await appleMusic.trendingComedians()
    }

    func discover(_ shelf: DiscoverShelf, in provider: Provider) async throws -> [ComedyAlbum] {
        try await catalog(for: provider).discover(shelf)
    }

    func trendingComedians(in provider: Provider) async throws -> [ComedyArtist] {
        try await catalog(for: provider).trendingComedians()
    }

    func playlist(id: String) async throws -> PlaylistDetail {
        try await appleMusic.playlist(id: id)
    }
}

enum CatalogError: LocalizedError, Equatable {
    case notFound
    /// The item exists but isn't comedy, so the app won't show it.
    case notComedy
    /// Neither the Comedy chart nor a search turned up any comedy. Carries
    /// what the chart did return, to tell an empty chart from a failed one.
    case noComedy(String)

    var errorDescription: String? {
        switch self {
        case .notFound: "This isn't in the Apple Music catalog."
        case .notComedy: "Standup only plays comedy, and this isn't tagged as comedy."
        case .noComedy(let detail): "Apple Music didn't return any comedy here right now. \(detail)"
        }
    }
}

extension EnvironmentValues {
    /// The catalog. Mock by default, so previews work without Apple Music;
    /// the app injects the live one.
    @Entry var catalog: any CatalogProviding = MockCatalog()
}
