import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKRender
// `@testable`: every symbol this file actually needs from `MKPersistence`
// (`DocumentPackage`, `MakhtootDocument`, `AutosaveController`,
// `CommandJournal`, `MKAssetStore`, `MKSaveReason`, `MKNoOpCommand`) is
// already `public`; the ONE exception is `MKSceneRevision.hash` (internal),
// used by `RealAutosaveAdapter.flushJournalOnly()` below to compute the
// exact same journal `baseRev` that `MakhtootDocument.saveNow(reason:
// .memoryPressureCritical)` computes internally in production ، precedented
// by `MKSyncTests/MKSyncDurableDirtyMarkingTests.swift`, which already
// reaches into `MKPersistence` internals via `@testable import` from a
// DIFFERENT test target the same way this file does.
@testable import MKPersistence

// P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, memory-stress-drive
// item): host-runnable, deterministic evidence for the backlog item
// "5000-node memory-stress drive with save-before-degrade + zero-loss
// relaunch evidence." This is NOT a live simulator/device memory-pressure
// kill-and-restore drive ، this codebase's own established convention
// (`docs/impl-log/WS-07-p14.md`'s "Environment-deferred" list,
// `T-PERF-KILL-RESTORE`: "kill-under-pressure → relaunch → exact restore
// (10/10 runs) ، device required") is to prove the LOGIC end to end via
// injected pressure signals over REAL components, and leave actual
// on-device memory-pressure-kill timing environment-deferred alongside
// every other device-gated item already documented that way. This file is
// that logic proof: a real `MKPersistence.DocumentPackage` +
// `AutosaveController` + `CommandJournal` (not a fake), a real
// `MKRender.MKDegradationController` + `MKFoundation.MKMemoryGovernor`, and
// a real 5000-node `MKScene` (via `MemoryStressFixtureScenes.flatNodesScene`
// below, a verbatim mirror of `Tests/MKPersistenceTests
// /FixtureScenes.flatNodesScene` ، the same generator `MakhtootDocumentTests`'
// D-115 perf gates already use ، no new 5000-node generator invented here;
// see that enum's own doc comment for why it is duplicated rather than
// imported).
//
// Sibling relationship: `MemoryGovernorIntegrationTests.swift` (same
// directory) proves the ladder→governor WIRING with a SYNTHETIC autosave
// recorder ، sufficient for that file's narrower "does the governor get
// called in the right order" question. This file goes one layer deeper:
// the autosave side of the save-before-degrade ordering is a REAL
// `MKPersistence.AutosaveController` writing REAL bytes to a REAL
// `.makhtoot` package on disk, and the "zero-loss" half of the evidence
// (§4 below) only means something against real on-disk state ، a synthetic
// recorder has nothing to reopen. Requires `MKPersistence` as a target
// dependency (`Package.swift`, `MKRenderTests` test target) ، a one-line,
// test-only addition logged at that edit site; precedented by
// `MKArrangeTests`, which already depends on `MKPersistence` + `MKRender` +
// `MKModel` + `MKFoundation` + `MKTextEngine` simultaneously.
/// `count` flat sibling shape nodes ، a verbatim mirror of
/// `Tests/MKPersistenceTests/FixtureScenes.flatNodesScene(count:)` (the SAME
/// 5000-node generator `MakhtootDocumentTests`' D-115 perf gates already
/// use: identical node naming/shape/canvas). Duplicated here, not imported,
/// because `MKRenderTests` has no `FixtureScenes.swift` copy of its own
/// (unlike `MKModelTests`/`MKPersistenceTests`, which already share this
/// exact file verbatim per that file's own header note on why SPM test
/// targets duplicate rather than share fixture source) ، this reuses that
/// generator's exact construction, it does not invent a different one.
private enum MemoryStressFixtureScenes {
    static func flatNodesScene(count: Int) -> MKScene {
        var nodes: [MKNode] = []
        nodes.reserveCapacity(count)
        for i in 0..<count {
            let core = MKNodeCore(name: "عنصر \(i)", zOrder: i)
            nodes.append(.shape(MKShapeNode(core: core, geometry: .rect(cornerRadius: 4))))
        }
        return MKScene(canvas: MKCanvasSpec(size: CGSize(width: 1080, height: 1350)), nodes: nodes)
    }
}

@Suite struct MemoryStressDriveTests {
    /// Ordered, actor-serialized event log ، identical role to the sibling
    /// `MemoryGovernorIntegrationTests.OrderLog` (duplicated here, not
    /// imported, since it is a private nested type of that file's `@Suite`
    /// struct and this is a separate file/suite).
    actor OrderLog {
        private(set) var events: [String] = []
        func record(_ event: String) { events.append(event) }
    }

