import SwiftUI

/// Plaatst een uren-totaal in één van 5 buckets voor heat-map kleuring.
public enum HeatMapBucket: Int, Sendable, CaseIterable {
    case empty = 0
    case low = 1       // 1–4
    case medium = 2    // 5–12
    case high = 3      // 13–24
    case veryHigh = 4  // 25+

    public static func bucket(for uren: Double) -> HeatMapBucket {
        switch uren {
        case ..<0.0001: return .empty
        case 0.0001..<5: return .low
        case 5..<13: return .medium
        case 13..<25: return .high
        default: return .veryHigh
        }
    }

    public var background: Color {
        switch self {
        case .empty: return .heatLevel0
        case .low: return .heatLevel1
        case .medium: return .heatLevel2
        case .high: return .heatLevel3
        case .veryHigh: return .heatLevel4
        }
    }

    public var foreground: Color {
        switch self {
        case .empty, .low: return .appTextPrimary
        case .medium: return .heatTextLight
        case .high, .veryHigh: return .heatTextDark
        }
    }

    public var fontWeight: Font.Weight {
        switch self {
        case .high, .veryHigh: return .bold
        default: return .medium
        }
    }
}
