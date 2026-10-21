import UIKit
import XCTest

/// Home, Browse and playlists, plus larger text sizes and iPad.
final class HomeBrowseUITests: StandupUITestCase {
    private let seeded = ["-StandupLibrary", "seeded"]

    @MainActor
    func testHomeBrowseAndPlaylistScreens() {
        for dark in [false, true] {
            var app = launch(tab: "home", extra: seeded, dark: dark)
            require(element("continue.mock-al-lower", in: app), in: app, timeout: 15, "no Continue Listening")
            snap("50-home", dark: dark)
            app.swipeUp()
            snap("51-home-scrolled", dark: dark)
            // Further down: Trending Comedians, More from …, Essential Specials.
            for _ in 0..<4 where !element("home.trending", in: app).exists {
                app.swipeUp()
            }
            require(element("home.trending", in: app), in: app, timeout: 5, "no Trending Comedians")
            snap("51b-home-trending", dark: dark)
            for _ in 0..<4 where !element("home.essential", in: app).exists {
                app.swipeUp()
            }
            require(element("home.essential", in: app), in: app, timeout: 5, "no Essential Specials")
            snap("51c-home-essential", dark: dark)
            app.terminate()

            app = launch(tab: "browse", dark: dark)
            require(element("browse.featured", in: app), in: app, timeout: 15, "no featured special")
            snap("52-browse", dark: dark)
            app.swipeUp()
            snap("53-browse-scrolled", dark: dark)
            app.terminate()
        }
    }

    /// A playlist lists only bits on comedy specials: its pop song is gone.
    @MainActor
    func testPlaylistShowsOnlyComedy() {
        let app = launch(tab: "home", extra: ["-StandupRoute", "playlist:mock-pl-clean"], dark: false)
        require(element("playlist.track.0", in: app), in: app, timeout: 15, "the playlist didn't load")
        XCTAssertFalse(labelled("Radio Edit", in: app).exists, "a non-comedy song is in the playlist")
        XCTAssertFalse(element("playlist.track.3", in: app).exists, "more bits than the comedy ones")
        snap("54-playlist", dark: false)
        element("playlist.play", in: app).tap()
        require(labelled("Now Playing:", in: app), in: app, "the playlist didn't play")
    }

    /// Continue Listening picks the special up where it was left, not at
    /// the first bit.
    @MainActor
    func testContinueListeningResumes() {
        let app = launch(tab: "home", extra: seeded, dark: false)
        let card = element("continue.mock-al-lower", in: app)
        require(card, in: app, timeout: 15, "no Continue Listening")
        card.tap()
        require(labelled("Now Playing:", in: app), in: app, "nothing started")
        XCTAssertFalse(labelled("Now Playing: Intro", in: app).exists, "started over instead of resuming")
    }

