import Foundation
import SwiftData

// The App Library: Standup's own store on this device, separate from the
// Apple Music library (which the app never writes to). Each model keeps the
// MusicItemID to re-load the full item from the catalog, plus enough cached
// metadata to draw the library offline.

@Model
final class SavedComedian {
    @Attribute(.unique) var artistID: String
    var name: String
    var artworkTemplate: String?
    var artworkRGB: Int?
    var genreNames: [String]
    var dateAdded: Date
    /// Added because one of their specials was, not on its own; leaves
    /// again with the last such special.
    var isAutomatic: Bool = false

    init(_ artist: ComedyArtist, dateAdded: Date = .now, isAutomatic: Bool = false) {
        self.isAutomatic = isAutomatic
        artistID = artist.id
        name = artist.name
        artworkTemplate = artist.artwork.template
        artworkRGB = artist.artwork.backgroundRGB
        genreNames = artist.genreNames
        self.dateAdded = dateAdded
    }

    var comedian: ComedyArtist {
        ComedyArtist(
            id: artistID, name: name,
            artwork: ArtworkRef(template: artworkTemplate, backgroundRGB: artworkRGB, seed: ArtworkRef.seed(for: artistID)),
            genreNames: genreNames
        )
    }
}

/// A saved special.
@Model
final class SavedAlbum {
    @Attribute(.unique) var albumID: String
    var title: String
    var artistName: String
    var artistID: String?
    var artworkTemplate: String?
    var artworkRGB: Int?
    var releaseDate: Date?
    var trackCount: Int
    var genreNames: [String]
    var isExplicit: Bool
    var dateAdded: Date

    init(_ album: ComedyAlbum, dateAdded: Date = .now) {
        albumID = album.id
        title = album.title
        artistName = album.artistName
        artistID = album.artistID
        artworkTemplate = album.artwork.template
        artworkRGB = album.artwork.backgroundRGB
        releaseDate = album.releaseDate
        trackCount = album.trackCount
        genreNames = album.genreNames
        isExplicit = album.isExplicit
        self.dateAdded = dateAdded
    }

    var album: ComedyAlbum {
        ComedyAlbum(
            id: albumID, title: title, artistName: artistName, artistID: artistID,
            artwork: ArtworkRef(template: artworkTemplate, backgroundRGB: artworkRGB, seed: ArtworkRef.seed(for: albumID)),
            releaseDate: releaseDate, trackCount: trackCount, genreNames: genreNames, isExplicit: isExplicit
        )
    }
}

/// A saved bit.
@Model
final class SavedTrack {
    @Attribute(.unique) var songID: String
    var title: String
    /// The comedian.
    var artistName: String
    var albumID: String?
    var albumTitle: String?
    var duration: TimeInterval?
    var trackNumber: Int?
    var artworkTemplate: String?
    var artworkRGB: Int?
    var albumGenreNames: [String]
    var isExplicit: Bool
    var dateAdded: Date

    init(_ track: ComedyTrack, dateAdded: Date = .now) {
        songID = track.id
        title = track.title
        artistName = track.artistName
        albumID = track.albumID
        albumTitle = track.albumTitle
        duration = track.duration
        trackNumber = track.trackNumber
        artworkTemplate = track.artwork.template
        artworkRGB = track.artwork.backgroundRGB
        albumGenreNames = track.albumGenreNames
        isExplicit = track.isExplicit
        self.dateAdded = dateAdded
    }

    var track: ComedyTrack {
        ComedyTrack(
            id: songID, title: title, artistName: artistName, albumID: albumID, albumTitle: albumTitle,
            duration: duration, trackNumber: trackNumber,
            // Bit artwork is its special's, so it shares the special's seed.
            artwork: ArtworkRef(template: artworkTemplate, backgroundRGB: artworkRGB, seed: ArtworkRef.seed(for: albumID ?? songID)),
            isExplicit: isExplicit, albumGenreNames: albumGenreNames
        )
    }
}

/// Where a special (or a single bit) was left off. Written by the player
/// (Phase 4); read by Continue Listening and resume.
@Model
final class PlaybackProgress {
    /// The album ID, or the song ID for a bit played on its own.
    @Attribute(.unique) var itemID: String
    var isAlbum: Bool
    var lastTrackIndex: Int
    var lastPosition: TimeInterval
    var lastPlayed: Date
    var finished: Bool
    /// 0...1 through the whole set, for the progress ring.
    var fractionComplete: Double
    // Cached so Continue Listening draws offline.
    var title: String
    var artistName: String
    var artworkTemplate: String?
    var artworkRGB: Int?
    var trackCount: Int

    init(
        itemID: String, isAlbum: Bool, lastTrackIndex: Int = 0, lastPosition: TimeInterval = 0,
        lastPlayed: Date = .now, finished: Bool = false, fractionComplete: Double = 0,
        title: String, artistName: String, artworkTemplate: String? = nil, artworkRGB: Int? = nil, trackCount: Int = 0
    ) {
        self.itemID = itemID
        self.isAlbum = isAlbum
        self.lastTrackIndex = lastTrackIndex
        self.lastPosition = lastPosition
        self.lastPlayed = lastPlayed
        self.finished = finished
        self.fractionComplete = fractionComplete
        self.title = title
        self.artistName = artistName
        self.artworkTemplate = artworkTemplate
        self.artworkRGB = artworkRGB
        self.trackCount = trackCount
    }
}
