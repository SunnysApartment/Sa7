import Testing
@testable import Sa7Core

@Test func keepListRestoresListedWordsOnly() {
    let keep = KeepList(["Sa7", "  khaled "])
    #expect(keep.restore(original: "Sa7, lvpfh", fixed: "سا7، مرحبا") == "Sa7, مرحبا")
    #expect(keep.restore(original: "KHALED! hi", fixed: "xxx! yy") == "KHALED! yy")
}

@Test func keepListKeepsWhitespaceRuns() {
    let keep = KeepList(["sa7"])
    #expect(keep.restore(original: "a  sa7\n\nb", fixed: "x  yyy\n\nz") == "x  sa7\n\nz")
    #expect(keep.restore(original: " sa7 ", fixed: " yyy ") == " sa7 ")
}

@Test func keepListMisalignedReturnsFixed() {
    let keep = KeepList(["sa7"])
    #expect(keep.restore(original: "sa7 a", fixed: "yyyb") == "yyyb")
    #expect(keep.restore(original: "sa7 a", fixed: " yyy") == " yyy")
}

@Test func keepListEmptyAndPunctuationOnly() {
    #expect(KeepList([" ", ""]).isEmpty)
    let keep = KeepList(["sa7"])
    #expect(!keep.isEmpty)
    #expect(keep.restore(original: "?? sa7", fixed: "؟؟ yyy") == "؟؟ sa7")
}

@Test func keepListParse() {
    #expect(KeepList.parse("Sa7, Apple\n\n  Khaled  ,\nNike،Adidas") == ["Sa7", "Apple", "Khaled", "Nike", "Adidas"])
    #expect(KeepList.parse(" \n , ").isEmpty)
}
