import SwiftUI
import Testing
@testable import Standup

struct LaunchOptionsTests {
    private func options(_ values: [String: String]) -> LaunchOptions {
        LaunchOptions(value: { values[$0] })
    }

    @Test func defaultsAreLive() {
        let options = options([:])
        #expect(options.useMockData == false)
        #expect(options.accessScenario == .ready)
        #expect(options.colorScheme == nil)
        #expect(options.initialTab == .home)
    }

    @Test func readsEverySwitch() {
        let options = options([
            "StandupMock": "YES",
            "StandupAccess": "noSubscription",
            "StandupAppearance": "dark",
            "StandupTab": "library",
        ])
        #expect(options.useMockData)
        #expect(options.accessScenario == .noSubscription)
        #expect(options.colorScheme == .dark)
        #expect(options.initialTab == .library)
    }

    @Test func mockModeStartsOnTheServiceAskedFor() {
        #expect(options([:]).service == .appleMusic)
        #expect(options(["StandupService": "spotify"]).service == .spotify)
        #expect(options(["StandupService": "ask"]).service == nil)
    }

    @Test func ignoresUnknownValues() {
        let options = options(["StandupMock": "maybe", "StandupAccess": "nope", "StandupAppearance": "sepia", "StandupTab": "radio"])
        #expect(options == LaunchOptions())
    }
}

struct GateContentTests {
    @Test func onboardingAsksForAccessAndPromisesNoLibraryWrites() {
        let content = GateContent(state: .needsAuthorization)
        #expect(content.primary == .requestAccess)
        #expect(content.footnote?.contains("never adds anything to your Apple Music library") == true)
    }

    @Test func deniedSendsToSettings() {
        #expect(GateContent(state: .denied).primary == .openSettings)
    }

    @Test func subscriptionOfferOnlyWhenEligible() {
        #expect(GateContent(state: .noSubscription(canSubscribe: true)).primary == .subscribe)
        #expect(GateContent(state: .noSubscription(canSubscribe: false)).primary == .checkAgain)
    }

    @Test func misconfiguredShowsTheSigning() {
        let content = GateContent(state: .misconfigured("This copy is signed as X."))
        #expect(content.title == "MusicKit Isn't Set Up")
        #expect(content.detail == "This copy is signed as X.")
        #expect(content.primary == .checkAgain)
        #expect(content.footnote?.contains("Feather") == true)
    }

    @Test func unavailableShowsTheReason() {
        let content = GateContent(state: .unavailable("Developer token missing"))
        #expect(content.detail == "Developer token missing")
        #expect(content.primary == .checkAgain)
    }
}
