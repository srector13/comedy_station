import Foundation
import Observation

/// The service Standup runs on, picked on first launch:
/// - Apple Music needs a subscription, and Home, Browse and Search come
///   from Apple Music.
/// - Spotify needs Premium and the Spotify app, and never touches Apple
///   Music: Search is Spotify's, and Home's and Browse's TMDB lists are
///   matched to Spotify (Apple's charts and playlists aren't there).
///
/// Nil until picked, which is what brings up the choice.
@MainActor
@Observable
final class ServiceChoice {
    static let defaultsKey = "Standup.service"

    private(set) var provider: Provider?

    @ObservationIgnored private let defaults: UserDefaults?

    /// The saved choice, or `initial` when none is saved. Without
    /// `defaults` (mock mode, previews) the choice lasts until the app
    /// quits.
    init(defaults: UserDefaults?, initial: Provider? = nil) {
        self.defaults = defaults
        provider = defaults?.string(forKey: Self.defaultsKey).flatMap(Provider.init(rawValue:)) ?? initial
    }

    func choose(_ provider: Provider) {
        self.provider = provider
        defaults?.set(provider.rawValue, forKey: Self.defaultsKey)
    }

    var isSpotify: Bool {
        provider == .spotify
    }
}
