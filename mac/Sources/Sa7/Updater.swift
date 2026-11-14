import Foundation
import Sa7Core

/// Opt-in update checker. Touches the network only when `enabled` is on or a check is forced ("Check now").
/// The request carries nothing but a fixed User-Agent: no cookies, no cache, no identifiers.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "checkForUpdates")
            start()
        }
    }
    @Published private(set) var available: Version?
    @Published private(set) var installing = false
    /// Set when install() fails to start or the installer exits non-zero.
    @Published private(set) var errorMessage: String?

    private var timer: Timer?
    private let api = URL(string: "https://api.github.com/repos/SunnysApartment/Sa7/releases/latest")!
    private let installCommand = "curl -fsSL https://sunnysapartment.github.io/Sa7/install.sh | bash"

    private init() {
        enabled = UserDefaults.standard.bool(forKey: "checkForUpdates")
    }

    private var current: Version? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(Version.init)
    }

    func checkIfDue(force: Bool = false) async {
        guard enabled || force else { return }
        let last = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date
        if !force, let last, Date().timeIntervalSince(last) < 24 * 3600 { return }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        var request = URLRequest(url: api)
        request.setValue("Sa7-updater", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession(configuration: config).data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        UserDefaults.standard.set(Date(), forKey: "lastUpdateCheck")
        guard let release = ReleaseInfo(json: data), let current else { return }
        available = release.version > current ? release.version : nil
    }

    func install() -> Bool {
        guard !installing else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", installCommand]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = FileHandle.nullDevice
        process.terminationHandler = { [weak self] p in
            let text = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let status = p.terminationStatus
            Task { @MainActor in
                guard let self else { return }
                self.installing = false
                if status != 0 {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.errorMessage = trimmed.isEmpty ? "Update failed (exit \(status))" : trimmed
                }
            }
        }
        errorMessage = nil
        do { try process.run() } catch {
            errorMessage = error.localizedDescription
            return false
        }
        installing = true
        return true
    }

    /// Restarts the 6-hour timer (and does a due check now) while enabled; stops it otherwise.
    func start() {
        timer?.invalidate()
        timer = nil
        guard enabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
            Task { @MainActor in await Updater.shared.checkIfDue() }
        }
        Task { await checkIfDue() }
    }
}
