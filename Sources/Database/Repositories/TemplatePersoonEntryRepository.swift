import Foundation
import GRDB
import Models

public struct TemplatePersoonEntryRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func fetch(templateId: UUID) async throws -> [TemplatePersoonEntry] {
        try await writer.read { db in
            try TemplatePersoonEntry
                .filter(TemplatePersoonEntry.Columns.templateId == templateId.uuidString.uppercased())
                .fetchAll(db)
        }
    }

    @discardableResult
    public func save(_ entry: TemplatePersoonEntry) async throws -> TemplatePersoonEntry {
        try await writer.write { db in
            var copy = entry
            try copy.save(db)
            return copy
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await writer.write { db in
            try TemplatePersoonEntry.deleteOne(db, key: id.uuidString.uppercased())
        }
    }
}
