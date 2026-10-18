import SwiftUI

@main
struct StandupApp: App {
    @State private var environment = AppEnvironment.make()

    var body: some Scene {
        WindowGroup {
            RootView(initialTab: environment.options.initialTab)
                .environment(environment.authGate)
                .tint(Theme.accent)
                .preferredColorScheme(environment.options.colorScheme)
        }
    }
}
