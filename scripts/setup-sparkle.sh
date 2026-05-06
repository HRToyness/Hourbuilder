#!/usr/bin/env bash
# Eenmalige setup van Sparkle EdDSA signing keys. Private key komt in macOS
# Keychain (Sparkle beheert dat zelf), public key wordt in Resources/Sparkle.pub
# gezet — die wordt door build-app.sh als SUPublicEDKey in Info.plist gestopt.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Sparkle CLI tools komen mee met het SPM artifact bundle. Pas resolve eerst
# als de bundle nog niet binnen is gehaald.
SPARKLE_BIN="$ROOT/.build/artifacts/sparkle/Sparkle/bin"
if [[ ! -d "$SPARKLE_BIN" ]]; then
    echo "▸ Sparkle artifact ophalen via swift package resolve…"
    swift package resolve >/dev/null
fi
if [[ ! -x "$SPARKLE_BIN/generate_keys" ]]; then
    echo "ERR: kon $SPARKLE_BIN/generate_keys niet vinden" >&2
    exit 1
fi

PUB_OUT="$ROOT/Resources/Sparkle.pub"

# Probeer eerst bestaande public key uit te lezen — generate_keys -p faalt
# als er geen key in de keychain staat.
if PUB="$("$SPARKLE_BIN/generate_keys" -p 2>/dev/null)" && [[ -n "$PUB" ]]; then
    echo "▸ Bestaande Sparkle key gevonden in Keychain"
else
    echo "▸ Nieuwe Sparkle keypair genereren…"
    "$SPARKLE_BIN/generate_keys"
    PUB="$("$SPARKLE_BIN/generate_keys" -p)"
fi

mkdir -p "$ROOT/Resources"
printf '%s' "$PUB" > "$PUB_OUT"

echo "✓ Public key naar $PUB_OUT"
echo "  Inhoud: $PUB"
echo
echo "  Deze key is veilig om te committen — het is per definitie publiek."
echo "  De private key staat in je macOS Keychain (zoek naar 'Sparkle' / 'ed25519')"
echo "  en wordt door scripts/release.sh gebruikt om elke .dmg te ondertekenen."
