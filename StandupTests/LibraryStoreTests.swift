import Foundation
import SwiftData
import Testing
@testable import Standup

@MainActor
struct LibraryStoreTests {
    private let special = MockData.albums[0]
    private let comedian = MockData.comedians[0]
    private var bit: ComedyTrack { MockData.tracks[special.id]![2] }

    private func count<Model: PersistentModel>(_ type: Model.Type, in store: LibraryStore) throws -> Int {
        try store.container.mainContext.fetchCount(FetchDescriptor<Model>())
    }

    @Test func startsEmpty() {
        let store = LibraryStore.inMemory()
        #expect(store.isEmpty)
        #expect(!store.contains(.special(special)))
    }

    @Test func addingASpecialSavesItOnce() throws {
        let store = LibraryStore.inMemory()
        store.add(.special(special))
        store.add(.special(special))
        #expect(store.contains(.special(special)))
        #expect(try count(SavedAlbum.self, in: store) == 1)
        #expect(store.feedback?.message == "Added to Library")
    }

    @Test func removingASpecialDeletesIt() throws {
        let store = LibraryStore.inMemory()
        store.add(.special(special))
        store.remove(.special(special))
        #expect(!store.contains(.special(special)))
        #expect(try count(SavedAlbum.self, in: store) == 0)
        #expect(store.feedback?.message == "Removed from Library")
    }

    @Test func eachKindIsSeparate() throws {
        let store = LibraryStore.inMemory()
        store.add(.comedian(comedian))
        store.add(.bit(bit))
        #expect(store.contains(.comedian(comedian)))
        #expect(store.contains(.bit(bit)))
        #expect(!store.contains(.special(special)))
        #expect(try count(SavedComedian.self, in: store) == 1)
        #expect(try count(SavedTrack.self, in: store) == 1)
        #expect(try count(SavedAlbum.self, in: store) == 0)
    }

    @Test func toggleAddsThenRemoves() {
        let store = LibraryStore.inMemory()
        store.toggle(.comedian(comedian))
        #expect(store.contains(.comedian(comedian)))
        store.toggle(.comedian(comedian))
        #expect(!store.contains(.comedian(comedian)))
    }

    /// The cached metadata rebuilds the same values, so the library draws
    /// without the catalog.
    @Test func savedItemsRebuildOffline() throws {
        let store = LibraryStore.inMemory()
        store.add(.special(special))
        store.add(.comedian(comedian))
        store.add(.bit(bit))
        let context = store.container.mainContext
        #expect(try context.fetch(FetchDescriptor<SavedAlbum>()).first?.album == special)
        #expect(try context.fetch(FetchDescriptor<SavedComedian>()).first?.comedian == comedian)
        #expect(try context.fetch(FetchDescriptor<SavedTrack>()).first?.track == bit)
    }

    @Test func aNewStoreOnTheSameContainerSeesSavedItems() {
        let first = LibraryStore.inMemory()
        first.add(.special(special))
        let second = LibraryStore(container: first.container)
        #expect(second.contains(.special(special)))
    }

    @Test func seededLibraryHasEveryKind() throws {
        let store = LibraryStore.inMemory(seeded: true)
        #expect(try count(SavedAlbum.self, in: store) == 5)
        #expect(try count(SavedComedian.self, in: store) == 3)
        #expect(try count(SavedTrack.self, in: store) == 3)
        #expect(store.feedback == nil)
    }

    @Test func feedbackClearsOnlyItself() throws {
        let store = LibraryStore.inMemory()
        store.add(.special(special))
        let first = try #require(store.feedback)
        store.add(.comedian(comedian))
        store.dismissFeedback(first.id)
        #expect(store.feedback?.message == "Added to Library")
        store.dismissFeedback(store.feedback!.id)
        #expect(store.feedback == nil)
    }
}
