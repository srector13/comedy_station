import SwiftUI

/// A comedian's page, Music style: full-bleed hero with Play and Shuffle,
/// the latest special in its own card, then Specials, Top Bits and Similar
/// Comedians. Everything shown passed the comedy filter.
struct ArtistView: View {
    let artist: ComedyArtist

    @Environment(\.catalog) private var catalog
    @Environment(\.play) private var play
    @State private var detail: LoadState<ArtistDetail> = .loading
    @State private var showsTitle = false

    private static let heroHeight: CGFloat = 420

    private var shown: ComedyArtist { detail.value?.artist ?? artist }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                hero
                switch detail {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't Load This Comedian", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    }
                case .loaded(let detail):
                    sections(detail)
                }
            }
            .padding(.bottom, 32)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle(shown.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(shown.name)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showsTitle ? 1 : 0)
                    .accessibilityHidden(!showsTitle)
            }
            ToolbarItem(placement: .topBarTrailing) {
                LibraryToolbarButton(item: .comedian(shown))
            }
        }
        // The hero runs under the bar, which leaves no edge effect behind
        // it; once the hero scrolls away the bar gets its background back
        // so the shelves don't show through the title.
        .toolbarBackgroundVisibility(showsTitle ? .visible : .hidden, for: .navigationBar)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > Self.heroHeight - 100
        } action: { _, pastHero in
            withAnimation(.easeInOut(duration: 0.2)) { showsTitle = pastHero }
        }
        .task(id: artist.id) {
            do {
                detail = .loaded(try await catalog.artist(id: artist.id))
            } catch {
                detail = .failed(error.localizedDescription)
            }
        }
    }

    private var hero: some View {
        Color.clear
            .frame(height: Self.heroHeight)
            .overlay {
                ArtworkView(shown.artwork, placeholder: .monogram(shown.name), pixels: 1400, fill: true)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 190)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shown.name)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                            .accessibilityAddTraits(.isHeader)
                        if let spotify = SpotifyWebAPI.webURL(for: shown.id) {
                            OpenInSpotifyButton(url: spotify, onImage: true)
                                .padding(.top, 4)
                                .accessibilityIdentifier("artist.openInSpotify")
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        play(PlayRequest(item: .artist(shown), shuffle: true))
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.title3.weight(.semibold))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("Shuffle")
                    .accessibilityIdentifier("artist.shuffle")
                    Button {
                        play(PlayRequest(item: .artist(shown)))
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("Play")
                    .accessibilityIdentifier("artist.play")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .clipped()
    }

    @ViewBuilder
    private func sections(_ detail: ArtistDetail) -> some View {
        if let featured = detail.featured {
            NavigationLink(value: Route.album(featured)) {
                FeaturedSpecialCard(album: featured)
            }
            .buttonStyle(.plain)
            .libraryContextMenu(.special(featured))
            .padding(.horizontal, 20)
            .accessibilityIdentifier("artist.featured")
        }

        if !detail.specials.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ShelfHeader(title: "Specials")
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(detail.specials) { album in
                            NavigationLink(value: Route.album(album)) {
                                SpecialCard(album: album)
                            }
                            .buttonStyle(.plain)
                            .libraryContextMenu(.special(album))
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
            }
        }

        if !detail.topBits.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ShelfHeader(title: "Top Bits")
                VStack(spacing: 0) {
                    ForEach(detail.topBits) { track in
                        Button {
                            play(.bit(track))
                        } label: {
                            BitRow(track: track, subtitle: track.albumTitle)
                                .padding(.vertical, 6)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .libraryContextMenu(.bit(track))
                        if track.id != detail.topBits.last?.id {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }

        if !detail.similar.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                ShelfHeader(title: "Similar Comedians")
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(detail.similar) { other in
                            NavigationLink(value: Route.artist(other)) {
                                ComedianBubble(artist: other)
                            }
                            .buttonStyle(.plain)
                            .libraryContextMenu(.comedian(other))
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ArtistView(artist: MockData.comedians[0])
            .comedyDestinations()
    }
    .previewEnvironment()
}
