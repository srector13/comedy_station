import Foundation

/// The app's services, live or mock, built once per process. Shared rather
/// than owned by a scene so a second scene (CarPlay) uses the same catalog,
/// player and library as the phone.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment(options: .fromProcess())

    let options: LaunchOptions
    let authGate: AuthGate
    let catalog: any CatalogProviding
    let library: LibraryStore

    init(options: LaunchOptions) {
        self.options = options
        if options.useMockData {
            authGate = AuthGate(access: MockMusicAccess(scenario: options.accessScenario))
            catalog = MockCatalog()
            library = .inMemory(seeded: options.seedLibrary)
        } else {
            authGate = AuthGate(access: LiveMusicAccess())
            catalog = MusicKitCatalog()
            library = .onDisk()
        }
    }

    /// The page a `-StandupRoute` launch argument asks for (mock data only).
    var initialRoute: Route? {
        guard options.useMockData, let route = options.route else { return nil }
        return MockCatalog.route(for: route)
    }
}
