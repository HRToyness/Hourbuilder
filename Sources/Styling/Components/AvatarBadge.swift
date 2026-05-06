import SwiftUI

public struct AvatarBadge: View {
    private let name: String
    private let size: CGFloat

    public init(name: String, size: CGFloat = 22) {
        self.name = name
        self.size = size
    }

    public var body: some View {
        let pair = AvatarPalette.pair(for: name)
        let initials = AvatarPalette.initials(for: name)

        return Text(initials)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(pair.foreground)
            .frame(width: size, height: size)
            .background(pair.background)
            .clipShape(Circle())
    }
}
