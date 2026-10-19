import SwiftUI

/// The bar above the tabs, as in Music: the bit playing, play/pause and
/// +15 seconds. Tapping it opens Now Playing, zooming from the bar.
struct MiniPlayerView: View {
    let namespace: Namespace.ID

    @Environment(PlayerService.self) private var player
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        let track = player.currentTrack
        HStack(spacing: 12) {
            Button {
                player.showsNowPlaying = true
            } label: {
                HStack(spacing: 12) {
                    Group {
                        if let artwork = player.artwork {
                            ArtworkView(artwork, placeholder: .poster(player.session?.title ?? ""), pixels: 120)
                        } else {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.quaternary)
                                .overlay {
                                    Image(systemName: "music.mic")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(.rect(cornerRadius: 6))
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(track?.title ?? "Not Playing")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(track == nil ? .secondary : .primary)
                            .lineLimit(1)
                        if let track, placement != .inline {
                            Text(track.artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(track == nil)
            .accessibilityLabel(track.map { "Now Playing: \($0.title), \($0.artistName)" } ?? "Not Playing")
            .accessibilityHint(track == nil ? "" : "Opens Now Playing")
            .accessibilityIdentifier("miniPlayer.open")

            Button(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.fill" : "play.fill") {
                Task { await player.togglePlayPause() }
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .contentTransition(.symbolEffect(.replace))
            .disabled(track == nil)
            .accessibilityIdentifier("miniPlayer.playPause")

            if placement != .inline {
                Button("Skip Forward 15 Seconds", systemImage: "goforward.15") {
                    Task { await player.skip(by: PlayerService.skipInterval) }
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .disabled(track == nil)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .matchedTransitionSource(id: "nowPlaying", in: namespace)
    }
}
