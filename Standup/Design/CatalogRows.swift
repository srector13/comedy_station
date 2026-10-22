import SwiftUI

/// A comedian in a list: round artwork and name. (The round artwork, and
/// the section, already say it's a comedian.)
struct ComedianRow: View {
    let artist: ComedyArtist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(artist.artwork, placeholder: .monogram(artist.name), pixels: 160)
                .frame(width: 52, height: 52)
                .clipShape(.circle)
            HStack(spacing: 4) {
                Text(artist.name)
                    .font(.body)
                    .lineLimit(1)
                ProviderBadge(id: artist.id)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A special in a list: artwork, title, comedian and year.
struct SpecialRow: View {
    let album: ComedyAlbum
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 160)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(album.title)
                        .font(.body)
                        .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                    if album.isExplicit { ExplicitBadge() }
                    ProviderBadge(id: album.id)
                }
                Text([album.artistName, Format.year(album.releaseDate)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A bit in a list: artwork, title, comedian and special, duration. The bit playing
/// (or just tapped and loading) is marked on its artwork and in the accent
/// color.
struct BitRow: View {
    let track: ComedyTrack
    var subtitle: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(PlayerService.self) private var player

    var body: some View {
        // At accessibility sizes the duration moves under the title, which
        // gets the full width.
        let large = typeSize.isAccessibilitySize
        let state = player.state(ofBit: track.id)
        HStack(spacing: 12) {
            ArtworkView(track.artwork, placeholder: .poster(track.albumTitle ?? track.title), pixels: 160)
                .frame(width: 48, height: 48)
                .overlay {
                    if state != .none {
                        Color.black.opacity(0.45)
                        BitStateIndicator(state: state, tint: .white)
                    }
                }
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(track.title)
                        .font(.body)
                        .foregroundStyle(state == .none ? Color.primary : Theme.accent)
                        .lineLimit(large ? 3 : 1)
                    if track.isExplicit { ExplicitBadge() }
                    ProviderBadge(id: track.id)
                }
                Text(subtitle ?? [track.artistName, track.albumTitle].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(large ? 2 : 1)
                if large {
                    Text(Format.trackTime(track.duration))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if !large {
                Text(Format.trackTime(track.duration))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(BitStateIndicator.description(of: state))
    }
}

/// The mark on the bit that's playing (moving bars), paused (still bars),
/// or just tapped and loading (a spinner), so it's clear which one was
/// picked before it starts.
struct BitStateIndicator: View {
    let state: PlayerService.BitState
    var tint = Theme.accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch state {
        case .none:
            EmptyView()
        case .loading:
            ProgressView()
                .controlSize(.small)
                .tint(tint)
        case .playing, .paused:
            Image(systemName: "waveform")
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .symbolEffect(.variableColor.iterative, isActive: state == .playing && !reduceMotion)
        }
    }

    /// For VoiceOver.
    static func description(of state: PlayerService.BitState) -> String {
        switch state {
        case .none: ""
        case .loading: "Loading"
        case .playing: "Now Playing"
        case .paused: "Paused"
        }
    }
}

/// A special in a shelf or grid: artwork over title and year (and the
/// comedian, where specials by several are mixed). A nil width fills the
/// grid cell.
struct SpecialCard: View {
    let album: ComedyAlbum
    var width: CGFloat? = 160
    var showsComedian = false
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Wider at accessibility text sizes; nil (fill the cell) stays nil.
    private var shownWidth: CGFloat? { width.map { typeSize.cardWidth($0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 500)
                .frame(width: shownWidth, height: shownWidth)
                .clipShape(.rect(cornerRadius: 8))
            Text(album.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
            let detail = [showsComedian ? album.artistName : nil, Format.year(album.releaseDate)].compactMap { $0 }
            if !detail.isEmpty {
                Text(detail.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            }
        }
        .frame(width: shownWidth, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A special in its own wide card: the latest one on a comedian's page
/// (under a label), or the only one in a Home shelf, where a lone card
/// would leave the row half empty.
struct FeaturedSpecialCard: View {
    let album: ComedyAlbum
    /// The small accent line over the title, if any.
    var label: String? = "LATEST SPECIAL"
    var showsComedian = false

    var body: some View {
        HStack(spacing: 14) {
            ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 400)
                .frame(width: 104, height: 104)
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                if let label {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text(album.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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

    /// When it came out and how many bits, after the comedian if shown.
    private var details: String {
        [
            showsComedian ? album.artistName : nil,
            showsComedian ? Format.year(album.releaseDate) : Format.longDate(album.releaseDate),
            album.trackCount > 0 ? Format.bitCount(album.trackCount) : nil,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

/// A comedian in a horizontal shelf: round artwork over the name.
struct ComedianBubble: View {
    let artist: ComedyArtist
    var width: CGFloat = 112

    var body: some View {
        VStack(spacing: 8) {
            ArtworkView(artist.artwork, placeholder: .monogram(artist.name), pixels: 360)
                .frame(width: width, height: width)
                .clipShape(.circle)
            Text(artist.name)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: width)
        .accessibilityElement(children: .combine)
    }
}

/// "SPOTIFY" beside Spotify items: Spotify's terms ask for its name next to
/// its content. Nothing for Apple Music, the default.
struct ProviderBadge: View {
    let id: String

    var body: some View {
        if Provider.of(id) == .spotify {
            Text("SPOTIFY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.secondary.opacity(0.18), in: .rect(cornerRadius: 3))
                .accessibilityLabel("From Spotify")
        }
    }
}

/// "Open in Spotify" as a glass button, on a Spotify special's or
/// comedian's page. White over the comedian's photo.
struct OpenInSpotifyButton: View {
    let url: URL
    var onImage = false

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 6) {
                Text("Open in Spotify")
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .accessibilityHidden(true)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(onImage ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(minHeight: 30)
        }
        .buttonStyle(.glass)
        .accessibilityHint("Opens the Spotify app")
    }
}

/// The "E" Music shows beside explicit titles.
struct ExplicitBadge: View {
    var body: some View {
        Image(systemName: "e.square.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Explicit")
    }

    /// The "E" as text, to follow a title that can wrap: it stays right
    /// after the last word instead of floating beside the whole block.
    static var text: Text {
        Text(Image(systemName: "e.square.fill"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Explicit")
    }
}

/// A shelf title, Music style: bold, and with a route, a chevron that
/// opens the whole list (See All).
struct ShelfHeader: View {
    let title: String
    var route: Route?

    var body: some View {
        Group {
            if let route {
                NavigationLink(value: route) {
                    HStack(spacing: 4) {
                        Text(title)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.forward")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows all of them")
                // The chevron's tap area, not the title's height, sets the
                // header's: keep shelves where they were.
                .padding(.vertical, -8)
            } else {
                Text(title)
            }
        }
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)
        .padding(.horizontal, 20)
    }
}

/// Play and Shuffle side by side, stacked at accessibility text sizes so
/// neither label is cut off. No wider than a phone's, centered, on iPad.
struct PlayButtonsLayout<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            content
        }
        .frame(maxWidth: typeSize.isAccessibilitySize ? 520 : 420)
        .frame(maxWidth: .infinity)
    }
}
