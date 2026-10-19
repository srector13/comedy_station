import Foundation
import Testing
@testable import Standup

/// A clock tests move by hand.
@MainActor
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    func advance(_ seconds: TimeInterval) {
        now += seconds
    }
}

@MainActor
struct PlayerServiceTests {
    let clock = TestClock()
    let engine = MockPlaybackEngine()
    let store = MemoryProgressStore()
    let player: PlayerService

    let special = MockData.album(id: "mock-al-lower")!
    var bits: [ComedyTrack] { MockData.tracks[special.id]! }

    init() {
        player = PlayerService(engine: engine, catalog: MockCatalog(), progressStore: store)
        engine.now = { [clock] in clock.now }
        player.now = { [clock] in clock.now }
    }

    private func advance(_ seconds: TimeInterval) {
        clock.advance(seconds)
        player.sync()
    }

    // MARK: Starting

    @Test func playStartsTheWholeSpecialAtTheTop() async {
        await player.play(album: special)
        #expect(player.session?.album?.id == special.id)
        #expect(player.session?.tracks.map(\.id) == bits.map(\.id))
        #expect(player.index == 0)
        #expect(player.currentTrack?.title == "Intro")
        #expect(player.isPlaying)
        #expect(player.upNext.count == bits.count - 1)
    }

    @Test func aTappedBitStartsThere() async {
        await player.play(album: special, startIndex: 3)
        #expect(player.index == 3)
        #expect(player.currentTrack?.id == bits[3].id)
    }

    @Test func shuffleKeepsEveryBitAndDoesNotResume() async {
        await player.play(album: special, shuffle: true)
        #expect(Set(player.session?.tracks.map(\.id) ?? []) == Set(bits.map(\.id)))
        #expect(player.session?.progressID == nil)
        player.pause()
        #expect(store.saved.isEmpty)
    }

    @Test func nonComedyIsRefused() async {
        await player.play(album: MockData.album(id: "mock-al-arena")!)
        #expect(player.session == nil)
        #expect(player.errorMessage != nil)
    }

    @Test func artistPlayStartsTheirLatestSpecial() async {
        await player.play(artist: MockData.artist(id: "mock-ar-maya")!, shuffle: false)
        #expect(player.session?.album?.title == "Lower Your Expectations")
    }

    @Test func artistShuffleMixesTheirTopBits() async {
        await player.play(artist: MockData.artist(id: "mock-ar-maya")!, shuffle: true)
        #expect(player.session?.album == nil)
        #expect(player.session?.progressID == nil)
        #expect(player.session?.title == "Maya Okafor: Top Bits")
        #expect(player.session?.tracks.allSatisfy { ComedyFilter.isComedy($0.albumGenreNames) } == true)
    }

    // MARK: Controls

    @Test func skipsFifteenSecondsEitherWay() async {
        await player.play(album: special)
        advance(30)
        #expect(player.elapsed == 30)
        await player.skip(by: 15)
        #expect(player.elapsed == 45)
        await player.skip(by: -15)
        #expect(player.elapsed == 30)
        await player.skip(by: -100)
        #expect(player.elapsed == 0)
    }

    @Test func skippingPastTheEndGoesToTheNextBit() async {
        await player.play(album: special)
        player.seek(to: player.duration - 5)
        await player.skip(by: 15)
        #expect(player.index == 1)
        #expect(player.elapsed == 0)
    }

    @Test func followsTheEngineToTheNextBit() async {
        await player.play(album: special)
        advance((bits[0].duration ?? 0) + 5)
        #expect(player.index == 1)
        #expect(abs(player.elapsed - 5) < 0.01)
    }

    @Test func speedScalesTime() async {
        await player.play(album: special)
        player.setRate(2)
        advance(10)
        #expect(player.elapsed == 20)
        #expect(player.rate == 2)
    }

    @Test func previousRestartsThenGoesBack() async {
        await player.play(album: special, startIndex: 2)
        advance(20)
        await player.previous()
        #expect(player.index == 2)
        #expect(player.elapsed == 0)
        await player.previous()
        #expect(player.index == 1)
    }

    @Test func upNextJumps() async {
        await player.play(album: special)
        await player.jump(to: 4)
        #expect(player.index == 4)
        #expect(player.upNext.first?.id == bits[5].id)
    }

    // MARK: Progress and resume

    @Test func pausingSavesWhereTheSetIs() async throws {
        await player.play(album: special)
        await player.jump(to: 2)
        advance(12)
        player.pause()
        let saved = try #require(store.progress(for: special.id))
        #expect(saved.lastTrackIndex == 2)
        #expect(abs(saved.lastPosition - 12) < 0.01)
        #expect(!saved.finished)
        #expect(saved.fractionComplete > 0 && saved.fractionComplete < 1)
        #expect(saved.title == special.title)
    }

    @Test func savesEveryTenSecondsWhilePlaying() async throws {
        await player.play(album: special)
        advance(4)
        #expect(store.progress(for: special.id)?.lastPosition == 0)
        advance(7)
        #expect(abs((try #require(store.progress(for: special.id))).lastPosition - 11) < 0.01)
    }

    @Test func playResumesWhereItWasLeft() async {
        await player.play(album: special)
        await player.jump(to: 2)
        advance(12)
        player.pause()
        #expect(player.resumePoint(for: special.id) != nil)

        let other = PlayerService(engine: MockPlaybackEngine(), catalog: MockCatalog(), progressStore: store)
        await other.play(album: special, resume: true)
        #expect(other.index == 2)
        #expect(abs(other.elapsed - 12) < 0.01)
    }

    @Test func aTappedBitIgnoresTheSavedPlace() async {
        await player.play(album: special)
        await player.jump(to: 2)
        advance(12)
        player.pause()
        await player.play(album: special, startIndex: 0)
        #expect(player.index == 0)
        #expect(player.elapsed == 0)
    }

    @Test func nearTheEndCountsAsFinishedAndStartsOver() async throws {
        await player.play(album: special, startIndex: bits.count - 1)
        player.seek(to: player.duration - 10)
        player.pause()
        let saved = try #require(store.progress(for: special.id))
        #expect(saved.finished)
        #expect(saved.fractionComplete == 1)
        #expect(saved.lastTrackIndex == 0)
        #expect(player.resumePoint(for: special.id) == nil)
    }

    @Test func switchingSpecialsSavesTheOldOne() async throws {
        await player.play(album: special)
        advance(30)
        await player.play(album: MockData.album(id: "mock-al-parking")!)
        let saved = try #require(store.progress(for: special.id))
        #expect(abs(saved.lastPosition - 30) < 0.01)
    }
}
