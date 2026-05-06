# Visual polish — UrenReconstructie

> Status: design approved 2026-05-06. Implementation pending.

## 1. Doel

Tilt de bestaande app van "werkt" naar "voelt als een serieuze tool". Alle features blijven; we vervangen de generieke SwiftUI-default styling door een coherent, info-dense visueel systeem in de stijl van Notion / Airtable / Linear-list.

**In scope**: visuele upgrade van bestaande schermen, nieuwe styling-componenten, kleine layout-aanpassingen die de info-densiteit versterken (sidebar cards i.p.v. plain rows, KPI-strip in detail header, heat-map matrix).

**Out of scope**:
- Nieuwe features of workflows
- Wijzigingen aan datamodel, repositories of services
- Dark mode (alles licht; donker thema kan later)
- Charts/sparklines in v1 (heat-map dekt visualisatie van uren al)
- Onboarding flow / sample data
- Settings layout herontwerp (huidige TabView volstaat)

## 2. Designrichting

**Power spreadsheet, light**. Crème achtergrond, donkere tekst, kleur als signaal niet als decoratie. Pastel status pills, filter chips, dichte tabellen, voortgangsbalken, persoon-avatars. Alle kleur dient een betekenis (status, intensiteit, type) — geen decoratieve gradients.

**Referentie-mockup**: `.superpowers/brainstorm/.../full-mockup.html` (door gebruiker goedgekeurd op 2026-05-06).

## 3. Design tokens

### 3.1 Kleur

Bestaande `Color.appPrimary` etc. blijven, maar paletwaarden worden vervangen + uitgebreid.

| Token | Hex | Rol |
|---|---|---|
| `appBackground` | `#FAFAF7` | Window content bg, totalen rij |
| `appSurface` | `#FFFFFF` | Detail panel, cellen, kaarten |
| `appSidebar` | `#F5F5F0` | Sidebar bg |
| `appPrimary` | `#1F1F1F` | Body tekst, koppen, active chip |
| `appTextSecondary` | `#6A6A66` | Meta tekst, labels, caption |
| `appTextTertiary` | `#8A8A85` | Placeholder, "geen waarde" |
| `appBorder` | `#E5E5E0` | Lijnen, kaartranden |
| `appBorderStrong` | `#DDDDD5` | Header onder, scheidingen |

**Status pills (pastel bg + donkere tekst)**:

| Status | Bg | Text |
|---|---|---|
| Lopend / bevestigd / op koers | `#DCF5E5` | `#0A6B40` |
| Concept / waarschuwing | `#FFF1D9` | `#9F6B00` |
| Afgewezen / neutraal / gefactureerd | `#E5E5E0` | `#5A5A57` |
| AI voorstel | `#FAEEFC` | `#7A2299` |
| Klant tag | `#FFF6D9` | `#9F6B00` |
| Intern tag | `#E0F0E5` | `#0F7B6C` |
| Leverancier tag | `#E8F4FF` | `#114B7A` |

**Heat-map schaal voor matrix cellen** (uren-buckets, 5 niveaus):

| Bucket | Bg | Text |
|---|---|---|
| 0 (leeg) | transparant | — |
| 1–4 | `#E8F4FF` | default |
| 5–12 | `#C5E1FB` | `#114B7A` |
| 13–24 | `#9CCBF6` | `#0A3559` |
| 25+ | `#74B5F0` | `#0A3559` (bold) |

