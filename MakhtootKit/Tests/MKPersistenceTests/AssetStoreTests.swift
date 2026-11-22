import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §5 task 8 accept criteria: same bytes stored twice dedupe
/// to one file; orphan sweep test.
@Suite("MKAssetStore")
struct AssetStoreTests {
    private func makeTempPackage() throws -> (DocumentPackage, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-asset-store-tests-\(UUID().uuidString)", isDirectory: true)
        let url = root.appendingPathComponent("test.makhtoot")
        let package = try DocumentPackage.create(
            at: url, projectID: MKProjectID(), title: "t", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
        )
        return (package, root)
    }

    @Test func identicalBytesDedupeToOneFile() async throws {
        let (package, root) = try makeTempPackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MKAssetStore(package: package)

        let bytes = Data("hello asset".utf8)
        let ref1 = try await store.storeAsset(data: bytes, ext: "bin")
        let ref2 = try await store.storeAsset(data: bytes, ext: "bin")

        #expect(ref1 == ref2)
        let contents = try FileManager.default.contentsOfDirectory(atPath: package.assetsDirURL.path)
        #expect(contents.count == 1)
        #expect(try await store.assetData(for: ref1) == bytes)
    }

    @Test func differentBytesProduceDifferentDigests() async throws {
        let (package, root) = try makeTempPackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MKAssetStore(package: package)

        let ref1 = try await store.storeAsset(data: Data("a".utf8), ext: "bin")
        let ref2 = try await store.storeAsset(data: Data("b".utf8), ext: "bin")
        #expect(ref1.digest != ref2.digest)
    }

    @Test func orphanSweepGivesOneGraceCycleBeforeDeletion() async throws {
        let (package, root) = try makeTempPackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MKAssetStore(package: package)

        let ref = try await store.storeAsset(data: Data("orphan-me".utf8), ext: "bin")

        // Cycle 1: no longer referenced → moved to backups/orphans/, NOT deleted.
        try await store.sweepOrphans(referencedBy: [])
        #expect(await store.hasAsset(ref) == false)
        var orphaned = try await store.orphanedFilenames()
        #expect(orphaned.contains("sha256-\(ref.digest).bin"))

        // Cycle 2: still unreferenced → the grace-cycle file is now purged.
        try await store.sweepOrphans(referencedBy: [])
        orphaned = try await store.orphanedFilenames()
        #expect(orphaned.isEmpty)
    }

    @Test func referencedAssetsSurviveASweep() async throws {
        let (package, root) = try makeTempPackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MKAssetStore(package: package)

        let ref = try await store.storeAsset(data: Data("keep-me".utf8), ext: "bin")
        try await store.sweepOrphans(referencedBy: [ref])
        #expect(await store.hasAsset(ref) == true)
    }

    /// P-7: `sweepOrphans` must skip its filesystem work entirely when the
    /// referenced-asset set is unchanged since the last sweep AND there is
    /// nothing left over in `backups/orphans/` to finalize ،
    /// `MKManifest.assetIndexDigest` is what makes this check possible
    /// across calls (previously declared, never written). `sweepExecutionCount`
    /// (a test/diagnostic counter, same pattern as `AutosaveController
    /// .fullSaveCount`) makes the skip observable without racing the
    /// filesystem.
    @Test func sweepIsSkippedWhenTheReferencedAssetSetIsUnchanged() async throws {
        let (package, root) = try makeTempPackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MKAssetStore(package: package)

        let ref = try await store.storeAsset(data: Data("steady-state".utf8), ext: "bin")

        // First call: digest goes from "never set" to a real value ،
        // this is a genuine sweep, not a skip.
        try await store.sweepOrphans(referencedBy: [ref])
        #expect(await store.sweepExecutionCount == 1)

        // Second and third calls with the IDENTICAL referenced set and no
        // pending orphans: nothing for the sweep to do, so it must return
        // before touching the filesystem at all.
        try await store.sweepOrphans(referencedBy: [ref])
        try await store.sweepOrphans(referencedBy: [ref])
        #expect(await store.sweepExecutionCount == 1)
        #expect(await store.hasAsset(ref) == true)
    }

    /// P-7: when the sweep DOES run, it must finalize (permanently delete)
    /// only orphans left over from a PRIOR cycle, never a file that became
    /// unreferenced in the CURRENT cycle ، that file still owes its own
    /// one-cycle grace period. Exercises a set that shrinks over three
    /// sweeps: {a, b} → {a} (b freshly orphaned) → {} (a freshly orphaned,
    /// b's grace cycle expires).
    @Test func sweepFinalizesOnlyThePriorCyclesOrphansNotTheCurrentCyclesOnes() async throws {
        let (package, root) = try makeTempPackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MKAssetStore(package: package)

        let refA = try await store.storeAsset(data: Data("asset-a".utf8), ext: "bin")
        let refB = try await store.storeAsset(data: Data("asset-b".utf8), ext: "bin")

        // Cycle 1: both referenced ، establishes the initial digest, no
        // orphans yet.
        try await store.sweepOrphans(referencedBy: [refA, refB])
        #expect(try await store.orphanedFilenames().isEmpty)

        // Cycle 2: only `a` still referenced ، `b` is freshly orphaned this
        // cycle, must NOT be deleted yet (still owes its one-cycle grace).
        try await store.sweepOrphans(referencedBy: [refA])
        var orphaned = try await store.orphanedFilenames()
        #expect(orphaned == ["sha256-\(refB.digest).bin"])
        #expect(await store.hasAsset(refA) == true)

        // Cycle 3: nothing referenced ، `a` is freshly orphaned this cycle
        // (must survive, still in `orphanedFilenames()`), while `b` (a
        // PRIOR-cycle orphan) is finalized (permanently deleted).
        try await store.sweepOrphans(referencedBy: [])
        orphaned = try await store.orphanedFilenames()
        #expect(orphaned == ["sha256-\(refA.digest).bin"])
        #expect(await store.hasAsset(refA) == false) // moved to orphans, not in assets/
        #expect(await store.hasAsset(refB) == false) // permanently gone
    }

    /// S-2 defense in depth: `MKAssetRef.init(from:)` (`MKNode.swift`)
    /// already rejects a traversal-shaped `digest`/`ext` at DECODE time
    /// (see `MKAssetRefValidationTests.swift`), but a ref can also reach
    /// this store constructed directly via the plain memberwise
    /// `init(digest:ext:)` (used throughout this package's own source for
    /// already-trusted, in-process values), which does NOT re-run that
    /// validation. `assetURL(for:)` is the backstop for that path: it
    /// asserts the resolved URL still lives inside `assetsDirURL` and
    /// throws `MKAssetPathError` rather than touching the filesystem
    /// outside the sandboxed asset directory.
    @Test func assetURLDefenseInDepthRejectsARefThatBypassesDecodeValidation() async throws {
        let (package, root) = try makeTempPackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = MKAssetStore(package: package)

        // The audit's own worked example (S-2): an `ext` that climbs out
        // of `assets/` via `..` segments once interpolated into a path
        // component.
        let escapingRef = MKAssetRef(digest: "deadbeef", ext: "png/../../../../etc/passwd")

        #expect(await store.hasAsset(escapingRef) == false)
        await #expect(throws: MKAssetPathError.self) {
            try await store.assetData(for: escapingRef)
        }
    }
}
