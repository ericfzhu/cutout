#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/artifacts/Cutout.app"
OUT="$ROOT/artifacts/release"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
codesign --verify --deep --strict "$APP"
mkdir -p "$OUT"
ARCHIVE="Cutout-$VERSION-macOS-arm64.zip"
if [[ -e "$OUT/$ARCHIVE" ]]; then
    echo "Archive already exists: $OUT/$ARCHIVE" >&2
    exit 1
fi
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$ARCHIVE"
(cd "$OUT" && shasum -a 256 "$ARCHIVE" > SHA256SUMS)
echo "Packaged $OUT/$ARCHIVE"
