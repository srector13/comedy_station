import Foundation

/// Fictional comedians and specials for previews, tests and CI screenshots.
/// The decoys (a pop artist, a soundtrack titled "Comedy of Errors", a pop
/// compilation carrying a comedy bit) aren't comedy by genre, so the comedy
/// filter must drop them everywhere. Rick Alvarez is filed under books, but
/// his comedy special makes him a comedian.
enum MockData {
    static let comedians: [ComedyArtist] = [
        artist("maya", "Maya Okafor", ["Comedy", "Music"]),
        artist("dev", "Dev Raman", ["Stand-Up Comedy", "Comedy"]),
        artist("lou", "Lou Petrakis", ["Comedy"]),
        artist("rosa", "Rosa Delgado", ["Comedy"]),
        artist("sam", "Sam Whitlock", ["comedy"]),
        artist("jenna", "Jenna Albright", ["Comedy"]),
        // Filed under books, as Apple files some comedians: their comedy
        // special makes them one.
        artist("rick", "Rick Alvarez", ["Biographies & Memoirs"]),
        // Decoys.
        artist("nova", "Nova Rae", ["Pop", "Music"]),
        artist("pops", "City Pops Orchestra", ["Soundtrack"]),
    ]

    static let albums: [ComedyAlbum] = [
        album("lower", "Lower Your Expectations", "maya", "2025-08-15", 11),
        album("groupchat", "Group Chat Energy", "maya", "2022-03-04", 9),
        album("parking", "Parking Lot Philosophy", "dev", "2024-11-01", 10),
        album("smalltalk", "Small Talk, Big Feelings", "dev", "2021-06-18", 8),
        album("laundromat", "Live from the Laundromat", "lou", "2023-09-29", 12),
        album("leftovers", "Leftovers", "rosa", "2025-02-14", 10),
        album("momsaid", "Mom Said It Was Fine", "rosa", "2020-10-09", 9),
        album("overthinking", "Overthinking It", "sam", "2024-04-26", 11),
        album("customer", "Customer Service Voice", "jenna", "2023-01-20", 9),
        album("memoir", "Mostly True Stories", "rick", "2022-09-16", 8),
        // Decoys.
        album("arena", "Live at the Arena", "nova", "2024-07-12", 14, genres: ["Pop", "Music"]),
        album("errors", "Comedy of Errors (Original Score)", "pops", "2019-05-03", 16, genres: ["Soundtrack"]),
        album("summer", "Summer Hits", "nova", "2024-06-01", 3, genres: ["Pop"]),
    ]

    static let editorialNotes: [String: String] = [
        album("lower"): "Recorded over two sold-out nights, Maya Okafor's third hour turns small humiliations (self-checkout, a landlord who texts in all caps, a family group chat that never sleeps) into a set that builds like a single, very long story.",
        album("parking"): "Dev Raman's hour about the places we wait: parking lots, airport gates, and the DMV, where he finally finds inner peace.",
        album("laundromat"): "Taped in an actual laundromat, between spin cycles.",
    ]

    /// Comedy-genre chart playlists. "Clean Comedy" carries a pop song,
    /// which the playlist page must drop.
    static let playlists: [ComedyPlaylist] = [
        playlist("essentials", "Stand-Up Essentials", "The sets every comedy fan should know."),
        playlist("clean", "Clean Comedy", "Laughs for the whole car."),
        playlist("crowdwork", "Crowd Work", "When the front row talks back."),
        playlist("new", "New in Comedy", "Fresh specials, updated weekly."),
    ]

    /// Each playlist's bits by ID, decoys included.
    static func playlistTracks(_ id: String) -> [ComedyTrack] {
        let picks: [(String, Int)] = switch id {
        case "mock-pl-essentials": [("lower", 2), ("parking", 1), ("laundromat", 3), ("leftovers", 4), ("customer", 2), ("overthinking", 5)]
        case "mock-pl-clean": [("smalltalk", 2), ("summer", 0), ("momsaid", 3), ("groupchat", 1)]
        case "mock-pl-crowdwork": [("laundromat", 1), ("parking", 4), ("lower", 6)]
        default: [("lower", 1), ("leftovers", 2), ("parking", 3)]
        }
        return picks.compactMap { tracks[album($0.0)]?[safe: $0.1] }
    }

    /// The Comedy chart as Apple would return it: mostly comedy, plus the
    /// decoys (a pop album, a soundtrack, a pop compilation's bit).
    static let chartAlbumIDs = ["lower", "parking", "arena", "leftovers", "laundromat", "overthinking", "errors", "customer", "groupchat", "smalltalk", "momsaid"].map { album($0) }
    static let chartBitPicks: [(String, Int)] = [("lower", 3), ("parking", 2), ("summer", 0), ("leftovers", 1), ("laundromat", 4), ("overthinking", 2), ("customer", 3), ("groupchat", 5), ("lower", 7)]

    /// Each special's bits, by album ID.
    static let tracks: [String: [ComedyTrack]] = Dictionary(uniqueKeysWithValues: albums.map { album in
        (album.id, bits(for: album))
    })

    /// Similar comedians by artist ID, decoys included so the filter shows.
    static func similar(to artistID: String) -> [ComedyArtist] {
        comedians.filter { $0.id != artistID }
    }

