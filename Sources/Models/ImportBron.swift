import Foundation
import GRDB

public struct ImportBron: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var type: ImportBronType
    public var bestandsnaam: String?
    public var importDatum: Date
    public var rijenAantal: Int

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        type: ImportBronType,
        bestandsnaam: String? = nil,
        importDatum: Date = Date(),
        rijenAantal: Int = 0
    ) {
        self.id = id
        self.projectId = projectId
        self.type = type
        self.bestandsnaam = bestandsnaam
        self.importDatum = importDatum
        self.rijenAantal = rijenAantal
    }
}

extension ImportBron: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "importBron"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let projectId = Column(CodingKeys.projectId)
        public static let type = Column(CodingKeys.type)
        public static let bestandsnaam = Column(CodingKeys.bestandsnaam)
        public static let importDatum = Column(CodingKeys.importDatum)
        public static let rijenAantal = Column(CodingKeys.rijenAantal)
    }
}
