import Foundation
import Testing

@testable import Heeler

@Suite("Oracle identity and icons")
struct OracleIdentityTests {
    private let known: Set<String> = ["studio-labs", "studio", "nova", "ar", "scout"]

    @Test func normalizesOracleAndSoulSuffixes() {
        #expect(OracleIdentity.normalized(" Nova-Oracle ") == "nova")
        #expect(OracleIdentity.normalized("scout-soul") == "scout")
        #expect(OracleIdentity.normalized("heeler") == "heeler")
    }

    @Test func agentNameWinsOverFolder() {
        let name = OracleIdentity.resolve(
            agentName: "nova", cwd: "/src/org/scout-oracle",
            workspaceLabel: "laris-team", known: known)
        #expect(name == "nova")
    }

    @Test func fallsBackToRepoFolder() {
        #expect(OracleIdentity.resolve(
            agentName: "claude", cwd: "/src/org/scout-oracle",
            workspaceLabel: nil, known: known) == "scout")
        #expect(OracleIdentity.resolve(
            agentName: nil, cwd: "/x/wt/scout-soul", workspaceLabel: nil, known: known) == "scout")
    }

    @Test func worktreeFolderMatchesOracleInsideSlugAndDate() {
        let cwd = "/src/app/wt/app-layout-studio-labs-issue4-18nov-wed2026"
        #expect(OracleIdentity.resolve(
            agentName: "heeler-layout", cwd: cwd, workspaceLabel: nil, known: known) == "studio-labs")
    }

    @Test func fallsBackToWorkspaceLabelLast() {
        #expect(OracleIdentity.resolve(
            agentName: "agent", cwd: "/tmp", workspaceLabel: "nova-oracle", known: known) == "nova")
    }

    @Test func shortOracleNamesDoNotMatchInsideFolders() {
        #expect(OracleIdentity.resolve(
            agentName: nil, cwd: "/x/ar-something-else-ar", workspaceLabel: nil, known: known) == nil)
        #expect(OracleIdentity.resolve(
            agentName: "ar", cwd: nil, workspaceLabel: nil, known: known) == "ar")
    }

    @Test func noKnownOraclesResolvesNothing() {
        #expect(OracleIdentity.resolve(
            agentName: "nova", cwd: "/x/nova-oracle", workspaceLabel: "nova", known: []) == nil)
    }

    @Test func fallbackIsStableMonogramOrEmoji() {
        let a = OracleIcon.fallback(name: "scout")
        let b = OracleIcon.fallback(name: "scout")
        #expect(a == b)
        #expect(a.face == .glyph("S", hue: OracleIcon.hue(for: "scout")))
        #expect(OracleIcon.fallback(name: "studio-labs").face
            == .glyph("🏮", hue: OracleIcon.hue(for: "studio-labs")))
        #expect(OracleIcon.hue(for: "scout") != OracleIcon.hue(for: "nova"))
        #expect((0..<1).contains(OracleIcon.hue(for: "anything")))
        #expect(OracleIcon.monogram(for: "") == "?")
    }

    @Test func makeUsesPictureWhenPresent() {
        let png = Data([1, 2, 3])
        #expect(OracleIcon.make(name: "nova", pictures: ["nova": png]).face == .picture(png))
        #expect(OracleIcon.make(name: "nova", pictures: [:]).face
            == .glyph("N", hue: OracleIcon.hue(for: "nova")))
    }

    @Test func decodesBundleAndRejectsBadOnes() throws {
        let good = try JSONSerialization.data(withJSONObject: [
            "v": 1, "icons": ["nova": Data([9, 8]).base64EncodedString(), "bad": "!!!"],
        ])
        #expect(OracleIconBundle.decode(good) == ["nova": Data([9, 8])])
        #expect(OracleIconBundle.decode(nil).isEmpty)
        #expect(OracleIconBundle.decode(Data("{}".utf8)).isEmpty)
        let wrong = try JSONSerialization.data(withJSONObject: ["v": 2, "icons": [:] as [String: String]])
        #expect(OracleIconBundle.decode(wrong).isEmpty)
    }
}
