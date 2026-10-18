import Foundation

/// The app's services, live or mock, built once at launch.
@MainActor
struct AppEnvironment {
    let options: LaunchOptions
    let authGate: AuthGate

    static func make(options: LaunchOptions = .fromProcess()) -> AppEnvironment {
        let access: any MusicAccessProviding = options.useMockData
            ? MockMusicAccess(scenario: options.accessScenario)
            : LiveMusicAccess()
        return AppEnvironment(options: options, authGate: AuthGate(access: access))
    }
}
