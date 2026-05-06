import SwiftUI

public struct AppCard<Content: View>: View {
    private let showsAccentStripe: Bool
    @ViewBuilder private let content: () -> Content

    public init(
        showsAccentStripe: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsAccentStripe = showsAccentStripe
        self.content = content
    }

    public var body: some View {
        content()
            .padding(14)
            .background(Color.appSurface)
            .overlay(alignment: .leading) {
                if showsAccentStripe {
                    Rectangle()
                        .fill(Color.appPrimary)
                        .frame(width: 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(Color.appBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}
