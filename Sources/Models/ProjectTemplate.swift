import Foundation
import GRDB

public struct ProjectTemplate: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var naam: String
    public var beschrijving: String
    public var defaultDoelKlantUren: Double?
    public var defaultDoelInternUren: Double?
    public var defaultNotities: String

    public init(
        id: UUID = UUID(),
        naam: String,
        beschrijving: String = "",
        defaultDoelKlantUren: Double? = nil,
        defaultDoelInternUren: Double? = nil,
        defaultNotities: String = ""
    ) {
        self.id = id
        self.naam = naam
        self.beschrijving = beschrijving
        self.defaultDoelKlantUren = defaultDoelKlantUren
        self.defaultDoelInternUren = defaultDoelInternUren
        self.defaultNotities = defaultNotities
    }
}

extension ProjectTemplate: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "projectTemplate"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let naam = Column(CodingKeys.naam)
        public static let beschrijving = Column(CodingKeys.beschrijving)
        public static let defaultDoelKlantUren = Column(CodingKeys.defaultDoelKlantUren)
        public static let defaultDoelInternUren = Column(CodingKeys.defaultDoelInternUren)
        public static let defaultNotities = Column(CodingKeys.defaultNotities)
    }
}
