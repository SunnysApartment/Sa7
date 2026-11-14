import Foundation

/// Words that must never be flipped (names, brands, "Sa7"...). Matching ignores case.
public struct KeepList: Sendable {
    private let words: Set<String>

    public init(_ words: [String]) {
        self.words = Set(words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
    }

    public var isEmpty: Bool { words.isEmpty }

    /// After a conversion, puts back every original word that is on the list.
    /// `original` and `fixed` line up word for word; if their whitespace runs don't, `fixed` is returned unchanged.
    public func restore(original: String, fixed: String) -> String {
        guard !isEmpty else { return fixed }
        let a = Converter.runs(original), b = Converter.runs(fixed)
        guard a.count == b.count, zip(a, b).allSatisfy({ isSpace($0) == isSpace($1) }) else { return fixed }
        return zip(a, b).map { o, f in
            let core = Converter.core(String(o)).lowercased()
            return !isSpace(o) && words.contains(core) ? String(o) : String(f)
        }.joined()
    }

    /// Settings field text: one word per line or comma-separated (also the Arabic comma).
    public static func parse(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == "،" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func isSpace(_ run: Substring) -> Bool { run.first?.isWhitespace ?? false }
}
