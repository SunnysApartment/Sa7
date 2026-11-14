import Foundation

/// The last fix Sa7 made, kept so a second ⌃K can undo it.
///
/// Intended use in the Fixer: after a successful fix, store a `LastFix`. On the next press,
/// if a `LastFix` exists and nothing is selected, select backwards `fixed.count` characters
/// (⇧← repeated, or ⌥⇧← per word) and read them. If `shouldUndo(current:)` is true, paste
/// `original` and clear the `LastFix`, so a third press fixes again. Otherwise clear it and fix as usual.
public struct LastFix: Equatable, Sendable {
    public let original: String
    public let fixed: String
    public let date: Date
    /// Whether the user had selected text (true) or Sa7 selected the last word itself (false).
    public let wasSelection: Bool

    public init(original: String, fixed: String, date: Date = Date(), wasSelection: Bool) {
        self.original = original
        self.fixed = fixed
        self.date = date
        self.wasSelection = wasSelection
    }

    /// True within `window` seconds of the fix when `current` (what Sa7 just read; nil if nothing) is still `fixed`.
    public func shouldUndo(current: String?, now: Date = Date(), window: TimeInterval = 10) -> Bool {
        let age = now.timeIntervalSince(date)
        return current == fixed && age >= 0 && age <= window
    }
}
