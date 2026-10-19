import Foundation

/// Who this copy of the app is signed as, read from its embedded
/// provisioning profile (Xcode and Feather both embed one), next to who it
/// must be signed as for MusicKit to work.
struct SigningInfo: Equatable, Sendable {
    /// "TEAMID.bundle.id" from the profile's entitlements.
    var applicationIdentifier: String?
    var teamID: String?
    var teamName: String?
    var profileName: String?
    var bundleID: String?
    /// "TEAMID.bundle.id" the app was built for (`StandupExpectedAppID`).
    var expected: String?

    static var current: SigningInfo {
        var info = SigningInfo(
            bundleID: Bundle.main.bundleIdentifier,
            expected: Bundle.main.object(forInfoDictionaryKey: "StandupExpectedAppID") as? String
        )
        if let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
           let data = try? Data(contentsOf: url) {
            info.read(profile: data)
        }
        return info
    }

    /// Fills in the profile's details. A profile is a signed (CMS) envelope
    /// around an XML property list.
    mutating func read(profile data: Data) {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return }
        profileName = plist["Name"] as? String
        teamName = plist["TeamName"] as? String
        teamID = (plist["TeamIdentifier"] as? [String])?.first
        applicationIdentifier = (plist["Entitlements"] as? [String: Any])?["application-identifier"] as? String
    }

    /// What this copy is signed as: the profile's app ID, or the bundle ID
    /// when there's no profile.
    var signedAs: String {
        applicationIdentifier ?? bundleID.map { "\($0) (no provisioning profile)" } ?? "unknown"
    }

    var matchesExpected: Bool {
        guard let expected, let applicationIdentifier else { return false }
        return applicationIdentifier == expected
    }

    /// Two lines for the setup screen.
    var summary: String {
        var lines = ["This copy is signed as \(signedAs)" + (teamName.map { " (\($0))" } ?? "") + "."]
        if let expected {
            lines.append("MusicKit needs \(expected).")
        }
        return lines.joined(separator: "\n")
    }
}

/// Apple Music refused this copy a developer token: MusicKit only serves the
/// catalog to an app signed by the team whose App ID has MusicKit enabled,
/// under that App ID's bundle ID.
struct MusicKitSetupError: LocalizedError, Equatable {
    var signing: SigningInfo

    var errorDescription: String? {
        "Apple Music didn't accept this copy of Standup. " + signing.summary
    }
}
