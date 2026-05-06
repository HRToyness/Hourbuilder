import Foundation
import GRDB

public struct Persoon: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var naam: String
    public var rol: String
    public var type: PersoonType
    public var email: String?

    public init(
        id: UUID = UUID(),
        naam: String,
        rol: String,
        type: PersoonType,
        email: String? = nil
    ) {
        self.id = id
        self.naam = naam
        self.rol = rol
        self.type = type
        self.email = email
    }
}

extension Persoon: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "persoon"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let naam = Column(CodingKeys.naam)
        public static let rol = Column(CodingKeys.rol)
        public static let type = Column(CodingKeys.type)
        public static let email = Column(CodingKeys.email)
    }
}
