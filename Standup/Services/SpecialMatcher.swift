import Foundation

/// Finds a special's Apple Music version among catalog search results: the
/// same comedian, the same (or nearly the same) title, released around the
/// same time. A special with no such album isn't shown.
enum SpecialMatcher {
    /// The least title likeness that counts as the same special.
    static let threshold = 0.6
    /// Audio can come out well after the video, but not years apart.
    static let maximumGap: TimeInterval = 2 * 365 * 86_400

    static func best(comedian: String, title: String, released: Date?, in candidates: [ComedyAlbum]) -> ComedyAlbum? {
        let scored: [(album: ComedyAlbum, score: Double, gap: TimeInterval)] = candidates.compactMap { album in
            guard sameComedian(comedian, album.artistName) else { return nil }
            var gap: TimeInterval = 0
            if let released, let albumDate = album.releaseDate {
                gap = abs(albumDate.timeIntervalSince(released))
                guard gap <= maximumGap else { return nil }
            }
            let score = titleLikeness(title, album.title, comedian: comedian)
            guard score >= threshold else { return nil }
            return (album, score, gap)
        }
        return scored.max { a, b in
            a.score != b.score ? a.score < b.score : a.gap > b.gap
        }?.album
    }

    static func sameComedian(_ a: String, _ b: String) -> Bool {
        let x = normalized(a), y = normalized(b)
        guard !x.isEmpty, !y.isEmpty else { return false }
        return x == y || x.contains(y) || y.contains(x)
    }

    /// 1 for the same title, 0.9 when one holds the other, else the share of
    /// words in common. The comedian's name is ignored on both sides
    /// ("Nate Bargatze: Hello World" against "Hello World").
    static func titleLikeness(_ a: String, _ b: String, comedian: String = "") -> Double {
        let name = normalized(comedian)
        func clean(_ text: String) -> String {
            var text = normalized(text)
            if !name.isEmpty, text.hasPrefix(name + " "), text.count > name.count + 3 {
                text = String(text.dropFirst(name.count + 1))
            }
            return text
        }
        let x = clean(a), y = clean(b)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        if x == y { return 1 }
        if (x.count >= 4 && y.contains(x)) || (y.count >= 4 && x.contains(y)) { return 0.9 }
        let wordsX = Set(x.split(separator: " ")), wordsY = Set(y.split(separator: " "))
        return Double(wordsX.intersection(wordsY).count) / Double(wordsX.union(wordsY).count)
    }

    /// Lowercase letters and digits, single spaces: no accents, no
    /// punctuation, no "(Live)"-style asides, and no trailing "live".
    static func normalized(_ text: String) -> String {
        var text = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        text = text.replacingOccurrences(of: "&", with: " and ")
        text = text.replacingOccurrences(of: #"\([^)]*\)|\[[^\]]*\]"#, with: " ", options: .regularExpression)
        text = String(text.map { $0.isLetter || $0.isNumber ? $0 : " " })
        var words = text.split(separator: " ").map(String.init)
        if words.count > 1, words.last == "live" {
            words.removeLast()
        }
        return words.joined(separator: " ")
    }
}
