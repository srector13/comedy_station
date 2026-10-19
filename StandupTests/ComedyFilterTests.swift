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

    /// Rick Alvarez is filed under books; his comedy special makes him a
    /// comedian, and his genres then say so. A pop singer with a pop album
    /// stays out.
    @Test func aComedySpecialMakesAComedian() throws {
        let rick = try #require(MockData.artist(id: "mock-ar-rick"))
        let memoir = try #require(MockData.album(id: "mock-al-memoir"))
        #expect(!ComedyFilter.isComedy(rick.genreNames))
        let comedian = try #require(ComedyFilter.comedian(rick, specials: [memoir]))
        #expect(comedian.id == rick.id)
        #expect(ComedyFilter.isComedy(comedian.genreNames))
        #expect(ComedyFilter.comedian(rick, specials: []) == nil)

        let nova = try #require(MockData.artist(id: "mock-ar-nova"))
        #expect(ComedyFilter.comedian(nova, specials: [try #require(MockData.album(id: "mock-al-arena"))]) == nil)
        let maya = try #require(MockData.artist(id: "mock-ar-maya"))
        #expect(ComedyFilter.comedian(maya, specials: []) == maya)
    }

    /// Search results' specials rarely carry their artist, so names match.
    @Test func searchComediansAreMatchedToSpecialsByName() throws {
        var memoir = try #require(MockData.album(id: "mock-al-memoir"))
        memoir.artistID = nil
        memoir.artistName = "RICK ALVAREZ"
        let artists = ["mock-ar-rick", "mock-ar-nova", "mock-ar-maya"].compactMap(MockData.artist(id:))
        let arena = try #require(MockData.album(id: "mock-al-arena"))
        #expect(ComedyFilter.comedians(artists, specials: [memoir, arena]).map(\.name) == ["Rick Alvarez", "Maya Okafor"])
        #expect(ComedyFilter.comedians(artists, specials: [arena]).map(\.name) == ["Maya Okafor"])
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
