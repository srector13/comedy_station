import SwiftUI

/// A titled horizontal shelf, Music style.
struct Shelf<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: title)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    content
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

extension DynamicTypeSize {
    /// A shelf card's width: wider at accessibility sizes so a title fits in
    /// a few lines.
    func cardWidth(_ base: CGFloat) -> CGFloat {
        isAccessibilitySize ? max(base, 280) : base
    }
}

/// How far through a special: a ring on its artwork, as on Continue
/// Listening.
struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0.02), 1))
                .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityElement()
        .accessibilityLabel("\(Int((fraction * 100).rounded()))% played")
    }
}

/// A special left partway: artwork with its progress ring, title, and time
/// left. Tapping resumes it.
struct ContinueListeningCard: View {
    let progress: ProgressSnapshot
    var width: CGFloat = 160

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Wider at accessibility text sizes, so titles have room.
    private var shownWidth: CGFloat { typeSize.cardWidth(width) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(progress.artwork, placeholder: .poster(progress.title), pixels: 500)
                .frame(width: shownWidth, height: shownWidth)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(alignment: .bottomTrailing) {
                    ProgressRing(fraction: progress.fractionComplete)
                        .frame(width: 26, height: 26)
                        .padding(5)
                        .background(.black.opacity(0.35), in: .circle)
                        .padding(8)
                }
            Text(progress.title)
                .font(.subheadline)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
            Text(timeLeft)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
        }
        .frame(width: shownWidth, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Resumes the special")
    }

    private var timeLeft: String {
        progress.totalDuration > 0
            ? "\(Format.runtime(progress.remaining)) left"
            : progress.artistName
    }
}

/// A chart row: rank, artwork, title, subtitle. Music's Top Charts grid.
struct RankedRow: View {
    let rank: Int
    let title: String
    let subtitle: String
    let artwork: ArtworkRef
    var placeholderTitle: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(artwork, placeholder: .poster(placeholderTitle), pixels: 160)
                .frame(width: 52, height: 52)
                .clipShape(.rect(cornerRadius: 6))
            Text("\(rank)")
                .font(.headline)
                .monospacedDigit()
                .frame(minWidth: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(rank): \(title), \(subtitle)")
    }
}

/// A chart grid: rows in columns that scroll sideways, as in Music.
struct RankedGrid<Item: Identifiable, Row: View>: View {
    let title: String
    let items: [Item]
    var rows = 4
    @ViewBuilder var row: (Int, Item) -> Row

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: title)
            ScrollView(.horizontal) {
                LazyHGrid(rows: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 2 : rows), spacing: 16) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(index + 1, item)
                            .containerRelativeFrame(.horizontal, count: 10, span: 9, spacing: 16)
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

/// A playlist in a shelf: artwork over name and curator.
struct PlaylistCard: View {
    let playlist: ComedyPlaylist
    var width: CGFloat = 160

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Wider at accessibility text sizes, so titles have room.
    private var shownWidth: CGFloat { typeSize.cardWidth(width) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(playlist.artwork, placeholder: .poster(playlist.name), pixels: 500)
                .frame(width: shownWidth, height: shownWidth)
                .clipShape(.rect(cornerRadius: 8))
            Text(playlist.name)
                .font(.subheadline)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
            if let curator = playlist.curatorName {
                Text(curator)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: shownWidth, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
