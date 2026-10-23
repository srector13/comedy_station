import Foundation
import Observation

/// Where the TMDB key is kept.
protocol KeyStoring: Sendable {
    func load() -> String?
    func save(_ key: String?)
}

/// A key kept only while the app runs: mock mode, previews and tests.
final class MemoryKeyStore: KeyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

    init(_ key: String? = nil) {
        self.key = key
    }

    func load() -> String? {
        lock.withLock { key }
    }

    func save(_ key: String?) {
        lock.withLock { self.key = key }
    }
}

/// TMDB behind New and Popular Specials and Browse. A build with Standup's
/// relay (`TMDBAccess.relay`) needs nothing from the person. Without one,
/// they paste their own key here; a key is never built into the app, whose
/// release IPAs are public.
@MainActor
@Observable
final class SpecialsSettings {
    /// This build reaches TMDB through Standup's relay: no key needed.
    let isBuiltIn: Bool
    private(set) var hasKey: Bool
    /// Bumped when the key changes, so Home and Browse load again.
    private(set) var revision = 0

    @ObservationIgnored private let store: any KeyStoring
    /// Asks TMDB whether a key works before it's kept.
    @ObservationIgnored private let check: @Sendable (String) async throws -> Void

    init(store: any KeyStoring, builtIn: Bool = false, check: @escaping @Sendable (String) async throws -> Void) {
        self.store = store
        self.isBuiltIn = builtIn
        self.check = check
        hasKey = store.load() != nil
    }

    /// Whether Home and Browse can list TMDB's specials.
    var isAvailable: Bool {
        isBuiltIn || hasKey
    }

    /// Checks the key with TMDB, then keeps it.
    func save(_ key: String) async throws {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try await check(key)
        store.save(key)
        hasKey = true
        revision += 1
    }

    func remove() {
        store.save(nil)
        hasKey = false
        revision += 1
    }
}
