import SwiftUI

public struct AppPrimaryButton: View {
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
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isDisabled ? Color.appTextTertiary : Color.appPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
