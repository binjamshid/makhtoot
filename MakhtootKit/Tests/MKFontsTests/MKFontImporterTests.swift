import Foundation
import MKFoundation
import Testing
@testable import MKFonts

struct FakeEntitlementProvider: MKEntitlementProviding {
    let state: MKEntitlementState
}

/// T14/T15 AC: valid ttf/otf/ttc/variable accepted; duplicate import
/// (same hash) idempotent; free-tier import refused; imported fonts get
/// `licenseType == .userProvided` with empty embedding rights.
@Suite("MKFontImporter ، T14/T15")
struct MKFontImporterTests {
    private func realAmiriData() throws -> Data {
        let loaded = try BundledFontIndex().loadAll()
        let amiri = try #require(loaded.first { $0.record.fontID == "amiri" })
        let face = try #require(amiri.record.faces.first)
        return try Data(contentsOf: face.fileURL)
    }

    private func tempSourceFile(data: Data, name: String = "MyFont.ttf") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mk-import-\(UUID().uuidString)-\(name)")
        try data.write(to: url)
        return url
    }

    @Test func premiumUserCanImportAValidFont() async throws {
        let registry = MKFontRegistry()
        let importer = MKFontImporter(
            registry: registry, entitlements: StubEntitlementResolver(),
            destinationRoot: FileManager.default.temporaryDirectory.appendingPathComponent("mk-import-dest-\(UUID().uuidString)")
        )
        let source = try tempSourceFile(data: try realAmiriData())
        let fontID = try await importer.importFont(from: source, originalFilename: "MyFont.ttf")
        #expect(fontID.hasPrefix("user."))

        let record = await registry.record(for: fontID)
        #expect(record?.origin == .userImported)
        let license = await registry.licenseRecord(for: fontID)
        #expect(license?.licenseType == .userProvided)
        #expect(license?.redistributionConfirmed == false)
        #expect(license?.embeddingRights.isEmpty == true)
    }

    @Test func freeTierImportIsRefused() async throws {
        let registry = MKFontRegistry()
        let importer = MKFontImporter(registry: registry, entitlements: FakeEntitlementProvider(state: .free))
        let source = try tempSourceFile(data: try realAmiriData())
        await #expect(throws: MKFontError.self) {
            _ = try await importer.importFont(from: source, originalFilename: "MyFont.ttf")
        }
    }

    @Test func duplicateImportIsIdempotent() async throws {
        let registry = MKFontRegistry()
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("mk-import-dest-\(UUID().uuidString)")
        let importer = MKFontImporter(registry: registry, entitlements: StubEntitlementResolver(), destinationRoot: dest)
        let data = try realAmiriData()
        let first = try await importer.importFont(from: try tempSourceFile(data: data), originalFilename: "A.ttf")
        let second = try await importer.importFont(from: try tempSourceFile(data: data), originalFilename: "A-copy.ttf")
        #expect(first == second)
        let allRecords = await registry.records()
        #expect(allRecords.filter { $0.fontID == first }.count == 1)
    }

    @Test func woffRejectedWithSpecificArabicMessage() async throws {
        let registry = MKFontRegistry()
        let importer = MKFontImporter(registry: registry, entitlements: StubEntitlementResolver())
        var woffBytes = Data([0x77, 0x4F, 0x46, 0x46])
        woffBytes.append(Data(repeating: 0, count: 20))
        let source = try tempSourceFile(data: woffBytes, name: "font.woff")
        do {
            _ = try await importer.importFont(from: source, originalFilename: "font.woff")
            Issue.record("expected throw")
        } catch let error as MKFontError {
            #expect(error.arabicUserMessage == "صيغة WOFF غير مدعومة ، استخدم TTF أو OTF")
        }
    }

    @Test func truncatedFileRejectedAsCorrupt() async throws {
        let registry = MKFontRegistry()
        let importer = MKFontImporter(registry: registry, entitlements: StubEntitlementResolver())
        let source = try tempSourceFile(data: Data([0x00, 0x01]), name: "broken.ttf")
        do {
            _ = try await importer.importFont(from: source, originalFilename: "broken.ttf")
            Issue.record("expected throw")
        } catch let error as MKFontError {
            #expect(error.arabicUserMessage == "ملف الخط تالف أو غير مكتمل")
        }
    }
}
