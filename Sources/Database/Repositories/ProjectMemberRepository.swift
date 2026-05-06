import Foundation
import GRDB
import Models

public struct ProjectMemberRepository: Sendable {
    public let writer: any DatabaseWriter

    public init(writer: any DatabaseWriter) {
        self.writer = writer
    }

    public func fetchMembers(projectId: UUID) async throws -> [ProjectMember] {
        try await writer.read { db in
            try ProjectMember
                .filter(ProjectMember.Columns.projectId == projectId.uuidString.uppercased())
                .fetchAll(db)
        }
    }

    /// Geeft de gekoppelde personen direct terug — handig voor matrix/lijsten.
    public func fetchPersonen(projectId: UUID) async throws -> [Persoon] {
        try await writer.read { db in
            let key = projectId.uuidString.uppercased()
            let rows = try Row.fetchAll(db, sql: """
                SELECT persoon.* FROM persoon
                JOIN projectMember ON projectMember.persoonId = persoon.id
                WHERE projectMember.projectId = ?
                ORDER BY persoon.naam
                """, arguments: [key])
            return try rows.map { try Persoon(row: $0) }
        }
    }

    @discardableResult
    public func add(projectId: UUID, persoonId: UUID, rol: String? = nil) async throws -> ProjectMember {
        try await writer.write { db in
            // Idempotent: skip als al lid
            let projectKey = projectId.uuidString.uppercased()
            let persoonKey = persoonId.uuidString.uppercased()
            if let existing = try ProjectMember
                .filter(ProjectMember.Columns.projectId == projectKey)
                .filter(ProjectMember.Columns.persoonId == persoonKey)
                .fetchOne(db) {
                return existing
            }
            var member = ProjectMember(projectId: projectId, persoonId: persoonId, rol: rol)
            try member.insert(db)
            return member
        }
    }

    public func remove(projectId: UUID, persoonId: UUID) async throws {
        _ = try await writer.write { db in
            let projectKey = projectId.uuidString.uppercased()
            let persoonKey = persoonId.uuidString.uppercased()
            try ProjectMember
                .filter(ProjectMember.Columns.projectId == projectKey)
                .filter(ProjectMember.Columns.persoonId == persoonKey)
                .deleteAll(db)
        }
    }

    public func remove(memberId: UUID) async throws {
        _ = try await writer.write { db in
            try ProjectMember.deleteOne(db, key: memberId.uuidString.uppercased())
        }
    }
}
