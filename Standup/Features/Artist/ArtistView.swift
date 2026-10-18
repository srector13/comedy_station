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
        }
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
                    Text(shown.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .accessibilityAddTraits(.isHeader)
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
            .accessibilityIdentifier("artist.hero")
    }

    @ViewBuilder
    private func sections(_ detail: ArtistDetail) -> some View {
        if let featured = detail.featured {
            NavigationLink(value: Route.album(featured)) {
                FeaturedSpecialCard(album: featured)
            }
            .buttonStyle(.plain)
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
                            if let album = track.albumStub {
                                play(PlayRequest(item: .album(album), startIndex: max((track.trackNumber ?? 1) - 1, 0)))
                            }
                        } label: {
                            BitRow(track: track, subtitle: track.albumTitle)
                                .padding(.vertical, 6)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
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

/// The latest special, in its own card on the comedian's page.
struct FeaturedSpecialCard: View {
    let album: ComedyAlbum

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 400)
                .frame(width: 104, height: 104)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text("LATEST SPECIAL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(album.title)
                    .font(.headline)
                    .lineLimit(2)
                Text([Format.longDate(album.releaseDate), album.trackCount > 0 ? Format.bitCount(album.trackCount) : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the special")
    }
}

#Preview {
    NavigationStack {
        ArtistView(artist: MockData.comedians[0])
            .comedyDestinations()
    }
    .tint(Theme.accent)
}
