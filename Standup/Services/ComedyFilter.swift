/// The one filter every catalog result passes through (hard rule 3): search
/// results, suggestions, charts, an artist's albums, top bits and similar
/// comedians alike.
enum ComedyFilter {
    /// Apple Music's genre ID for Comedy. Used only to ask for the Comedy
    /// charts; everything else is judged by genre name, because sub-genre
    /// tagging is inconsistent.
    static let comedyGenreID = "3"

    /// True when any genre name contains "comedy", in any case ("Comedy",
    /// "Stand-Up Comedy"). No genre names means not comedy.
    static func isComedy(_ genreNames: [String]?) -> Bool {
        genreNames?.contains { $0.localizedCaseInsensitiveContains("comedy") } ?? false
    }

    /// The comedy items, in order. For a bit, its album's genres decide.
    static func keep<Item: GenreTagged>(_ items: some Sequence<Item>) -> [Item] {
        items.filter { isComedy($0.genreNames) }
    }

    /// A comedian Apple files under another genre (Tom Segura is
    /// "Biographies & Memoirs") still counts when one of their specials is
    /// comedy. Their genres then gain "Comedy", so every later check
    /// agrees. Nil when they're neither.
    static func comedian(_ artist: ComedyArtist, specials: some Sequence<ComedyAlbum>) -> ComedyArtist? {
        if isComedy(artist.genreNames) {
            return artist
        }
        guard specials.contains(where: { isComedy($0.genreNames) }) else { return nil }
        var tagged = artist
        tagged.genreNames.append("Comedy")
        return tagged
    }

    /// The comedians among search results, judged as above by the specials
    /// in the same results. Those rarely carry their artist's ID, so a
    /// special counts when its artist has the comedian's name.
    static func comedians(_ artists: [ComedyArtist], specials: [ComedyAlbum]) -> [ComedyArtist] {
        artists.compactMap { artist in
            let name = SpecialMatcher.normalized(artist.name)
            return comedian(artist, specials: specials.lazy.filter {
                $0.artistID == artist.id || SpecialMatcher.normalized($0.artistName) == name
            })
        }
    }
}
