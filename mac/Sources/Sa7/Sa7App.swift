import SwiftUI

@main
struct Sa7App: App {
    @NSApplicationDelegateAdaptor(Delegate.self) private var delegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(state)
        } label: {
            Image(systemName: state.icon)
        }
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AppState.shared.start() }
    }

    /// Opening Sa7 again while it runs (Spotlight, Finder) brings up Settings, since it has no Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        MainActor.assumeIsolated { AppState.shared.showSettings() }
        return false
    }
}
