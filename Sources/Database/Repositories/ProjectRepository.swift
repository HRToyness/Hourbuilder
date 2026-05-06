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
}
