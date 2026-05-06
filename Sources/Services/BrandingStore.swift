import Foundation

/// Persistente branding voorkeur — accent kleur in UserDefaults, logo als
/// bestand in Application Support. Geen klantdata, geen iCloud sync nodig.
public enum BrandingStore {
    private static let accentKey = "branding.accentHex"
    public static let defaultAccentHex: UInt32 = 0x2DD4A8

    public static func loadAccentHex() -> UInt32 {
        let raw = UserDefaults.standard.integer(forKey: accentKey)
        if raw == 0 { return defaultAccentHex }
        return UInt32(truncatingIfNeeded: raw)
    }

    public static func saveAccentHex(_ hex: UInt32) {
        UserDefaults.standard.set(Int(hex), forKey: accentKey)
    }

    public static func resetAccent() {
        UserDefaults.standard.removeObject(forKey: accentKey)
    }

    // MARK: - Logo

    public static func logoURL() throws -> URL {
        let folder = try ApplicationSupportLocations.appSupportDirectory()
            .appendingPathComponent("branding", isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        return folder.appendingPathComponent("logo")
    }

    public static func loadLogoData() -> Data? {
        guard let url = try? logoURL(),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    public static func saveLogo(_ data: Data) throws {
        let url = try logoURL()
        try data.write(to: url, options: .atomic)
    }

    public static func clearLogo() throws {
        let url = try logoURL()
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    public static func currentBranding() -> Branding {
        Branding(accentHex: loadAccentHex(), logoData: loadLogoData())
    }
}

public struct Branding: Sendable, Equatable {
    public let accentHex: UInt32
    public let logoData: Data?

    public init(accentHex: UInt32, logoData: Data?) {
        self.accentHex = accentHex
        self.logoData = logoData
    }

    public static let `default` = Branding(
        accentHex: BrandingStore.defaultAccentHex,
        logoData: nil
    )

    public var accentRGB: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let r = CGFloat((accentHex >> 16) & 0xFF) / 255.0
        let g = CGFloat((accentHex >> 8) & 0xFF) / 255.0
        let b = CGFloat(accentHex & 0xFF) / 255.0
        return (r, g, b)
    }

    public var accentDarkRGB: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let (r, g, b) = accentRGB
        return (r * 0.6, g * 0.6, b * 0.6)
    }
}
