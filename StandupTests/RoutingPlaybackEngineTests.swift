import Foundation
import Testing
@testable import Standup

/// A queue mixing services plays each run on its own engine.
@MainActor
struct RoutingPlaybackEngineTests {
    let clock = TestClock()
    let apple = MockPlaybackEngine()
    let spotify = MockPlaybackEngine()
    let routing: RoutingPlaybackEngine

    let appleBits = Array(MockData.tracks["mock-al-lower"]!.prefix(2))
    let spotifyBits = Array(MockSpotify.tracks(of: "spotify:album:mock-overbooked").prefix(2))

    init() {
        apple.now = { [clock] in clock.now }
        spotify.now = { [clock] in clock.now }
        routing = RoutingPlaybackEngine(appleMusic: apple, spotify: spotify)
    }

    @Test func runsSplitWhereTheServiceChanges() {
        let mixed = [appleBits[0], appleBits[1], spotifyBits[0], appleBits[0]]
        #expect(RoutingPlaybackEngine.runs(of: mixed) == [0..<2, 2..<3, 3..<4])
        #expect(RoutingPlaybackEngine.runs(of: appleBits) == [0..<2])
        #expect(RoutingPlaybackEngine.runs(of: []) == [])
    }

    @Test func oneServiceStaysOnItsEngine() async throws {
        try await routing.load(appleBits, startIndex: 1, position: 30)
        try await routing.play()
        #expect(routing.isPlaying)
        #expect(routing.currentTrackID == appleBits[1].id)
        #expect(routing.playbackTime == 30)
        #expect(spotify.tracks.isEmpty)
    }

    @Test func aRunThatEndsHandsOverToTheNextService() async throws {
        let mixed = [appleBits[0], spotifyBits[0], appleBits[1]]
        try await routing.load(mixed, startIndex: 0, position: 0)
        try await routing.play()
        clock.advance((appleBits[0].duration ?? 0) + 1)
        #expect(routing.isPlaying)
        await routing.handOver?.value
        #expect(routing.currentTrackID == spotifyBits[0].id)
        #expect(spotify.isPlaying)
        #expect(!apple.isPlaying)
    }

    @Test func skippingToAnotherServiceQuietsTheFirst() async throws {
        let mixed = [appleBits[0], spotifyBits[0], spotifyBits[1]]
        try await routing.load(mixed, startIndex: 0, position: 0)
        try await routing.play()
        try await routing.skip(toIndex: 2)
        #expect(!apple.isPlaying)
        #expect(spotify.isPlaying)
        #expect(routing.currentTrackID == spotifyBits[1].id)
        try await routing.skip(toIndex: 1)
        #expect(routing.currentTrackID == spotifyBits[0].id)
    }

    @Test func pausingStopsHandOvers() async throws {
        let mixed = [appleBits[0], spotifyBits[0]]
        try await routing.load(mixed, startIndex: 0, position: 0)
        try await routing.play()
        routing.pause()
        clock.advance((appleBits[0].duration ?? 0) + 1)
        #expect(!routing.isPlaying)
        #expect(routing.handOver == nil)
    }
}
