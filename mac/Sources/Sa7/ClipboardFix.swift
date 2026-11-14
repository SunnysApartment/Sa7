import AppKit

/// "Fix what's on the clipboard" for apps that don't allow selecting text: converts the plain-text
/// clipboard in place. Other clipboard types are dropped; the result is normal (non-transient) text
/// so the user can paste it.
@MainActor
enum ClipboardFix {
    static func run(_ convert: (String) -> String?) -> String? {
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string), let fixed = convert(text), fixed != text else { return nil }
        pb.clearContents()
        pb.setString(fixed, forType: .string)
        return fixed
    }
}
