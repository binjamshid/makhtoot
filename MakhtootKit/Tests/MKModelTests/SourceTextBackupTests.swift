import Foundation
import Testing
@testable import MKModel

/// WS-02 packet §5 task 5 accept criterion: backup survives scene JSON
/// round-trip byte-identically for the string "الله". §6 Arabic-correctness
/// notes: exact codepoint sequence including tashkeel, ZWJ/ZWNJ, and
/// Arabic-Indic digits must round-trip byte-identically.
@Suite("MKSourceTextBackup")
struct SourceTextBackupTests {
    @Test(arguments: [
        "الله",
        "لا",
        "شَدَّةٌ وفَتْحَةٌ",
        "عام ٢٠٢٦ / 2026",
        "أحمد\u{200D}", // trailing user-typed ZWJ
    ])
    func sourceStringRoundTripsByteIdentically(_ text: String) throws {
        let backup = MKSourceTextBackup(sourceString: text, style: .default)
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(MKSourceTextBackup.self, from: data)
        #expect(decoded.sourceString == text)
        #expect(decoded.sourceString.unicodeScalars.elementsEqual(text.unicodeScalars))
    }

    @Test func contentHashDetectsTamperingButNotHonestDecode() throws {
        let backup = MKSourceTextBackup(sourceString: "الله", style: .default)
        #expect(backup.contentHash == backup.recomputedHash()) // INV-4

        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(MKSourceTextBackup.self, from: data)
        #expect(decoded.contentHash == decoded.recomputedHash())
        #expect(decoded.contentHash == backup.contentHash)

        var tampered = decoded
        tampered.sourceString = "غير ذلك" // something else
        #expect(tampered.contentHash != tampered.recomputedHash())
    }

    @Test func embeddedInsideArrangedNodeSurvivesFullSceneRoundTrip() throws {
        let scene = FixtureScenes.arrangedLaScene()
        let data = try MKSceneCodec.encode(scene)
        let decoded = try MKSceneCodec.decode(data)
        guard case .arranged(let arranged) = decoded.nodes[0] else {
            Issue.record("expected arranged node")
            return
        }
        #expect(arranged.composition.sourceBackup.sourceString == "لا")
    }
}
