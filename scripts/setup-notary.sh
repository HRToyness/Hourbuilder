#!/usr/bin/env bash
# Eenmalige setup van notary credentials in de Keychain. Hierna kun je
# scripts/notarize.sh draaien zonder password te tikken.

set -euo pipefail

PROFILE="${NOTARY_PROFILE:-urenreconstructie-notary}"
TEAM_ID="${TEAM_ID:-TPQD8BJ6DW}"

cat <<EOF
==================================================================
Notary credentials setup voor profiel: $PROFILE
==================================================================

Voor dit script heb je nodig:

  1. Je Apple ID e-mail (hetzelfde account als je Developer Program)
  2. Een app-specific password — genereer er één op:
       https://appleid.apple.com → Sign-In and Security → App-Specific Passwords
     Geef 'm bijvoorbeeld de naam: "UrenReconstructie notary"
  3. Team ID: $TEAM_ID (al ingevuld via env var TEAM_ID)

==================================================================

Daarna draait er een interactief commando dat je Apple ID en het
app-specific password vraagt en opslaat in je Keychain als profiel
'$PROFILE'.

Klaar? Druk Enter — of Ctrl-C om te stoppen.
EOF

read -r

read -rp "Apple ID e-mail: " APPLE_ID

xcrun notarytool store-credentials "$PROFILE" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID"

echo
echo "✓ Profiel '$PROFILE' opgeslagen in Keychain."
echo "  Je kunt nu scripts/notarize.sh of scripts/release.sh draaien."
