<div align="center">

<img src="Resources/AppIcon-1024.png" width="160" alt="UrenReconstructie">

# UrenReconstructie

**Reconstrueer je urenregistratie aan het einde van een traject — zonder dat klantdata je Mac verlaat.**

[![Download v0.1.0](https://img.shields.io/badge/Download-v0.1.0-1f1f1f?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/HRToyness/Hourbuilder/releases/latest)
&nbsp;
[![macOS 14+](https://img.shields.io/badge/macOS-14+-2dd4a8?style=for-the-badge)](#systeem-vereisten)
&nbsp;
[![Notarized](https://img.shields.io/badge/Notarized-Apple-2dd4a8?style=for-the-badge)](#)

</div>

---

UrenReconstructie helpt zelfstandige consultants en kleine bureaus om aan het einde van een traject een **kloppende, factuur-aansluitende urenregistratie** op te bouwen op basis van fragmentarische bronnen — agenda-afspraken, leverancier-bijlages, klantmail, eigen aantekeningen.

Geen live timetracking, geen cloud, geen team-collaboratie. Eén Mac, jouw data, jouw factuur.

## ⬇ Download

**[Laatste release · v0.1.0](https://github.com/HRToyness/Hourbuilder/releases/latest)** — klik de `.dmg` aan de download-pagina, sleep de app naar Applications, klaar.

De dmg is **gesigneerd met Developer ID en genotariseerd door Apple** — Gatekeeper geeft geen waarschuwing.

Toekomstige updates worden automatisch geleverd via Sparkle: de app checkt 1× per dag stilletjes op een nieuwe versie en presenteert een modal "Install and Relaunch" als er een is. Of pak het zelf via menu **UrenReconstructie → Check for Updates…**.

## Wat doet 'ie

- 📊 **Matrix view**: personen op de Y-as, weken op de X-as. Heat-map cellen kleuren naar uren-intensiteit. Status per cel: bevestigd, concept (gestreept), AI-voorstel (paarse rand met ✨)
- 📅 **Imports**: Apple Calendar (via EventKit), CSV, Excel (XLSX). Dedupe op event-id of bestand-regel — re-import doet geen dubbele inserts. Undo per import-batch
- ✨ **AI assist**: Claude (Anthropic) of OpenAI als provider — switch in Settings. Een [anonimisatie-laag](.claude/skills/claude-api-anonymized/SKILL.md) zorgt dat alleen rolnamen (`intern_dev_1`, `klant_pm`) en gehashte project-context naar de API gaan, nooit echte namen of klantnamen
- 📋 **Templates**: bewaar fase-structuur, vaste teamleden, of placeholder-rollen ("PM klant", "webbouwer leverancier") die bij apply ingevuld worden. "Opslaan als template" extracteert automatisch fases met relatieve timing
- 📈 **Insights tab**: SwiftUI Charts met uren-per-week (lijn, gestapeld per groep), uren-per-fase (staaf), verdeling per persoon (donut)
- 🏠 **Portfolio dashboard**: cross-project overzicht met sparklines en KPIs zodra geen project geselecteerd is
- 🔮 **Forecast inline**: lineaire ETA-extrapolatie ("ETA op koers · 195u op 31 mei") in de matrix totals-rij
- 📤 **Export**: PDF (per partij — klant / intern / leverancier) en CSV (Excel-compatibel met UTF-8 BOM). Configureerbare branding (accent kleur + logo) in Settings
- 🔄 **Auto-update**: Sparkle-gebaseerd, EdDSA-signed appcast op GitHub Pages. Geen handmatig downloaden bij volgende versies.

## Privacy

| Wat | Waar |
|---|---|
| Activiteiten, projecten, personen, fases | SQLite in `~/Library/Application Support/UrenReconstructie/` |
| API sleutels (Anthropic + OpenAI) | macOS Keychain — nooit plaintext, nooit gelogd |
| Logo, accent kleur preferences | UserDefaults |
| AI-aanvragen | HTTPS naar `api.anthropic.com` of `api.openai.com` met **alleen** anonieme rolnamen + uren-buckets, geen namen, e-mails of klantgegevens |

Geen telemetrie, geen analytics, geen iCloud sync. Time Machine is je backup.

## Systeem vereisten

- **macOS 14 (Sonoma) of nieuwer** — gebruikt SwiftUI Charts en moderne EventKit APIs
- Apple Silicon of Intel (universal binary)
- Voor AI: Anthropic API key OR OpenAI API key (geen abonnement vereist, pay-as-you-go)
- Voor agenda import: toegang tot Apple Calendar bij eerste gebruik (vraagt 'ie zelf om)

## Build vanaf source

Geen Xcode project — alles draait op SPM + bash scripts.

```bash
git clone https://github.com/HRToyness/Hourbuilder.git
cd Hourbuilder
swift run UrenReconstructie     # development run
swift test                       # 109 tests draaien
```

Voor een eigen distributable build:

```bash
# Eenmalig
scripts/setup-notary.sh         # Apple notary credentials in Keychain

# Volledige release pipeline
scripts/release.sh              # SPM build → .app → .dmg → notarize → staple
```

Versie override: `VERSION=0.2.0 scripts/release.sh`. Output in `dist/`.

Voor signing heb je een **Developer ID Application** certificaat nodig. De scripts gebruiken Team ID `TPQD8BJ6DW` — pas aan via env var `DEV_ID_CERT` als je je eigen build maakt.

## Architectuur in één oogopslag

Modulair Swift Package met 6 targets:

```
App         ← @main entry point + RootView
Features    ← SwiftUI views + @Observable view models per feature
Database    ← GRDB + repositories + ProjectTemplateApplyService + ForecastCalculator
Services    ← CalendarService (EventKit), CsvParser, XlsxImporter, ClaudeService,
              OpenAIService, AnonymizationService, KeychainHelper, BrandingStore,
              ExportService (PDF + CSV)
Models      ← Pure record types met GRDB conformances
Styling     ← Color/Font extensions, herbruikbare componenten (HeatMapCell,
              FilterChip, AvatarBadge, KPIRow, Sparkline, etc.)
```

Spec-document met de oorspronkelijke vereisten staat in [`urenreconstructie-spec.md`](urenreconstructie-spec.md). Design-notities voor latere features in [`docs/superpowers/specs/`](docs/superpowers/specs/).

---

<div align="center">

Gemaakt met SwiftUI + GRDB + ❤️

</div>
