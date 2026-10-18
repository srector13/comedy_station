import XCTest

/// Launches the app in mock mode (no Apple Music needed) and screenshots it.
/// Screenshots land in the result bundle; CI exports them with
/// `scripts/export_screenshots.py` and uploads them as an artifact.
class StandupUITestCase: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    // Each loop terminates the app itself before the next launch, as
    // MyTeams' screenshot tests do: leaving it to launch() let XCUITest time
    // out terminating the previous instance ("Failed to terminate").

    @MainActor
    func launch(access: String = "ready", tab: String? = nil, extra: [String] = [], dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-StandupMock", "YES",
            "-StandupAccess", access,
            "-StandupAppearance", dark ? "dark" : "light",
        ]
        if let tab {
            app.launchArguments += ["-StandupTab", tab]
        }
        app.launchArguments += extra
        app.launch()
        return app
    }

    /// Any element with this accessibility identifier.
    @MainActor
    func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Any element whose label mentions `text` (rows combine their texts
    /// into one label).
    @MainActor
    func labelled(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    @MainActor
    func snap(_ name: String, dark: Bool, settle: TimeInterval = 0.8) {
        // Let transitions and glass settle.
        Thread.sleep(forTimeInterval: settle)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(name)-\(dark ? "dark" : "light")"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
