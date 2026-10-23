import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Responses by key, each kept for `lifetime` seconds, and the loads under
/// way, so an actor asked for the same thing twice at once makes one
/// request: the second ask waits for the first's answer.
///
///     if cache.isLoading(key) {
///         let shared = try await withCheckedThrowingContinuation { cache.wait(for: key, $0) }
///         if let shared = shared as? Value { return shared }
///     }
///     // (a waiter whose load was cancelled loads for itself)
///     cache.startLoading(key)
///     // load, then finishLoading(key, with:) with the value or the error
struct ResponseCache {
    let lifetime: TimeInterval
    var maximumCount = 200
    private var entries: [String: (stored: Date, value: any Sendable)] = [:]
    private var waiting: [String: [CheckedContinuation<any Sendable, any Error>]] = [:]

    init(lifetime: TimeInterval) {
        self.lifetime = lifetime
    }

    func value<Value>(for key: String, now: Date = .now) -> Value? {
        guard let entry = entries[key], now.timeIntervalSince(entry.stored) < lifetime else { return nil }
        return entry.value as? Value
    }

    mutating func store(_ value: any Sendable, for key: String, now: Date = .now) {
        if entries.count >= maximumCount {
            entries = entries.filter { now.timeIntervalSince($0.value.stored) < lifetime }
            if entries.count >= maximumCount, let oldest = entries.min(by: { $0.value.stored < $1.value.stored })?.key {
                entries[oldest] = nil
            }
        }
        entries[key] = (now, value)
    }

    // MARK: Loads under way

    /// Whether a load stopped because it was cancelled, not because it
    /// failed.
    static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    func isLoading(_ key: String) -> Bool {
        waiting[key] != nil
    }

    mutating func startLoading(_ key: String) {
        waiting[key] = []
    }

    /// Waits for the load under way to answer.
    mutating func wait(for key: String, _ continuation: CheckedContinuation<any Sendable, any Error>) {
        waiting[key, default: []].append(continuation)
    }

    /// Keeps a value, and answers everyone waiting for it (or tells them
    /// it failed).
    mutating func finishLoading(_ key: String, with result: Result<any Sendable, any Error>) {
        if case .success(let value) = result {
            store(value, for: key)
        }
        for continuation in waiting.removeValue(forKey: key) ?? [] {
            continuation.resume(with: result)
        }
    }
}
