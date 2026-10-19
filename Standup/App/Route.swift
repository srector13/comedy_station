import SwiftUI

/// A catalog page pushed onto a tab's navigation stack.
enum Route: Hashable {
    case artist(ComedyArtist)
    case album(ComedyAlbum)
    case playlist(ComedyPlaylist)
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
            }
        }
    }
}

extension EnvironmentValues {
    @Entry var play: @MainActor @Sendable (PlayRequest) -> Void = { _ in }
}
