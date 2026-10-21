import SwiftUI

/// The service choice on first launch, then that service's setup (Apple
/// Music's access gate, or connecting Spotify), then the tabs.
struct RootView: View {
    var initialTab: AppTab = .home
    /// Launch-argument state for UI tests: a search query, a page to open.
    var initialQuery = ""
    var initialRoute: Route?

    @Environment(AuthGate.self) private var gate
    @Environment(ServiceChoice.self) private var service
    @Environment(SpotifyAccount.self) private var spotify
    @Environment(\.catalog) private var catalog
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlayerService.self) private var player
    @Environment(LibraryStore.self) private var library

    var body: some View {
        ZStack {
            switch service.provider {
            case nil:
                ServicePickerView()
                    .transition(.opacity)
            case .spotify:
                if spotify.isConnected {
                    tabs(searching: .spotify)
                } else {
                    SpotifySetupView()
                        .transition(.opacity)
                }
            case .appleMusic:
                switch gate.state {
                case .checking:
                    // A moment at launch; blank rather than flashing onboarding.
                    Color(.systemBackground)
                        .ignoresSafeArea()
                case .ready:
                    tabs(searching: .appleMusic)
                default:
                    AccessGateView(state: gate.state)
                        .transition(.opacity)
                }
            }
        }
        .animation(.default, value: gate.state)
        .animation(.default, value: service.provider)
        .animation(.default, value: spotify.isConnected)
        .task { await gate.refresh() }
        .task(id: isReady) {
            // Once the catalog answers: comedians earlier versions left out.
            if isReady {
                await library.addMissingComediansOnce()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings (or anywhere): the answer may have changed.
            if phase == .active {
                Task { await gate.refresh() }
            } else if phase == .background {
                player.saveProgress()
            }
        }
    }

    private func tabs(searching provider: Provider) -> some View {
        MainTabView(catalog: catalog, initialTab: initialTab, initialQuery: initialQuery, initialRoute: initialRoute, provider: provider)
            .transition(.opacity)
    }

    /// The chosen service can be used.
    private var isReady: Bool {
        switch service.provider {
        case .appleMusic: gate.state == .ready
        case .spotify: spotify.isConnected
        case nil: false
        }
    }
}

#Preview("Ready") {
    RootView()
        .environment(AuthGate(access: MockMusicAccess(scenario: .ready)))
        .previewEnvironment()
}

#Preview("Apple Music onboarding") {
    RootView()
        .environment(AuthGate(access: MockMusicAccess(scenario: .notDetermined)))
        .previewEnvironment()
}

#Preview("First launch") {
    RootView()
        .environment(ServiceChoice(defaults: nil))
        .previewEnvironment()
}
