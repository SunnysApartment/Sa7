import AppKit
import Carbon
import Sa7Core

/// Opt-in: notices a word just typed on the wrong keyboard and suggests the fix. It never changes text by itself.
///
/// Privacy: it reads key presses only to build the word being typed, keeps at most that one word in memory,
/// and forgets it at the next space, click, arrow or shortcut. Nothing is stored, logged or sent anywhere.
/// Password fields (secure input) are skipped.
@MainActor
final class TypingWatcher {
    private let isAllowed: () -> Bool
    private let suggest: (_ typed: String, _ fixed: String) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var buffer = WordBuffer()
    private var keyboards: Keyboards?
    private var keyboardsReadAt = Date.distantPast

    /// `suggest` is called on the main actor with (typedWord, fixedWord) when a just-finished word is gibberish in the current
    /// keyboard but a real word on the other keyboard. `isAllowed` lets the app veto (e.g. excluded apps).
    init(isAllowed: @escaping () -> Bool, suggest: @escaping (_ typed: String, _ fixed: String) -> Void) {
        self.isAllowed = isAllowed
        self.suggest = suggest
    }

    isolated deinit { stop() }

    var isRunning: Bool { tap != nil }

    /// Input Monitoring. Accessibility may also be accepted by macOS, so `start()` is the real test.
    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    /// Shows the Input Monitoring prompt (once); after that the person turns it on in System Settings.
    static func requestPermission() { CGRequestListenEventAccess() }

    /// Starts a listen-only keyboard event tap; returns false if macOS refuses (missing permission).
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.keyDown, .leftMouseDown, .rightMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | 1 << $1.rawValue }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                          eventsOfInterest: mask, callback: { _, type, event, me in
            let watcher = Unmanaged<TypingWatcher>.fromOpaque(me!).takeUnretainedValue()
            MainActor.assumeIsolated { watcher.handle(type, event) } // the tap runs on the main run loop
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        buffer.reset()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            buffer.reset()
        case .keyDown:
            // Sa7's own keystrokes (the fix it types or pastes) come from this process.
            if event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(getpid()) { return }
            if IsSecureEventInputEnabled() || !event.flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]) {
                buffer.reset()
                return
            }
            if event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Delete) {
                buffer.backspace()
                return
            }
            var length = 0
            var chars = [UniChar](repeating: 0, count: 8)
            event.keyboardGetUnicodeString(maxStringLength: chars.count, actualStringLength: &length, unicodeString: &chars)
            if let word = buffer.type(String(utf16CodeUnits: chars, count: length)) {
                // Spell checking can be slow; do it after the tap callback returns.
                DispatchQueue.main.async { [weak self] in self?.check(word) }
            }
        default:
            buffer.reset() // a click may have moved the cursor
        }
    }

    private func check(_ typed: String) {
        guard isRunning, !IsSecureEventInputEnabled(), isAllowed(), let keyboards = currentKeyboards() else { return }
        let capsLock = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
        let fix = Converter(pair: keyboards.pair).fix(typed, capsLock: capsLock, isWord: Spelling.isWord)
        guard let target = fix.target,
              Spelling.isWord(typed, target.other) == false,
              Spelling.isWord(fix.text, target) == true else { return }
        suggest(typed, fix.text)
    }

    /// Reading the keyboards is not free, and they rarely change.
    private func currentKeyboards() -> Keyboards? {
        if Date().timeIntervalSince(keyboardsReadAt) > 5 {
            keyboards = Keyboards.current()
            keyboardsReadAt = Date()
            if let keyboards { Spelling.languages = (keyboards.latinLanguage, keyboards.otherLanguage) }
        }
        return keyboards
    }
}
