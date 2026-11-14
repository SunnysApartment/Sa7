#!/bin/bash
# Installs (or updates) Sa7 from its latest GitHub release.
#   curl -fsSL https://sunnysapartment.github.io/Sa7/install.sh | bash
# Files that curl downloads aren't marked as "downloaded from the internet", so macOS opens Sa7
# without the unidentified-developer prompt. Nothing else on the Mac is changed.
set -euo pipefail

URL="https://github.com/SunnysApartment/Sa7/releases/latest/download/Sa7.dmg"
DEST=/Applications
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

TMP=$(mktemp -d)
cleanup() { hdiutil detach -quiet "$TMP/mnt" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

echo "Downloading Sa7…"
curl -fL --progress-bar "$URL" -o "$TMP/Sa7.dmg"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$TMP/mnt" "$TMP/Sa7.dmg"
codesign --verify --strict "$TMP/mnt/Sa7.app" || { echo "The download looks damaged. Nothing was installed." >&2; exit 1; }

pkill -x Sa7 2>/dev/null && sleep 1 || true
rm -rf "$DEST/Sa7.app"
ditto "$TMP/mnt/Sa7.app" "$DEST/Sa7.app"
xattr -dr com.apple.quarantine "$DEST/Sa7.app" 2>/dev/null || true

open "$DEST/Sa7.app"
echo "Sa7 is installed in $DEST and running. Look for the ✓ in the menu bar."
