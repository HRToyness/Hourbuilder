#!/usr/bin/env bash
# Genereert/update docs/appcast.xml met EdDSA-signed entries voor alle .dmg
# bestanden in dist/archive/. Sparkle's update-checker leest deze appcast
# vanaf https://hrtoyness.github.io/Hourbuilder/appcast.xml.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.1.1}"
APP_NAME="${APP_NAME:-UrenReconstructie}"

DIST="$ROOT/dist"
ARCHIVE="$DIST/archive"
APPCAST="$ROOT/docs/appcast.xml"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

if [[ ! -f "$DMG" ]]; then
    echo "ERR: $DMG bestaat niet — run scripts/build-dmg.sh eerst" >&2
    exit 1
fi

# Sparkle artifact path
SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
if [[ ! -x "$SPARKLE_BIN/generate_appcast" ]]; then
    echo "ERR: $SPARKLE_BIN/generate_appcast niet gevonden — run swift package resolve" >&2
    exit 1
fi

mkdir -p "$ARCHIVE"
cp -f "$DMG" "$ARCHIVE/"

# generate_appcast leest alle .dmg in $ARCHIVE, signed elk met de Keychain-
# private-key, schrijft full appcast.xml met release notes link naar GitHub.
echo "▸ Appcast genereren uit $ARCHIVE"
"$SPARKLE_BIN/generate_appcast" "$ARCHIVE" \
    --download-url-prefix "https://github.com/HRToyness/Hourbuilder/releases/download/v$VERSION/" \
    --link "https://hrtoyness.github.io/Hourbuilder/" \
    -o "$APPCAST"

echo "✓ $APPCAST geschreven"
echo "  (commit + push naar main om GitHub Pages te updaten)"
