import SwiftUI

/// The Apple Music catalog as the app sees it: comedy only. Every method
/// returns results that already passed `ComedyFilter`.
protocol CatalogProviding: Sendable {
    func suggestions(for term: String) async throws -> [SearchSuggestion]
    func search(_ term: String) async throws -> SearchResults
    func album(id: String) async throws -> AlbumDetail
    func artist(id: String) async throws -> ArtistDetail
    /// Just the comedian (name, artwork, genres), without their page.
    func comedian(id: String) async throws -> ComedyArtist
    /// The Comedy charts: top specials, top bits, playlists.
    func charts() async throws -> ComedyCharts
    func playlist(id: String) async throws -> PlaylistDetail
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
