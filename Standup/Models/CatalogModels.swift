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
    /// Most played specials, in chart order.
    var topSpecials: [ComedyAlbum] = []
    /// Most played bits, in chart order.
    var topBits: [ComedyTrack] = []
    var playlists: [ComedyPlaylist] = []

    /// Charted specials from the last two years, newest first: MusicKit
    /// has no new-releases-by-genre request.
    func newSpecials(now: Date = .now) -> [ComedyAlbum] {
        let cutoff = now.addingTimeInterval(-2 * 365 * 86_400)
        return topSpecials
            .filter { ($0.releaseDate ?? .distantPast) >= cutoff }
            .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
    }

    var isEmpty: Bool { topSpecials.isEmpty && topBits.isEmpty && playlists.isEmpty }
}

struct SearchResults: Hashable, Sendable {
    var comedians: [ComedyArtist] = []
    var specials: [ComedyAlbum] = []
    var bits: [ComedyTrack] = []

    var isEmpty: Bool { comedians.isEmpty && specials.isEmpty && bits.isEmpty }
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
