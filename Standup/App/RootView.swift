import SwiftUI

/// The access gate until Apple Music is authorized with a subscription that
/// plays catalog content, then the tabs.
struct RootView: View {
    var initialTab: AppTab = .home
    /// Launch-argument state for UI tests: a search query, a page to open.
    var initialQuery = ""
    var initialRoute: Route?

    @Environment(AuthGate.self) private var gate
    @Environment(\.catalog) private var catalog
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlayerService.self) private var player

    var body: some View {
        ZStack {
            switch gate.state {
            case .checking:
                // A moment at launch; blank rather than flashing onboarding.
                Color(.systemBackground)
                    .ignoresSafeArea()
            case .ready:
                MainTabView(catalog: catalog, initialTab: initialTab, initialQuery: initialQuery, initialRoute: initialRoute)
                    .transition(.opacity)
            default:
                AccessGateView(state: gate.state)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: gate.state)
        .task { await gate.refresh() }
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings (or anywhere): the answer may have changed.
            if phase == .active {
                Task { await gate.refresh() }
            } else if phase == .background {
                player.saveProgress()
            }
        }
    }
}

#Preview("Ready") {
    RootView()
        .environment(AuthGate(access: MockMusicAccess(scenario: .ready)))
        .previewEnvironment()
}

#Preview("Onboarding") {
    RootView()
        .environment(AuthGate(access: MockMusicAccess(scenario: .notDetermined)))
        .previewEnvironment()
}
