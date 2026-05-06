# Insights, Portfolio dashboard & Forecast

> Status: design approved 2026-05-06.

## 1. Doel

Visueel inzicht en cross-project overzicht — drie delen:

- **Insights tab** per project: charts naast de matrix (lijn uren/week, staaf uren/fase, donut per persoon)
- **Portfolio dashboard**: home-view die de "Geen project geselecteerd" empty state vervangt
- **Forecast inline**: lineair geëxtrapoleerde ETA in de matrix totals-rij voor groepen met doel-totaal

**In scope**:
- Nieuwe aggregatie-queries op repos
- SwiftUI Charts (built-in framework, macOS 13+)
- Insights tab in `ProjectDetailView`
- Portfolio view die `RootView.emptyDetail` vervangt
- Forecast tekstregel in `MatrixView` totals KPI

**Out of scope (v1)**:
- Click-throughs / drill-down op chart-onderdelen
- Configurabele datum-ranges in charts (lijngrafiek pakt hele projectduur)
- Echte audit-log (recente activiteit gebruikt `Activiteit.datum` als proxy)
- Cross-project trend chart in portfolio
- Forecast met smarter modellen (exponential, weighted) — alleen lineair

## 2. Data laag

### 2.1 Aggregatie-queries (nieuw)

Toevoegen aan `Sources/Database/Repositories/ActiviteitRepository.swift`:

```swift
public struct WeekTotals: Sendable, Hashable {
    public let yearWeek: String        // "2026-W19"
    public let weekStart: Date
    public let perGroep: [PersoonGroep: Double]
}

public func urenPerWeek(projectId: UUID) async throws -> [WeekTotals]
```

Berekening: alle activiteiten met status `bevestigd` voor project, gegroepeerd op ISO-week + persoonsgroep. Returnt gesorteerd op `weekStart`.

```swift
public struct FaseTotals: Sendable, Hashable {
    public let faseId: UUID?           // nil = "geen fase"
    public let naam: String
    public let perGroep: [PersoonGroep: Double]
    public let totaal: Double
}

public func urenPerFase(projectId: UUID) async throws -> [FaseTotals]
```

JOIN met `fase` tabel; activiteiten zonder `faseId` gebundeld onder "Geen fase".

```swift
public struct PersoonTotals: Sendable, Hashable {
    public let persoon: Persoon
    public let totaal: Double
}

public func urenPerPersoon(projectId: UUID) async throws -> [PersoonTotals]
```

JOIN met `persoon`. Sorteer descending op totaal.

### 2.2 Portfolio query (nieuw)

`Sources/Database/Repositories/ProjectRepository.swift` krijgt:

```swift
public struct PortfolioSummary: Sendable {
    public struct ProjectMetric: Sendable, Hashable {
        public let project: Project
        public let bevestigdeUren: Double
        public let doelInternUren: Double?
        public let doelKlantUren: Double?
        public let internUren: Double
        public let klantUren: Double
        public let weeklySparkline: [Double]   // laatste 8 weken
        public let isOverDoel: Bool
    }

    public let urenDezeMaand: Double
    public let lopendeProjecten: Int
    public let totaalBevestigd: Double      // som over alle projecten met status .lopend
    public let projectenOverDoel: Int
    public let perProject: [ProjectMetric]
    public let recenteActiviteiten: [Activiteit]   // 5 meest recente op .datum
}

public func fetchPortfolioSummary() async throws -> PortfolioSummary
```

Eén lees-transactie. Sparkline is array van 8 doubles (uren per week, laatste 8 weken vanaf nu).

### 2.3 Forecast helper (nieuw)

`Sources/Database/ForecastCalculator.swift` (pure functie, geen DB):

```swift
public enum ForecastCalculator {
    public struct Result: Sendable, Equatable {
        public let etaUren: Double
        public let etaDatum: Date
        public let sentiment: Sentiment   // .onTrack / .behind / .over
    }

    public enum Sentiment: Sendable { case onTrack, behind, over }

    public static func forecast(
        currentUren: Double,
        projectStart: Date,
        projectEnd: Date,
        now: Date,
        doelUren: Double
    ) -> Result?
}
```

- Verstreken weken = `max(0.5, weeks(now - projectStart))` (cap op 0.5 om delen-door-nul te voorkomen)
- Project totaal weken = `weeks(projectEnd - projectStart)`
- ETA uren = `currentUren / verstreken_weken * totaal_weken`
- ETA datum = `projectEnd` (we voorspellen op het einde, niet wanneer doel bereikt is)
- Sentiment:
  - `etaUren < doelUren * 0.95` → `.behind` (oranje)
  - `etaUren > doelUren * 1.05` → `.over` (rood)
  - else → `.onTrack` (groen)
- Returnt `nil` als `now >= projectEnd` (geen forecast meer zinvol)
- Returnt `nil` als `verstreken_weken < 1.0` (te vroeg)

## 3. UI laag

### 3.1 Insights tab

Nieuwe map: `Sources/Features/Insights/`

