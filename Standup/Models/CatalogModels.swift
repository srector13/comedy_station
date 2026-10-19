import Foundation

/// Anything the comedy filter can judge by its genre names.
protocol GenreTagged {
    var genreNames: [String] { get }
}

/// Artwork for a catalog item: an Apple Music URL template, or, with no
/// template (mock data, items without art), a generated placeholder.
struct ArtworkRef: Hashable, Sendable, Codable {
    /// An Apple Music artwork URL with `{w}` and `{h}` for the pixel size.
    var template: String?
    /// The artwork's average color as 0xRRGGBB, for tinted backgrounds.
    var backgroundRGB: Int?
    /// Picks the generated placeholder's colors. Stable for an item ID.
    var seed: UInt32 = 0

    init(template: String? = nil, backgroundRGB: Int? = nil, seed: UInt32 = 0) {
        self.template = template
        self.backgroundRGB = backgroundRGB
        self.seed = seed
    }

    /// Generated artwork seeded from `id`.
    init(generatedFor id: String) {
        self.init(seed: Self.seed(for: id))
    }

    func url(side: Int) -> URL? {
        guard let template else { return nil }
        return URL(string: template
            .replacingOccurrences(of: "{w}", with: "\(side)")
            .replacingOccurrences(of: "{h}", with: "\(side)"))
    }

    /// The template for an artwork URL MusicKit formatted at 1111×1111 px
    /// (`Artwork.url(width:height:)`), so any size can be asked for later.
    static func template(fromProbe url: String) -> String {
        url.replacingOccurrences(of: "1111x1111", with: "{w}x{h}")
    }

    static let probeSide = 1111

    /// FNV-1a, so the seed is the same on every launch (Hasher isn't).
    static func seed(for id: String) -> UInt32 {
        id.utf8.reduce(2_166_136_261) { ($0 ^ UInt32($1)) &* 16_777_619 }
    }
}

/// A comedian (an Apple Music artist).
struct ComedyArtist: Identifiable, Hashable, Sendable, Codable, GenreTagged {
    /// The `MusicItemID` raw value.
    var id: String
    var name: String
    var artwork: ArtworkRef
    var genreNames: [String]
}

/// A special (an Apple Music album).
struct ComedyAlbum: Identifiable, Hashable, Sendable, Codable, GenreTagged {
    var id: String
    var title: String
    var artistName: String
    /// Known once the album's artists are loaded (album pages).
    var artistID: String?
    var artwork: ArtworkRef
    var releaseDate: Date?
    var trackCount: Int
    var genreNames: [String]
    var isExplicit: Bool = false
}

/// A bit (an Apple Music song on a special).
struct ComedyTrack: Identifiable, Hashable, Sendable, Codable, GenreTagged {
    var id: String
    var title: String
    var artistName: String
    var albumID: String?
    var albumTitle: String?
    var duration: TimeInterval?
    var trackNumber: Int?
    var artwork: ArtworkRef
    var isExplicit: Bool = false
    /// The genre names of the album the bit is on. A bit counts as comedy
    /// only when its album does.
    var albumGenreNames: [String]

    var genreNames: [String] { albumGenreNames }

    /// The special this bit is on, as far as the bit knows it; its page
    /// loads the rest.
    var albumStub: ComedyAlbum? {
        guard let albumID else { return nil }
        return ComedyAlbum(
            id: albumID, title: albumTitle ?? title, artistName: artistName,
            artwork: artwork, trackCount: 0, genreNames: albumGenreNames
        )
    }
}

/// Everything an album page shows.
struct AlbumDetail: Hashable, Sendable {
    var album: ComedyAlbum
    var tracks: [ComedyTrack]
    var editorialNotes: String?
    var copyright: String?

    var totalDuration: TimeInterval {
        tracks.compactMap(\.duration).reduce(0, +)
    }
}

/// Everything an artist page shows.
struct ArtistDetail: Hashable, Sendable {
    var artist: ComedyArtist
    /// The latest special, shown in its own card.
    var featured: ComedyAlbum?
    /// Newest first.
    var specials: [ComedyAlbum]
    var topBits: [ComedyTrack]
    var similar: [ComedyArtist]
}

/// A comedy playlist. Playlists carry no genre names, so the app only
/// shows ones from the Comedy-genre chart, and filters their bits.
struct ComedyPlaylist: Identifiable, Hashable, Sendable, Codable {
    var id: String
    var name: String
    var curatorName: String?
    var artwork: ArtworkRef
    var summary: String?
}

struct PlaylistDetail: Hashable, Sendable {
    var playlist: ComedyPlaylist
    /// Only the bits on comedy specials.
    var tracks: [ComedyTrack]
}

