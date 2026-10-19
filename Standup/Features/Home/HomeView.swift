import SwiftData
import SwiftUI

/// Home, Music style: Continue Listening (specials left partway, newest
/// first, each with its progress ring), New Specials and the Top Comedy
/// chart from the catalog, and Recently Added from the App Library.
struct HomeView: View {
    @State private var path: [Route]
    @State private var charts: LoadState<ComedyCharts> = .loading

    @Environment(\.catalog) private var catalog
    @Environment(\.play) private var play
    @Environment(LibraryStore.self) private var library
    @Environment(SpecialsSettings.self) private var specials

    @Query(filter: #Predicate<PlaybackProgress> { $0.isAlbum && !$0.finished }, sort: \PlaybackProgress.lastPlayed, order: .reverse)
    private var inProgress: [PlaybackProgress]
    @Query(sort: \SavedAlbum.dateAdded, order: .reverse) private var recentlyAdded: [SavedAlbum]

    init(initialPath: [Route] = []) {
        _path = State(initialValue: initialPath)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 34) {
                    if !inProgress.isEmpty {
                        continueListening
                    }
                    switch charts {
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 160)
                    case .failed(let message):
                        chartsUnavailable(message)
                    case .loaded(let charts):
                        catalogShelves(charts)
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
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Home")
            .settingsButton()
            .comedyDestinations()
            // Again when the TMDB key changes in Settings.
            .task(id: specials.revision) { await loadCharts() }
            .refreshable { await loadCharts() }
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

    @ViewBuilder
    private func catalogShelves(_ charts: ComedyCharts) -> some View {
        let newSpecials = charts.newSpecials()
        if !newSpecials.isEmpty {
            Shelf(title: "New Specials") {
                ForEach(newSpecials) { album in
                    NavigationLink(value: Route.album(album)) {
                        SpecialCard(album: album)
                    }
                    .buttonStyle(.plain)
                    .libraryContextMenu(.special(album))
                }
            }
        }
        if !charts.topSpecials.isEmpty {
            RankedGrid(title: charts.specialsSource == .chart ? "Top Comedy" : charts.specialsTitle, items: Array(charts.topSpecials.prefix(12))) { rank, album in
                NavigationLink(value: Route.album(album)) {
                    RankedRow(rank: charts.specialRank(rank), title: album.title, subtitle: album.artistName, artwork: album.artwork, placeholderTitle: album.title)
                }
                .buttonStyle(.plain)
                .libraryContextMenu(.special(album))
            }
        }
    }

    private func chartsUnavailable(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Can't Load the Charts", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await loadCharts() }
            }
            .buttonStyle(.glass)
        }
    }

    private func loadCharts() async {
        do {
            charts = .loaded(try await catalog.charts())
        } catch {
            if charts.value == nil {
                charts = .failed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    HomeView()
        .previewEnvironment()
}
