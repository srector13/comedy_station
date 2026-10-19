import SwiftUI

/// A comedian in a list: round artwork and name.
struct ComedianRow: View {
    let artist: ComedyArtist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(artist.artwork, placeholder: .monogram(artist.name), pixels: 160)
                .frame(width: 52, height: 52)
                .clipShape(.circle)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(artist.name)
                        .font(.body)
                        .lineLimit(1)
                    ProviderBadge(id: artist.id)
                }
                Text("Comedian")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                Text(["Special", album.artistName, Format.year(album.releaseDate)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A bit in a list: artwork, title, comedian, duration. The bit playing
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
                Text(subtitle ?? "Bit · \(track.artistName)")
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

/// A special in a shelf or grid: artwork over title and year. A nil width
/// fills the grid cell.
struct SpecialCard: View {
    let album: ComedyAlbum
    var width: CGFloat? = 160
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
            if let year = Format.year(album.releaseDate) {
                Text(year)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: shownWidth, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .accessibilityElement(children: .combine)
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

/// The "E" Music shows beside explicit titles.
struct ExplicitBadge: View {
    var body: some View {
        Image(systemName: "e.square.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Explicit")
    }
}

/// A shelf title, Music style: bold, with an optional chevron.
struct ShelfHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 20)
    }
}

/// Play and Shuffle side by side, stacked at accessibility text sizes so
/// neither label is cut off.
struct PlayButtonsLayout<Content: View>: View {
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        layout {
            content
        }
    }
}
