import Foundation

/// A dotted version such as "1.2.0", "v1.2" or "1.2.0-beta". A pre-release sorts before its release.
public struct Version: Comparable, Sendable, CustomStringConvertible {
    let parts: [Int]
    let pre: String?

    public init?(_ string: String) {
        var s = Substring(string.trimmingCharacters(in: .whitespaces))
        if s.hasPrefix("v") || s.hasPrefix("V") { s = s.dropFirst() }
        let halves = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let core = halves.first, !core.isEmpty else { return nil }
        let nums = core.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard nums.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        parts = nums.map { $0! }
        let tag = halves.count > 1 ? String(halves[1]) : nil
        if let tag, tag.isEmpty { return nil }
        pre = tag
    }

    public var description: String {
        parts.map(String.init).joined(separator: ".") + (pre.map { "-" + $0 } ?? "")
    }

    private static func cmp(_ a: Version, _ b: Version) -> Int {
        for i in 0..<max(a.parts.count, b.parts.count) {
            let x = i < a.parts.count ? a.parts[i] : 0
            let y = i < b.parts.count ? b.parts[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        switch (a.pre, b.pre) {
        case (nil, nil): return 0
        case (nil, _): return 1
        case (_, nil): return -1
        case let (p?, q?):
            let order = p.compare(q, options: .numeric)
            return order == .orderedSame ? 0 : (order == .orderedAscending ? -1 : 1)
        }
    }

    public static func < (a: Version, b: Version) -> Bool { cmp(a, b) < 0 }
    public static func == (a: Version, b: Version) -> Bool { cmp(a, b) == 0 }
}

/// The few fields we read from GitHub's "latest release" JSON.
public struct ReleaseInfo: Sendable {
    public let version: Version
    public let url: URL?

    /// Returns nil for drafts, pre-releases, malformed JSON or an unparseable tag.
    public init?(json: Data) {
        struct Raw: Decodable { let tag_name: String; let draft: Bool?; let prerelease: Bool?; let html_url: String? }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: json),
              raw.draft != true, raw.prerelease != true,
              let v = Version(raw.tag_name) else { return nil }
        version = v
        url = raw.html_url.flatMap(URL.init(string:))
    }
}
