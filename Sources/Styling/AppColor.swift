import SwiftUI
import AppKit

extension Color {
    // MARK: - Surface & background

    /// Window-content achtergrond — gebruikt het systeem semantic kleur zodat
    /// de detail-kant matcht met de sidebar-vibrancy en niet "wit-tegen-zwart"
    /// botst op donkere wallpapers.
    public static let appBackground = Color(nsColor: .windowBackgroundColor)
    public static let appSurface = Color(nsColor: .textBackgroundColor)
    public static let appSidebar = Color(nsColor: .underPageBackgroundColor)

    // MARK: - Tekst

    public static let appPrimary = Color(hex: 0x1F1F1F)
    public static let appTextPrimary = Color(hex: 0x1F1F1F)
    public static let appTextSecondary = Color(hex: 0x6A6A66)
    public static let appTextTertiary = Color(hex: 0x8A8A85)

    // MARK: - Lijnen

    public static let appBorder = Color(hex: 0xE5E5E0)
    public static let appBorderStrong = Color(hex: 0xDDDDD5)

    // MARK: - Accent (legacy aliases — gebruikt door bestaande views, in nieuwe ontwerp neutraal)

    public static let appAccent = Color(hex: 0x1F1F1F)
    public static let appAccentDark = Color(hex: 0x0A6B40)
    public static let appWarning = Color(hex: 0x9F6B00)

    // MARK: - Status pill paren (bg/fg)

    public static let pillSuccessBg = Color(hex: 0xDCF5E5)
    public static let pillSuccessFg = Color(hex: 0x0A6B40)
    public static let pillWarningBg = Color(hex: 0xFFF1D9)
    public static let pillWarningFg = Color(hex: 0x9F6B00)
    public static let pillNeutralBg = Color(hex: 0xE5E5E0)
    public static let pillNeutralFg = Color(hex: 0x5A5A57)
    public static let pillAiBg = Color(hex: 0xFAEEFC)
    public static let pillAiFg = Color(hex: 0x7A2299)
    public static let pillAiBorder = Color(hex: 0xB560D4)
    public static let pillKlantBg = Color(hex: 0xFFF6D9)
    public static let pillKlantFg = Color(hex: 0x9F6B00)
    public static let pillInternBg = Color(hex: 0xE0F0E5)
    public static let pillInternFg = Color(hex: 0x0F7B6C)
    public static let pillLeverancierBg = Color(hex: 0xE8F4FF)
    public static let pillLeverancierFg = Color(hex: 0x114B7A)

    // MARK: - Heat-map (matrix uren intensiteit)

    public static let heatLevel0 = Color.clear
    public static let heatLevel1 = Color(hex: 0xE8F4FF)
    public static let heatLevel2 = Color(hex: 0xC5E1FB)
    public static let heatLevel3 = Color(hex: 0x9CCBF6)
    public static let heatLevel4 = Color(hex: 0x74B5F0)
    public static let heatTextLight = Color(hex: 0x114B7A)
    public static let heatTextDark = Color(hex: 0x0A3559)

    public static let heatUnconfirmedTint = Color(hex: 0xFFF8E0)
    public static let heatUnconfirmedStroke = Color(hex: 0xD4A12A)
}

extension Color {
    public init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
