import Carbon
import Testing
@testable import Sa7Core

// What each physical key types, as macOS's own layouts report it (Keyboards.type on this Mac), in US key order:
// number row, Q row, A row (with \ and `), Z row; unshifted then Shift. "∅" is a key that types nothing.
let usKeys = ["1 2 3 4 5 6 7 8 9 0 - = q w e r t y u i o p [ ] a s d f g h j k l ; ' \\ ` z x c v b n m , . /",
              "! @ # $ % ^ & * ( ) _ + Q W E R T Y U I O P { } A S D F G H J K L : \" | ~ Z X C V B N M < > ?"]
let frenchKeys = ["& é \" ' ( § è ! ç à ) - a z e r t y u i o p ∅ $ q s d f g h j k l m ù ∅ < w x c v b n , ; : =",
                  "1 2 3 4 5 6 7 8 9 0 ° _ A Z E R T Y U I O P ∅ * Q S D F G H J K L M % £ > W X C V B N ? . / +"]
let arabicPCKeys = ["١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩ ٠ - = ض ص ث ق ف غ ع ه خ ح ج د ش س ي ب ل ا ت ن م ك ط \\ ٫ ئ ء ؤ ر لا ى ة و ز ظ",
                    "! @ # $ ٪ ^ & * ) ( ـ + َ ً ُ ٌ لإ إ ‘ ÷ × ؛ < > ِ ٍ ] [ لأ أ ـ ، / : \" | ٬ ~ ْ } { لآ آ ’ , . ؟"]
/// Persian – Standard (ISIRI 9147 on the Mac).
let persianKeys = ["۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹ ۰ - = ض ص ث ق ف غ ع ه خ ح ج چ ش س ی ب ل ا ت ن م ک گ \\ ∅ ظ ط ز ر ذ د پ و . /",
                   "! ٬ ٫ ﷼ ٪ × ، * ) ( ـ + ْ ٌ ٍ ً ُ ِ َ ّ ] [ } { ؤ ئ ي إ أ آ ة » « : ؛ | ∅ ك ٓ ژ ٰ \u{200C} ٔ ء < > ؟"]
let urduKeys = ["۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹ ۰ - = ق و ع ر ت ے ئ ی ہ پ ُ َ ا س د ف گ ھ ج ک ل ؛ ' ِ ؀ ز ش چ ط ب ن م ، ۔ /",
                "! @ # $ ٪ ^ ٴ * ) ( _ + ْ ؤ ّ ڑ ٹ ٖ ء ٰ ۂ ٗ ٌ ً آ ص ڈ ∅ غ ح ض خ ∅ : \" ٍ ؔ ذ ژ ث ظ ∅ ں ∅ ٬ . ؟"]

/// Split on scalars: a mark after a space would otherwise join the space into one Character.
func layoutPair(_ latin: [String], _ other: [String]) -> LayoutPair {
    func keys(_ rows: [String]) -> [String] {
        rows.flatMap { $0.unicodeScalars.split(separator: " ").map { String(String.UnicodeScalarView($0)) } }
    }
    let latin = keys(latin), other = keys(other)
    precondition(latin.count == other.count, "tables must line up key for key")
    return LayoutPair(keys: zip(latin, other).filter { $0 != "∅" && $1 != "∅" }.map { (english: $0, arabic: $1) })
}

let persian = Converter(pair: layoutPair(usKeys, persianKeys))
let urdu = Converter(pair: layoutPair(usKeys, urduKeys))
let frenchArabic = Converter(pair: layoutPair(frenchKeys, arabicPCKeys))

@Test func persianRoundTrip() {
    #expect(persian.fix("sghl") == Fix(text: "سلام", target: .arabic))
    #expect(persian.fix("سلام") == Fix(text: "sghl", target: .latin))
    #expect(persian.fix("md]").text == "پیچ")
    #expect(persian.fix("Chgi").text == "ژاله", "ژ is Shift-C")
    #expect(persian.fix("۱۲۳") == Fix(text: "123", target: .latin), "Persian digits")
    let words: (String, Script) -> Bool? = { word, script in script == .arabic ? word == "سلام" : false }
    #expect(persian.fix("سلام sghl", isWord: words).text == "سلام سلام")
}

@Test func urduRoundTrip() {
    #expect(urdu.fix("pakstan") == Fix(text: "پاکستان", target: .arabic))
    #expect(urdu.fix("پاکستان").text == "pakstan")
    #expect(urdu.fix("Thik").text == "ٹھیک", "ٹ is Shift-T, ھ is H")
    #expect(urdu.fix("maN").text == "ماں")
    #expect(urdu.fix("ہے").text == "oy")
}

