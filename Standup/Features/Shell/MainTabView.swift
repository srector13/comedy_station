import SwiftUI

enum AppTab: String, Hashable, CaseIterable, Sendable {
    case home, browse, library, search
}

/// The Music-style shell: a system `TabView`, so the platform draws the
/// Liquid Glass bar, minimize-on-scroll, and the sidebar on iPad. Search is
/// a `.search`-role tab with `.searchable` on the tab view itself, which is
/// what sets it apart at the trailing end of the bar. The mini-player rides
/// above the tabs as the bar's bottom accessory, once something is loaded.
/// On the Spotify route there's no Browse: Spotify has no comedy charts or
/// playlists for an app like this.
struct MainTabView: View {
    @State private var selection: AppTab
    @State private var search: SearchModel
    @Namespace private var nowPlayingNamespace
    @Environment(PlayerService.self) private var player
    private let initialRoute: Route?
    private let provider: Provider

    init(catalog: any CatalogProviding, initialTab: AppTab = .home, initialQuery: String = "", initialRoute: Route? = nil, provider: Provider = .appleMusic) {
        _selection = State(initialValue: provider == .spotify && initialTab == .browse ? .home : initialTab)
        _search = State(initialValue: SearchModel(catalog: catalog, query: initialQuery, provider: provider))
        self.initialRoute = initialRoute
        self.provider = provider
    }

    var body: some View {
        @Bindable var player = player
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView(initialPath: initialRoute.map { [$0] } ?? [])
            }
            if provider == .appleMusic {
                Tab("Browse", systemImage: "square.grid.2x2.fill", value: AppTab.browse) {
                    BrowseView()
                }
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
        .sheet(isPresented: $player.showsNowPlaying) {
            NowPlayingView()
                .navigationTransition(.zoom(sourceID: "nowPlaying", in: nowPlayingNamespace))
        }
        .alert("Can't Play", isPresented: $player.showsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "")
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

#Preview {
    MainTabView(catalog: MockCatalog())
        .previewEnvironment()
}
