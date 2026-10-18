import Testing
@testable import Standup

struct ComedyFilterTests {
    @Test(arguments: [
        ["Comedy"], ["comedy"], ["COMEDY"], ["Stand-Up Comedy"], ["Music", "Comedy"],
    ])
    func comedyGenreNamesPass(_ names: [String]) {
        #expect(ComedyFilter.isComedy(names))
    }

    @Test(arguments: [
        ["Pop"], ["Soundtrack"], ["Spoken Word"], [],
    ])
    func otherGenreNamesFail(_ names: [String]) {
        #expect(!ComedyFilter.isComedy(names))
    }

    @Test func missingGenreNamesFail() {
        #expect(!ComedyFilter.isComedy(nil))
    }

    @Test func genreIDIsComedys() {
        #expect(ComedyFilter.comedyGenreID == "3")
    }

    @Test func keepsOnlyComedyInOrder() {
        let kept = ComedyFilter.keep(MockData.comedians)
        #expect(kept.map(\.name) == ["Maya Okafor", "Dev Raman", "Lou Petrakis", "Rosa Delgado", "Sam Whitlock", "Jenna Albright"])
    }

    @Test func titleSayingComedyIsNotEnough() throws {
        let score = try #require(MockData.albums.first { $0.title.hasPrefix("Comedy of Errors") })
        #expect(ComedyFilter.keep([score]).isEmpty)
    }

    @Test func aBitIsJudgedByItsAlbum() throws {
        let onCompilation = try #require(MockData.tracks["mock-al-summer"]?.first)
        let onSpecial = try #require(MockData.tracks["mock-al-lower"]?.first)
        #expect(onCompilation.artistName == "Maya Okafor")
        #expect(ComedyFilter.keep([onCompilation, onSpecial]) == [onSpecial])
    }
}
