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

    func currentAuthorization() -> AuthorizationStatus { authorization }
    func requestAuthorization() async -> AuthorizationStatus { afterRequest }
    func subscription() async throws -> SubscriptionStatus { try subscriptionResult.get() }
    func subscriptionUpdates() -> AsyncStream<SubscriptionStatus> { AsyncStream { $0.finish() } }
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
        case .ready:
            self.init(authorization: .authorized)
        }
    }
}
