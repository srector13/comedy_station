import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A stand-up special as The Movie Database lists it (Netflix, Max, Prime
/// Video and the rest). TMDB only says which specials are new and popular;
/// Standup shows and plays their Apple Music versions (`SpecialMatcher`).
struct TMDBSpecial: Equatable, Sendable, Decodable {
    var id: Int
    var title: String
    var releaseDate: Date?
    var popularity: Double

    enum CodingKeys: String, CodingKey {
        case id, title, popularity
        case releaseDate = "release_date"
    }

    init(id: Int, title: String, releaseDate: Date?, popularity: Double) {
        self.id = id
        self.title = title
        self.releaseDate = releaseDate
        self.popularity = popularity
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        popularity = try container.decodeIfPresent(Double.self, forKey: .popularity) ?? 0
        // "" when TMDB doesn't know it yet.
        releaseDate = (try container.decodeIfPresent(String.self, forKey: .releaseDate)).flatMap(TMDBClient.day(from:))
    }

    /// "Nate Bargatze: Your Friend, Nate Bargatze" names its comedian
    /// before the colon, as most specials' titles do. Nil without one.
    var titleParts: (comedian: String, title: String)? {
        guard let colon = title.range(of: ": ") else { return nil }
        let comedian = title[..<colon.lowerBound].trimmingCharacters(in: .whitespaces)
        let rest = title[colon.upperBound...].trimmingCharacters(in: .whitespaces)
        guard !comedian.isEmpty, !rest.isEmpty else { return nil }
        return (comedian, rest)
    }
}

enum TMDBError: LocalizedError, Equatable {
    case status(Int)
    case noStandUpKeyword

    var errorDescription: String? {
        switch self {
        case .status(401): "TMDB didn't accept this key."
        case .status(let code): "TMDB answered with an error (\(code))."
        case .noStandUpKeyword: "TMDB has no stand-up comedy keyword."
        }
    }
}

/// The few TMDB requests Standup makes. The key is the person's own, from
/// Settings: a v3 API key, or a v4 read access token.
struct TMDBClient: Sendable {
    var key: String

    static let base = URL(string: "https://api.themoviedb.org/3/")!

    /// A request with the key: as a bearer token for a v4 token (a JWT,
    /// with dots), as `api_key` for a v3 key.
    func request(_ path: String, _ query: [String: String] = [:]) -> URLRequest {
        var items = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        let isToken = key.contains(".")
        if !isToken {
            items.append(URLQueryItem(name: "api_key", value: key))
        }
        var components = URLComponents(url: Self.base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if isToken {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func get<Value: Decodable>(_ path: String, _ query: [String: String] = [:]) async throws -> Value {
        let (data, response) = try await URLSession.shared.data(for: request(path, query))
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw TMDBError.status(http.statusCode)
        }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    // MARK: Requests

    struct Page<Item: Decodable>: Decodable {
        var results: [Item]
    }

    struct Keyword: Decodable {
        var id: Int
        var name: String
    }

    struct Credits: Decodable {
        struct Person: Decodable {
            var name: String
            var order: Int?
        }

        var cast: [Person]

        /// The headliner: first in the cast's billing.
        var headliner: String? {
            cast.min { ($0.order ?? .max) < ($1.order ?? .max) }?.name
        }
    }

    /// TMDB's "stand-up comedy" keyword, which its specials are tagged with.
    func standUpKeywordID() async throws -> Int {
        let page: Page<Keyword> = try await get("search/keyword", ["query": "stand-up comedy"])
        guard let keyword = Self.standUpKeyword(in: page.results) else { throw TMDBError.noStandUpKeyword }
        return keyword.id
    }

    static func standUpKeyword(in keywords: [Keyword]) -> Keyword? {
        keywords.first { $0.name.caseInsensitiveCompare("stand-up comedy") == .orderedSame }
            ?? keywords.first { $0.name.localizedCaseInsensitiveContains("stand-up") }
    }

    /// How a list of specials is ordered.
    enum Order: String, Sendable {
        case popular = "popularity.desc"
        case rated = "vote_average.desc"
        /// The most voted on: the best known of their time.
        case votes = "vote_count.desc"
    }

    /// Where a special streams: a TMDB watch provider in a region.
    struct Streaming: Equatable, Sendable {
        var provider: Int
        var region: String
    }

    /// One page (twenty) of specials with that keyword, released in a
    /// window (open at the start when `start` is nil), in an order; rated
    /// lists can ask for enough votes to mean something. With `streaming`,
    /// only specials included with that service's subscription.
    func specials(keyword: Int, from start: Date?, to end: Date, order: Order = .popular, minimumVotes: Int = 0, streaming: Streaming? = nil, page: Int = 1) async throws -> [TMDBSpecial] {
        let results: Page<TMDBSpecial> = try await get("discover/movie", Self.discoverQuery(keyword: keyword, from: start, to: end, order: order, minimumVotes: minimumVotes, streaming: streaming, page: page))
        return results.results
    }

    static func discoverQuery(keyword: Int, from start: Date?, to end: Date, order: Order, minimumVotes: Int, streaming: Streaming? = nil, page: Int) -> [String: String] {
        var query = [
            "with_keywords": String(keyword),
            "primary_release_date.lte": day(end),
            "sort_by": order.rawValue,
            "include_adult": "false",
            "include_video": "false",
            "language": "en-US",
            "page": String(page),
        ]
        if let start {
            query["primary_release_date.gte"] = day(start)
        }
        if minimumVotes > 0 {
            query["vote_count.gte"] = String(minimumVotes)
        }
        if let streaming {
            query["with_watch_providers"] = String(streaming.provider)
            query["watch_region"] = streaming.region
            query["with_watch_monetization_types"] = "flatrate"
        }
        return query
    }

    /// A streaming service, as TMDB lists them.
    struct WatchProvider: Decodable, Equatable, Sendable {
        var id: Int
        var name: String
        /// Lower is more widely used in the region.
        var priority: Int?

        enum CodingKeys: String, CodingKey {
            case id = "provider_id"
            case name = "provider_name"
            case priority = "display_priority"
        }
    }

    /// The streaming services TMDB knows in a region.
    func watchProviders(region: String) async throws -> [WatchProvider] {
        let page: Page<WatchProvider> = try await get("watch/providers/movie", ["watch_region": region, "language": "en-US"])
        return page.results
    }

    /// Browse's services, in this order, where the region has them: the
    /// ones that carry most stand-up specials.
    static let streamingPicks: [[String]] = [["netflix"], ["hbo max", "max"], ["prime video"], ["hulu"], ["peacock"], ["paramount"]]

    /// `streamingPicks` among TMDB's providers: each the most used match,
    /// leaving out add-on channels and ad tiers.
    static func streamingServices(from providers: [WatchProvider]) -> [BrowseCategory] {
        let candidates = providers
            .filter { !$0.name.localizedCaseInsensitiveContains("channel") && !$0.name.localizedCaseInsensitiveContains("with ads") }
            .sorted { ($0.priority ?? .max) < ($1.priority ?? .max) }
        var seen = Set<Int>()
        return streamingPicks.compactMap { picks in
            let match = candidates.first { provider in
                let name = provider.name.lowercased()
                // A short pick ("max") must be the whole name.
                return picks.contains { $0.count <= 3 ? name == $0 : name.contains($0) }
            }
            guard let match, seen.insert(match.id).inserted else { return nil }
            return .streaming(id: match.id, name: match.name)
        }
    }

    /// The comedian of a special whose title doesn't name them.
    func comedian(ofSpecial id: Int) async throws -> String? {
        let credits: Credits = try await get("movie/\(id)/credits")
        return credits.headliner
    }

    /// The cheapest request that needs a working key (Settings' check).
    func check() async throws {
        let _: Page<Keyword> = try await get("search/keyword", ["query": "stand-up comedy"])
    }

    // MARK: Dates

    private static let dayStyle = Date.ISO8601FormatStyle(timeZone: TimeZone(identifier: "UTC")!).year().month().day()

    /// "2025-03-04", as TMDB writes dates.
    static func day(_ date: Date) -> String {
        date.formatted(dayStyle)
    }

    static func day(from text: String) -> Date? {
        try? Date(text, strategy: dayStyle)
    }
}
