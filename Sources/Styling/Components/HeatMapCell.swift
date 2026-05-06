import SwiftUI

public struct HeatMapCell: View {
    public enum Variant: Sendable {
        case empty
        case confirmed
        case importedUnconfirmed
        case aiSuggested
        case rejected
    }

    private let uren: Double
    private let variant: Variant
    private let isSelected: Bool

    public init(uren: Double, variant: Variant, isSelected: Bool = false) {
        self.uren = uren
        self.variant = variant
        self.isSelected = isSelected
    }

    public var body: some View {
        ZStack {
            backgroundLayer

            if uren > 0 {
                HStack(spacing: 3) {
                    Text(formatted)
                        .font(.appNumberSmall(11))
                        .foregroundStyle(textColor)
                        .fontWeight(textWeight)
                    if variant == .aiSuggested {
                        Text("✨")
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .frame(minHeight: 32)
        .frame(maxWidth: .infinity)
        .overlay(borderOverlay)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch variant {
        case .empty:
            Color.clear
        case .confirmed:
            HeatMapBucket.bucket(for: uren).background
        case .aiSuggested:
            Color.pillAiBg
        case .importedUnconfirmed:
            UnconfirmedStripes()
        case .rejected:
            HeatMapBucket.bucket(for: uren).background.opacity(0.30)
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        if isSelected {
            Rectangle().stroke(Color.appPrimary, lineWidth: 1.5)
        } else {
            switch variant {
            case .aiSuggested:
                Rectangle().stroke(Color.pillAiBorder, lineWidth: 1)
            case .importedUnconfirmed:
                Rectangle().stroke(Color.heatUnconfirmedStroke.opacity(0.6), lineWidth: 0.5)
            default:
                Rectangle().stroke(Color.appBorder, lineWidth: 0.5)
            }
        }
    }

    private var textColor: Color {
        switch variant {
        case .aiSuggested: return .pillAiFg
        case .importedUnconfirmed: return .pillWarningFg
        case .rejected: return .appTextTertiary
        case .confirmed, .empty:
            return HeatMapBucket.bucket(for: uren).foreground
        }
    }

    private var textWeight: Font.Weight {
        switch variant {
        case .confirmed: return HeatMapBucket.bucket(for: uren).fontWeight
        case .aiSuggested: return .semibold
        default: return .medium
        }
    }

    private var formatted: String {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        f.decimalSeparator = ","
        return f.string(from: uren as NSNumber) ?? String(format: "%.1f", uren)
    }
}

/// Diagonale streep-patroon voor onbevestigde import-cellen.
private struct UnconfirmedStripes: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.heatUnconfirmedTint))
            let spacing: CGFloat = 5
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                ctx.stroke(p, with: .color(.heatUnconfirmedStroke.opacity(0.35)), lineWidth: 0.5)
                x += spacing
            }
        }
    }
}
