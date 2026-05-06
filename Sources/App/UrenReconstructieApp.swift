import SwiftUI
import AppKit
import Database
import Features
import Services
import Styling

/// SPM-executables krijgen standaard `.prohibited` activation policy en geen
/// dock-icoon — dat maakt het venster onvindbaar. Deze delegate transitioneert
/// naar `.regular` zodra de app klaar is met laden, en haalt 'm naar voren.
final class UrenReconstructieAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct UrenReconstructieApp: App {
    @NSApplicationDelegateAdaptor(UrenReconstructieAppDelegate.self) private var appDelegate

    @State private var appDatabase: AppDatabase
    @State private var initError: String?

    init() {
        do {
            let url = try ApplicationSupportLocations.databaseURL()
            _appDatabase = State(initialValue: try AppDatabase.makeOnDisk(at: url))
            _initError = State(initialValue: nil)
        } catch {
            _appDatabase = State(initialValue: try! AppDatabase.makeInMemory())
            _initError = State(initialValue: "Kon database niet openen — gebruik tijdelijk een in-memory database. \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(appDatabase: appDatabase, initError: initError)
                .frame(minWidth: 980, minHeight: 640)
                .preferredColorScheme(.light)
        }
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
                .preferredColorScheme(.light)
        }
    }
}
