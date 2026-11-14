import AppKit

public enum Spelling {
    /// Dictionary language for each script. Set it from the chosen keyboards
    /// (`Keyboards.latinLanguage`, `Keyboards.otherLanguage`) so French or Persian words are checked in their own language.
    @MainActor public static var languages: (latin: String, arabic: String) = ("en", "ar")

    /// Whether macOS's own dictionary knows the word; nil when there's no dictionary for that language.
    @MainActor
    public static func isWord(_ word: String, _ script: Script) -> Bool? {
        let checker = NSSpellChecker.shared
        let language = script == .arabic ? languages.arabic : languages.latin
        guard checker.availableLanguages.contains(where: { $0.hasPrefix(language) }) else { return nil }
        guard !word.isEmpty else { return false }
        let miss = checker.checkSpelling(of: word, startingAt: 0, language: language, wrap: false,
                                         inSpellDocumentWithTag: 0, wordCount: nil)
        return miss.location == NSNotFound
    }
}
