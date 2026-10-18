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

    private var context: ModelContext { container.mainContext }

    init(container: ModelContainer) {
        self.container = container
        reloadIDs()
    }

    /// The on-disk store.
    static func onDisk() -> LibraryStore {
        let configuration = ModelConfiguration("StandupLibrary", schema: schema, cloudKitDatabase: .none)
        do {
            return LibraryStore(container: try ModelContainer(for: schema, configurations: configuration))
        } catch {
            // A store that can't open (a failed migration) shouldn't take the
            // app down; run on an empty in-memory library instead.
            assertionFailure("Couldn't open the App Library: \(error)")
            return inMemory()
        }
    }

    /// A throwaway store, for previews, tests and mock mode.
    static func inMemory(seeded: Bool = false) -> LibraryStore {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        // An in-memory container only fails on a broken schema, a programmer error.
        let store = LibraryStore(container: try! ModelContainer(for: schema, configurations: configuration))
        if seeded {
            store.seed(MockData.librarySeed)
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

    func add(_ item: LibraryItem, at date: Date = .now) {
        guard !contains(item) else { return }
        insert(item, at: date)
        save()
        feedback = Feedback(message: "Added to Library", symbol: "checkmark")
    }

    func remove(_ item: LibraryItem) {
        guard contains(item) else { return }
        let id = item.id
        switch item {
        case .comedian:
            delete(FetchDescriptor<SavedComedian>(predicate: #Predicate { $0.artistID == id }))
            comedianIDs.remove(id)
        case .special:
            delete(FetchDescriptor<SavedAlbum>(predicate: #Predicate { $0.albumID == id }))
            specialIDs.remove(id)
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

    // MARK: Helpers

    private func insert(_ item: LibraryItem, at date: Date) {
        switch item {
        case .comedian(let artist):
            context.insert(SavedComedian(artist, dateAdded: date))
            comedianIDs.insert(artist.id)
        case .special(let album):
            context.insert(SavedAlbum(album, dateAdded: date))
            specialIDs.insert(album.id)
        case .bit(let track):
            context.insert(SavedTrack(track, dateAdded: date))
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
