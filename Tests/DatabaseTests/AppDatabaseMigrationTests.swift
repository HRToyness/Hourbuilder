import XCTest
import GRDB
@testable import Database

final class AppDatabaseMigrationTests: XCTestCase {
    func testInMemoryDatabaseAppliesMigrations() throws {
        let db = try AppDatabase.makeInMemory()
        try db.dbWriter.read { db in
            let tables: [String] = try String.fetchAll(db, sql: """
                SELECT name FROM sqlite_master
                WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'
                ORDER BY name
                """)
            XCTAssertEqual(
                Set(tables),
                Set([
                    "activiteit",
                    "fase",
                    "importBron",
                    "persoon",
                    "project",
                    "projectMember",
                    "projectTemplate",
                    "templateFase",
                    "templatePersoonEntry",
                ])
            )
        }
    }
}
