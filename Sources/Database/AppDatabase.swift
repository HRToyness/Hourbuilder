import Foundation
import GRDB
import Models

/// Centrale ingang naar de SQLite database. Houdt de pool / queue vast en past
/// schema migraties toe bij init. Alle persistentie loopt via dit type.
public final class AppDatabase: @unchecked Sendable {
    public let dbWriter: any DatabaseWriter

    public init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    // MARK: - Migraties

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial_schema") { db in
            try db.create(table: "project") { t in
                t.column("id", .text).primaryKey()
                t.column("naam", .text).notNull()
                t.column("klantNaam", .text).notNull()
                t.column("startDatum", .datetime).notNull()
                t.column("eindDatum", .datetime)
                t.column("status", .text).notNull()
                t.column("factuurNummer", .text)
                t.column("doelTotaalKlantUren", .double)
                t.column("doelTotaalInternUren", .double)
                t.column("notities", .text).notNull().defaults(to: "")
            }

            try db.create(table: "fase") { t in
                t.column("id", .text).primaryKey()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("naam", .text).notNull()
                t.column("volgorde", .integer).notNull()
                t.column("startDatum", .datetime)
                t.column("eindDatum", .datetime)
            }
            try db.create(index: "fase_projectId_idx", on: "fase", columns: ["projectId"])

            try db.create(table: "persoon") { t in
                t.column("id", .text).primaryKey()
                t.column("naam", .text).notNull()
                t.column("rol", .text).notNull()
                t.column("type", .text).notNull()
                t.column("email", .text)
            }

            try db.create(table: "activiteit") { t in
                t.column("id", .text).primaryKey()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("faseId", .text)
                    .references("fase", onDelete: .setNull)
                t.column("persoonId", .text).notNull()
                    .references("persoon", onDelete: .restrict)
                t.column("datum", .datetime).notNull()
                t.column("uren", .double).notNull()
                t.column("beschrijving", .text).notNull().defaults(to: "")
                t.column("bron", .text).notNull()
                t.column("bronReferentie", .text)
                t.column("status", .text).notNull()
                t.column("bewijs", .text)
            }
            try db.create(
                index: "activiteit_project_datum_idx",
                on: "activiteit",
                columns: ["projectId", "datum"]
            )
            try db.create(
                index: "activiteit_persoon_idx",
                on: "activiteit",
                columns: ["persoonId"]
            )

            try db.create(table: "importBron") { t in
                t.column("id", .text).primaryKey()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("bestandsnaam", .text)
                t.column("importDatum", .datetime).notNull()
                t.column("rijenAantal", .integer).notNull()
            }
        }

        migrator.registerMigration("v2_activiteit_importBronId") { db in
            try db.alter(table: "activiteit") { t in
                t.add(column: "importBronId", .text)
                    .references("importBron", onDelete: .setNull)
            }
            try db.create(
                index: "activiteit_importBronId_idx",
                on: "activiteit",
                columns: ["importBronId"]
            )
        }

        migrator.registerMigration("v3_templates_and_membership") { db in
            try db.create(table: "projectTemplate") { t in
                t.column("id", .text).primaryKey()
                t.column("naam", .text).notNull()
                t.column("beschrijving", .text).notNull().defaults(to: "")
                t.column("defaultDoelKlantUren", .double)
                t.column("defaultDoelInternUren", .double)
                t.column("defaultNotities", .text).notNull().defaults(to: "")
            }

            try db.create(table: "templateFase") { t in
                t.column("id", .text).primaryKey()
                t.column("templateId", .text).notNull()
                    .references("projectTemplate", onDelete: .cascade)
                t.column("naam", .text).notNull()
                t.column("volgorde", .integer).notNull()
                t.column("weekVanaf", .integer)
                t.column("weekTotEnMet", .integer)
            }
            try db.create(
                index: "templateFase_templateId_idx",
                on: "templateFase",
                columns: ["templateId"]
            )

            try db.create(table: "templatePersoonEntry") { t in
                t.column("id", .text).primaryKey()
                t.column("templateId", .text).notNull()
                    .references("projectTemplate", onDelete: .cascade)
                t.column("mode", .text).notNull()
                t.column("persoonId", .text)
                    .references("persoon", onDelete: .cascade)
                t.column("placeholderRol", .text)
                t.column("placeholderType", .text)
            }
            try db.create(
                index: "templatePersoonEntry_templateId_idx",
                on: "templatePersoonEntry",
                columns: ["templateId"]
            )

            try db.create(table: "projectMember") { t in
                t.column("id", .text).primaryKey()
                t.column("projectId", .text).notNull()
                    .references("project", onDelete: .cascade)
                t.column("persoonId", .text).notNull()
                    .references("persoon", onDelete: .cascade)
                t.column("rol", .text)
            }
            try db.create(
                index: "projectMember_unique_idx",
                on: "projectMember",
                columns: ["projectId", "persoonId"],
                options: .unique
            )

            // Backfill: bestaande projecten krijgen members afgeleid van
            // unieke persoonen in hun activiteiten.
            let rows = try Row.fetchAll(db, sql: """
                SELECT DISTINCT projectId, persoonId FROM activiteit
                """)
            for row in rows {
                let id = UUID().uuidString.uppercased()
                try db.execute(sql: """
                    INSERT INTO projectMember (id, projectId, persoonId)
                    VALUES (?, ?, ?)
                    """, arguments: [id, row["projectId"], row["persoonId"]])
            }
        }

        return migrator
    }
}

// MARK: - Constructors

extension AppDatabase {
    /// In-memory database — gebruikt voor unit tests.
    public static func makeInMemory() throws -> AppDatabase {
        let queue = try DatabaseQueue()
        return try AppDatabase(queue)
    }

    /// `DatabasePool` op disk. Pool i.p.v. queue zodat reads parallel kunnen
    /// lopen. Maakt de parent directory aan indien nodig.
    public static func makeOnDisk(at url: URL) throws -> AppDatabase {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parent,
            withIntermediateDirectories: true
        )
        var config = Configuration()
        config.foreignKeysEnabled = true
        let pool = try DatabasePool(path: url.path, configuration: config)
        return try AppDatabase(pool)
    }
}
