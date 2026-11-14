import Foundation
import Testing
@testable import Sa7Core

@Test func versionParsing() {
    #expect(Version("1.2.0")?.description == "1.2.0")
    #expect(Version("v1.2")?.description == "1.2")
    #expect(Version("1.2.0-beta")?.description == "1.2.0-beta")
    #expect(Version("") == nil)
    #expect(Version("abc") == nil)
    #expect(Version("1..2") == nil)
    #expect(Version("1.2-") == nil)
}

@Test func versionOrdering() {
    #expect(Version("1.1.1")! < Version("1.2.0")!)
    #expect(Version("1.9")! < Version("1.10")!)
    #expect(Version("1.2")! == Version("1.2.0")!)
    #expect(Version("v2.0")! > Version("1.99.99")!)
    #expect(Version("1.2.0-beta")! < Version("1.2.0")!)
    #expect(Version("1.2.0-beta.2")! < Version("1.2.0-beta.10")!)
    #expect(Version("1.1.9")! < Version("1.2.0-beta")!)
}

private func json(_ s: String) -> Data { Data(s.utf8) }

@Test func releaseInfoParsing() {
    // Trimmed from a real api.github.com/repos/SunnysApartment/Sa7/releases/latest response.
    let sample = #"{"html_url":"https://github.com/SunnysApartment/Sa7/releases/tag/v1.1.1","tag_name":"v1.1.1","name":"Sa7 1.1.1","draft":false,"prerelease":false,"assets":[]}"#
    let info = ReleaseInfo(json: json(sample))
    #expect(info?.version == Version("1.1.1"))
    #expect(info?.url?.absoluteString == "https://github.com/SunnysApartment/Sa7/releases/tag/v1.1.1")
    #expect(ReleaseInfo(json: json(#"{"tag_name":"v2.0","draft":true,"prerelease":false}"#)) == nil)
    #expect(ReleaseInfo(json: json(#"{"tag_name":"v2.0","draft":false,"prerelease":true}"#)) == nil)
    #expect(ReleaseInfo(json: json(#"{"message":"Not Found"}"#)) == nil)
    #expect(ReleaseInfo(json: json("nope")) == nil)
}
