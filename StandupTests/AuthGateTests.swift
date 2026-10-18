import Testing
@testable import Standup

@MainActor
struct AuthGateTests {
    private func makeGate(_ access: MockMusicAccess) async -> AuthGate {
        let gate = AuthGate(access: access)
        await gate.refresh()
        return gate
    }

    @Test func startsChecking() {
        #expect(AuthGate(access: MockMusicAccess(authorization: .authorized)).state == .checking)
    }

    @Test func neverAskedShowsOnboarding() async {
        #expect(await makeGate(MockMusicAccess(authorization: .notDetermined)).state == .needsAuthorization)
    }

    @Test func deniedIsBlocked() async {
        #expect(await makeGate(MockMusicAccess(authorization: .denied)).state == .denied)
    }

    @Test func restrictedIsBlocked() async {
        #expect(await makeGate(MockMusicAccess(authorization: .restricted)).state == .restricted)
    }

    @Test func authorizedWithSubscriptionIsReady() async {
        #expect(await makeGate(MockMusicAccess(authorization: .authorized)).state == .ready)
    }

    @Test func authorizedWithoutSubscriptionOffersOne() async {
        let access = MockMusicAccess(authorization: .authorized, subscriptionResult: .success(.lapsed))
        #expect(await makeGate(access).state == .noSubscription(canSubscribe: true))
    }

    @Test func subscriptionThatCantSubscribe() async {
        let status = SubscriptionStatus(canPlayCatalogContent: false, canBecomeSubscriber: false)
        let access = MockMusicAccess(authorization: .authorized, subscriptionResult: .success(status))
        #expect(await makeGate(access).state == .noSubscription(canSubscribe: false))
    }

    @Test func failedSubscriptionCheckIsUnavailable() async {
        let access = MockMusicAccess(authorization: .authorized, subscriptionResult: .failure(.init()))
        let state = await makeGate(access).state
        guard case .unavailable(let reason) = state else {
            Issue.record("Expected .unavailable, got \(state)")
            return
        }
        #expect(!reason.isEmpty)
    }

    @Test func continueFromOnboardingReachesReady() async {
        let gate = await makeGate(MockMusicAccess(authorization: .notDetermined, afterRequest: .authorized))
        #expect(gate.state == .needsAuthorization)
        await gate.requestAccess()
        #expect(gate.state == .ready)
    }

    @Test func declinedPromptIsDenied() async {
        let gate = await makeGate(MockMusicAccess(authorization: .notDetermined, afterRequest: .denied))
        await gate.requestAccess()
        #expect(gate.state == .denied)
    }

    @Test(arguments: LaunchOptions.AccessScenario.allCases)
    func everyScenarioLandsInItsState(_ scenario: LaunchOptions.AccessScenario) async {
        let state = await makeGate(MockMusicAccess(scenario: scenario)).state
        switch scenario {
        case .notDetermined: #expect(state == .needsAuthorization)
        case .denied: #expect(state == .denied)
        case .restricted: #expect(state == .restricted)
        case .noSubscription: #expect(state == .noSubscription(canSubscribe: true))
        case .unavailable:
            if case .unavailable = state {} else { Issue.record("Expected .unavailable, got \(state)") }
        case .ready: #expect(state == .ready)
        }
    }
}
