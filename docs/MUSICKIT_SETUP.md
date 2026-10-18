# MusicKit setup

Standup plays the Apple Music catalog through MusicKit. MusicKit needs no API keys in the app. It mints its developer token itself, but only for an app whose **bundle ID has the MusicKit app service enabled** and that is **signed by the team that owns that bundle ID**.

| | |
|---|---|
| Bundle ID | `PolarReailty.Standup` |
| Team | `68L4YU8U89` (same as MyTeams) |

Both live in `Standup.xcodeproj` (`PRODUCT_BUNDLE_IDENTIFIER`, `DEVELOPMENT_TEAM`). If you change them, change them there, here, and in the release notes in `.github/workflows/build-ipa.yml`.

## 1. Register the App ID with MusicKit (once)

1. Go to [developer.apple.com/account](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Identifiers** → **+**.
2. Choose **App IDs** → **App** → Continue.
3. Description `Standup`. Bundle ID **Explicit**: `PolarReailty.Standup`. Continue → Register.
4. Open the new identifier, switch to the **App Services** tab, tick **MusicKit**, and Save.
   - MusicKit is an App Service, not a Capability. There is no entitlement to add and nothing changes in the provisioning profile.
   - The token service can take a few minutes to pick the change up.

## 2. Install the unsigned IPA with Feather

1. Run **Actions → Build unsigned IPA → Run workflow** (the workflow is dispatchable once it is on `main`). It publishes a release `v1.0.N` with `Standup-v1.0.N-unsigned.ipa`.
2. On the portal, make a provisioning profile for `PolarReailty.Standup` that includes your iPhone's UDID. Use **iOS App Development** with your Apple Development certificate, or **Ad Hoc** with your Apple Distribution certificate.
3. Export that certificate from Keychain Access as a `.p12`.
4. In Feather, import the `.p12` and the `.mobileprovision`, then import the IPA and sign it.
   - **Keep the bundle ID `PolarReailty.Standup`.** Don't let Feather rewrite it.
   - **Use your own team's certificate.** With a different team's certificate, or a changed bundle ID, authorization still succeeds, but every catalog request fails. The app then shows "Can't Reach Apple Music".

## 3. On the device

- Sign in to the Apple Music app with an account that has an active subscription.
- On first launch, Standup asks for Apple Music access. If you decline, turn it on later in Settings → Standup → Media & Apple Music.

## What Standup never does

- It never writes to your Apple Music library. Its library is a separate local store (`scripts/audit_no_library_writes.sh` enforces this in CI).
- It plays only through `ApplicationMusicPlayer`, with `affectsListeningHistory = false` on every queue. Comedy stays out of Music's Recently Played, recommendations, and Replay.

## Simulator vs. device

MusicKit playback doesn't work in the Simulator. Catalog browsing needs a signed build with a team (CI's unsigned simulator builds have none). CI therefore runs the app in mock mode (`-StandupMock YES`) for screenshots. Real playback is tested on a device.
