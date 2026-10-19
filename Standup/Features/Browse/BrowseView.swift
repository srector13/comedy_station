import SwiftUI

/// Browse: the Comedy charts and comedy playlists. A featured new special
/// up top, then Top Specials, Top Bits (tap to play) and Playlists.
struct BrowseView: View {
    @State private var charts: LoadState<ComedyCharts> = .loading

    @Environment(\.catalog) private var catalog
    @Environment(\.play) private var play

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 34) {
                    switch charts {
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 240)
                    case .failed(let message):
                        ContentUnavailableView {
                            Label("Can't Load Browse", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Try Again") {
                                Task { await load() }
                            }
                            .buttonStyle(.glass)
                        }
                    case .loaded(let charts):
                        sections(charts)
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Browse")
            .comedyDestinations()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    @ViewBuilder
    private func sections(_ charts: ComedyCharts) -> some View {
        if let featured = charts.newSpecials().first ?? charts.topSpecials.first {
            NavigationLink(value: Route.album(featured)) {
                FeaturedBanner(album: featured, label: charts.newSpecials().isEmpty ? "TOP SPECIAL" : "NEW SPECIAL")
            }
            .buttonStyle(.plain)
            .libraryContextMenu(.special(featured))
            .padding(.horizontal, 20)
            .accessibilityIdentifier("browse.featured")
        }

        if !charts.topSpecials.isEmpty {
            Shelf(title: "Top Specials") {
                ForEach(charts.topSpecials) { album in
                    NavigationLink(value: Route.album(album)) {
                        SpecialCard(album: album)
                    }
                    .buttonStyle(.plain)
                    .libraryContextMenu(.special(album))
                }
            }
        }

        if !charts.topBits.isEmpty {
            RankedGrid(title: "Top Bits", items: charts.topBits) { rank, track in
                Button {
                    if let album = track.albumStub {
                        play(PlayRequest(item: .album(album), startIndex: max((track.trackNumber ?? 1) - 1, 0)))
                    }
                } label: {
                    RankedRow(rank: rank, title: track.title, subtitle: track.artistName, artwork: track.artwork, placeholderTitle: track.albumTitle ?? track.title)
                }
                .buttonStyle(.plain)
                .libraryContextMenu(.bit(track))
                .accessibilityHint("Plays the special from this bit")
            }
        }

        if !charts.playlists.isEmpty {
            Shelf(title: "Comedy Playlists") {
                ForEach(charts.playlists) { playlist in
                    NavigationLink(value: Route.playlist(playlist)) {
                        PlaylistCard(playlist: playlist)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("browse.playlist.\(playlist.id)")
                }
            }
        }
    }

    private func load() async {
        do {
            charts = .loaded(try await catalog.charts())
        } catch {
            if charts.value == nil {
                charts = .failed(error.localizedDescription)
            }
        }
    }
}

/// A big card for one special, tinted from its artwork, like Music's
/// editorial banners.
struct FeaturedBanner: View {
    let album: ComedyAlbum
    let label: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(spacing: 16))
        layout {
            ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 600)
                .frame(width: 132, height: 132)
                .clipShape(.rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(album.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text([album.artistName, Format.year(album.releaseDate)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [album.artwork.tint, album.artwork.tint.mix(with: .black, by: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 22)
        )
        .contentShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the special")
    }
}

#Preview {
    BrowseView()
        .previewEnvironment()
}
