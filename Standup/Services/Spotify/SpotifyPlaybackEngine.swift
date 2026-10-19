import Foundation
@preconcurrency import SpotifyiOS

/// Spotify playback, which happens in the Spotify app: Standup drives it
/// through the Spotify iOS SDK's App Remote (hard rule 2), the only code
/// that imports the SDK (scripts/audit_no_library_writes.sh checks).
///
/// - A queue that is one special in order plays as that album, so Spotify
///   carries on from bit to bit by itself. Anything else (a shuffle, the
///   App Library's bits) plays a bit at a time, and the next is started
///   when Spotify moves off the last one.
/// - When the Spotify app isn't running, the SDK wakes it (a quick switch
///   to Spotify and back).
/// - No speed control: App Remote only has it for podcasts.
/// - Nothing is ever saved to the Spotify library (rule 1).
@MainActor
final class SpotifyPlaybackEngine: NSObject, PlaybackEngine {
    private let account: SpotifyAccount
    private var remote: SPTAppRemote?
    /// Waiting for App Remote to connect (or for the Spotify app to call back).
    private var connection: CheckedContinuation<Void, any Error>?

    private var queue: [ComedyTrack] = []
    private var index = 0
    private var startPosition: TimeInterval = 0
    private var needsStart = false
    /// The special the queue plays through in order, if it does.
    private var albumURI: String?

    /// Spotify's latest player state, and when it came.
    private var stateTrack: String?
    private var statePosition: TimeInterval = 0
    private var statePaused = true
    private var stateTime = Date.distantPast

    init(account: SpotifyAccount) {
        self.account = account
    }

    var supportsRate: Bool { false }

    // MARK: Loading and playing

    func load(_ tracks: [ComedyTrack], startIndex: Int, position: TimeInterval) async throws {
        guard tracks.indices.contains(startIndex) else { throw PlaybackError.nothingToPlay }
        queue = tracks
        index = startIndex
        startPosition = position
        needsStart = true
        albumURI = Self.albumInOrder(tracks)
        stateTrack = tracks[startIndex].id
        statePosition = position
        statePaused = true
        stateTime = .now
    }

    /// The album a queue plays straight through, if it is one in its order.
    static func albumInOrder(_ tracks: [ComedyTrack]) -> String? {
        guard let album = tracks.first?.albumID,
              tracks.allSatisfy({ $0.albumID == album && $0.trackNumber != nil }),
              tracks.map({ $0.trackNumber ?? 0 }) == tracks.map({ $0.trackNumber ?? 0 }).sorted()
        else { return nil }
        return album
    }

    func play() async throws {
        let firstURI = needsStart ? queue[index].id : nil
        try await connect(waking: firstURI)
        guard let player = remote?.playerAPI else { throw SpotifyError.notConnected }
        if needsStart {
            needsStart = false
            try await start(at: index, player: player)
            if startPosition > 0 {
                try await call { player.seek(toPosition: Int(self.startPosition * 1000), callback: $0) }
            }
        } else {
            try await call { player.resume($0) }
        }
        statePaused = false
        stateTime = .now
    }

    private func start(at index: Int, player: any SPTAppRemotePlayerAPI) async throws {
        let track = queue[index]
        if let albumURI, let content = remote?.contentAPI, let number = track.trackNumber {
            // The album, from this bit.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                content.fetchContentItem(forURI: albumURI) { result, error in
                    guard let item = result as? SPTAppRemoteContentItem else {
                        continuation.resume(throwing: error ?? PlaybackError.nothingToPlay)
                        return
                    }
                    player.play(item, skipToTrackIndex: number - 1) { _, error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
            }
        } else {
            try await call { player.play(track.id, callback: $0) }
        }
        stateTrack = track.id
        statePosition = 0
        stateTime = .now
    }

    func pause() {
        remote?.playerAPI?.pause(nil)
        statePosition = playbackTime
        statePaused = true
        stateTime = .now
    }

    func skip(toIndex newIndex: Int) async throws {
        guard queue.indices.contains(newIndex) else { throw PlaybackError.nothingToPlay }
        index = newIndex
        if needsStart {
            startPosition = 0
            stateTrack = queue[newIndex].id
            return
        }
        guard let player = remote?.playerAPI else { throw SpotifyError.notConnected }
        try await start(at: newIndex, player: player)
    }