    @MainActor
    func testRemoveFromContinueListening() {
        let app = launch(tab: "home", extra: seeded, dark: false)
        let card = element("continue.mock-al-parking", in: app)
        require(card, in: app, timeout: 15, "no Continue Listening")
        card.press(forDuration: 1.2)
        let remove = app.buttons["Remove from Continue Listening"]
        require(remove, in: app, timeout: 5, "no context menu")
        remove.tap()
        // The menu closes before the action runs, and a busy simulator can
        // take seconds per check, so this waits as long as the others.
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 15), .completed, "still on Continue Listening")
    }

    /// The biggest accessibility text size on the busiest screens.
    @MainActor
    func testAccessibilityTextSize() {
        let ax = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        var app = launch(tab: "home", extra: seeded + ax, dark: false)
        require(element("continue.mock-al-lower", in: app), in: app, timeout: 15, "no Continue Listening")
        snap("60-home-ax", dark: false)
        app.terminate()

        app = launch(tab: "home", extra: ["-StandupRoute", "album:mock-al-lower"] + ax, dark: false)
        require(element("album.play", in: app), in: app, timeout: 15, "album didn't load")
        snap("61-album-ax", dark: false)
        // At these sizes the header fills the screen; the bits are below it.
        for _ in 0..<4 where !element("album.track.0", in: app).exists {
            app.swipeUp()
        }
        require(element("album.track.0", in: app), in: app, timeout: 5, "no bits below the header")
        snap("61b-album-bits-ax", dark: false)
        app.terminate()

        app = launch(tab: "home", extra: ["-StandupNowPlaying", "album:mock-al-lower:3:125", "-StandupShowNowPlaying", "YES"] + ax, dark: false)
        require(element("nowPlaying.playPause", in: app), in: app, timeout: 15, "Now Playing didn't open")
        snap("62-now-playing-ax", dark: false)
        app.terminate()

        app = launch(tab: "library", extra: seeded + ax, dark: true)
        require(element("library.comedians", in: app), in: app, timeout: 15, "no library")
        snap("63-library-ax", dark: true)
    }

    /// Settings: the TMDB key for New and Popular Specials (mock mode
    /// accepts any key and keeps it only in memory) and TMDB's credit.
    @MainActor
    func testSettingsKeepATMDBKey() {
        for dark in [false, true] {
            let app = launch(tab: "home", dark: dark)
            let gear = element("settings.open", in: app)
            require(gear, in: app, timeout: 15, "no Settings button")
            gear.tap()
            let field = element("settings.tmdbKey", in: app)
            require(field, in: app, timeout: 5, "no TMDB key field")
            XCTAssertTrue(element("settings.service", in: app).exists, "no service section")
            snap("80-settings", dark: dark)

            field.tap()
            field.typeText("mock-key")
            element("settings.tmdbSave", in: app).tap()
            require(element("settings.tmdbSaved", in: app), in: app, timeout: 5, "the key wasn't kept")
            snap("81-settings-key-saved", dark: dark)
            // The credit is at the bottom, below the fold.
            let credit = element("settings.tmdbCredit", in: app)
            for _ in 0..<3 where !credit.exists {
                app.swipeUp()
            }
            XCTAssertTrue(credit.exists, "no TMDB credit")
            element("settings.done", in: app).tap()
            app.terminate()
        }
    }
}

/// iPad layouts. CI runs this class on an iPad simulator; on iPhone it skips.
final class IPadScreenshotTests: StandupUITestCase {
    @MainActor
    func testIPadScreens() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("iPad only")
        }
        let seeded = ["-StandupLibrary", "seeded"]
        for dark in [false, true] {
            var app = launch(tab: "home", extra: seeded, dark: dark)
            require(element("continue.mock-al-lower", in: app), in: app, timeout: 20, "no Continue Listening")
            snap("70-ipad-home", dark: dark)
            app.terminate()

            app = launch(tab: "home", extra: ["-StandupRoute", "artist:mock-ar-maya"], dark: dark)
            require(element("artist.featured", in: app), in: app, timeout: 20, "artist didn't load")
            snap("71-ipad-artist", dark: dark)
            app.terminate()

            app = launch(tab: "home", extra: ["-StandupRoute", "album:mock-al-lower"], dark: dark)
            require(element("album.track.0", in: app), in: app, timeout: 20, "album didn't load")
            snap("72-ipad-album", dark: dark)
            app.terminate()

            app = launch(tab: "home", extra: ["-StandupNowPlaying", "album:mock-al-lower:3:125", "-StandupShowNowPlaying", "YES"], dark: dark)
            require(element("nowPlaying.playPause", in: app), in: app, timeout: 20, "Now Playing didn't open")
            snap("73-ipad-now-playing", dark: dark)
            app.terminate()

            app = launch(tab: "library", extra: seeded, dark: dark)
            require(element("library.comedians", in: app), in: app, timeout: 20, "no library")
            snap("74-ipad-library", dark: dark)
            app.terminate()
        }
    }
}
