import Foundation
import Testing
@testable import MKPersistence

// S-5 (AUDIT_2026-07-28.md): export temp files were never cleaned up.
// `ExportTempDirectory` isolates every test instance under its own
// throwaway root (`systemTemporaryDirectory:`) rather than sharing the
// real system temp directory `ExportTempDirectory.shared` writes into ،
// this suite would otherwise be racing every OTHER test in the process
// that also happens to touch `tmp/MKExports/`.
@Suite("ExportTempDirectory ، S-5 export temp cleanup")
struct ExportTempDirectoryTests {
    private func makeIsolatedRoot() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mk-export-temp-dir-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func urlForExportWritesLandInsideADedicatedMKExportsSubdirectory() throws {
        let root = makeIsolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sut = ExportTempDirectory(systemTemporaryDirectory: root)

        let fileURL = sut.urlForExport(ext: "jpg")
        #expect(fileURL.pathExtension == "jpg")
        #expect(fileURL.deletingLastPathComponent().lastPathComponent == "MKExports")
        // The subdirectory must already exist by the time a caller gets a
        // URL back ، a caller that immediately `Data.write(to:)`s it must
        // not have to `createDirectory` itself first.
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
    }

    @Test func purgeDeletesEveryFileWrittenViaUrlForExport() throws {
        let root = makeIsolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sut = ExportTempDirectory(systemTemporaryDirectory: root)

        let first = sut.urlForExport(ext: "jpg")
        let second = sut.urlForExport(ext: "png")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))

        sut.purge()

        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(!FileManager.default.fileExists(atPath: second.path))
    }

    @Test func purgeOnAnAlreadyEmptyOrMissingDirectoryIsANoOpNotAnError() throws {
        let root = makeIsolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sut = ExportTempDirectory(systemTemporaryDirectory: root)

        // Never even called `urlForExport`/`directoryURL` ، the "MKExports"
        // subdirectory doesn't exist yet at all.
        sut.purge()
        sut.purge() // and purging an already-purged directory is also fine.
    }

    @Test func directoryURLIsUsableAgainImmediatelyAfterAPurge() throws {
        let root = makeIsolatedRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let sut = ExportTempDirectory(systemTemporaryDirectory: root)

        _ = sut.urlForExport(ext: "jpg")
        sut.purge()

        // A caller (e.g. `MKExportCoordinator`'s `destinationDirectory:`)
        // reading `directoryURL` right after a `purge()` must get a real,
        // existing directory back, not a stale/missing path.
        let url = sut.directoryURL
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
    }
}
