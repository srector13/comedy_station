import Observation

/// Decides whether the app can show the catalog: Apple Music authorization
/// first, then a subscription that can play catalog content.
@MainActor
@Observable
final class AuthGate {
    private(set) var state: AccessState

    private let access: any MusicAccessProviding
    @ObservationIgnored private var subscriptionTask: Task<Void, Never>?

    init(access: any MusicAccessProviding, state: AccessState = .checking) {
        self.access = access
        self.state = state
    }

    /// Re-reads authorization and the subscription without prompting. Runs
    /// at launch and whenever the app returns to the foreground, so a change
    /// made in Settings is picked up.
    func refresh() async {
        await update(for: access.currentAuthorization())
    }

    /// Shows the system prompt. Called from onboarding's Continue button.
    func requestAccess() async {
        await update(for: await access.requestAuthorization())
    }

    private func update(for authorization: AuthorizationStatus) async {
        switch authorization {
        case .notDetermined: state = .needsAuthorization
        case .denied: state = .denied
        case .restricted: state = .restricted
        case .authorized: await checkSubscription()
        }
    }

    private func checkSubscription() async {
        do {
            apply(try await access.subscription())
        } catch {
            state = .unavailable(error.localizedDescription)
        }
        observeSubscription()
        if state == .ready {
            await verifyCatalogAccess()
        }
    }

    /// Catches a copy signed wrong (Apple Music refuses it a token) at launch
    /// rather than as empty screens. Any other failure (offline) doesn't
    /// block: the App Library works without the catalog.
    private func verifyCatalogAccess() async {
        do {
            try await access.verifyCatalogAccess()
        } catch let setup as MusicKitSetupError {
            state = .misconfigured(setup.signing.summary)
        } catch {
            // Offline or a passing error: carry on.
        }
    }

    private func apply(_ subscription: SubscriptionStatus) {
        state = subscription.canPlayCatalogContent
            ? .ready
            : .noSubscription(canSubscribe: subscription.canBecomeSubscriber)
    }

    /// Follows the subscription once authorized: a lapsed subscription
    /// blocks the app, a new one unblocks it.
    private func observeSubscription() {
        guard subscriptionTask == nil else { return }
        let updates = access.subscriptionUpdates()
        subscriptionTask = Task { [weak self] in
            for await subscription in updates {
                self?.apply(subscription)
            }
        }
    }
}
