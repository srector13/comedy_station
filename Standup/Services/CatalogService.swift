import SwiftUI

/// The Apple Music catalog as the app sees it: comedy only. Every method
/// returns results that already passed `ComedyFilter`.
protocol CatalogProviding: Sendable {
    func suggestions(for term: String) async throws -> [SearchSuggestion]
    func search(_ term: String) async throws -> SearchResults
    func album(id: String) async throws -> AlbumDetail
    func artist(id: String) async throws -> ArtistDetail
}

enum CatalogError: LocalizedError, Equatable {
    case notFound
    /// The item exists but isn't comedy, so the app won't show it.
    case notComedy

    var errorDescription: String? {
        switch self {
        case .notFound: "This isn't in the Apple Music catalog."
        case .notComedy: "Standup only plays comedy, and this isn't tagged as comedy."
        }
    }
}

extension EnvironmentValues {
    /// The catalog. Mock by default, so previews work without Apple Music;
    /// the app injects the live one.
    @Entry var catalog: any CatalogProviding = MockCatalog()
}
