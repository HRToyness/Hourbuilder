import Foundation
import GRDB
import Models

public struct ActiviteitRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func fetch(projectId: UUID) async throws -> [Activiteit] {
        try await writer.read { db in
            try Activiteit
                .filter(Activiteit.Columns.projectId == projectId.uuidString.uppercased())
                .order(Activiteit.Columns.datum)
                .fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Activiteit? {
        try await writer.read { db in
            try Activiteit.fetchOne(db, key: id.uuidString.uppercased())
        }
    }

    @discardableResult
    public func save(_ activiteit: Activiteit) async throws -> Activiteit {
        try await writer.write { db in
            var copy = activiteit
            try copy.save(db)
            return copy
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await writer.write { db in
            try Activiteit.deleteOne(db, key: id.uuidString.uppercased())
        }
    }

    // MARK: - Aggregaties (voor Insights/Portfolio)

    /// Som van bevestigde uren per ISO-week, gegroepeerd per persoonsgroep.
    /// Returnt gesorteerd op week-start oplopend.
    public func urenPerWeek(projectId: UUID) async throws -> [WeekTotals] {
        try await writer.read { db in
            let projectKey = projectId.uuidString.uppercased()
            let rows = try Row.fetchAll(db, sql: """
                SELECT activiteit.datum AS datum,
                       persoon.type AS type,
                       activiteit.uren AS uren
                FROM activiteit
                JOIN persoon ON persoon.id = activiteit.persoonId
                WHERE activiteit.projectId = ?
                  AND activiteit.status = ?
                """, arguments: [projectKey, ActiviteitStatus.bevestigd.rawValue])

            var calendar = Calendar(identifier: .iso8601)
            calendar.firstWeekday = 2
            calendar.minimumDaysInFirstWeek = 4

            var bucketed: [String: (start: Date, perGroep: [PersoonGroep: Double])] = [:]
            for row in rows {
                guard let datum: Date = row["datum"],
                      let typeRaw: String = row["type"],
                      let type = PersoonType(rawValue: typeRaw) else { continue }
                let uren: Double = row["uren"] ?? 0
                let comps = calendar.dateComponents(
                    [.yearForWeekOfYear, .weekOfYear],
                    from: datum
                )
                guard let yfwy = comps.yearForWeekOfYear,
                      let woy = comps.weekOfYear else { continue }
                let key = "\(yfwy)-W\(String(format: "%02d", woy))"
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: datum)?.start ?? datum

                var entry = bucketed[key] ?? (weekStart, [:])
                entry.perGroep[type.groep, default: 0] += uren
                bucketed[key] = entry
            }

            return bucketed
                .map { (key, value) in
                    WeekTotals(yearWeek: key, weekStart: value.start, perGroep: value.perGroep)
                }
                .sorted { $0.weekStart < $1.weekStart }
        }
    }

    /// Som van bevestigde uren per fase (incl. "Geen fase" bucket).
    public func urenPerFase(projectId: UUID) async throws -> [FaseTotals] {
        try await writer.read { db in
            let projectKey = projectId.uuidString.uppercased()
            let rows = try Row.fetchAll(db, sql: """
                SELECT activiteit.faseId AS faseId,
                       fase.naam AS faseNaam,
                       fase.volgorde AS volgorde,
                       persoon.type AS type,
                       activiteit.uren AS uren
                FROM activiteit
                JOIN persoon ON persoon.id = activiteit.persoonId
                LEFT JOIN fase ON fase.id = activiteit.faseId
                WHERE activiteit.projectId = ?
                  AND activiteit.status = ?
                """, arguments: [projectKey, ActiviteitStatus.bevestigd.rawValue])

            struct Bucket {
                var faseId: UUID?
                var naam: String
                var volgorde: Int
                var perGroep: [PersoonGroep: Double] = [:]
            }
            var bucketed: [String: Bucket] = [:]
            for row in rows {
                let faseIdStr: String? = row["faseId"]
                let faseId: UUID? = faseIdStr.flatMap { UUID(uuidString: $0) }
                let key = faseIdStr ?? "_geen"
                let naam: String = row["faseNaam"] ?? "Geen fase"
                let volgorde: Int = row["volgorde"] ?? Int.max
                guard let typeRaw: String = row["type"],
                      let type = PersoonType(rawValue: typeRaw) else { continue }
                let uren: Double = row["uren"] ?? 0

                var entry = bucketed[key] ?? Bucket(faseId: faseId, naam: naam, volgorde: volgorde)
                entry.perGroep[type.groep, default: 0] += uren
                bucketed[key] = entry
            }

            return bucketed.values
                .sorted { $0.volgorde < $1.volgorde }
                .map { FaseTotals(faseId: $0.faseId, naam: $0.naam, perGroep: $0.perGroep) }
        }
    }

    /// Bevestigde uren per persoon, gesorteerd op totaal descending.
    public func urenPerPersoon(projectId: UUID) async throws -> [PersoonTotals] {
        try await writer.read { db in
            let projectKey = projectId.uuidString.uppercased()
            let rows = try Row.fetchAll(db, sql: """
                SELECT persoon.id AS id,
                       persoon.naam AS naam,
                       persoon.rol AS rol,
                       persoon.type AS type,
                       persoon.email AS email,
                       SUM(activiteit.uren) AS totaal
                FROM activiteit
                JOIN persoon ON persoon.id = activiteit.persoonId
                WHERE activiteit.projectId = ?
                  AND activiteit.status = ?
                GROUP BY persoon.id
                ORDER BY totaal DESC
                """, arguments: [projectKey, ActiviteitStatus.bevestigd.rawValue])

            return try rows.map { row in
                let totaal: Double = row["totaal"] ?? 0
                let persoon = try Persoon(row: row)
                return PersoonTotals(persoon: persoon, totaal: totaal)
            }
        }
    }

    /// Werkt de status bij van meerdere activiteiten in één transactie.
    /// Returnt het aantal aangepaste rijen.
    @discardableResult
    public func bulkSetStatus(
        _ status: ActiviteitStatus,
        ids: Set<UUID>
    ) async throws -> Int {
        guard !ids.isEmpty else { return 0 }
        let keys = ids.map { $0.uuidString.uppercased() }
        return try await writer.write { db in
            try Activiteit
                .filter(keys.contains(Activiteit.Columns.id))
                .updateAll(db, Activiteit.Columns.status.set(to: status.rawValue))
        }
    }

    /// Bulk-insert van geïmporteerde activiteiten. Skipt records waarvan
    /// `bronReferentie` al bestaat binnen hetzelfde project — voorkomt
    /// duplicaten bij re-import.
    public func insertWithDedup(
        _ activiteiten: [Activiteit]
    ) async throws -> ImportResult {
        try await writer.write { db in
            try Self.dedupInsert(activiteiten: activiteiten, db: db)
        }
    }

    /// Voert een import uit als één transactie: maakt een `ImportBron` aan,
    /// inserts activiteiten met dedup, stempelt `importBronId` op elke nieuwe
    /// activiteit. Het resulterende `ImportSummary` linkt naar het ImportBron
    /// record voor latere undo.
    public func runImport(
        projectId: UUID,
        bronType: ImportBronType,
        bestandsnaam: String?,
        candidates: [Activiteit]
    ) async throws -> ImportSummary {
        try await writer.write { db in
            var bron = ImportBron(
                projectId: projectId,
                type: bronType,
                bestandsnaam: bestandsnaam,
                importDatum: Date(),
                rijenAantal: 0
            )
            try bron.insert(db)

            let stamped = candidates.map { activiteit in
                var copy = activiteit
                copy.importBronId = bron.id
                return copy
            }
            let result = try Self.dedupInsert(activiteiten: stamped, db: db)

            bron.rijenAantal = result.inserted
            try bron.update(db)

            return ImportSummary(
                importBron: bron,
                inserted: result.inserted,
                skipped: result.skipped
            )
        }
    }

    /// Verwijdert alle activiteiten geïmporteerd via dit `ImportBron` record,
    /// inclusief het record zelf. Activiteiten zonder gekoppelde bron blijven
    /// staan. Returnt het aantal verwijderde activiteiten.
    public func undoImport(importBronId: UUID) async throws -> Int {
        try await writer.write { db in
            let key = importBronId.uuidString.uppercased()
            let deleted = try Activiteit
                .filter(Activiteit.Columns.importBronId == key)
                .deleteAll(db)
            _ = try ImportBron.deleteOne(db, key: key)
            return deleted
        }
    }

    private static func dedupInsert(
        activiteiten: [Activiteit],
        db: GRDB.Database
    ) throws -> ImportResult {
        var inserted = 0
        var skipped = 0
        for var act in activiteiten {
            if let ref = act.bronReferentie {
                let existsCount = try Activiteit
                    .filter(Activiteit.Columns.projectId == act.projectId.uuidString.uppercased())
                    .filter(Activiteit.Columns.bronReferentie == ref)
                    .fetchCount(db)
                if existsCount > 0 {
                    skipped += 1
                    continue
                }
            }
            try act.insert(db)
            inserted += 1
        }
        return ImportResult(inserted: inserted, skipped: skipped)
    }

    /// Haalt activiteiten + bijbehorende personen + fases voor een project op
    /// in één lees-transactie. Personen = union van project-leden (uit
    /// `projectMember`) + personen die activiteiten in dit project hebben.
    /// Zo verschijnen leden zonder activiteiten ook als 0-rij in de matrix.
    public func fetchMatrixData(projectId: UUID) async throws -> MatrixData {
        try await writer.read { db in
            let projectKey = projectId.uuidString.uppercased()

            let activiteiten = try Activiteit
                .filter(Activiteit.Columns.projectId == projectKey)
                .order(Activiteit.Columns.datum)
                .fetchAll(db)

            // 1. Members
            let memberRows = try Row.fetchAll(db, sql: """
                SELECT persoon.* FROM persoon
                JOIN projectMember ON projectMember.persoonId = persoon.id
                WHERE projectMember.projectId = ?
                """, arguments: [projectKey])
            var personen: [Persoon] = try memberRows.map { try Persoon(row: $0) }
            var seen = Set(personen.map(\.id))

            // 2. Personen-uit-activiteiten die nog niet als member bekend zijn
            let extraIds = Set(activiteiten.map(\.persoonId)).subtracting(seen)
            if !extraIds.isEmpty {
                let keys = extraIds.map { $0.uuidString.uppercased() }
                let extras = try Persoon
                    .filter(keys.contains(Persoon.Columns.id))
                    .fetchAll(db)
                personen.append(contentsOf: extras)
                for p in extras { seen.insert(p.id) }
            }
            personen.sort { $0.naam.localizedCompare($1.naam) == .orderedAscending }

            let fases = try Fase
                .filter(Fase.Columns.projectId == projectKey)
                .order(Fase.Columns.volgorde)
                .fetchAll(db)

            return MatrixData(
                activiteiten: activiteiten,
                personen: personen,
                fases: fases
            )
        }
    }
}

public struct WeekTotals: Sendable, Hashable {
    public let yearWeek: String
    public let weekStart: Date
    public let perGroep: [PersoonGroep: Double]

