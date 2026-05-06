# UrenReconstructie — Native macOS App

> Spec voor Claude Code. Lokaal-eerst, geen klantdata in de cloud (behalve geanonimiseerde context naar Claude API voor gap-filling).

## 1. Doel

Een macOS app die helpt bij het reconstrueren van een kloppende urenregistratie aan het einde van een traject, op basis van fragmentarische input: agenda-afspraken, bijlagen van leveranciers (webbouwer, editor), klanturen, en eigen registratie. Output is een set bijlagen + totaaloverzicht dat aansluit op de factuur.

**Niet het doel:** uren reverse-engineeren naar een vooraf bepaald totaal. De AI-assist stelt voor op basis van bewijs en project context; gebruiker keurt goed of wijst af.

## 2. Privacy principes (hard)

- Alle persoons- en projectdata blijft lokaal (SQLite in `~/Library/Application Support/UrenReconstructie/`)
- Bestanden worden lokaal opgeslagen, niet gesynchroniseerd
- Claude API krijgt **alleen geanonimiseerde context**: rolnamen ("klant_pm", "intern_dev_1"), geen NAW
- API key in Keychain, nooit in plaintext
- Optioneel: encrypted database via SQLCipher

## 3. Tech stack

- **Swift 5.9+ / SwiftUI**, macOS 14+ (Sonoma)
- **GRDB.swift** voor SQLite (volwassener dan SwiftData voor dit type relationele data)
- **EventKit** voor Apple Calendar toegang
- **PDFKit** voor PDF generatie
- **CoreXLSX** of eigen CSV parser voor imports
- **URLSession** voor Claude API (geen SDK nodig, simpele POST)

## 4. Data model

```
Project
  id: UUID
  naam: String
  klantNaam: String
  startDatum: Date
  eindDatum: Date?
  status: enum (lopend, afgerond, gefactureerd)
  factuurNummer: String?
  doelTotaalKlantUren: Double?    // optioneel ankerpunt, niet leidend
  doelTotaalInternUren: Double?
  notities: String

Fase
  id: UUID
  projectId: UUID
  naam: String
  volgorde: Int
  startDatum: Date?
  eindDatum: Date?

Persoon
  id: UUID
  naam: String
  rol: String                      // "PM klant", "developer", "editor"
  type: enum (intern, klant, leverancier_webbouwer, leverancier_editor)
  email: String?

Activiteit
  id: UUID
  projectId: UUID
  faseId: UUID?
  persoonId: UUID
  datum: Date
  uren: Double
  beschrijving: String
  bron: enum (agenda, import_csv, import_xlsx, handmatig, ai_voorstel)
  bronReferentie: String?          // bv. event ID of bestand+rij
  status: enum (concept, bevestigd, afgewezen)
  bewijs: String?                  // korte onderbouwing

ImportBron
  id: UUID
  projectId: UUID
  type: enum (ics, csv, xlsx, calendar_sync)
  bestandsnaam: String?
  importDatum: Date
  rijenAantal: Int
```

## 5. Schermen

### 5.1 Project overzicht
Lijst van alle projecten met status, totalen, voortgang.

### 5.2 Project detail — **matrix view** (primair scherm)
Grid: **Personen op Y-as, weken/dagen op X-as**, cellen tonen uren. Filterbaar op fase, persoonstype, bron. Cellen kleuren naar status (concept/bevestigd/AI-voorstel). Klik op cel → detail van onderliggende activiteiten.

Onderaan: lopende totalen per persoonstype (klant / intern / leverancier) met afwijking t.o.v. doelTotaal.

### 5.3 Import wizard
- **Apple Calendar**: selecteer kalenders + datumrange + optionele zoektermen → preview van events → koppel aan project + persoon
- **ICS bestand**: drop file → zelfde flow
- **CSV/Excel** (webbouwer/editor bijlage): kolom mapping wizard (welke kolom = datum, uren, beschrijving) → koppel aan persoon

### 5.4 Reconstructie scherm (AI assist)
Toont:
- Wat is bekend per fase / week / persoon
- Waar zitten gaten (geen uren in periode waarin wel facturatie was)
- AI-voorstellen voor invulling met onderbouwing
- Goedkeur/afwijs per voorstel

### 5.5 Output generator
- PDF per partij (klant / intern / per leverancier)
- Excel totaaloverzicht
- Preview voor export
- Branding configureerbaar (logo + kleuren via app settings)

## 6. Calendar import (EventKit specifiek)

