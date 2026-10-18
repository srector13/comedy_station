import SwiftUI

/// A catalog page pushed onto a tab's navigation stack.
enum Route: Hashable {
    case artist(ComedyArtist)
    case album(ComedyAlbum)
}

extension View {
    /// Registers the catalog pages on a navigation stack. Each tab's root
    /// view applies it once.
    func comedyDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .artist(let artist): ArtistView(artist: artist)
            case .album(let album): AlbumView(album: album)
            }
        }
    }
}

/// What a Play, Shuffle or bit tap asks for. Playback arrives in Phase 4;
/// until then the app's handler does nothing.
struct PlayRequest: Equatable, Sendable {
    enum Item: Equatable, Sendable {
        case album(ComedyAlbum)
        case artist(ComedyArtist)
    }

    var item: Item
    /// The bit to start from, in the special's track order.
    var startIndex = 0
    var shuffle = false
}

extension EnvironmentValues {
    @Entry var play: @MainActor @Sendable (PlayRequest) -> Void = { _ in }
}
