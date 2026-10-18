import CoreGraphics
import Foundation
import MusicKit

/// The live catalog: MusicKit requests, the comedy filter, and a small
/// in-memory cache so going back and forth between pages doesn't refetch.
actor MusicKitCatalog: CatalogProviding {
    private var cache = ResponseCache(lifetime: 10 * 60)

    func suggestions(for term: String) async throws -> [SearchSuggestion] {
        try await cached("suggestions:\(term.lowercased())") {
            var request = MusicCatalogSearchSuggestionsRequest(term: term, includingTopResultsOfTypes: [Artist.self, Album.self])
            request.limit = 10
            let suggestions: [SearchSuggestion] = try await request.response().topResults.compactMap { result in
                switch result {
                case .artist(let artist): .comedian(ComedyArtist(artist))
                case .album(let album): .special(ComedyAlbum(album))
                default: nil
                }
            }
            return ComedyFilter.keep(suggestions)
        }
    }

    func search(_ term: String) async throws -> SearchResults {
        try await cached("search:\(term.lowercased())") {
            var request = MusicCatalogSearchRequest(term: term, types: [Artist.self, Album.self, Song.self])
            request.limit = 25
            let response = try await request.response()
            let bits = try await comedyBits(Array(response.songs))
            return SearchResults(
                comedians: ComedyFilter.keep(response.artists.map(ComedyArtist.init)),
                specials: ComedyFilter.keep(response.albums.map(ComedyAlbum.init)),
                bits: bits
            )
        }
    }

    func album(id: String) async throws -> AlbumDetail {
        try await cached("album:\(id)") {
            var request = MusicCatalogResourceRequest<Album>(matching: \.id, equalTo: MusicItemID(id))
            request.properties = [.tracks, .artists]
            guard let album = try await request.response().items.first else { throw CatalogError.notFound }
            guard ComedyFilter.isComedy(album.genreNames) else { throw CatalogError.notComedy }

            let tracks: [ComedyTrack] = (album.tracks ?? []).compactMap { track in
                guard case .song(let song) = track else { return nil }
                return ComedyTrack(song, album: album)
            }
            return AlbumDetail(
                album: ComedyAlbum(album),
                tracks: tracks,
                editorialNotes: (album.editorialNotes?.standard ?? album.editorialNotes?.short).map(Format.plainText),
                copyright: album.copyright
            )
        }
    }

    func artist(id: String) async throws -> ArtistDetail {
        try await cached("artist:\(id)") {
            var request = MusicCatalogResourceRequest<Artist>(matching: \.id, equalTo: MusicItemID(id))
            request.properties = [.albums, .topSongs, .similarArtists, .latestRelease, .featuredAlbums]
            guard let artist = try await request.response().items.first else { throw CatalogError.notFound }
            guard ComedyFilter.isComedy(artist.genreNames) else { throw CatalogError.notComedy }

            let specials = ComedyFilter.keep((artist.albums ?? []).map(ComedyAlbum.init))
                .sorted { ($0.releaseDate ?? .distantPast) > ($1.releaseDate ?? .distantPast) }
            let latest = artist.latestRelease.map(ComedyAlbum.init).flatMap { ComedyFilter.isComedy($0.genreNames) ? $0 : nil }
            let featured = latest
                ?? ComedyFilter.keep((artist.featuredAlbums ?? []).map(ComedyAlbum.init)).first
                ?? specials.first
            let topBits = try await comedyBits(Array((artist.topSongs ?? []).prefix(10)))
            return ArtistDetail(
                artist: ComedyArtist(artist),
                featured: featured,
                specials: specials,
                topBits: topBits,
                similar: ComedyFilter.keep((artist.similarArtists ?? []).map(ComedyArtist.init))
            )
        }
    }

    // MARK: Helpers

    /// The songs that are on a comedy album. One batched request loads every
    /// song's albums; a song whose albums don't load is dropped.
    private func comedyBits(_ songs: [Song]) async throws -> [ComedyTrack] {
        guard !songs.isEmpty else { return [] }
        var request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: songs.map(\.id))
        request.properties = [.albums]
        let loaded = try await request.response().items
        let byID = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let bits: [ComedyTrack] = songs.compactMap { song in
            guard let full = byID[song.id], let albums = full.albums, !albums.isEmpty else { return nil }
            // A song can be on several albums (a special and a compilation):
            // it counts if any of them is comedy.
            let album = albums.first { ComedyFilter.isComedy($0.genreNames) } ?? albums.first
            return ComedyTrack(full, album: album)
        }
        return ComedyFilter.keep(bits)
    }

    private func cached<Value: Sendable>(_ key: String, load: () async throws -> Value) async throws -> Value {
        if let hit: Value = cache.value(for: key) {
            return hit
        }
        let value = try await load()
        cache.store(value, for: key)
        return value
    }
}

// MARK: MusicKit to app models

extension ArtworkRef {
    init(_ artwork: Artwork?, id: MusicItemID) {
        let probe = artwork?.url(width: Self.probeSide, height: Self.probeSide)?.absoluteString
        self.init(
            template: probe.map(Self.template(fromProbe:)),
            backgroundRGB: artwork?.backgroundColor.flatMap(Self.rgb),
            seed: Self.seed(for: id.rawValue)
        )
    }

    private static func rgb(_ color: CGColor) -> Int? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let components = color.converted(to: srgb, intent: .defaultIntent, options: nil)?.components,
              components.count >= 3
        else { return nil }
        let byte = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return byte(components[0]) << 16 | byte(components[1]) << 8 | byte(components[2])
    }
}

extension ComedyArtist {
    init(_ artist: Artist) {
        self.init(
            id: artist.id.rawValue,
            name: artist.name,
            artwork: ArtworkRef(artist.artwork, id: artist.id),
            genreNames: artist.genreNames ?? []
        )
    }
}

extension ComedyAlbum {
    init(_ album: Album) {
        self.init(
            id: album.id.rawValue,
            title: album.title,
            artistName: album.artistName,
            artistID: album.artists?.first?.id.rawValue,
            artwork: ArtworkRef(album.artwork, id: album.id),
            releaseDate: album.releaseDate,
            trackCount: album.trackCount,
            genreNames: album.genreNames,
            isExplicit: album.contentRating == .explicit
        )
    }
}

extension ComedyTrack {
    init(_ song: Song, album: Album?) {
        self.init(
            id: song.id.rawValue,
            title: song.title,
            artistName: song.artistName,
            albumID: album?.id.rawValue,
            albumTitle: album?.title ?? song.albumTitle,
            duration: song.duration,
            trackNumber: song.trackNumber,
            artwork: ArtworkRef(song.artwork ?? album?.artwork, id: album?.id ?? song.id),
            isExplicit: song.contentRating == .explicit,
            albumGenreNames: album?.genreNames ?? []
        )
    }
}
