import Foundation
import GRDB
import Models

public struct PersoonRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func fetchAll() async throws -> [Persoon] {
        try await writer.read { db in
            try Persoon.order(Persoon.Columns.naam).fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> Persoon? {
        try await writer.read { db in
            try Persoon.fetchOne(db, key: id.uuidString.uppercased())
        }
    }

    @discardableResult
    public func save(_ persoon: Persoon) async throws -> Persoon {
        try await writer.write { db in
            var copy = persoon
            try copy.save(db)
            return copy
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await writer.write { db in
            try Persoon.deleteOne(db, key: id.uuidString.uppercased())
        }
    }
}
