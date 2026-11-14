import Foundation

public enum Script: Sendable {
    case latin, arabic
    public var other: Script { self == .latin ? .arabic : .latin }
}

/// What each physical key types on the Latin-script layout (English, French) and on the Arabic-script one
/// (Arabic, Persian, Urdu). The names say English/Arabic for the original pairing.
public struct LayoutPair: Sendable {
    public let toArabic: [String: String]
    public let toEnglish: [String: String]

    /// Keys in order; when two keys give the same character, the first one wins.
    public init(keys: [(english: String, arabic: String)]) {
        var toArabic: [String: String] = [:], toEnglish: [String: String] = [:]
        for key in keys where key.english != key.arabic {
            if toArabic[key.english] == nil { toArabic[key.english] = key.arabic }
            if toEnglish[key.arabic] == nil { toEnglish[key.arabic] = key.english }
        }
        self.toArabic = toArabic
        self.toEnglish = toEnglish
    }
}

public struct Fix: Equatable, Sendable {
    public let text: String
    /// The script the text is in after fixing; nil when nothing needed fixing.
    public let target: Script?
}

public struct Converter: Sendable {
    public let pair: LayoutPair

    public init(pair: LayoutPair) { self.pair = pair }

    /// `isWord` says whether a word is real in a language, or nil when it can't tell.
    /// Without it, or when it can't decide, the whole text flips toward the less-used script.
    public func fix(_ text: String, capsLock: Bool = false, isWord: ((String, Script) -> Bool?)? = nil) -> Fix {
        let latin = Self.count(text, .latin), arabic = Self.count(text, .arabic)
        if latin > 0, arabic > 0, let isWord, let fixed = fixWords(text, capsLock: capsLock, isWord: isWord) {
            return fixed
        }
        let from: Script = latin > arabic ? .latin : .arabic
        let out = convert(text, from: from, capsLock: capsLock)
        return Fix(text: out, target: out == text ? nil : from.other)
    }

    /// Mixed text: change only the words that are gibberish now and real words once converted.
    func fixWords(_ text: String, capsLock: Bool, isWord: (String, Script) -> Bool?) -> Fix? {
        var out = "", lastFixed: Script?
        for token in Self.runs(text) {
            let word = String(token)
            let latin = Self.count(word, .latin), arabic = Self.count(word, .arabic)
            guard (latin > 0) != (arabic > 0) else { out += word; continue }
            let from: Script = latin > 0 ? .latin : .arabic
            let candidate = convert(word, from: from, capsLock: capsLock)
            guard let realNow = isWord(Self.core(word), from),
                  let realAfter = isWord(Self.core(candidate), from.other) else { return nil }
            if !realNow && realAfter {
                out += candidate
                lastFixed = from.other
            } else {
                out += word
            }
        }
        // The last fixed word is what the person was typing, so its language is the one to switch to.
        return lastFixed.map { Fix(text: out, target: $0) }
    }

    func convert(_ text: String, from: Script, capsLock: Bool) -> String {
        from == .latin
            ? Self.map(Self.undoCaps(text, capsLock: capsLock), pair.toArabic)
            : Self.map(text, pair.toEnglish)
    }

    /// Caps Lock makes letters look shifted when they weren't. All capitals with Caps Lock
    /// already off means it was on while typing.
    static func undoCaps(_ text: String, capsLock: Bool) -> String {
        if capsLock { // strings, not Characters: "ß".uppercased() is two letters
            return text.map { c in
                guard isLatin(c) else { return String(c) }
                return c.isUppercase ? c.lowercased() : c.uppercased()
            }.joined()
        }
        let letters = text.filter { isLatin($0) }
        return letters.count >= 2 && letters.allSatisfy(\.isUppercase) ? text.lowercased() : text
    }

    /// Works on Unicode scalars so Arabic marks (shadda, harakat) map key by key; two-scalar keys like لا match first.
    static func map(_ text: String, _ table: [String: String]) -> String {
        let scalars = Array(text.unicodeScalars)
        var out = "", i = 0
        while i < scalars.count {
            if i + 1 < scalars.count, let both = table[string(scalars[i], scalars[i + 1])] {
                out += both
                i += 2
            } else {
                out += table[string(scalars[i])] ?? string(scalars[i])
                i += 1
            }
        }
        return out
    }

    static func string(_ scalars: Unicode.Scalar...) -> String {
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }

    static func count(_ text: String, _ script: Script) -> Int {
        text.unicodeScalars.filter { script == .latin ? isLatin($0) : isArabic($0) }.count
    }

    /// Latin letters, accented ones too (é è à ç ù).
    static func isLatin(_ s: Unicode.Scalar) -> Bool {
        s.properties.isAlphabetic && (s.isASCII || (0x00C0...0x024F).contains(s.value) || (0x1E00...0x1EFF).contains(s.value))
    }

    static func isLatin(_ c: Character) -> Bool { c.unicodeScalars.first.map(isLatin) ?? false }

    /// Arabic script as Arabic, Persian and Urdu write it, presentation forms included.
    static let arabicBlocks: [ClosedRange<UInt32>] = [0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF,
                                                      0xFB50...0xFDFF, 0xFE70...0xFEFF]

    static func isArabic(_ s: Unicode.Scalar) -> Bool { arabicBlocks.contains { $0.contains(s.value) } }

    /// Alternating runs of whitespace and non-whitespace, so joining them gives back the text.
    static func runs(_ text: String) -> [Substring] {
        var result: [Substring] = [], start = text.startIndex
        for i in text.indices where i != start && text[i].isWhitespace != text[text.index(before: i)].isWhitespace {
            result.append(text[start..<i])
            start = i
        }
        if start < text.endIndex { result.append(text[start...]) }
        return result
    }

    static func core(_ word: String) -> String {
        word.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
    }
}
