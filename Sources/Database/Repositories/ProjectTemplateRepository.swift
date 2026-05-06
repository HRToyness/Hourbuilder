import Foundation
import GRDB
import Models

public struct ProjectTemplateRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func fetchAll() async throws -> [ProjectTemplate] {
        try await writer.read { db in
            try ProjectTemplate.order(ProjectTemplate.Columns.naam).fetchAll(db)
        }
    }

    public func fetch(id: UUID) async throws -> ProjectTemplate? {
        try await writer.read { db in
            try ProjectTemplate.fetchOne(db, key: id.uuidString.uppercased())
        }
    }

    @discardableResult
    public func save(_ template: ProjectTemplate) async throws -> ProjectTemplate {
        try await writer.write { db in
            var copy = template
            try copy.save(db)
            return copy
        }
    }

    public func delete(id: UUID) async throws {
        _ = try await writer.write { db in
            try ProjectTemplate.deleteOne(db, key: id.uuidString.uppercased())
        }
    }
}
