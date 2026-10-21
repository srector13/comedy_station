import Foundation

/// TMDB's stand-up specials for Home before any service matches them: each
/// shelf's list and the comedian behind each special. The Apple Music and
/// Spotify catalogs each find their own versions.
protocol TMDBListing: Sendable {
    /// The person's TMDB key, from Settings; nothing is listed without one.
    var key: String? { get }
    /// A shelf's specials, most popular (or best rated) first.
    func specials(for shelf: DiscoverShelf) async throws -> [TMDBSpecial]
    /// The comedian a special names before its colon, or else its
    /// headliner from TMDB's credits.
    func comedianName(of special: TMDBSpecial) async -> String?
    /// The comedians behind new and popular specials, most popular first.
    func trendingNames() async -> [String]
    /// Browse's streaming services, where the person is.
    func streamingServices() async throws -> [BrowseCategory]
    /// A Browse list's specials: most popular on a service, or the best
    /// known of a decade.
    func specials(in category: BrowseCategory) async throws -> [TMDBSpecial]
}

/// `TMDBListing` from TMDB, with answers kept for ten minutes.
actor TMDBDiscovery: TMDBListing {
    private let keys: any KeyStoring
    private var cache = ResponseCache(lifetime: 10 * 60)

    init(keys: any KeyStoring) {
        self.keys = keys
    }

    nonisolated var key: String? {
        keys.load()
    }

    /// Where streaming services are looked up: the device's region.
    nonisolated let region = Locale.current.region?.identifier ?? "US"

    /// Three pages of twenty (two for the best rated, which need fifty
    /// votes to count).
    func specials(for shelf: DiscoverShelf) async throws -> [TMDBSpecial] {
        guard let key else { return [] }
        let client = TMDBClient(key: key)
        return try await cached("list:\(shelf.rawValue):\(key)") {
            let keyword = try await self.cached("keyword:\(key)") { try await client.standUpKeywordID() }
            let now = Date.now
            var specials: [TMDBSpecial] = []
            switch shelf {
            case .new:
                for page in 1...3 {
                    specials += try await client.specials(keyword: keyword, from: now.addingTimeInterval(-365 * 86_400), to: now, page: page)
                }
            case .popular:
                for page in 1...3 {
                    specials += try await client.specials(keyword: keyword, from: now.addingTimeInterval(-3 * 365 * 86_400), to: now, page: page)
                }
            case .essential:
                for page in 1...2 {
                    specials += try await client.specials(keyword: keyword, from: nil, to: now, order: .rated, minimumVotes: 50, page: page)
                }
            }
            var seen = Set<Int>()
            return specials.filter { seen.insert($0.id).inserted }
        }
    }

    func comedianName(of special: TMDBSpecial) async -> String? {
        if let comedian = special.titleParts?.comedian {
            return comedian
        }
        guard let key else { return nil }
        let client = TMDBClient(key: key)
        return try? await cached("comedian:\(special.id)") { try await client.comedian(ofSpecial: special.id) }
    }

    /// Up to 24, one per comedian.
    func trendingNames() async -> [String] {
        let new = (try? await specials(for: .new)) ?? []
        let popular = (try? await specials(for: .popular)) ?? []
        var names: [String] = []
        var seen = Set<String>()
        for special in (new + popular).sorted(by: { $0.popularity > $1.popularity }) where names.count < 24 {
            if let name = await comedianName(of: special), seen.insert(SpecialMatcher.normalized(name)).inserted {
                names.append(name)
            }
        }
        return names
    }

    func streamingServices() async throws -> [BrowseCategory] {
        guard let key else { return [] }
        let client = TMDBClient(key: key), region = self.region
        return try await cached("services:\(region):\(key)") {
            TMDBClient.streamingServices(from: try await client.watchProviders(region: region))
        }
    }

    /// Two pages of twenty.
    func specials(in category: BrowseCategory) async throws -> [TMDBSpecial] {
        guard let key else { return [] }
        let client = TMDBClient(key: key)
        return try await cached("browse:\(category.id):\(region):\(key)") {
            let keyword = try await self.cached("keyword:\(key)") { try await client.standUpKeywordID() }
            let now = Date.now
            var specials: [TMDBSpecial] = []
            for page in 1...2 {
                switch category {
                case .streaming(let id, _):
                    specials += try await client.specials(keyword: keyword, from: nil, to: now, streaming: .init(provider: id, region: region), page: page)
                case .decade(let start):
                    let (from, to) = Self.window(ofDecade: start, now: now)
                    specials += try await client.specials(keyword: keyword, from: from, to: to, order: .votes, page: page)
                }
            }
            var seen = Set<Int>()
            return specials.filter { seen.insert($0.id).inserted }
        }
    }

    /// January 1 of the decade's first year to December 31 of its last, or
    /// today for this decade.
    static func window(ofDecade start: Int, now: Date = .now) -> (Date, Date) {
        let from = TMDBClient.day(from: "\(start)-01-01") ?? now
        let to = TMDBClient.day(from: "\(start + 9)-12-31") ?? now
        return (from, min(to, now))
    }

    private func cached<Value: Sendable>(_ key: String, load: () async throws -> Value) async throws -> Value {
        if let hit: Value = cache.value(for: key) {
            return hit
        }
        let value = try await load()
        cache.store(value, for: key)
        return value
    }
}

/// `transform` over `items`, `width` at a time, with the results in the
/// items' order (nil results left out).
func inOrder<Item: Sendable, Value: Sendable>(
    _ items: [Item], width: Int, _ transform: @escaping @Sendable (Item) async -> Value?
) async -> [Value] {
    var found: [Int: Value] = [:]
    await withTaskGroup(of: (Int, Value?).self) { group in
        var next = 0
        func addNext() {
            guard next < items.count else { return }
            let index = next, item = items[index]
            group.addTask { (index, await transform(item)) }
            next += 1
        }
        for _ in 0..<max(width, 1) { addNext() }
        for await (index, value) in group {
            found[index] = value
            addNext()
        }
    }
    return items.indices.compactMap { found[$0] }
}
