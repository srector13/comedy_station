# Phase 7 plan: Spotify as a second provider

**Status:** plan for review, nothing built yet.

**Goal:** Spotify alongside Apple Music. You can search, open specials and comedians, save them to the App Library, and play them. Apple Music stays the default, and everything that works today keeps working.

## What Spotify allows as of 2026

- **Playback runs in the Spotify app.** Spotify's iOS SDK ("App Remote") remote-controls the installed Spotify app. Playing a chosen track needs Premium. Standup can't play Spotify audio itself.
- **Catalog data comes from the Spotify Web API.** You sign in with Spotify inside Standup (PKCE, so no client secret goes in the app).
- **Development Mode limits (since February 2026):**
  - The app's owner needs Premium.
  - At most 5 users.
  - Search returns at most 10 results per page.
  - Artist top tracks, new releases and browse categories are gone.
- **What that means for Standup:**
  - Search, special pages and comedian pages work. A comedian page lists their specials, but it can't have Top Bits.
  - Home and Browse stay Apple Music and external-chart driven.
- **Playback speed isn't available.** App Remote has no speed control for music tracks, so the speed menu is hidden for Spotify. ±15 s works, through seek.

## Hard rules, proposed wording

1. **Never write to a streaming library.** Never write to the Apple Music library (unchanged), and never save, follow or create anything in the Spotify library either. The App Library stays Standup's own store.
2. **Playback per provider:**
   - Apple Music plays only through `ApplicationMusicPlayer`, with `affectsListeningHistory = false` (unchanged).
   - Spotify plays only through the Spotify app, via App Remote.
   - Spotify has no way to keep plays out of its listening history. The Spotify settings in Standup say so and suggest Spotify's Private Session.
3. **Comedy only.** One shared filter still decides.
   - Spotify albums carry no genres. A Spotify album counts when its artist's genres include "comedy".
   - Spotify has been returning fewer artist genres. When an artist has none, the special is matched to its Apple Music version (same title and comedian) and that version's genres decide. Anything unconfirmed is hidden.
4. **Branding.** Still no Apple logos. Spotify requires its name or logo next to Spotify content, plus a link back to Spotify, so Spotify rows carry a small "Spotify" label.

## What you'd set up

1. **Spotify Premium** on the account that owns the developer app.
2. **developer.spotify.com → Dashboard → Create app:**
   - Name: `Standup`
   - Redirect URI: `standup://spotify-callback`
   - APIs: **Web API** and **iOS**
   - iOS bundle ID: `PolarReality.Standup`
3. Copy the **Client ID** (no secret is needed). Add it as a GitHub repository secret named `SPOTIFY_CLIENT_ID`; the IPA build puts it in the app.
4. Under **User Management**, add the Spotify account(s) that will use Standup (up to 5).
5. Have the Spotify app installed on the phone.

## How it's built

- **Providers:** every catalog item gets a provider (`appleMusic`, `spotify`), and IDs become provider-qualified (`spotify:album:…`).
  - The App Library models gain a `provider` field, defaulting to Apple Music.
  - It syncs through iCloud like the rest. CloudKit's development schema updates by itself.
- **SpotifyAuth:** sign-in with `ASWebAuthenticationSession` (PKCE). Tokens go in the Keychain and refresh automatically. Connect and disconnect live in a new Settings sheet, under Library.
- **SpotifyCatalog:** a second `CatalogProviding` over the Web API, through the same comedy filter.
  - Search (two pages of 10).
  - A special and its bits.
  - A comedian and their specials.
- **SpotifyPlaybackEngine:** a second `PlaybackEngine` over App Remote.
  - Plays a special from a chosen bit, pause and play, next, previous, ±15 s and Up Next.
  - It reports position and which bit is playing, so progress, resume, Continue Listening and the playing-bit highlight work as they do now.
- **Player routing:** the player service picks the engine for what's being played.
- **Search:** a segmented control at the top (Apple Music | Spotify) when Spotify is connected.
- **Tests:**
  - Mock Spotify catalog and engine, used in unit tests and CI screenshots.
  - A real-device checklist added to `docs/DEVICE_TEST.md`.

## Risks to know up front

- **Switching apps:** App Remote wakes the Spotify app to connect, so the first play after launch jumps to Spotify for a moment and back.
- **Background connection:** the connection can drop in the background. The player reconnects when you return.
- **Spotify policy changes:** Development Mode limits have tightened twice in two years, and could again.
- **Spotify's developer terms:** I'll re-read the current terms before building, in case they restrict building another player around Spotify content.

## Open questions for you

1. **Search:** should one search show both providers, one after the other? Or use a switch (the plan above)?
2. **The same special on both services:** should it appear as one entry in the App Library, or as two?
3. **Order of work:** Phase 6 (CarPlay) first, or Spotify first? CarPlay still needs Apple's entitlement.

## Size

About the size of Phases 2 to 4 together. It ships as its own branch and builds, after this plan is approved.
