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
    let player: PlayerService
    let specials: SpecialsSettings
    let spotify: SpotifyAccount
    /// Apple Music or Spotify, picked on first launch.
    let service: ServiceChoice
    /// Live only: takes the Spotify app's call back after waking it.
    let spotifyEngine: SpotifyPlaybackEngine?

    init(options: LaunchOptions) {
        self.options = options
        let engine: any PlaybackEngine
        if options.useMockData {
            authGate = AuthGate(access: MockMusicAccess(scenario: options.accessScenario))
            let spotify = SpotifyAccount(clientIDs: MemoryKeyStore(options.spotifyConnected ? "mock-client" : nil), tokens: MemoryKeyStore(), isMock: true)
            if options.spotifyConnected {
                spotify.connectMock()
            }
            self.spotify = spotify
            service = ServiceChoice(defaults: nil, initial: options.service)
            catalog = RoutingCatalog(appleMusic: MockCatalog(delay: options.catalogDelay), spotify: MockSpotifyCatalog())
            library = .inMemory(seeded: options.seedLibrary, catalog: catalog)
            engine = MockPlaybackEngine()
            spotifyEngine = nil
            specials = SpecialsSettings(store: MemoryKeyStore(), check: { _ in })
        } else {
            authGate = AuthGate(access: LiveMusicAccess())
            let spotify = SpotifyAccount(clientIDs: KeychainKeyStore.spotifyClientID, tokens: KeychainKeyStore.spotifyTokens)
            self.spotify = spotify
            service = ServiceChoice(defaults: .standard)
            // One TMDB source for both services, so the lists load once.
            let tmdb = TMDBDiscovery(keys: KeychainKeyStore.tmdb)
            let appleMusic = MusicKitCatalog(tmdb: tmdb)
            let spotifyAPI = SpotifyWebAPI(token: { try await spotify.validToken() })
            // Spotify's comedians are confirmed through iTunes Search, which
            // needs no Apple Music sign-in, so the Spotify route works alone.
            catalog = RoutingCatalog(appleMusic: appleMusic, spotify: SpotifyCatalog(api: spotifyAPI, confirming: ITunesComedianCheck(), tmdb: tmdb))
            library = .onDisk(catalog: catalog)
            let spotifyEngine = SpotifyPlaybackEngine(account: spotify)
            self.spotifyEngine = spotifyEngine
            engine = RoutingPlaybackEngine(appleMusic: MusicKitPlaybackEngine(), spotify: spotifyEngine)
            specials = SpecialsSettings(store: KeychainKeyStore.tmdb, check: { try await TMDBClient(key: $0).check() })
        }
        player = PlayerService(engine: engine, catalog: catalog, progressStore: library)
        restoreMockSession()
    }

    /// `-StandupNowPlaying album:<id>:<bit index>:<seconds>` loads a paused
    /// special (mock only), and `-StandupShowNowPlaying YES` opens Now
    /// Playing over it, for screenshots.
    private func restoreMockSession() {
        guard options.useMockData, let value = options.nowPlaying else { return }
        let parts = value.split(separator: ":").map(String.init)
        guard parts.count == 4, parts[0] == "album", let album = MockData.album(id: parts[1]),
              let index = Int(parts[2]), let seconds = TimeInterval(parts[3])
        else { return }
        let service = self.player
        let opens = options.showNowPlaying
        Task {
            await service.play(album: album, startIndex: index, position: seconds, autoplay: false)
            service.showsNowPlaying = opens
        }
    }

    /// The page a `-StandupRoute` launch argument asks for (mock data only).
    var initialRoute: Route? {
        guard options.useMockData, let route = options.route else { return nil }
        return MockCatalog.route(for: route)
    }
}
