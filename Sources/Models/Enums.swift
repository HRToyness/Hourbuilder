import Foundation

public enum ProjectStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case lopend
    case afgerond
    case gefactureerd

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .lopend: return "Lopend"
        case .afgerond: return "Afgerond"
        case .gefactureerd: return "Gefactureerd"
        }
    }
}

public enum PersoonType: String, Codable, CaseIterable, Sendable, Identifiable {
    case intern
    case klant
    case leverancierWebbouwer = "leverancier_webbouwer"
    case leverancierEditor = "leverancier_editor"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .intern: return "Intern"
        case .klant: return "Klant"
        case .leverancierWebbouwer: return "Leverancier (webbouwer)"
        case .leverancierEditor: return "Leverancier (editor)"
        }
    }

    /// High-level grouping used voor matrix totalen.
    public var groep: PersoonGroep {
        switch self {
        case .intern: return .intern
        case .klant: return .klant
        case .leverancierWebbouwer, .leverancierEditor: return .leverancier
        }
    }
}

public enum PersoonGroep: String, Codable, CaseIterable, Sendable, Identifiable {
    case intern
    case klant
    case leverancier

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .intern: return "Intern"
        case .klant: return "Klant"
        case .leverancier: return "Leverancier"
        }
    }
}

public enum ActiviteitBron: String, Codable, CaseIterable, Sendable, Identifiable {
    case agenda
    case importCsv = "import_csv"
    case importXlsx = "import_xlsx"
    case handmatig
    case aiVoorstel = "ai_voorstel"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .agenda: return "Agenda"
        case .importCsv: return "CSV import"
        case .importXlsx: return "Excel import"
        case .handmatig: return "Handmatig"
        case .aiVoorstel: return "AI voorstel"
        }
    }
}

public enum ActiviteitStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case concept
    case bevestigd
    case afgewezen

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .concept: return "Concept"
        case .bevestigd: return "Bevestigd"
        case .afgewezen: return "Afgewezen"
        }
    }
}

public enum ImportBronType: String, Codable, CaseIterable, Sendable, Identifiable {
    case ics
    case csv
    case xlsx
    case calendarSync = "calendar_sync"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .ics: return "ICS bestand"
        case .csv: return "CSV bestand"
        case .xlsx: return "Excel bestand"
        case .calendarSync: return "Apple Calendar"
        }
    }
}
