import SwiftData
import SwiftUI

/// The App Library's sections, as rows like Music's library.
enum LibraryCategory: String, CaseIterable, Identifiable, Hashable {
    case comedians, specials, bits, recentlyAdded, downloads

    var id: Self { self }

    var title: String {
        switch self {
        case .comedians: "Comedians"
        case .specials: "Specials"
        case .bits: "Bits"
        case .recentlyAdded: "Recently Added"
        case .downloads: "Downloads"
        }
    }

    var symbol: String {
        switch self {
        case .comedians: "music.mic"
        case .specials: "square.stack"
        case .bits: "quote.bubble"
        case .recentlyAdded: "clock"
        case .downloads: "arrow.down.circle"
        }
    }

    var emptyTitle: String {
        switch self {
        case .downloads: "No Downloads"
        default: "No \(title)"
        }
    }

    var emptyMessage: String {
        switch self {
        case .comedians: "Add a comedian with the + on their page, or by touching and holding them anywhere."
        case .specials: "Add a special with the + on its page, or by touching and holding it."
        case .bits: "Swipe left on a bit to add it on its own."
        case .recentlyAdded: "Everything you add shows up here, newest first."
        case .downloads: "Downloads would have to go through your Apple Music library, which Standup never touches. Specials stream instead."
        }
    }
}

/// The Library tab. It reads only Standup's own store, never the Apple Music
/// library.
struct LibraryView: View {
    @Query(sort: \SavedAlbum.dateAdded, order: .reverse) private var specials: [SavedAlbum]

    var body: some View {
        NavigationStack {
            // A scroll view rather than a List: a List puts a disclosure
            // chevron on every link, including the grid's cards.
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(LibraryCategory.allCases) { category in
                        NavigationLink(value: category) {
                            CategoryRow(category: category)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("library.\(category.rawValue)")
                        Divider()
                            .padding(.leading, 44)
                    }

                    if !specials.isEmpty {
                        Text("Recently Added")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .padding(.top, 28)
                            .padding(.bottom, 12)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16, alignment: .top)], spacing: 20) {
                            ForEach(specials.prefix(6)) { saved in
                                NavigationLink(value: Route.album(saved.album)) {
                                    SpecialCard(album: saved.album, width: nil)
                                }
                                .buttonStyle(.plain)
                                .libraryContextMenu(.special(saved.album))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("Library")
            .navigationDestination(for: LibraryCategory.self) { category in
                LibraryCategoryView(category: category)
            }
            .comedyDestinations()
        }
    }
}

/// A library section row, Music style: accent symbol, title, chevron.
private struct CategoryRow: View {
    let category: LibraryCategory

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: category.symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
                .accessibilityHidden(true)
            Text(category.title)
                .font(.title3)
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
    }
}

/// One library section.
struct LibraryCategoryView: View {
    let category: LibraryCategory

    var body: some View {
        Group {
            switch category {
            case .comedians: LibraryComediansList()
            case .specials: LibrarySpecialsGrid()
            case .bits: LibraryBitsList()
            case .recentlyAdded: RecentlyAddedList()
            case .downloads: LibraryEmptyView(category: .downloads)
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct LibraryEmptyView: View {
    let category: LibraryCategory

    var body: some View {
        ContentUnavailableView {
            Label(category.emptyTitle, systemImage: category.symbol)
        } description: {
            Text(category.emptyMessage)
        }
    }
}

struct LibraryComediansList: View {
    @Query(sort: \SavedComedian.name) private var comedians: [SavedComedian]

    var body: some View {
        if comedians.isEmpty {
            LibraryEmptyView(category: .comedians)
        } else {
            List(comedians) { saved in
                NavigationLink(value: Route.artist(saved.comedian)) {
                    ComedianRow(artist: saved.comedian)
                }
                .libraryContextMenu(.comedian(saved.comedian))
                .librarySwipeActions(.comedian(saved.comedian))
                .accessibilityIdentifier("library.comedian.\(saved.artistID)")
            }
            .listStyle(.plain)
        }
    }
}

struct LibrarySpecialsGrid: View {
    @Query(sort: \SavedAlbum.dateAdded, order: .reverse) private var specials: [SavedAlbum]

    var body: some View {
        if specials.isEmpty {
            LibraryEmptyView(category: .specials)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16, alignment: .top)], spacing: 22) {
                    ForEach(specials) { saved in
                        NavigationLink(value: Route.album(saved.album)) {
                            SpecialCard(album: saved.album, width: nil)
                        }
                        .buttonStyle(.plain)
                        .libraryContextMenu(.special(saved.album))
                        .accessibilityIdentifier("library.special.\(saved.albumID)")
                    }
                }
                .padding(20)
            }
        }
    }
}

struct LibraryBitsList: View {
    @Query(sort: \SavedTrack.dateAdded, order: .reverse) private var bits: [SavedTrack]

    var body: some View {
        if bits.isEmpty {
            LibraryEmptyView(category: .bits)
        } else {
            List(bits) { saved in
                let track = saved.track
                Group {
                    if let album = track.albumStub {
                        NavigationLink(value: Route.album(album)) {
                            BitRow(track: track, subtitle: [track.artistName, track.albumTitle].compactMap { $0 }.joined(separator: " · "))
                        }
                    } else {
                        BitRow(track: track)
                    }
                }
                .libraryContextMenu(.bit(track))
                .librarySwipeActions(.bit(track))
                .accessibilityIdentifier("library.bit.\(saved.songID)")
            }
            .listStyle(.plain)
        }
    }
}

/// Everything in the App Library, newest first.
struct RecentlyAddedList: View {
    @Query private var comedians: [SavedComedian]
    @Query private var specials: [SavedAlbum]
    @Query private var bits: [SavedTrack]

    private var items: [(item: LibraryItem, date: Date)] {
        var all: [(item: LibraryItem, date: Date)] = []
        for saved in comedians { all.append((.comedian(saved.comedian), saved.dateAdded)) }
        for saved in specials { all.append((.special(saved.album), saved.dateAdded)) }
        for saved in bits { all.append((.bit(saved.track), saved.dateAdded)) }
        return all.sorted { $0.date > $1.date }
    }

    var body: some View {
        let items = items
        if items.isEmpty {
            LibraryEmptyView(category: .recentlyAdded)
        } else {
            List(items, id: \.item) { entry in
                LibraryItemRow(item: entry.item)
                    .libraryContextMenu(entry.item)
                    .librarySwipeActions(entry.item)
            }
            .listStyle(.plain)
        }
    }
}

/// Any library item as a navigable row.
struct LibraryItemRow: View {
    let item: LibraryItem

    var body: some View {
        switch item {
        case .comedian(let artist):
            NavigationLink(value: Route.artist(artist)) { ComedianRow(artist: artist) }
        case .special(let album):
            NavigationLink(value: Route.album(album)) { SpecialRow(album: album) }
        case .bit(let track):
            if let album = track.albumStub {
                NavigationLink(value: Route.album(album)) { BitRow(track: track) }
            } else {
                BitRow(track: track)
            }
        }
    }
}

#Preview("Library") {
    LibraryView()
        .previewEnvironment()
}

#Preview("Empty") {
    LibraryView()
        .previewEnvironment(seeded: false)
}
