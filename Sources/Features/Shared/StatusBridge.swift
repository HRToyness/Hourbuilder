import Foundation
import Models
import Styling

/// Bridges domein-enums uit `Models` naar de visuele varianten in `Styling`.
/// Houdt Models en Styling onafhankelijk; Features doet de mapping.
enum StatusBridge {
    static func cellVariant(
        for activiteiten: [Activiteit]
    ) -> HeatMapCell.Variant {
        guard !activiteiten.isEmpty else { return .empty }
        let bevatAi = activiteiten.contains { $0.bron == .aiVoorstel }
        if bevatAi { return .aiSuggested }
        if activiteiten.allSatisfy({ $0.status == .afgewezen }) {
            return .rejected
        }
        if activiteiten.contains(where: { $0.status == .bevestigd }) {
            return .confirmed
        }
        return .importedUnconfirmed
    }

    static func badgeTone(for status: ProjectStatus) -> AppStatusBadge.Tone {
        switch status {
        case .lopend: return .success
        case .afgerond: return .warning
        case .gefactureerd: return .neutral
        }
    }

    static func badgeTone(for status: ActiviteitStatus) -> AppStatusBadge.Tone {
        switch status {
        case .concept: return .warning
        case .bevestigd: return .success
        case .afgewezen: return .neutral
        }
    }

    static func badgeTone(for type: PersoonType) -> AppStatusBadge.Tone {
        switch type.groep {
        case .klant: return .klant
        case .intern: return .intern
        case .leverancier: return .leverancier
        }
    }

    static func badgeTone(for groep: PersoonGroep) -> AppStatusBadge.Tone {
        switch groep {
        case .klant: return .klant
        case .intern: return .intern
        case .leverancier: return .leverancier
        }
    }

    static func badgeTone(for bron: ActiviteitBron) -> AppStatusBadge.Tone {
        switch bron {
        case .agenda: return .leverancier
        case .importCsv, .importXlsx: return .neutral
        case .handmatig: return .intern
        case .aiVoorstel: return .ai
        }
    }
}
