# MusicKit setup

Standup plays the Apple Music catalog through MusicKit. MusicKit needs no API keys in the app. It mints its developer token itself, but only for an app whose **bundle ID has the MusicKit app service enabled** and that is **signed by the team that owns that bundle ID**.

| | |
|---|---|
| Bundle ID | `PolarReality.Standup` (MyTeams' `PolarReailty.Hawk` is spelled differently; Standup uses the spelling of its registered App ID) |
| Team | `68L4YU8U89` (same as MyTeams) |

Both live in `Standup.xcodeproj` (`PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM`). If you change them, change them there, here, and in the release notes in `.github/workflows/build-ipa.yml`.

## 1. Register the App ID with MusicKit (once)

1. Go to [developer.apple.com/account](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Identifiers** → **+**.
2. Choose **App IDs** → **App** → Continue.
3. Description `Standup`. Bundle ID **Explicit**: `PolarReality.Standup`. Continue → Register.
4. Open the new identifier, switch to the **App Services** tab, tick **MusicKit**, and Save.
   - MusicKit is an App Service, not a Capability. There is no entitlement to add and nothing changes in the provisioning profile.
   - The token service can take a few minutes to pick the change up.

## 2. Install the unsigned IPA with Feather

1. Run **Actions → Build unsigned IPA → Run workflow** (the workflow is dispatchable once it is on `main`). It publishes a release `v1.0.N` with `Standup-v1.0.N-unsigned.ipa`.
2. On the portal, make a provisioning profile for `PolarReality.Standup` that includes your iPhone's UDID. Use **iOS App Development** with your Apple Development certificate, or **Ad Hoc** with your Apple Distribution certificate.
3. Export that certificate from Keychain Access as a `.p12`.
4. In Feather, import the `.p12` and the `.mobileprovision`, then import the IPA and sign it.
   - **Keep the bundle ID `PolarReality.Standup`.** Don't let Feather rewrite it.
   - **Use your own team's certificate.** With a different team's certificate, or a changed bundle ID, authorization still succeeds, but Apple refuses the developer token and every catalog request fails. The app then shows "MusicKit Isn't Set Up" with how this copy is signed.
   - Feather's built-in or shared certificates belong to other teams, so they can't work with MusicKit.

## Troubleshooting: "MusicKit Isn't Set Up" / "Failed to request developer token"

The app checks the catalog right after Apple Music access is granted. If Apple refuses the developer token, the screen shows how this copy is signed and what MusicKit needs:

```
This copy is signed as <TEAM>.<bundle id> (<name>).
MusicKit needs 68L4YU8U89.PolarReality.Standup.
```

A line "Its bundle ID is …" is added when the app's bundle ID differs from its profile. When the signing already matches, the screen says so: then the App ID is missing MusicKit.

| What the first line shows | Fix |
|---|---|
| A team other than `68L4YU8U89` | Re-sign in Feather with your own Apple Development or Distribution `.p12` and a profile from team `68L4YU8U89`. |
| A bundle ID other than `PolarReality.Standup` (or a wildcard `*`) | Use an explicit profile for `PolarReality.Standup` and turn off Feather's bundle ID change. |
| Exactly `68L4YU8U89.PolarReality.Standup` | The signing is right. Check that **MusicKit** is ticked under the App ID's **App Services** tab and saved. Then wait a few minutes and tap **Check Again**. |

## 3. iCloud sync for the App Library (optional)

The App Library (comedians, specials, bits, where you left off) syncs through your private iCloud database. That keeps it the same on every device, and it comes back after you delete and reinstall the app. Feather signs with the provisioning profile's entitlements, so the profile has to include iCloud:

1. **Identifiers → + → iCloud Containers.** Description `Standup`, identifier `iCloud.PolarReality.Standup`. Register.
2. **Identifiers → PolarReality.Standup → Capabilities tab.** Tick **iCloud** (with CloudKit), click **Edit** or **Configure** next to it, tick `iCloud.PolarReality.Standup`, and continue. Tick **Push Notifications** too, so changes arrive without reopening the app. Save, then confirm.
3. **Profiles → your Standup profile → Edit → Save** to regenerate it with iCloud, then download it again. In Safari, long-press Download and choose **Download Linked File**.
4. **Feather:** sign the IPA with the new profile. Keep the bundle ID.
5. On each device, be signed in to iCloud. Each device also has to be in the profile's device list, since it's a development profile.

The foot of the Library tab says whether the library is syncing, when it last synced, or why it isn't. Without iCloud in the profile, the library stays on that device, as before.

- **Development environment:** a copy signed with a development profile syncs to CloudKit's Development environment. Keep using a development profile. An Ad Hoc or App Store build uses Production, which starts empty and needs the schema deployed in the CloudKit Console first.
- **No data loss when you turn it on:** items saved before iCloud was set up upload on the first sync.
- **Duplicates are merged:** the same item added on two devices is merged into one.

## 4. New & Popular Specials from TMDB (optional)

Apple's comedy charts lean on novelty songs and decades-old albums. With a TMDB key, Home builds its shelves from The Movie Database's stand-up specials, across Netflix, Max, Prime Video and the rest:

- **New Specials:** out in the last year.
- **Popular Specials:** the most watched of the last three years.
- **Trending Comedians:** the comedians behind those specials.
- **Essential Specials:** the best rated of all time.

Home also adds **More from …** for the comedians in your library.

**Browse** gets two grids from TMDB as well:

- **Streaming Services:** the stand-up on Netflix, HBO Max, Prime Video, Hulu, Peacock and Paramount+, where they're in your region.
- **Decades:** the best-known specials of each decade, from the 2020s back to the 1970s.

Each special is shown and played as its Apple Music album: same comedian (searched across their whole Apple Music discography), a matching title, and released around the same time. Specials without one are left out. Matches are remembered on the phone, so only the first load takes a while; a miss is tried again after a few days, because audio often comes out after the video. Bits and playlists still come from Apple's chart. On the Spotify route, the same lists are matched to Spotify albums instead.

1. Create an account at [themoviedb.org](https://www.themoviedb.org), then go to **Settings → API → Request an API key**.
2. Choose **Developer** (personal, non-commercial use) and fill in the short form.
3. Copy the **API Key**. The longer **API Read Access Token** works too.
4. In Standup, tap the gear on Home, Browse or Library. Paste the key and tap **Save Key**. Standup checks it with TMDB before keeping it.

The key lives in your keychain and reaches your other devices through iCloud Keychain. It's never built into the app, because the release IPAs are public. TMDB's terms ask for its logo and notice, and for credit to JustWatch, where its streaming data and the services' logos come from. All three are in Settings → About.

## 5. Spotify (optional)

Standup asks on first launch whether to run on **Apple Music** or **Spotify** (Settings → Service switches later).

- **On Spotify**, Standup never asks for Apple Music: Search, Home's and Browse's TMDB lists, the App Library and playback are all Spotify's. Apple's charts and playlists aren't there (Spotify gives apps in Development Mode none of its own). Without a TMDB key, Home has only what you've saved and Browse asks for a key.
- **On Apple Music**, connecting Spotify in Settings adds an Apple Music | Spotify switch to Search.

Either way, Spotify specials and comedians open, save to the App Library, and play. Playback happens in the Spotify app, so it needs Spotify **Premium** and the Spotify app installed.

1. At [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard), **Create app** (Spotify requires the app owner to have Premium):
   - **Name:** `Standup`.
   - **Redirect URI:** `standup://spotify-callback`.
   - **APIs used:** tick **Web API** and **iOS**.
   - **iOS bundle ID:** `PolarReality.Standup`.
2. Under **User Management**, add the Spotify account(s) that will use Standup (Development Mode allows 5).
3. Copy the app's **Client ID**. No secret is needed: Standup signs in with PKCE.
4. In Standup, paste the Client ID: on the Spotify setup screen (the Spotify route; tap **Continue**), or in Settings (the gear) → Spotify (tap **Save Client ID**). Then tap **Connect Spotify** and sign in.

The Client ID is kept in your keychain and syncs to your other devices. Each device signs in to Spotify on its own.

**Listening history:** Spotify has no setting that keeps comedy out of your Spotify listening history, as Apple Music's has. Start a Private Session in Spotify if you'd rather it stayed out.

## 6. On the device

- Sign in to the Apple Music app with an account that has an active subscription.
- On first launch, Standup asks for Apple Music access. If you decline, turn it on later in Settings → Standup → Media & Apple Music.

## What Standup never does

- It never writes to your Apple Music library. Its library is a separate local store (`scripts/audit_no_library_writes.sh` enforces this in CI).
- It plays only through `ApplicationMusicPlayer`, with `affectsListeningHistory = false` on every queue. Comedy stays out of Music's Recently Played, recommendations, and Replay.

## Simulator vs. device

MusicKit playback doesn't work in the Simulator. Catalog browsing needs a signed build with a team (CI's unsigned simulator builds have none). CI therefore runs the app in mock mode (`-StandupMock YES`) for screenshots. Real playback is tested on a device.
