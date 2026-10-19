import SwiftUI

/// Now Playing, Music style, over a background tinted from the artwork: the
/// bit, a scrubber, ±15 s skips (comedy timing beats track skips), speed,
/// and Up Next. Side by side in landscape.
struct NowPlayingView: View {
    @Environment(PlayerService.self) private var player
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsUpNext = false

    var body: some View {
        Group {
            if let track = player.currentTrack, let session = player.session {
                if verticalSizeClass == .compact {
                    landscape(track, session)
                } else {
                    portrait(track, session)
                }
            } else {
                ContentUnavailableView("Nothing Playing", systemImage: "music.mic")
            }
        }
        // Light text and dark controls on the tinted background, as in Music.
        .environment(\.colorScheme, .dark)
        .presentationDragIndicator(.visible)
        .presentationBackground {
            NowPlayingBackground(tint: (player.artwork ?? ArtworkRef()).tint)
        }
    }

    // MARK: Layouts

    private func portrait(_ track: ComedyTrack, _ session: PlayerService.Session) -> some View {
        VStack(spacing: 22) {
            if showsUpNext {
                compactHeader(track, session)
                UpNextList()
            } else {
                Spacer(minLength: 8)
                artwork(session)
                Spacer(minLength: 8)
                titleRow(track, session)
            }
            Scrubber(elapsed: player.elapsed, duration: player.duration) { player.seek(to: $0) }
            TransportControls()
            bottomBar
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 16)
    }

    private func landscape(_ track: ComedyTrack, _ session: PlayerService.Session) -> some View {
        HStack(spacing: 36) {
            Group {
                if showsUpNext {
                    UpNextList()
                } else {
                    artwork(session)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 16) {
                Spacer(minLength: 0)
                titleRow(track, session)
                Scrubber(elapsed: player.elapsed, duration: player.duration) { player.seek(to: $0) }
                TransportControls()
                bottomBar
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 20)
    }

    // MARK: Pieces

    private func artwork(_ session: PlayerService.Session) -> some View {
        ArtworkView(player.artwork ?? ArtworkRef(), placeholder: .poster(session.title), pixels: 1200)
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: .black.opacity(0.4), radius: 24, y: 14)
            // Music shrinks the artwork while paused.
            .scaleEffect(player.isPlaying ? 1 : 0.86)
            .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.25), value: player.isPlaying)
            .frame(maxWidth: 380)
            .accessibilityHidden(true)
    }

    private func subtitle(_ track: ComedyTrack, _ session: PlayerService.Session) -> String {
        [track.artistName, track.albumTitle ?? session.title].joined(separator: " — ")
    }

    private func titleRow(_ track: ComedyTrack, _ session: PlayerService.Session) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.title3.bold())
                    .lineLimit(1)
                    .accessibilityIdentifier("nowPlaying.title")
                Text(subtitle(track, session))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let album = session.album {
                LibraryToolbarButton(item: .special(album))
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }
        }
    }

    private func compactHeader(_ track: ComedyTrack, _ session: PlayerService.Session) -> some View {
        HStack(spacing: 14) {
            ArtworkView(player.artwork ?? ArtworkRef(), placeholder: .poster(session.title), pixels: 240)
                .frame(width: 64, height: 64)
                .clipShape(.rect(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                    // Stands in for the title row while Up Next is open.
                    .accessibilityIdentifier("nowPlaying.title")
                Text(subtitle(track, session))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if player.supportsSpeed {
                SpeedMenu()
            } else {
                Text("Playing in Spotify")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("nowPlaying.spotify")
            }
            Spacer()
            ShuffleButton()
            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.35)) { showsUpNext.toggle() }
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(showsUpNext ? AnyShapeStyle(.white.opacity(0.22)) : AnyShapeStyle(.clear), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Up Next")
            .accessibilityAddTraits(showsUpNext ? .isSelected : [])
            .accessibilityIdentifier("nowPlaying.upNext")
        }
    }
}

/// The artwork's color, darkening to the bottom.
struct NowPlayingBackground: View {
    let tint: Color

    var body: some View {
        LinearGradient(colors: [tint, tint.mix(with: .black, by: 0.6)], startPoint: .top, endPoint: .bottom)
            .overlay(Color.black.opacity(0.12))
            .ignoresSafeArea()
    }
}

/// The position in the bit: drag to seek; thickens while dragging, as in
/// Music. Adjustable for VoiceOver in 15-second steps.
struct Scrubber: View {
    let elapsed: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?

    private var fraction: Double {
        dragFraction ?? (duration > 0 ? min(max(elapsed / duration, 0), 1) : 0)
    }

