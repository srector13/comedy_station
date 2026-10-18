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
            .tint(Theme.accent)
            .preferredColorScheme(environment.options.colorScheme)
        }
    }
}
