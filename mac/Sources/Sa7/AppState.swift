import AppKit
import Carbon
import ServiceManagement
import Sa7Core
import SwiftUI

/// Settings live in UserDefaults: ~/Library/Preferences/com.khaledomar.sa7.plist. Nothing else is stored.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var trusted = AXIsProcessTrusted()
    @Published var icon = "checkmark"
    @Published var status = ""
    @Published var keyboards = ""
    @Published var shortcutLabel: String
    @Published var recording = false
    @Published var practice = "hgsghl ugd;l"
    /// "en" (default) or "ar". The whole UI follows it, including right-to-left layout.
    @Published var language: String {
        didSet { defaults.set(language, forKey: "language"); status = t("Ready", "جاهز") }
    }
    @Published var switchKeyboard: Bool {
        didSet { defaults.set(switchKeyboard, forKey: "switchKeyboard") }
    }
    @Published var bubble: Bool { didSet { defaults.set(bubble, forKey: "showBubble") } }
    @Published var sound: Bool { didSet { defaults.set(sound, forKey: "playSound") } }
    /// Words Sa7 never flips, one per line or comma-separated.
    @Published var keepText: String {
        didSet { defaults.set(keepText, forKey: "keepWords"); keep = KeepList(KeepList.parse(keepText)) }
    }
    /// Off by default. When on, a hint bubble appears for a word typed on the wrong keyboard; nothing is changed or stored.
    @Published var typingHints: Bool { didSet { defaults.set(typingHints, forKey: "typingHints"); applyTypingHints() } }
    @Published var typingPermission = TypingWatcher.hasPermission

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                status = t("Couldn't change the login setting", "مقدرتش أغيّر التشغيل مع الماك")
            }
        }
    }

    private let defaults = UserDefaults.standard
    private let fixer = Fixer()
    private var hotkey: Hotkey?
    private var keyMonitor: Any?
    private var setupWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var busy = false
    private var keep: KeepList
    private var watcher: TypingWatcher?
    private var frontmostExcluded = false

    private init() {
        defaults.register(defaults: ["shortcutKey": kVK_ANSI_K, "shortcutModifiers": controlKey,
                                     "shortcutLabel": "⌃K", "switchKeyboard": true, "language": "en",
                                     "showBubble": true, "playSound": false, "keepWords": "Sa7", "typingHints": false])
        shortcutLabel = defaults.string(forKey: "shortcutLabel") ?? "⌃K"
        switchKeyboard = defaults.bool(forKey: "switchKeyboard")
        language = defaults.string(forKey: "language") == "ar" ? "ar" : "en"
        bubble = defaults.bool(forKey: "showBubble")
        sound = defaults.bool(forKey: "playSound")
        keepText = defaults.string(forKey: "keepWords") ?? ""
        keep = KeepList(KeepList.parse(defaults.string(forKey: "keepWords") ?? ""))
        typingHints = defaults.bool(forKey: "typingHints")
        status = t("Ready", "جاهز")
    }

    func t(_ english: String, _ arabic: String) -> String { language == "ar" ? arabic : english }

    func start() {
        hotkey = Hotkey { [weak self] in Task { @MainActor in await self?.fix() } }
        registerShortcut()
        refreshKeyboards()
        // In apps the person turned Sa7 off for, release the shortcut so it reaches that app.
        AppRules.shared.startObserving { [weak self] excluded in
            guard let self else { return }
            frontmostExcluded = excluded
            if excluded { hotkey?.unregister() } else if !recording { registerShortcut() }
        }
        Updater.shared.start()
        applyTypingHints()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        if !trusted || keyboards.isEmpty { showSetup() }
    }

    func fix() async {
        guard !busy, !recording else { return }
        busy = true
        defer { busy = false }
        show(await fixer.run(switchKeyboard: switchKeyboard, keep: keep))
    }

    private func show(_ outcome: Outcome) {
        switch outcome {
        case .fixed(let text):
            icon = "checkmark.circle.fill"; status = t("Fixed", "اتصلّح")
            if bubble { HUD.shared.show(text, sound: sound) }
        case .undone(let text):
            icon = "arrow.uturn.backward.circle"; status = t("Put back as it was", "رجّعته زي ما كان")
            if bubble { HUD.shared.show(text, symbol: "arrow.uturn.backward.circle.fill", sound: sound) }
        case .nothingToFix:
            icon = "minus.circle"; status = t("Nothing to fix", "مفيش حاجة تتصلّح")
            if bubble { HUD.shared.show(status, symbol: "minus.circle.fill", tint: .secondaryLabelColor) }
        case .noText:
            icon = "minus.circle"; status = t("No text selected", "مفيش كلام محدد")
            if bubble { HUD.shared.show(status, symbol: "minus.circle.fill", tint: .secondaryLabelColor) }
        case .noPermission: icon = "exclamationmark.triangle"; status = t("Needs Accessibility permission", "محتاج صلاحية Accessibility"); showSetup()
        case .noKeyboards: icon = "exclamationmark.triangle"; status = t("Add an Arabic, Persian or Urdu keyboard and an English or French one", "ضيف كيبورد عربي أو فارسي أو أردو، وكيبورد إنجليزي أو فرنسي"); showSetup()
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            icon = "checkmark"
        }
    }

    func fixClipboard() {
        guard let keyboards = Keyboards.current() else { return show(.noKeyboards) }
        Spelling.languages = (keyboards.latinLanguage, keyboards.otherLanguage)
        if let fixed = ClipboardFix.run({ Fixer.convert($0, keyboards: keyboards, keep: keep)?.text }) {
            status = t("Clipboard fixed. Paste it anywhere.", "اتصلّح اللي في الحافظة، الصقه في أي مكان")
            if bubble { HUD.shared.show(fixed, symbol: "doc.on.clipboard.fill", sound: sound) }
        } else {
            status = t("Nothing on the clipboard to fix", "مفيش حاجة في الحافظة تتصلّح")
            if bubble { HUD.shared.show(status, symbol: "minus.circle.fill", tint: .secondaryLabelColor) }
        }
    }

    private func applyTypingHints() {
        guard typingHints else { watcher?.stop(); return }
        if watcher == nil {
            watcher = TypingWatcher(isAllowed: { [weak self] in self?.frontmostExcluded == false },
                                    suggest: { [weak self] _, fixed in
                                        guard let self else { return }
                                        HUD.shared.hint(fixed, key: shortcutLabel)
                                    })
        }
        if watcher?.start() != true { TypingWatcher.requestPermission() }
        typingPermission = TypingWatcher.hasPermission
    }

    func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    private func poll() {
        if trusted != AXIsProcessTrusted() { trusted.toggle() }
        if typingHints {
            let allowed = TypingWatcher.hasPermission
            if typingPermission != allowed { typingPermission = allowed }
            if watcher?.isRunning == false, allowed { watcher?.start() }
        }
        if setupWindow?.isVisible == true { refreshKeyboards() }
    }

    private func refreshKeyboards() {
        let found = Keyboards.current()?.summary ?? ""
        if keyboards != found { keyboards = found }
    }

    /// macOS keeps a permission tied to the signature of the version it was given to. After a signature change the
    /// toggle in System Settings still shows "on" but no longer applies, so clear Sa7's old entries and ask again.
    func resetPermission() {
        let id = Bundle.main.bundleIdentifier ?? "com.khaledomar.sa7"
        for service in ["Accessibility", "ListenEvent"] {
            let reset = Process()
            reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            reset.arguments = ["reset", service, id]
            try? reset.run()
            reset.waitUntilExit()
        }
        askForPermission()
    }

    func askForPermission() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    func showSetup() {
        refreshKeyboards()
        if setupWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SetupView().environmentObject(self)))
            window.title = "Sa7 | صح"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            setupWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()
                .environmentObject(self).environmentObject(AppRules.shared).environmentObject(Updater.shared)))
            window.title = t("Sa7 Settings", "إعدادات صح")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.title = t("Sa7 Settings", "إعدادات صح")
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: Shortcut

    func startRecording() {
        recording = true
        hotkey?.unregister()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return nil
        }
    }

    func stopRecording() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        recording = false
        registerShortcut()
    }

    private func record(_ event: NSEvent) {
        defer { stopRecording() }
        if event.keyCode == UInt16(kVK_Escape) { return }
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !flags.isDisjoint(with: [.control, .option, .command]) else {
            status = t("The shortcut needs ⌃, ⌥ or ⌘", "الاختصار لازم يكون فيه ⌃ أو ⌥ أو ⌘")
            return
        }
        let parts: [(NSEvent.ModifierFlags, Int, String)] = [(.control, controlKey, "⌃"), (.option, optionKey, "⌥"),
                                                             (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")]
        let used = parts.filter { flags.contains($0.0) }
        shortcutLabel = used.map(\.2).joined() + Keyboards.keyName(Int(event.keyCode))
        defaults.set(Int(event.keyCode), forKey: "shortcutKey")
        defaults.set(used.reduce(0) { $0 | $1.1 }, forKey: "shortcutModifiers")
        defaults.set(shortcutLabel, forKey: "shortcutLabel")
    }

    private func registerShortcut() {
        let ok = hotkey?.register(keyCode: defaults.integer(forKey: "shortcutKey"),
                                  modifiers: defaults.integer(forKey: "shortcutModifiers")) ?? false
        if !ok { status = t("\(shortcutLabel) is used by another app, pick another one",
                                "الاختصار \u{2066}\(shortcutLabel)\u{2069} مستخدم في برنامج تاني، اختار غيره") }
    }
}
