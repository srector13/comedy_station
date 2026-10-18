#!/usr/bin/env bash
# Enforces Standup's hard rules 1 and 2 on the app's Swift sources:
#
#   1. Never write to the user's Apple Music library: no MusicLibrary,
#      LibraryPlaylist, MediaPlayer library or player APIs.
#   2. Play only with ApplicationMusicPlayer (never SystemMusicPlayer), and
#      only from Services/PlayerService.swift, which must set
#      affectsListeningHistory = false on its queues.
#
# Comment lines are ignored, so docs may name the APIs they forbid.
# Runs in CI (ios-gate.yml) and before every commit:
#
#     scripts/audit_no_library_writes.sh
set -euo pipefail

cd "$(dirname "$0")/.."
SRC="Standup"
PLAYER="Standup/Services/PlayerService.swift"
fail=0

# Swift lines matching $1 (extended regex), minus comment lines.
code_hits() {
  grep -rnE --include='*.swift' "$1" "$SRC" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true
}

forbid() {
  local pattern="$1" why="$2" hits
  hits="$(code_hits "$pattern")"
  if [ -n "$hits" ]; then
    echo "::error::${why}"
    echo "$hits"
    fail=1
  fi
}

forbid 'MusicLibrary([^A-Za-z]|$)' "MusicLibrary writes to the Apple Music library (rule 1)"
forbid 'LibraryPlaylist' "LibraryPlaylist is the Apple Music library's playlists (rule 1)"
forbid 'MPMediaLibrary|MPMediaPlaylist|addItem\(withProductID|MPMusicPlayerController' \
  "MediaPlayer library and player APIs are off limits (rules 1 and 2)"
forbid 'SystemMusicPlayer' "Play only with ApplicationMusicPlayer (rule 2)"
forbid 'import[[:space:]]+MediaPlayer' "MediaPlayer is not used; MusicKit's ApplicationMusicPlayer only (rule 2)"

# ApplicationMusicPlayer and queues only inside PlayerService.
outside="$(code_hits 'ApplicationMusicPlayer|\.Queue\(|affectsListeningHistory' | grep -v "^${PLAYER}:" || true)"
if [ -n "$outside" ]; then
  echo "::error::ApplicationMusicPlayer and its queues belong in ${PLAYER} only (rule 2)"
  echo "$outside"
  fail=1
fi

if [ -f "$PLAYER" ]; then
  if ! grep -qE 'affectsListeningHistory[[:space:]]*=[[:space:]]*false' "$PLAYER"; then
    echo "::error::${PLAYER} never sets affectsListeningHistory = false (rule 2)"
    fail=1
  fi
  if grep -nE 'affectsListeningHistory[[:space:]]*=[[:space:]]*true' "$PLAYER"; then
    echo "::error::${PLAYER} sets affectsListeningHistory = true (rule 2)"
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "Audit FAILED"
  exit 1
fi
echo "Audit passed: no Apple Music library writes, no system player, no listening-history queues."
