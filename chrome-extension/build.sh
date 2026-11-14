#!/bin/sh
# Builds the extension in place (load this folder unpacked) and zips it to dist/Sa7-chrome.zip.
set -e
cd "$(dirname "$0")"

if [ ! -f ../sa7-site/franco.js ]; then
  echo "build.sh: ../sa7-site/franco.js is missing. The extension needs the Franco-Arabic converter; add sa7-site/franco.js first." >&2
  exit 1
fi
cp ../sa7-site/convert.js ../sa7-site/franco.js .

mkdir -p icons dist
for size in 16 32 48 128; do
  sips -z "$size" "$size" ../mac/Resources/icon-1024.png --out "icons/icon-$size.png" >/dev/null
done

node test.js
rm -f dist/Sa7-chrome.zip
zip -qr dist/Sa7-chrome.zip manifest.json _locales background.js fix.js convert.js franco.js popup.html popup.css popup.js icons
echo "Built dist/Sa7-chrome.zip"
