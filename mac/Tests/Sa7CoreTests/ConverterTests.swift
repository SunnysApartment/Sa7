import Testing
@testable import Sa7Core

/// Arabic PC keys as macOS reports them (a subset of the Shift layer is enough here).
let arabicPC: LayoutPair = {
    let english = Array("qwertyuiop[]asdfghjkl;'`zxcvbnm,./").map(String.init)
    let arabic = ["ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح", "ج", "د",
                  "ش", "س", "ي", "ب", "ل", "ا", "ت", "ن", "م", "ك", "ط", "ذ",
                  "ئ", "ء", "ؤ", "ر", "لا", "ى", "ة", "و", "ز", "ظ"]
    let shifted: [(String, String)] = [("T", "لإ"), ("G", "لأ"), ("H", "أ"), ("Y", "إ"), ("B", "لآ"),
                                       ("N", "آ"), ("K", "،"), ("P", "؛"), ("?", "؟"), ("~", "\u{0651}")]
    return LayoutPair(keys: Array(zip(english, arabic)) + shifted)
}()
let converter = Converter(pair: arabicPC)

@Test func englishKeysToArabic() {
    #expect(converter.fix("lvpfh") == Fix(text: "مرحبا", target: .arabic))
    #expect(converter.fix("hgsghl ugd;l").text == "السلام عليكم")
    #expect(converter.fix("wp?").text == "صح؟")
}

@Test func arabicKeysToEnglish() {
    #expect(converter.fix("اثممخ") == Fix(text: "hello", target: .latin))
    #expect(converter.fix("لا").text == "b", "lam-alef is one key")
    #expect(converter.fix("شّ").text == "a~", "shadda maps on its own key")
}

@Test func shiftAndCapsLock() {
    #expect(converter.fix("Hkh").text == "أنا")
    #expect(converter.fix("LVPFH").text == "مرحبا", "all capitals means Caps Lock was on")
    #expect(converter.fix("LVPFH", capsLock: true).text == "مرحبا")
}

@Test func nothingToFix() {
    #expect(converter.fix("123").target == nil)
    #expect(converter.fix("").target == nil)
}

@Test func mixedTextFixesOnlyWrongWords() {
    let english: Set = ["hello", "google"], arabic: Set = ["مرحبا", "السلام"]
    let dictionary: (String, Script) -> Bool? = { word, script in
        script == .latin ? english.contains(word) : arabic.contains(word)
    }
    #expect(converter.fix("مرحبا lvpfhK google", isWord: dictionary)
            == Fix(text: "مرحبا مرحبا، google", target: .arabic))
    // Nothing recognisable: fall back to flipping toward the less-used script.
    #expect(converter.fix("مم lvp", isWord: dictionary).text == "مم مرح")
    #expect(converter.fix("مرحبا lvpfh", isWord: { _, _ in nil }).target != nil)
}

@MainActor
@Test func macDictionary() throws {
    #expect(Spelling.isWord("hello", .latin) == true)
    #expect(Spelling.isWord("lvpfh", .latin) == false)
    if let arabic = Spelling.isWord("مرحبا", .arabic) { #expect(arabic) }
}

@MainActor // macOS aborts when two threads call the keyboard (TIS) API at once
@Test(.enabled(if: Keyboards.current() != nil, "needs an English and an Arabic keyboard turned on"))
func keyboardsOnThisMac() throws {
    let keyboards = try #require(Keyboards.current())
    let converter = Converter(pair: keyboards.pair)
    print("Keyboards found:", keyboards.summary, ["lvpfh", "hgsghl ugd;l", "اثممخ"].map { converter.fix($0).text })
    #expect(converter.fix("lvpfh").target == .arabic)
}
