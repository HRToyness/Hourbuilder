import SwiftUI

public struct AppStatusBadge: View {
    public enum Tone: Sendable, Hashable {
        case success
        case warning
        case neutral
        case ai
        case klant
        case intern
        case leverancier

        public var background: Color {
            switch self {
            case .success: return .pillSuccessBg
            case .warning: return .pillWarningBg
            case .neutral: return .pillNeutralBg
            case .ai: return .pillAiBg
            case .klant: return .pillKlantBg
            case .intern: return .pillInternBg
            case .leverancier: return .pillLeverancierBg
            }
        }

        public var foreground: Color {
            switch self {
            case .success: return .pillSuccessFg
            case .warning: return .pillWarningFg
            case .neutral: return .pillNeutralFg
            case .ai: return .pillAiFg
            case .klant: return .pillKlantFg
            case .intern: return .pillInternFg
            case .leverancier: return .pillLeverancierFg
            }
        }
    }

    private let label: String
    private let tone: Tone

    public init(label: String, tone: Tone) {
        self.label = label
        self.tone = tone
    }

    public var body: some View {
        Text(label)
            .font(.appLabel(10))
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(tone.background)
            .foregroundStyle(tone.foreground)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
