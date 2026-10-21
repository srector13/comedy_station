import XCTest

/// Spotify in mock mode: connecting in Settings, searching Spotify, and a
/// Spotify special playing "in Spotify" (no speed menu). The real thing
/// needs the Spotify app and Premium, so it's tested on a device.
final class SpotifyUITests: StandupUITestCase {
    @MainActor
    func testConnectSpotifyInSettings() {
        let app = launch(tab: "home", dark: false)
        let gear = element("settings.open", in: app)
        require(gear, in: app, timeout: 15, "no Settings button")
        gear.tap()
        let field = element("settings.spotifyClientID", in: app)
        // Below the Service and TMDB sections.
        for _ in 0..<2 where !field.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        require(field, in: app, timeout: 5, "no Spotify Client ID field")
        field.tap()
        field.typeText("mock-client-id")
        element("settings.spotifySaveClientID", in: app).tap()
        let connect = element("settings.spotifyConnect", in: app)
        for _ in 0..<2 where !connect.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        require(connect, in: app, timeout: 5, "no Connect Spotify")
        snap("82-settings-spotify", dark: false)
        connect.tap()
        require(element("settings.spotifyConnected", in: app), in: app, timeout: 5, "Spotify didn't connect")
        snap("83-settings-spotify-connected", dark: false)
    }

    @MainActor
    func testSearchAndPlayFromSpotify() {
        for dark in [false, true] {
            let app = launch(tab: "search", extra: ["-StandupSpotify", "connected", "-StandupSearch", "lena"], dark: dark)
            let spotify = app.buttons["Spotify"]
            require(spotify, in: app, timeout: 15, "no Apple Music | Spotify switch")
            spotify.tap()
            let special = element("result.album.spotify:album:mock-small-talk", in: app)
            require(special, in: app, timeout: 10, "no Spotify special in the results")
            XCTAssertFalse(labelled("Party Mix", in: app).exists, "a non-comedy Spotify album was shown")
            snap("84-search-spotify", dark: dark)

            special.tap()
            require(element("album.openInSpotify", in: app), in: app, timeout: 10, "no Open in Spotify on the special")
            snap("85-spotify-special", dark: dark)
            element("album.play", in: app).tap()
            let mini = element("miniPlayer.open", in: app)
            require(mini, in: app, timeout: 10, "no mini-player")
            mini.tap()
            require(element("nowPlaying.spotify", in: app), in: app, timeout: 10, "Now Playing doesn't say it's playing in Spotify")
            XCTAssertFalse(element("nowPlaying.speed", in: app).exists, "Spotify has no speed control")
            snap("86-now-playing-spotify", dark: dark)
            app.terminate()
        }
    }
}
