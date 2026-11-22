import Foundation
import CoreGraphics
import Testing
import MKFoundation
import MKModel
@testable import MKPersistence
@testable import MKSync

// P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 4 ، MKSync
// pending-queue durability backlog item, WS-11 §5's D1 deviation). Proves
// the gap `MKSyncEngineController.markDurablyDirtyIfAlreadySynced` closes:
// without it, a project that already synced once and is then modified
// again stays durably `syncState == 1` (stale) until the in-memory
// `MKSyncPendingQueue`'s 5 s debounce actually fires ، a kill inside that
// window would have made `enqueueAllPendingFromStore`'s relaunch rebuild
// scan silently skip a real, un-uploaded edit forever. `CKSyncEngine`
// itself is not mockable (WS-11's own D5), so this exercises
// `MKSyncEngineController.handleLocalChange` ، the internal entry point ،
// directly against a real, in-memory-backed `MetadataStore`, never
// touching CloudKit.
@MainActor
@Suite struct MKSyncDurableDirtyMarkingTests {
    private func makeStore() throws -> (MetadataStore, URL) {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-sync-durability-tests-\(UUID().uuidString).store")
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
                .appendingPathComponent("mk-sync-durability-support-\(UUID().uuidString)", isDirectory: true)
        )
    }

    /// The gap: a project already synced once (`syncState == 1`), modified
    /// again, must be durably re-marked dirty ، simulating "process is
    /// killed right after this call, before the in-memory queue's debounce
    /// fires" and confirming the NEXT launch's rebuild scan would still
    /// catch it (`syncState == 0` is exactly `enqueueAllPendingFromStore`'s
    /// own rebuild condition).
    @Test func modifyingAnAlreadySyncedProjectDurablyResetsSyncStateToZero() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let projectID = UUID()
        let summary = try await store.addProject(
            projectID: projectID, title: "بطاقة معايدة",
            canvas: MKCanvasSpec(size: CGSize(width: 100, height: 100)),
            packageRelativePath: "Projects/\(projectID.uuidString).makhtoot"
        )
        // Simulate a prior successful sync ، exactly what `processSentChanges`
        // writes on upload success.
        try await store.updateSyncState(projectID: projectID, syncState: 1, lastSyncedChangeTag: "old-hash-abc")

        let controller = makeController(metadataStore: store)
        await controller.handleLocalChange(.modified(summary))

        let after = try await store.project(id: projectID)
        #expect(after?.syncState == 0)   // durably dirty ، survives a kill before the debounce fires
        // The opaque CloudKit tag is preserved (not nil'd) ، only the
        // freshness bit changes; a future conflict-diagnosis read still has
        // it available.
        #expect(after?.lastSyncedChangeTag == "old-hash-abc")
    }

    @Test func renamingAnAlreadySyncedProjectDurablyResetsSyncStateToZero() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let projectID = UUID()
        _ = try await store.addProject(
            projectID: projectID, title: "قبل",
            canvas: MKCanvasSpec(size: CGSize(width: 100, height: 100)),
            packageRelativePath: "Projects/\(projectID.uuidString).makhtoot"
        )
        try await store.updateSyncState(projectID: projectID, syncState: 1, lastSyncedChangeTag: "tag-1")

        let controller = makeController(metadataStore: store)
        await controller.handleLocalChange(.renamed(projectID, newTitle: "بعد"))

        let after = try await store.project(id: projectID)
        #expect(after?.syncState == 0)
    }

    /// Guard path: a NEVER-synced project (the common, already-correct
    /// case per D1) must not be touched by this fix ، no redundant write,
    /// and `syncState` stays exactly `0` (its `MKProjectRecord.init`
    /// default), matching the pre-existing rebuild condition it already
    /// satisfied.
    @Test func neverSyncedProjectIsUnaffectedNoRedundantWrite() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let projectID = UUID()
        let summary = try await store.addProject(
            projectID: projectID, title: "مشروع جديد",
            canvas: MKCanvasSpec(size: CGSize(width: 100, height: 100)),
            packageRelativePath: "Projects/\(projectID.uuidString).makhtoot"
        )
        #expect(summary.syncState == 0)

        let controller = makeController(metadataStore: store)
        await controller.handleLocalChange(.modified(summary))

        let after = try await store.project(id: projectID)
        #expect(after?.syncState == 0)
        #expect(after?.lastSyncedChangeTag == nil)
    }

    /// A project deleted locally must still surface via the durable
    /// tombstone registry (unchanged, pre-existing behavior) ، this fix
    /// only touches the upload-side gap, never the delete path (see the
    /// comment in `handleLocalChange`'s `.deleted` case for why no
    /// additional durable marker is needed there).
    @Test func deletingAProjectStillRecordsATombstoneUnaffectedByThisFix() async throws {
        let (store, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let projectID = UUID()
        _ = try await store.addProject(
            projectID: projectID, title: "للحذف",
            canvas: MKCanvasSpec(size: CGSize(width: 100, height: 100)),
            packageRelativePath: "Projects/\(projectID.uuidString).makhtoot"
        )
        try await store.deleteProject(id: projectID)

        let controller = makeController(metadataStore: store)
        await controller.handleLocalChange(.deleted(projectID))

        let tombstones = try await store.tombstones()
        #expect(tombstones.contains(projectID))
    }
}
