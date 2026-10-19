# Playback on a device

MusicKit can't play in the Simulator, so CI tests playback with a mock engine. This checklist covers the real thing on an iPhone.

## Before you start

- Complete [MUSICKIT_SETUP.md](MUSICKIT_SETUP.md): the App ID has MusicKit, and the IPA is re-signed in Feather with your team and the bundle ID `PolarReality.Standup`.
- Be signed in to Apple Music with an active subscription.
- Note one comedy special and check that it's not in Music's Recently Played. You'll check again at the end.

## Checklist

1. **Catalog.** Search a comedian you know: you get comedians, specials and bits, and no music. Open a special and a comedian page.
2. **Play a special.** Tap Play on a special. Audio starts at bit 1, and the mini-player shows the bit and comedian.
3. **Now Playing.** Tap the mini-player.
   - The artwork, title, comedian and special name match what's playing.
   - The scrubber moves. Drag it, and playback jumps there.
   - **+15 / −15** move 15 seconds. +15 near the end of a bit goes to the next bit.
   - **Previous / Next** change bits. Previous within the first 3 seconds goes back a bit; later, it restarts the bit.
   - **Speed**: pick 1.5×. Speech is faster, and it stays at 1.5× when the next bit starts.
   - **Up Next** lists the rest of the special. Tap one to jump to it.
   - Rotate to landscape: artwork on the left, controls on the right.
4. **Lock screen.** Lock the phone. Audio keeps playing, and play/pause works from the lock screen and Control Center.
5. **Resume.**
   - Pause partway into bit 3. Leave the special page and come back: the button says **Resume**. Tap it, and it continues at bit 3, at the same spot.
   - Close the app from the app switcher, reopen it, and open the same special. **Resume** still continues from there.
6. **Finish.** Seek to the last 20 seconds of the last bit and let it end. Opening the special again shows **Play**, and it starts at bit 1.
7. **Shuffle.** Shuffle on a special plays its bits in a mixed order. Shuffle on a comedian plays a mix of their top bits.
8. **Library.** Add a special with +. Its comedian appears under Library → Comedians. Remove the special, and the comedian goes too, unless you had added them yourself.
   - Try a comedian Apple files under books, such as Tom Segura. Add one of his specials from Home (touch and hold → Add to Library). He appears under Comedians.
   - Add a single bit from a special's page (touch and hold). Its comedian appears under Comedians too.
   - Specials saved with an earlier version get their missing comedians the first time this version opens.
9. **Listening history (rule 2).** Open the Music app → Home / Recently Played. Nothing you played in Standup appears. Next month's Replay shouldn't count it either.
10. **Apple Music library (rule 1).** Open Music → Library. Nothing you added in Standup is there.

## Spotify (Phase 7)

These steps need the Spotify app, Spotify Premium, and Spotify connected in Settings (see MUSICKIT_SETUP.md, section 5).

11. **Connect.** Go to Settings (the gear) → Spotify → **Connect Spotify**. Sign in, and it says "Connected as …".
12. **Search.** Search a comedian, then switch the control at the top to **Spotify**. Only comedians, specials and bits show, each marked SPOTIFY.
13. **Play.** Play a Spotify special from its third bit. The first time, Standup may switch to Spotify for a moment and back. It plays from bit 3. Now Playing says "Playing in Spotify" with no speed menu.
14. **Controls.** ±15 s, next/previous, Up Next and pause all work, and Standup follows along when you skip in Spotify.
15. **Mixed library.** Add one Spotify special and one Apple Music special. Play Library → Bits. When the Apple Music bits run out, the Spotify bits start, and the other way round.
16. **Spotify library (rule 1).** Open Spotify → Your Library. Nothing you added or played in Standup is saved there.

## If something fails

- **"Can't Reach Apple Music" or "Can't Play"** on every special: the signing team or bundle ID doesn't match the App ID with MusicKit. See MUSICKIT_SETUP.md, step 2.
- **Speed resets to 1×** when a new bit starts: tell me. The app re-applies it, but MusicKit's behavior here varies by iOS version.
- **Anything else:** note the step number and what you saw. A screen recording helps.
