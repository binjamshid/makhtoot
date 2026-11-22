import Foundation
import CoreGraphics
import Testing
import MKFoundation
import MKModel
@testable import MKPersistence
@testable import MKSync

// S-3 (AUDIT_2026-07-28.md): `nextBatch(context:)` packs a full plaintext
// copy of every uploaded project's package (scene + assets) into
// `tmp/MKSyncBatch-<UUID>/` and, before this fix, never removed it ، every
// sync cycle silently accumulated another full copy of the user's
// documents in `tmp/`, which iOS purges only opportunistically. The
// download path (`materialise(record:projectID:)`) already cleans up its
// own temp dir via `defer`; this closes the matching gap on the upload
// side.
//
// `CKSyncEngine.SendChangesContext` and `Event.SentRecordZoneChanges` are
// opaque CloudKit types with no public initializer anywhere in this
// codebase (mirrors `MKSyncDurableDirtyMarkingTests`'s own note on why it
// drives `handleLocalChange` directly instead of a live `CKSyncEngine`
// round-trip), so these tests exercise `MKSyncEngineController`'s
// internal, directly-callable `trackBatchTempDir(_:for:)`/
// `cleanupBatchTempDir(for:)` pair, and the launch-time sweep via ordinary
// actor construction, never a real `CKSyncEngine`.
@MainActor
@Suite struct MKSyncBatchTempCleanupTests {
    private func makeStore() throws -> (MetadataStore, URL) {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-sync-batch-cleanup-tests-\(UUID().uuidString).store")
        let container = try MetadataStore.makeContainer(at: storeURL)
        return (MetadataStore(modelContainer: container), storeURL)
    }

    private func makeController(metadataStore: MetadataStore) -> MKSyncEngineController {
        MKSyncEngineController(
            metadataStore: metadataStore,
            documentsRootURL: FileManager.default.temporaryDirectory,
            entitlementProvider: StubEntitlementResolver(),
            statusPublisher: MKSyncStatusPublisher(),
            applicationSupportURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("mk-sync-batch-cleanup-support-\(UUID().uuidString)", isDirectory: true)
        )
    }

    /// Creates a real directory (with one file inside, mirroring a packed
    /// project's non-empty package contents) under `parent` ، defaulting to
    /// the system temp directory ، and returns its URL.
    ///
    /// The track/cleanup round-trip tests below MUST pass an isolated
    /// per-test `parent` instead of the default: every `makeController(…)`
    /// in this process (including the other @MainActor suites'
    /// `MKSyncErrorSurfacingTests`/`MKSyncDurableDirtyMarkingTests`, which
    /// Swift Testing runs in parallel) triggers the S-3 launch-time sweep in
    /// `MKSyncEngineController.init`, which unconditionally removes every
    /// top-level `tmp/MKSyncBatch-*` entry. `MKSyncEngineController` is an
    /// actor, so each `await controller.…` here is a MainActor suspension
    /// point where a concurrent test's construction can run that sweep and
    /// delete a dir this test only just tracked ، exactly the flake this
    /// isolation prevents. The sweep scans only tmp's TOP level by name
    /// prefix, so an `MKSyncBatch-*` leaf nested under a uniquely-named
    /// parent keeps the production-mirroring name while being unreachable
    /// by any concurrent sweep. (`trackBatchTempDir`/`cleanupBatchTempDir`
    /// are themselves prefix- and location-agnostic ، the behaviour under
    /// test is unchanged.) The two sweep tests keep the default top-level
    /// placement deliberately ، the sweep's prefix matching IS their subject,
    /// and their create-then-construct sections are fully synchronous
    /// @MainActor chunks with no suspension point for a rival sweep to
    /// interleave into.
    private func makeRealTempDir(named name: String, under parent: URL? = nil) throws -> URL {
        let dir = (parent ?? FileManager.default.temporaryDirectory).appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("fake packed scene bytes".utf8).write(to: dir.appendingPathComponent("scene.json"))
        return dir
    }

    // MARK: - trackBatchTempDir / cleanupBatchTempDir

    /// The core register-then-cleanup round trip `nextBatch(context:)`/
    /// `processSentChanges(_:)` drive in production: a tracked directory
    /// that really exists on disk is actually removed, and the tracking
    /// entry itself is consumed (a second cleanup call for the same key is
    /// a harmless no-op, not a crash).
    @Test func trackThenCleanupRemovesARealTempDirectory() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let controller = makeController(metadataStore: store)

