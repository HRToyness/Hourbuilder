import Foundation
import GRDB

public struct TemplateFase: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var templateId: UUID
    public var naam: String
    public var volgorde: Int
    public var weekVanaf: Int?
    public var weekTotEnMet: Int?

    public init(
        id: UUID = UUID(),
        templateId: UUID,
        naam: String,
        volgorde: Int,
        weekVanaf: Int? = nil,
        weekTotEnMet: Int? = nil
    ) {
        self.id = id
        self.templateId = templateId
        self.naam = naam
        self.volgorde = volgorde
        self.weekVanaf = weekVanaf
        self.weekTotEnMet = weekTotEnMet
    }
}

extension TemplateFase: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "templateFase"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let templateId = Column(CodingKeys.templateId)
        public static let naam = Column(CodingKeys.naam)
        public static let volgorde = Column(CodingKeys.volgorde)
        public static let weekVanaf = Column(CodingKeys.weekVanaf)
        public static let weekTotEnMet = Column(CodingKeys.weekTotEnMet)
    }
}
