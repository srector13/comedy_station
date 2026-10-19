import SwiftData
import SwiftUI

/// Home, Music style, from the top:
/// - Continue Listening: specials left partway, newest first, each with its
///   progress ring.
/// - New Specials and Popular Specials: from TMDB, as their Apple Music
///   albums, or from Apple's Comedy chart without a TMDB key.
/// - Trending Comedians: the comedians behind TMDB's new and popular
///   specials.
/// - More from …: other specials by comedians in the App Library.
/// - Essential Specials: TMDB's best rated of all time.
/// - Recently Added, from the App Library.
///
/// Each part loads on its own, so the page fills in as answers arrive.
struct HomeView: View {
    /// Other specials by a comedian in the App Library.
    struct MoreFrom: Identifiable {
        var comedian: ComedyArtist
        var specials: [ComedyAlbum]
        var id: String { comedian.id }
    }

    @State private var path: [Route]
    @State private var shelves: [DiscoverShelf: [ComedyAlbum]] = [:]
    @State private var shelvesLoaded = false
    @State private var charts: LoadState<ComedyCharts>?
    @State private var trending: [ComedyArtist] = []
    @State private var moreFrom: [MoreFrom] = []

    @Environment(\.catalog) private var catalog
    @Environment(\.play) private var play
    @Environment(LibraryStore.self) private var library
    @Environment(SpecialsSettings.self) private var specials

    @Query(filter: #Predicate<PlaybackProgress> { $0.isAlbum && !$0.finished }, sort: \PlaybackProgress.lastPlayed, order: .reverse)
    private var inProgress: [PlaybackProgress]
    @Query(sort: \SavedAlbum.dateAdded, order: .reverse) private var recentlyAdded: [SavedAlbum]
    @Query(sort: \SavedComedian.dateAdded, order: .reverse) private var savedComedians: [SavedComedian]

    init(initialPath: [Route] = []) {
        _path = State(initialValue: initialPath)
    }

    /// TMDB's new specials, or else the chart's recent ones.
    private var newSpecials: [ComedyAlbum] {
        if let new = shelves[.new], !new.isEmpty { return new }
        return charts?.value?.newSpecials() ?? []
    }

    /// TMDB's popular specials when there are enough to rank.
    private var popular: [ComedyAlbum]? {
        guard let popular = shelves[.popular], popular.count >= 4 else { return nil }
        return popular
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 34) {
                    if !inProgress.isEmpty {
                        continueListening
                    }
                    if !shelvesLoaded && charts == nil {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 160)
                    }
                    if !newSpecials.isEmpty {
                        cards(DiscoverShelf.new.title, newSpecials, id: "home.new")
                    }
                    rankedSpecials
                    if !trending.isEmpty {
                        trendingComedians
                    }
                    ForEach(moreFrom) { entry in
                        let unsaved = entry.specials.filter { !library.specialIDs.contains($0.id) }
                        if !unsaved.isEmpty {
                            cards("More from \(entry.comedian.name)", unsaved, id: "home.moreFrom.\(entry.comedian.id)")
                        }
                    }
                    if let essential = shelves[.essential], !essential.isEmpty {
                        cards(DiscoverShelf.essential.title, essential, id: "home.essential")
                    }
                    if !recentlyAdded.isEmpty {
                        Shelf(title: "Recently Added") {
                            ForEach(recentlyAdded.prefix(10)) { saved in
                                NavigationLink(value: Route.album(saved.album)) {
                                    SpecialCard(album: saved.album)
                                }
                                .buttonStyle(.plain)
                                .libraryContextMenu(.special(saved.album))
                            }
                        }
                    }
                    if case .failed(let message) = charts, newSpecials.isEmpty, popular == nil {
                        chartsUnavailable(message)
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Home")
            .settingsButton()
            .comedyDestinations()
            // Again when the TMDB key changes in Settings.
            .task(id: specials.revision) { await loadSpecials() }
            .task(id: specials.revision) { await loadTrending() }
            .task(id: savedComedians.prefix(3).map(\.artistID)) { await loadMoreFrom() }
            .refreshable {
                await loadSpecials()
                await loadTrending()
                await loadMoreFrom()
            }
        }
    }

