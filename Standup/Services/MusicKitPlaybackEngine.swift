import Foundation
@preconcurrency import MusicKit

/// Playback through MusicKit's `ApplicationMusicPlayer`: the only code in
/// the app that touches a music player (scripts/audit_no_library_writes.sh
/// checks). Never the system player (hard rule 2), and every queue is built
/// with `affectsListeningHistory = false`, so comedy stays out of Music's
/// Recently Played, recommendations and Replay.
@MainActor
final class MusicKitPlaybackEngine: PlaybackEngine {
    private let player = ApplicationMusicPlayer.shared
    /// The bits asked for, by song ID, in the player service's order (so
    /// its indices hold even if a song has left the catalog).
    private var trackIDs: [String] = []

    func load(_ tracks: [ComedyTrack], startIndex: Int, position: TimeInterval) async throws {
        guard tracks.indices.contains(startIndex) else { throw PlaybackError.nothingToPlay }
        // Re-load the songs from the catalog by ID, a hundred at a time (a
        // whole library of bits can pass the API's limit), then queue them
        // in the order asked for (a special's order, or shuffled).
        let ids = tracks.map { MusicItemID($0.id) }
        var found: [Song] = []
        for start in stride(from: 0, to: ids.count, by: 100) {
            let batch = Array(ids[start..<min(start + 100, ids.count)])
            found += try await MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: batch).response().items
        }
        let byID = Dictionary(found.map { ($0.id.rawValue, $0) }, uniquingKeysWith: { first, _ in first })
        let songs = tracks.compactMap { byID[$0.id] }
        guard !songs.isEmpty else { throw PlaybackError.nothingToPlay }

        player.queue = makeQueue(songs, startingAt: byID[tracks[startIndex].id] ?? songs[0])
        trackIDs = tracks.map(\.id)
        try await player.prepareToPlay()
        if position > 0 {
            player.playbackTime = position
        }
    }

    /// The one place a queue is made.
    private func makeQueue(_ songs: [Song], startingAt start: Song) -> ApplicationMusicPlayer.Queue {
        let queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: start)
        queue.affectsListeningHistory = false
        return queue
    }

    func play() async throws {
        try await player.play()
    }

    func pause() {
        player.pause()
    }

    func skip(toIndex index: Int) async throws {
        guard trackIDs.indices.contains(index) else { throw PlaybackError.nothingToPlay }
        let id = trackIDs[index]
        guard let entry = player.queue.entries.first(where: { $0.item?.id.rawValue == id }) else {
            throw PlaybackError.nothingToPlay
        }
        let wasPlaying = isPlaying
        player.queue.currentEntry = entry
        if wasPlaying {
            try await player.play()
        }
    }

    var playbackTime: TimeInterval {
        get { player.playbackTime }
        set { player.playbackTime = newValue }
    }

    var rate: Float {
        get { player.state.playbackRate }
        set {
            // Setting the rate while paused would start playback.
            if isPlaying, player.state.playbackRate != newValue {
                player.state.playbackRate = newValue
            }
        }
    }

    var isPlaying: Bool {
        player.state.playbackStatus == .playing
    }

    var currentTrackID: String? {
        player.queue.currentEntry?.item?.id.rawValue
    }
}