    /// A filled App Library (`-StandupLibrary seeded`, previews): a few of
    /// each kind, added over the past weeks, newest first.
    static var librarySeed: [(LibraryItem, Date)] {
        let now = Date(timeIntervalSince1970: 1_792_000_000) // fixed, so screenshots don't drift
        let day: TimeInterval = 86_400
        var items: [LibraryItem] = []
        items += ["mock-al-lower", "mock-al-parking", "mock-al-leftovers", "mock-al-customer", "mock-al-laundromat"]
            .compactMap(album(id:)).map(LibraryItem.special)
        items += ["mock-ar-maya", "mock-ar-dev", "mock-ar-rosa"].compactMap(artist(id:)).map(LibraryItem.comedian)
        items += [("mock-al-overthinking", 3), ("mock-al-groupchat", 2), ("mock-al-momsaid", 5)]
            .compactMap { tracks[$0.0]?[$0.1] }.map(LibraryItem.bit)
        return items.enumerated().map { index, item in (item, now - Double(index) * 2.5 * day) }
    }

    /// Specials left partway, for Continue Listening (seeded library).
    static var progressSeed: [ProgressSnapshot] {
        let now = Date(timeIntervalSince1970: 1_792_000_000)
        return [("mock-al-lower", 3, 95.0, 0.36, 0.0), ("mock-al-parking", 6, 40.0, 0.71, 3600.0), ("mock-al-laundromat", 1, 30.0, 0.12, 7200.0)]
            .compactMap { id, index, position, fraction, ago in
                guard let album = album(id: id) else { return nil }
                let total = (tracks[id] ?? []).compactMap(\.duration).reduce(0, +)
                return ProgressSnapshot(
                    itemID: id, isAlbum: true, lastTrackIndex: index, lastPosition: position,
                    lastPlayed: now - ago, finished: false, fractionComplete: fraction,
                    title: album.title, artistName: album.artistName, artwork: album.artwork,
                    trackCount: album.trackCount, totalDuration: total
                )
            }
    }

    static func artist(id: String) -> ComedyArtist? {
        comedians.first { $0.id == id }
    }

    static func album(id: String) -> ComedyAlbum? {
        albums.first { $0.id == id }
    }

    // MARK: Building

    private static let bitTitles = [
        "Cold Open", "Self-Checkout", "My Landlord Texts in Caps", "Airport Security", "The Family Group Chat",
        "Dating Apps Are a Job", "My Dad Discovered Voice Memos", "Gym Membership", "The Wedding Toast",
        "Therapy, Season Two", "Customer Service Voice", "Parallel Parking", "The DMV", "Smart Fridge",
        "Jury Duty", "Brunch", "Group Projects", "My Mom's Facebook", "Hotel Breakfast", "Closing",
        "Leftovers", "Neighbors", "Car Rental Upsell", "Wellness Retreat", "Fantasy Football",
    ]

    private static func playlist(_ slug: String, _ name: String, _ summary: String) -> ComedyPlaylist {
        let id = "mock-pl-\(slug)"
        return ComedyPlaylist(id: id, name: name, curatorName: "Standup Samples", artwork: ArtworkRef(generatedFor: id), summary: summary)
    }

    private static func artist(_ slug: String, _ name: String, _ genres: [String]) -> ComedyArtist {
        let id = "mock-ar-\(slug)"
        return ComedyArtist(id: id, name: name, artwork: ArtworkRef(generatedFor: id), genreNames: genres)
    }

    private static func album(_ slug: String) -> String { "mock-al-\(slug)" }

    private static func album(
        _ slug: String, _ title: String, _ artistSlug: String, _ date: String, _ count: Int,
        genres: [String] = ["Comedy"]
    ) -> ComedyAlbum {
        let id = album(slug)
        let artist = comedians.first { $0.id == "mock-ar-\(artistSlug)" }
        return ComedyAlbum(
            id: id, title: title, artistName: artist?.name ?? "Unknown", artistID: artist?.id,
            artwork: ArtworkRef(generatedFor: id),
            releaseDate: ISO8601DateFormatter().date(from: "\(date)T12:00:00Z"),
            trackCount: count, genreNames: genres, isExplicit: genres.contains("Comedy")
        )
    }

    private static func bits(for album: ComedyAlbum) -> [ComedyTrack] {
        if album.id == self.album("summer") {
            // A Maya Okafor bit on a pop compilation: not comedy by its album.
            return [track(on: album, number: 1, title: "Self-Checkout (Radio Edit)", artistName: "Maya Okafor", seconds: 190)]
        }
        let start = Int(album.artwork.seed % UInt32(bitTitles.count))
        return (0..<album.trackCount).map { index in
            let title = index == 0 ? "Intro" : bitTitles[(start + index) % bitTitles.count]
            let seconds = 120 + Int((album.artwork.seed >> UInt32(index % 16)) % 420)
            return track(on: album, number: index + 1, title: title, artistName: album.artistName, seconds: seconds)
        }
    }

    private static func track(on album: ComedyAlbum, number: Int, title: String, artistName: String, seconds: Int) -> ComedyTrack {
        ComedyTrack(
            id: "\(album.id)-\(number)", title: title, artistName: artistName,
            albumID: album.id, albumTitle: album.title, duration: TimeInterval(seconds), trackNumber: number,
            artwork: album.artwork, isExplicit: album.isExplicit, albumGenreNames: album.genreNames
        )
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
