import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

// S-4 (AUDIT_2026-07-28.md): `DocumentPackage.validateForImport(at:limits:)`
// bounds an externally-supplied `.makhtoot` package's total size and shape
// BEFORE `MKPersistenceProjectLibrary.importExternalPackage(at:)` copies it
// into this app's own managed storage. These tests exercise the validator
// directly, in isolation from that call site.
//
// The byte-cap and file-count-cap cases pass a deliberately tiny `limits:`
// override rather than actually writing hundreds of megabytes or tens of
// thousands of files to disk ، `MKPackageImportLimits` exists precisely so
// callers (production code and tests alike) can supply a cap; a slow test
// that materializes real oversized fixtures to prove the exact same
// comparison logic would only make the suite slower, not more correct.
@Suite("PackageImportValidator")
struct PackageImportValidatorTests {
    private func makeTempPackageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-import-validator-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("test.makhtoot")
    }

    private func makePackage(at url: URL) throws -> DocumentPackage {
        let canvas = MKCanvasSpec(size: CGSize(width: 400, height: 400))
        return try DocumentPackage.create(at: url, projectID: MKProjectID(), title: "استيراد", canvas: canvas)
    }

    @Test func underCapAllowlistedPackagePasses() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let package = try makePackage(at: url)
        // A realistic-but-small asset alongside the manifest/scene
        // `DocumentPackage.create` already writes, still well under the
        // default caps.
        try Data(repeating: 0x42, count: 1_024).write(to: package.assetsDirURL.appendingPathComponent("a.png"))

        // Default limits ، should not throw.
        try DocumentPackage.validateForImport(at: url)
    }

    @Test func exceedingByteCapThrowsByteCapExceeded() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let package = try makePackage(at: url)
        // manifest.json + scene.json together are already a handful of
        // bytes; a 64-byte cap guarantees the walk trips the cap without
        // needing to write anything unusually large.
        try Data(repeating: 0x01, count: 256).write(to: package.assetsDirURL.appendingPathComponent("big.bin"))

        let tinyLimits = MKPackageImportLimits(maxTotalBytes: 64, maxFileCount: 1_000)
        #expect(throws: MKPackageImportValidationError.byteCapExceeded(limit: 64)) {
            try DocumentPackage.validateForImport(at: url, limits: tinyLimits)
        }
    }

    @Test func exceedingFileCountCapThrowsFileCountCapExceeded() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let package = try makePackage(at: url)
        // `DocumentPackage.create` already writes manifest.json + scene.json
        // (2 files); add a few more so a cap of 2 is guaranteed to trip
        // regardless of enumeration order.
        for i in 0..<5 {
            try Data("x".utf8).write(to: package.assetsDirURL.appendingPathComponent("f\(i).bin"))
        }

        let tinyLimits = MKPackageImportLimits(maxTotalBytes: 10 * 1024 * 1024, maxFileCount: 2)
        #expect(throws: MKPackageImportValidationError.fileCountCapExceeded(limit: 2)) {
            try DocumentPackage.validateForImport(at: url, limits: tinyLimits)
        }
    }

    // MARK: - S8-3 symlink rejection

    /// A link nested inside an allowlisted directory: the enumerator reports
    /// the LINK's own size, so it slips past `maxTotalBytes` entirely ، the
    /// exact evasion that made this reachable before the fix.
    @Test func symlinkInsideAssetsThrowsUnexpectedMember() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let package = try makePackage(at: url)

        // Points outside the package entirely ، the exfiltration shape.
        let escape = package.assetsDirURL.appendingPathComponent("escape.png")
        try FileManager.default.createSymbolicLink(
            at: escape, withDestinationURL: URL(fileURLWithPath: "/etc/hosts"))

        #expect(throws: MKPackageImportValidationError.unexpectedMember("escape.png")) {
            try DocumentPackage.validateForImport(at: url)
        }
    }

    /// A link named exactly like an allowlisted member ، rejected on
    /// link-ness before the name check ever runs, which is why that ordering
    /// matters in `validateForImport`.
    @Test func symlinkedTopLevelMemberThrowsDespiteAllowlistedName() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        _ = try makePackage(at: url)

        let thumbnail = url.appendingPathComponent("thumbnail.png")
        try? FileManager.default.removeItem(at: thumbnail)
        try FileManager.default.createSymbolicLink(
            at: thumbnail, withDestinationURL: URL(fileURLWithPath: "/etc/hosts"))

        #expect(throws: MKPackageImportValidationError.unexpectedMember("thumbnail.png")) {
            try DocumentPackage.validateForImport(at: url)
        }
    }

    /// A symlinked DIRECTORY can report `isDirectory == true`, which the
    /// byte/count guard skips with `continue` ، so the link check must come
    /// before that guard, not after it.
    @Test func symlinkedDirectoryIsRejectedNotSkipped() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let package = try makePackage(at: url)

        let link = package.assetsDirURL.appendingPathComponent("linked-dir")
        try FileManager.default.createSymbolicLink(
            at: link, withDestinationURL: URL(fileURLWithPath: "/etc"))

        #expect(throws: MKPackageImportValidationError.unexpectedMember("linked-dir")) {
            try DocumentPackage.validateForImport(at: url)
        }
    }

    @Test func unexpectedTopLevelEntryThrowsUnexpectedMember() throws {
        let url = makeTempPackageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        _ = try makePackage(at: url)
        // A member outside `manifest.json`/`scene.json`/`thumbnail.png`/
        // `journal.mkj`/`assets`/`backups` ، e.g. something a malicious or
        // merely corrupt package smuggled in alongside a real layout.
        try Data("payload".utf8).write(to: url.appendingPathComponent("unexpected.exe"))

        #expect(throws: MKPackageImportValidationError.unexpectedMember("unexpected.exe")) {
            try DocumentPackage.validateForImport(at: url)
        }
    }

    @Test func nonexistentURLDoesNotThrowLeavesRejectionToTheCaller() throws {
        // Not a directory at all ، the caller's own subsequent
        // `DocumentPackage.exists`/`readManifest()` check is the authority
        // on "is this really a package"; this validator has nothing to
        // enumerate and must not throw a validation-specific error for a
        // condition it isn't responsible for diagnosing.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-import-validator-tests-missing-\(UUID().uuidString)", isDirectory: true)
        try DocumentPackage.validateForImport(at: url)
    }
}
