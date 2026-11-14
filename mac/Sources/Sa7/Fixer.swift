import AppKit
import Carbon
import Sa7Core

enum Outcome { case fixed(String), undone(String), nothingToFix, noText, noPermission, noKeyboards }

/// Copies the selection (or the last word), fixes it, pastes it back and puts the clipboard back as it was.
/// Pressing the shortcut again right after a fix puts the original text back.
@MainActor
final class Fixer {
    private let pasteboard = NSPasteboard.general
    private var last: LastFix?

    func run(switchKeyboard: Bool, keep: KeepList) async -> Outcome {
        guard AXIsProcessTrusted() else { return .noPermission }
        guard let keyboards = Keyboards.current() else { return .noKeyboards }
        Spelling.languages = (keyboards.latinLanguage, keyboards.otherLanguage)
        await waitForModifiersUp()
        let capsLock = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)

        let saved = snapshot()
        let changeCountAtStart = pasteboard.changeCount
        defer { if pasteboard.changeCount != changeCountAtStart { restore(saved) } }

        if let previous = last {
            last = nil
            if let original = await undo(previous) {
                if switchKeyboard { keyboards.select(Self.script(of: original)) }
                return .undone(original)
            }
        }

        // When the app says nothing is selected, don't press ⌘C: some editors copy the whole line then.
        var text = selectionIsEmpty() ? nil : await copySelection()
        let wasSelection = text != nil
        if text == nil {
            press(CGKeyCode(kVK_LeftArrow), [.maskAlternate, .maskShift]) // select the last word
            text = await copySelection()
        }
        guard let text else { return .noText }
        guard let result = Self.convert(text, keyboards: keyboards, capsLock: capsLock, keep: keep) else { return .nothingToFix }

        await put(result.text)
        last = LastFix(original: text, fixed: result.text, wasSelection: wasSelection)
        if switchKeyboard { keyboards.select(result.target) }
        return .fixed(result.text)
    }

    /// The fix for `text`: wrong-keyboard conversion, or Franco-Arabic when that's what it is,
    /// with words from the never-flip list put back. Nil when nothing would change.
    static func convert(_ text: String, keyboards: Keyboards, capsLock: Bool = false, keep: KeepList) -> (text: String, target: Script)? {
        let fix = Converter(pair: keyboards.pair).fix(text, capsLock: capsLock, isWord: Spelling.isWord)
        var out = fix.text, target = fix.target
        // "ezayak" is Franco; "lvpfh" is the Arabic keyboard. Trust the keyboard reading only when it gives real Arabic words.
        if Franco.looksLikeFranco(text), !(target == .arabic && allRealWords(out, .arabic)) {
            out = Franco.toArabic(text)
            target = .arabic
        }
        out = keep.restore(original: text, fixed: out)
        guard let target, out != text else { return nil }
        return (out, target)
    }

    private static func allRealWords(_ text: String, _ script: Script) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters.union(.symbols)) }
            .filter { !$0.isEmpty }
        return !words.isEmpty && words.allSatisfy { Spelling.isWord($0, script) == true }
    }

    static func script(of text: String) -> Script {
        text.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0xFB50...0xFEFF).contains($0.value) } ? .arabic : .latin
    }

    /// Selects the text just pasted (if nothing is selected) and, if it's still exactly the fix, pastes the original back.
    private func undo(_ previous: LastFix) async -> String? {
        guard Date().timeIntervalSince(previous.date) <= 10, previous.fixed.count <= 300 else { return nil }
        let selectedByUs = selectionIsEmpty()
        if selectedByUs {
            for _ in 0..<previous.fixed.count { press(CGKeyCode(kVK_LeftArrow), .maskShift) }
            try? await Task.sleep(for: .milliseconds(40))
        }
        guard previous.shouldUndo(current: await copySelection()) else {
            if selectedByUs { press(CGKeyCode(kVK_RightArrow), []) } // drop our selection, caret back where it was
            return nil
        }
        await put(previous.original)
        return previous.original
    }

    private func put(_ text: String) async {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.hasPrefix("com.adobe") == true {
            type(text) // Adobe text tools don't take a pasted replacement reliably
        } else {
            write(text)
            press(CGKeyCode(kVK_ANSI_V), .maskCommand)
            try? await Task.sleep(for: .milliseconds(500)) // let slow apps read the clipboard first
        }
    }

    private func waitForModifiersUp() async {
        let held: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        for _ in 0..<50 {
            if CGEventSource.flagsState(.combinedSessionState).intersection(held).isEmpty { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func selectionIsEmpty() -> Bool {
        var focused: CFTypeRef?, selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &selected) == .success
        else { return false }
        return (selected as? String)?.isEmpty == true
    }

    private func copySelection() async -> String? {
        let before = pasteboard.changeCount
        press(CGKeyCode(kVK_ANSI_C), .maskCommand)
        for _ in 0..<25 { // up to half a second, for slow apps
            try? await Task.sleep(for: .milliseconds(20))
            if pasteboard.changeCount != before {
                return pasteboard.string(forType: .string).flatMap { $0.isEmpty ? nil : $0 }
            }
        }
        return nil
    }

    private func snapshot() -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private func restore(_ items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }

    /// Marked so clipboard-history apps (Raycast, Paste, Maccy) skip it.
    private func write(_ text: String) {
        let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        let generated = NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, transient, generated], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: transient)
        pasteboard.setData(Data(), forType: generated)
    }

    private func press(_ key: CGKeyCode, _ flags: CGEventFlags) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }

    private func type(_ text: String) {
        let source = CGEventSource(stateID: .privateState)
        let units = Array(text.utf16)
        for start in stride(from: 0, to: units.count, by: 20) {
            var chunk = Array(units[start..<min(start + 20, units.count)])
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
                event?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
                event?.post(tap: .cghidEventTap)
            }
        }
    }
}