    // MARK: Sections

    private var continueListening: some View {
        Shelf(title: "Continue Listening") {
            ForEach(inProgress.prefix(10)) { record in
                let progress = record.snapshot
                Button {
                    play(PlayRequest(item: .album(progress.albumStub), resume: true))
                } label: {
                    ContinueListeningCard(progress: progress)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Show Special", systemImage: "square.stack") {
                        path.append(.album(progress.albumStub))
                    }
                    Button("Remove from Continue Listening", systemImage: "minus.circle", role: .destructive) {
                        library.removeProgress(for: progress.itemID)
                    }
                }
                .accessibilityIdentifier("continue.\(progress.itemID)")
            }
        }
    }

    /// A shelf of special cards.
    private func cards(_ title: String, _ albums: [ComedyAlbum], id: String) -> some View {
        Shelf(title: title) {
            ForEach(albums.prefix(20)) { album in
                NavigationLink(value: Route.album(album)) {
                    SpecialCard(album: album)
                }
                .buttonStyle(.plain)
                .libraryContextMenu(.special(album))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    /// TMDB's popular specials, or else Apple's Comedy chart, ranked.
    @ViewBuilder
    private var rankedSpecials: some View {
        if let popular {
            ranked(DiscoverShelf.popular.title, popular, ranks: true)
        } else if let charts = charts?.value, !charts.topSpecials.isEmpty {
            ranked(charts.specialsSource == .chart ? "Top Comedy" : charts.specialsTitle, charts.topSpecials, ranks: charts.specialsSource != .search)
        }
    }

    private func ranked(_ title: String, _ albums: [ComedyAlbum], ranks: Bool) -> some View {
        RankedGrid(title: title, items: Array(albums.prefix(20))) { rank, album in
            NavigationLink(value: Route.album(album)) {
                RankedRow(rank: ranks ? rank : nil, title: album.title, subtitle: album.artistName, artwork: album.artwork, placeholderTitle: album.title)
            }
            .buttonStyle(.plain)
            .libraryContextMenu(.special(album))
        }
    }

    private var trendingComedians: some View {
        Shelf(title: "Trending Comedians") {
            ForEach(trending) { comedian in
                NavigationLink(value: Route.artist(comedian)) {
                    ComedianBubble(artist: comedian)
                }
                .buttonStyle(.plain)
                .libraryContextMenu(.comedian(comedian))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.trending")
    }

    private func chartsUnavailable(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Can't Load the Charts", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await loadSpecials() }
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: Loading

    /// TMDB's shelves, each shown as it arrives; Apple's chart only when
    /// TMDB leaves New or Popular short (no key, or nothing matched).
    private func loadSpecials() async {
        let catalog = self.catalog
        await withTaskGroup(of: (DiscoverShelf, [ComedyAlbum]).self) { group in
            for shelf in DiscoverShelf.allCases {
                group.addTask { (shelf, (try? await catalog.discover(shelf)) ?? []) }
            }
            for await (shelf, albums) in group {
                shelves[shelf] = albums
            }
        }
        shelvesLoaded = true
        guard (shelves[.new] ?? []).isEmpty || popular == nil else { return }
        do {
            charts = .loaded(try await catalog.charts())
        } catch {
            if charts?.value == nil {
                charts = .failed(error.localizedDescription)
            }
        }
    }

    private func loadTrending() async {
        trending = (try? await catalog.trendingComedians()) ?? []
    }

    /// The three comedians added to the App Library most recently, with
    /// their specials.
    private func loadMoreFrom() async {
        var found: [MoreFrom] = []
        for saved in savedComedians.prefix(3) {
            let comedian = saved.comedian
            if let detail = try? await catalog.artist(id: comedian.id) {
                found.append(MoreFrom(comedian: comedian, specials: detail.specials))
            }
        }
        moreFrom = found
    }
}

#Preview {
    HomeView()
        .previewEnvironment()
}
