import Foundation
import GRDB

public struct Fase: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var naam: String
    public var volgorde: Int
    public var startDatum: Date?
    public var eindDatum: Date?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        naam: String,
        volgorde: Int,
        startDatum: Date? = nil,
        eindDatum: Date? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.naam = naam
        self.volgorde = volgorde
        self.startDatum = startDatum
        self.eindDatum = eindDatum
    }
}

extension Fase: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "fase"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let projectId = Column(CodingKeys.projectId)
        public static let naam = Column(CodingKeys.naam)
        public static let volgorde = Column(CodingKeys.volgorde)
        public static let startDatum = Column(CodingKeys.startDatum)
        public static let eindDatum = Column(CodingKeys.eindDatum)
    }
}
