import Carbon
import Foundation

/// The Latin-script keyboard (English or French) and the Arabic-script one (Arabic, Persian or Urdu) turned on
/// in System Settings, read straight from macOS so any layout (PC, Apple, QWERTY, AZERTY) works with the keys
/// the person actually has.
public struct Keyboards {
    /// The Latin-script side: English or French (named for the original English + Arabic pairing).
    public let english: TISInputSource
    /// The Arabic-script side: Arabic, Persian or Urdu.
    public let arabic: TISInputSource
    public let pair: LayoutPair
    /// Two-letter language codes of the chosen layouts: "en" or "fr", and "ar", "fa" or "ur".
    public let latinLanguage: String
    public let otherLanguage: String

    public static let latinLanguages = ["en", "fr"]
    public static let otherLanguages = ["ar", "fa", "ur"]
    static let lastOtherKey = "Sa7LastArabicScriptKeyboard"

    public var summary: String { "\(Self.name(english)) + \(Self.name(arabic))" }

    /// Prefers the layouts in use right now when several are turned on; otherwise English before French,
    /// and the Arabic-script layout used last before the first one turned on.
    public static func current() -> Keyboards? {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return nil }
        let inUse = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        let defaults = UserDefaults.standard
        if let inUse, let language = language(inUse), otherLanguages.contains(language) {
            defaults.set(id(inUse), forKey: lastOtherKey)
        }
        let lastOther = defaults.string(forKey: lastOtherKey)
        let isInUse = { (source: TISInputSource) in inUse.map { CFEqual(source, $0) } ?? false }

        guard let english = pick(list, latinLanguages, language: language, prefer: [isInUse, { language($0) == "en" }]),
              let arabic = pick(list, otherLanguages, language: language, prefer: [isInUse, { id($0) == lastOther }]),
              let latinLanguage = language(english), let otherLanguage = language(arabic),
              let englishKeys = layoutData(english), let arabicKeys = layoutData(arabic) else { return nil }
        return Keyboards(english: english, arabic: arabic, pair: layoutPair(englishKeys, arabicKeys),
                         latinLanguage: latinLanguage, otherLanguage: otherLanguage)
    }

    /// The first source in one of `languages` that meets the earliest preference, else the first one at all.
    static func pick<Source>(_ sources: [Source], _ languages: [String], language: (Source) -> String?,
                             prefer: [(Source) -> Bool]) -> Source? {
        let matches = sources.filter { language($0).map(languages.contains) == true }
        return prefer.lazy.compactMap { matches.first(where: $0) }.first ?? matches.first
    }

    /// What every physical key types on the two layouts, unshifted and with Shift.
    static func layoutPair(_ latinKeys: Data, _ otherKeys: Data) -> LayoutPair {
        var keys: [(english: String, arabic: String)] = []
        for code in 0...50 where ![36, 48, 49].contains(code) { // skip Return, Tab, Space
            for shift in [false, true] {
                if let e = type(code, shift: shift, latinKeys), let a = type(code, shift: shift, otherKeys) {
                    keys.append((e, a))
                }
            }
        }
        return LayoutPair(keys: keys)
    }

    public func select(_ script: Script) {
        TISSelectInputSource(script == .arabic ? arabic : english)
    }

    /// The label printed on a key, from the person's English layout (for showing shortcuts).
    public static func keyName(_ code: Int) -> String {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let data = layoutData(source),
              let name = type(code, shift: false, data)?.uppercased(),
              !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "#\(code)" }
        return name
    }

    static func type(_ code: Int, shift: Bool, _ layout: Data) -> String? {
        var deadKeys: UInt32 = 0, length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let modifiers: UInt32 = shift ? UInt32(shiftKey >> 8) & 0xFF : 0
        let status = layout.withUnsafeBytes { raw in
            UCKeyTranslate(raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!, UInt16(code),
                           UInt16(kUCKeyActionDown), modifiers, UInt32(LMGetKbdType()),
                           OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: chars, count: length)
        return text.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value != 127 } ? text : nil
    }

    /// The layout's main language, matched exactly ("fr", "fa") so transliteration layouts like "ar-Latn" don't count.
    static func language(_ source: TISInputSource) -> String? {
        (property(source, kTISPropertyInputSourceLanguages) as [String]?)?.first
    }

    static func id(_ source: TISInputSource) -> String? {
        property(source, kTISPropertyInputSourceID) as String?
    }

    static func layoutData(_ source: TISInputSource) -> Data? {
        property(source, kTISPropertyUnicodeKeyLayoutData) as Data?
    }

    static func name(_ source: TISInputSource) -> String {
        property(source, kTISPropertyLocalizedName) as String? ?? "?"
    }

    static func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? T
    }
}
