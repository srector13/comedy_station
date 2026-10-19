import MusicKit

/// Where the app stands with Apple Music, as `RootView` shows it.
enum AccessState: Equatable, Sendable {
    /// Not known yet (the first moment after launch).
    case checking
    /// Never asked: onboarding, whose Continue button shows the system prompt.
    case needsAuthorization
    /// The person said no; only Settings can change it.
    case denied
    /// Blocked by Screen Time or a device profile.
    case restricted
    /// Authorized, but this account can't play catalog content.
    case noSubscription(canSubscribe: Bool)
    /// The subscription check failed (offline, or MusicKit isn't set up for
    /// this bundle ID / signing team).
    case unavailable(String)
    /// Apple Music refused this copy a developer token: it isn't signed as
    /// the App ID with MusicKit enabled. Carries the signing details.
    case misconfigured(String)
    /// Authorized with a subscription that plays catalog content.
    case ready
}

/// `MusicAuthorization.Status`, mirrored so tests can produce every case.
enum AuthorizationStatus: Sendable {
    case notDetermined, denied, restricted, authorized

    init(_ status: MusicAuthorization.Status) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .authorized: self = .authorized
        @unknown default: self = .denied
        }
    }
}

/// The parts of `MusicSubscription` the gate needs.
struct SubscriptionStatus: Equatable, Sendable {
    var canPlayCatalogContent: Bool
    var canBecomeSubscriber: Bool
}

/// Apple Music authorization and subscription, behind a protocol so the gate
/// runs on mock answers in previews, tests and CI screenshots.
protocol MusicAccessProviding: Sendable {
    func currentAuthorization() -> AuthorizationStatus
    func requestAuthorization() async -> AuthorizationStatus
    func subscription() async throws -> SubscriptionStatus
    /// Changes to the subscription after the first check.
    func subscriptionUpdates() -> AsyncStream<SubscriptionStatus>
    /// One small catalog request, to learn whether Apple Music will serve
    /// this copy at all. Throws `MusicKitSetupError` when it won't.
    func verifyCatalogAccess() async throws
}

/// The real thing: MusicKit.
struct LiveMusicAccess: MusicAccessProviding {
    func currentAuthorization() -> AuthorizationStatus {
        AuthorizationStatus(MusicAuthorization.currentStatus)
    }

    func requestAuthorization() async -> AuthorizationStatus {
        AuthorizationStatus(await MusicAuthorization.request())
    }

    func subscription() async throws -> SubscriptionStatus {
        SubscriptionStatus(try await MusicSubscription.current)
    }

    func verifyCatalogAccess() async throws {
        do {
            let request = MusicCatalogResourceRequest<Genre>(matching: \.id, equalTo: MusicItemID(ComedyFilter.comedyGenreID))
            _ = try await request.response()
        } catch {
            if let setup = MusicKitSetupError(error) { throw setup }
            throw error
        }
    }

    func subscriptionUpdates() -> AsyncStream<SubscriptionStatus> {
        AsyncStream { continuation in
            let task = Task {
                for await subscription in MusicSubscription.subscriptionUpdates {
                    continuation.yield(SubscriptionStatus(subscription))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

private extension SubscriptionStatus {
    init(_ subscription: MusicSubscription) {
        self.init(
            canPlayCatalogContent: subscription.canPlayCatalogContent,
            canBecomeSubscriber: subscription.canBecomeSubscriber
        )
    }
}

extension MusicKitSetupError {
    /// MusicKit's refusal to mint a developer token, with how this copy is
    /// signed; nil for any other error.
    init?(_ error: any Error) {
        if let token = error as? MusicTokenRequestError, case .developerTokenRequestFailed = token {
            self.init(signing: .current)
        } else if error.localizedDescription.localizedCaseInsensitiveContains("developer token") {
            self.init(signing: .current)
        } else {
            return nil
        }
    }
}
