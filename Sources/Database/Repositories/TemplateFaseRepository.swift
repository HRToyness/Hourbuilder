import Foundation
import GRDB
import Models

public struct TemplateFaseRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func fetch(templateId: UUID) async throws -> [TemplateFase] {
        try await writer.read { db in
            try TemplateFase
                .filter(TemplateFase.Columns.templateId == templateId.uuidString.uppercased())
                .order(TemplateFase.Columns.volgorde)
                .fetchAll(db)
        }
    }

    @discardableResult
    public func save(_ fase: TemplateFase) async throws -> TemplateFase {
        try await writer.write { db in
            var copy = fase
            try copy.save(db)
            return copy
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await writer.write { db in
            try TemplateFase.deleteOne(db, key: id.uuidString.uppercased())
        }
    }
}
