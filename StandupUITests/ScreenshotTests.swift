import XCTest

/// Drives the app in mock mode (no Apple Music needed) and attaches a
/// screenshot of each screen to the result bundle. CI exports them with
/// `scripts/export_screenshots.py` and uploads them as an artifact.
final class ScreenshotTests: StandupUITestCase {
    // MARK: Screens

    @MainActor
    func testAccessGateScreens() {
        let screens: [(name: String, access: String)] = [
            ("01-onboarding", "notDetermined"),
            ("02-denied", "denied"),
            ("03-restricted", "restricted"),
            ("04-no-subscription", "noSubscription"),
            ("05-unavailable", "unavailable"),
            ("06-misconfigured", "misconfigured"),
        ]
        for dark in [false, true] {
            for screen in screens {
                let app = launch(access: screen.access, dark: dark)
                XCTAssertTrue(app.buttons["gate.primary"].waitForExistence(timeout: 15), "\(screen.name): no primary button")
                snap(screen.name, dark: dark)
                app.terminate()
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
                app.terminate()
            }
        }
    }

    /// Search results, a comedian's page (top and scrolled) and a special's
    /// page, opened straight from launch arguments.
    @MainActor
    func testCatalogScreens() {
        for dark in [false, true] {
            var app = launch(tab: "search", extra: ["-StandupSearch", "maya"], dark: dark)
            XCTAssertTrue(element("result.artist.mock-ar-maya", in: app).waitForExistence(timeout: 15), "no search results")
            snap("20-search-results", dark: dark)
            app.terminate()

            app = launch(tab: "home", extra: ["-StandupRoute", "artist:mock-ar-maya"], dark: dark)
            XCTAssertTrue(element("artist.featured", in: app).waitForExistence(timeout: 15), "artist page didn't load")
            snap("21-artist", dark: dark)
            app.swipeUp()
            snap("22-artist-scrolled", dark: dark)
            app.terminate()

            app = launch(tab: "home", extra: ["-StandupRoute", "album:mock-al-lower"], dark: dark)
            XCTAssertTrue(element("album.track.0", in: app).waitForExistence(timeout: 15), "album page didn't load")
            snap("23-album", dark: dark)
            app.swipeUp()
            snap("24-album-scrolled", dark: dark)
            app.terminate()
        }
    }

    // MARK: Flows

    /// Typing searches as you go, shows comedy only (the pop "Live at the
    /// Arena" never appears), and a result opens its special.
    @MainActor
    func testSearchShowsOnlyComedy() {
        let app = launch(tab: "search", dark: false)
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("live")

        let comedy = labelled("Live from the Laundromat", in: app)
        XCTAssertTrue(comedy.waitForExistence(timeout: 10), "no as-you-type suggestion")
        XCTAssertFalse(labelled("Live at the Arena", in: app).exists, "a non-comedy album was suggested")
        snap("25-search-suggestions", dark: false)

        field.typeText("\n")
        let result = element("result.album.mock-al-laundromat", in: app)
        XCTAssertTrue(result.waitForExistence(timeout: 10), "no search result")
        XCTAssertFalse(labelled("Live at the Arena", in: app).exists, "a non-comedy album was in the results")

        result.tap()
        XCTAssertTrue(element("album.track.0", in: app).waitForExistence(timeout: 10), "the special didn't open")
    }

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

        // The empty list's button goes over to Search.
        let find = element("library.empty.find", in: app)
        require(find, in: app, timeout: 5, "no Find Comedians in an empty list")
        find.tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 10), "Find Comedians didn't open Search")
    }

    /// A bit in the results plays when tapped, as everywhere else; touch and
    /// hold offers its special.
    @MainActor
    func testSearchBitPlaysAndShowsItsSpecial() {
        let app = launch(tab: "search", extra: ["-StandupSearch", "maya"], dark: false)
        let bit = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "result.track.")).firstMatch
        require(bit, in: app, timeout: 15, "no bits in the results")
        for _ in 0..<3 where !bit.isHittable {
            app.swipeUp()
        }
        bit.tap()
        require(labelled("Now Playing:", in: app), in: app, timeout: 10, "tapping a bit didn't play it")
        XCTAssertFalse(element("album.track.0", in: app).exists, "tapping a bit opened its special")

        bit.press(forDuration: 1.2)
        let showSpecial = app.buttons["Show Special"]
        require(showSpecial, in: app, timeout: 5, "no Show Special for a bit")
        snap("20b-search-bit-menu", dark: false, settle: 0.4)
        showSpecial.tap()
        require(element("album.track.0", in: app), in: app, timeout: 10, "Show Special didn't open the special")
    }
}
