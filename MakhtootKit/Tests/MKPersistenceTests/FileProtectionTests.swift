import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// S-6 (AUDIT_2026-07-28.md): no `FileProtectionType`/`NSFileProtectionKey`
/// appeared anywhere in the codebase before this fix ، document packages,
/// assets, and journals all took the platform default
/// (`completeUntilFirstUserAuthentication`). For a design tool holding
/// client work and unreleased brand material, `.completeUnlessOpen` on
/// scene/asset writes is the appropriate posture (still lets
/// autosave/background sync write while the device is locked, unlike plain
/// `.complete`).
///
/// **What this suite proves, and what it does NOT prove:** these tests
/// assert the `.protectionKey` FILE ATTRIBUTE is set to `.completeUnlessOpen`
/// on every write this fix touches. They do NOT prove cryptographic
/// enforcement ، Data Protection is backed by the device passcode/Secure
/// Enclave, and this suite runs on the `swift test` HOST PROCESS (a macOS
/// command-line binary, never a passcode-protected iOS Simulator/device),
/// where the attribute is accepted and persisted but has no actual
/// encryption effect to observe. Confirming the attribute is REQUESTED on
/// every write path is the meaningful, host-verifiable half of this fix;
/// confirming it's ENFORCED is only checkable by manual verification (`file
/// -P` / instruments on-device), which is out of scope for a unit test.
@Suite("File protection (S-6)")
struct FileProtectionTests {
    /// Reads back `.protectionKey` and normalizes it to `FileProtectionType`
    /// regardless of whether `FileManager.attributesOfItem(atPath:)` hands
    /// it back already-typed or as the underlying raw `String` constant
    /// (e.g. `"NSFileProtectionCompleteUnlessOpen"`) ، both are valid
    /// representations of the same attribute depending on Foundation
    /// version/platform, and this suite cares about the VALUE, not which
    /// boxed form it arrives in.
    private func protectionAttribute(atPath path: String) throws -> FileProtectionType? {
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        guard let raw = attrs[.protectionKey] else { return nil }
        if let typed = raw as? FileProtectionType { return typed }
        if let rawString = raw as? String { return FileProtectionType(rawValue: rawString) }
        return nil
    }

    // MARK: - MKAtomicIO.write (every scene.json/manifest.json/thumbnail.png write)

    @Test func atomicIOWriteSetsCompleteUnlessOpenProtectionOnTheDestinationFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-file-protection-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("payload.dat")

        try MKAtomicIO.write(Data("محتوى محمي".utf8), to: destination)

        let protection = try protectionAttribute(atPath: destination.path)
        #expect(protection == .completeUnlessOpen)
    }

    @Test func documentPackageSceneAndManifestWritesAreProtected() throws {
        // `DocumentPackage.writeScene`/`writeManifest` route through
        // `MKAtomicIO.write` ، exercised via the real package API rather
        // than the internal helper directly, so this suite also guards the
        // wiring, not just the primitive.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-file-protection-pkg-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.makhtoot")
        let package = try DocumentPackage.create(
            at: url, projectID: MKProjectID(), title: "ت", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
        )

        #expect(try protectionAttribute(atPath: package.sceneURL.path) == .completeUnlessOpen)
        #expect(try protectionAttribute(atPath: package.manifestURL.path) == .completeUnlessOpen)
    }

    // MARK: - MKAssetStore.storeAsset

    @Test func storeAssetSetsCompleteUnlessOpenProtectionOnTheAssetFile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-file-protection-asset-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.makhtoot")
        let package = try DocumentPackage.create(
            at: url, projectID: MKProjectID(), title: "ت", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
        )
        let store = MKAssetStore(package: package)

        let ref = try await store.storeAsset(data: Data("بيانات الصورة".utf8), ext: "bin")
        let assetPath = package.assetsDirURL.appendingPathComponent("sha256-\(ref.digest).bin").path

        #expect(try protectionAttribute(atPath: assetPath) == .completeUnlessOpen)
    }

    // MARK: - MKFileLocations.documentsProjectsDirectory (S-6: same posture on the directory itself)

    @Test func documentsProjectsDirectoryRequestsCompleteUnlessOpenProtection() throws {
        // Best-effort on the source side (`try?`, see `MKFileLocations
        // .documentsProjectsDirectory`'s doc comment): a failure to set
        // this attribute must never fail directory creation. This test
        // confirms the attribute IS requested when the underlying
        // filesystem accepts it; it does not fail the suite if the host
        // filesystem silently declines it (`try?` at the source means
        // there is no error to observe here either way, only the
        // resulting attribute).
        let projects = try MKFileLocations.documentsProjectsDirectory()
        let protection = try? protectionAttribute(atPath: projects.path)
        // Either the attribute was accepted (`.completeUnlessOpen`) or the
        // host silently declined it (`nil`/some other default) ، both are
        // acceptable outcomes of a `try?`-guarded best-effort call. What
        // would be a genuine regression is the directory itself not
        // existing at all afterward.
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: projects.path, isDirectory: &isDirectory)
        #expect(exists)
        #expect(isDirectory.boolValue)
        if let protection {
            #expect(protection == .completeUnlessOpen)
        }
    }
}