    public init(yearWeek: String, weekStart: Date, perGroep: [PersoonGroep: Double]) {
        self.yearWeek = yearWeek
        self.weekStart = weekStart
        self.perGroep = perGroep
    }

    public var totaal: Double { perGroep.values.reduce(0, +) }
}

public struct FaseTotals: Sendable, Hashable {
    public let faseId: UUID?
    public let naam: String
    public let perGroep: [PersoonGroep: Double]

    public init(faseId: UUID?, naam: String, perGroep: [PersoonGroep: Double]) {
        self.faseId = faseId
        self.naam = naam
        self.perGroep = perGroep
    }

    public var totaal: Double { perGroep.values.reduce(0, +) }
}

public struct PersoonTotals: Sendable, Hashable {
    public let persoon: Persoon
    public let totaal: Double

    public init(persoon: Persoon, totaal: Double) {
        self.persoon = persoon
        self.totaal = totaal
    }
}

public struct ImportResult: Sendable {
    public let inserted: Int
    public let skipped: Int

    public init(inserted: Int, skipped: Int) {
        self.inserted = inserted
        self.skipped = skipped
    }
}

public struct ImportSummary: Sendable {
    public let importBron: ImportBron
    public let inserted: Int
    public let skipped: Int

    public init(importBron: ImportBron, inserted: Int, skipped: Int) {
        self.importBron = importBron
        self.inserted = inserted
        self.skipped = skipped
    }
}

public struct MatrixData: Sendable {
    public let activiteiten: [Activiteit]
    public let personen: [Persoon]
    public let fases: [Fase]

    public init(activiteiten: [Activiteit], personen: [Persoon], fases: [Fase]) {
        self.activiteiten = activiteiten
        self.personen = personen
        self.fases = fases
    }
}