    var body: some View {
        let shown = dragFraction.map { $0 * duration } ?? elapsed
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white.opacity(dragFraction == nil ? 0.75 : 1))
                        .frame(width: proxy.size.width * fraction)
                }
                .frame(height: dragFraction == nil ? 7 : 12)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragFraction = min(max(value.location.x / max(proxy.size.width, 1), 0), 1)
                        }
                        .onEnded { value in
                            let final = min(max(value.location.x / max(proxy.size.width, 1), 0), 1)
                            onSeek(final * duration)
                            dragFraction = nil
                        }
                )
                .animation(.easeOut(duration: 0.15), value: dragFraction == nil)
            }
            .frame(height: 24)

            HStack {
                Text(Format.trackTime(shown))
                Spacer()
                Text("-" + Format.trackTime(max(duration - shown, 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Position")
        .accessibilityValue("\(Format.trackTime(elapsed)) of \(Format.trackTime(duration))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onSeek(elapsed + PlayerService.skipInterval)
            case .decrement: onSeek(elapsed - PlayerService.skipInterval)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("nowPlaying.scrubber")
    }
}

/// Back 15 s, previous bit, play/pause, next bit, forward 15 s.
struct TransportControls: View {
    @Environment(PlayerService.self) private var player

    var body: some View {
        HStack {
            control("Back 15 Seconds", "gobackward.15", id: "back15") {
                await player.skip(by: -PlayerService.skipInterval)
            }
            Spacer()
            control("Previous Bit", "backward.fill", id: "previous") {
                await player.previous()
            }
            Spacer()
            Button {
                Task { await player.togglePlayPause() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 46))
                    .frame(width: 68, height: 68)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            .accessibilityIdentifier("nowPlaying.playPause")
            Spacer()
            control("Next Bit", "forward.fill", id: "next") {
                await player.next()
            }
            .disabled(player.upNext.isEmpty)
            Spacer()
            control("Forward 15 Seconds", "goforward.15", id: "forward15") {
                await player.skip(by: PlayerService.skipInterval)
            }
        }
        .font(.title)
        .buttonStyle(.plain)
        // Five controls in a row: past this size they'd no longer fit.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func control(_ label: String, _ symbol: String, id: String, action: @escaping @MainActor () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: symbol)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("nowPlaying.\(id)")
    }
}

/// Playback speed: 0.75× to 2×.
struct SpeedMenu: View {
    @Environment(PlayerService.self) private var player

    var body: some View {
        @Bindable var player = player
        Menu {
            Picker("Playback Speed", selection: $player.playbackRate) {
                ForEach(PlayerService.rates, id: \.self) { rate in
                    Text(Self.label(rate)).tag(rate)
                }
            }
        } label: {
            Text(Self.label(player.rate))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .padding(.horizontal, 12)
                .frame(minWidth: 52, minHeight: 32)
                .background(.white.opacity(0.16), in: .capsule)
        }
        .accessibilityLabel("Playback Speed")
        .accessibilityValue(Self.label(player.rate))
        .accessibilityIdentifier("nowPlaying.speed")
    }

    /// "1×", "1.25×", "0.75×".
    static func label(_ rate: Float) -> String {
        Double(rate).formatted(.number.precision(.fractionLength(0...2))) + "×"
    }
}

/// Shuffle on and off for what's loaded, as in Music: the bit playing
/// carries on either way.
struct ShuffleButton: View {
    @Environment(PlayerService.self) private var player

    var body: some View {
        let on = player.isShuffled
        Button {
            Task { await player.setShuffle(!on) }
        } label: {
            Image(systemName: "shuffle")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(on ? AnyShapeStyle(.white.opacity(0.22)) : AnyShapeStyle(.clear), in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(player.session == nil)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityLabel("Shuffle")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("nowPlaying.shuffle")
    }
}

/// The rest of the set; tap a bit to jump to it.
struct UpNextList: View {
    @Environment(PlayerService.self) private var player

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Up Next")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let title = player.session?.title {
                    Text("From \(title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if player.upNext.isEmpty {
                Text("This is the last bit.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(player.upNext.enumerated()), id: \.element.id) { offset, track in
                            Button {
                                Task { await player.jump(to: player.index + 1 + offset) }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(track.title)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    Text(Format.trackTime(track.duration))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 11)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Plays this bit")
                            .accessibilityIdentifier("nowPlaying.upNext.\(offset)")
                            Divider()
                                .opacity(0.4)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

extension ArtworkRef {
    /// The artwork's color: Apple Music's average color, or the generated
    /// placeholder's.
    var tint: Color {
        if let rgb = backgroundRGB {
            Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
        } else {
            Color(hue: Double(seed % 360) / 360, saturation: 0.55, brightness: 0.62)
        }
    }
}

#Preview {
    @Previewable @State var shown = true
    Color.clear
        .sheet(isPresented: $shown) {
            NowPlayingView()
        }
        .previewEnvironment()
}
