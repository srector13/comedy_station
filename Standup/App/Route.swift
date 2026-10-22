import SwiftUI

/// A catalog page pushed onto a tab's navigation stack.
enum Route: Hashable {
    case artist(ComedyArtist)
    case album(ComedyAlbum)
    case playlist(ComedyPlaylist)
    /// A Browse list from TMDB.
    case category(BrowseCategory)
    /// A Home shelf's specials, all of them (See All).
    case specials(title: String, albums: [ComedyAlbum])
}

extension View {
    /// Registers the catalog pages on a navigation stack. Each tab's root
    /// view applies it once.
    func comedyDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .artist(let artist): ArtistView(artist: artist)
            case .album(let album): AlbumView(album: album)
            case .playlist(let playlist): PlaylistView(playlist: playlist)
            case .category(let category): BrowseCategoryView(category: category)
            case .specials(let title, let albums): SeeAllSpecialsView(title: title, albums: albums)
            }
        }
    }
}

extension EnvironmentValues {
    @Entry var play: @MainActor @Sendable (PlayRequest) -> Void = { _ in }
    /// Switches tabs, as an empty Library list's Find button does.
    @Entry var selectTab: @MainActor @Sendable (AppTab) -> Void = { _ in }
}
