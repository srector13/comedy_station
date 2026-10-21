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

struct DiscoverTests {
    @Test func shelvesAskTMDBForTheRightLists() {
        let now = TMDBClient.day(from: "2026-10-19")!
        let new = TMDBClient.discoverQuery(keyword: 9716, from: now.addingTimeInterval(-365 * 86_400), to: now, order: .popular, minimumVotes: 0, page: 2)
        #expect(new["primary_release_date.gte"] == "2025-10-19")
        #expect(new["sort_by"] == "popularity.desc")
        #expect(new["page"] == "2")
        #expect(new["vote_count.gte"] == nil)
        let essential = TMDBClient.discoverQuery(keyword: 9716, from: nil, to: now, order: .rated, minimumVotes: 50, page: 1)
        #expect(essential["primary_release_date.gte"] == nil)
        #expect(essential["sort_by"] == "vote_average.desc")
        #expect(essential["vote_count.gte"] == "50")
    }

    @Test func browseAsksForAServiceOrADecade() {
        let now = TMDBClient.day(from: "2026-10-19")!
        let netflix = TMDBClient.discoverQuery(keyword: 9716, from: nil, to: now, order: .popular, minimumVotes: 0, streaming: .init(provider: 8, region: "US"), page: 1)
        #expect(netflix["with_watch_providers"] == "8")
        #expect(netflix["watch_region"] == "US")
        #expect(netflix["with_watch_monetization_types"] == "flatrate")
        let (from, to) = TMDBDiscovery.window(ofDecade: 1990, now: now)
        let nineties = TMDBClient.discoverQuery(keyword: 9716, from: from, to: to, order: .votes, minimumVotes: 0, page: 1)
        #expect(nineties["primary_release_date.gte"] == "1990-01-01")
        #expect(nineties["primary_release_date.lte"] == "1999-12-31")
        #expect(nineties["sort_by"] == "vote_count.desc")
        #expect(nineties["with_watch_providers"] == nil)
        // This decade ends today.
        #expect(TMDBDiscovery.window(ofDecade: 2020, now: now).1 == now)
    }

    @Test func browsePicksTheBigServicesInOrder() throws {
        let json = """
        {"results":[
          {"provider_id":15,"provider_name":"Hulu","display_priority":5},
          {"provider_id":1796,"provider_name":"Netflix Standard with Ads","display_priority":20},
          {"provider_id":8,"provider_name":"Netflix","display_priority":2},
          {"provider_id":1899,"provider_name":"HBO Max","display_priority":4},
          {"provider_id":1825,"provider_name":"HBO Max Amazon Channel","display_priority":40},
          {"provider_id":9,"provider_name":"Amazon Prime Video","display_priority":3},
          {"provider_id":2,"provider_name":"Apple TV Store","display_priority":1},
          {"provider_id":283,"provider_name":"Crunchyroll","display_priority":30}
        ]}
        """
        let providers = try JSONDecoder().decode(TMDBClient.Page<TMDBClient.WatchProvider>.self, from: Data(json.utf8)).results
        #expect(TMDBClient.streamingServices(from: providers) == [
            .streaming(id: 8, name: "Netflix"),
            .streaming(id: 1899, name: "HBO Max"),
            .streaming(id: 9, name: "Amazon Prime Video"),
            .streaming(id: 15, name: "Hulu"),
        ])
        // "Max" alone, as it was called for a while.
        #expect(TMDBClient.streamingServices(from: [.init(id: 1899, name: "Max", priority: 1)]) == [.streaming(id: 1899, name: "Max")])
        #expect(TMDBClient.streamingServices(from: [.init(id: 7, name: "Maxdome", priority: 1)]).isEmpty)
    }

    @Test func categoriesHaveStableIDsAndTitles() {
        #expect(BrowseCategory.streaming(id: 8, name: "Netflix").id == "streaming-8")
        #expect(BrowseCategory.streaming(id: 8, name: "Netflix").title == "Netflix")
        #expect(BrowseCategory.decade(1990).id == "decade-1990")
        #expect(BrowseCategory.decade(1990).title == "The 1990s")
        #expect(BrowseCategory.decades.first == .decade(2020))
        #expect(BrowseCategory.decades.allSatisfy { $0.isDecade })
    }

    @Test func mockBrowseListsAreComedyAndFitTheirCategory() async throws {
        let catalog = MockCatalog()
        let categories = try await catalog.browseCategories()
        #expect(categories.contains(.decade(2020)))
        let twenties = try await catalog.browse(.decade(2020))
        #expect(!twenties.isEmpty)
        #expect(twenties.allSatisfy { ComedyFilter.isComedy($0.genreNames) })
        #expect(twenties.allSatisfy { ($0.releaseDate ?? .distantPast) >= TMDBClient.day(from: "2020-01-01")! })
        #expect(try await catalog.browse(.decade(2010)).isEmpty)
        // The services split the sample specials between them.
        var seen = Set<String>()
        for service in MockData.streamingServices {
            for album in try await catalog.browse(service) {
                #expect(seen.insert(album.id).inserted)
            }
        }
        #expect(seen.count == ComedyFilter.keep(MockData.albums).count)
    }

    @Test func matchesAreRememberedAndMissesRetried() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("matches-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let lower = try #require(MockData.album(id: "mock-al-lower"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var store = SpecialMatchStore(url: url)
        #expect(store.lookup(1, now: now) == nil)
        store.record(lower, for: 1, now: now)
        store.record(nil, for: 2, now: now)
        store.save()

        let reopened = SpecialMatchStore(url: url)
        #expect(reopened.lookup(1, now: now.addingTimeInterval(86_400)) == .some(lower))
        #expect(reopened.lookup(2, now: now.addingTimeInterval(86_400)) == .some(nil))
        // A miss is looked up again after a few days, a match after a month.
        #expect(reopened.lookup(2, now: now.addingTimeInterval(4 * 86_400)) == nil)
        #expect(reopened.lookup(1, now: now.addingTimeInterval(31 * 86_400)) == nil)
    }

    @Test func mockShelvesAreComedyOnly() async throws {
        let catalog = MockCatalog()
        for shelf in DiscoverShelf.allCases {
            #expect(try await catalog.discover(shelf).allSatisfy { ComedyFilter.isComedy($0.genreNames) })
        }
        #expect(try await catalog.trendingComedians().allSatisfy { ComedyFilter.isComedy($0.genreNames) })
        let new = try await catalog.discover(.new)
        #expect(new == new.sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) })
    }
}
