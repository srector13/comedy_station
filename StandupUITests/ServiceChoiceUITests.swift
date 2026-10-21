import XCTest

/// First launch asks which service Standup runs on. Spotify goes through
/// its setup to tabs without Browse, with Home and Search on Spotify; Apple
/// Music asks for access straight away.
final class ServiceChoiceUITests: StandupUITestCase {
    @MainActor
    func testFirstLaunchOnSpotify() {
        let app = launch(extra: ["-StandupService", "ask"], dark: false)
        let spotify = element("service.spotify", in: app)
        require(spotify, in: app, timeout: 15, "no service choice")
        XCTAssertTrue(element("service.appleMusic", in: app).exists, "no Apple Music choice")
        snap("00-choose-service", dark: false)
        spotify.tap()

        let field = app.textFields["spotifySetup.clientID"]
        require(field, in: app, timeout: 10, "no Spotify setup")
        snap("00b-spotify-setup", dark: false)
        field.tap()
        field.typeText("mock-client-id\n")
        let connect = element("spotifySetup.connect", in: app)
        require(connect, in: app, timeout: 5, "no Connect Spotify")
        connect.tap()

        require(element("home.new", in: app), in: app, timeout: 15, "no Spotify specials on Home")
        XCTAssertTrue(element("home.new.spotify:album:mock-small-talk", in: app).exists, "Home's specials aren't Spotify's")
        XCTAssertFalse(app.tabBars.buttons["Browse"].exists, "Browse on the Spotify route")
        XCTAssertFalse(element("miniPlayer.open", in: app).exists, "a mini-player with nothing playing")
        snap("87-home-spotify", dark: false)
    }

    @MainActor
    func testSpotifyRouteSearchesOnlySpotify() {
        for dark in [false, true] {
            let app = launch(tab: "search", extra: ["-StandupService", "spotify", "-StandupSpotify", "connected", "-StandupSearch", "theo"], dark: dark)
            require(element("result.album.spotify:album:mock-late-checkout", in: app), in: app, timeout: 15, "no Spotify results")
            XCTAssertFalse(app.segmentedControls.firstMatch.exists, "a service switch on the Spotify route")
            snap("88-search-spotify-route", dark: dark)
            app.terminate()
        }
    }

    @MainActor
    func testFirstLaunchOnAppleMusic() {
        let app = launch(access: "notDetermined", extra: ["-StandupService", "ask"], dark: false)
        let appleMusic = element("service.appleMusic", in: app)
        require(appleMusic, in: app, timeout: 15, "no service choice")
        appleMusic.tap()
        require(app.tabBars.buttons["Browse"], in: app, timeout: 15, "no tabs after choosing Apple Music")
    }

    /// Without Apple Music access, the gate offers Spotify instead.
    @MainActor
    func testAppleMusicGateOffersSpotify() {
        let app = launch(access: "denied", dark: false)
        let useSpotify = element("gate.useSpotify", in: app)
        require(useSpotify, in: app, timeout: 15, "no way over to Spotify")
        useSpotify.tap()
        require(app.textFields["spotifySetup.clientID"], in: app, timeout: 10, "no Spotify setup")
    }
}
