import Foundation
import Testing
@testable import MKFonts

/// T14 AC: valid ttf/otf/ttc/variable accepted; woff/woff2 rejected with
/// the specific Arabic error; truncated file rejected; format detection is
/// exercised against REAL bundled font bytes (not synthetic fixtures) so a
/// false pass can't hide behind a hand-rolled minimal sfnt.
@Suite("MKFontValidator ، T14")
struct MKFontValidatorTests {
    private func realFontData() throws -> Data {
        let index = BundledFontIndex()
        let loaded = try index.loadAll()
        let amiri = try #require(loaded.first { $0.record.fontID == "amiri" })
        let face = try #require(amiri.record.faces.first)
        return try Data(contentsOf: face.fileURL)
    }

    @Test func acceptsRealTTF() throws {
        let data = try realFontData()
        let validator = MKFontValidator()
        switch validator.validate(data) {
        case .ok(let faces):
            #expect(!faces.isEmpty)
            #expect(faces[0].format == .ttf)
            #expect(faces[0].postScriptName != nil)
        case .reject(let error):
            Issue.record("expected accept, got \(error)")
        }
    }

    @Test func rejectsWOFF() {
        var bytes = Data([0x77, 0x4F, 0x46, 0x46])  // 'wOFF'
        bytes.append(Data(repeating: 0, count: 20))
        let validator = MKFontValidator()
        switch validator.validate(bytes) {
        case .ok: Issue.record("expected reject")
        case .reject(let error):
            #expect(error.arabicUserMessage == "صيغة WOFF غير مدعومة ، استخدم TTF أو OTF")
        }
    }

    @Test func rejectsWOFF2() {
        var bytes = Data([0x77, 0x4F, 0x46, 0x32])  // 'wOF2'
        bytes.append(Data(repeating: 0, count: 20))
        let validator = MKFontValidator()
        switch validator.validate(bytes) {
        case .ok: Issue.record("expected reject")
        case .reject(let error):
            if case .unsupportedFormat = error {
                // pass
            } else {
                Issue.record("expected .unsupportedFormat, got \(error)")
            }
        }
    }

    @Test func rejectsTruncatedFile() {
        let bytes = Data([0x00, 0x01])  // way too short
        let validator = MKFontValidator()
        switch validator.validate(bytes) {
        case .ok: Issue.record("expected reject")
        case .reject(let error):
            #expect(error.arabicUserMessage == "ملف الخط تالف أو غير مكتمل")
        }
    }

    @Test func rejectsCorruptTableDirectory() {
        // Valid sfnt version tag, but a numTables claim that overruns the buffer.
        var bytes = Data([0x00, 0x01, 0x00, 0x00])  // sfnt version
        bytes.append(contentsOf: [0xFF, 0xFF])       // numTables = huge
        bytes.append(Data(repeating: 0, count: 20))
        let validator = MKFontValidator()
        switch validator.validate(bytes) {
        case .ok: Issue.record("expected reject")
        case .reject: break  // pass ، any rejection is acceptable here
        }
    }

    @Test func detectsVariableFont() throws {
        // Noto Naskh Arabic is shipped as a variable font ("[wght]" filename).
        let index = BundledFontIndex()
        let loaded = try index.loadAll()
        let noto = try #require(loaded.first { $0.record.fontID == "noto-naskh-arabic" })
        let face = try #require(noto.record.faces.first)
        let data = try Data(contentsOf: face.fileURL)
        switch MKFontValidator().validate(data) {
        case .ok(let faces):
            #expect(faces[0].isVariable)
        case .reject(let error):
            Issue.record("expected accept, got \(error)")
        }
    }
}
