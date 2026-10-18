import Foundation

/// Responses by key, each kept for `lifetime` seconds.
struct ResponseCache {
    let lifetime: TimeInterval
    var maximumCount = 200
    private var entries: [String: (stored: Date, value: any Sendable)] = [:]

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
}
