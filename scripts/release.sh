#!/usr/bin/env bash
# Een commando voor de hele release flow: build .app → bundle .dmg → notarize.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=branding.sh
source "$ROOT/scripts/branding.sh"

"$ROOT/scripts/build-app.sh"
"$ROOT/scripts/build-dmg.sh"
"$ROOT/scripts/notarize.sh"

echo
echo "🎉 Release $VERSION klaar:"
echo "   $ROOT/dist/$APP_NAME-$VERSION.dmg"
