import Foundation

/// Plays a queue that can mix services (the App Library's Bits): each run
/// of consecutive bits from one service goes to that service's engine, and
/// when a run plays out the next one starts on its engine. A queue from a
/// single service, which is most of them, is one run.
@MainActor
final class RoutingPlaybackEngine: PlaybackEngine {
    private let engines: [Provider: any PlaybackEngine]
    private var tracks: [ComedyTrack] = []
    private var runs: [Range<Int>] = []
    private var run = 0
    /// Whether the person wants sound, so a run that ends hands over.
    private var shouldPlay = false
    /// The hand-over to the next run, while it's under way (and for tests).
    private(set) var handOver: Task<Void, Never>?

    init(appleMusic: any PlaybackEngine, spotify: any PlaybackEngine) {
        engines = [.appleMusic: appleMusic, .spotify: spotify]
    }

    /// Consecutive bits from the same service.
    static func runs(of tracks: [ComedyTrack]) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        var start = 0
        for index in tracks.indices.dropFirst() where Provider.of(tracks[index].id) != Provider.of(tracks[index - 1].id) {
            runs.append(start..<index)
            start = index
        }
        if !tracks.isEmpty {
            runs.append(start..<tracks.count)
        }
        return runs
    }

    private func engine(forRun run: Int) -> any PlaybackEngine {
        engines[Provider.of(tracks[runs[run].lowerBound].id)]!
    }

    private var active: (any PlaybackEngine)? {
        runs.indices.contains(run) ? engine(forRun: run) : nil
    }

    private func run(containing index: Int) -> Int? {
        runs.firstIndex { $0.contains(index) }
    }

    /// Loads a run into its engine at `index`, quieting the other engine.
    private func start(run newRun: Int, at index: Int, position: TimeInterval, playing: Bool) async throws {
        let next = engine(forRun: newRun)
        if let previous = active, previous !== next, previous.isPlaying {
            previous.pause()
        }
        run = newRun
        let range = runs[newRun]
        try await next.load(Array(tracks[range]), startIndex: index - range.lowerBound, position: position)
        if playing {
            try await next.play()
        }
    }

    // MARK: PlaybackEngine

    func load(_ tracks: [ComedyTrack], startIndex: Int, position: TimeInterval) async throws {
        let oldActive = active
        self.tracks = tracks
        runs = Self.runs(of: tracks)
        handOver?.cancel()
        handOver = nil
        guard let first = run(containing: startIndex) else { throw PlaybackError.nothingToPlay }
        if let oldActive, oldActive !== engine(forRun: first), oldActive.isPlaying {
            oldActive.pause()
        }
        run = first
        try await start(run: first, at: startIndex, position: position, playing: false)
    }

    func play() async throws {
        shouldPlay = true
        try await active?.play()
    }

    func pause() {
        shouldPlay = false
        active?.pause()
    }

    func skip(toIndex index: Int) async throws {
        guard let target = run(containing: index) else { throw PlaybackError.nothingToPlay }
        if target == run, let active {
            try await active.skip(toIndex: index - runs[target].lowerBound)
        } else {
            try await start(run: target, at: index, position: 0, playing: shouldPlay)
        }
    }

    var playbackTime: TimeInterval {
        get { active?.playbackTime ?? 0 }
        set { active?.playbackTime = newValue }
    }

    var rate: Float {
        get { active?.rate ?? 1 }
        set { active?.rate = newValue }
    }

    var isPlaying: Bool {
        handOverIfRunEnded()
        return (active?.isPlaying ?? false) || handOver != nil
    }

    var currentTrackID: String? {
        handOverIfRunEnded()
        return active?.currentTrackID
    }

    var supportsRate: Bool {
        active?.supportsRate ?? true
    }

    /// When a run has played to its end, the next one starts on its engine.
    private func handOverIfRunEnded() {
        guard shouldPlay, handOver == nil, run + 1 < runs.count, let active, !active.isPlaying else { return }
        let last = tracks[runs[run].upperBound - 1]
        guard active.currentTrackID == nil || active.currentTrackID == last.id else { return }
        // Stopped on the last bit before its end is a pause, not the end.
        if active.currentTrackID != nil, let length = last.duration, active.playbackTime < length - 2 { return }
        let next = run + 1
        let start = runs[next].lowerBound
        handOver = Task { [weak self] in
            guard let self else { return }
            try? await self.start(run: next, at: start, position: 0, playing: true)
            self.handOver = nil
        }
    }
}
