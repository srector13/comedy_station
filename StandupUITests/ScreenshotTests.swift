import XCTest

/// Drives the app in mock mode (no Apple Music needed) and attaches a
/// screenshot of each screen to the result bundle. CI exports them with
/// `scripts/export_screenshots.py` and uploads them as an artifact.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Screens

    @MainActor
    func testAccessGateScreens() {
        let screens: [(name: String, access: String)] = [
            ("01-onboarding", "notDetermined"),
            ("02-denied", "denied"),
            ("03-restricted", "restricted"),
            ("04-no-subscription", "noSubscription"),
            ("05-unavailable", "unavailable"),
        ]
        for dark in [false, true] {
            for screen in screens {
                let app = launch(access: screen.access, dark: dark)
                XCTAssertTrue(app.buttons["gate.primary"].waitForExistence(timeout: 15), "\(screen.name): no primary button")
                snap(screen.name, dark: dark)
            }
        }
    }

    @MainActor
    func testTabScreens() {
        let tabs: [(name: String, tab: String, title: String)] = [
            ("10-home", "home", "Home"),
            ("11-browse", "browse", "Browse"),
            ("12-library", "library", "Library"),
            ("13-search", "search", "Search"),
        ]
        for dark in [false, true] {
            for tab in tabs {
                let app = launch(tab: tab.tab, dark: dark)
                XCTAssertTrue(app.navigationBars[tab.title].waitForExistence(timeout: 15), "\(tab.name): no \(tab.title) title")
                snap(tab.name, dark: dark)
            }
        }
    }

    // MARK: Flows

    /// Onboarding's Continue grants access (mock) and lands on the tabs,
    /// whose bar switches between them.
    @MainActor
    func testContinueThenSwitchTabs() {
        let app = launch(access: "notDetermined", dark: false)
        let proceed = app.buttons["gate.primary"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 15))
        proceed.tap()

        let library = app.tabBars.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 15))
        library.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))

        let comedians = app.descendants(matching: .any)["library.comedians"].firstMatch
        XCTAssertTrue(comedians.waitForExistence(timeout: 10))
        comedians.tap()
        XCTAssertTrue(app.navigationBars["Comedians"].waitForExistence(timeout: 10))
        snap("14-library-comedians-empty", dark: false)
    }

    // MARK: Helpers

    @MainActor
    private func launch(access: String = "ready", tab: String? = nil, dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-StandupMock", "YES",
            "-StandupAccess", access,
            "-StandupAppearance", dark ? "dark" : "light",
        ]
        if let tab {
            app.launchArguments += ["-StandupTab", tab]
        }
        app.launch()
        return app
    }

    @MainActor
    private func snap(_ name: String, dark: Bool) {
        // Let transitions and glass settle.
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(name)-\(dark ? "dark" : "light")"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
