import SwiftUI

enum AppTab: String, Hashable, CaseIterable, Sendable {
    case home, browse, library, search
}

/// The Music-style shell: a system `TabView`, so the platform draws the
/// Liquid Glass bar, the separate search tab, minimize-on-scroll, and the
/// sidebar on iPad. The mini-player rides above the tabs as the bar's
/// bottom accessory.
struct MainTabView: View {
    @State private var selection: AppTab

    init(initialTab: AppTab = .home) {
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Browse", systemImage: "square.grid.2x2.fill", value: AppTab.browse) {
                BrowseView()
            }
            Tab("Library", systemImage: "square.stack.fill", value: AppTab.library) {
                LibraryView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayerView()
        }
    }
}

#Preview {
    MainTabView()
        .tint(Theme.accent)
}
