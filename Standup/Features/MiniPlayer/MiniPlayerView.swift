import SwiftUI

/// The bar above the tabs, as in Music: the bit playing, play/pause and
/// +15 seconds. Tapping it opens Now Playing, zooming from the bar.
struct MiniPlayerView: View {
    let namespace: Namespace.ID

    @Environment(PlayerService.self) private var player
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        let track = player.currentTrack
        HStack(spacing: 4) {
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

            // Full-size tap areas: the symbols alone are small targets.
            Button {
                Task { await player.togglePlayPause() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .font(.title3)
            .disabled(track == nil)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            .accessibilityIdentifier("miniPlayer.playPause")

            if placement != .inline {
                Button {
                    Task { await player.skip(by: PlayerService.skipInterval) }
                } label: {
                    Image(systemName: "goforward.15")
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .font(.title3)
                .disabled(track == nil)
                .accessibilityLabel("Skip Forward 15 Seconds")
                .accessibilityIdentifier("miniPlayer.forward15")
            }
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        // The accessory's height is fixed, as the tab bar's is.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .matchedTransitionSource(id: "nowPlaying", in: namespace)
    }
}
