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

    // MARK: A special brings its comedian

    private func comedians(in store: LibraryStore) throws -> [SavedComedian] {
        try store.container.mainContext.fetch(FetchDescriptor<SavedComedian>())
    }

    @Test func addingASpecialAddsItsComedian() async throws {
        let store = LibraryStore.inMemory(catalog: MockCatalog())
        let parking = try #require(MockData.album(id: "mock-al-parking"))
        store.add(.special(parking))
        await store.relatedLookup?.value
        #expect(store.comedianIDs == ["mock-ar-dev"])
        #expect(try comedians(in: store).first?.isAutomatic == true)
    }

    /// Search results don't carry the artist; the catalog finds it.
    @Test func aSpecialFromSearchStillFindsItsComedian() async throws {
        let store = LibraryStore.inMemory(catalog: MockCatalog())
        var fromSearch = try #require(MockData.album(id: "mock-al-parking"))
        fromSearch.artistID = nil
        store.add(.special(fromSearch))
        await store.relatedLookup?.value
        #expect(store.comedianIDs == ["mock-ar-dev"])
        let saved = try store.container.mainContext.fetch(FetchDescriptor<SavedAlbum>()).first
        #expect(saved?.artistID == "mock-ar-dev")
    }

    @Test func removingTheSpecialTakesAnAddedAlongComedianWithIt() async throws {
        let store = LibraryStore.inMemory(catalog: MockCatalog())
        let parking = try #require(MockData.album(id: "mock-al-parking"))
        store.add(.special(parking))
        await store.relatedLookup?.value
        store.remove(.special(parking))
        #expect(store.comedianIDs.isEmpty)
        #expect(try comedians(in: store).isEmpty)
    }

    @Test func aComedianAddedOnPurposeStays() async throws {
        let store = LibraryStore.inMemory(catalog: MockCatalog())
        let parking = try #require(MockData.album(id: "mock-al-parking"))
        store.add(.comedian(try #require(MockData.artist(id: "mock-ar-dev"))))
        store.add(.special(parking))
        await store.relatedLookup?.value
        #expect(try comedians(in: store).first?.isAutomatic == false)
        store.remove(.special(parking))
        #expect(store.comedianIDs == ["mock-ar-dev"])
    }

    @Test func theComedianStaysUntilTheirLastSpecialGoes() async throws {
        let store = LibraryStore.inMemory(catalog: MockCatalog())
        let lower = try #require(MockData.album(id: "mock-al-lower"))
        let groupChat = try #require(MockData.album(id: "mock-al-groupchat"))
        store.add(.special(lower))
        await store.relatedLookup?.value
        store.add(.special(groupChat))
        await store.relatedLookup?.value
        store.remove(.special(lower))
        #expect(store.comedianIDs == ["mock-ar-maya"])
        store.remove(.special(groupChat))
        #expect(store.comedianIDs.isEmpty)
    }

    // MARK: A special brings its bits

    private func bits(in store: LibraryStore) throws -> [SavedTrack] {
        try store.container.mainContext.fetch(FetchDescriptor<SavedTrack>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]))
    }

    @Test func addingASpecialAddsItsBitsInOrder() async throws {
        let store = LibraryStore.inMemory(catalog: MockCatalog())
        let parking = try #require(MockData.album(id: "mock-al-parking"))
        let tracks = try #require(MockData.tracks[parking.id])
        store.add(.special(parking))
        await store.relatedLookup?.value
        #expect(store.bitIDs == Set(tracks.map(\.id)))
        let saved = try bits(in: store)
        #expect(saved.map(\.songID) == tracks.map(\.id))
        #expect(saved.allSatisfy(\.isAutomatic))
    }

    @Test func removingTheSpecialTakesItsBitsButKeepsOnesAddedOnPurpose() async throws {
        let store = LibraryStore.inMemory(catalog: MockCatalog())
        let parking = try #require(MockData.album(id: "mock-al-parking"))
        let tracks = try #require(MockData.tracks[parking.id])
        store.add(.bit(tracks[1]))
        store.add(.special(parking))
        await store.relatedLookup?.value
        #expect(try bits(in: store).first { $0.songID == tracks[1].id }?.isAutomatic == false)
        store.remove(.special(parking))
        #expect(store.bitIDs == [tracks[1].id])
        #expect(try bits(in: store).map(\.songID) == [tracks[1].id])
    }

    @Test func removingOneBitOfASpecialLeavesTheRest() async throws {
        let store = LibraryStore.inMemory(catalog: MockCatalog())
        let parking = try #require(MockData.album(id: "mock-al-parking"))
        let tracks = try #require(MockData.tracks[parking.id])
        store.add(.special(parking))
        await store.relatedLookup?.value
        store.remove(.bit(tracks[0]))
        #expect(store.bitIDs == Set(tracks.dropFirst().map(\.id)))
        #expect(store.specialIDs == [parking.id])
    }

    // MARK: Records synced in twice

    @Test func syncedDuplicatesMergeIntoOne() throws {
        let store = LibraryStore.inMemory()
        let context = store.container.mainContext
        let lower = try #require(MockData.album(id: "mock-al-lower"))
        let maya = try #require(MockData.artist(id: "mock-ar-maya"))
        let bit = try #require(MockData.tracks[lower.id]?.first)
        let early = Date(timeIntervalSince1970: 1_700_000_000)
        let late = early.addingTimeInterval(3600)

        var withoutArtist = lower
        withoutArtist.artistID = nil
        context.insert(SavedAlbum(withoutArtist, dateAdded: early))
        context.insert(SavedAlbum(lower, dateAdded: late))
        context.insert(SavedComedian(maya, dateAdded: early, isAutomatic: true))
        context.insert(SavedComedian(maya, dateAdded: late, isAutomatic: false))
        context.insert(SavedTrack(bit, dateAdded: early, isAutomatic: true))
        context.insert(SavedTrack(bit, dateAdded: late, isAutomatic: true))
        context.insert(PlaybackProgress(itemID: lower.id, isAlbum: true, lastTrackIndex: 1, lastPlayed: early, title: lower.title, artistName: lower.artistName))
        context.insert(PlaybackProgress(itemID: lower.id, isAlbum: true, lastTrackIndex: 4, lastPlayed: late, title: lower.title, artistName: lower.artistName))
        try context.save()

        store.mergeSyncedDuplicates()

        let albums = try context.fetch(FetchDescriptor<SavedAlbum>())
        #expect(albums.count == 1)
        #expect(albums.first?.dateAdded == early)
        #expect(albums.first?.artistID == lower.artistID)
        let comedians = try context.fetch(FetchDescriptor<SavedComedian>())
        #expect(comedians.count == 1)
        #expect(comedians.first?.isAutomatic == false)
        let bits = try context.fetch(FetchDescriptor<SavedTrack>())
        #expect(bits.count == 1)
        #expect(bits.first?.isAutomatic == true)
        let progress = try context.fetch(FetchDescriptor<PlaybackProgress>())
        #expect(progress.count == 1)
        #expect(progress.first?.lastTrackIndex == 4)
        #expect(store.specialIDs == [lower.id])
        #expect(store.comedianIDs == [maya.id])
        #expect(store.bitIDs == [bit.id])
    }

    @Test func aLocalStoreShowsNoSyncStatus() {
        #expect(LibraryStore.inMemory().syncStatus == .local)
    }

    // MARK: Playback progress

    @Test func progressRoundTripsAndUpdatesInPlace() throws {
        let store = LibraryStore.inMemory()
        var snapshot = ProgressSnapshot(
            itemID: special.id, isAlbum: true, lastTrackIndex: 2, lastPosition: 42,
            lastPlayed: Date(timeIntervalSince1970: 1_800_000_000), finished: false, fractionComplete: 0.3,
            title: special.title, artistName: special.artistName, artwork: special.artwork, trackCount: 11
        )
        store.saveProgress(snapshot)
        #expect(store.progress(for: special.id) == snapshot)
        snapshot.lastTrackIndex = 5
        snapshot.lastPosition = 7
        store.saveProgress(snapshot)
        #expect(store.progress(for: special.id) == snapshot)
        #expect(try count(PlaybackProgress.self, in: store) == 1)
        #expect(store.progress(for: "nothing") == nil)
    }
}

