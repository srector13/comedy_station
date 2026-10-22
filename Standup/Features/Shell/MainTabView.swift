import SwiftUI
import UIKit

enum AppTab: String, Hashable, CaseIterable, Sendable {
    case home, browse, library, search
}

/// The Music-style shell: a system `TabView`, so the platform draws the
/// Liquid Glass bar, minimize-on-scroll, and the sidebar on iPad. Search is
/// a `.search`-role tab. On iPhone `.searchable` goes on the tab view
/// itself, which turns the tab into the field at the trailing end of the
/// bar; on iPad it goes on the Search page instead, since on the tab view
/// it would also put a search button on every other tab's page. The
/// mini-player rides above the tabs as the bar's bottom accessory, once
/// something is loaded.
struct MainTabView: View {
    @State private var tabs: TabSelection
    @State private var search: SearchModel
    @Namespace private var nowPlayingNamespace
    @Environment(PlayerService.self) private var player
    private let initialRoute: Route?

    init(catalog: any CatalogProviding, initialTab: AppTab = .home, initialQuery: String = "", initialRoute: Route? = nil, provider: Provider = .appleMusic) {
        _tabs = State(initialValue: TabSelection(initialTab))
        _search = State(initialValue: SearchModel(catalog: catalog, query: initialQuery, provider: provider))
        self.initialRoute = initialRoute
    }

    var body: some View {
        @Bindable var player = player
        TabView(selection: $tabs.tab) {
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
        // Only once something is playing or paused: nothing to show before.
        .tabViewBottomAccessory(isEnabled: player.session != nil) {
            MiniPlayerView(namespace: nowPlayingNamespace)
        }
        .environment(\.selectTab, { [tabs] tab in
            tabs.tab = tab
        })
        .sheet(isPresented: $player.showsNowPlaying) {
            NowPlayingView()
                .navigationTransition(.zoom(sourceID: "nowPlaying", in: nowPlayingNamespace))
        }
        .alert("Can't Play", isPresented: $player.showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
        }
        .modifier(ComedySearchField(model: search, isEnabled: !ComedySearchField.onSearchPage))
        .onChange(of: search.query) {
            search.queryChanged()
        }
        .overlay {
            LibraryFeedbackHUD()
        }
        .task {
            // A query from launch arguments searches right away.
            if !search.term.isEmpty {
                search.submit()
            }
        }
    }
}

/// Which tab is showing, so a page inside one can switch to another
/// (`selectTab`).
@MainActor
@Observable
final class TabSelection {
    var tab: AppTab

    init(_ tab: AppTab) {
        self.tab = tab
    }
}

/// The search field, its as-you-type suggestions, and Return to search.
struct ComedySearchField: ViewModifier {
    @Bindable var model: SearchModel
    var isEnabled = true

    /// On iPad the field sits on the Search page rather than the tab view.
    @MainActor static var onSearchPage: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    func body(content: Content) -> some View {
        if isEnabled {
            content
                // On the Search page (iPad) the field stays open under the
                // title, rather than folding into another search button.
                .searchable(text: $model.query, placement: Self.onSearchPage ? .navigationBarDrawer(displayMode: .always) : .automatic, prompt: "Comedians, Specials, and Bits")
                .searchSuggestions {
                    ForEach(model.visibleSuggestions) { suggestion in
                        SuggestionRow(suggestion: suggestion)
                            .searchCompletion(suggestion.title)
                    }
                }
                .onSubmit(of: .search) {
                    model.submit()
                }
        } else {
            content
        }
    }
}

#Preview {
    MainTabView(catalog: MockCatalog())
        .previewEnvironment()
}