    /// Adapts the REAL `MKPersistence.AutosaveController` to `MKRender`'s
    /// `MKAutosaveTriggering` seam, so `MKDegradationController` drives
    /// actual `scene.json`/`manifest.json`/`journal.mkj` I/O at each stage
    /// transition ، not a synthetic stand-in (see the file header's note on
    /// why this differs from `MemoryGovernorIntegrationTests`'
    /// `RecordingAutosave`). Mirrors exactly the two call shapes
    /// `MakhtootDocument.saveNow(reason:)` already uses in production
    /// (`Sources/MKPersistence/MakhtootDocument.swift`): stage 1/2 →
    /// `autosave.flushNow(...)`; critical → `autosave.criticalJournalFlush`
    /// with a journaled no-op command anchored to the current scene's
    /// revision hash (`MKSceneRevision.hash`, hence the one `@testable
    /// import MKPersistence` above ، that type is internal, mirroring how
    /// `MakhtootDocument.saveNow` computes the exact same baseRev
    /// internally). The event is logged only AFTER the real save call
    /// returns, so the ordering assertions below prove the REAL I/O
    /// happened before eviction, not just that this adapter was invoked
    /// before eviction.
    actor RealAutosaveAdapter: MKAutosaveTriggering {
        private let autosave: AutosaveController
        private let log: OrderLog
        private let title: String
        private let sceneProvider: @Sendable () -> MKScene

        init(autosave: AutosaveController, log: OrderLog, title: String, sceneProvider: @escaping @Sendable () -> MKScene) {
            self.autosave = autosave
            self.log = log
            self.title = title
            self.sceneProvider = sceneProvider
        }

        func flushForMemoryPressure(stage: MKMemoryStage) async {
            let reason: MKSaveReason = (stage == .stage1) ? .memoryPressureStage1 : .memoryPressureStage2
            try? await autosave.flushNow(scene: sceneProvider(), referencedAssets: [], title: title, reason: reason)
            await log.record("save:\(stage)")
        }

        func flushJournalOnly() async {
            let scene = sceneProvider()
            let baseRev = MKSceneRevision.hash(scene)
            // Same "durability of whatever is already true" no-op-marker
            // shape `MakhtootDocument.saveNow(reason: .memoryPressureCritical)`
            // journals ، D-223: the critical flush's job is not to invent a
            // new mutation, only to guarantee the journal chain has a valid
            // anchor at the current revision.
            try? await autosave.criticalJournalFlush(command: MKNoOpCommand(name: "ضغط الذاكرة الحرج"), baseRev: baseRev)
            await log.record("save:journalOnly")
        }
    }

    /// A byte-counted stand-in for a large in-memory cache (the "ballast
    /// allocator") ، same shape as the sibling `MemoryGovernorIntegrationTests
    /// .BallastAccountable`, sized per this task's spec: 200 MB total, an
    /// 80 MB offscreen-reclaimable portion.
    actor BallastAccountable: MKMemoryAccountable {
        private(set) var heldBytes: Int
        private let offscreenBytes: Int
        private let log: OrderLog

        init(totalBytes: Int, offscreenBytes: Int, log: OrderLog) {
            self.heldBytes = totalBytes
            self.offscreenBytes = offscreenBytes
            self.log = log
        }

        func accountedBytes() async -> Int { heldBytes }

        func evictOffscreen() async {
            heldBytes = max(0, heldBytes - offscreenBytes)
            await log.record("evictOffscreen")
        }

        func evictAll() async {
            heldBytes = 0
            await log.record("evictAll")
        }
    }

