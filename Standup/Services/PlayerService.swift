import Foundation
import Observation

/// The app's player: what's loaded, where it is, and how fast. It drives a
/// `PlaybackEngine` (MusicKit's `ApplicationMusicPlayer` on device) and saves
/// where each special was left off, so Play picks the set back up.
@MainActor
@Observable
final class PlayerService {
    /// What's loaded.
    struct Session: Equatable {
        enum Kind: Equatable {
            /// A special, played as one continuous set.
            case special(ComedyAlbum)
            /// A mix of bits (a comedian's top bits, shuffled).
            case bits(title: String)
        }

        var kind: Kind
        /// In play order.
        var tracks: [ComedyTrack]
        /// The special's ID, under which progress is saved; nil for a mix,
        /// which doesn't resume.
        var progressID: String?
        /// The bits in their own order while shuffled; nil when in order.
        var unshuffled: [ComedyTrack]?

        var isShuffled: Bool { unshuffled != nil }

        var album: ComedyAlbum? {
            if case .special(let album) = kind { album } else { nil }
        }

        var title: String {
            switch kind {
            case .special(let album): album.title
            case .bits(let title): title
            }
        }
    }

    static let rates: [Float] = [0.75, 1, 1.25, 1.5, 2]
    static let skipInterval: TimeInterval = 15
    static let saveInterval: TimeInterval = 10
    /// A special counts as finished within this many seconds of its end.
    static let finishedThreshold: TimeInterval = 30

    private(set) var session: Session?
    private(set) var index = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var rate: Float = 1
    var errorMessage: String?
    var showsNowPlaying = false
    /// Bumped on every save, so views showing Resume redraw.
    private(set) var progressRevision = 0

    @ObservationIgnored private let engine: any PlaybackEngine
    @ObservationIgnored private let catalog: any CatalogProviding
    @ObservationIgnored private let progressStore: (any ProgressStoring)?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var lastSave = Date.distantPast
    /// The clock, so tests can move time.
    @ObservationIgnored var now: () -> Date = { .now }

    init(engine: any PlaybackEngine, catalog: any CatalogProviding, progressStore: (any ProgressStoring)?) {
        self.engine = engine
        self.catalog = catalog
        self.progressStore = progressStore
    }

    // MARK: State for the UI

    var currentTrack: ComedyTrack? {
        guard let session, session.tracks.indices.contains(index) else { return nil }
        return session.tracks[index]
    }

    var upNext: [ComedyTrack] {
        guard let session else { return [] }
        return Array(session.tracks.dropFirst(index + 1))
    }

    /// The current bit's length.
    var duration: TimeInterval {
        currentTrack?.duration ?? 0
    }

    var artwork: ArtworkRef? {
        session?.album?.artwork ?? currentTrack?.artwork
    }

    /// 0...1 through the whole set.
    var setFraction: Double {
        guard let session else { return 0 }
        let total = session.tracks.compactMap(\.duration).reduce(0, +)
        guard total > 0 else { return 0 }
        let before = session.tracks.prefix(index).compactMap(\.duration).reduce(0, +)
        return min(max((before + elapsed) / total, 0), 1)
    }

    /// Where Play would resume this special, if it was left partway.
    func resumePoint(for albumID: String) -> ProgressSnapshot? {
        _ = progressRevision
        guard let saved = progressStore?.progress(for: albumID), !saved.finished,
              saved.lastTrackIndex > 0 || saved.lastPosition > 1
        else { return nil }
        return saved
    }

    // MARK: Starting

    func handle(_ request: PlayRequest) async {
        switch request.item {
        case .album(let album):
            await play(album: album, startIndex: request.startIndex, shuffle: request.shuffle, resume: request.resume)
        case .artist(let artist):
            await play(artist: artist, shuffle: request.shuffle)
        case .playlist(let playlist):
            await play(playlist: playlist, startIndex: request.startIndex, shuffle: request.shuffle)
        }
    }

