import Foundation
import Testing
@testable import Standup

@MainActor
struct ServiceChoiceTests {
    private func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "ServiceChoiceTests-\(UUID().uuidString)"))
    }

    @Test func nothingIsPickedOnFirstLaunch() throws {
        #expect(ServiceChoice(defaults: try defaults()).provider == nil)
    }

    @Test func thePickIsKept() throws {
        let defaults = try defaults()
        ServiceChoice(defaults: defaults).choose(.spotify)
        let reopened = ServiceChoice(defaults: defaults)
        #expect(reopened.provider == .spotify)
        #expect(reopened.isSpotify)
        reopened.choose(.appleMusic)
        #expect(ServiceChoice(defaults: defaults).provider == .appleMusic)
    }

    /// Mock mode starts where the launch argument says and keeps nothing.
    @Test func withoutDefaultsTheStartIsGiven() {
        let choice = ServiceChoice(defaults: nil, initial: .spotify)
        #expect(choice.provider == .spotify)
        choice.choose(.appleMusic)
        #expect(choice.provider == .appleMusic)
        #expect(ServiceChoice(defaults: nil).provider == nil)
    }
}
