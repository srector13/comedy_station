import SwiftData
import SwiftUI

extension View {
    /// Mock services for SwiftUI previews: the mock catalog and an in-memory
    /// App Library (filled unless `seeded` is false).
    func previewEnvironment(seeded: Bool = true) -> some View {
        let catalog = MockCatalog()
        let library = LibraryStore.inMemory(seeded: seeded, catalog: catalog)
        let player = PlayerService(engine: MockPlaybackEngine(), catalog: catalog, progressStore: library)
        return environment(\.catalog, catalog)
            .environment(library)
            .modelContainer(library.container)
            .environment(player)
            .tint(Theme.accent)
    }
}
