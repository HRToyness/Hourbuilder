import Foundation
import GRDB
import Models

public struct ImportBronRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    @discardableResult
    public func save(_ bron: ImportBron) async throws -> ImportBron {
        try await writer.write { db in
            var copy = bron
            try copy.save(db)
            return copy
        }
    }

    public func fetch(projectId: UUID) async throws -> [ImportBron] {
        try await writer.read { db in
            try ImportBron
                .filter(ImportBron.Columns.projectId == projectId.uuidString.uppercased())
                .order(ImportBron.Columns.importDatum.desc)
                .fetchAll(db)
        }
    }
}
