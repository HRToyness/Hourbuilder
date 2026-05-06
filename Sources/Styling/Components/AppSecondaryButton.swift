import SwiftUI

public struct AppSecondaryButton: View {
    private let title: String
    private let action: () -> Void
    private let isDisabled: Bool

    public init(title: String, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appLabel(12))
                .foregroundStyle(isDisabled ? Color.appTextTertiary : Color.appTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.appSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.appBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
