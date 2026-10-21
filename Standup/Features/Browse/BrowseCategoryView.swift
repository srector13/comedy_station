import SwiftUI

/// A Browse list: TMDB's stand-up on a streaming service or from a decade,
/// as the specials on the service Standup runs on.
struct BrowseCategoryView: View {
    let category: BrowseCategory

    @State private var albums: LoadState<[ComedyAlbum]> = .loading
    @Environment(\.catalog) private var catalog
    @Environment(ServiceChoice.self) private var service

    private var provider: Provider {
        service.provider ?? .appleMusic
    }

    var body: some View {
        content
            .navigationTitle(category.title)
            .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch albums {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Can't Load \(category.title)", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") {
                    Task { await load() }
                }
                .buttonStyle(.glass)
            }
        case .loaded(let albums) where albums.isEmpty:
            ContentUnavailableView("Nothing Here Yet", systemImage: "magnifyingglass", description: Text(emptyMessage))
                .accessibilityIdentifier("category.empty")
        case .loaded(let albums):
            List {
                ForEach(albums) { album in
                    NavigationLink(value: Route.album(album)) {
                        SpecialRow(album: album)
                    }
                    .accessibilityIdentifier("category.album.\(album.id)")
                    .libraryContextMenu(.special(album))
                    .librarySwipeActions(.special(album))
                }
            }
            .listStyle(.plain)
            .refreshable { await load() }
        }
    }

    private var emptyMessage: String {
        switch category {
        case .streaming(_, let name, _): "No stand-up from \(name) turned up on \(provider.name) yet."
        case .decade(let start): "No stand-up from the \(start)s turned up on \(provider.name) yet."
        }
    }

    private func load() async {
        do {
            albums = .loaded(try await catalog.browse(category, in: provider))
        } catch {
            if albums.value == nil {
                albums = .failed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BrowseCategoryView(category: .decade(2020))
            .comedyDestinations()
    }
    .previewEnvironment()
}
