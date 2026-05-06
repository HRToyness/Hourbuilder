import SwiftUI
import Styling

public struct SectionTabBar<ID: Hashable>: View {
    public struct Item: Identifiable {
        public let id: ID
        public let label: String
        public let count: Int?
        public let countTone: CountBadge.Tone

        public init(id: ID, label: String, count: Int? = nil, countTone: CountBadge.Tone = .neutral) {
            self.id = id
            self.label = label
            self.count = count
            self.countTone = countTone
        }
    }

    @Binding private var selection: ID
    private let items: [Item]

    public init(selection: Binding<ID>, items: [Item]) {
        self._selection = selection
        self.items = items
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
    }

    private func tabButton(_ item: Item) -> some View {
        let isActive = item.id == selection
        return Button {
            selection = item.id
        } label: {
            HStack(spacing: 5) {
                Text(item.label)
                    .font(.appBody(12))
                    .fontWeight(isActive ? .semibold : .regular)
                    .foregroundStyle(isActive ? Color.appTextPrimary : Color.appTextSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if let count = item.count, count > 0 {
                    CountBadge(count: count, tone: item.countTone)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isActive ? Color.appPrimary : Color.clear)
                    .frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
