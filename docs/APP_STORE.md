# Before submitting to the App Store

What App Review or App Store Connect would flag in Standup, as of October 2026, and where each stands.

## Fixed

| What | Why it mattered | Fix |
|---|---|---|
| No privacy manifest | Standup reads UserDefaults, an API Apple requires a stated reason for. Uploads without one are rejected (ITMS-91053). | `Standup/Resources/PrivacyInfo.xcprivacy`: no tracking, no data collected, UserDefaults for the app's own settings (reason CA92.1). The Spotify SDK ships its own manifest. |
| iCloud sync off for App Store copies | The library decided whether it could sync by reading the embedded provisioning profile. App Store and TestFlight copies have none, so every customer's library would have stayed on one device. | A copy without a profile is trusted to sync: Apple signs it with the app's own entitlements, iCloud container included (`SigningInfo.iCloudProblem`). |
| A sideloading tool named in the app | The MusicKit setup screen told people to re-sign in Feather and pointed at a file in this repository. | Plain setup wording; Feather stays in the docs. |
| Every person needed a TMDB key | A reviewer would have had to sign up for a TMDB developer key to see Home's specials. | The TMDB relay ([TMDB_RELAY.md](TMDB_RELAY.md)): nobody pastes a key once it's deployed and the build points at it. |
| Every build was 1.0.0 (1) | App Store Connect needs each upload's build number to go up. | Release builds are stamped `1.0.N` (build `N`). An App Store upload from Xcode sets its own. |
| Export compliance prompt | Each upload asked about encryption. | `ITSAppUsesNonExemptEncryption = NO`: Standup only uses HTTPS and a SHA-256 hash for Spotify sign-in, both exempt. |

## Needs a decision before submitting

1. **The Spotify route (likely rejection).** Using Spotify means creating your own Spotify developer app and pasting its Client ID, in the first-launch setup and in Settings. App Review rejects features a reviewer can't use without registering as a developer (Guideline 2.1, App Completeness). A single built-in Client ID would remove that step (with PKCE it isn't a secret), but a Spotify app in Development Mode only serves the few accounts its owner lists, and Spotify now grants wider access only to established businesses. Recommendation: submit Apple Music only, with the Spotify route left to sideloaded builds behind a build setting, unless Spotify grants extended quota.
2. **Looking like Apple's Music app (some risk).** Guideline 5.2.5 asks apps not to look confusingly like Apple's own. Standup uses standard system components with its own name, icon and amber color, which is normally fine, but the review notes should say it's an independent comedy player built with MusicKit.
3. **TMDB's terms.** TMDB's free API covers non-commercial apps. A paid app, ads or in-app purchases need TMDB's commercial license first.

## In App Store Connect

- **Age rating:** specials are frequently explicit. Answer the questionnaire for frequent profanity, crude humor and mature themes; expect the highest rating band.
- **App Privacy:** Data Not Collected, matching the privacy manifest. Searches go straight to Apple Music (or Spotify); the TMDB relay sees only which public lists are asked for and keeps no logs of its own.
- **Review notes:** playing needs an Apple Music subscription (a reviewer's own works). Mention that Home's specials come from TMDB, matched to Apple Music albums, and that nothing is ever added to the Apple Music library.
- **Signing:** archive with automatic signing for distribution. That turns `aps-environment` to production (the entitlements file says development, for builds from Xcode) and embeds the iCloud container. MusicKit needs the App ID's MusicKit service, as in [MUSICKIT_SETUP.md](MUSICKIT_SETUP.md).

## Checked and fine

- **Background modes:** `audio` keeps `ApplicationMusicPlayer` playing with the screen off; `remote-notification` brings iCloud changes in. Both are used.
- **Permissions:** only Apple Music, with its usage string. No location, camera, contacts or tracking.
- **iPad:** all four orientations, so multitasking works without `UIRequiresFullScreen`.
- **App icon:** 1024 px, no transparency, with dark and tinted variants.
- **Launch-argument mock mode:** only reachable from Xcode or UI tests, not by anyone using the app.
