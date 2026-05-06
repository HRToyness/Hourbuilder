import Foundation
import GRDB

public struct Activiteit: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var projectId: UUID
    public var faseId: UUID?
    public var persoonId: UUID
    public var datum: Date
    public var uren: Double
    public var beschrijving: String
    public var bron: ActiviteitBron
    public var bronReferentie: String?
    public var status: ActiviteitStatus
    public var bewijs: String?
    public var importBronId: UUID?

    public init(
        id: UUID = UUID(),
        projectId: UUID,
        faseId: UUID? = nil,
        persoonId: UUID,
        datum: Date,
        uren: Double,
        beschrijving: String = "",
        bron: ActiviteitBron,
        bronReferentie: String? = nil,
        status: ActiviteitStatus = .concept,
        bewijs: String? = nil,
        importBronId: UUID? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.faseId = faseId
        self.persoonId = persoonId
        self.datum = datum
        self.uren = uren
        self.beschrijving = beschrijving
        self.bron = bron
        self.bronReferentie = bronReferentie
        self.status = status
        self.bewijs = bewijs
        self.importBronId = importBronId
    }
}

extension Activiteit: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "activiteit"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let projectId = Column(CodingKeys.projectId)
        public static let faseId = Column(CodingKeys.faseId)
        public static let persoonId = Column(CodingKeys.persoonId)
        public static let datum = Column(CodingKeys.datum)
        public static let uren = Column(CodingKeys.uren)
        public static let beschrijving = Column(CodingKeys.beschrijving)
        public static let bron = Column(CodingKeys.bron)
        public static let bronReferentie = Column(CodingKeys.bronReferentie)
        public static let status = Column(CodingKeys.status)
        public static let bewijs = Column(CodingKeys.bewijs)
        public static let importBronId = Column(CodingKeys.importBronId)
    }
}
