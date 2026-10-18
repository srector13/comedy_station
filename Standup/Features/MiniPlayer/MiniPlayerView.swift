import SwiftUI

/// The bar above the tabs, as in Music. Until playback arrives it shows
/// "Not Playing" with its controls disabled.
struct MiniPlayerView: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.quaternary)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)

            Text("Not Playing")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button("Play", systemImage: "play.fill") {}
                .labelStyle(.iconOnly)
                .font(.title3)
                .disabled(true)

            if placement != .inline {
                Button("Skip Forward 15 Seconds", systemImage: "goforward.15") {}
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .disabled(true)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("miniPlayer")
    }
}
