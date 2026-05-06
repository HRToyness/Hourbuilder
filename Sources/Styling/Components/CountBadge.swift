import SwiftUI

public struct CountBadge: View {
    public enum Tone: Sendable {
        case neutral
        case ai
    }

    private let count: Int
    private let tone: Tone

    public init(count: Int, tone: Tone = .neutral) {
        self.count = count
        self.tone = tone
    }

    public var body: some View {
        Text("\(count)")
            .font(.appLabel(9))
            .foregroundStyle(foreground)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(background)
            .clipShape(Capsule())
            .opacity(count == 0 ? 0 : 1)
    }

    private var background: Color {
        switch tone {
        case .neutral: return .appBorder
        case .ai: return .pillAiBg
        }
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return .appTextSecondary
        case .ai: return .pillAiFg
        }
    }
}
