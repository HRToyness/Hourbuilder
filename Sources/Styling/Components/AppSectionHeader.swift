import SwiftUI

public struct AppSectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let style: Style

    public enum Style: Sendable { case plain, prominent }

    public init(title: String, subtitle: String? = nil, style: Style = .plain) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(style == .prominent ? .appTitle(20) : .appH1(15))
                .foregroundStyle(Color.appTextPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.appMeta(11))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }
}
