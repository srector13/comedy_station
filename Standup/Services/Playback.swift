import Foundation

/// What a Play, Shuffle, Resume or bit tap asks for.
struct PlayRequest: Equatable, Sendable {
    enum Item: Equatable, Sendable {
        case album(ComedyAlbum)
        case artist(ComedyArtist)
        case playlist(ComedyPlaylist)
        /// A list of bits as they are (the App Library's Bits), under a title.
        case bits(title: String, tracks: [ComedyTrack])
    }

    var item: Item
    /// The bit to start from, in the special's track order.
    var startIndex = 0
    var shuffle = false
    /// Pick up a special where it was left off, if it was (Play / Resume);
    /// a tapped bit starts that bit instead.
    var resume = false
    /// The bit that was tapped, so its row can show it loading.
    var trackID: String?

    /// A bit tapped on its own (in search results or a list of bits from
    /// different specials): its special from that bit, or just the bit
    /// when its special isn't known.
    static func bit(_ track: ComedyTrack) -> PlayRequest {
        guard let album = track.albumStub else {
            return PlayRequest(item: .bits(title: track.title, tracks: [track]), trackID: track.id)
        }
        return PlayRequest(item: .album(album), startIndex: max((track.trackNumber ?? 1) - 1, 0), trackID: track.id)
    }
}

/// Plays a queue of bits. The live engine wraps MusicKit's
/// `ApplicationMusicPlayer` (`MusicKitPlaybackEngine`); the mock one runs a
/// clock, for previews, tests and CI.
@MainActor
protocol PlaybackEngine: AnyObject {
    /// Replaces the queue with `tracks`, in order, ready at `startIndex`
    /// and `position` seconds into it. Doesn't start playing.
    func load(_ tracks: [ComedyTrack], startIndex: Int, position: TimeInterval) async throws
    func play() async throws
    func pause()
    /// Moves to another bit in the loaded queue, at its start.
    func skip(toIndex index: Int) async throws
    /// Seconds into the current bit.
    var playbackTime: TimeInterval { get set }
    var rate: Float { get set }
    var isPlaying: Bool { get }
    /// The bit playing now, by song ID.
    var currentTrackID: String? { get }
    /// Whether `rate` does anything (Spotify has no speed for music).
    var supportsRate: Bool { get }
}

extension PlaybackEngine {
    var supportsRate: Bool { true }
}

enum PlaybackError: LocalizedError {
    case nothingToPlay

    var errorDescription: String? {
        switch self {
        case .nothingToPlay: "There's nothing to play here."
        }
    }
}

/// Where a special was left off, as the player saves it.
struct ProgressSnapshot: Equatable, Sendable {
    var itemID: String
    var isAlbum: Bool
    var lastTrackIndex: Int
    var lastPosition: TimeInterval
    var lastPlayed: Date
    var finished: Bool
    /// 0...1 through the whole set.
    var fractionComplete: Double
    var title: String
    var artistName: String
    var artwork: ArtworkRef
    var trackCount: Int
    /// The whole set's length.
    var totalDuration: TimeInterval = 0

    /// Time left in the set.
    var remaining: TimeInterval {
        max(totalDuration * (1 - fractionComplete), 0)
    }
}

/// Saved progress, by special. The App Library (`LibraryStore`) keeps it in
/// SwiftData; tests use `MemoryProgressStore`.
@MainActor
protocol ProgressStoring: AnyObject {
    func progress(for itemID: String) -> ProgressSnapshot?
    func saveProgress(_ snapshot: ProgressSnapshot)
}

extension ProgressSnapshot {
    /// The special to resume, as far as saved progress knows it; the player
    /// re-loads (and re-checks) it from the catalog.
    var albumStub: ComedyAlbum {
        ComedyAlbum(id: itemID, title: title, artistName: artistName, artwork: artwork, trackCount: trackCount, genreNames: [])
    }
}
