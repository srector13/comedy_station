import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The service an item comes from. Spotify items keep their Spotify URI as
/// their ID ("spotify:album:…"); Apple Music IDs are plain numbers. So the
/// App Library, its iCloud records and the player can tell them apart with
/// nothing extra stored.
enum Provider: String, Sendable, CaseIterable, Identifiable {
    case appleMusic, spotify

    var id: Self { self }

    static func of(_ id: String) -> Provider {
        id.hasPrefix("spotify:") ? .spotify : .appleMusic
    }

    var name: String {
        switch self {
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        }
    }
}

enum SpotifyError: LocalizedError, Equatable {
    case notConnected
    case status(Int)
    case notASpotifyID

    var errorDescription: String? {
        switch self {
        case .notConnected: "Connect Spotify in Settings first."
        case .status(401): "Spotify signed Standup out. Connect Spotify again in Settings."
        case .status(429): "Spotify asked Standup to slow down. Try again in a minute."
        case .status(let code): "Spotify answered with an error (\(code))."
        case .notASpotifyID: "This isn't a Spotify item."
        }
    }
}

/// The read-only Spotify Web API requests Standup makes: search, a special,
/// a comedian and their specials. Nothing is ever written to the Spotify
/// library (hard rule 1); every request here is a GET.
struct SpotifyWebAPI: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    /// A current access token (refreshed when needed).
    var token: @Sendable () async throws -> String
    /// The network, replaceable in tests.
    var transport: Transport = { try await URLSession.shared.data(for: $0) }

    static let base = URL(string: "https://api.spotify.com/v1/")!
    /// The most Development Mode allows per search page (February 2026).
    static let searchLimit = 10

    func request(_ path: String, _ query: [String: String] = [:], token: String) -> URLRequest {
        var components = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func get<Value: Decodable>(_ path: String, _ query: [String: String] = [:]) async throws -> Value {
        let (data, response) = try await transport(request(path, query, token: try await token()))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SpotifyError.status(http.statusCode)
        }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    /// The item on the Spotify web player, which Spotify's terms ask Spotify
    /// content to link to ("spotify:album:abc" → open.spotify.com/album/abc).
    static func webURL(for uri: String) -> URL? {
        let parts = uri.split(separator: ":")
        guard parts.count == 3, parts[0] == "spotify" else { return nil }
        return URL(string: "https://open.spotify.com/\(parts[1])/\(parts[2])")
    }

    /// The bare ID in a Spotify URI ("spotify:album:abc" → "abc").
    static func bareID(_ uri: String) throws -> String {
        let parts = uri.split(separator: ":")
        guard parts.count == 3, parts[0] == "spotify" else { throw SpotifyError.notASpotifyID }
        return String(parts[2])
    }

    // MARK: Requests

    func search(_ term: String, types: String = "artist,album,track", offset: Int = 0) async throws -> SearchResponse {
        try await get("search", [
            "q": term,
            "type": types,
            "limit": String(Self.searchLimit),
            "offset": String(offset),
            "market": "from_token",
        ])
    }

    func album(_ uri: String) async throws -> Album {
        try await get("albums/\(try Self.bareID(uri))", ["market": "from_token"])
    }

    func artist(_ uri: String) async throws -> Artist {
        try await get("artists/\(try Self.bareID(uri))")
    }

    func artistAlbums(_ uri: String) async throws -> [SimpleAlbum] {
        let page: Page<SimpleAlbum> = try await get("artists/\(try Self.bareID(uri))/albums", [
            "include_groups": "album,single",
            "limit": "10",
            "market": "from_token",
        ])
        return page.items
    }

    // MARK: Objects

    struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
        var items: [Item]
    }

    struct Image: Decodable, Sendable {
        var url: String
        var width: Int?
    }

    struct SimpleArtist: Decodable, Sendable {
        var name: String
        var uri: String
    }

    struct Artist: Decodable, Sendable {
        var name: String
        var uri: String
        var genres: [String]?
        var images: [Image]?
    }

    struct SimpleAlbum: Decodable, Sendable {
        var name: String
        var uri: String
        var releaseDate: String?
        var totalTracks: Int?
        var images: [Image]?
        var artists: [SimpleArtist]

        enum CodingKeys: String, CodingKey {
            case name, uri, images, artists
            case releaseDate = "release_date"
            case totalTracks = "total_tracks"
        }
    }

    struct SimpleTrack: Decodable, Sendable {
        var name: String
        var uri: String
        var durationMS: Int?
        var trackNumber: Int?
        var explicit: Bool?
        var artists: [SimpleArtist]

        enum CodingKeys: String, CodingKey {
            case name, uri, explicit, artists
            case durationMS = "duration_ms"
            case trackNumber = "track_number"
        }
    }

    struct Track: Decodable, Sendable {
        var name: String
        var uri: String
        var durationMS: Int?
        var trackNumber: Int?
        var explicit: Bool?
        var artists: [SimpleArtist]
        var album: SimpleAlbum

        enum CodingKeys: String, CodingKey {
            case name, uri, explicit, artists, album
            case durationMS = "duration_ms"
            case trackNumber = "track_number"
        }
    }

    struct Album: Decodable, Sendable {
        struct Copyright: Decodable, Sendable {
            var text: String
        }

        var name: String
        var uri: String
        var releaseDate: String?
        var totalTracks: Int?
        var images: [Image]?
        var artists: [SimpleArtist]
        var tracks: Page<SimpleTrack>?
        var copyrights: [Copyright]?

        enum CodingKeys: String, CodingKey {
            case name, uri, images, artists, tracks, copyrights
            case releaseDate = "release_date"
            case totalTracks = "total_tracks"
        }

        var simple: SimpleAlbum {
            SimpleAlbum(name: name, uri: uri, releaseDate: releaseDate, totalTracks: totalTracks, images: images, artists: artists)
        }
    }

    struct SearchResponse: Decodable, Sendable {
        var artists: Page<Artist>?
        var albums: Page<SimpleAlbum>?
        var tracks: Page<Track>?
    }

    // MARK: Values

    /// The largest image, as a fixed URL (Spotify doesn't size on request).
    static func artwork(_ images: [Image]?, uri: String) -> ArtworkRef {
        let best = images?.max { ($0.width ?? 0) < ($1.width ?? 0) }
        return ArtworkRef(template: best?.url, backgroundRGB: nil, seed: ArtworkRef.seed(for: uri))
    }

    /// "2024", "2024-03" or "2024-03-01", as Spotify writes release dates.
    static func date(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        var parts = text.split(separator: "-").map(String.init)
        while parts.count < 3 { parts.append("01") }
        return TMDBClient.day(from: parts.prefix(3).joined(separator: "-"))
    }
}

