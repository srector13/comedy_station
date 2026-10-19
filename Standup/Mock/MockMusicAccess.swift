import Foundation

/// Fixed Apple Music answers for previews, unit tests and CI screenshots.
struct MockMusicAccess: MusicAccessProviding {
    struct Failure: LocalizedError {
        var errorDescription: String? { "The Apple Music catalog didn't respond." }
    }

    var authorization: AuthorizationStatus
    /// What the system prompt "returns" when onboarding's Continue is tapped.
    var afterRequest: AuthorizationStatus = .authorized
    var subscriptionResult: Result<SubscriptionStatus, Failure> = .success(.subscribed)
    /// Whether Apple Music refuses this copy a developer token.
    var refusesToken = false

    func currentAuthorization() -> AuthorizationStatus { authorization }
    func requestAuthorization() async -> AuthorizationStatus { afterRequest }
    func subscription() async throws -> SubscriptionStatus { try subscriptionResult.get() }
    func subscriptionUpdates() -> AsyncStream<SubscriptionStatus> { AsyncStream { $0.finish() } }
    func verifyCatalogAccess() async throws {
        if refusesToken {
            throw MusicKitSetupError(signing: SigningInfo(
                applicationIdentifier: "A1B2C3D4E5.com.example.resigned", teamID: "A1B2C3D4E5", teamName: "Some Other Team",
                profileName: "Wildcard", bundleID: "com.example.resigned", expected: "68L4YU8U89.PolarReality.Standup"
            ))
        }
    }
}

extension SubscriptionStatus {
    static let subscribed = SubscriptionStatus(canPlayCatalogContent: true, canBecomeSubscriber: false)
    static let lapsed = SubscriptionStatus(canPlayCatalogContent: false, canBecomeSubscriber: true)
}

extension MockMusicAccess {
    /// The mock for a `-StandupAccess` launch value (`LaunchOptions`).
    init(scenario: LaunchOptions.AccessScenario) {
        switch scenario {
        case .notDetermined:
            self.init(authorization: .notDetermined)
        case .denied:
            self.init(authorization: .denied)
        case .restricted:
            self.init(authorization: .restricted)
        case .noSubscription:
            self.init(authorization: .authorized, subscriptionResult: .success(.lapsed))
        case .unavailable:
            self.init(authorization: .authorized, subscriptionResult: .failure(Failure()))
        case .misconfigured:
            self.init(authorization: .authorized, refusesToken: true)
        case .ready:
            self.init(authorization: .authorized)
        }
    }
}
