# Project templates

> Status: design approved 2026-05-06.

## 1. Doel

Hergebruik van projectstructuur. Een gebruiker maakt een template aan met fases (relatieve timing) en personen (specifieke + placeholder-rollen) en kan die toepassen op een nieuw project — automatisch fases inplannen, automatisch members koppelen, eventueel placeholders invullen met bestaande of nieuwe personen.

**In scope**:
- CRUD voor `ProjectTemplate` met child `TemplateFase` + `TemplatePersoonEntry`
- Apply-wizard die een nieuw `Project` + `Fase`s + `ProjectMember`s aanmaakt
- "Opslaan als template…" actie op bestaand project (extract huidige structuur)
- `ProjectMember` als nieuwe lichte project↔persoon join (matrix toont members ook met 0 uren)
- Migration v3 met backfill: bestaande projecten krijgen members afgeleid van bestaande activiteiten

**Out of scope (v1)**:
- Template van activiteiten / placeholder-uren
- Linked templates (updates aan template propageren naar projecten die 'm gebruikten)
- Template categorieën, tags, sharing, import/export
- Per-project uurtarief op `ProjectMember`

## 2. Datamodel

Migration v3 voegt 4 tabellen toe.

### 2.1 `projectTemplate`

| Kolom | Type | Notities |
|---|---|---|
| id | text PK | UUID, .uppercaseString |
| naam | text not null | |
| beschrijving | text not null default '' | |
| defaultDoelKlantUren | double | nullable |
| defaultDoelInternUren | double | nullable |
| defaultNotities | text not null default '' | |

### 2.2 `templateFase`

| Kolom | Type | Notities |
|---|---|---|
| id | text PK | |
| templateId | text not null FK projectTemplate ON DELETE CASCADE | |
| naam | text not null | |
| volgorde | int not null | |
| weekVanaf | int | nullable, 1-based |
| weekTotEnMet | int | nullable |

Index op `templateId`.

### 2.3 `templatePersoonEntry`

| Kolom | Type | Notities |
|---|---|---|
| id | text PK | |
| templateId | text not null FK ON DELETE CASCADE | |
| mode | text not null | `specifiek` / `placeholder` |
| persoonId | text FK persoon ON DELETE CASCADE | alleen voor `specifiek`; cascade zodat persoon-delete de entry opruimt |
| placeholderRol | text | alleen voor `placeholder` |
| placeholderType | text | alleen voor `placeholder`, raw value van `PersoonType` |

Index op `templateId`.

### 2.4 `projectMember`

| Kolom | Type | Notities |
|---|---|---|
| id | text PK | |
| projectId | text not null FK ON DELETE CASCADE | |
| persoonId | text not null FK ON DELETE CASCADE | |
| rol | text | nullable override van `Persoon.rol` voor dit project |

Unique index op (projectId, persoonId).

### 2.5 Backfill

Bij migration v3, na schema creatie:

```swift
let rows = try Row.fetchAll(db, sql: """
    SELECT DISTINCT projectId, persoonId FROM activiteit
""")
for row in rows {
    let id = UUID().uuidString.uppercased()
    try db.execute(sql: """
        INSERT INTO projectMember (id, projectId, persoonId) VALUES (?, ?, ?)
        """, arguments: [id, row["projectId"], row["persoonId"]])
}
```

Houdt bestaande projecten consistent: ieder persoon met activiteiten in een project wordt automatisch member.

## 3. Modules & files

### Models (`Sources/Models/`)
- `ProjectTemplate.swift`
- `TemplateFase.swift`
- `TemplatePersoonEntry.swift` (met `enum TemplatePersoonMode`)
- `ProjectMember.swift`

### Database (`Sources/Database/`)
- Migration toegevoegd in `AppDatabase.swift`
- `Repositories/ProjectTemplateRepository.swift`
- `Repositories/TemplateFaseRepository.swift`
- `Repositories/TemplatePersoonEntryRepository.swift`
- `Repositories/ProjectMemberRepository.swift`

### Services (`Sources/Services/`)
- `ProjectTemplateApplyService.swift` — coördineert apply-flow

### Features
- `Sources/Features/Templates/` — nieuw
  - `TemplateListViewModel.swift`
  - `TemplateListView.swift`
  - `TemplateEditorViewModel.swift`
  - `TemplateEditorView.swift`
  - `TemplateApplyWizardViewModel.swift`
  - `TemplateApplyWizardView.swift`
  - `Components/TemplateRow.swift` (sidebar entry)
  - `Components/PlaceholderResolutionRow.swift` (1 rij in apply wizard)

### Wijzigingen aan bestaande Features
- `Sources/Features/Projects/ProjectListView.swift` — sidebar krijgt Templates sectie boven Projecten
- `Sources/Features/Projects/ProjectFormView.swift` — bovenaan template-picker; bij keuze opent apply wizard i.p.v. lege form
- `Sources/Features/Personen/PersoonListViewModel.swift` — wordt project-scoped: leest uit `ProjectMemberRepository` i.p.v. globale Personen
- `Sources/Features/Personen/PersoonListView.swift` — "+ Persoon" voegt member toe (pick bestaande of maak nieuwe)
- `Sources/Features/Matrix/MatrixViewModel.swift` — `fetchMatrixData` haalt members op (niet alleen via activiteiten); matrix toont alle members ook met 0u

## 4. Apply-flow contract

```swift
public struct ProjectTemplateApplyInput: Sendable {
    public let templateId: UUID
    public let projectNaam: String
    public let klantNaam: String
    public let startDatum: Date
    public let eindDatum: Date?
    public let factuurNummer: String?
    public let placeholderResolutions: [UUID: PlaceholderResolution]  // keyed op TemplatePersoonEntry.id
}

public enum PlaceholderResolution: Sendable {
    case existing(persoonId: UUID)
    case newPersoon(naam: String, rol: String, type: PersoonType, email: String?)
    case skip
}

public struct ProjectTemplateApplyResult: Sendable {
    public let projectId: UUID
    public let createdFaseIds: [UUID]
    public let memberPersoonIds: [UUID]
}
```

Service-implementatie in één `writer.write { db in ... }` transactie:

1. `Project` insert met overgenomen `defaultDoelKlant/Intern/Notities`
2. Voor elke `TemplateFase` (in volgorde): bereken absolute datums:
   - `startDatum = projectStart + (weekVanaf - 1) * 7 dagen` (als `weekVanaf` set)
   - `eindDatum = projectStart + weekTotEnMet * 7 dagen - 1 dag` (als `weekTotEnMet` set)
   - Insert `Fase`
3. Voor elke `TemplatePersoonEntry`:
   - `specifiek` met `persoonId`: insert `ProjectMember(projectId, persoonId)`
   - `placeholder`: kijk in `placeholderResolutions[entry.id]`:
     - `.existing(id)` → insert `ProjectMember(projectId, id)`
     - `.newPersoon(naam, rol, type, email)` → insert nieuwe `Persoon`, dan `ProjectMember`
     - `.skip` → niets
4. Return `ProjectTemplateApplyResult`

Validatie vooraf: alle `placeholder` entries moeten een resolution hebben (of `skip`). Service throwt `MissingResolution(entryId)` als een entry ontbreekt — UI moet dit voorkomen via disabled "Maak project aan" knop.

## 5. UI

### 5.1 Sidebar — Templates sectie

Boven "Projecten" een uitklapbaar `Section("Templates")` met:
- Eigen `+` knop in section header → opent template editor in nieuwe template modus
- Per template een rij met naam + aantal fases + aantal personen klein onder
- Klik = open template editor voor die template
- Right-click = "Verwijder" / "Toepassen op nieuw project…"

`@AppStorage` boolean of de sectie collapsed is.

### 5.2 Project create — template keuze

Huidige `ProjectFormView` krijgt bovenaan een sectie "Begin met":

```
( ) Leeg project
( ) Template:  [picker]
```

Bij keuze van template + klik "Volgende" → opent `TemplateApplyWizardView` met de geselecteerde template + de basis-velden (naam/klant/dates) ingevuld. De wizard handelt de rest af.

Bij "Leeg project" → huidige form-flow blijft ongewijzigd.

### 5.3 Template editor

Sheet met tabs:

**Algemeen**
- Naam (verplicht)
- Beschrijving (textarea)
- Default doel-uren (klant + intern)
- Default notities

**Fases**
- Tabel: volgorde · naam · week vanaf · week tot · acties
- "+" knop voor nieuwe rij; sleep voor herordenen (later — v1 alleen via volgorde-veld)

**Personen**
- Tabel: mode · naam/rol · type · acties
- Per rij toggle "specifieke persoon" vs "placeholder rol"
  - `specifiek`: persoon picker
  - `placeholder`: vrije rol-tekstveld + type picker
- "+" knop met menu: "Specifieke persoon…" / "Placeholder rol…"

Onderaan: Annuleren · Opslaan.

### 5.4 Apply-wizard

Sheet met:

```
[ Template: Standaard webbouw ]

Project basis
  Naam      [ Acme launch                 ]
  Klant     [ Acme B.V.                   ]
  Vanaf     [ 7 mei 2026 ]
  Tot       [ 31 juli 2026 ]      [ ] Open einde
  Factuur   [ INV-...                     ]

Fases die worden aangemaakt:
  1. Discovery     7 mei → 21 mei      (week 1-2)
  2. Design        22 mei → 12 juni    (week 3-5)
  3. Build         13 juni → 17 juli   (week 6-10)
  4. Launch        18 juli → 31 juli   (week 11-12)

Personen invullen:
  ✓ Teun Kralt (intern · lead)        ← uit template, specifiek
  ! PM klant (placeholder)            [ kies ▾ ] [ + nieuwe ] [ skip ]
  ! Webbouwer leverancier (placeholder)  [ kies ▾ ] [ + nieuwe ] [ skip ]

Preview: maakt 1 project, 4 fases, 3 leden

[ Annuleren ]    [ Maak project aan ]   ← disabled tot alle placeholders resolved
```

### 5.5 "Opslaan als template…" actie

Right-click op project in sidebar → menu item.

Sheet met:
- Template naam (default: project naam)
- Beschrijving
- Checkbox "Personen overnemen als specifiek" (default: aan)
- Checkbox "Notities overnemen" (default: aan)
- Checkbox "Doel-uren overnemen" (default: aan)
- Knop "Opslaan"

Implementatie:
1. Maak `ProjectTemplate` met opgegeven naam + beschrijving + (optioneel) doel/notities
2. Voor elke `Fase` van het bron-project: bereken `weekVanaf/weekTotEnMet` op basis van faseDatums + projectStart, sla op als `TemplateFase`
3. Voor elke `ProjectMember` van het bron-project: sla op als `TemplatePersoonEntry` met `mode=specifiek`
4. Open de template editor zodat gebruiker direct kan tweaken (bv. specifiek → placeholder)

### 5.6 Personen tab wordt project-scoped

Vandaag: `PersoonListView` toont alle globale `Persoon`. Nieuw: toont alleen `ProjectMember`s van het huidige project. "+ Persoon" toevoeging:
- Picker met "Bestaande persoon kiezen" of "Nieuwe persoon aanmaken"
- Bij existing: pick → insert `ProjectMember`
- Bij nieuw: form (naam/rol/type/email) → insert `Persoon` + `ProjectMember`

Verwijderen uit project = `ProjectMember` rij verwijderen (Persoon blijft globaal bestaan).

### 5.7 MatrixView toont alle members

`MatrixViewModel.fetchMatrixData` wordt:
1. Members van project ophalen via `ProjectMemberRepository.fetchMembers(projectId:)` → `[Persoon]` (joined)
2. Activiteiten ophalen (huidig)
3. Personen-set = members (alle members, ook 0-uren rijen)

Levert lege rijen op bij members zonder activiteiten — zichtbaar als planningsbasis.

## 6. Implementatie volgorde

1. **Datamodel + migration v3 + backfill** — Records, AppDatabase, repositories, schema tests
2. **Apply service** — pure logic + tests met in-memory DB
3. **Template editor + list** — kan templates aanmaken, bekijken, bewerken, verwijderen
4. **Apply wizard** — kan template toepassen op nieuw project
5. **"Opslaan als template…"** flow
6. **MatrixView + PersoonListView migratie naar `ProjectMember`** — laatste stap, want andere flows leunen erop

Elke stap = werkende build + tests groen.

## 7. Tests (nieuw)

| Suite | Wat |
|---|---|
| `ProjectMemberRepositoryTests` | CRUD, unique constraint per (project, persoon), cascade delete bij project en persoon |
| `ProjectTemplateRepositoryTests` | CRUD + cascade naar templateFase / templatePersoonEntry |
| `TemplateFaseTimingTests` | weekVanaf=1 met projectStart=ma → fase start = projectStart, etc. |
| `ProjectTemplateApplyServiceTests` | apply met alle placeholder resolution modes, fase-dates, atomiciteit (faal halverwege rolt terug) |
| `MigrationV3BackfillTests` | bestaand project met activiteiten → projectMember rijen aangemaakt voor unieke persoonen |

## 8. Risico's & open punten

- **Volgorde-uniciteit binnen template**: meerdere fases met `volgorde=1` is geldig in DB maar verwarrend. UI moet bij toevoegen auto-incrementeren.
- **Tijdberekening bij maand-grenzen**: `weekVanaf`/`weekTotEnMet` zijn weken sinds project start. Als gebruiker projectstart op woensdag zet, wordt fase ook woensdag. Acceptabel; matrix gebruikt ISO weeks elders.
- **Persoon-delete cascade**: bij `templatePersoonEntry.persoonId` ON DELETE CASCADE wordt de entry verwijderd als de persoon weg is. Alternatief: SET NULL en mode wordt automatisch placeholder. Voor v1 kies CASCADE — eenvoudiger en leesbaarder.
- **Lege placeholder-rol bij apply skip**: `.skip` betekent geen ProjectMember. Resterende fases blijven gewoon. Is dat wat user wil? Voor v1 ja — gebruiker kan altijd later via "+ Persoon" lid toevoegen.
