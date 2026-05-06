import Foundation
import GRDB

public struct Project: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var naam: String
    public var klantNaam: String
    public var startDatum: Date
    public var eindDatum: Date?
    public var status: ProjectStatus
    public var factuurNummer: String?
    public var doelTotaalKlantUren: Double?
    public var doelTotaalInternUren: Double?
    public var notities: String

    public init(
        id: UUID = UUID(),
        naam: String,
        klantNaam: String,
        startDatum: Date,
        eindDatum: Date? = nil,
        status: ProjectStatus = .lopend,
        factuurNummer: String? = nil,
        doelTotaalKlantUren: Double? = nil,
        doelTotaalInternUren: Double? = nil,
        notities: String = ""
    ) {
        self.id = id
        self.naam = naam
        self.klantNaam = klantNaam
        self.startDatum = startDatum
        self.eindDatum = eindDatum
        self.status = status
        self.factuurNummer = factuurNummer
        self.doelTotaalKlantUren = doelTotaalKlantUren
        self.doelTotaalInternUren = doelTotaalInternUren
        self.notities = notities
    }
}

extension Project: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "project"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let naam = Column(CodingKeys.naam)
        public static let klantNaam = Column(CodingKeys.klantNaam)
        public static let startDatum = Column(CodingKeys.startDatum)
        public static let eindDatum = Column(CodingKeys.eindDatum)
        public static let status = Column(CodingKeys.status)
        public static let factuurNummer = Column(CodingKeys.factuurNummer)
        public static let doelTotaalKlantUren = Column(CodingKeys.doelTotaalKlantUren)
        public static let doelTotaalInternUren = Column(CodingKeys.doelTotaalInternUren)
        public static let notities = Column(CodingKeys.notities)
    }
}
