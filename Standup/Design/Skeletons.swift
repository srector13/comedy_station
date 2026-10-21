import SwiftUI

// Gray stand-ins for Home's and Browse's sections while they load, shaped
// like what's coming, with a soft shimmer sweeping across. Each reads to
// VoiceOver as one "Loading" element.

/// A highlight that sweeps across its content's shapes, over and over.
/// Still with Reduce Motion.
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var swept = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        let band = max(proxy.size.width * 0.45, 140)
                        LinearGradient(
                            colors: [.clear, .white.opacity(colorScheme == .dark ? 0.16 : 0.55), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: band)
                        .offset(x: swept ? proxy.size.width : -band)
                    }
                    .mask { content }
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: false)) {
                    swept = true
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(Shimmer())
    }

    /// One "Loading" element for VoiceOver and UI tests, shimmering.
    func loadingPlaceholder(_ identifier: String) -> some View {
        shimmering()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading")
            .accessibilityIdentifier(identifier)
    }
}

/// A gray rounded shape standing in for text or artwork.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = 6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.quaternary)
            .frame(width: width, height: height)
    }
}

/// A shelf title's stand-in.
struct SkeletonHeader: View {
    var width: CGFloat = 170

    var body: some View {
        SkeletonBlock(width: width, height: 22)
            .padding(.horizontal, 20)
    }
}

/// A shelf of special cards (`SpecialCard`).
struct ShelfSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonHeader()
            HStack(alignment: .top, spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 160, height: 160, cornerRadius: 8)
                        SkeletonBlock(width: 120, height: 12)
                        SkeletonBlock(width: 44, height: 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }
}

/// A ranked list (`RankedGrid` of `RankedRow`s).
struct RankedSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonHeader(width: 200)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonBlock(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBlock(width: 190, height: 13)
                            SkeletonBlock(width: 110, height: 11)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A shelf of comedian bubbles (`ComedianBubble`).
struct BubbleShelfSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonHeader(width: 220)
            HStack(alignment: .top, spacing: 14) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(.quaternary)
                            .frame(width: 112, height: 112)
                        SkeletonBlock(width: 80, height: 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }
}

/// Browse's featured banner (`FeaturedBanner`).
struct BannerSkeleton: View {
    var body: some View {
        SkeletonBlock(height: 168, cornerRadius: 22)
            .padding(.horizontal, 20)
    }
}

/// Browse's Streaming Services and Decades grids.
struct CategoriesSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            VStack(alignment: .leading, spacing: 12) {
                SkeletonHeader(width: 210)
                HStack(alignment: .top, spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 8) {
                            SkeletonBlock(height: 104, cornerRadius: 20)
                            SkeletonBlock(width: 64, height: 12)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
            }
            VStack(alignment: .leading, spacing: 12) {
                SkeletonHeader(width: 120)
                HStack(spacing: 12) {
                    SkeletonBlock(height: 84, cornerRadius: 14)
                    SkeletonBlock(height: 84, cornerRadius: 14)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

/// A list of specials (`SpecialRow`s), as on a Browse list.
struct SpecialRowsSkeleton: View {
    var rows = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonBlock(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonBlock(width: 200, height: 14)
                        SkeletonBlock(width: 150, height: 11)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 34) {
            BannerSkeleton()
            CategoriesSkeleton()
            ShelfSkeleton()
            RankedSkeleton()
            BubbleShelfSkeleton()
        }
        .loadingPlaceholder("preview.loading")
    }
}
