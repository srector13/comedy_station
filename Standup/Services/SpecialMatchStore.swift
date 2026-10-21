import Foundation

/// TMDB specials already matched to their albums on a service, or found to
/// have none, kept between launches so Home fills in quickly. A match is
/// trusted for a month; a miss is tried again after a few days, since the
/// audio often comes out after the video.
struct SpecialMatchStore: Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var album: ComedyAlbum?
        var checked: Date
    }

    static let matchLifetime: TimeInterval = 30 * 86_400
    static let missLifetime: TimeInterval = 3 * 86_400

    /// In Caches: losing it only means matching again.
    static var defaultURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TMDBMatches-v1.json")
    }

    /// The Spotify route's matches, kept apart from Apple Music's.
    static var spotifyURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TMDBMatches-spotify-v1.json")
    }

    let url: URL?
    private(set) var entries: [String: Entry] = [:]

    init(url: URL?) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url),
           let saved = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = saved
        }
    }

    /// The known answer for a special: `.some(album)`, `.some(nil)` for a
    /// recent miss, or nil when it has to be looked up.
    func lookup(_ specialID: Int, now: Date = .now) -> ComedyAlbum?? {
        guard let entry = entries[String(specialID)] else { return nil }
        let lifetime = entry.album == nil ? Self.missLifetime : Self.matchLifetime
        guard now.timeIntervalSince(entry.checked) < lifetime else { return nil }
        return .some(entry.album)
    }

    mutating func record(_ album: ComedyAlbum?, for specialID: Int, now: Date = .now) {
        entries[String(specialID)] = Entry(album: album, checked: now)
    }

    func save() {
        guard let url, let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
