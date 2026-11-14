#!/bin/bash
# Builds build.noindex/Sa7.app (Apple Silicon and Intel). Usage: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN=$(swift build -c release "${ARCHS[@]}" --show-bin-path)
# ".noindex" keeps Spotlight from listing this test copy next to the installed app.
APP=build.noindex/Sa7.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Sa7" "$APP/Contents/MacOS/Sa7"
cp Info.plist "$APP/Contents/"
cp Resources/Sa7.icns "$APP/Contents/Resources/"

# A stable signature keeps the Accessibility permission across versions. Preference: Apple Developer ID,
# then the project's own self-signed "Khaled Omar (Sa7)" certificate (free; macOS still shows the
# first-launch warning, but permissions survive updates), then Apple Development, then ad-hoc.
if [ -z "${IDENTITY:-}" ]; then
  IDS=$(security find-identity -p codesigning)
  for want in '"Developer ID Application' '"Khaled Omar (Sa7)"' '"Apple Development'; do
    IDENTITY=$(grep -F "$want" <<<"$IDS" | head -1 | awk '{print $2}' || true)
    [ -n "$IDENTITY" ] && break
  done
fi
IDENTITY=${IDENTITY:--}
NAME=$(security find-identity -p codesigning | grep -F "$IDENTITY" | head -1 | grep -oE '"[^"]+"' | tr -d '"' || true)
if [ "${DMG:-}" = 1 ] && [[ "$NAME" == *@* ]]; then
  echo "Refusing to package a public build signed with a certificate that contains an email: $NAME" >&2
  exit 1
fi
codesign --force --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP (signed with: ${NAME:-ad-hoc})"

if [ "${DMG:-}" = 1 ]; then
  STAGE=$(mktemp -d)
  cp -R "$APP" "$STAGE/" && ln -s /Applications "$STAGE/Applications"
  rm -f build.noindex/Sa7.dmg
  hdiutil create -quiet -volname Sa7 -srcfolder "$STAGE" -format UDZO build.noindex/Sa7.dmg
  echo "Packaged build.noindex/Sa7.dmg"
fi
