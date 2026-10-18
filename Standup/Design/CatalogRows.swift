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
                Text(artist.name)
                    .font(.body)
                    .lineLimit(1)
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

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 160)
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(album.title)
                        .font(.body)
                        .lineLimit(1)
                    if album.isExplicit { ExplicitBadge() }
                }
                Text(["Special", album.artistName, Format.year(album.releaseDate)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A bit in a list: artwork, title, comedian, duration.
struct BitRow: View {
    let track: ComedyTrack
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(track.artwork, placeholder: .poster(track.albumTitle ?? track.title), pixels: 160)
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)
                    if track.isExplicit { ExplicitBadge() }
                }
                Text(subtitle ?? "Bit · \(track.artistName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Format.trackTime(track.duration))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A special in a shelf or grid: artwork over title and year. A nil width
/// fills the grid cell.
struct SpecialCard: View {
    let album: ComedyAlbum
    var width: CGFloat? = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 500)
                .frame(width: width, height: width)
                .clipShape(.rect(cornerRadius: 8))
            Text(album.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let year = Format.year(album.releaseDate) {
                Text(year)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: width, alignment: .leading)
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
