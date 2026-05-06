import Foundation

public enum ApplicationSupportLocations {
    public static let folderName = "UrenReconstructie"

    /// `~/Library/Application Support/UrenReconstructie/`
    public static func appSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        return folder
    }

    /// Pad naar de SQLite database in Application Support.
    public static func databaseURL() throws -> URL {
        try appSupportDirectory().appendingPathComponent("urenreconstructie.sqlite")
    }
}
