---
name: grdb-database
description: How to set up and use GRDB.swift for the local SQLite database. Read before touching the schema, migrations, models, queries, or repositories. Covers Record protocol conformance, migration patterns, fetching, observation, and concurrent access.
---

# GRDB Database Patterns

GRDB is the chosen SQLite layer. Lower level than SwiftData but stable, predictable, and battle-tested for relational data with evolving schemas.

## Setup

Add via Swift Package Manager:
```
https://github.com/groue/GRDB.swift.git
```

Database lives at `~/Library/Application Support/UrenReconstructie/database.sqlite`. Created on first launch.

## Database singleton

One `DatabasePool` for the whole app, injected via Environment. Pool (not Queue) for concurrent reads.

```swift
// Database/Database.swift
import GRDB

final class AppDatabase {
    let dbPool: DatabasePool

    init(at url: URL) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        // config.prepareDatabase { db in try db.usePassphrase("...") } // for SQLCipher later

        dbPool = try DatabasePool(path: url.path, configuration: config)
        try migrator.migrate(dbPool)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        // Register migrations here, in order, never modify after shipping
        migrator.registerMigration("v1_initial") { db in
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
            // ... other tables
        }
        return migrator
    }
}
```

## Records (model types)

Conform models to `Codable`, `FetchableRecord`, `MutablePersistableRecord`. Use `struct` not `class`.

```swift
// Models/Project.swift
import GRDB
import Foundation

struct Project: Codable, Identifiable, Equatable {
    var id: UUID
    var naam: String
    var klantNaam: String
    var startDatum: Date
    var eindDatum: Date?
    var status: ProjectStatus
    var factuurNummer: String?
    var doelTotaalKlantUren: Double?
    var doelTotaalInternUren: Double?
    var notities: String
}

enum ProjectStatus: String, Codable, CaseIterable {
    case lopend, afgerond, gefactureerd
}

extension Project: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "project"
}
```

## Migrations

**Once a migration is shipped, never modify it.** New schema changes go in a new migration with a new identifier.

```swift
migrator.registerMigration("v2_add_persoon_email") { db in
    try db.alter(table: "persoon") { t in
        t.add(column: "email", .text)
    }
}
```

Identifier convention: `v{number}_{short_description}`. Numbers monotonic, never reused.

## Repositories

One repository per aggregate. Repositories take a `DatabaseWriter` (which `DatabasePool` conforms to).

```swift
// Database/Repositories/ProjectRepository.swift
struct ProjectRepository {
    let writer: any DatabaseWriter

    func fetchAll() async throws -> [Project] {
        try await writer.read { db in
            try Project.order(Column("startDatum").desc).fetchAll(db)
        }
    }

    func fetch(id: UUID) async throws -> Project? {
        try await writer.read { db in
            try Project.fetchOne(db, key: id)
        }
    }

    func save(_ project: Project) async throws {
        try await writer.write { db in
            var p = project
            try p.save(db)
        }
    }

    func delete(id: UUID) async throws {
        _ = try await writer.write { db in
            try Project.deleteOne(db, key: id)
        }
    }
}
```

Reads use `.read`, writes use `.write`. Both async. Both throw.

## Live observation (reactive lists)

For views that should update when DB changes, use `ValueObservation`:

```swift
extension ProjectRepository {
    func observeAll() -> AsyncValueObservation<[Project]> {
        ValueObservation
            .tracking { db in try Project.order(Column("startDatum").desc).fetchAll(db) }
            .values(in: writer)
    }
}
```

In a view model:
```swift
func startObserving() {
    observationTask = Task {
        for try await projects in repository.observeAll() {
            self.projects = projects
        }
    }
}
```

Cancel the task in `deinit` or when the view disappears.

## Queries with joins

Define associations on the records:

```swift
extension Project {
    static let activiteiten = hasMany(Activiteit.self)
}

extension Activiteit {
    static let project = belongsTo(Project.self)
    static let persoon = belongsTo(Persoon.self)
}

// Usage:
let projectsWithCounts = try await writer.read { db in
    try Project
        .annotated(with: Project.activiteiten.count)
        .fetchAll(db)
}
```

## Things to never do

- `try!` on a database call — always handle or rethrow
- Run a write inside a read block (deadlock)
- Hold a `DatabaseQueue`/`DatabasePool` reference inside a record type
- Modify a shipped migration — add a new one
- Use `Date` columns without `.datetime` type — GRDB stores it as ISO 8601 string
- Forget to register the migration after writing it

## Testing

Use an in-memory database for unit tests:
```swift
let db = try AppDatabase(at: URL(string: ":memory:")!)
```

Each test gets a fresh DB. Fast, isolated, deterministic.
