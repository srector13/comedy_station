import SwiftData
import SwiftUI

@main
struct StandupApp: App {
    private let environment = AppEnvironment.shared

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
            .environment(\.play, { [player = environment.player] request in
                Task { await player.handle(request) }
            })
            .tint(Theme.accent)
            .preferredColorScheme(environment.options.colorScheme)
        }
    }
}
