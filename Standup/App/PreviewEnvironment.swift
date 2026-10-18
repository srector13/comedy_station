import SwiftData
import SwiftUI

extension View {
    /// Mock services for SwiftUI previews: the mock catalog and an in-memory
    /// App Library (filled unless `seeded` is false).
    func previewEnvironment(seeded: Bool = true) -> some View {
        let library = LibraryStore.inMemory(seeded: seeded)
        return environment(\.catalog, MockCatalog())
            .environment(library)
            .modelContainer(library.container)
            .tint(Theme.accent)
    }
}
