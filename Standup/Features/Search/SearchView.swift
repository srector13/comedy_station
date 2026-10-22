import SwiftUI

/// The search tab's page. On iPhone the field itself belongs to the tab
/// view (`MainTabView`), which is what makes the bar show search as its own
/// tab; on iPad it's on this page.
struct SearchView: View {
    let model: SearchModel
    @Environment(SpotifyAccount.self) private var spotify
    @Environment(ServiceChoice.self) private var service

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .top) {
                    // The Spotify route searches only Spotify.
                    if spotify.isConnected && !service.isSpotify {
                        providerPicker
                    }
                }
                .navigationTitle("Search")
                .modifier(ComedySearchField(model: model, isEnabled: ComedySearchField.onSearchPage))
                .comedyDestinations()
        }
        .onChange(of: spotify.isConnected) { _, connected in
            if !connected && !service.isSpotify {
                model.setProvider(.appleMusic)
            }
        }
    }

    /// Apple Music | Spotify, once Spotify is connected on the Apple Music
    /// route.
    private var providerPicker: some View {
        @Bindable var model = model
        return Picker("Search", selection: $model.searchProvider) {
            ForEach(Provider.allCases) { provider in
                Text(provider.name).tag(provider)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
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

/// Results in Music's order: comedians, then specials, then bits. A bit
/// plays when tapped, as everywhere; Show Special (touch and hold) opens its
/// special.
struct SearchResultsList: View {
    let results: SearchResults

    @Environment(\.play) private var play
    @State private var shownSpecial: ComedyAlbum?

    var body: some View {
        List {
            if !results.comedians.isEmpty {
                Section("Comedians") {
                    ForEach(results.comedians) { artist in
                        NavigationLink(value: Route.artist(artist)) {
                            ComedianRow(artist: artist)
                        }
                        .accessibilityIdentifier("result.artist.\(artist.id)")
                        .libraryContextMenu(.comedian(artist))
                        .librarySwipeActions(.comedian(artist))
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
                        .libraryContextMenu(.special(album))
                        .librarySwipeActions(.special(album))
                    }
                }
            }
            if !results.bits.isEmpty {
                Section("Bits") {
                    ForEach(results.bits) { track in
                        Button {
                            play(.bit(track))
                        } label: {
                            BitRow(track: track)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Plays the bit")
                        .accessibilityIdentifier("result.track.\(track.id)")
                        .libraryContextMenu(.bit(track), showSpecial: showSpecial(of: track))
                        .librarySwipeActions(.bit(track))
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(item: $shownSpecial) { album in
            AlbumView(album: album)
        }
    }

    private func showSpecial(of track: ComedyTrack) -> (() -> Void)? {
        guard let album = track.albumStub else { return nil }
        return { shownSpecial = album }
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
    .previewEnvironment()
}