    /// A playlist's bits (the comedy ones), from `startIndex` or shuffled.
    /// Playlists don't resume.
    func play(playlist: ComedyPlaylist, startIndex: Int = 0, shuffle: Bool = false) async {
        await run {
            let detail = try await catalog.playlist(id: playlist.id)
            var tracks = detail.tracks
            guard !tracks.isEmpty else { throw PlaybackError.nothingToPlay }
            var start = min(max(startIndex, 0), tracks.count - 1)
            if shuffle {
                tracks.shuffle()
                start = 0
            }
            let session = Session(kind: .bits(title: detail.playlist.name), tracks: tracks, unshuffled: shuffle ? detail.tracks : nil)
            try await begin(session, at: start, position: 0, autoplay: true)
        }
    }

    /// Plays a special as one set: from `startIndex`, shuffled, or (with
    /// `resume`) from where it was left off.
    func play(album: ComedyAlbum, startIndex: Int = 0, shuffle: Bool = false, resume: Bool = false, position: TimeInterval = 0, autoplay: Bool = true) async {
        await run {
            try await begin(album, startIndex: startIndex, shuffle: shuffle, resume: resume, position: position, autoplay: autoplay)
        }
    }

    /// Play: the comedian's latest special (resuming it). Shuffle: their top
    /// bits, mixed.
    func play(artist: ComedyArtist, shuffle: Bool) async {
        await run {
            let detail = try await catalog.artist(id: artist.id)
            if shuffle {
                let bits = detail.topBits.shuffled()
                guard !bits.isEmpty else { throw PlaybackError.nothingToPlay }
                let session = Session(kind: .bits(title: "\(detail.artist.name): Top Bits"), tracks: bits, unshuffled: detail.topBits)
                try await begin(session, at: 0, position: 0, autoplay: true)
            } else {
                guard let special = detail.featured ?? detail.specials.first else { throw PlaybackError.nothingToPlay }
                try await begin(special, startIndex: 0, shuffle: false, resume: true, position: 0, autoplay: true)
            }
        }
    }

    private func begin(_ album: ComedyAlbum, startIndex: Int, shuffle: Bool, resume: Bool, position: TimeInterval, autoplay: Bool) async throws {
        let detail = try await catalog.album(id: album.id)
        var tracks = detail.tracks
        guard !tracks.isEmpty else { throw PlaybackError.nothingToPlay }
        var start = min(max(startIndex, 0), tracks.count - 1)
        var seconds = position
        if shuffle {
            tracks.shuffle()
            start = 0
            seconds = 0
        } else if resume, let saved = resumePoint(for: album.id), saved.lastTrackIndex < tracks.count {
            start = saved.lastTrackIndex
            seconds = saved.lastPosition
        }
        let session = Session(kind: .special(detail.album), tracks: tracks, progressID: album.id, unshuffled: shuffle ? detail.tracks : nil)
        try await begin(session, at: start, position: seconds, autoplay: autoplay)
    }

    private func begin(_ session: Session, at index: Int, position: TimeInterval, autoplay: Bool) async throws {
        saveProgress()
        try await engine.load(session.tracks, startIndex: index, position: position)
        self.session = session
        self.index = index
        elapsed = position
        engine.rate = rate
        if autoplay {
            try await engine.play()
            engine.rate = rate
        }
        isPlaying = engine.isPlaying
        startTicker()
        saveProgress()
    }

