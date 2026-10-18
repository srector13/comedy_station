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
}
