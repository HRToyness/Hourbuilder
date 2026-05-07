#!/usr/bin/env bash
# Centrale brand/distributie-config voor alle release scripts.
# Pas deze waarden aan om naar een andere developer/organisatie te releasen
# zonder elk script handmatig te moeten wijzigen.
#
# Override via env-vars (bv. `BUNDLE_ID=com.example.foo scripts/build-app.sh`)
# blijft mogelijk — alle defaults hieronder zijn `: "${VAR:=default}"`.

# App-identiteit
: "${VERSION:=0.1.0}"
: "${APP_NAME:=UrenReconstructie}"
: "${BUNDLE_ID:=nl.toynessit.urenreconstructie}"

# Code signing — Apple Developer ID-certificaat (zoals zichtbaar in Keychain)
: "${DEV_ID_CERT:=Developer ID Application: Teun Kralt (TPQD8BJ6DW)}"

# Copyright string — komt in Info.plist (zichtbaar in About-dialog)
: "${COPYRIGHT_HOLDER:=Toyness IT}"

# Sparkle / GitHub Pages auto-update kanaal
: "${GITHUB_OWNER:=HRToyness}"
: "${GITHUB_REPO:=Hourbuilder}"
: "${SPARKLE_FEED_URL:=https://hrtoyness.github.io/${GITHUB_REPO}/appcast.xml}"
: "${RELEASE_DOWNLOAD_URL_PREFIX:=https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/v${VERSION}/}"
: "${RELEASE_LANDING_URL:=https://hrtoyness.github.io/${GITHUB_REPO}/}"

# Notarytool keychain profiel (zie scripts/setup-notary.sh)
: "${NOTARY_PROFILE:=urenreconstructie-notary}"

export VERSION APP_NAME BUNDLE_ID DEV_ID_CERT COPYRIGHT_HOLDER \
    GITHUB_OWNER GITHUB_REPO SPARKLE_FEED_URL \
    RELEASE_DOWNLOAD_URL_PREFIX RELEASE_LANDING_URL NOTARY_PROFILE
