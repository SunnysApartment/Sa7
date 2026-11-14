import Testing
import Foundation
@testable import Sa7Core

private let t0 = Date(timeIntervalSince1970: 1_000)
private let fix = LastFix(original: "lvpfh", fixed: "مرحبا", date: t0, wasSelection: true)

@Test func undoWithinWindow() {
    #expect(fix.shouldUndo(current: "مرحبا", now: t0.addingTimeInterval(3)))
}

@Test func undoWindowBoundaries() {
    #expect(fix.shouldUndo(current: "مرحبا", now: t0.addingTimeInterval(10)))
    #expect(!fix.shouldUndo(current: "مرحبا", now: t0.addingTimeInterval(10.01)))
    #expect(fix.shouldUndo(current: "مرحبا", now: t0.addingTimeInterval(20), window: 30))
    #expect(!fix.shouldUndo(current: "مرحبا", now: t0.addingTimeInterval(-1)))
}

@Test func undoNeedsMatchingText() {
    #expect(!fix.shouldUndo(current: "مرحب", now: t0))
    #expect(!fix.shouldUndo(current: nil, now: t0))
}
