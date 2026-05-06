import SwiftUI

public struct FilterChip: View {
    private let label: String
    private let isActive: Bool
    private let dot: Color?
    private let action: () -> Void

    public init(
        label: String,
        isActive: Bool = false,
        dot: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.isActive = isActive
        self.dot = dot
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let dot {
                    Circle()
                        .fill(dot)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.appBody(11))
                    .fontWeight(isActive ? .semibold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(isActive ? .white : Color.appTextPrimary)
            .background(isActive ? Color.appPrimary : Color.appSurface)
            .overlay(
                Capsule().stroke(isActive ? Color.appPrimary : Color.appBorder, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
