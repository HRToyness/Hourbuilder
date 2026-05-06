import SwiftUI

public struct KPIRow<Trailing: View>: View {
    private let label: String
    private let value: String
    private let valueSuffix: String?
    private let trailing: () -> Trailing

    public init(
        label: String,
        value: String,
        valueSuffix: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.label = label
        self.value = value
        self.valueSuffix = valueSuffix
        self.trailing = trailing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.appLabel(10))
                .tracking(0.5)
                .foregroundStyle(Color.appTextSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.appNumber(20))
                    .foregroundStyle(Color.appTextPrimary)
                if let valueSuffix {
                    Text(valueSuffix)
                        .font(.appNumberSmall(11))
                        .foregroundStyle(Color.appTextTertiary)
                }
            }
            trailing()
        }
    }
}

extension KPIRow where Trailing == EmptyView {
    public init(label: String, value: String, valueSuffix: String? = nil) {
        self.init(label: label, value: value, valueSuffix: valueSuffix) { EmptyView() }
    }
}
