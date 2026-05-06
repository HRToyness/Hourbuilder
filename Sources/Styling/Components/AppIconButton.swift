import SwiftUI

public struct AppIconButton: View {
    private let label: String
    private let systemImage: String
    private let action: () -> Void

    public init(_ label: String, systemImage: String, action: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.appBody(12))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(Color.appTextPrimary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
