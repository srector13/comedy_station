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

    let catalog = SpotifyCatalog(api: Self.api(), confirming: CatalogComedianCheck(catalog: MockCatalog()), matchesURL: nil)

    @Test func searchKeepsOnlyComedians() async throws {
        let found = try await catalog.search("comedy")
        // Taylor by her Spotify genres; Maya, who has none on Spotify, by
        // the comedian check; not the pop star, and not someone unconfirmed.
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

/// TMDB lists for the Spotify route's Home, without the network.
struct FakeTMDB: TMDBListing {
    var key: String? = "key"
    var lists: [DiscoverShelf: [TMDBSpecial]] = [:]
    var names: [String] = []
    var services: [BrowseCategory] = []
    var categoryLists: [BrowseCategory: [TMDBSpecial]] = [:]

    func specials(for shelf: DiscoverShelf) async throws -> [TMDBSpecial] {
        lists[shelf] ?? []
    }

    func comedianName(of special: TMDBSpecial) async -> String? {
        special.titleParts?.comedian
    }

    func trendingNames() async -> [String] {
        names
    }

    func streamingServices() async throws -> [BrowseCategory] {
        services
    }

    func specials(in category: BrowseCategory) async throws -> [TMDBSpecial] {
        categoryLists[category] ?? []
    }
}

/// Home's TMDB shelves matched to Spotify, through the same comedy check.
struct SpotifyHomeTests {
    static let specials = [
        TMDBSpecial(id: 1, title: "Taylor Tomlinson: Have It All", releaseDate: TMDBClient.day(from: "2024-02-13"), popularity: 50),
        TMDBSpecial(id: 2, title: "Pop Star: Club Hits", releaseDate: nil, popularity: 40),
        TMDBSpecial(id: 3, title: "Someone: Not on Spotify", releaseDate: nil, popularity: 30),
    ]

    static let tmdb = FakeTMDB(
        lists: [.new: specials],
        names: ["Taylor Tomlinson", "Pop Star", "Maya Okafor", "Nobody Known"],
        services: [.streaming(id: 8, name: "Netflix")],
        categoryLists: [.streaming(id: 8, name: "Netflix"): specials, .decade(2020): specials]
    )

    private func catalog(tmdb: FakeTMDB = Self.tmdb) -> SpotifyCatalog {
        SpotifyCatalog(api: SpotifyCatalogTests.api(), confirming: CatalogComedianCheck(catalog: MockCatalog()), tmdb: tmdb, matchesURL: nil)
    }

    @Test func aShelfIsTMDBsSpecialsOnSpotify() async throws {
        let shelf = try await catalog().discover(.new)
        // The pop album matches its title but isn't comedy.
        #expect(shelf.map(\.id) == ["spotify:album:haveitall"])
        #expect(ComedyFilter.isComedy(shelf.first?.genreNames))
    }

    @Test func trendingComediansAreSpotifyArtists() async throws {
        let comedians = try await catalog().trendingComedians()
        #expect(comedians.map(\.id) == ["spotify:artist:taylor", "spotify:artist:maya"])
        #expect(comedians.allSatisfy { ComedyFilter.isComedy($0.genreNames) })
    }

    @Test func browseListsAreSpotifySpecials() async throws {
        let catalog = catalog()
        #expect(try await catalog.browseCategories() == [.streaming(id: 8, name: "Netflix")] + BrowseCategory.decades)
        #expect(try await catalog.browse(.streaming(id: 8, name: "Netflix")).map(\.id) == ["spotify:album:haveitall"])
        #expect(try await catalog.browse(.decade(2020)).map(\.id) == ["spotify:album:haveitall"])
        #expect(try await catalog.browse(.decade(1990)).isEmpty)
    }

    @Test func nothingWithoutATMDBKey() async throws {
        var tmdb = Self.tmdb
        tmdb.key = nil
        #expect(try await catalog(tmdb: tmdb).discover(.new).isEmpty)
        #expect(try await catalog(tmdb: tmdb).trendingComedians().isEmpty)
        #expect(try await catalog(tmdb: tmdb).browseCategories().isEmpty)
        #expect(try await catalog(tmdb: tmdb).browse(.decade(2020)).isEmpty)
    }

    @Test func matchesAreRemembered() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spotify-matches-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = SpotifyCatalog(api: SpotifyCatalogTests.api(), confirming: CatalogComedianCheck(catalog: MockCatalog()), tmdb: Self.tmdb, matchesURL: url)
        let shelf = try await first.discover(.new)
        let store = SpecialMatchStore(url: url)
        #expect(store.lookup(1) == .some(shelf.first))
        // Not on Spotify: a miss, tried again in a few days.
        #expect(store.lookup(3) == .some(nil))
        // On Spotify but not comedy: not kept, so a later check can say.
        #expect(store.lookup(2) == nil)
    }

    @Test func mockSpotifyShelvesAreComedy() async throws {
        let mock = MockSpotifyCatalog()
        for shelf in DiscoverShelf.allCases {
            let albums = try await mock.discover(shelf)
            #expect(!albums.isEmpty)
            #expect(albums.allSatisfy { Provider.of($0.id) == .spotify && ComedyFilter.isComedy($0.genreNames) })
        }
        #expect(try await mock.trendingComedians().map(\.name) == ["Lena Brooks", "Theo Park"])
    }
}

