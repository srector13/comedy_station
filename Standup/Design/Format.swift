import Foundation

/// Text for durations, dates and counts.
enum Format {
    /// "4:32", or "1:02:03" past an hour.
    static func trackTime(_ seconds: TimeInterval?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "" }
        let duration = Duration.seconds(seconds.rounded())
        return seconds >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond))
    }

    /// A special's length: "52 minutes", "1 hour, 4 minutes".
    static func runtime(_ seconds: TimeInterval) -> String {
        let minutes = (seconds / 60).rounded()
        return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }

    static func bitCount(_ count: Int) -> String {
        count == 1 ? "1 bit" : "\(count) bits"
    }

    static func year(_ date: Date?) -> String? {
        date?.formatted(.dateTime.year())
    }

    /// "August 15, 2025".
    static func longDate(_ date: Date?) -> String? {
        date?.formatted(date: .long, time: .omitted)
    }

    /// Editorial notes can carry markup (<i>, <br>); the app shows plain text.
    static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<br ?/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A page's content while it loads.
enum LoadState<Value> {
    case loading
    case loaded(Value)
    case failed(String)

    var value: Value? {
        if case .loaded(let value) = self { value } else { nil }
    }
}
