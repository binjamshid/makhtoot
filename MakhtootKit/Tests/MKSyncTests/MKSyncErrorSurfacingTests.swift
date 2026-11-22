import Foundation
import CoreGraphics
import CloudKit
import Testing
import MKFoundation
import MKModel
@testable import MKPersistence
@testable import MKSync

// UX-5 (AUDIT_2026-07-28.md), corrected scope per Wave 0 Agent 0.1: sync
// errors were already partly surfaced ، `SyncSettingsView` renders
// `globalState.localizedMessage` live, and the project browser renders a
// per-project badge via `MKSyncStatusAdapter.badge(for:)` ، but only
// `MKSyncError.zoneNotFound` ever reached any state that outlived the
// engine's own immediate next event. Every OTHER error kind
// (`materialise`/`handleConflict`/`processSentChanges`'s per-record
// failures) only ever reached the transient per-project badge and vanished
// the moment CKSyncEngine's next `.didFetchChanges`/`.didSendChanges` fired.
//
// `MKSyncEngineController.lastError` (this Wave's fix) is only ever SET,
// never cleared by a subsequent non-error status publish, so it survives
// exactly the kind of "engine settles back to idle a moment later" flow
// CKSyncEngine's real event stream produces. `CKSyncEngine.SendChangesContext`/
// `Event.SentRecordZoneChanges` are opaque CloudKit types with no public
// initializer anywhere in this codebase (mirrors
// `MKSyncBatchTempCleanupTests`'s own note on why it drives
// `trackBatchTempDir`/`cleanupBatchTempDir` directly), so these tests drive
// `recordLastError(_:)` ، the same directly-callable seam `publishStatus`/
// `publishProjectStatus` route every error through in production ، rather
// than trying to construct a live batch/event round-trip.
@MainActor
@Suite struct MKSyncErrorSurfacingTests {
    private func makeStore() throws -> (MetadataStore, URL) {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-sync-error-surfacing-tests-\(UUID().uuidString).store")
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
                .appendingPathComponent("mk-sync-error-surfacing-support-\(UUID().uuidString)", isDirectory: true)
        )
    }

    /// `lastError` starts nil ، no error has ever been observed yet.
    @Test func lastErrorStartsNil() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let controller = makeController(metadataStore: store)

        #expect(await controller.lastError == nil)
    }

    /// The core fix: a CKError distinct from `.zoneNotFound` (the only kind
    /// that reached any persisted surface before this Wave), mapped through
    /// the SAME pure `MKSyncErrorMapper.map` production code uses, reaches
    /// `lastError`.
    @Test func nonZoneNotFoundErrorKindReachesLastError() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let controller = makeController(metadataStore: store)

        let ckError = CKError(.quotaExceeded)
        let mapped = MKSyncErrorMapper.map(ckError)
        #expect(mapped == .quotaExceeded)

        await controller.recordLastError(mapped)
        #expect(await controller.lastError == .quotaExceeded)
    }

    /// `.zoneNotFound` itself still reaches `lastError` too ، this fix
    /// extends the existing path, it doesn't replace it.
    @Test func zoneNotFoundStillReachesLastError() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let controller = makeController(metadataStore: store)

        await controller.recordLastError(.zoneNotFound)
        #expect(await controller.lastError == .zoneNotFound)
    }

    /// The persistence half of the fix: once an error has been recorded, an
    /// unrelated NON-error status publish (`handleLocalChange`'s
    /// `.pendingUpload` publish, the same call `publishProjectStatus` makes
    /// in production every time a project is edited) must NOT clear it ،
    /// mirroring CKSyncEngine settling the transient `globalState`/
    /// per-project badge back to a normal state moments after a real
    /// failure.
    @Test func lastErrorSurvivesASubsequentNonErrorStatusPublish() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let projectID = UUID()
        let summary = try await store.addProject(
            projectID: projectID, title: "مشروع بخطأ سابق",
            canvas: MKCanvasSpec(size: CGSize(width: 100, height: 100)),
            packageRelativePath: "Projects/\(projectID.uuidString).makhtoot"
        )
        let controller = makeController(metadataStore: store)

        let ckError = CKError(.networkFailure)
        let mapped = MKSyncErrorMapper.map(ckError)
        await controller.recordLastError(mapped)
        #expect(await controller.lastError == mapped)

        // `handleLocalChange(.modified(_:))` calls `publishProjectStatus(id,
        // .pendingUpload)` internally ، a real, non-private, non-error
        // status publish, exactly like the ones CKSyncEngine's ordinary
        // event flow produces right after a failure.
        await controller.handleLocalChange(.modified(summary))

        #expect(await controller.lastError == mapped)
    }

    /// A SECOND, different error kind overwrites the first ، `lastError`
    /// tracks the MOST RECENT failure, not the first one ever seen.
    @Test func aNewerErrorOverwritesAnOlderOne() async throws {
        let (store, storeURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let controller = makeController(metadataStore: store)

        await controller.recordLastError(.zoneNotFound)
        #expect(await controller.lastError == .zoneNotFound)

        await controller.recordLastError(.quotaExceeded)
        #expect(await controller.lastError == .quotaExceeded)
    }
}
