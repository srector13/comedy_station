import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Standup

/// The Spotify catalog against canned Web API answers.
struct SpotifyCatalogTests {
    /// Answers by path: the search, each artist, a special.
    static let answers: [String: String] = [
        "/v1/search": """
        {"artists":{"items":[
          {"name":"Taylor Tomlinson","uri":"spotify:artist:taylor","genres":["comedy","stand-up comedy"],"images":[{"url":"https://i.scdn.co/t640","width":640},{"url":"https://i.scdn.co/t64","width":64}]},
          {"name":"Pop Star","uri":"spotify:artist:pop","genres":["dance pop"]},
          {"name":"Maya Okafor","uri":"spotify:artist:maya","genres":[]},
          {"name":"Nobody Known","uri":"spotify:artist:nobody","genres":[]}
        ]},
        "albums":{"items":[
          {"name":"Have It All","uri":"spotify:album:haveitall","release_date":"2024-02","total_tracks":12,"images":[],"artists":[{"name":"Taylor Tomlinson","uri":"spotify:artist:taylor"}]},
          {"name":"Club Hits","uri":"spotify:album:clubhits","release_date":"2025","total_tracks":10,"artists":[{"name":"Pop Star","uri":"spotify:artist:pop"}]}
        ]},
        "tracks":{"items":[
          {"name":"Dating Apps","uri":"spotify:track:dating","duration_ms":185000,"track_number":3,"explicit":true,
           "artists":[{"name":"Taylor Tomlinson","uri":"spotify:artist:taylor"}],
           "album":{"name":"Have It All","uri":"spotify:album:haveitall","release_date":"2024-02-13","artists":[{"name":"Taylor Tomlinson","uri":"spotify:artist:taylor"}]}},
          {"name":"Club Song","uri":"spotify:track:club","duration_ms":200000,
           "artists":[{"name":"Pop Star","uri":"spotify:artist:pop"}],
           "album":{"name":"Club Hits","uri":"spotify:album:clubhits","artists":[{"name":"Pop Star","uri":"spotify:artist:pop"}]}}
        ]}}
        """,
        "/v1/artists/taylor": #"{"name":"Taylor Tomlinson","uri":"spotify:artist:taylor","genres":["comedy"]}"#,
        "/v1/artists/pop": #"{"name":"Pop Star","uri":"spotify:artist:pop","genres":["dance pop"]}"#,
        "/v1/albums/haveitall": """
        {"name":"Have It All","uri":"spotify:album:haveitall","release_date":"2024-02-13","total_tracks":2,
         "artists":[{"name":"Taylor Tomlinson","uri":"spotify:artist:taylor"}],
         "copyrights":[{"text":"2024 Taylor Tomlinson"}],
         "tracks":{"items":[
           {"name":"Intro","uri":"spotify:track:intro","duration_ms":60000,"track_number":1,"artists":[]},
           {"name":"Dating Apps","uri":"spotify:track:dating","duration_ms":185000,"track_number":2,"artists":[]}
         ]}}
        """,
        "/v1/albums/clubhits": #"{"name":"Club Hits","uri":"spotify:album:clubhits","artists":[{"name":"Pop Star","uri":"spotify:artist:pop"}],"tracks":{"items":[]}}"#,
    ]

    static func api() -> SpotifyWebAPI {
        SpotifyWebAPI(token: { "token" }, transport: { request in
            let path = request.url?.path ?? ""
            guard let body = answers[path] else {
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
            }
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
    }

    let catalog = SpotifyCatalog(api: Self.api(), appleMusic: MockCatalog())

    @Test func searchKeepsOnlyComedians() async throws {
        let found = try await catalog.search("comedy")
        // Taylor by her Spotify genres; Maya, who has none on Spotify, by
        // Apple Music; not the pop star, and not someone unconfirmed.
        #expect(found.comedians.map(\.name) == ["Taylor Tomlinson", "Maya Okafor"])
        #expect(found.specials.map(\.id) == ["spotify:album:haveitall"])
        #expect(found.bits.map(\.id) == ["spotify:track:dating"])
    }

    @Test func spotifyObjectsBecomeTheAppsWithURIsAsIDs() async throws {
        let found = try await catalog.search("comedy")
        let special = try #require(found.specials.first)
        #expect(Provider.of(special.id) == .spotify)
        #expect(special.artistID == "spotify:artist:taylor")
        #expect(special.trackCount == 12)
        #expect(special.releaseDate == TMDBClient.day(from: "2024-02-01"))
        let taylor = try #require(found.comedians.first)
        #expect(taylor.artwork.url(side: 300)?.absoluteString == "https://i.scdn.co/t640")
        let bit = try #require(found.bits.first)
        #expect(bit.duration == 185)
        #expect(bit.isExplicit)
        #expect(bit.albumID == "spotify:album:haveitall")
    }

    @Test func aSpecialPageListsItsBits() async throws {
        let detail = try await catalog.album(id: "spotify:album:haveitall")
        #expect(detail.tracks.map(\.title) == ["Intro", "Dating Apps"])
        #expect(detail.tracks.allSatisfy { $0.artistName == "Taylor Tomlinson" })
        #expect(detail.copyright == "2024 Taylor Tomlinson")
    }

    @Test func aMusicAlbumIsRefused() async {
        await #expect(throws: CatalogError.notComedy) {
            _ = try await catalog.album(id: "spotify:album:clubhits")
        }
    }

    @Test func idsSayWhichServiceTheyreFrom() throws {
        #expect(Provider.of("spotify:album:abc") == .spotify)
        #expect(Provider.of("1440833098") == .appleMusic)
        #expect(try SpotifyWebAPI.bareID("spotify:album:abc") == "abc")
        #expect(throws: SpotifyError.notASpotifyID) { try SpotifyWebAPI.bareID("1440833098") }
        #expect(SpotifyWebAPI.date("2024") == TMDBClient.day(from: "2024-01-01"))
    }

    @Test func requestsCarryTheTokenAndNeverWrite() {
        let request = Self.api().request("search", ["q": "taylor"], token: "abc")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
        #expect(request.httpMethod == "GET")
        #expect(request.url?.absoluteString == "https://api.spotify.com/v1/search?q=taylor")
    }
}

/// The routing catalog sends Spotify IDs to Spotify and the rest to Apple
/// Music.
struct RoutingCatalogTests {
    let routing = RoutingCatalog(appleMusic: MockCatalog(), spotify: SpotifyCatalog(api: SpotifyCatalogTests.api(), appleMusic: MockCatalog()))

    @Test func eachIDGoesToItsService() async throws {
        #expect(try await routing.album(id: "spotify:album:haveitall").album.title == "Have It All")
        #expect(try await routing.album(id: "mock-al-lower").album.title == "Lower Your Expectations")
    }

    @Test func searchUsesTheChosenService() async throws {
        #expect(try await routing.search("comedy", in: .spotify).specials.map(\.id) == ["spotify:album:haveitall"])
        #expect(try await routing.search("Maya", in: .appleMusic).comedians.map(\.name) == ["Maya Okafor"])
    }
}