**Speciale cel-overlays**:
- AI-voorstel: 1px solid `#B560D4` rand + bg `#FAEEFC` + ✨ glyph
- Onbevestigd import: diagonale strepen pattern (#FFF + #FFF8E0)
- Afgewezen: 50% opacity op heat-map bg

**Avatar kleuren** (deterministisch per naam, 6 paren bg+text):
- `#E8DCEF` / `#5C2A82` (paars)
- `#FCD9C1` / `#8A4012` (oranje)
- `#D4F0E1` / `#0A5C2E` (groen)
- `#D9E5FA` / `#1B3A7A` (blauw)
- `#F5E0E0` / `#7A1F1F` (rood)
- `#EAEACE` / `#5A5215` (olijf)

### 3.2 Typografie

System font (`-apple-system` / SF Pro). Inter als optionele upgrade later.

| Token | Size | Weight | Use |
|---|---|---|---|
| `appTitle` | 22 | bold (700) | Project naam in detail header |
| `appH1` | 17 | semibold | Section titels |
| `appH2` | 13 | semibold | Card naam, kolom kop bold |
| `appBody` | 12 | regular | Body |
| `appLabel` | 10 | medium uppercase tracking 0.6 | Tabkolom-label, KPI-label |
| `appMeta` | 10.5 | regular | Meta lijn onder cards |
| `appNumber` | 22 | bold tabular-nums | Totaal getallen |
| `appNumberSmall` | 11 | medium tabular-nums | Cel uren |

**Belangrijke regel**: alle numerieke waarden krijgen `monospacedDigit()` (Swift's tabular-nums) — voorkomt jitter bij wisselende waarden.

### 3.3 Spacing & radius

- Padding: 4 / 6 / 8 / 10 / 12 / 14 / 18 / 24 / 32
- Card radius: 6
- Pill radius: capsule (volledig rond)
- Chip radius: 14 (semi-capsule)
- Input radius: 6
- Window radius: 10 (bij minimal toolbar)

### 3.4 Lijnen & schaduwen

- Standaard border: 1px `appBorder`
- Card schaduw (sidebar selected, popover): `0 12px 40px rgba(0,0,0,0.08)` voor sheets, `0 1px 2px rgba(0,0,0,0.04)` voor cards
- Active sidebar item: linker streep 2px `appPrimary` + bg `appSurface`

## 4. Componentbibliotheek

### 4.1 Bestaande componenten — herzien

`Sources/Styling/Components/`:

- **`AppStatusBadge`** → keep, vervang interne bg/fg-mapping met nieuwe pastel-paren. Toon types `.lopend`, `.bevestigd`, `.concept`, `.afgewezen`, `.gefactureerd`, `.aiVoorstel`, `.klant`, `.intern`, `.leverancier`. Verwijder oude `.accent` / `.warning` / `.success` / `.neutral` of map ze door.
- **`AppCard`** → behoud, verlaag schaduw (`0 1px 2px`), accent-streep optioneel maken via init param.
- **`AppPrimaryButton`** → behoud, kleur upgrade. Plus secundaire variant nodig.
- **`AppSectionHeader`** → wijzigen: kleinere variant zonder accent-streep voor in-scherm gebruik (huidige variant overpowered voor sidebar/sheet titels).
- **`MatrixCell`** → vervangen door `HeatMapCell` (zie 4.2).

### 4.2 Nieuw — Styling/Components/

| Naam | Doel |
|---|---|
| `AppSecondaryButton` | Outline variant — voor "Annuleren", neutrale acties |
| `AppIconButton` | Icon-only knop voor toolbar (Importeer/Exporteer met SF Symbol) |
| `FilterChip` | Toggle chip met active/inactive states; optionele dot indicator |
| `HeatMapCell` | Matrix cel met intensiteits-bg, optioneel AI-rand, onbevestigd-streep, ✨ glyph |
| `AvatarBadge` | Cirkel met initialen, deterministische kleur per naam |
| `ProgressBar` | Linear, configureerbare fill kleur |
| `DeltaLabel` | "+/-Nu" met groen/rood/grijs status |
| `KPIRow` | Label-boven-getal blok voor totalen rij |
| `CountBadge` | Klein rond getal-badge voor tabs ("42") |
| `SearchField` | Sidebar zoekveld met SF Symbol leading icon |

### 4.3 Nieuw — Features/Components/

| Naam | Doel |
|---|---|
| `ProjectCardRow` | Sidebar rij met naam + status pill + klant + totalen + voortgangsbalk |
| `DetailHeader` | Project detail header: breadcrumb + grote titel + status pill + KPI strip |
| `SectionTabBar` | Tab segmented control met count badges (bv. "Activiteiten 42") |
| `MatrixFilterBar` | FilterChip rij voor groep / bron / fase |
| `MatrixTotalsRow` | Voet-rij met KPI per groep + voortgang + delta tekst |

## 5. Schermimpact

### 5.1 ProjectListView (sidebar)

Vervang huidige `List` door `ScrollView` + `LazyVStack` met `ProjectCardRow` items. Bovenaan een `SearchField` (filtert in-memory op naam + klantNaam). Header met "Projecten" label + "+ Nieuw" knop blijft. Active selectie via achtergrond + linker accent-streep i.p.v. SwiftUI default highlight.

`ProjectCardRow` toont: naam (bold), status pill rechts, klant onder, dan een meta lijn met "intern X/Y · klant A/B" (tabular nums), tot slot een progress bar als doelTotaal aanwezig.

### 5.2 ProjectDetailView header

Nieuwe `DetailHeader` boven de tabs:
- Breadcrumb: "Projecten · {klantNaam}" (kleine grijze tekst)
- Grote project naam + status pill rechts ernaast
- KPI strip: "12 weken · 42 activiteiten · 3 personen · Factuur INV-2024-001 · 7 mei → 31 juli 2026" (komma-gescheiden, key cijfers in bold)

### 5.3 Tab bar

Vervang `Picker(.segmented)` door custom `SectionTabBar`. Tabs:
- Matrix
- Activiteiten + count badge
- Personen + count badge
- Fases + count badge
- Reconstructie + ✨ count badge (alleen als pending suggestions > 0)

Rechts in dezelfde rij: Importeer-menu + Exporteer-knop (uit huidige toolbar).

### 5.4 Matrix view

- `MatrixFilterBar` met chips (Alle groepen / Klant / Intern / Leverancier + Fase chip + Bron chip). Active chip = donkere bg, inactive = witte bg met dunne rand.
- `HeatMapCell` voor uren cellen — heat-map intensiteit, AI-rand, onbevestigd-streep.
- Header rij krijgt `appSidebar` bg + uppercase tracked label.
- Persoon-kolom toont `AvatarBadge` met initialen + naam + kleine rol regel.
- `MatrixTotalsRow` onderaan: per groep label, getal (tabular), progress bar (waar doel bestaat), delta tekst.

### 5.5 Activiteiten tabel

Behoud SwiftUI `Table` (multi-select werkt prima). Cosmetic upgrade:
- Status kolom toont `AppStatusBadge` i.p.v. tekst.
- Bron kolom toont kleine pill met type kleur.
- Datum + uren kolommen `monospacedDigit()`.
- Persoon kolom: kleine avatar + naam.
- Bulk action bar: knoppen krijgen tellers ("Bevestig (5)") in pill-stijl.

### 5.6 Personen / Fases / Reconstructie

- PersoonListView krijgt `AvatarBadge` in elke rij.
- FaseListView blijft tabel; volgorde-kolom als monotone badge.
- ReconstructionView: gap kaarten met `KPIRow` styling, voorstel-kaarten in grid van 2 kolommen i.p.v. lange lijst.

## 6. Implementatie aanpak

### 6.1 Volgorde

1. **Tokens eerst**: AppColor + AppFont uitbreiden met nieuwe waarden. Bestaande aliases behouden zodat oude views blijven compileren.
2. **Nieuwe styling componenten**: alle items uit 4.2/4.3 toevoegen, met SwiftUI Previews. Geen view nog migreren.
3. **Componenten migreren per scherm** (kan parallel):
   - ProjectListView → ProjectCardRow + SearchField
   - ProjectDetailView → DetailHeader + SectionTabBar
   - MatrixView → MatrixFilterBar + HeatMapCell + MatrixTotalsRow
   - ActiviteitListView → cosmetic kolom-upgrades
   - PersoonListView → AvatarBadge
   - ReconstructionView → grid voorstellen
4. **Cleanup**: oude `MatrixCell`, `StatusBridge` waar overbodig, oude `Picker(.segmented)` weg.

Elke stap is een logisch commit-punt; tests moeten blijven slagen.

### 6.2 Tab counts

Nieuwe property nodig op `ProjectDetailView` om counts te bepalen. Twee opties:
- Optie A (simpel): tab counts uit bestaande VMs lezen via shared parent (`ProjectDetailViewModel`). Vereist nieuw VM type.
- Optie B (pragma): tab bar leest direct uit losse VMs die al bestaan (`activiteitVM.activiteiten.count` etc.). Minder zuiver, geen nieuwe types.

**Keuze**: optie B. Past bij bestaand patroon, geen extra abstractie. Counts ververst wanneer onderliggende VM zijn `.load()` doet.

### 6.3 Avatar kleur deterministisch

```swift
let palette: [(bg: Color, fg: Color)] = [...]
let idx = abs(naam.hashValue) % palette.count
```

`hashValue` is per-launch random in Swift; gebruik in plaats daarvan een eigen stabiele hash (sum van bytes mod palette.count).

### 6.4 Heat-map bucketing

```swift
func bucket(uren: Double) -> Int {
    switch uren {
    case 0: return 0
    case 0..<5: return 1
    case 5..<13: return 2
    case 13..<25: return 3
    default: return 4
    }
}
```

In `HeatMapCell` mapt bucket → bg/text via lookup.

### 6.5 Tabular numbers

Swift API: `Text(value, format: .number).monospacedDigit()` of view modifier `.font(.body.monospacedDigit())`. Verwerken in `AppFont.appNumber()` extension met `.monospacedDigit()` baked-in.

## 7. Testen

Visuele wijzigingen, weinig logica. Bestaande test suite (67 tests) moet groen blijven.

**Nieuw**:
- `AvatarBadgeTests` — deterministische kleur-pick per gelijke naam, verschillende voor verschillende namen.
- `HeatMapBucketTests` — bucket-grenzen op 0/4/5/12/13/24/25/100u.
- `StatusPillMappingTests` — elke `ProjectStatus` / `ActiviteitStatus` mapt naar unieke pill-config.

Geen UI-snapshot tests — niet ingericht in project, te brittle voor v1.

## 8. Risico's & open vragen

- **Inter font**: optioneel, niet in v1. Levert ~10% beter "polished" gevoel maar vereist font-bundle in Resources/. Vraag voor later.
- **Custom SectionTabBar**: SwiftUI's stock segmented control biedt geen count badges per segment. Custom HStack van knoppen is ~50 LoC, simpel. Geen sidebar selection wonders nodig.
- **Filter chips als View**: SwiftUI heeft geen built-in chip component. Mijn `FilterChip` = `Button` met custom background. Active state via VM binding.
- **Sidebar `List` → `ScrollView`**: verlaagt SwiftUI's "List" magic (selection management). Compenseren door manual `selection: Binding<UUID?>` op `ProjectCardRow`. Acceptabel.

## 9. Wat dit NIET adresseert

- Reactive ValueObservation in andere views dan ProjectListViewModel (al bestaand voor sidebar) — no-op
- Performance bij 1000+ activiteiten in matrix — heat-map is O(n), prima
- Accessibility audit (labels, contrast) — verdient eigen ronde later
- Tests voor `Settings`/`Branding` flows — out of scope

---

**Approval**: gebruiker akkoord op visuele richting via mockup goedgekeurd 2026-05-06.