/// The iTunes Search check behind Spotify artists without genres.
struct ITunesComedianCheckTests {
    static let answer = """
    {"resultCount":3,"results":[
      {"artistName":"Tom Segura","collectionName":"Sledgehammer","primaryGenreName":"Comedy"},
      {"artistName":"Tom Segura","collectionName":"I'd Like to Leave Now","primaryGenreName":"Biographies & Memoirs"},
      {"artistName":"Tom Segura Band","collectionName":"Riffs","primaryGenreName":"Rock"}
    ]}
    """

    private func check(status: Int = 200, body: String = Self.answer) -> ITunesComedianCheck {
        ITunesComedianCheck(transport: { request in
            (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        })
    }

    @Test func aComedyAlbumMakesAComedian() async {
        #expect(await check().isComedian(named: "Tom Segura") == true)
        #expect(await check().isComedian(named: "Tom Segura Band") == false)
        #expect(await check().isComedian(named: "Someone Else") == false)
    }

    @Test func noAnswerIsUnknownNotNo() async {
        #expect(await check(status: 403).isComedian(named: "Tom Segura") == nil)
        #expect(await check(body: "not json").isComedian(named: "Tom Segura") == nil)
    }

    @Test func asksForAlbumsByArtistName() throws {
        let url = try #require(ITunesComedianCheck.request(for: "Tom Segura").url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(url.host() == "itunes.apple.com")
        #expect(items.contains(URLQueryItem(name: "term", value: "Tom Segura")))
        #expect(items.contains(URLQueryItem(name: "entity", value: "album")))
        #expect(items.contains(URLQueryItem(name: "attribute", value: "artistTerm")))
        #expect(ITunesComedianCheck.request(for: "x").httpMethod == "GET")
    }
}

/// The routing catalog sends Spotify IDs to Spotify and the rest to Apple
/// Music.
struct RoutingCatalogTests {
    let routing = RoutingCatalog(appleMusic: MockCatalog(), spotify: SpotifyCatalog(api: SpotifyCatalogTests.api(), confirming: CatalogComedianCheck(catalog: MockCatalog()), matchesURL: nil))

    @Test func eachIDGoesToItsService() async throws {
        #expect(try await routing.album(id: "spotify:album:haveitall").album.title == "Have It All")
        #expect(try await routing.album(id: "mock-al-lower").album.title == "Lower Your Expectations")
    }

    @Test func searchUsesTheChosenService() async throws {
        #expect(try await routing.search("comedy", in: .spotify).specials.map(\.id) == ["spotify:album:haveitall"])
        #expect(try await routing.search("Maya", in: .appleMusic).comedians.map(\.name) == ["Maya Okafor"])
    }

    @Test func homesShelvesComeFromTheChosenService() async throws {
        let mocks = RoutingCatalog(appleMusic: MockCatalog(), spotify: MockSpotifyCatalog())
        #expect(try await mocks.discover(.new, in: .spotify).allSatisfy { Provider.of($0.id) == .spotify })
        #expect(try await mocks.discover(.new, in: .appleMusic).allSatisfy { Provider.of($0.id) == .appleMusic })
        #expect(try await mocks.trendingComedians(in: .spotify).allSatisfy { Provider.of($0.id) == .spotify })
        #expect(try await mocks.browse(.decade(2020), in: .spotify).allSatisfy { Provider.of($0.id) == .spotify })
        #expect(try await mocks.browse(.decade(2020), in: .appleMusic).allSatisfy { Provider.of($0.id) == .appleMusic })
        #expect(!(try await mocks.browseCategories(in: .spotify)).isEmpty)
    }
}
