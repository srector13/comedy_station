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
            // Long enough that a query after a tap still finds it.
            "-StandupFeedbackSeconds", "6",
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

    /// Waits for `element`; on failure attaches the app's accessibility
    /// hierarchy and a screenshot, so CI shows what was on screen.
    @MainActor
    @discardableResult
    func require(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 10, _ message: String, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        if element.waitForExistence(timeout: timeout) {
            return true
        }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "failure-hierarchy-\(name)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "failure-screen-\(name)"
        screen.lifetime = .keepAlways
        add(screen)
        XCTFail(message, file: file, line: line)
        return false
    }
}
