# Hard-rule audit

How each of Standup's four hard rules is enforced, and the evidence as of Phase 5. Rules 1 and 2 are re-checked on every push by `scripts/audit_no_library_writes.sh`, which runs first in CI (`ios-gate.yml`) and in the IPA build (`build-ipa.yml`).

## 1. Never write to the Apple Music library

| Check | Result |
|---|---|
| `MusicLibrary`, `LibraryPlaylist`, `MPMediaLibrary`, `MPMediaPlaylist`, `MPMusicPlayerController`, `addItem(withProductID:)`, `import MediaPlayer` in app code | none (the audit fails the build on any) |
| What the app saves | only `LibraryStore` (SwiftData: `SavedComedian`, `SavedAlbum`, `SavedTrack`, `PlaybackProgress`), in its own store `StandupLibrary`, synced through the person's private CloudKit database `iCloud.PolarReality.Standup` when the profile allows it |
| Downloads | not offered: they would need the Apple Music library |

The App Library keeps `MusicItemID`s and re-loads items from the catalog. It never asks Apple Music to add anything.

## 2. `ApplicationMusicPlayer` only, `affectsListeningHistory = false` on every queue

| Check | Result |
|---|---|
| `SystemMusicPlayer` anywhere | none (audit) |
| Files touching `ApplicationMusicPlayer` | only `Standup/Services/MusicKitPlaybackEngine.swift` (audit) |
| `ApplicationMusicPlayer.Queue(` constructions | exactly one, in `makeQueue`, which sets `affectsListeningHistory = false` on the next line (audit) |
| `player.queue =` assignments | only `player.queue = makeQueue(...)` (audit) |
| `affectsListeningHistory = true` | none (audit) |

`affectsListeningHistory` needs iOS 26.4 or later; the app targets 27.0. Whether comedy stays out of Music's Recently Played on a real device is step 9 of [DEVICE_TEST.md](DEVICE_TEST.md).

## 3. Comedy only

- Every catalog result passes `ComedyFilter.keep` / `isComedy`. An item is kept when any of its genre names contains "comedy", ignoring case. That covers search results, suggestions, album and artist pages (specials, top bits, similar comedians), charts, playlists, and the comedian looked up when a special is added.
- A bit (song) counts only if its album is comedy. One batched request loads the albums.
- New and Popular Specials can come from TMDB. TMDB only names specials. Each one is shown only as its Apple Music album, matched by comedian, title and release date (`SpecialMatcher`), and only after that album passes the same filter. Specials with no comedy album on Apple Music aren't shown.
- Genre ID 3 is used only for `MusicCatalogChartsRequest(genre:)`. The chart's results are still filtered by name. When the chart has no comedy specials or bits, Home and Browse fill that section from catalog searches for comedy, through the same filter, and label it without chart ranks.
- Playlists carry no genre names. The app shows only playlists from the Comedy-genre chart, and their pages list only bits on comedy specials.
- Album and artist pages refuse non-comedy items (`CatalogError.notComedy`), so a non-comedy ID can't be opened or played.
- **Tests:** the mock catalog contains non-comedy decoys (a pop artist and album, a soundtrack titled "Comedy of Errors", a comedy bit on a pop compilation, a pop song in a playlist). The unit tests (`ComedyFilterTests`, `MockCatalogTests`, `ChartsAndPlaylistsTests`) and UI tests (`testSearchShowsOnlyComedy`, `testPlaylistShowsOnlyComedy`) assert that each decoy never appears.

## 4. No Apple logos, wordmark or app icon

- **Bundled images:** the original placeholder icon (a mic on a stand, drawn by `scripts/make_app_icon.py`), in three variants, and TMDB's own logo, which its terms require next to its credit in Settings → About.
- **SF Symbols:** no `applelogo` or other Apple-branded symbols. The app uses generic ones (`music.mic`, `house.fill`, `play.fill`, …).
- **"Apple Music" as words:** appears only as plain text naming the service, in onboarding and error messages. This is the name of the subscription, not the wordmark.
- **Subscription offer:** the "Try Apple Music" button opens Apple's own `musicSubscriptionOffer` sheet. That sheet is Apple-presented, not app-drawn branding.

## How to re-run

```
scripts/audit_no_library_writes.sh
```
