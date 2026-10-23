import Foundation

/// TMDB's stand-up specials for Home before any service matches them: each
/// shelf's list and the comedian behind each special. The Apple Music and
/// Spotify catalogs each find their own versions.
protocol TMDBListing: Sendable {
    /// How TMDB is reached: Standup's relay, or the person's own key. Nil
    /// when neither is there, and then nothing is listed.
    var access: TMDBAccess? { get }
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

/// `TMDBListing` from TMDB, with answers kept for ten minutes. A request
/// already on its way is shared, not made again (Home's shelves and
/// Trending Comedians ask for the same lists at once).
actor TMDBDiscovery: TMDBListing {
    private let keys: any KeyStoring
    private let relay: URL?
    private var cache = ResponseCache(lifetime: 10 * 60)

    /// Through `relay` when the build has one; otherwise with the key
    /// Settings keeps.
    init(keys: any KeyStoring, relay: URL? = TMDBAccess.builtInRelay()) {
        self.keys = keys
        self.relay = relay
    }

    nonisolated var access: TMDBAccess? {
        if let relay { return .relay(relay) }
        return keys.load().map(TMDBAccess.key)
    }

    /// Where streaming services are looked up: the device's region.
    nonisolated let region = Locale.current.region?.identifier ?? "US"

    /// Three pages of twenty (two for the best rated, which need fifty
    /// votes to count), asked for together.
    func specials(for shelf: DiscoverShelf) async throws -> [TMDBSpecial] {
        guard let access else { return [] }
        let client = TMDBClient(access: access)
        return try await cached("list:\(shelf.rawValue):\(access.cacheID)") {
            let keyword = try await self.keyword(client)
            let now = Date.now
            return try await Self.pages(shelf == .essential ? 2 : 3) { page in
                switch shelf {
                case .new:
                    return try await client.specials(keyword: keyword, from: now.addingTimeInterval(-365 * 86_400), to: now, page: page)
                case .popular:
                    return try await client.specials(keyword: keyword, from: now.addingTimeInterval(-3 * 365 * 86_400), to: now, page: page)
                case .essential:
                    return try await client.specials(keyword: keyword, from: nil, to: now, order: .rated, minimumVotes: 50, page: page)
                }
            }
        }
    }

    func comedianName(of special: TMDBSpecial) async -> String? {
        if let comedian = special.titleParts?.comedian {
            return comedian
        }
        guard let access else { return nil }
        let client = TMDBClient(access: access)
        return try? await cached("comedian:\(special.id)") { try await client.comedian(ofSpecial: special.id) }
    }

    /// Up to 24, one per comedian, most popular first. Names TMDB has to
    /// be asked for (titles without one) are asked for twelve specials at a
    /// time, until there are enough.
    func trendingNames() async -> [String] {
        async let new = specials(for: .new)
        async let popular = specials(for: .popular)
        var ranked = ArraySlice((((try? await new) ?? []) + ((try? await popular) ?? [])).sorted { $0.popularity > $1.popularity })
        var names: [String] = []
        var seen = Set<String>()
        while names.count < 24, !ranked.isEmpty {
            let batch = Array(ranked.prefix(12))
            ranked = ranked.dropFirst(12)
            let found = await inOrder(batch, width: 6) { [self] special in
                await comedianName(of: special)
            }
            for name in found where names.count < 24 && seen.insert(SpecialMatcher.normalized(name)).inserted {
                names.append(name)
            }
        }
        return names
    }

    func streamingServices() async throws -> [BrowseCategory] {
        guard let access else { return [] }
        let client = TMDBClient(access: access), region = self.region
        return try await cached("services:\(region):\(access.cacheID)") {
            TMDBClient.streamingServices(from: try await client.watchProviders(region: region))
        }
    }

    /// Two pages of twenty, asked for together.
    func specials(in category: BrowseCategory) async throws -> [TMDBSpecial] {
        guard let access else { return [] }
        let client = TMDBClient(access: access), region = self.region
        return try await cached("browse:\(category.id):\(region):\(access.cacheID)") {
            let keyword = try await self.keyword(client)
            let now = Date.now
            return try await Self.pages(2) { page in
                switch category {
                case .streaming(let id, _, _):
                    return try await client.specials(keyword: keyword, from: nil, to: now, streaming: .init(provider: id, region: region), page: page)
                case .decade(let start):
                    let (from, to) = Self.window(ofDecade: start, now: now)
                    return try await client.specials(keyword: keyword, from: from, to: to, order: .votes, page: page)
                }
            }
        }
    }

    /// TMDB's stand-up keyword, asked for once.
    private func keyword(_ client: TMDBClient) async throws -> Int {
        try await cached("keyword:\(client.access.cacheID)") { try await client.standUpKeywordID() }
    }

    /// Pages 1 through `count` of a list, asked for together, in page
    /// order without repeats.
    static func pages(_ count: Int, _ page: @escaping @Sendable (Int) async throws -> [TMDBSpecial]) async throws -> [TMDBSpecial] {
        let pages = try await withThrowingTaskGroup(of: (Int, [TMDBSpecial]).self) { group in
            for number in 1...count {
                group.addTask { (number, try await page(number)) }
            }
            var pages: [Int: [TMDBSpecial]] = [:]
            for try await (number, specials) in group {
                pages[number] = specials
            }
            return pages
        }
        var seen = Set<Int>()
        return (1...count).flatMap { pages[$0] ?? [] }.filter { seen.insert($0.id).inserted }
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
        // Already on its way: wait for that answer. If that load was
        // cancelled (its screen went away) and this ask wasn't, load here.
        if cache.isLoading(key) {
            do {
                let shared = try await withCheckedThrowingContinuation { cache.wait(for: key, $0) }
                if let shared = shared as? Value {
                    return shared
                }
            } catch let error where ResponseCache.isCancellation(error) && !Task.isCancelled {}
        }
        cache.startLoading(key)
        do {
            let value = try await load()
            cache.finishLoading(key, with: .success(value))
            return value
        } catch {
            cache.finishLoading(key, with: .failure(error))
            throw error
        }
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
