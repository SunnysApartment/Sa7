/// The word being typed right now, built from keystrokes. Holds at most one word, in memory only.
///
/// The keys . , ; ' / [ ] and backtick are not word ends: on the Arabic keyboard those keys are letters (ز و ك ط ظ ج د ذ),
/// so a word typed on the wrong keyboard would be cut in half.
public struct WordBuffer: Sendable {
    public static let maxLength = 40
    static let boundaries: Set<Character> = ["!", "?", "\"", ":", "(", ")", "،", "؛", "؟"]

    public private(set) var word = ""
    private var tooLong = false

    public init() {}

    /// Feeds typed characters. Returns the word a boundary just finished, if it has at least 2 letters.
    public mutating func type(_ text: String) -> String? {
        var finished: String?
        for c in text {
            if c.isWhitespace || Self.boundaries.contains(c) {
                if !tooLong, word.filter(\.isLetter).count >= 2 { finished = word }
                reset()
            } else if c.unicodeScalars.contains(where: { $0.properties.generalCategory == .control || $0.properties.generalCategory == .privateUse }) {
                reset() // arrows, Escape, Delete and other non-printing keys
            } else if !tooLong {
                word.append(c)
                if word.count > Self.maxLength { word = ""; tooLong = true }
            }
        }
        return finished
    }

    public mutating func backspace() {
        if !word.isEmpty { word.removeLast() }
    }

    public mutating func reset() {
        word = ""
        tooLong = false
    }
}
