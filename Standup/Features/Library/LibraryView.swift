import SwiftData
import SwiftUI

/// The App Library's sections, as rows like Music's library.
enum LibraryCategory: String, CaseIterable, Identifiable, Hashable {
    case comedians, specials, bits, recentlyAdded

    var id: Self { self }

    var title: String {
        switch self {
        case .comedians: "Comedians"
        case .specials: "Specials"
        case .bits: "Bits"
        case .recentlyAdded: "Recently Added"
        }
    }

    var symbol: String {
        switch self {
        case .comedians: "music.mic"
        case .specials: "square.stack"
        case .bits: "quote.bubble"
        case .recentlyAdded: "clock"
        }
    }

    var emptyTitle: String {
        "No \(title)"
    }

    var emptyMessage: String {
        switch self {
        case .comedians: "Add a comedian with the + on their page, or by touching and holding them anywhere."
        case .specials: "Add a special with the + on its page, or by touching and holding it."
        case .bits: "A special's bits come along when you add it. Swipe left on any bit to add it on its own."
        case .recentlyAdded: "Everything you add shows up here, newest first."
        }
    }
}

/// The Library tab. It reads only Standup's own store, never the Apple Music
/// library.
struct LibraryView: View {
    @Query(sort: \SavedAlbum.dateAdded, order: .reverse) private var specials: [SavedAlbum]
    @Environment(LibraryStore.self) private var library

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

                    SyncStatusLine(status: library.syncStatus)
                        .padding(.top, 28)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("Library")
            .settingsButton()
            .navigationDestination(for: LibraryCategory.self) { category in
                LibraryCategoryView(category: category)
            }
            .comedyDestinations()
        }
    }
}

/// Whether the App Library syncs with iCloud, at the foot of Library.
/// Nothing in mock mode.
struct SyncStatusLine: View {
    let status: LibraryStore.SyncStatus

    var body: some View {
        if case let (symbol, text)? = content {
            Label(text, systemImage: symbol)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("library.sync")
        }
    }

    private var content: (String, String)? {
        switch status {
        case .local:
            nil
        case .unavailable(let reason):
            ("icloud.slash", "Your library is saved on this device only. \(reason)")
        case .starting:
            ("icloud", "Syncing your library with iCloud…")
        case .synced(let date):
            ("checkmark.icloud", "Library synced with iCloud \(date.formatted(.relative(presentation: .named))).")
        case .failed(let reason):
            ("exclamationmark.icloud", "iCloud sync didn't work: \(reason)")
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

/// Every saved bit, newest first. Play, Shuffle or a tapped bit plays the
/// whole list as one queue, so shuffle mixes all of them, not just one
/// special's. Show Special (touch and hold) opens a bit's special.
struct LibraryBitsList: View {
    static let queueTitle = "Library Bits"

    @Query(sort: \SavedTrack.dateAdded, order: .reverse) private var bits: [SavedTrack]
    @Environment(\.play) private var play
    @State private var shownSpecial: ComedyAlbum?

    var body: some View {
        if bits.isEmpty {
            LibraryEmptyView(category: .bits)
        } else {
            let tracks = bits.map(\.track)
            List {
                PlayButtonsLayout {
                    Button {
                        play(PlayRequest(item: .bits(title: Self.queueTitle, tracks: tracks)))
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("library.bits.play")
                    Button {
                        play(PlayRequest(item: .bits(title: Self.queueTitle, tracks: tracks), shuffle: true))
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("library.bits.shuffle")
                }
                .font(.headline)
                .foregroundStyle(Theme.accent)
                .buttonStyle(.glass)
                .controlSize(.large)
                .listRowSeparator(.hidden)

                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        play(PlayRequest(item: .bits(title: Self.queueTitle, tracks: tracks), startIndex: index, trackID: track.id))
                    } label: {
                        BitRow(track: track, subtitle: [track.artistName, track.albumTitle].compactMap { $0 }.joined(separator: " · "))
                    }
                    .buttonStyle(.plain)
                    .libraryContextMenu(.bit(track), showSpecial: showSpecial(of: track))
                    .librarySwipeActions(.bit(track))
                    .accessibilityIdentifier("library.bit.\(track.id)")
                }
            }
            .listStyle(.plain)
            .navigationDestination(item: $shownSpecial) { album in
                AlbumView(album: album)
            }
        }
    }

    private func showSpecial(of track: ComedyTrack) -> (() -> Void)? {
        guard let album = track.albumStub else { return nil }
        return { shownSpecial = album }
    }
}

/// Everything in the App Library, newest first. Bits that came with a
/// special aren't listed one by one; the special is.
struct RecentlyAddedList: View {
    @Query private var comedians: [SavedComedian]
    @Query private var specials: [SavedAlbum]
    @Query private var bits: [SavedTrack]

    private var items: [(item: LibraryItem, date: Date)] {
        var all: [(item: LibraryItem, date: Date)] = []
        for saved in comedians { all.append((.comedian(saved.comedian), saved.dateAdded)) }
        for saved in specials { all.append((.special(saved.album), saved.dateAdded)) }
        for saved in bits where !saved.isAutomatic { all.append((.bit(saved.track), saved.dateAdded)) }
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