    private func run(_ work: () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Controls

    func togglePlayPause() async {
        if isPlaying {
            pause()
        } else {
            await resumePlayback()
        }
    }

    func pause() {
        engine.pause()
        sync()
        isPlaying = false
        saveProgress()
    }

    func resumePlayback() async {
        guard session != nil else { return }
        await run {
            try await engine.play()
            engine.rate = rate
            isPlaying = engine.isPlaying
        }
    }

    /// ±15 seconds. Past the end of a bit goes on to the next one.
    func skip(by seconds: TimeInterval) async {
        let target = elapsed + seconds
        if target >= duration, duration > 0, let session, index + 1 < session.tracks.count {
            await jump(to: index + 1)
        } else {
            seek(to: target)
        }
    }

    func seek(to time: TimeInterval) {
        guard session != nil else { return }
        let clamped = min(max(time, 0), max(duration - 1, 0))
        engine.playbackTime = clamped
        elapsed = clamped
    }

    func next() async {
        guard let session, index + 1 < session.tracks.count else { return }
        await jump(to: index + 1)
    }

    /// Back to the start of the bit, or to the bit before when already
    /// near its start, as in Music.
    func previous() async {
        if elapsed > 3 || index == 0 {
            seek(to: 0)
        } else {
            await jump(to: index - 1)
        }
    }

    /// Plays another bit of the loaded set (Up Next).
    func jump(to newIndex: Int) async {
        guard let session, session.tracks.indices.contains(newIndex) else { return }
        await run {
            try await engine.skip(toIndex: newIndex)
            index = newIndex
            elapsed = 0
            engine.rate = rate
            saveProgress()
        }
    }

    /// Whether the loaded bits play shuffled.
    var isShuffled: Bool {
        session?.isShuffled ?? false
    }

    /// The player's shuffle switch. On: the bit playing carries on and the
    /// rest of the set is mixed. Off: back to the set's own order, at the
    /// same bit. A special doesn't save its place while shuffled.
    func setShuffle(_ on: Bool) async {
        guard var session, on != session.isShuffled, session.tracks.indices.contains(index) else { return }
        saveProgress()
        let newIndex: Int
        if on {
            var rest = session.tracks
            let current = rest.remove(at: index)
            session.unshuffled = session.tracks
            session.tracks = [current] + rest.shuffled()
            newIndex = 0
        } else {
            let current = session.tracks[index]
            session.tracks = session.unshuffled ?? session.tracks
            session.unshuffled = nil
            newIndex = session.tracks.firstIndex(of: current) ?? 0
        }
        let position = elapsed
        let wasPlaying = isPlaying
        await run {
            try await engine.load(session.tracks, startIndex: newIndex, position: position)
            self.session = session
            index = newIndex
            elapsed = position
            engine.rate = rate
            if wasPlaying {
                try await engine.play()
                engine.rate = rate
            }
            isPlaying = engine.isPlaying
            saveProgress()
        }
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        engine.rate = newRate
    }

    /// `rate` as a binding target (the speed menu).
    var playbackRate: Float {
        get { rate }
        set { setRate(newValue) }
    }

    /// `errorMessage` as an alert's presentation binding.
    var showsError: Bool {
        get { errorMessage != nil }
        set { if !newValue { errorMessage = nil } }
    }

    // MARK: Following the engine

    /// Reads the engine (time, playing, which bit) and saves progress every
    /// `saveInterval` seconds. Runs twice a second while something's loaded.
    func sync() {
        guard let session else { return }
        elapsed = engine.playbackTime
        isPlaying = engine.isPlaying
        if let id = engine.currentTrackID, id != currentTrack?.id,
           let newIndex = session.tracks.firstIndex(where: { $0.id == id }) {
            index = newIndex
            // A new entry can come back at 1×; keep the chosen speed.
            engine.rate = rate
        }
        if isPlaying, now().timeIntervalSince(lastSave) >= Self.saveInterval {
            saveProgress()
        }
    }

    private func startTicker() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                self.sync()
            }
        }
    }

    // MARK: Progress

    /// Saves where the current special is (every 10 s, on pause, on
    /// backgrounding, and before something else is loaded). Within 30 s of
    /// the end it counts as finished and starts over next time.
    func saveProgress() {
        guard let session, !session.isShuffled, let id = session.progressID, let progressStore, let album = session.album else { return }
        let isLastBit = index == session.tracks.count - 1
        let finished = isLastBit && duration > 0 && duration - elapsed < Self.finishedThreshold
        progressStore.saveProgress(ProgressSnapshot(
            itemID: id,
            isAlbum: true,
            lastTrackIndex: finished ? 0 : index,
            lastPosition: finished ? 0 : elapsed,
            lastPlayed: now(),
            finished: finished,
            fractionComplete: finished ? 1 : setFraction,
            title: album.title,
            artistName: album.artistName,
            artwork: album.artwork,
            trackCount: session.tracks.count,
            totalDuration: session.tracks.compactMap(\.duration).reduce(0, +)
        ))
        lastSave = now()
        progressRevision += 1
    }
}
