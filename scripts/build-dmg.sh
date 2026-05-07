#!/usr/bin/env bash
# Maakt een gesigneerde .dmg met drag-to-Applications layout.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=branding.sh
source "$ROOT/scripts/branding.sh"

DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
STAGING="$DIST/dmg-staging"

if [[ ! -d "$APP" ]]; then
    echo "ERR: $APP bestaat niet — run scripts/build-app.sh eerst" >&2
    exit 1
fi

echo "▸ DMG staging in $STAGING"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "▸ DMG bouwen"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG"

rm -rf "$STAGING"

echo "▸ DMG signen"
codesign --force --sign "$DEV_ID_CERT" --timestamp "$DMG"

echo "✓ $DMG klaar"
ls -lh "$DMG"
