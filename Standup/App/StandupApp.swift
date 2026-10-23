import SwiftData
import SwiftUI

@main
struct StandupApp: App {
    private let environment = AppEnvironment.shared

    init() {
        // Artwork loads through the shared URL cache, whose default holds
        // too little to keep a few screens of covers: scrolling back would
        // download them again.
        URLCache.shared = URLCache(memoryCapacity: 48 * 1024 * 1024, diskCapacity: 256 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                initialTab: environment.options.initialTab,
                initialQuery: environment.options.searchQuery ?? "",
                initialRoute: environment.initialRoute
            )
            .environment(environment.authGate)
            .environment(\.catalog, environment.catalog)
            .environment(environment.library)
            .modelContainer(environment.library.container)
            .environment(\.libraryFeedbackDuration, environment.options.feedbackSeconds ?? 1.6)
            .environment(environment.player)
            .environment(environment.specials)
            .environment(environment.spotify)
            .environment(environment.service)
            .environment(\.play, { [player = environment.player] request in
                Task { await player.handle(request) }
            })
            .tint(Theme.accent)
            .preferredColorScheme(environment.options.colorScheme)
            .onOpenURL { url in
                // The Spotify app, back from being woken to play.
                _ = environment.spotifyEngine?.handle(url)
            }
        }
    }
}
