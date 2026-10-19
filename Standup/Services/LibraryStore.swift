import Foundation
import Observation
import SwiftData

/// The App Library: comedians, specials and bits saved in Standup's own
/// SwiftData store. This is the only place the app saves anything, and it
/// never touches the Apple Music library (hard rule 1).
@MainActor
@Observable
final class LibraryStore {
    /// The "Added to Library" confirmation the root view shows.
    struct Feedback: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let symbol: String
    }

    static let schema = Schema([SavedComedian.self, SavedAlbum.self, SavedTrack.self, PlaybackProgress.self])

    let container: ModelContainer
    /// What's saved, by ID, so every + / checkmark updates as soon as it
    /// changes without a fetch per row.
    private(set) var comedianIDs: Set<String> = []
    private(set) var specialIDs: Set<String> = []
    private(set) var bitIDs: Set<String> = []
    private(set) var feedback: Feedback?

    /// Looks up a special's comedian and bits when it's added
    /// (`addRelated(to:)`).
    @ObservationIgnored private let catalog: (any CatalogProviding)?
    /// The latest such lookup, so tests can wait for it.
    @ObservationIgnored private(set) var relatedLookup: Task<Void, Never>?

    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer, catalog: (any CatalogProviding)? = nil) {
        self.container = container
        self.catalog = catalog
        reloadIDs()
    }

    /// The on-disk store.
    static func onDisk(catalog: any CatalogProviding) -> LibraryStore {
        let configuration = ModelConfiguration("StandupLibrary", schema: schema, cloudKitDatabase: .none)
        do {
            return LibraryStore(container: try ModelContainer(for: schema, configurations: configuration), catalog: catalog)
        } catch {
            // A store that can't open (a failed migration) shouldn't take the
            // app down; run on an empty in-memory library instead.
            assertionFailure("Couldn't open the App Library: \(error)")
            return inMemory(catalog: catalog)
        }
    }

    /// A throwaway store, for previews, tests and mock mode.
    static func inMemory(seeded: Bool = false, catalog: (any CatalogProviding)? = nil) -> LibraryStore {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        // An in-memory container only fails on a broken schema, a programmer error.
        let store = LibraryStore(container: try! ModelContainer(for: schema, configurations: configuration), catalog: catalog)
        if seeded {
            store.seed(MockData.librarySeed)
            for snapshot in MockData.progressSeed {
                store.saveProgress(snapshot)
            }
        }
        return store
    }

    // MARK: Reading

    func contains(_ item: LibraryItem) -> Bool {
        switch item {
        case .comedian(let artist): comedianIDs.contains(artist.id)
        case .special(let album): specialIDs.contains(album.id)
        case .bit(let track): bitIDs.contains(track.id)
        }
    }

    var isEmpty: Bool {
        comedianIDs.isEmpty && specialIDs.isEmpty && bitIDs.isEmpty
    }

    // MARK: Writing

    /// Adds an item. A special brings its comedian and its bits along
    /// (`addRelated(to:)`).
    func add(_ item: LibraryItem, at date: Date = .now) {
        guard !contains(item) else { return }
        insert(item, at: date)
        save()
        feedback = Feedback(message: "Added to Library", symbol: "checkmark")
        if case .special(let album) = item {
            addRelated(to: album, at: date)
        }
    }

    func remove(_ item: LibraryItem) {
        guard contains(item) else { return }
        let id = item.id
        switch item {
        case .comedian:
            delete(FetchDescriptor<SavedComedian>(predicate: #Predicate { $0.artistID == id }))
            comedianIDs.remove(id)
        case .special:
            let artistID = savedAlbum(id)?.artistID
            delete(FetchDescriptor<SavedAlbum>(predicate: #Predicate { $0.albumID == id }))
            specialIDs.remove(id)
            removeAutomaticBits(of: id)
            if let artistID {
                removeAutomaticComedian(artistID)
            }
        case .bit:
            delete(FetchDescriptor<SavedTrack>(predicate: #Predicate { $0.songID == id }))
            bitIDs.remove(id)
        }
        save()
        feedback = Feedback(message: "Removed from Library", symbol: "minus")
    }

    func toggle(_ item: LibraryItem) {
        if contains(item) {
            remove(item)
        } else {
            add(item)
        }
    }

    /// Clears the confirmation once it has been shown.
    func dismissFeedback(_ id: Feedback.ID) {
        if feedback?.id == id {
            feedback = nil
        }
    }

    /// Fills an empty store without confirmations (mock mode, previews).
    func seed(_ items: [(LibraryItem, Date)]) {
        for (item, date) in items where !contains(item) {
            insert(item, at: date)
        }
        save()
    }

    // MARK: A special's comedian and bits

    /// Adds the special's bits and its comedian too, as Music adds an
    /// album's songs and artist. Both come from the catalog (the special's
    /// page, which carries its artist ID even when search didn't), and the
    /// comedian goes through the comedy filter. Offline, the special stays
    /// saved on its own.
    private func addRelated(to album: ComedyAlbum, at date: Date) {
        guard let catalog else { return }
        relatedLookup = Task { [weak self] in
            guard let detail = try? await catalog.album(id: album.id) else { return }
            guard let self, self.specialIDs.contains(album.id) else { return }
            self.addAutomaticBits(detail.tracks, at: date)
            let artistID = album.artistID ?? detail.album.artistID
            self.savedAlbum(album.id)?.artistID = artistID
            self.save()
            guard let artistID, !self.comedianIDs.contains(artistID),
                  let comedian = try? await catalog.comedian(id: artistID),
                  self.specialIDs.contains(album.id), !self.comedianIDs.contains(comedian.id)
            else { return }
            self.insert(.comedian(comedian), at: date, automatic: true)
            self.save()
        }
    }

    /// The special's bits, in track order, except any already saved. Each
    /// is a millisecond older than the one before, so the Bits list (newest
    /// first) shows them in the special's order.
    private func addAutomaticBits(_ tracks: [ComedyTrack], at date: Date) {
        for (offset, track) in tracks.enumerated() where !bitIDs.contains(track.id) {
            insert(.bit(track), at: date.addingTimeInterval(-Double(offset) / 1000), automatic: true)
        }
    }

    /// Removes the bits that came with a special; bits added on their own
    /// stay.
    private func removeAutomaticBits(of albumID: String) {
        let special: String? = albumID
        let descriptor = FetchDescriptor<SavedTrack>(predicate: #Predicate { $0.albumID == special && $0.isAutomatic })
        for bit in (try? context.fetch(descriptor)) ?? [] {
            bitIDs.remove(bit.songID)
            context.delete(bit)
        }
    }

    /// Removes a comedian who was only here because of their specials, once
    /// the last one is gone.
    private func removeAutomaticComedian(_ artistID: String) {
        let stillHasSpecials = ((try? context.fetchCount(FetchDescriptor<SavedAlbum>(predicate: #Predicate { $0.artistID == artistID }))) ?? 0) > 0
        guard !stillHasSpecials,
              let comedian = try? context.fetch(FetchDescriptor<SavedComedian>(predicate: #Predicate { $0.artistID == artistID })).first,
              comedian.isAutomatic
        else { return }
        context.delete(comedian)
        comedianIDs.remove(artistID)
    }

    private func savedAlbum(_ id: String) -> SavedAlbum? {
        try? context.fetch(FetchDescriptor<SavedAlbum>(predicate: #Predicate { $0.albumID == id })).first
    }

    // MARK: Helpers

    private func insert(_ item: LibraryItem, at date: Date, automatic: Bool = false) {
        switch item {
        case .comedian(let artist):
            context.insert(SavedComedian(artist, dateAdded: date, isAutomatic: automatic))
            comedianIDs.insert(artist.id)
        case .special(let album):
            context.insert(SavedAlbum(album, dateAdded: date))
            specialIDs.insert(album.id)
        case .bit(let track):
            context.insert(SavedTrack(track, dateAdded: date, isAutomatic: automatic))
            bitIDs.insert(track.id)
        }
    }

    private func delete<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) {
        for model in (try? context.fetch(descriptor)) ?? [] {
            context.delete(model)
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Couldn't save the App Library: \(error)")
        }
    }

    private func reloadIDs() {
        comedianIDs = Set(((try? context.fetch(FetchDescriptor<SavedComedian>())) ?? []).map(\.artistID))
        specialIDs = Set(((try? context.fetch(FetchDescriptor<SavedAlbum>())) ?? []).map(\.albumID))
        bitIDs = Set(((try? context.fetch(FetchDescriptor<SavedTrack>())) ?? []).map(\.songID))
    }
}

// MARK: Playback progress

extension PlaybackProgress {
    var snapshot: ProgressSnapshot {
        ProgressSnapshot(
            itemID: itemID, isAlbum: isAlbum,
            lastTrackIndex: lastTrackIndex, lastPosition: lastPosition,
            lastPlayed: lastPlayed, finished: finished,
            fractionComplete: fractionComplete,
            title: title, artistName: artistName,
            artwork: ArtworkRef(template: artworkTemplate, backgroundRGB: artworkRGB, seed: ArtworkRef.seed(for: itemID)),
            trackCount: trackCount,
            totalDuration: totalDuration
        )
    }
}

extension LibraryStore: ProgressStoring {
    func progress(for itemID: String) -> ProgressSnapshot? {
        progressRecord(itemID)?.snapshot
    }

    func saveProgress(_ snapshot: ProgressSnapshot) {
        let record = progressRecord(snapshot.itemID) ?? {
            let new = PlaybackProgress(itemID: snapshot.itemID, isAlbum: snapshot.isAlbum, title: snapshot.title, artistName: snapshot.artistName)
            context.insert(new)
            return new
        }()
        record.isAlbum = snapshot.isAlbum
        record.lastTrackIndex = snapshot.lastTrackIndex
        record.lastPosition = snapshot.lastPosition
        record.lastPlayed = snapshot.lastPlayed
        record.finished = snapshot.finished
        record.fractionComplete = snapshot.fractionComplete
        record.title = snapshot.title
        record.artistName = snapshot.artistName
        record.artworkTemplate = snapshot.artwork.template
        record.artworkRGB = snapshot.artwork.backgroundRGB
        record.trackCount = snapshot.trackCount
        record.totalDuration = snapshot.totalDuration
        save()
    }

    /// Takes a special off Continue Listening (it starts over next time).
    func removeProgress(for itemID: String) {
        guard let record = progressRecord(itemID) else { return }
        context.delete(record)
        save()
    }

    private func progressRecord(_ itemID: String) -> PlaybackProgress? {
        try? context.fetch(FetchDescriptor<PlaybackProgress>(predicate: #Predicate { $0.itemID == itemID })).first
    }
}
