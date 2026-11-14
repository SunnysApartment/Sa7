import AppKit

/// An app identified by bundle ID, shown in the "don't fix in these apps" list.
struct AppInfo: Hashable, Identifiable {
    let bundleID: String
    let name: String
    var id: String { bundleID }
    /// The app's icon, or a generic app icon if it isn't installed.
    var icon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    init(bundleID: String, name: String) { self.bundleID = bundleID; self.name = name }

    init?(url: URL) {
        guard let b = Bundle(url: url), let id = b.bundleIdentifier else { return nil }
        let n = (b.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (b.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        self.init(bundleID: id, name: n)
    }
}

/// Apps where Sa7 stays out of the way (games, Terminal, editors where ⌃K means something else).
/// The list is persisted in UserDefaults ("excludedApps", as bundle IDs). Observe the frontmost app
/// to unregister the global hotkey while an excluded app is active, so the keystroke reaches that app.
@MainActor
final class AppRules: ObservableObject {
    static let shared = AppRules()
    private let key = "excludedApps"

    @Published private(set) var excluded: [AppInfo] = []

    private init() {
        let ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        excluded = ids.map { id in
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            return url.flatMap(AppInfo.init(url:)) ?? AppInfo(bundleID: id, name: id)
        }
    }

    func exclude(_ app: AppInfo) {
        guard !isExcluded(app.bundleID) else { return }
        excluded.append(app)
        save()
    }

    func include(_ bundleID: String) {
        excluded.removeAll { $0.bundleID == bundleID }
        save()
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excluded.contains { $0.bundleID == bundleID }
    }

    var frontmostIsExcluded: Bool { isExcluded(NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }

    /// Calls `onChange(isExcluded)` whenever the frontmost app changes (and once immediately).
    func startObserving(onChange: @escaping (Bool) -> Void) {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let id = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { onChange(self?.isExcluded(id) ?? false) }
        }
        onChange(frontmostIsExcluded)
    }

    /// Running regular apps, sorted by name, minus Sa7 itself.
    func runningApps() -> [AppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in
                guard let id = app.bundleIdentifier else { return nil }
                return AppInfo(bundleID: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Lets the user pick any .app via NSOpenPanel, starting in /Applications.
    func chooseApp() -> AppInfo? {
        let p = NSOpenPanel()
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        p.allowedContentTypes = [.applicationBundle]
        p.allowsMultipleSelection = false
        guard p.runModal() == .OK, let url = p.url else { return nil }
        return AppInfo(url: url)
    }

    private func save() { UserDefaults.standard.set(excluded.map(\.bundleID), forKey: key) }
}
