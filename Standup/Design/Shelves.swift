import SwiftUI

/// A titled horizontal shelf, Music style. With a route, its title opens
/// the whole list.
struct Shelf<Content: View>: View {
    let title: String
    var route: Route?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: title, route: route)
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

/// How far through a special: a thin bar under its artwork, as on Continue
/// Listening, so the artwork stays clear.
struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(proxy.size.width * min(max(fraction, 0), 1), 4))
                }
            }
            .frame(height: 4)
            .accessibilityElement()
            .accessibilityLabel("\(Int((fraction * 100).rounded()))% played")
    }
}

/// A special left partway: artwork, how far through, title, and time left.
/// Tapping resumes it.
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
            ProgressBar(fraction: progress.fractionComplete)
                .padding(.vertical, 4)
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
/// Without a rank (a list that isn't a chart) the number is left out.
struct RankedRow: View {
    let rank: Int?
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
            if let rank {
                Text("\(rank)")
                    .font(.headline)
                    .monospacedDigit()
                    .frame(minWidth: 18)
            }
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
        .accessibilityLabel((rank.map { "Number \($0): " } ?? "") + "\(title), \(subtitle)")
    }
}

/// A chart grid: rows in columns that scroll sideways, as in Music. On a
/// phone a column fills most of the width, with the next one peeking in;
/// wider screens show two or three columns at once.
struct RankedGrid<Item: Identifiable, Row: View>: View {
    let title: String
    var route: Route?
    let items: [Item]
    var rows = 4
    @ViewBuilder var row: (Int, Item) -> Row

    @Environment(\.dynamicTypeSize) private var typeSize

    private nonisolated static var spacing: CGFloat { 16 }

    /// A column's width in a row `length` points wide.
    nonisolated static func columnWidth(in length: CGFloat) -> CGFloat {
        let columns: CGFloat = length >= 1000 ? 3 : length >= 600 ? 2 : 1
        guard columns > 1 else { return length * 0.9 - 2 }
        return (length - spacing * (columns - 1)) / columns
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: title, route: route)
            ScrollView(.horizontal) {
                LazyHGrid(rows: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 2 : rows), spacing: Self.spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(index + 1, item)
                            .containerRelativeFrame(.horizontal) { length, _ in
                                Self.columnWidth(in: length)
                            }
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
