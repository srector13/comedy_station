import Foundation
import Testing
@testable import Standup

struct TMDBTests {
    @Test func discoverResultsDecode() throws {
        let json = """
        {"page":1,"results":[
          {"id":1234,"title":"Nate Bargatze: Your Friend, Nate Bargatze","release_date":"2024-12-24","popularity":61.5,"adult":false},
          {"id":99,"title":"Untitled Special","release_date":"","popularity":2}
        ],"total_pages":1}
        """
        let page = try JSONDecoder().decode(TMDBClient.Page<TMDBSpecial>.self, from: Data(json.utf8))
        #expect(page.results.count == 2)
        #expect(page.results[0].id == 1234)
        #expect(page.results[0].releaseDate == TMDBClient.day(from: "2024-12-24"))
        #expect(page.results[0].popularity == 61.5)
        #expect(page.results[1].releaseDate == nil)
    }

    @Test func aTitleNamesItsComedianBeforeTheColon() throws {
        let special = TMDBSpecial(id: 1, title: "Nate Bargatze: Your Friend, Nate Bargatze", releaseDate: nil, popularity: 1)
        let parts = try #require(special.titleParts)
        #expect(parts.comedian == "Nate Bargatze")
        #expect(parts.title == "Your Friend, Nate Bargatze")
        #expect(TMDBSpecial(id: 2, title: "Live at the Apollo", releaseDate: nil, popularity: 1).titleParts == nil)
    }

    @Test func theHeadlinerIsFirstBilled() throws {
        let json = #"{"id":1,"cast":[{"name":"Opener","order":3},{"name":"Taylor Tomlinson","order":0}],"crew":[]}"#
        let credits = try JSONDecoder().decode(TMDBClient.Credits.self, from: Data(json.utf8))
        #expect(credits.headliner == "Taylor Tomlinson")
    }

    @Test func theStandUpKeywordIsPicked() {
        let keywords = [TMDBClient.Keyword(id: 1, name: "comedy"), TMDBClient.Keyword(id: 9716, name: "Stand-up Comedy"), TMDBClient.Keyword(id: 5, name: "stand-up comedy special")]
        #expect(TMDBClient.standUpKeyword(in: keywords)?.id == 9716)
        #expect(TMDBClient.standUpKeyword(in: [TMDBClient.Keyword(id: 5, name: "stand-up comedy special")])?.id == 5)
    }

    @Test func aV3KeyGoesInTheQueryAndAV4TokenInTheHeader() throws {
        let v3 = TMDBClient(key: "abc123").request("discover/movie", ["page": "1"])
        let v3URL = try #require(v3.url?.absoluteString)
        #expect(v3URL.hasPrefix("https://api.themoviedb.org/3/discover/movie?"))
        #expect(v3URL.contains("api_key=abc123"))
        #expect(v3.value(forHTTPHeaderField: "Authorization") == nil)

        let v4 = TMDBClient(key: "eyJhbGciOiJIUzI1NiJ9.e30.sig").request("search/keyword", ["query": "stand-up comedy"])
        #expect(v4.url?.absoluteString.contains("api_key") == false)
        #expect(v4.value(forHTTPHeaderField: "Authorization") == "Bearer eyJhbGciOiJIUzI1NiJ9.e30.sig")
    }

    @Test func datesAreDays() throws {
        let date = try #require(TMDBClient.day(from: "2026-04-30"))
        #expect(TMDBClient.day(date) == "2026-04-30")
    }
}

struct SpecialMatcherTests {
    private func album(_ id: String, _ title: String, by artist: String, released: String? = nil) -> ComedyAlbum {
        ComedyAlbum(
            id: id, title: title, artistName: artist,
            artwork: ArtworkRef(template: nil, backgroundRGB: nil, seed: 1),
            releaseDate: released.flatMap(TMDBClient.day(from:)), trackCount: 10, genreNames: ["Comedy"]
        )
    }

    @Test func normalizingDropsAsidesAccentsAndLive() {
        #expect(SpecialMatcher.normalized("Hello World (Live)") == "hello world")
        #expect(SpecialMatcher.normalized("Señor Café & Friends [Explicit]") == "senor cafe and friends")
        #expect(SpecialMatcher.normalized("Baby J Live") == "baby j")
        #expect(SpecialMatcher.normalized("Live") == "live")
    }

    @Test func findsTheSameSpecialFromTheSameComedian() {
        let candidates = [
            album("a", "Hello World", by: "Someone Else", released: "2025-01-10"),
            album("b", "Your Friend, Nate Bargatze (Live)", by: "Nate Bargatze", released: "2025-01-10"),
            album("c", "The Tennessee Kid", by: "Nate Bargatze", released: "2019-01-01"),
        ]
        let best = SpecialMatcher.best(comedian: "Nate Bargatze", title: "Your Friend, Nate Bargatze", released: TMDBClient.day(from: "2024-12-24"), in: candidates)
        #expect(best?.id == "b")
    }

    @Test func aTitleWithTheComedianInFrontStillMatches() {
        let candidates = [album("a", "Taylor Tomlinson: Have It All", by: "Taylor Tomlinson")]
        #expect(SpecialMatcher.best(comedian: "Taylor Tomlinson", title: "Have It All", released: nil, in: candidates)?.id == "a")
    }

    @Test func noMatchMeansNothing() {
        let candidates = [
            album("a", "Have It All", by: "Someone Else"),
            album("b", "A Different Hour", by: "Taylor Tomlinson"),
        ]
        #expect(SpecialMatcher.best(comedian: "Taylor Tomlinson", title: "Have It All", released: nil, in: candidates) == nil)
    }

    @Test func anAlbumYearsApartIsADifferentRelease() {
        let candidates = [album("a", "Lucky", by: "Bert Kreischer", released: "2015-05-01")]
        #expect(SpecialMatcher.best(comedian: "Bert Kreischer", title: "Lucky", released: TMDBClient.day(from: "2025-03-04"), in: candidates) == nil)
    }
}

@MainActor
struct SpecialsSettingsTests {
    struct Refused: Error {}

    @Test func aWorkingKeyIsKept() async throws {
        let store = MemoryKeyStore()
        let settings = SpecialsSettings(store: store, check: { _ in })
        #expect(!settings.hasKey)
        try await settings.save("  abc123\n")
        #expect(settings.hasKey)
        #expect(store.load() == "abc123")
        #expect(settings.revision == 1)
        settings.remove()
        #expect(!settings.hasKey)
        #expect(store.load() == nil)
        #expect(settings.revision == 2)
    }

    @Test func aRefusedKeyIsNotKept() async {
        let store = MemoryKeyStore()
        let settings = SpecialsSettings(store: store, check: { _ in throw Refused() })
        await #expect(throws: Refused.self) { try await settings.save("bad") }
        #expect(!settings.hasKey)
        #expect(store.load() == nil)
        #expect(settings.revision == 0)
    }

    @Test func aKeptKeyIsFoundAtLaunch() {
        #expect(SpecialsSettings(store: MemoryKeyStore("abc"), check: { _ in }).hasKey)
    }
}