```swift
// Permissions: NSCalendarsUsageDescription in Info.plist
// Vraag toegang met EKEventStore.requestFullAccessToEvents
// Filter events op datumrange en optioneel deelnemersmail of titel-keyword
```

Per event: voorstel een Activiteit met duur = event duration, persoon = matched op email, beschrijving = event titel.

## 7. AI integratie (Claude API)

**Wanneer**: alleen als gebruiker expliciet op "Vul gaten in" klikt in reconstructie scherm.

**Input naar API** (geanonimiseerd):
```json
{
  "project_context": {
    "duur_weken": 12,
    "fases": ["analyse", "bouw", "oplevering"],
    "rol_typen": ["intern_pm", "intern_dev", "klant_pm", "leverancier_editor"]
  },
  "bekende_activiteiten": [
    {"week": 3, "rol": "intern_dev", "uren": 12, "beschrijving": "..."}
  ],
  "doel_totalen": {"klant": 180, "intern": 200},
  "vraag": "Stel realistische activiteiten voor om de gaten te vullen, met onderbouwing per voorstel"
}
```

**Output verwerking**: parse JSON response → toon als `ai_voorstel` activiteiten met status `concept`. Elk voorstel heeft een onderbouwing in `bewijs` veld.

**Model**: `claude-opus-4-7` voor kwaliteit, met streaming voor UX.

## 8. Output / export

### PDF (per partij)
- Header met logo (configureerbaar via settings)
- Project info + factuur referentie
- Tabel: datum, beschrijving, uren
- Subtotalen per fase
- Eindtotaal
- Footer met datum export en hash van data (voor verificatie)

### Excel
- Sheet per persoonstype
- Sheet "Totalen" met kruistabel

## 9. Bouwfasering

### Fase 1 — Fundament (start hier)
- [ ] Xcode project setup, GRDB schema, basis styling
- [ ] Project CRUD
- [ ] Persoon CRUD
- [ ] Handmatige Activiteit invoer
- [ ] Matrix view (read-only, simpel)

### Fase 2 — Imports
- [ ] EventKit calendar import + persoon-matching
- [ ] CSV import met kolom mapping
- [ ] XLSX import
- [ ] Import historie / undo

### Fase 3 — AI assist
- [ ] Keychain helper voor API key
- [ ] Anonimisatie laag
- [ ] Claude API client
- [ ] Reconstructie scherm met goedkeur flow

### Fase 4 — Output & polish
- [ ] PDF generatie met configureerbare branding
- [ ] Excel export
- [ ] App icon, signing, notarization

## 10. Open punten om te beslissen

1. **Backup**: gewoon Time Machine vertrouwen, of expliciete export naar versleuteld zip?
2. **Multi-project parallel**: kan een persoon op één dag uren op meerdere projecten hebben? (Waarschijnlijk ja → datamodel klopt)
3. **Doel-totalen**: harde validatie dat output ≤ doel, of alleen waarschuwing?
4. **Onderbouwing audit log**: bij export, ook een logbestand met "deze X uren zijn AI-voorgesteld op datum Y" bijsluiten?
5. **Encryptie database**: SQLCipher toevoegen of vertrouwen op FileVault?
6. **Branding**: configureerbaar via app settings (logo upload + accent kleur), of vast in code?

## 11. Repo structuur (suggestie)

```
UrenReconstructie/
├── App/
│   └── UrenReconstructieApp.swift
├── Models/
│   ├── Project.swift
│   ├── Activiteit.swift
│   └── ...
├── Database/
│   ├── Database.swift          // GRDB setup
│   └── Migrations/
├── Features/
│   ├── Projects/
│   ├── Matrix/
│   ├── Import/
│   ├── Reconstruction/
│   └── Export/
├── Services/
│   ├── CalendarService.swift   // EventKit wrapper
│   ├── ClaudeService.swift     // API client
│   ├── AnonymizationService.swift
│   └── ExportService.swift
├── Styling/
│   ├── AppColor.swift
│   ├── AppFont.swift
│   └── Components/
└── Resources/
```

---

**Eerste Claude Code prompt** (suggestie):

> Lees de spec in `urenreconstructie-spec.md`. Start met Fase 1: maak een nieuw SwiftUI macOS project, voeg GRDB toe via SPM, implementeer het data model uit sectie 4, en bouw schermen 5.1 en 5.2 (project overzicht + matrix view) met handmatige activiteit invoer. Hou alles testbaar en modulair.
