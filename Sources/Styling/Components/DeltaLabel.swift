import SwiftUI

public struct DeltaLabel: View {
    public enum Sentiment: Sendable {
        case positive   // groen
        case negative   // oranje/rood
        case neutral    // grijs
    }

    private let text: String
    private let sentiment: Sentiment

    public init(_ text: String, sentiment: Sentiment) {
        self.text = text
        self.sentiment = sentiment
    }

    public var body: some View {
        Text(text)
            .font(.appLabel(11))
            .foregroundStyle(color)
    }

    private var color: Color {
        switch sentiment {
        case .positive: return .pillSuccessFg
        case .negative: return .pillWarningFg
        case .neutral: return .appTextTertiary
        }
    }
}
