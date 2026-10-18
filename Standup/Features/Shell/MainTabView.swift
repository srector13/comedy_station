import SwiftUI

enum AppTab: String, Hashable, CaseIterable, Sendable {
    case home, browse, library, search
}

/// The Music-style shell: a system `TabView`, so the platform draws the
/// Liquid Glass bar, minimize-on-scroll, and the sidebar on iPad. Search is
/// a `.search`-role tab with `.searchable` on the tab view itself, which is
/// what sets it apart at the trailing end of the bar. The mini-player rides
/// above the tabs as the bar's bottom accessory.
struct MainTabView: View {
    @State private var selection: AppTab
    @State private var search: SearchModel
    private let initialRoute: Route?

    init(catalog: any CatalogProviding, initialTab: AppTab = .home, initialQuery: String = "", initialRoute: Route? = nil) {
        _selection = State(initialValue: initialTab)
        _search = State(initialValue: SearchModel(catalog: catalog, query: initialQuery))
        self.initialRoute = initialRoute
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(initialPath: initialRoute.map { [$0] } ?? [])
            }
            Tab("Browse", systemImage: "square.grid.2x2.fill", value: AppTab.browse) {
                BrowseView()
            }
            Tab("Library", systemImage: "square.stack.fill", value: AppTab.library) {
                LibraryView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView(model: search)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayerView()
        }
        .searchable(text: $search.query, prompt: "Comedians, Specials, and Bits")
        .searchSuggestions {
            ForEach(search.visibleSuggestions) { suggestion in
                SuggestionRow(suggestion: suggestion)
                    .searchCompletion(suggestion.title)
            }
        }
        .onSubmit(of: .search) {
            search.submit()
        }
        .onChange(of: search.query) {
            search.queryChanged()
        }
        .task {
            // A query from launch arguments searches right away.
            if !search.term.isEmpty {
                search.submit()
            }
        }
    }
}

#Preview {
    MainTabView(catalog: MockCatalog())
        .tint(Theme.accent)
}
