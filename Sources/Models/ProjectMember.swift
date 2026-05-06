import Foundation
import GRDB

public struct ProjectMember: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var persoonId: UUID
    public var rol: String?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        persoonId: UUID,
        rol: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.persoonId = persoonId
        self.rol = rol
    }
}

extension ProjectMember: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "projectMember"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let projectId = Column(CodingKeys.projectId)
        public static let persoonId = Column(CodingKeys.persoonId)
        public static let rol = Column(CodingKeys.rol)
    }
}
