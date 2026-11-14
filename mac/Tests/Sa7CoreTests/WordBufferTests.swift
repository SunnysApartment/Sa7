import Testing
@testable import Sa7Core

@Test func typingFinishesWordsAtSpaces() {
    var buffer = WordBuffer()
    #expect(buffer.type("h") == nil)
    #expect(buffer.type("ello") == nil)
    #expect(buffer.word == "hello")
    #expect(buffer.type(" ") == "hello")
    #expect(buffer.word.isEmpty)
    #expect(buffer.type(" ") == nil, "a second space finishes nothing")
}

@Test func returnAndTabFinishWords() {
    var buffer = WordBuffer()
    _ = buffer.type("lvpfh")
    #expect(buffer.type("\r") == "lvpfh")
    _ = buffer.type("اثممخ")
    #expect(buffer.type("\t") == "اثممخ")
}

@Test func backspaceRemovesLastCharacter() {
    var buffer = WordBuffer()
    _ = buffer.type("helxx")
    buffer.backspace()
    buffer.backspace()
    _ = buffer.type("lo")
    #expect(buffer.type(" ") == "hello")
    buffer.backspace() // on an empty buffer
    #expect(buffer.word.isEmpty)
}

@Test func punctuationEndsWordsIncludingArabic() {
    var buffer = WordBuffer()
    _ = buffer.type("مرحبا")
    #expect(buffer.type("،") == "مرحبا")
    _ = buffer.type("كيف")
    #expect(buffer.type("؟") == "كيف")
    _ = buffer.type("تمام")
    #expect(buffer.type("؛") == "تمام")
    #expect(buffer.type("wow!") == "wow")
}

@Test func keysThatAreArabicLettersStayInTheWord() {
    var buffer = WordBuffer()
    // "كتب" typed on the English keyboard: ; is ك
    #expect(buffer.type(";jf ") == ";jf")
    // the period key is ز on the Arabic keyboard, so it stays with the word
    #expect(buffer.type("hello. ") == "hello.")
}

@Test func shortWordsAreNotReported() {
    var buffer = WordBuffer()
    #expect(buffer.type("a ") == nil)
    #expect(buffer.type("12 ") == nil, "digits are not letters")
    #expect(buffer.type("في ") == "في")
}

@Test func resetAndNonPrintingKeysClearTheWord() {
    var buffer = WordBuffer()
    _ = buffer.type("hel")
    buffer.reset()
    #expect(buffer.type("lo ") == "lo")
    _ = buffer.type("hel")
    _ = buffer.type("\u{F702}") // left arrow
    #expect(buffer.type("lo ") == "lo")
    _ = buffer.type("hel")
    _ = buffer.type("\u{1B}") // Escape
    #expect(buffer.word.isEmpty)
}

@Test func overlongWordsAreIgnoredUntilBoundary() {
    var buffer = WordBuffer()
    let long = String(repeating: "a", count: WordBuffer.maxLength + 1)
    #expect(buffer.type(long) == nil)
    #expect(buffer.word.isEmpty, "nothing kept once too long")
    _ = buffer.type("bc")
    #expect(buffer.type(" ") == nil)
    #expect(buffer.type("ok ") == "ok", "next word works again")
    let exact = String(repeating: "a", count: WordBuffer.maxLength)
    #expect(buffer.type(exact + " ") == exact)
}