- `InsightsViewModel.swift` — laadt `urenPerWeek`, `urenPerFase`, `urenPerPersoon` parallel
- `InsightsView.swift` — drie sectie-kaarten

Tab volgorde in `ProjectDetailView.Tab`:
```
matrix → activiteiten → personen → fases → insights → reconstructie
```

`InsightsView` body:
- KPI strip bovenin (gebruikt bestaand `KPIRow`): bevestigde / concept / AI-voorstel counts
- `Chart` SwiftUI view: lijngrafiek `LineMark` per groep, x = week, y = uren, kleur per `PersoonGroep`
- `Chart` staafgrafiek: `BarMark`, x = fase naam, y = uren, kleur = persoon-groep gestapeld
- `Chart` donut: `SectorMark` per persoon (top 6 + "andere")

Charts framework wordt geïmporteerd via `import Charts`. Beschikbaar zonder package dep.

### 3.2 Portfolio dashboard

Nieuwe map: `Sources/Features/Portfolio/`

- `PortfolioViewModel.swift` — laadt `fetchPortfolioSummary` via `ValueObservation` (auto-update bij activiteit/project mutaties)
- `PortfolioView.swift` — top KPIs + project-grid + recente activiteit

Layout:
```
[ KPI: 220u deze maand ] [ KPI: 4 lopend ] [ KPI: 18u te facturen ] [ KPI: 1 over doel ]

PROJECTEN
┌─────────────────────────┬─────────────────────────┐
│ Acme launch  · LOPEND   │ Polderpost   · LOPEND   │
│ Acme B.V.               │ Polderpost B.V.         │
│ 96/200 intern  ▆▆▆▆▆░░░ │ 22/120 intern  ▆▆░░░░░░ │
│ ─sparkline─             │ ─sparkline─             │
└─────────────────────────┴─────────────────────────┘

RECENTE ACTIVITEIT
· 8 mei · Teun Kralt · 4u Sprint planning  (Acme launch)
· 7 mei · Marieke v. · 2u Review  (Acme launch)
...
```

Vervang `RootView.emptyDetail` met `PortfolioView`. Project tap → set `selectedProjectId`.

Sparkline component: nieuw `Sources/Styling/Components/Sparkline.swift` — eenvoudige `Path` van punten in een mini-grafiek (60×16pt).

### 3.3 Forecast inline

`MatrixTotalsRow` in `MatrixView` krijgt extra regel onder de bestaande "+/- N over/te gaan":
- Roept `ForecastCalculator.forecast(...)` aan
- Toont "ETA op koers (195u op 31 juli)" / "ETA achter — 175u op 31 juli (-25)" / "ETA over — 220u op 31 juli (+20)"
- Skip leverancier (geen doel)
- Skip als forecaster `nil` returnt

Reuse `DeltaLabel` component voor sentiment-kleur.

## 4. Implementatie volgorde

1. **Repo aggregaties + ForecastCalculator + tests** (pure data laag, dichtgetimmerd)
2. **Forecast inline** in MatrixView (kleinste UI verandering, valideert calculator)
3. **Insights tab** met 3 charts
4. **Portfolio dashboard + Sparkline component**

Elke stap = werkende build + tests groen.

## 5. Tests (nieuw)

| Suite | Inhoud |
|---|---|
| `UrenPerWeekTests` | Activiteiten in week 19/20/21, gegroepeerd per groep; status-filter (alleen bevestigd); lege data |
| `UrenPerFaseTests` | Activiteiten met/zonder faseId; "Geen fase" bucket |
| `UrenPerPersoonTests` | Sortering descending, joining met persoon |
| `PortfolioSummaryTests` | Cross-project aggregaat; recente activiteiten = top 5; sparkline lengte 8 |
| `ForecastCalculatorTests` | onTrack / behind / over sentiment-grenzen; nil bij `now > projectEnd`; nil bij `verstreken < 1 week`; lineair klopt |

Geen UI-snapshot tests — chart rendering te brittle.

## 6. Risico's & beslissingen

- **SwiftUI Charts is macOS 13+**: project target is macOS 14, dus geen issue.
- **Lijngrafiek met 0 weken data**: render lege `Chart` met "Nog geen data" overlay.
- **Donut met >6 personen**: top 5 + "andere (sum)" om legenda leesbaar te houden.
- **Portfolio `urenDezeMaand` definitie**: kalendermaand of laatste 30 dagen? **Kalendermaand** — past bij factuurcyclus.
- **Sparkline data ontbreekt voor projecten korter dan 8 weken**: pad met nullen aan begin (left-pad). Visueel: lijn start later in de mini-grafiek.

## 7. Wat niet veranderd

- Datamodel + migration v3 blijft. Geen nieuwe tabel nodig.
- Bestaande tabs Matrix / Activiteiten / Personen / Fases / Reconstructie blijven onveranderd op layout.
- Bestaande Status pills / Avatar / heat-map blijven hergebruikt in charts (kleurpalet consistent met persoonsgroep tones).
