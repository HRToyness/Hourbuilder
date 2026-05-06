import SwiftUI

/// Mini lijngrafiek voor 6–12 datapunten in een kleine ruimte. Geen assen,
/// geen labels. Bedoeld voor sidebar / portfolio kaarten.
public struct Sparkline: View {
    private let values: [Double]
    private let lineColor: Color
    private let fillColor: Color?

    public init(
        values: [Double],
        lineColor: Color = .appPrimary,
        fillColor: Color? = nil
    ) {
        self.values = values
        self.lineColor = lineColor
        self.fillColor = fillColor
    }

    public var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                if let fillColor, !pts.isEmpty {
                    fillPath(points: pts, in: geo.size)
                        .fill(fillColor)
                }
                if !pts.isEmpty {
                    linePath(points: pts)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: 18)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let maxVal = max(values.max() ?? 1, 1)
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { idx, value in
            let x = CGFloat(idx) * stepX
            let y = size.height - (size.height * CGFloat(value / maxVal))
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() { path.addLine(to: p) }
        return path
    }

    private func fillPath(points: [CGPoint], in size: CGSize) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: points[0].x, y: size.height))
        for p in points { path.addLine(to: p) }
        path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: size.height))
        path.closeSubpath()
        return path
    }
}
