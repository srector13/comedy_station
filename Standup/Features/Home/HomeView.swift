import SwiftData
import SwiftUI

/// Home, Music style, from the top:
/// - Continue Listening: specials left partway, newest first, each with a
///   bar showing how far through it is.
/// - New Specials and Popular Specials: from TMDB, as their albums on the
///   service Standup runs on. On Apple Music, Apple's Comedy chart fills
///   in without a TMDB key; Spotify has no chart, so Home asks for a key.
/// - Trending Comedians: the comedians behind TMDB's new and popular
///   specials.
/// - More from …: other specials by comedians in the App Library; just one
///   gets a wide card of its own.
/// - Essential Specials: TMDB's best rated of all time.
/// - Recently Added, from the App Library.
///
/// New, Popular and Essential open all their specials (See All) from their
/// titles. Each part loads on its own, so the page fills in as answers
/// arrive, with a shimmering placeholder shaped like it until then.
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
    /// TMDB's shelves and, when they fall short, Apple's chart have all
    /// answered once.
    @State private var specialsLoaded = false
    @State private var charts: LoadState<ComedyCharts>?
    @State private var trending: [ComedyArtist] = []
    @State private var trendingLoaded = false
    @State private var moreFrom: [MoreFrom] = []

    @Environment(\.catalog) private var catalog
    @Environment(\.play) private var play
    @Environment(LibraryStore.self) private var library
    @Environment(SpecialsSettings.self) private var specials
    @Environment(ServiceChoice.self) private var service

    @Query(filter: #Predicate<PlaybackProgress> { $0.isAlbum && !$0.finished }, sort: \PlaybackProgress.lastPlayed, order: .reverse)
    private var inProgress: [PlaybackProgress]
    @Query(sort: \SavedAlbum.dateAdded, order: .reverse) private var recentlyAdded: [SavedAlbum]
    @Query(sort: \SavedComedian.dateAdded, order: .reverse) private var savedComedians: [SavedComedian]

    init(initialPath: [Route] = []) {
        _path = State(initialValue: initialPath)
    }

    private var provider: Provider {
        service.provider ?? .appleMusic
    }

    /// The Spotify route found nothing for Home: no TMDB key, or nothing
    /// TMDB named is on Spotify.
    private var spotifyHasNothing: Bool {
        provider == .spotify && shelvesLoaded && trending.isEmpty && shelves.values.allSatisfy(\.isEmpty)
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
                    if !newSpecials.isEmpty {
                        cards(DiscoverShelf.new.title, newSpecials, id: "home.new", seeAll: true)
                    } else if !specialsLoaded {
                        ShelfSkeleton()
                            .loadingPlaceholder("home.loading")
                    }
                    rankedSpecials
                    if !trending.isEmpty {
                        trendingComedians
                    } else if !trendingLoaded {
                        BubbleShelfSkeleton()
                            .loadingPlaceholder("home.loading")
                    }
                    ForEach(moreFrom) { entry in
                        moreFromSection(entry)
                    }
                    if let essential = shelves[.essential], !essential.isEmpty {
                        cards(DiscoverShelf.essential.title, essential, id: "home.essential", seeAll: true)
                    } else if shelves[.essential] == nil {
                        ShelfSkeleton()
                            .loadingPlaceholder("home.loading")
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
                    if spotifyHasNothing {
                        spotifyNeedsSpecials
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
            .task(id: moreFromComedians.map(\.artistID)) { await loadMoreFrom() }
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

    /// A shelf of special cards; with `seeAll`, its title opens all of
    /// them, and with `comedian`, the comedian's page.
    private func cards(_ title: String, _ albums: [ComedyAlbum], id: String, seeAll: Bool = false, comedian: ComedyArtist? = nil) -> some View {
        Shelf(title: title, route: comedian.map(Route.artist) ?? (seeAll ? .specials(title: title, albums: albums) : nil)) {
            ForEach(albums.prefix(20)) { album in
                NavigationLink(value: Route.album(album)) {
                    SpecialCard(album: album)
                }
                .buttonStyle(.plain)
                .libraryContextMenu(.special(album))
                .accessibilityIdentifier("\(id).\(album.id)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    /// Other specials by a comedian in the App Library, leaving out saved
    /// ones. Just one gets a wide card, not a shelf of one.
    @ViewBuilder
    private func moreFromSection(_ entry: MoreFrom) -> some View {
        let unsaved = entry.specials.filter { !library.specialIDs.contains($0.id) }
        let title = "More from \(entry.comedian.name)"
        let id = "home.moreFrom.\(entry.comedian.id)"
        if unsaved.count == 1, let album = unsaved.first {
            VStack(alignment: .leading, spacing: 12) {
                ShelfHeader(title: title, route: .artist(entry.comedian))
                NavigationLink(value: Route.album(album)) {
                    FeaturedSpecialCard(album: album, label: nil, showsComedian: true)
                }
                .buttonStyle(.plain)
                .libraryContextMenu(.special(album))
                .padding(.horizontal, 20)
                .accessibilityIdentifier("\(id).\(album.id)")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(id)
        } else if !unsaved.isEmpty {
            cards(title, unsaved, id: id, comedian: entry.comedian)
        }
    }

    /// TMDB's popular specials, or else Apple's Comedy chart, ranked.
    @ViewBuilder
    private var rankedSpecials: some View {
        if let popular {
            ranked(DiscoverShelf.popular.title, popular, ranks: true)
        } else if let charts = charts?.value, !charts.topSpecials.isEmpty {
            ranked(charts.specialsSource == .chart ? "Top Comedy" : charts.specialsTitle, charts.topSpecials, ranks: charts.specialsSource != .search)
        } else if !specialsLoaded {
            RankedSkeleton()
                .loadingPlaceholder("home.loading")
        }
    }

    private func ranked(_ title: String, _ albums: [ComedyAlbum], ranks: Bool) -> some View {
        RankedGrid(title: title, route: .specials(title: title, albums: albums), items: Array(albums.prefix(20))) { rank, album in
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

    private var spotifyNeedsSpecials: some View {
        Group {
            if specials.isAvailable {
                ContentUnavailableView(
                    "No Specials Matched",
                    systemImage: "magnifyingglass",
                    description: Text("None of TMDB's new or popular specials turned up on Spotify. Pull to refresh, or search.")
                )
            } else {
                ContentUnavailableView(
                    "Add a TMDB Key",
                    systemImage: "sparkles.tv",
                    description: Text("Home's new, popular and essential specials come from TMDB. Add your free TMDB key in Settings (the gear above), and Home shows the ones on Spotify.")
                )
            }
        }
        .accessibilityIdentifier("home.spotifyEmpty")
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

    /// TMDB's shelves, each shown as it arrives; on Apple Music, Apple's
    /// chart when TMDB leaves New or Popular short (no key, or nothing
    /// matched).
    private func loadSpecials() async {
        let catalog = self.catalog, provider = self.provider
        await withTaskGroup(of: (DiscoverShelf, [ComedyAlbum]).self) { group in
            for shelf in DiscoverShelf.allCases {
                group.addTask { (shelf, (try? await catalog.discover(shelf, in: provider)) ?? []) }
            }
            for await (shelf, albums) in group {
                shelves[shelf] = albums
            }
        }
        shelvesLoaded = true
        defer { specialsLoaded = true }
        guard provider == .appleMusic, (shelves[.new] ?? []).isEmpty || popular == nil else { return }
        do {
            charts = .loaded(try await catalog.charts())
        } catch {
            if charts?.value == nil {
                charts = .failed(error.localizedDescription)
            }
        }
    }

    private func loadTrending() async {
        trending = (try? await catalog.trendingComedians(in: provider)) ?? []
        trendingLoaded = true
    }

    /// The three comedians from this service added to the App Library most
    /// recently.
    private var moreFromComedians: [SavedComedian] {
        Array(savedComedians.filter { Provider.of($0.artistID) == provider }.prefix(3))
    }

    /// `moreFromComedians`, with their specials.
    private func loadMoreFrom() async {
        var found: [MoreFrom] = []
        for saved in moreFromComedians {
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
