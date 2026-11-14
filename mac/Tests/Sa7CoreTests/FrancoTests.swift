import Testing
@testable import Sa7Core

// Mirrors sa7-site/franco.test.js: keep the cases in sync.

@Test func francoEverydayPhrases() {
    #expect(Franco.toArabic("ezayak 3amel eh") == "ازيك عامل ايه")
    #expect(Franco.toArabic("ana 2olt keda") == "انا قلت كده")
    #expect(Franco.toArabic("mesh 3aref") == "مش عارف")
    #expect(Franco.toArabic("el sa3a kam") == "الساعة كام")
    #expect(Franco.toArabic("yalla bina") == "يلا بينا")
    #expect(Franco.toArabic("sabah el 5eer") == "صباح الخير")
    #expect(Franco.toArabic("ana 3ayez akol") == "انا عايز اكل")
    #expect(Franco.toArabic("inshallah") == "ان شاء الله")
}

/// Single words through the rules, not the dictionary.
@Test(arguments: [
    ("7abibi", "حبيبي"), ("3amel", "عامل"), ("wa7ed", "واحد"), ("ragel", "راجل"), ("mashe", "ماشي"),
    ("kalam", "كلام"), ("tamam", "تمام"), ("beta3", "بتاع"), ("ta3ban", "تعبان"), ("salam", "سلام"),
    ("sa3a", "ساعة"), ("sa3ah", "ساعة"), ("bokra", "بكرة"), ("7elwa", "حلوة"), ("kelma", "كلمة"), ("fekra", "فكرة"),
    ("3arabeya", "عربية"), ("donya", "دنيا"), ("a7la", "احلى"), ("aktar", "اكتر"), ("a7san", "احسن"),
    ("momken", "ممكن"), ("2olt", "قلت"), ("yom", "يوم"), ("3ando", "عنده"), ("3andaha", "عندها"), ("marra", "مرة"),
    ("ezay", "ازاي"), ("shay", "شاي"), ("leh", "ليه"), ("feeh", "فيه"), ("ba7eb", "بحب"), ("ma3ak", "معاك"),
    ("2ahwa", "قهوة"), ("7'adt", "خدت"), ("3'aly", "غالي"), ("9aba7", "صباح"), ("6ayeb", "طايب"), ("3ady", "عادي"),
    ("ibn", "ابن"),
])
func francoWordRules(input: String, expected: String) {
    #expect(Franco.toArabic(input) == expected)
}

@Test func francoArticles() {
    #expect(Franco.toArabic("elbeit") == "البيت")
    #expect(Franco.toArabic("el-sa3a") == "الساعة")
    #expect(Franco.toArabic("fel beit") == "في البيت")
    #expect(Franco.toArabic("elly") == "اللي", "dictionary beats the article rule")
}

@Test func francoKeepsCasePunctuationAndSpacing() {
    #expect(Franco.toArabic("El Sa3a KAM") == "الساعة كام")
    #expect(Franco.toArabic("sa7?") == "صح?")
    #expect(Franco.toArabic("(mesh 3aref)") == "(مش عارف)")
    #expect(Franco.toArabic("ana,  enta!\nmesh keda") == "انا,  انت!\nمش كده")
}

@Test func francoPassesThroughNonLatin() {
    #expect(Franco.toArabic("مرحبا يا sa7") == "مرحبا يا صح")
    #expect(Franco.toArabic("123 456") == "123 456")
    #expect(Franco.toArabic("") == "")
    #expect(Franco.toArabic("constructor") == "كنستروكتر", "same output as the JS port, where this is an Object key")
}

@Test func looksLikeFranco() {
    for s in ["ezayak 3amel eh", "ana 2olt keda", "sa7", "mesh 3aref", "el sa3a kam", "yalla bina", "inshallah", "7abibi"] {
        #expect(Franco.looksLikeFranco(s), "\(s)")
    }
    for s in ["hello world", "lvpfh", "hgsghl ugd;l", "I love mesh networks", "Ana is here", "the 3rd floor",
              "send me the mp3", "مرحبا", "123", ""] {
        #expect(!Franco.looksLikeFranco(s), "\(s)")
    }
}
