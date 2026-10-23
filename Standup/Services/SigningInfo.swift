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
    /// The iCloud containers the profile allows.
    var iCloudContainers: [String] = []
    /// Whether the profile allows CloudKit.
    var allowsCloudKit = false
    /// Whether this copy carries a provisioning profile at all. Copies from
    /// the App Store and TestFlight don't: Apple signs them with the
    /// entitlements they were submitted with. Simulator builds don't
    /// either, and may have no entitlements.
    var hasProfile = false
    /// Running in the Simulator.
    var isSimulator: Bool = {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }()

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
        hasProfile = true
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any]
        else { return }
        profileName = plist["Name"] as? String
        teamName = plist["TeamName"] as? String
        teamID = (plist["TeamIdentifier"] as? [String])?.first
        let entitlements = plist["Entitlements"] as? [String: Any]
        applicationIdentifier = entitlements?["application-identifier"] as? String
        iCloudContainers = entitlements?["com.apple.developer.icloud-container-identifiers"] as? [String] ?? []
        // "*" in a development profile, a list once narrowed by Xcode.
        let services = entitlements?["com.apple.developer.icloud-services"]
        allowsCloudKit = (services as? String) == "*" || (services as? [String])?.contains("CloudKit") == true
    }

    /// The App Library's iCloud container: "iCloud." and the bundle ID.
    var iCloudContainer: String? {
        bundleID.map { "iCloud.\($0)" }
    }

    /// Why the App Library can't sync through iCloud in this copy, or nil
    /// when it can. A copy from the App Store or TestFlight can: it's signed
    /// with the app's own entitlements, container included. A re-signed
    /// copy (Feather) is signed with its profile's entitlements, so the
    /// profile has to include the container. A simulator build without a
    /// profile stays local: CloudKit stops the app outright when the
    /// entitlement is missing, rather than failing to open.
    var iCloudProblem: String? {
        guard let container = iCloudContainer else { return "This copy has no bundle ID." }
        guard hasProfile else {
            return isSimulator ? "This simulator copy has no provisioning profile." : nil
        }
        guard applicationIdentifier != nil else { return "This copy's provisioning profile couldn't be read." }
        guard allowsCloudKit, iCloudContainers.contains(container) else {
            return "Its provisioning profile doesn't include iCloud with the container \(container)."
        }
        return nil
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

    /// The bundle ID part of the signed app ID ("TEAMID.bundle.id").
    private var signedBundleID: String? {
        applicationIdentifier?.split(separator: ".", maxSplits: 1).last.map(String.init)
    }

    /// For the setup screen: how this copy is signed, what MusicKit needs,
    /// and, when those match, that the App ID itself is what's missing.
    var summary: String {
        var lines = ["This copy is signed as \(signedAs)" + (teamName.map { " (\($0))" } ?? "") + "."]
        if let bundleID, let signedBundleID, bundleID != signedBundleID {
            lines.append("Its bundle ID is \(bundleID).")
        }
        if let expected {
            lines.append("MusicKit needs \(expected).")
        }
        if matchesExpected {
            lines.append("The signing is right, so turn on MusicKit for this App ID (App Services tab in the developer portal), wait a few minutes, and tap Check Again.")
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
