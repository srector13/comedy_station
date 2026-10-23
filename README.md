# Standup

A stand-up comedy player for iOS 27, built on the Apple Music catalog through MusicKit and styled after the iOS 27 Music app. It shows comedy only. It keeps its own App Library, separate from your Apple Music library.

- SwiftUI, Swift 6, iOS 27.0, iPhone and iPad.
- `Standup.xcodeproj` uses synchronized folders: add a Swift file under `Standup/` and it's in the target, with no project edits.

## Hard rules

1. Never write to the Apple Music library.
2. Play only with `ApplicationMusicPlayer`, with `affectsListeningHistory = false` on every queue.
3. Show only items whose `genreNames` contain "Comedy". The charts request uses genre ID 3.
4. No Apple logos, wordmark, or app icon. The icon is original (`scripts/make_app_icon.py`).

Rules 1 and 2 are checked by `scripts/audit_no_library_writes.sh`, locally and in CI.

## Layout

```
Standup/
  App/          entry point, launch options, environment, root gate
  Design/       Theme (the one accent color), shared components
  Models/       catalog value types (ComedyArtist, ComedyAlbum, ComedyTrack)
  Services/     Apple Music access, auth gate, ComedyFilter, MusicKit catalog,
                LibraryStore (App Library), PlayerService + MusicKitPlaybackEngine
  Features/     one folder per screen
  Mock/         mock Apple Music answers and data for previews, tests, CI
  Resources/    Info.plist, asset catalog
StandupTests/   Swift Testing unit tests
StandupUITests/ mock-mode screenshot tests
```

## Running without Apple Music

Launch arguments (also used by the UI tests):

| Argument | Values |
|---|---|
| `-StandupMock YES` | mock Apple Music answers and data |
| `-StandupAccess` | `notDetermined`, `denied`, `restricted`, `noSubscription`, `unavailable`, `ready` |
| `-StandupAppearance` | `light`, `dark` |
| `-StandupTab` | `home`, `browse`, `library`, `search` |
| `-StandupSearch` | a query to search for at launch |
| `-StandupRoute` | `album:<id>`, `artist:<id>` or `playlist:<id>`: open a mock page on the first tab |
| `-StandupLibrary seeded` | start with a filled App Library |
| `-StandupNowPlaying` | `album:<id>:<bit index>:<seconds>`: a paused special |
| `-StandupShowNowPlaying YES` | open Now Playing over it |

## CI

- **iOS Gate** (`.github/workflows/ios-gate.yml`) runs on every push, on the `xcode-27` runner. It runs the audit, the simulator build, the unsigned Release device build, unit tests, UI and screenshot tests on iPhone, and screenshots on an iPad simulator. The screenshots are uploaded as the `standup-screenshots-N` artifact.
- **Build unsigned IPA** (`.github/workflows/build-ipa.yml`) is manual and works the same way as MyTeams' Feather route. It builds Release with signing disabled, as version `1.0.N` (build `N`), zips `Payload/Standup.app`, and publishes a GitHub Release `v1.0.N` with `Standup-v1.0.N-unsigned.ipa`.
- **Deploy TMDB relay** (`.github/workflows/deploy-relay.yml`) deploys `relay/`, the Cloudflare Worker that holds the TMDB key so nobody has to paste one. Manual, and on pushes to `main` that change the relay. Setup: [docs/TMDB_RELAY.md](docs/TMDB_RELAY.md).

Developer-portal and Feather steps: [docs/MUSICKIT_SETUP.md](docs/MUSICKIT_SETUP.md). Playback checklist for a device: [docs/DEVICE_TEST.md](docs/DEVICE_TEST.md). How the hard rules are enforced: [docs/AUDIT.md](docs/AUDIT.md). Before submitting to the App Store: [docs/APP_STORE.md](docs/APP_STORE.md).
