import SwiftUI

/// The access gate until Apple Music is authorized with a subscription that
/// plays catalog content, then the tabs.
struct RootView: View {
    var initialTab: AppTab = .home

    @Environment(AuthGate.self) private var gate
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            switch gate.state {
            case .checking:
                // A moment at launch; blank rather than flashing onboarding.
                Color(.systemBackground)
                    .ignoresSafeArea()
            case .ready:
                MainTabView(initialTab: initialTab)
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
            }
        }
    }
}

#Preview("Ready") {
    RootView()
        .environment(AuthGate(access: MockMusicAccess(scenario: .ready)))
        .tint(Theme.accent)
}

#Preview("Onboarding") {
    RootView()
        .environment(AuthGate(access: MockMusicAccess(scenario: .notDetermined)))
        .tint(Theme.accent)
}