    var playbackTime: TimeInterval {
        get {
            statePaused ? statePosition : statePosition + Date.now.timeIntervalSince(stateTime)
        }
        set {
            remote?.playerAPI?.seek(toPosition: Int(newValue * 1000), callback: nil)
            statePosition = newValue
            stateTime = .now
            if needsStart { startPosition = newValue }
        }
    }

    var rate: Float {
        get { 1 }
        set {}
    }

    var isPlaying: Bool { !statePaused }

    var currentTrackID: String? { stateTrack }

    // MARK: Connecting

    private func makeRemote() throws -> SPTAppRemote {
        if let remote { return remote }
        guard let clientID = account.clientID, let redirect = URL(string: SpotifyAuth.redirectURI) else { throw SpotifyError.notConnected }
        let remote = SPTAppRemote(configuration: SPTConfiguration(clientID: clientID, redirectURL: redirect), logLevel: .error)
        remote.delegate = self
        self.remote = remote
        return remote
    }

    /// Connects to the Spotify app, waking it (playing `uri`) if it isn't
    /// running.
    private func connect(waking uri: String?) async throws {
        let remote = try makeRemote()
        guard !remote.isConnected else { return }
        remote.connectionParameters.accessToken = try await account.validToken()
        do {
            try await withCheckedThrowingContinuation { continuation in
                connection = continuation
                remote.connect()
            }
        } catch {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                connection = continuation
                remote.authorizeAndPlayURI(uri ?? "") { [weak self] installed in
                    guard !installed else { return }
                    Task { @MainActor in
                        self?.finishConnecting(throwing: SpotifyPlaybackError.notInstalled)
                    }
                }
            }
        }
    }

    /// The Spotify app's call back after waking (`standup://spotify-callback`).
    /// Returns whether the URL was Spotify's.
    func handle(_ url: URL) -> Bool {
        guard let remote, let parameters = remote.authorizationParameters(from: url) else { return false }
        if let token = parameters[SPTAppRemoteAccessTokenKey] {
            remote.connectionParameters.accessToken = token
            remote.connect()
        } else {
            finishConnecting(throwing: SpotifyPlaybackError.refused(parameters[SPTAppRemoteErrorDescriptionKey] ?? "unknown"))
        }
        return true
    }

    private func finishConnecting(throwing error: (any Error)? = nil) {
        guard let connection else { return }
        self.connection = nil
        if let error { connection.resume(throwing: error) } else { connection.resume() }
    }

    private func call(_ body: (@escaping SPTAppRemoteCallback) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            body { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    // MARK: Following Spotify

    private func follow(trackURI: String, position: TimeInterval, paused: Bool) {
        let previous = stateTrack
        stateTrack = trackURI
        statePosition = position
        statePaused = paused
        stateTime = .now
        let ours = queue.map(\.id)
        guard !paused, !ours.contains(trackURI), let previous, let last = ours.firstIndex(of: previous) else {
            if let found = ours.firstIndex(of: trackURI) { index = found }
            return
        }
        // Spotify moved past our bit to something of its own (autoplay).
        if albumURI == nil, last + 1 < queue.count {
            let next = last + 1
            index = next
            Task {
                guard let player = self.remote?.playerAPI else { return }
                try? await self.start(at: next, player: player)
            }
        } else {
            remote?.playerAPI?.pause(nil)
            stateTrack = previous
            statePaused = true
        }
    }
}

enum SpotifyPlaybackError: LocalizedError {
    case notInstalled
    case refused(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: "Playing from Spotify needs the Spotify app."
        case .refused(let reason): "The Spotify app didn't connect (\(reason))."
        }
    }
}

extension SpotifyPlaybackEngine: @preconcurrency SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: nil)
        finishConnecting()
    }

    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: (any Error)?) {
        finishConnecting(throwing: error ?? SpotifyError.notConnected)
    }

    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: (any Error)?) {
        statePaused = true
    }
}

extension SpotifyPlaybackEngine: @preconcurrency SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: any SPTAppRemotePlayerState) {
        follow(trackURI: playerState.track.uri, position: TimeInterval(playerState.playbackPosition) / 1000, paused: playerState.isPaused)
    }
}