// MARK: Spotify objects as the app's

extension ComedyArtist {
    init(spotify artist: SpotifyWebAPI.Artist, genreNames: [String]) {
        self.init(id: artist.uri, name: artist.name, artwork: SpotifyWebAPI.artwork(artist.images, uri: artist.uri), genreNames: genreNames)
    }
}

extension ComedyAlbum {
    init(spotify album: SpotifyWebAPI.SimpleAlbum, genreNames: [String]) {
        self.init(
            id: album.uri, title: album.name, artistName: album.artists.first?.name ?? "",
            artistID: album.artists.first?.uri,
            artwork: SpotifyWebAPI.artwork(album.images, uri: album.uri),
            releaseDate: SpotifyWebAPI.date(album.releaseDate),
            trackCount: album.totalTracks ?? 0, genreNames: genreNames
        )
    }
}

extension ComedyTrack {
    init(spotify track: SpotifyWebAPI.SimpleTrack, album: SpotifyWebAPI.SimpleAlbum, albumGenreNames: [String]) {
        self.init(
            id: track.uri, title: track.name, artistName: track.artists.first?.name ?? album.artists.first?.name ?? "",
            albumID: album.uri, albumTitle: album.name,
            duration: track.durationMS.map { TimeInterval($0) / 1000 }, trackNumber: track.trackNumber,
            artwork: SpotifyWebAPI.artwork(album.images, uri: album.uri),
            isExplicit: track.explicit ?? false, albumGenreNames: albumGenreNames
        )
    }

    init(spotify track: SpotifyWebAPI.Track, albumGenreNames: [String]) {
        self.init(
            spotify: SpotifyWebAPI.SimpleTrack(name: track.name, uri: track.uri, durationMS: track.durationMS, trackNumber: track.trackNumber, explicit: track.explicit, artists: track.artists),
            album: track.album, albumGenreNames: albumGenreNames
        )
    }
}
