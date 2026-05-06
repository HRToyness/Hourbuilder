#!/usr/bin/env bash
# Een commando voor de hele release flow: build .app → bundle .dmg → notarize.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/scripts/build-app.sh"
"$ROOT/scripts/build-dmg.sh"
"$ROOT/scripts/notarize.sh"

VERSION="${VERSION:-0.1.0}"
APP_NAME="${APP_NAME:-UrenReconstructie}"

echo
echo "🎉 Release $VERSION klaar:"
echo "   $ROOT/dist/$APP_NAME-$VERSION.dmg"
