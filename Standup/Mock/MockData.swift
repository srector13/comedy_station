import Foundation

/// Fictional comedians and specials for previews, tests and CI screenshots.
/// The decoys (a pop artist, a soundtrack titled "Comedy of Errors", a pop
/// compilation carrying a comedy bit) aren't comedy by genre, so the comedy
/// filter must drop them everywhere.
enum MockData {
    static let comedians: [ComedyArtist] = [
        artist("maya", "Maya Okafor", ["Comedy", "Music"]),
        artist("dev", "Dev Raman", ["Stand-Up Comedy", "Comedy"]),
        artist("lou", "Lou Petrakis", ["Comedy"]),
        artist("rosa", "Rosa Delgado", ["Comedy"]),
        artist("sam", "Sam Whitlock", ["comedy"]),
        artist("jenna", "Jenna Albright", ["Comedy"]),
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

    /// Each special's bits, by album ID.
    static let tracks: [String: [ComedyTrack]] = Dictionary(uniqueKeysWithValues: albums.map { album in
        (album.id, bits(for: album))
    })

    /// Similar comedians by artist ID, decoys included so the filter shows.
    static func similar(to artistID: String) -> [ComedyArtist] {
        comedians.filter { $0.id != artistID }
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