        // Isolated parent keeps this dir out of reach of concurrent tests'
        // construction-time sweeps ، see `makeRealTempDir(named:under:)`.
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-sync-batch-cleanup-isolated-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let dir = try makeRealTempDir(named: "MKSyncBatch-\(UUID().uuidString)", under: parent)
        let projectIDs: Set<UUID> = [UUID(), UUID()]

        await controller.trackBatchTempDir(dir, for: projectIDs)
        #expect(FileManager.default.fileExists(atPath: dir.path))

        await controller.cleanupBatchTempDir(for: projectIDs)
        #expect(FileManager.default.fileExists(atPath: dir.path) == false)

        // Second cleanup for the same (now-untracked) key must not throw or
        // attempt to remove anything again.
        await controller.cleanupBatchTempDir(for: projectIDs)
    }

    /// `cleanupBatchTempDir(for:)` only removes the directory tracked under
    /// the EXACT project-ID set it's called with ، a different batch's
    /// tracked directory (e.g. still in flight) must survive untouched.
    @Test func cleanupOnlyRemovesTheMatchingBatchsDirectory() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let controller = makeController(metadataStore: store)

        // Isolated parent keeps these dirs out of reach of concurrent tests'
        // construction-time sweeps ، see `makeRealTempDir(named:under:)`.
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-sync-batch-cleanup-isolated-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let dirA = try makeRealTempDir(named: "MKSyncBatch-\(UUID().uuidString)", under: parent)
        let dirB = try makeRealTempDir(named: "MKSyncBatch-\(UUID().uuidString)", under: parent)
        let idsA: Set<UUID> = [UUID()]
        let idsB: Set<UUID> = [UUID()]

        await controller.trackBatchTempDir(dirA, for: idsA)
        await controller.trackBatchTempDir(dirB, for: idsB)

        await controller.cleanupBatchTempDir(for: idsA)

        #expect(FileManager.default.fileExists(atPath: dirA.path) == false)
        #expect(FileManager.default.fileExists(atPath: dirB.path))

        // Clean up dirB's tracking too so this test doesn't itself leak a
        // tracked-but-orphaned entry into the next test in this process.
        await controller.cleanupBatchTempDir(for: idsB)
    }

    /// Cleaning up a project-ID set nothing was ever tracked for is a
    /// no-op ، `processSentChanges(_:)` calls this unconditionally on every
    /// sent-changes event, including ones this controller instance never
    /// itself produced a batch for (e.g. a stale/duplicate delegate
    /// callback).
    @Test func cleanupWithNoTrackedEntryIsANoOp() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let controller = makeController(metadataStore: store)

        await controller.cleanupBatchTempDir(for: [UUID()])
    }

    // MARK: - Launch-time sweep

    /// A `MKSyncBatch-*` directory left behind in `tmp/` by a prior process
    /// (crash, force-quit, or a build predating this fix) is removed the
    /// next time an `MKSyncEngineController` is constructed ، the launch-time
    /// sweep runs unconditionally inside `init`, before this test's own
    /// controller could possibly have tracked anything.
    @Test func staleBatchTempDirFromAPriorLaunchIsSweptOnConstruction() async throws {
        let staleDir = try makeRealTempDir(named: "MKSyncBatch-\(UUID().uuidString)")
        #expect(FileManager.default.fileExists(atPath: staleDir.path))

        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        // Constructing the controller is the trigger under test ، no method
        // call beyond `init` is needed for the sweep to run.
        _ = makeController(metadataStore: store)

        #expect(FileManager.default.fileExists(atPath: staleDir.path) == false)
    }

    /// The sweep matches strictly by the `MKSyncBatch-` prefix ، an
    /// unrelated temp directory (e.g. another subsystem's own tmp scratch
    /// space) must survive construction untouched.
    @Test func unrelatedTempDirectoryIsNotSweptAway() async throws {
        let unrelatedDir = try makeRealTempDir(named: "SomeOtherSubsystem-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: unrelatedDir) }

        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        _ = makeController(metadataStore: store)

        #expect(FileManager.default.fileExists(atPath: unrelatedDir.path))
    }
}
