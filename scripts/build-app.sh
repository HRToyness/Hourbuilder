#!/usr/bin/env bash
# Bouwt UrenReconstructie.app uit het SPM-project — release config, hardened
# runtime, Developer ID-gesigneerd. Klaar voor notarization na build-dmg.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.1.0}"
BUNDLE_ID="${BUNDLE_ID:-nl.toynessit.urenreconstructie}"
APP_NAME="${APP_NAME:-UrenReconstructie}"
DEV_ID_CERT="${DEV_ID_CERT:-Developer ID Application: Teun Kralt (TPQD8BJ6DW)}"

DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

echo "▸ Iconset / .icns aanmaken"
"$ROOT/scripts/generate-icon.swift" "$ROOT/Resources" >/dev/null

echo "▸ Release build"
swift build -c release --product UrenReconstructie

# SPM zet de binary onder triple-specifiek pad; .build/release is een symlink.
EXEC="$ROOT/.build/release/UrenReconstructie"
if [[ ! -f "$EXEC" ]]; then
    EXEC="$(find "$ROOT/.build" -name UrenReconstructie -type f -path '*/release/*' | head -1)"
fi
if [[ -z "${EXEC:-}" || ! -f "$EXEC" ]]; then
    echo "ERR: kan build-output binary niet vinden" >&2
    exit 1
fi

echo "▸ Bundle aanmaken op $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$EXEC" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

YEAR="$(date +%Y)"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>nl</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSCalendarsUsageDescription</key>
    <string>UrenReconstructie leest agenda-afspraken om je urenregistratie te reconstrueren. Data blijft lokaal op je Mac.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>UrenReconstructie leest agenda-afspraken om je urenregistratie te reconstrueren. Data blijft lokaal op je Mac.</string>
    <key>NSHumanReadableCopyright</key>
    <string>© $YEAR Toyness IT</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
EOF

echo "▸ Code sign (hardened runtime + entitlements)"
codesign --force --options runtime --timestamp \
    --entitlements "$ROOT/Resources/Entitlements.plist" \
    --sign "$DEV_ID_CERT" \
    "$APP"

echo "▸ Verify signing"
codesign --verify --strict --verbose=2 "$APP"

# spctl assess zegt "rejected" zolang niet genotariseerd — dat is ok voor nu.
spctl --assess --type execute --verbose "$APP" 2>&1 || \
    echo "  (spctl assess geeft pas 'accepted' na notarization — verwacht)"

echo "✓ $APP klaar (versie $VERSION)"
