import Foundation
import GRDB
import Models

public struct FaseRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func fetch(projectId: UUID) async throws -> [Fase] {
        try await writer.read { db in
            try Fase
                .filter(Fase.Columns.projectId == projectId.uuidString.uppercased())
                .order(Fase.Columns.volgorde)
                .fetchAll(db)
        }
    }

    @discardableResult
    public func save(_ fase: Fase) async throws -> Fase {
        try await writer.write { db in
            var copy = fase
            try copy.save(db)
            return copy
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await writer.write { db in
            try Fase.deleteOne(db, key: id.uuidString.uppercased())
        }
    }
}
