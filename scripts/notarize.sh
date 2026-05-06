#!/usr/bin/env bash
# Submit de .dmg naar Apple's notary service, wacht op resultaat, en staple
# het ticket zodat de .dmg ook offline gevalideerd wordt.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.1.0}"
APP_NAME="${APP_NAME:-UrenReconstructie}"
PROFILE="${NOTARY_PROFILE:-urenreconstructie-notary}"

DIST="$ROOT/dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

if [[ ! -f "$DMG" ]]; then
    echo "ERR: $DMG bestaat niet — run scripts/build-dmg.sh eerst" >&2
    exit 1
fi

if ! security find-generic-password -s "com.apple.gke.notary.tool" -a "$PROFILE" >/dev/null 2>&1; then
    cat >&2 <<EOF
ERR: notary profile '$PROFILE' niet gevonden in Keychain.

Setup eerst eenmalig:
    scripts/setup-notary.sh

EOF
    exit 1
fi

echo "▸ Submit naar Apple notary (kan een paar minuten duren)…"
xcrun notarytool submit "$DMG" \
    --keychain-profile "$PROFILE" \
    --wait

echo "▸ Stapler ticket op .dmg"
xcrun stapler staple "$DMG"

echo "▸ Verify"
spctl --assess --type install --verbose "$DMG"

echo "✓ $DMG genotariseerd en gestapeld — klaar voor distributie"
