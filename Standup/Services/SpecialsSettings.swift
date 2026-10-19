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

/// The TMDB key behind New and Popular Specials, as Settings edits it. The
/// person pastes their own; it's never built into the app, whose release
/// IPAs are public.
@MainActor
@Observable
final class SpecialsSettings {
    private(set) var hasKey: Bool
    /// Bumped when the key changes, so Home and Browse load again.
    private(set) var revision = 0

    @ObservationIgnored private let store: any KeyStoring
    /// Asks TMDB whether a key works before it's kept.
    @ObservationIgnored private let check: @Sendable (String) async throws -> Void

    init(store: any KeyStoring, check: @escaping @Sendable (String) async throws -> Void) {
        self.store = store
        self.check = check
        hasKey = store.load() != nil
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
