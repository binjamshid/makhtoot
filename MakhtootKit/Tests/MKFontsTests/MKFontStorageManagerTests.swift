import Foundation
import Testing
@testable import MKFonts

/// T18 AC: delete removes file + unregisters; re-download works; warning
/// string in Arabic when referencing projects are named; bundled fonts
/// refuse deletion.
@Suite("MKFontStorageManager ، T18")
struct MKFontStorageManagerTests {
    private func registerFakeDownloaded(_ registry: MKFontRegistry, fontID: String) async throws -> URL {
        let bundled = try #require(await registry.records().first)
        let sourceFace = bundled.faces[0]
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("mk-storage-\(UUID().uuidString).ttf")
        try FileManager.default.copyItem(at: sourceFace.fileURL, to: dest)
        let face = MKFontFace(
            postScriptName: sourceFace.postScriptName + "-copy", familyName: "Copy", fullName: "Copy",
            styleName: "normal", weight: 400, isVariable: false, format: .ttf, filename: dest.lastPathComponent, fileURL: dest
        )
        let record = MKFontRecord(fontID: fontID, familyName: "Copy", origin: .premiumDownloaded, faces: [face], categories: [], tags: [])
        let license = MKLicenseRecord(
            fontID: fontID, familyName: "Copy", licenseType: .ofl11, copyrightNotice: "", reservedFontNames: [],
            sourceRepoURL: "", licenseFileBundlePath: "", verificationDate: "2026-07-18", verifiedBy: "test",
            redistributionConfirmed: true, embeddingRights: [.pdf, .svg, .commercialUse]
        )
        try await registry.registerDownloaded(record, license: license)
        return dest
    }

    @Test func deletingDownloadedFontRemovesFileAndUnregisters() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let fileURL = try await registerFakeDownloaded(registry, fontID: "premium-x")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let manager = MKFontStorageManager(registry: registry)
        let outcome = await manager.delete("premium-x")
        #expect(outcome == .deleted)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        let record = await registry.record(for: "premium-x")
        #expect(record == nil)
    }

    @Test func deletingBundledFontIsRefused() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let bundledID = try #require(await registry.records().first?.fontID)
        let manager = MKFontStorageManager(registry: registry)
        let outcome = await manager.delete(bundledID)
        #expect(outcome == .refusedBundled)
        #expect(await registry.record(for: bundledID) != nil)
    }

    @Test func deletingWithReferencingProjectsReturnsArabicWarning() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        _ = try await registerFakeDownloaded(registry, fontID: "premium-y")
        let manager = MKFontStorageManager(registry: registry)
        let outcome = await manager.delete("premium-y", referencingProjectTitles: ["دعوة زفاف"])
        guard case .deletedWithProjectReferenceWarning(let message) = outcome else {
            Issue.record("expected warning outcome, got \(outcome)")
            return
        }
        #expect(message.contains("دعوة زفاف"))
        #expect(message.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) })
    }

    @Test func redownloadAfterDeleteWorks() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        _ = try await registerFakeDownloaded(registry, fontID: "premium-z")
        let manager = MKFontStorageManager(registry: registry)
        _ = await manager.delete("premium-z")
        #expect(await registry.record(for: "premium-z") == nil)
        // Re-download == register again (same mechanism the real downloader uses).
        _ = try await registerFakeDownloaded(registry, fontID: "premium-z")
        #expect(await registry.record(for: "premium-z") != nil)
    }
}
