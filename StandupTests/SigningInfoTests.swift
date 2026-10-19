import Foundation
import Testing
@testable import Standup

struct SigningInfoTests {
    /// A provisioning profile as Xcode or Feather embeds it: binary CMS
    /// bytes around an XML property list.
    private func profile(appID: String, team: String, teamName: String) -> Data {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Name</key><string>Standup Development</string>
            <key>TeamName</key><string>\(teamName)</string>
            <key>TeamIdentifier</key><array><string>\(team)</string></array>
            <key>Entitlements</key>
            <dict>
                <key>application-identifier</key><string>\(appID)</string>
            </dict>
        </dict>
        </plist>
        """
        return Data([0x30, 0x82, 0x0b, 0x2e, 0x06, 0x09]) + Data(plist.utf8) + Data([0xa0, 0x82, 0x00, 0xff])
    }

    @Test func readsTheEmbeddedProfile() {
        var info = SigningInfo(bundleID: "PolarReality.Standup", expected: "68L4YU8U89.PolarReality.Standup")
        info.read(profile: profile(appID: "68L4YU8U89.PolarReality.Standup", team: "68L4YU8U89", teamName: "Polar Reality"))
        #expect(info.profileName == "Standup Development")
        #expect(info.teamID == "68L4YU8U89")
        #expect(info.teamName == "Polar Reality")
        #expect(info.applicationIdentifier == "68L4YU8U89.PolarReality.Standup")
        #expect(info.matchesExpected)
    }

    @Test func spotsAnotherTeamsSignature() {
        var info = SigningInfo(bundleID: "com.example.resigned", expected: "68L4YU8U89.PolarReality.Standup")
        info.read(profile: profile(appID: "A1B2C3D4E5.com.example.resigned", team: "A1B2C3D4E5", teamName: "Some Other Team"))
        #expect(!info.matchesExpected)
        #expect(info.summary == "This copy is signed as A1B2C3D4E5.com.example.resigned (Some Other Team).\nMusicKit needs 68L4YU8U89.PolarReality.Standup.")
    }

    @Test func rightSigningPointsAtTheAppID() {
        var info = SigningInfo(bundleID: "PolarReality.Standup", expected: "68L4YU8U89.PolarReality.Standup")
        info.read(profile: profile(appID: "68L4YU8U89.PolarReality.Standup", team: "68L4YU8U89", teamName: "Stephen Rector"))
        #expect(info.summary.hasSuffix("The signing is right, so turn on MusicKit for this App ID (App Services tab in the developer portal), wait a few minutes, and tap Check Again."))
        #expect(!info.summary.contains("Its bundle ID"))
    }

    @Test func showsABundleIDThatDiffersFromTheProfile() {
        var info = SigningInfo(bundleID: "PolarReailty.Standup", expected: "68L4YU8U89.PolarReality.Standup")
        info.read(profile: profile(appID: "68L4YU8U89.PolarReality.Standup", team: "68L4YU8U89", teamName: "Stephen Rector"))
        #expect(info.summary.contains("\nIts bundle ID is PolarReailty.Standup.\n"))
    }

    @Test func noProfileFallsBackToTheBundleID() {
        var info = SigningInfo(bundleID: "PolarReality.Standup", expected: "68L4YU8U89.PolarReality.Standup")
        info.read(profile: Data("not a profile".utf8))
        #expect(info.applicationIdentifier == nil)
        #expect(!info.matchesExpected)
        #expect(info.signedAs == "PolarReality.Standup (no provisioning profile)")
    }

    @Test func setupErrorExplainsItself() {
        let error = MusicKitSetupError(signing: SigningInfo(bundleID: "PolarReality.Standup", expected: "68L4YU8U89.PolarReality.Standup"))
        #expect(error.localizedDescription.hasPrefix("Apple Music didn't accept this copy of Standup."))
        #expect(error.localizedDescription.contains("MusicKit needs 68L4YU8U89.PolarReality.Standup."))
    }
}
