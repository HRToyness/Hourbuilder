import Foundation
import GRDB

public enum TemplatePersoonMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case specifiek
    case placeholder

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .specifiek: return "Specifieke persoon"
        case .placeholder: return "Placeholder rol"
        }
    }
}

public struct TemplatePersoonEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var templateId: UUID
    public var mode: TemplatePersoonMode
    public var persoonId: UUID?
    public var placeholderRol: String?
    public var placeholderType: PersoonType?

    public init(
        id: UUID = UUID(),
        templateId: UUID,
        mode: TemplatePersoonMode,
        persoonId: UUID? = nil,
        placeholderRol: String? = nil,
        placeholderType: PersoonType? = nil
    ) {
        self.id = id
        self.templateId = templateId
        self.mode = mode
        self.persoonId = persoonId
        self.placeholderRol = placeholderRol
        self.placeholderType = placeholderType
    }

    public static func specifiek(templateId: UUID, persoonId: UUID) -> Self {
        TemplatePersoonEntry(
            templateId: templateId,
            mode: .specifiek,
            persoonId: persoonId
        )
    }

    public static func placeholder(
        templateId: UUID,
        rol: String,
        type: PersoonType
    ) -> Self {
        TemplatePersoonEntry(
            templateId: templateId,
            mode: .placeholder,
            placeholderRol: rol,
            placeholderType: type
        )
    }
}

extension TemplatePersoonEntry: FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "templatePersoonEntry"
    public static var databaseUUIDEncodingStrategy: DatabaseUUIDEncodingStrategy { .uppercaseString }

    public enum Columns {
        public static let id = Column(CodingKeys.id)
        public static let templateId = Column(CodingKeys.templateId)
        public static let mode = Column(CodingKeys.mode)
        public static let persoonId = Column(CodingKeys.persoonId)
        public static let placeholderRol = Column(CodingKeys.placeholderRol)
        public static let placeholderType = Column(CodingKeys.placeholderType)
    }
}
