import SwiftUI

/// The search tab's page. The field itself belongs to the tab view
/// (`MainTabView`), which is what makes the bar show search as its own tab.
struct SearchView: View {
    let model: SearchModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .comedyDestinations()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            ContentUnavailableView {
                Label("Search Comedy", systemImage: "magnifyingglass")
            } description: {
                Text("Find comedians, specials, and bits.")
            }
        case .searching:
            ProgressView()
                .controlSize(.large)
        case .results:
            SearchResultsList(results: model.results)
        case .noResults:
            ContentUnavailableView.search(text: model.term)
        case .failed(let message):
            ContentUnavailableView {
                Label("Can't Search Right Now", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            }
        }
    }
}

/// Results in Music's order: comedians, then specials, then bits.
struct SearchResultsList: View {
    let results: SearchResults

    var body: some View {
        List {
            if !results.comedians.isEmpty {
                Section("Comedians") {
                    ForEach(results.comedians) { artist in
                        NavigationLink(value: Route.artist(artist)) {
                            ComedianRow(artist: artist)
                        }
                        .accessibilityIdentifier("result.artist.\(artist.id)")
                    }
                }
            }
            if !results.specials.isEmpty {
                Section("Specials") {
                    ForEach(results.specials) { album in
                        NavigationLink(value: Route.album(album)) {
                            SpecialRow(album: album)
                        }
                        .accessibilityIdentifier("result.album.\(album.id)")
                    }
                }
            }
            if !results.bits.isEmpty {
                Section("Bits") {
                    ForEach(results.bits) { track in
                        if let album = track.albumStub {
                            NavigationLink(value: Route.album(album)) {
                                BitRow(track: track)
                            }
                            .accessibilityIdentifier("result.track.\(track.id)")
                        } else {
                            BitRow(track: track)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

/// One as-you-type suggestion under the search field.
struct SuggestionRow: View {
    let suggestion: SearchSuggestion

    var body: some View {
        HStack(spacing: 12) {
            switch suggestion {
            case .comedian(let artist):
                ArtworkView(artist.artwork, placeholder: .monogram(artist.name), pixels: 120)
                    .frame(width: 40, height: 40)
                    .clipShape(.circle)
            case .special(let album):
                ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 120)
                    .frame(width: 40, height: 40)
                    .clipShape(.rect(cornerRadius: 5))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(suggestion.title)
                    .lineLimit(1)
                Text(suggestion.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Results") {
    @Previewable @State var model = SearchModel(catalog: MockCatalog(), query: "a")
    NavigationStack {
        SearchResultsList(results: model.results)
            .comedyDestinations()
    }
    .task { model.submit() }
    .tint(Theme.accent)
}