@Test func frenchAzertyAndArabic() {
    // AZERTY swaps A/Q and Z/W against QWERTY, so the Arabic ش (QWERTY A) is AZERTY's Q.
    #expect(frenchArabic.fix("qls") == Fix(text: "شمس", target: .arabic))
    #expect(frenchArabic.fix("شمس").text == "qls")
    #expect(frenchArabic.fix("zp").text == "صح")
    #expect(frenchArabic.fix("ù") == Fix(text: "ط", target: .arabic), "accented letters count as Latin")
    #expect(frenchArabic.fix("٢ف٢").text == "été")
    #expect(frenchArabic.fix("été").text == "٢ف٢")
    #expect(frenchArabic.fix("ÉTÉ").text == "٢ف٢", "all capitals, accents included, means Caps Lock was on")
    let words: (String, Script) -> Bool? = { word, script in script == .latin ? word == "bonjour" : word == "شمس" }
    #expect(frenchArabic.fix("شمس bonjour qls", isWord: words).text == "شمس bonjour شمس")
}

@Test func scriptDetection() {
    #expect(Converter.count("éèàçùÉœ", .latin) == 7)
    #expect(Converter.count("×÷", .latin) == 0)
    #expect(Converter.count("پچژگکیٹڈڑںےھ۱۲", .arabic) == 14)
    #expect(Converter.count("\u{0750}\u{08A0}\u{FB56}\u{FEFB}", .arabic) == 4, "supplement, extended-A, presentation forms")
    #expect(Converter.count("été", .arabic) == 0)
}

@Test func pickingLayouts() {
    typealias Source = (id: String, language: String)
    let enabled: [Source] = [("Translit", "ar-Latn"), ("AZERTY", "fr"), ("Persian", "fa"), ("US", "en"), ("Arabic", "ar")]
    func latin(inUse: String, _ sources: [Source] = enabled) -> String? {
        Keyboards.pick(sources, Keyboards.latinLanguages, language: \.language,
                       prefer: [{ $0.id == inUse }, { $0.language == "en" }])?.id
    }
    func other(inUse: String, last: String?) -> String? {
        Keyboards.pick(enabled, Keyboards.otherLanguages, language: \.language,
                       prefer: [{ $0.id == inUse }, { $0.id == last }])?.id
    }
    #expect(latin(inUse: "AZERTY") == "AZERTY")
    #expect(latin(inUse: "Persian") == "US", "English first when no Latin layout is in use")
    #expect(latin(inUse: "Persian", enabled.filter { $0.language != "en" }) == "AZERTY")
    #expect(other(inUse: "Arabic", last: "Persian") == "Arabic")
    #expect(other(inUse: "US", last: "Arabic") == "Arabic", "the one used last")
    #expect(other(inUse: "US", last: nil) == "Persian", "first turned on; ar-Latn is Latin, not Arabic")
}

@MainActor
@Test func spellingFollowsKeyboards() {
    Spelling.languages = ("fr", "fa")
    defer { Spelling.languages = ("en", "ar") }
    if let french = Spelling.isWord("bonjour", .latin) {
        #expect(french)
        #expect(Spelling.isWord("qls", .latin) == false)
    }
}

/// Every installed layout, turned on or not.
let installed: [TISInputSource] = {
    let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
    return TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
}()

func installedKeys(_ id: String) -> Data? {
    installed.first { Keyboards.id($0) == id }.flatMap(Keyboards.layoutData)
}

@MainActor // macOS aborts when two threads call the keyboard (TIS) API at once
@Test(.enabled(if: installedKeys("com.apple.keylayout.US") != nil && installedKeys("com.apple.keylayout.ArabicPC") != nil,
               "needs the built-in U.S. and Arabic – PC layouts"))
func installedLayoutsMakePairs() throws {
    let us = try #require(installedKeys("com.apple.keylayout.US"))
    let arabic = try #require(installedKeys("com.apple.keylayout.ArabicPC"))
    for language in ["fa", "ur", "fr"] {
        let sources = installed.filter { Keyboards.language($0) == language }
        for source in sources {
            guard let keys = Keyboards.layoutData(source) else { continue }
            let pair = language == "fr" ? Keyboards.layoutPair(keys, arabic) : Keyboards.layoutPair(us, keys)
            #expect(pair.toArabic.count > 20, "\(Keyboards.name(source))")
        }
        print("\(language):", sources.map(Keyboards.name))
    }
    if let keys = installedKeys("com.apple.keylayout.Persian-ISIRI2901") {
        #expect(Converter(pair: Keyboards.layoutPair(us, keys)).fix("sghl").text == "سلام")
    }
    if let keys = installedKeys("com.apple.keylayout.Urdu") {
        #expect(Converter(pair: Keyboards.layoutPair(us, keys)).fix("pakstan").text == "پاکستان")
    }
    if let keys = installedKeys("com.apple.keylayout.French") {
        #expect(Converter(pair: Keyboards.layoutPair(keys, arabic)).fix("qls").text == "شمس")
    }
}
