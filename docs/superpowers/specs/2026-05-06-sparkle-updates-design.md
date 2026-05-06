# In-app updates via Sparkle

> Status: design approved 2026-05-06.

## 1. Doel

Gebruiker kan vanuit de app checken of er een nieuwe versie is, en die automatisch downloaden + installeren. Standaard macOS update-UX (modal met release notes, "Install and Relaunch" knop, "Skip this version" optie). Industry-standard via Sparkle 2.x.

**In scope**:
- Sparkle 2.x als SPM dep
- `SPUStandardUpdaterController` bootstrap in `@main` App
- "Check for Updates…" menu item (Cmd-cluster onder app-naam)
- Auto-check op interval (1× per dag), silent als up-to-date
- EdDSA signing van elke release
- `appcast.xml` op GitHub Pages (`hrtoyness.github.io/Hourbuilder/appcast.xml`) auto-gegenereerd in release pipeline
- README + landing page documenteren update-flow

**Out of scope (v1)**:
- Beta / pre-release channel
- Delta updates (full .dmg per release is voor 5 MB prima)
- Custom UI rondom de update modal
- Geforceerde updates ("required minimum version")

## 2. Onderdelen

### 2.1 Sparkle dependency

```swift
// Package.swift
.package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
```

App target krijgt `Sparkle` als product dep.

### 2.2 App bootstrap

`Sources/App/UrenReconstructieApp.swift`:

```swift
import Sparkle

@main
struct UrenReconstructieApp: App {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // existing AppDatabase init
    }

    var body: some Scene {
        WindowGroup { RootView(...) }
            .commands {
                CommandGroup(after: .appInfo) {
                    Button("Check for Updates…") {
                        updaterController.checkForUpdates(nil)
                    }
                }
            }
        Settings { SettingsView() }
    }
}
```

Sparkle handelt de hele UX: detect → download → verify EdDSA → install → relaunch.

### 2.3 EdDSA signing key

Eenmalig: `scripts/setup-sparkle.sh` runt `bin/generate_keys` uit het Sparkle artifact bundle. Output:
- Private key → macOS Keychain (Sparkle beheert)
- Public key → `Resources/Sparkle.pub` (committed; het is per definitie publiek)

`Resources/Sparkle.pub` wordt door `build-app.sh` gelezen en als `SUPublicEDKey` in Info.plist gezet. Sparkle weigert updates die niet ondertekend zijn met de bijbehorende private key.

### 2.4 Info.plist toevoegingen

In `build-app.sh` extra keys:

| Key | Waarde |
|---|---|
| `SUFeedURL` | `https://hrtoyness.github.io/Hourbuilder/appcast.xml` |
| `SUPublicEDKey` | inhoud van `Resources/Sparkle.pub` |
| `SUEnableAutomaticChecks` | `true` |
| `SUScheduledCheckInterval` | `86400` (1 dag in seconds) |
| `SUAutomaticallyUpdate` | `false` (gebruiker bevestigt elke install handmatig) |

### 2.5 Appcast generatie

`scripts/release.sh` na de build-dmg stap:

```bash
mkdir -p dist/archive
cp dist/UrenReconstructie-$VERSION.dmg dist/archive/
sparkle/bin/generate_appcast dist/archive \
    -o docs/appcast.xml \
    --download-url-prefix "https://github.com/HRToyness/Hourbuilder/releases/download/v$VERSION/"

git add docs/appcast.xml
git commit -m "Update appcast for v$VERSION"
git push
```

`generate_appcast` doet automatisch:
- Scant alle .dmg files in folder
- Berekent sha256 + EdDSA signature met de Keychain-private-key
- Schrijft volledige appcast.xml met alle versies, gesorteerd descending
- Voegt release notes link toe (eerste bestaande `release-notes-VERSION.html` of fallback naar GitHub release pagina)

### 2.6 Distributie van appcast

GitHub Pages serveert `docs/appcast.xml` op `https://hrtoyness.github.io/Hourbuilder/appcast.xml` zodra het naar `main` is gepusht (~1 minuut deploy time).

App pollt deze URL elke 24 uur. Geen auth, geen rate limit problemen voor 1 user × 1 check/dag.

## 3. Implementatie volgorde

1. **Sparkle dep + bootstrap + menu** — werkt al (zonder appcast — geeft "kan update niet checken" foutje, maar build is groen)
2. **`scripts/setup-sparkle.sh`** voor key generation, runnen om `Resources/Sparkle.pub` te maken
3. **Info.plist updates in `build-app.sh`** — leest Sparkle.pub
4. **Appcast generatie in `release.sh`** — `dist/archive/` + `generate_appcast`
5. **README + landing page** — kort vermelden van auto-update support

Tussen elke stap: rebuild .app om te testen dat compile groen is.

## 4. Tests

- Geen Swift unit tests nodig — Sparkle is vendor library, niet onze code
- E2E test handmatig: build v0.1.0 → installeer → bouw v0.2.0 → run release.sh → open app v0.1.0 → "Check for Updates" → modal verschijnt → click Install → app update naar v0.2.0

## 5. Risico's

- **Eerste appcast**: bevat alleen v0.2.0+. v0.1.0 (al gepubliceerd) wordt niet via Sparkle aangeboden — gebruikers moeten één keer handmatig 0.2.0 downloaden, daarna pakt Sparkle het over. Acceptabel.
- **Sparkle CLI binaries pad**: SPM artifact bundles staan op verschillende plekken per Swift versie. `release.sh` doet `find` om ze te lokaliseren.
- **Hardened runtime + Sparkle XPC services**: Sparkle 2.x ships z'n eigen XPC services en die moeten apart gesigneerd worden binnen de .app. `build-app.sh` moet `--deep` gebruiken of explicit per-binary signen.

## 6. Wat verandert er voor gebruikers

Bij v0.2.0+ → eerste keer wachten op modal → klik "Install and Relaunch" → app update zichzelf. Geen handmatige download meer nodig.

`Check for Updates…` menu item geeft on-demand check.
