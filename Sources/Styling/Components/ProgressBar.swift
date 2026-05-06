import SwiftUI

public struct ProgressBar: View {
    private let value: Double  // 0..1
    private let fill: Color
    private let track: Color
    private let height: CGFloat

    public init(
        value: Double,
        fill: Color = .appPrimary,
        track: Color = .appBorder,
        height: CGFloat = 4
    ) {
        self.value = max(0, min(1, value))
        self.fill = fill
        self.track = track
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * value)
            }
        }
        .frame(height: height)
    }
}
