import XCTest

/// Every Add to Library entry point writes to the App Library and shows the
/// confirmation; the Library tab then lists what was added.
final class LibraryUITests: StandupUITestCase {
    /// The + on a special's page adds it, turns into a checkmark, and the
    /// checkmark offers removal.
    @MainActor
    func testPlusButtonAddsAndRemovesASpecial() {
        let app = launch(tab: "home", extra: ["-StandupRoute", "album:mock-al-lower"], dark: false)
        let toggle = app.buttons["library.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        XCTAssertEqual(toggle.label, "Add to Library")

        toggle.tap()
        require(element("library.feedback", in: app), in: app, timeout: 5, "no Added to Library confirmation")
        snap("30a-added-to-library", dark: false, settle: 0.2)
        XCTAssertTrue(waitForLabel(toggle, "In Library"))

        app.tabBars.buttons["Library"].tap()
        element("library.specials", in: app).tap()
        require(element("library.special.mock-al-lower", in: app), in: app, "the special isn't in the library")

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        let remove = app.buttons["Remove from Library"]
        require(remove, in: app, timeout: 5, "no removal confirmation")
        remove.tap()
        XCTAssertTrue(waitForLabel(toggle, "Add to Library"))
    }

    /// Swiping a bit on a special's page adds just that bit.
    @MainActor
    func testSwipeAddsABit() {
        let app = launch(tab: "home", extra: ["-StandupRoute", "album:mock-al-lower"], dark: false)
        let row = element("album.track.2", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        // A slow partial drag reveals the action. (A quick swipeLeft() is a
        // full swipe, which runs the action at once; that adds the bit too.)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5)))
        // Not the toolbar's +, which has the same label.
        let add = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Add to Library", "library.toggle")).firstMatch
        if add.waitForExistence(timeout: 3) {
            snap("30b-swipe-to-add", dark: false, settle: 0.2)
            add.tap()
        }
        require(element("library.feedback", in: app), in: app, timeout: 5, "no Added to Library confirmation")

        app.tabBars.buttons["Library"].tap()
        element("library.bits", in: app).tap()
        require(element("library.bit.mock-al-lower-3", in: app), in: app, "the bit isn't in the library")
    }

    /// Touch and hold a comedian in search results to add them.
    @MainActor
    func testContextMenuAddsAComedian() {
        let app = launch(tab: "search", extra: ["-StandupSearch", "maya"], dark: false)
        let result = element("result.artist.mock-ar-maya", in: app)
        XCTAssertTrue(result.waitForExistence(timeout: 15))
        result.press(forDuration: 1.2)
        let add = app.buttons["Add to Library"]
        require(add, in: app, timeout: 5, "no context menu")
        snap("30c-context-menu", dark: false, settle: 0.3)
        add.tap()
        require(element("library.feedback", in: app), in: app, timeout: 5, "no Added to Library confirmation")

        app.tabBars.buttons["Library"].tap()
        element("library.comedians", in: app).tap()
        require(element("library.comedian.mock-ar-maya", in: app), in: app, "the comedian isn't in the library")
    }

    /// A bit tapped on Library → Bits plays the whole library of bits as
    /// one queue (so Shuffle mixes them all), and its row shows it playing.
    @MainActor
    func testBitsPlayTheWholeLibrary() {
        let app = launch(tab: "library", extra: ["-StandupLibrary", "seeded"], dark: false)
        let bits = element("library.bits", in: app)
        require(bits, in: app, timeout: 15, "no Bits row")
        bits.tap()
        let bit = element("library.bit.mock-al-overthinking-4", in: app)
        require(bit, in: app, "no saved bit")
        bit.tap()
        require(labelled("Now Playing:", in: app), in: app, "the bit didn't start")
        snap("39-library-bit-playing", dark: false)
        XCTAssertTrue(element("library.bits.shuffle", in: app).exists, "no Shuffle on Bits")

        element("miniPlayer.open", in: app).tap()
        element("nowPlaying.upNext", in: app).tap()
        require(labelled("From Library Bits", in: app), in: app, timeout: 5, "Up Next isn't the library's bits")
    }

    /// A filled library and each of its sections, light and dark.
    @MainActor
    func testLibraryScreens() {
        let sections: [(name: String, row: String, anchor: String)] = [
            ("33-library-comedians", "library.comedians", "library.comedian.mock-ar-maya"),
            ("34-library-specials", "library.specials", "library.special.mock-al-lower"),
            ("35-library-bits", "library.bits", "library.bit.mock-al-overthinking-4"),
            ("36-library-recently-added", "library.recentlyAdded", ""),
        ]
        for dark in [false, true] {
            var app = launch(tab: "library", extra: ["-StandupLibrary", "seeded"], dark: dark)
            XCTAssertTrue(element("library.comedians", in: app).waitForExistence(timeout: 15))
            snap("32-library", dark: dark)
            app.terminate()

            for section in sections {
                app = launch(tab: "library", extra: ["-StandupLibrary", "seeded"], dark: dark)
                let row = element(section.row, in: app)
                XCTAssertTrue(row.waitForExistence(timeout: 15))
                row.tap()
                if !section.anchor.isEmpty {
                    XCTAssertTrue(element(section.anchor, in: app).waitForExistence(timeout: 10), "\(section.name): missing \(section.anchor)")
                }
                snap(section.name, dark: dark)
                app.terminate()
            }
        }
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ label: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 5) == .completed
    }
}