/// The Comedy charts (genre 3), filtered.
struct ComedyCharts: Hashable, Sendable {
    /// Where a section came from: TMDB's most popular stand-up specials,
    /// Apple's Comedy chart (ranked by plays), or, when neither had any,
    /// catalog searches for comedy (not ranked).
    enum Source: Hashable, Sendable {
        case popular, chart, search
    }

    /// Most popular (TMDB) or most played (Apple) specials, in rank order.
    var topSpecials: [ComedyAlbum] = []
    /// Specials out in the last few months, from TMDB, newest first. Empty
    /// without a TMDB key.
    var newReleases: [ComedyAlbum] = []
    /// Most played bits, in chart order.
    var topBits: [ComedyTrack] = []
    var playlists: [ComedyPlaylist] = []
    var specialsSource = Source.chart
    var bitsSource = Source.chart

    var specialsTitle: String {
        switch specialsSource {
        case .popular: "Popular Specials"
        case .chart: "Top Specials"
        case .search: "Comedy Specials"
        }
    }

    var bitsTitle: String {
        bitsSource == .chart ? "Top Bits" : "Comedy Bits"
    }

    /// The rank to show beside the n-th special, only when it is ranked.
    func specialRank(_ position: Int) -> Int? {
        specialsSource == .search ? nil : position
    }

    /// The rank to show beside the n-th bit, only when it is a chart.
    func bitRank(_ position: Int) -> Int? {
        bitsSource == .chart ? position : nil
    }

    /// TMDB's new releases, or else charted specials from the last two
    /// years, newest first: MusicKit has no new-releases-by-genre request.
    func newSpecials(now: Date = .now) -> [ComedyAlbum] {
        guard newReleases.isEmpty else { return newReleases }
        let cutoff = now.addingTimeInterval(-2 * 365 * 86_400)
        return topSpecials
            .filter { ($0.releaseDate ?? .distantPast) >= cutoff }
            .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
    }

    var isEmpty: Bool { topSpecials.isEmpty && topBits.isEmpty && playlists.isEmpty && newReleases.isEmpty }
}

/// Home's shelves of specials from TMDB, as their Apple Music versions.
enum DiscoverShelf: String, CaseIterable, Sendable {
    /// Out in the last year, newest first.
    case new
    /// Most watched lately (the last three years), most popular first.
    case popular
    /// Best rated of all time.
    case essential

    var title: String {
        switch self {
        case .new: "New Specials"
        case .popular: "Popular Specials"
        case .essential: "Essential Specials"
        }
    }
}

struct SearchResults: Hashable, Sendable {
    var comedians: [ComedyArtist] = []
    var specials: [ComedyAlbum] = []
    var bits: [ComedyTrack] = []

    var isEmpty: Bool { comedians.isEmpty && specials.isEmpty && bits.isEmpty }

    /// Comedians and specials found: what a name search is after.
    var headlineCount: Int { comedians.count + specials.count }

    /// Adds another search's results after these, skipping any already here.
    mutating func merge(_ other: SearchResults) {
        func appendNew<Item: Identifiable>(_ items: [Item], to list: inout [Item]) {
            var seen = Set(list.map(\.id))
            for item in items where seen.insert(item.id).inserted {
                list.append(item)
            }
        }
        appendNew(other.comedians, to: &comedians)
        appendNew(other.specials, to: &specials)
        appendNew(other.bits, to: &bits)
    }
}

/// An as-you-type suggestion: a catalog hit that passed the comedy filter.
enum SearchSuggestion: Identifiable, Hashable, Sendable, GenreTagged {
    case comedian(ComedyArtist)
    case special(ComedyAlbum)

    var id: String {
        switch self {
        case .comedian(let artist): "artist:\(artist.id)"
        case .special(let album): "album:\(album.id)"
        }
    }

    var title: String {
        switch self {
        case .comedian(let artist): artist.name
        case .special(let album): album.title
        }
    }

    var subtitle: String {
        switch self {
        case .comedian: "Comedian"
        case .special(let album): "Special · \(album.artistName)"
        }
    }

    var artwork: ArtworkRef {
        switch self {
        case .comedian(let artist): artist.artwork
        case .special(let album): album.artwork
        }
    }

    var genreNames: [String] {
        switch self {
        case .comedian(let artist): artist.genreNames
        case .special(let album): album.genreNames
        }
    }
}

/// Anything the App Library can hold.
enum LibraryItem: Hashable, Sendable {
    case comedian(ComedyArtist)
    case special(ComedyAlbum)
    case bit(ComedyTrack)

    var id: String {
        switch self {
        case .comedian(let artist): artist.id
        case .special(let album): album.id
        case .bit(let track): track.id
        }
    }
}
