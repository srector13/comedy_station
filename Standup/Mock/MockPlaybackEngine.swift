import Foundation

/// A playback engine that only keeps time: previews, tests, CI screenshots,
/// and the Simulator, where MusicKit can't play.
@MainActor
final class MockPlaybackEngine: PlaybackEngine {
    private(set) var tracks: [ComedyTrack] = []
    private(set) var index = 0
    /// Seconds into the current bit when the clock last started or stopped.
    private var anchor: TimeInterval = 0
    private var startedAt: Date?
    /// The clock, so tests can move time.
    var now: () -> Date = { .now }

    var rate: Float = 1 {
        didSet {
            // Keep the position, change the speed from here on.
            anchor = current
            if startedAt != nil { startedAt = now() }
        }
    }

    var isPlaying: Bool {
        advanceIfNeeded()
        return startedAt != nil
    }

    var currentTrackID: String? {
        advanceIfNeeded()
        return tracks.indices.contains(index) ? tracks[index].id : nil
    }

    var playbackTime: TimeInterval {
        get {
            advanceIfNeeded()
            return current
        }
        set {
            anchor = max(newValue, 0)
            if startedAt != nil { startedAt = now() }
        }
    }

    func load(_ tracks: [ComedyTrack], startIndex: Int, position: TimeInterval) async throws {
        guard tracks.indices.contains(startIndex) else { throw PlaybackError.nothingToPlay }
        self.tracks = tracks
        index = startIndex
        anchor = position
        startedAt = nil
    }

    func play() async throws {
        guard !tracks.isEmpty else { throw PlaybackError.nothingToPlay }
        if startedAt == nil { startedAt = now() }
    }

    func pause() {
        anchor = current
        startedAt = nil
    }

    func skip(toIndex index: Int) async throws {
        guard tracks.indices.contains(index) else { throw PlaybackError.nothingToPlay }
        self.index = index
        anchor = 0
        if startedAt != nil { startedAt = now() }
    }

    private var current: TimeInterval {
        anchor + (startedAt.map { now().timeIntervalSince($0) * Double(rate) } ?? 0)
    }

    /// Rolls on to the next bit when the current one runs out; stops after
    /// the last.
    private func advanceIfNeeded() {
        guard startedAt != nil else { return }
        while tracks.indices.contains(index), let length = tracks[index].duration, current >= length {
            let overflow = current - length
            if index + 1 < tracks.count {
                index += 1
                anchor = overflow
                startedAt = now()
            } else {
                anchor = length
                startedAt = nil
                return
            }
        }
    }
}

/// Saved progress in memory, for tests.
@MainActor
final class MemoryProgressStore: ProgressStoring {
    private(set) var saved: [String: ProgressSnapshot] = [:]

    func progress(for itemID: String) -> ProgressSnapshot? {
        saved[itemID]
    }

    func saveProgress(_ snapshot: ProgressSnapshot) {
        saved[snapshot.itemID] = snapshot
    }
}