    @Test
    func fiveThousandNodeDriveSavesBeforeEachDegradeStageAndSurvivesAZeroLossRelaunch() async throws {
        // 1. The real 5000-node scene ، reused, not reinvented.
        let scene = MemoryStressFixtureScenes.flatNodesScene(count: 5000)
        #expect(scene.nodes.count == 5000)

        // 2. A real on-disk `.makhtoot` package (mirrors the setup
        // `AutosaveControllerTests.makeAutosaveTestEnvironment()` and
        // `FixtureGenerator.ensure(...)` both use: `DocumentPackage.create`
        // then a direct `writeScene` to seed real content) in a temp
        // directory, plus a real `AutosaveController`/`CommandJournal`
        // wired to it exactly like `MakhtootDocumentTests`' own setup.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-memory-stress-drive-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("proj.makhtoot")
        let title = "اختبار ضغط الذاكرة"

        let package = try DocumentPackage.create(at: url, projectID: MKProjectID(), title: title, canvas: scene.canvas)
        try package.writeScene(scene)   // real on-disk 5000-node state to prove save/relaunch against

        let assetStore = MKAssetStore(package: package)
        let journal = CommandJournal(journalURL: package.journalURL)
        let autosave = AutosaveController(package: package, assetStore: assetStore, journal: journal)

        let log = OrderLog()
        let adapter = RealAutosaveAdapter(autosave: autosave, log: log, title: title, sceneProvider: { scene })

        // A large ballast (200 MB / 80 MB offscreen-reclaimable) standing in
        // for a real in-memory cache the ladder is responsible for draining.
        let governor = MKMemoryGovernor()
        let ballast = BallastAccountable(totalBytes: 200_000_000, offscreenBytes: 80_000_000, log: log)
        await governor.register(ballast)

        let controller = await MKDegradationController(autosave: adapter, governor: governor)

        let bytesBeforeAnyPressure = await governor.totalAccountedBytes()
        #expect(bytesBeforeAnyPressure == 200_000_000)

        // 3a. Stage 1 (70%): INV-17/D-223 ، save completes BEFORE eviction,
        // and only the offscreen-reclaimable 80 MB drains (mirrors
        // `MemoryGovernorIntegrationTests.stage1TransitionDrainsOnly
        // OffscreenBytesFromTheRegisteredBallast`, this time against a real
        // autosave path instead of a synthetic recorder).
        await controller.forceTransition(to: .stage1)

        let bytesAfterStage1 = await governor.totalAccountedBytes()
        #expect(bytesAfterStage1 == 120_000_000)
        let eventsAfterStage1 = await log.events
        #expect(eventsAfterStage1 == ["save:stage1", "evictOffscreen"])

        // The stage1 "save" event above was a REAL scene.json/manifest.json
        // write, not just ladder-internal bookkeeping ، confirm the write
        // actually happened via AutosaveController's own diagnostic counter.
        let fullSavesAfterStage1 = await autosave.fullSaveCount
        #expect(fullSavesAfterStage1 == 1)

        // 3b. Critical: D-223 ، journal-only flush (never `flushNow`), then
        // the ballast's full nuclear drain.
        await controller.forceTransition(to: .critical)

        let bytesAfterCritical = await governor.totalAccountedBytes()
        #expect(bytesAfterCritical == 0)
        let eventsAfterCritical = await log.events
        #expect(eventsAfterCritical == ["save:stage1", "evictOffscreen", "save:journalOnly", "evictAll"])

        // D-223 invariant, checked against the REAL AutosaveController: the
        // critical transition must NOT have produced a second full-scene
        // write ، only the journal grew.
        let fullSavesAfterCritical = await autosave.fullSaveCount
        let journalFlushesAfterCritical = await autosave.journalOnlyFlushCount
        #expect(fullSavesAfterCritical == 1)   // unchanged since stage1 ، no re-encode at critical
        #expect(journalFlushesAfterCritical == 1)

        let journalDataAfterCritical = try Data(contentsOf: package.journalURL)
        #expect(!journalDataAfterCritical.isEmpty)   // the critical no-op marker actually landed on disk

        // 4. Zero-loss relaunch: reopen the package exactly the way
        // production code does (`MakhtootDocument.open(at:)`, the same
        // entry point `MakhtootDocumentTests`' D-115 gates and WS-02's
        // crash-recovery tests already exercise) ، this runs REAL crash
        // recovery, replaying `journal.mkj` (the critical-stage no-op
        // marker) on top of `scene.json` (still the 5000-node scene; the
        // critical stage never touched it). A fresh process picking this
        // package back up after the simulated memory-pressure event must
        // see every one of the 5000 nodes, byte-for-byte identical to what
        // was there before the pressure event forced the critical, journal-
        // only path ، this is the "zero-loss" half of the evidence.
        let (reopened, recovery) = try await MakhtootDocument.open(at: url)

        // `MakhtootDocument` is `@MainActor`-isolated; hop once and hold a
        // local copy so both assertions below read the same snapshot.
        let reopenedScene = await reopened.scene
        #expect(reopenedScene.nodes.count == 5000)
        #expect(reopenedScene == scene)   // exact content match, not just a count coincidence
        #expect(recovery.recoveryOccurred)   // the critical-stage journal entry IS what got replayed
        #expect(recovery.replayedCommandCount == 1)
    }
}
