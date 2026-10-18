import SwiftUI

/// Catalog artwork, or a generated placeholder while it loads or when there
/// is none. Square unless `fill` is set; callers clip it to their shape.
struct ArtworkView: View {
    /// What the generated placeholder shows.
    enum Placeholder {
        /// A special's title, poster style.
        case poster(String)
        /// A comedian's initials.
        case monogram(String)
        case plain
    }

    let artwork: ArtworkRef
    var placeholder: Placeholder = .plain
    /// The pixel size to ask Apple Music for.
    var pixels = 300
    /// Fill the proposed frame instead of staying square (hero images).
    var fill = false

    init(_ artwork: ArtworkRef, placeholder: Placeholder = .plain, pixels: Int = 300, fill: Bool = false) {
        self.artwork = artwork
        self.placeholder = placeholder
        self.pixels = pixels
        self.fill = fill
    }

    var body: some View {
        Color.clear
            .aspectRatio(fill ? nil : 1, contentMode: .fit)
            .overlay {
                if let url = artwork.url(side: pixels) {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            GeneratedArtwork(seed: artwork.seed, placeholder: .plain)
                        }
                    }
                } else {
                    GeneratedArtwork(seed: artwork.seed, placeholder: placeholder)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

/// A gradient placeholder whose colors come from the item's seed.
struct GeneratedArtwork: View {
    let seed: UInt32
    var placeholder: ArtworkView.Placeholder = .plain

    var body: some View {
        let hue = Double(seed % 360) / 360
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.55, brightness: 0.62),
                        Color(hue: (hue + 0.09).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.28),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                switch placeholder {
                case .poster(let title):
                    VStack(alignment: .leading, spacing: 0) {
                        Image(systemName: "music.mic")
                            .font(.system(size: side * 0.14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer(minLength: 0)
                        Text(title)
                            .font(.system(size: side * 0.12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(side * 0.09)
                case .monogram(let name):
                    Text(Self.initials(name))
                        .font(.system(size: side * 0.36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                case .plain:
                    Image(systemName: "music.mic")
                        .font(.system(size: side * 0.32, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    static func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

#Preview {
    HStack {
        ArtworkView(ArtworkRef(generatedFor: "a"), placeholder: .poster("Lower Your Expectations"))
            .clipShape(.rect(cornerRadius: 8))
        ArtworkView(ArtworkRef(generatedFor: "b"), placeholder: .monogram("Maya Okafor"))
            .clipShape(.circle)
    }
    .padding()
}
