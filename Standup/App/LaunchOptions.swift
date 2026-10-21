import SwiftUI

/// Switches read from launch arguments, which the UI tests use to run the
/// app without Apple Music:
///
///     -StandupMock YES                  mock catalog and Apple Music answers
///     -StandupAccess noSubscription     which gate state the mock produces
///     -StandupAppearance dark           force light or dark
///     -StandupTab library               open on a tab
///     -StandupSearch maya               start the search tab with a query
///     -StandupRoute album:<id>          open a page on the first tab (mock)
///     -StandupLibrary seeded            start with a filled App Library (mock)
///     -StandupFeedbackSeconds 6         keep "Added to Library" up longer
///     -StandupNowPlaying album:<id>:3:125  a paused special, bit 4 at 2:05 (mock)
///     -StandupShowNowPlaying YES        open Now Playing over it (mock)
///     -StandupService spotify           the service picked (appleMusic, spotify,
///                                       or ask for the first-launch choice; mock)
///     -StandupCatalogDelay 6            Home's and Browse's lists take this long (mock)
///
/// Arguments of the form `-Key value` land in UserDefaults' argument domain.
struct LaunchOptions: Equatable {
    enum AccessScenario: String, CaseIterable {
        case notDetermined, denied, restricted, noSubscription, unavailable, misconfigured, ready
    }

    var useMockData = false
    var accessScenario: AccessScenario = .ready
    var colorScheme: ColorScheme?
    var initialTab: AppTab = .home
    var searchQuery: String?
    var route: String?
    var seedLibrary = false
    var feedbackSeconds: Double?
    var nowPlaying: String?
    var showNowPlaying = false
    /// `-StandupSpotify connected`: mock mode starts signed in to Spotify.
    var spotifyConnected = false
    /// The service mock mode starts on; nil asks, as a first launch does.
    var service: Provider? = .appleMusic
    /// Seconds the mock catalog takes over Home's and Browse's lists.
    var catalogDelay: Double = 0

    /// Options from `value(key)`, the launch argument for each key.
    init(value: (String) -> String?) {
        useMockData = ["yes", "true", "1"].contains(value("StandupMock")?.lowercased() ?? "")
        accessScenario = value("StandupAccess").flatMap(AccessScenario.init(rawValue:)) ?? .ready
        colorScheme = switch value("StandupAppearance")?.lowercased() {
        case "dark": .dark
        case "light": .light
        default: nil
        }
        initialTab = value("StandupTab").flatMap(AppTab.init(rawValue:)) ?? .home
        searchQuery = value("StandupSearch").flatMap { $0.isEmpty ? nil : $0 }
        route = value("StandupRoute").flatMap { $0.isEmpty ? nil : $0 }
        seedLibrary = value("StandupLibrary")?.lowercased() == "seeded"
        feedbackSeconds = value("StandupFeedbackSeconds").flatMap(Double.init)
        nowPlaying = value("StandupNowPlaying").flatMap { $0.isEmpty ? nil : $0 }
        showNowPlaying = ["yes", "true", "1"].contains(value("StandupShowNowPlaying")?.lowercased() ?? "")
        spotifyConnected = value("StandupSpotify")?.lowercased() == "connected"
        catalogDelay = value("StandupCatalogDelay").flatMap(Double.init) ?? 0
        service = switch value("StandupService")?.lowercased() {
        case "spotify": .spotify
        case "ask": nil
        default: .appleMusic
        }
    }

    init() {
        self.init(value: { _ in nil })
    }

    /// This process's launch arguments.
    static func fromProcess() -> LaunchOptions {
        LaunchOptions(value: { UserDefaults.standard.string(forKey: $0) })
    }
}
