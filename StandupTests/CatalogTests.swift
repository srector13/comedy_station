import Foundation
import Testing
@testable import Standup

/// The mock catalog runs the same filter as the live one, so these pin the
/// comedy-only rules end to end.
struct MockCatalogTests {
    let catalog = MockCatalog()

    @Test func searchDropsNonComedyAlbums() async throws {
        let results = try await catalog.search("live")
        #expect(results.specials.map(\.title) == ["Live from the Laundromat"])
    }

    @Test func searchDropsNonComedyArtists() async throws {
        let results = try await catalog.search("nova")
        #expect(results.comedians.isEmpty)
        #expect(results.specials.isEmpty)
    }

    @Test func searchFindsComedianSpecialsAndBits() async throws {
        let results = try await catalog.search("maya")
        #expect(results.comedians.map(\.name) == ["Maya Okafor"])
        #expect(Set(results.specials.map(\.title)) == ["Lower Your Expectations", "Group Chat Energy"])
        #expect(!results.bits.isEmpty)
        #expect(results.bits.allSatisfy { $0.albumID != "mock-al-summer" })
    }

    @Test func suggestionsAreComedyOnly() async throws {
        let suggestions = try await catalog.suggestions(for: "live")
        #expect(suggestions.map(\.title) == ["Live from the Laundromat"])
    }

    @Test func nonComedyAlbumPageIsRefused() async {
        await #expect(throws: CatalogError.notComedy) {
            try await catalog.album(id: "mock-al-arena")
        }
    }

    @Test func unknownAlbumIsNotFound() async {
        await #expect(throws: CatalogError.notFound) {
            try await catalog.album(id: "nope")
        }
    }

    @Test func albumDetailHasBitsAndRuntime() async throws {
        let detail = try await catalog.album(id: "mock-al-lower")
        #expect(detail.tracks.count == 11)
        #expect(detail.tracks.first?.title == "Intro")
        #expect(detail.totalDuration == detail.tracks.compactMap(\.duration).reduce(0, +))
        #expect(detail.editorialNotes != nil)
    }

    @Test func artistPageIsFilteredAndNewestFirst() async throws {
        let detail = try await catalog.artist(id: "mock-ar-maya")
        #expect(detail.specials.map(\.title) == ["Lower Your Expectations", "Group Chat Energy"])
        #expect(detail.featured?.title == "Lower Your Expectations")
        #expect(!detail.similar.contains { $0.name == "Nova Rae" || $0.name == "City Pops Orchestra" })
        #expect(!detail.similar.contains { $0.id == "mock-ar-maya" })
        #expect(!detail.topBits.isEmpty)
        #expect(detail.topBits.allSatisfy { ComedyFilter.isComedy($0.albumGenreNames) })
    }

    @Test func nonComedyArtistPageIsRefused() async {
        await #expect(throws: CatalogError.notComedy) {
            try await catalog.artist(id: "mock-ar-nova")
        }
    }

    @Test func routesResolveFromLaunchValues() {
        #expect(MockCatalog.route(for: "album:mock-al-lower") == .album(MockData.albums[0]))
        #expect(MockCatalog.route(for: "artist:mock-ar-maya") == .artist(MockData.comedians[0]))
        #expect(MockCatalog.route(for: "album:missing") == nil)
        #expect(MockCatalog.route(for: "garbage") == nil)
    }
}

struct ArtworkRefTests {
    @Test func templateFromProbe() {
        let probe = "https://is1-ssl.mzstatic.com/image/thumb/Music/ab/cd/1111x1111bb.jpg"
        let artwork = ArtworkRef(template: ArtworkRef.template(fromProbe: probe))
        #expect(artwork.url(side: 300)?.absoluteString == "https://is1-ssl.mzstatic.com/image/thumb/Music/ab/cd/300x300bb.jpg")
    }

    @Test func noTemplateMeansGenerated() {
        #expect(ArtworkRef(generatedFor: "x").url(side: 300) == nil)
    }

    @Test func seedIsStable() {
        #expect(ArtworkRef.seed(for: "mock-al-lower") == ArtworkRef.seed(for: "mock-al-lower"))
        #expect(ArtworkRef.seed(for: "a") != ArtworkRef.seed(for: "b"))
    }
}

struct FormatTests {
    @Test func trackTimes() {
        #expect(Format.trackTime(272) == "4:32")
        #expect(Format.trackTime(59) == "0:59")
        #expect(Format.trackTime(3723) == "1:02:03")
        #expect(Format.trackTime(nil) == "")
    }

    @Test func runtimeIsInHoursAndMinutes() {
        #expect(Format.runtime(3840).contains("1"))
        #expect(Format.runtime(3840).contains("4"))
        #expect(!Format.runtime(3840).contains("second"))
    }

    @Test func bitCounts() {
        #expect(Format.bitCount(1) == "1 bit")
        #expect(Format.bitCount(12) == "12 bits")
    }
}

struct ResponseCacheTests {
    @Test func expiresAfterLifetime() {
        var cache = ResponseCache(lifetime: 60)
        let start = Date(timeIntervalSince1970: 0)
        cache.store("value", for: "k", now: start)
        #expect((cache.value(for: "k", now: start.addingTimeInterval(30)) as String?) == "value")
        #expect((cache.value(for: "k", now: start.addingTimeInterval(61)) as String?) == nil)
    }

    @Test func evictsOldestWhenFull() {
        var cache = ResponseCache(lifetime: 600)
        cache.maximumCount = 2
        let start = Date(timeIntervalSince1970: 0)
        cache.store(1, for: "a", now: start)
        cache.store(2, for: "b", now: start.addingTimeInterval(1))
        cache.store(3, for: "c", now: start.addingTimeInterval(2))
        #expect((cache.value(for: "a", now: start.addingTimeInterval(3)) as Int?) == nil)
        #expect((cache.value(for: "c", now: start.addingTimeInterval(3)) as Int?) == 3)
    }

    @Test func editorialNotesLoseMarkup() {
        #expect(Format.plainText("<i>Live</i> at home<br/>Two nights") == "Live at home\nTwo nights")
    }
}
