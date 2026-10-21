import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Says whether someone is a comedian, by name, for a Spotify artist that
/// Spotify lists no genres for. Nil when it couldn't tell (offline, or
/// asked too often), so the answer isn't kept.
protocol ComedianConfirming: Sendable {
    func isComedian(named name: String) async -> Bool?
}

/// Asks Apple's public iTunes Search (no sign-in, no key), so the Spotify
/// route works without Apple Music. Someone counts when one of their
/// albums there is filed under Comedy, the same rule as everywhere else
/// (`ComedyFilter`). Read-only: one GET per name.
struct ITunesComedianCheck: ComedianConfirming {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    var transport: Transport = { try await URLSession.shared.data(for: $0) }

    struct Response: Decodable {
        struct Album: Decodable {
            var artistName: String?
            var primaryGenreName: String?
        }

        var results: [Album]
    }

    /// Albums by artists of that name.
    static func request(for name: String) -> URLRequest {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: name),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "album"),
            URLQueryItem(name: "attribute", value: "artistTerm"),
            URLQueryItem(name: "limit", value: "25"),
        ]
        return URLRequest(url: components.url!)
    }

    static func isComedian(_ name: String, in albums: [Response.Album]) -> Bool {
        let target = SpecialMatcher.normalized(name)
        return albums.contains { album in
            SpecialMatcher.normalized(album.artistName ?? "") == target && ComedyFilter.isComedy(album.primaryGenreName.map { [$0] })
        }
    }

    func isComedian(named name: String) async -> Bool? {
        guard let (data, response) = try? await transport(Self.request(for: name)) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        guard let found = try? JSONDecoder().decode(Response.self, from: data) else { return nil }
        return Self.isComedian(name, in: found.results)
    }
}

/// Asks a catalog's search for a comedian of that name (tests, and mock
/// mode).
struct CatalogComedianCheck: ComedianConfirming {
    let catalog: any CatalogProviding

    func isComedian(named name: String) async -> Bool? {
        guard let found = try? await catalog.search(name) else { return nil }
        let target = SpecialMatcher.normalized(name)
        return found.comedians.contains { SpecialMatcher.normalized($0.name) == target }
    }
}
