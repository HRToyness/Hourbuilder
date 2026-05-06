import Foundation
import GRDB
import Models

public struct ProjectRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func fetchAll() async throws -> [Project] {
        try await writer.read { db in
            try Project.order(Project.Columns.startDatum.desc).fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Project? {
        try await writer.read { db in
            try Project.fetchOne(db, key: id.uuidString.uppercased())
        }
    }

    @discardableResult
    public func save(_ project: Project) async throws -> Project {
        try await writer.write { db in
            var copy = project
            try copy.save(db)
            return copy
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await writer.write { db in
            try Project.deleteOne(db, key: id.uuidString.uppercased())
        }
    }

    /// Som van uren met status `bevestigd` per persoonsgroep voor een project.
    /// Bedoeld voor de "totalen" weergave onderaan de matrix.
    public func uurTotalenPerGroep(projectId: UUID) async throws -> [PersoonGroep: Double] {
        try await writer.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT persoon.type AS type, SUM(activiteit.uren) AS totaal
                FROM activiteit
                JOIN persoon ON persoon.id = activiteit.persoonId
                WHERE activiteit.projectId = ?
                  AND activiteit.status = ?
                GROUP BY persoon.type
                """, arguments: [
                    projectId.uuidString.uppercased(),
                    ActiviteitStatus.bevestigd.rawValue
                ])

            var totalen: [PersoonGroep: Double] = [:]
            for row in rows {
                guard let typeRaw: String = row["type"],
                      let type = PersoonType(rawValue: typeRaw) else { continue }
                let totaal: Double = row["totaal"] ?? 0
                totalen[type.groep, default: 0] += totaal
            }
            return totalen
        }
    }

    /// Cross-project samenvatting voor het portfolio dashboard.
    public func fetchPortfolioSummary(now: Date = Date()) async throws -> PortfolioSummary {
        try await writer.read { db in
            // 1. Lopende projecten
            let lopendeProjecten = try Project
                .filter(Project.Columns.status == ProjectStatus.lopend.rawValue)
                .order(Project.Columns.startDatum.desc)
                .fetchAll(db)

            // 2. Sparkline-weken (laatste 8 ISO weken eindigend op `now`)
            var calendar = Calendar(identifier: .iso8601)
            calendar.firstWeekday = 2
            calendar.minimumDaysInFirstWeek = 4
            var weekStarts: [Date] = []
            if let nowWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start {
                let startOfRange = calendar.date(byAdding: .weekOfYear, value: -7, to: nowWeekStart) ?? nowWeekStart
                for offset in 0..<8 {
                    if let s = calendar.date(byAdding: .weekOfYear, value: offset, to: startOfRange) {
                        weekStarts.append(s)
                    }
                }
            }

            // 3. Per project: totaal per groep + sparkline
            var perProject: [PortfolioSummary.ProjectMetric] = []
            var totaalBevestigd: Double = 0
            var projectenOverDoel = 0
            for project in lopendeProjecten {
                let key = project.id.uuidString.uppercased()
                let groepRows = try Row.fetchAll(db, sql: """
                    SELECT persoon.type AS type, SUM(activiteit.uren) AS totaal
                    FROM activiteit
                    JOIN persoon ON persoon.id = activiteit.persoonId
                    WHERE activiteit.projectId = ?
                      AND activiteit.status = ?
                    GROUP BY persoon.type
                    """, arguments: [key, ActiviteitStatus.bevestigd.rawValue])

                var internUren: Double = 0
                var klantUren: Double = 0
                var bevestigdeUren: Double = 0
                for r in groepRows {
                    guard let typeRaw: String = r["type"],
                          let type = PersoonType(rawValue: typeRaw) else { continue }
                    let totaal: Double = r["totaal"] ?? 0
                    bevestigdeUren += totaal
                    switch type.groep {
                    case .intern: internUren += totaal
                    case .klant: klantUren += totaal
                    case .leverancier: break
                    }
                }
                totaalBevestigd += bevestigdeUren

                // Sparkline
                var sparkline = Array(repeating: 0.0, count: weekStarts.count)
                let activiteitenRows = try Row.fetchAll(db, sql: """
                    SELECT datum, uren FROM activiteit
                    WHERE projectId = ? AND status = ?
                    """, arguments: [key, ActiviteitStatus.bevestigd.rawValue])
                for r in activiteitenRows {
                    guard let datum: Date = r["datum"] else { continue }
                    let uren: Double = r["uren"] ?? 0
                    guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: datum)?.start else { continue }
                    if let idx = weekStarts.firstIndex(of: weekStart) {
                        sparkline[idx] += uren
                    }
                }

                let metric = PortfolioSummary.ProjectMetric(
                    project: project,
                    bevestigdeUren: bevestigdeUren,
                    internUren: internUren,
                    klantUren: klantUren,
                    weeklySparkline: sparkline
                )
                if metric.isOverDoel { projectenOverDoel += 1 }
                perProject.append(metric)
            }

            // 4. Uren deze (kalender)maand over alle projecten
            var gregorian = Calendar(identifier: .gregorian)
            gregorian.timeZone = TimeZone.current
            let monthInterval = gregorian.dateInterval(of: .month, for: now)
            let urenDezeMaand: Double
            if let interval = monthInterval {
                let row = try Row.fetchOne(db, sql: """
                    SELECT COALESCE(SUM(uren), 0) AS m FROM activiteit
                    WHERE status = ? AND datum >= ? AND datum < ?
                    """, arguments: [
                        ActiviteitStatus.bevestigd.rawValue,
                        interval.start,
                        interval.end
                    ])
                urenDezeMaand = row?["m"] ?? 0
            } else {
                urenDezeMaand = 0
            }

            // 5. Recente activiteiten
            let recenteActiviteiten = try Activiteit
                .order(Activiteit.Columns.datum.desc)
                .limit(5)
                .fetchAll(db)

            return PortfolioSummary(
                urenDezeMaand: urenDezeMaand,
                lopendeProjecten: lopendeProjecten.count,
                totaalBevestigd: totaalBevestigd,
                projectenOverDoel: projectenOverDoel,
                perProject: perProject,
                recenteActiviteiten: recenteActiviteiten
            )
        }
    }
}

public struct PortfolioSummary: Sendable {
    public struct ProjectMetric: Sendable, Hashable {
        public let project: Project
        public let bevestigdeUren: Double
        public let internUren: Double
        public let klantUren: Double
        public let weeklySparkline: [Double]

        public init(
            project: Project,
            bevestigdeUren: Double,
            internUren: Double,
            klantUren: Double,
            weeklySparkline: [Double]
        ) {
            self.project = project
            self.bevestigdeUren = bevestigdeUren
            self.internUren = internUren
            self.klantUren = klantUren
            self.weeklySparkline = weeklySparkline
        }

        public var isOverDoel: Bool {
            if let doel = project.doelTotaalInternUren, doel > 0, internUren > doel { return true }
            if let doel = project.doelTotaalKlantUren, doel > 0, klantUren > doel { return true }
            return false
        }
    }

    public let urenDezeMaand: Double
    public let lopendeProjecten: Int
    public let totaalBevestigd: Double
    public let projectenOverDoel: Int
    public let perProject: [ProjectMetric]
    public let recenteActiviteiten: [Activiteit]

    public init(
        urenDezeMaand: Double,
        lopendeProjecten: Int,
        totaalBevestigd: Double,
        projectenOverDoel: Int,
        perProject: [ProjectMetric],
        recenteActiviteiten: [Activiteit]
    ) {
        self.urenDezeMaand = urenDezeMaand
        self.lopendeProjecten = lopendeProjecten
        self.totaalBevestigd = totaalBevestigd
        self.projectenOverDoel = projectenOverDoel
        self.perProject = perProject
        self.recenteActiviteiten = recenteActiviteiten
    }
}
