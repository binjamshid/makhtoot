import Foundation
import MKFoundation
import MKModel

// WS-02 packet §5 task 12. Debounced (≤2 s) incremental full-scene
// autosave + the D-223 stage-3/critical journal-only synchronous path.
// Save order (INV-7, §13.5): assets → scene.json → manifest.json →
// journal-truncate.

/// Why a save was triggered ، callers (`MakhtootDocument`, app lifecycle,
/// WS-07's memory-pressure ladder) pass this so `AutosaveController` can
/// route stage-3/critical triggers to the journal-only path per D-223,
/// never to a full re-encode.
public enum MKSaveReason: Sendable, Equatable {
    case debounced
    case background
    case documentClose
    case beforeExport
    /// Memory-pressure ladder stage 1 (70%) or 2 (85%) ، full-scene
    /// `flushNow()` still applies at these stages (D-223: "full-scene
    /// flushNow() is reserved for background and stage 1–2 triggers").
    case memoryPressureStage1
    case memoryPressureStage2
    /// Stage-3/critical ، MUST route to `criticalJournalFlush`, never
    /// `flushNow`.
    case memoryPressureCritical
}

/// Debounced autosave + journal-flush orchestration (an actor: all I/O off
/// the main thread, task 12's "<100 ms off main thread" budget).
public actor AutosaveController {
    private let package: DocumentPackage
    private let assetStore: MKAssetStore
    private let journal: CommandJournal
    private let debouncer: MKDebouncer
    private let debounceInterval: Duration

    private var lastSavedSceneHash: String?
    private var lastSavedAssetRefs: Set<MKAssetRef> = []

    /// Diagnostics for tests: counts real `scene.json`/`manifest.json`
    /// writes vs. journal-only flushes, so a mutation-storm test can
    /// assert "≤2 writes" without timestamp-polling the filesystem.
    public private(set) var fullSaveCount = 0
    public private(set) var journalOnlyFlushCount = 0

    /// Total COMPLETED flush operations (every `flushNow` return ،
    /// including hash-unchanged no-write passes ، plus every
    /// `criticalJournalFlush`). Distinct from `fullSaveCount`, which
    /// counts only actual `scene.json` writes. Drives `awaitFlushes`.
    public private(set) var completedFlushCount = 0
    private var flushWaiters: [CheckedContinuation<Void, Never>] = []

    public init(package: DocumentPackage, assetStore: MKAssetStore, journal: CommandJournal, debounceInterval: Duration = .seconds(2)) {
        self.init(
            package: package, assetStore: assetStore, journal: journal,
            debounceInterval: debounceInterval, scheduler: MKTaskSleepScheduler()
        )
    }

    /// Test seam (WS-02 session 3): inject a manual `MKDelayScheduling` so
    /// the debounce settle can be driven deterministically instead of
    /// raced against wall-clock sleeps. Internal ، production callers
    /// always go through the public init above (identical behavior:
    /// `MKTaskSleepScheduler` is a plain `Task.sleep`).
    init(
        package: DocumentPackage, assetStore: MKAssetStore, journal: CommandJournal,
        debounceInterval: Duration, scheduler: any MKDelayScheduling
    ) {
        self.package = package
        self.assetStore = assetStore
        self.journal = journal
        self.debounceInterval = debounceInterval
        self.debouncer = MKDebouncer(scheduler: scheduler)
    }

    /// Suspends until the total completed-flush count reaches at least
    /// `target`. Registration-race-free by construction: the counter is
    /// checked BEFORE suspending (on this actor), so a flush that already
    /// completed satisfies the wait immediately ، there is no window where
    /// a completion can slip between "check" and "register waiter".
    public func awaitFlushes(atLeast target: Int) async {
        while completedFlushCount < target {
            await withCheckedContinuation { flushWaiters.append($0) }
        }
    }

    private func recordFlushCompleted() {
        completedFlushCount += 1
        let waiters = flushWaiters
        flushWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    /// Called on every mutation. (Re)starts the debounce timer; only the
    /// LAST call in a burst within `debounceInterval` actually fires a
    /// save ، this is what keeps a mutation storm to ≤2 real writes (task
    /// 12 accept criterion).
    public func scheduleDebouncedSave(
        title: String,
        sceneProvider: @escaping @Sendable () async -> MKScene,
        referencedAssetsProvider: @escaping @Sendable () async -> Set<MKAssetRef>
    ) async {
        await debouncer.schedule(after: debounceInterval) { [weak self] in
            guard let self else { return }
            let scene = await sceneProvider()
            let refs = await referencedAssetsProvider()
            try? await self.flushNow(scene: scene, referencedAssets: refs, title: title, reason: .debounced)
        }
    }

    /// Full-scene save: writes assets (via `MKAssetStore.sweepOrphans`,
    /// which also handles asset-set changes), `scene.json`, then
    /// `manifest.json` last (its `modifiedAt` is the commit marker,
    /// §13.5), then truncates the journal. Skips the scene/manifest write
    /// entirely if the scene hasn't changed since the last save
    /// (incremental strategy, task 12: "write scene.json + manifest only
    /// when scene changed").
    ///
    /// **D-223 invariant**: never call this for `.memoryPressureCritical`
    /// ، that reason MUST route to `criticalJournalFlush` instead. This
    /// method still accepts a `reason` parameter (for logging/diagnostics
    /// symmetry) but does not special-case it; the routing decision is the
    /// CALLER's responsibility (`MakhtootDocument.saveNow(reason:)`),
    /// matching the packet's framing of `flushNow()` vs. task 13's
    /// journal-only flush as two distinct entry points.
    public func flushNow(scene: MKScene, referencedAssets: Set<MKAssetRef>, title: String, reason: MKSaveReason) async throws {
        // P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 2): the
        // task packet's own task 13 row ("`autosave` (WS-02 emits, you own
        // the category taxonomy)") assigned emission to this module but no
        // prior session actually wired it ، `docs/impl-log/WS-02.md` only
        // ever instrumented `documentOpen`. Same direct
        // `beginInterval`/`endInterval` idiom `MakhtootDocument.open` already
        // uses (`MKPersistence` cannot reach `MKRender`'s convenience
        // wrapper). Spans the <100 ms off-main incremental-autosave budget
        // (D-115) ، the whole method body, not just the write, since the
        // hash-unchanged skip fast path is itself part of what "off-main
        // autosave cost" measures.
        let signpostState = MKSignpost.signposter.beginInterval("autosave")
        defer { MKSignpost.signposter.endInterval("autosave", signpostState) }
        // Recorded even on a throwing exit so an `awaitFlushes` caller can
        // never hang on a failed flush attempt (the attempt COMPLETED,
        // unsuccessfully ، `fullSaveCount` still only counts real writes).
        defer { recordFlushCompleted() }
        await debouncer.cancel()

        let sceneHash = MKSceneRevision.hash(scene)
        let sceneChanged = sceneHash != lastSavedSceneHash
        let assetsChanged = referencedAssets != lastSavedAssetRefs

        if assetsChanged {
            try await assetStore.sweepOrphans(referencedBy: referencedAssets)
            lastSavedAssetRefs = referencedAssets
        }

        if sceneChanged {
            try package.writeScene(scene)
            var manifest = (try? package.readManifest()) ?? MKManifest(
                projectID: MKProjectID(), schemaVersion: scene.schemaVersion, title: title, canvas: scene.canvas
            )
            manifest.modifiedAt = Date()
            manifest.title = title
            manifest.schemaVersion = scene.schemaVersion
            manifest.canvas = scene.canvas
            try package.writeManifest(manifest)
            lastSavedSceneHash = sceneHash
            fullSaveCount += 1
        }

        try await journal.truncate()
    }

    /// D-223 stage-3/critical: synchronous-ish, append-only journal flush
    /// ONLY. No `scene.json` re-encode, no manifest write, no new large
    /// allocation beyond the one command's own encoded size ، this is the
    /// entire critical-path operation.
    public func criticalJournalFlush(command: any MKCommand, baseRev: String) async throws {
        defer { recordFlushCompleted() }
        await debouncer.cancel()
        try await journal.append(command: command, baseRev: baseRev)
        journalOnlyFlushCount += 1
    }

    // MARK: - Test/diagnostic hooks

    public func resetCounters() {
        fullSaveCount = 0
        journalOnlyFlushCount = 0
    }

    public func lastSavedRevision() -> String? { lastSavedSceneHash }
}
