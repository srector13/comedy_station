import XCTest

/// Playback in mock mode: the mini-player, Now Playing's controls, resume,
/// and screenshots in portrait and landscape. (MusicKit can't play in the
/// Simulator; the real thing is tested on a device.)
final class PlaybackUITests: StandupUITestCase {
    /// Play a special, open Now Playing, and use every control.
    @MainActor
    func testPlayThenUseNowPlaying() {
        let app = launch(tab: "home", extra: ["-StandupRoute", "album:mock-al-lower"], dark: false)
        let play = element("album.play", in: app)
        require(play, in: app, timeout: 15, "no Play button")
        play.tap()

        let mini = element("miniPlayer.open", in: app)
        require(labelled("Now Playing: Intro", in: app), in: app, "the mini-player doesn't show the first bit")
        snap("40-mini-player", dark: false)

        mini.tap()
        let playPause = element("nowPlaying.playPause", in: app)
        require(playPause, in: app, "Now Playing didn't open")
        XCTAssertEqual(playPause.label, "Pause")

        element("nowPlaying.forward15", in: app).tap()
        playPause.tap()
        XCTAssertTrue(waitForLabel(playPause, "Play"), "didn't pause")

        element("nowPlaying.speed", in: app).tap()
        let fast = app.buttons["1.5×"]
        require(fast, in: app, timeout: 5, "no speed menu")
        fast.tap()
        XCTAssertTrue(waitForValue(element("nowPlaying.speed", in: app), "1.5×"), "speed didn't change")

        element("nowPlaying.upNext", in: app).tap()
        let third = element("nowPlaying.upNext.2", in: app)
        require(third, in: app, timeout: 5, "no Up Next")
        third.tap()
        XCTAssertTrue(waitForLabel(element("nowPlaying.title", in: app), notEqualTo: "Intro"), "Up Next didn't jump")
    }

    /// Pause partway, and the special's Play becomes Resume and picks up
    /// at the same bit.
    @MainActor
    func testPlayResumesWhereItStopped() {
        let app = launch(tab: "home", extra: ["-StandupRoute", "album:mock-al-lower"], dark: false)
        let play = element("album.play", in: app)
        require(play, in: app, timeout: 15, "no Play button")
        play.tap()
        element("miniPlayer.open", in: app).tap()

        element("nowPlaying.upNext", in: app).tap()
        let bit = element("nowPlaying.upNext.1", in: app)
        require(bit, in: app, timeout: 5, "no Up Next")
        bit.tap()
        let title = element("nowPlaying.title", in: app)
        XCTAssertTrue(waitForLabel(title, notEqualTo: "Intro"))
        let resumedTitle = title.label
        element("nowPlaying.playPause", in: app).tap()

        // Close Now Playing.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        require(play, in: app, timeout: 10, "Now Playing didn't close")
        XCTAssertTrue(waitForLabel(play, "Resume"), "Play didn't become Resume")
        play.tap()
        require(labelled("Now Playing: \(resumedTitle)", in: app), in: app, "didn't resume at the same bit")
    }

    /// Adding a special adds its comedian too.
    @MainActor
    func testAddingASpecialAddsItsComedian() {
        let app = launch(tab: "home", extra: ["-StandupRoute", "album:mock-al-lower"], dark: false)
        let toggle = app.buttons["library.toggle"]
        require(toggle, in: app, timeout: 15, "no + button")
        toggle.tap()
        require(element("library.feedback", in: app), in: app, timeout: 5, "no confirmation")
        app.tabBars.buttons["Library"].tap()
        element("library.comedians", in: app).tap()
        require(element("library.comedian.mock-ar-maya", in: app), in: app, "the comedian wasn't added with the special")
    }

    /// A paused special: Now Playing, Up Next and landscape; and the
    /// mini-player on its own.
    @MainActor
    func testNowPlayingScreens() {
        let session = ["-StandupNowPlaying", "album:mock-al-lower:3:125"]
        for dark in [false, true] {
            var app = launch(tab: "home", extra: session + ["-StandupShowNowPlaying", "YES"], dark: dark)
            require(element("nowPlaying.playPause", in: app), in: app, timeout: 15, "Now Playing didn't open")
            snap("43-now-playing", dark: dark)

            element("nowPlaying.upNext", in: app).tap()
            require(element("nowPlaying.upNext.0", in: app), in: app, timeout: 5, "no Up Next")
            snap("44-up-next", dark: dark)
            element("nowPlaying.upNext", in: app).tap()

            XCUIDevice.shared.orientation = .landscapeLeft
            require(element("nowPlaying.playPause", in: app), in: app, "Now Playing gone in landscape")
            snap("45-now-playing-landscape", dark: dark, settle: 1.5)
            XCUIDevice.shared.orientation = .portrait
            app.terminate()

            app = launch(tab: "home", extra: session, dark: dark)
            require(labelled("Now Playing:", in: app), in: app, timeout: 15, "no mini-player")
            snap("46-mini-player-paused", dark: dark)
            app.terminate()
        }
    }

    // MARK: Helpers

    @MainActor
    private func waitForLabel(_ element: XCUIElement, _ label: String) -> Bool {
        wait(for: NSPredicate(format: "label == %@", label), on: element)
    }

    @MainActor
    private func waitForLabel(_ element: XCUIElement, notEqualTo label: String) -> Bool {
        wait(for: NSPredicate(format: "exists == true AND label != %@", label), on: element)
    }

    @MainActor
    private func waitForValue(_ element: XCUIElement, _ value: String) -> Bool {
        wait(for: NSPredicate(format: "value == %@", value), on: element)
    }

    @MainActor
    private func wait(for predicate: NSPredicate, on element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 8) == .completed
    }
}
