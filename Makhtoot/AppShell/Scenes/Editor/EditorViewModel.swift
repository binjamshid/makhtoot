import CoreGraphics
import CoreText
import Foundation
import MKAssets
import MKCanvas
import MKExport
import MKFoundation
import MKModel
import MKPathText
import MKPersistence
import MKRender
import Observation
import UIKit

/// The real editor composition's view-model spine (WS-13 P4 EDITOR-CHROME
/// session, packet T11): opens a REAL `MakhtootDocument` (WS-02
/// `MKPersistence`), wires WS-06's `CanvasSession`/`LayersModel`/
/// `InspectorModel` to it, and bridges WS-07's real `MKLayerTreeController`/
/// `HitTester` in via `MKCanvasRenderAdapter`. This is the "swap the stub
/// canvas host for the real composition" step `docs/impl-log/WS-13.md`
/// Session 1/2 both explicitly deferred, pending WS-06/WS-07 landing.
@MainActor
@Observable
final class EditorViewModel {
    let projectID: MKProjectID
    let packageURL: URL
    let document: MakhtootDocument
    let session: CanvasSession
    let layers: LayersModel
    let inspector: InspectorModel
    let renderAdapter: MKCanvasRenderAdapter
    let recovery: MKCrashRecoveryResult

    /// P7.1 (§2.2 project thumbnails, Bug 1): the browser's metadata seam,
    /// needed ONLY so the editor-close thumbnail regeneration (a
    /// fire-and-forget background render, see `generateThumbnailInBackground()`)
    /// can update `MKProjectRecord.thumbnailPath` once the render actually
    /// finishes ، the package-level write (`thumbnail.png` +
    /// `MKManifest.thumbnail`) needs nothing beyond `packageURL`/`document`
    /// this type already holds.
    private let projectLibrary: any ProjectLibraryProviding

    /// FC-1 (AUDIT_2026-07-28.md): the real `MKFontProviding` conformer
    /// (`container.fontProvider`, `MKRegistryFontProvider` ، WS-09
    /// `MKFonts`), injected here so every render/export path below reads
    /// the SAME font provider the font-settings sheet's bold/italic toggle
    /// (`FontSettingsSheet.swift`) already writes into the model. Before
    /// this fix, every one of the seven call sites this property now
    /// replaces constructed its own throwaway `SystemFontStubProvider()`
    /// ، which inherits `MKFontProviding`'s protocol-extension default for
    /// `resolve(_:variant:)` (`MKFoundation/Stubs/MKFontProviding.swift:
    /// 65-67`) and silently discards the requested bold/italic variant, so
    /// tapping **B**/**I** changed the model, marked the document dirty,
    /// pushed an undo entry, and rendered IDENTICALLY on canvas and in
    /// every export. `container.fontProvider` was constructed and exposed
    /// (`AppContainer.swift:202`) but never actually injected anywhere ،
    /// FC-6's `CompositionRootWiringTests` is the regression net for
    /// exactly this class of gap.
    private let fontProvider: any MKFontProviding

    /// P5.3: the app-target `MKAssetProviding` adapter (see
    /// `BackgroundImageSupport.swift`'s header for why this closes a real,
    /// previously-unreachable gap in image rendering, not just a background-
    /// image-specific seam). Wired into `layerTree` (screen) and every
    /// `MKSnapshotRenderer`/`MKExportCoordinator` call site below (export/
    /// thumbnail) so canvas ⇄ export stay in parity for ANY raster image
    /// content, not only backgrounds.
    private let assetProvider: MKDocumentAssetProvider

    /// Arrange Mode (packet task 15, PRD §6-§8). `arrangeAdapter` is held
    /// strongly here ، `arrangeInteraction.engine` is `weak` (same
    /// injection pattern `session.geometrySource`/`.renderBridge` already
    /// use), so this is the ONE strong reference keeping it alive, exactly
    /// the footgun `docs/impl-log/WS-06.md`'s own "weak var + inline
    /// temporary test doubles" note warns test authors about ، here it's
    /// production wiring, so the `let` binding at this scope IS the fix.
    let arrangeInteraction: MKArrangeInteractionModel
    private let arrangeAdapter: MKArrangeInteractionAdapter

    /// Path-Edit Mode (packet task 16, PRD §9/FL-8) ، the Path-Text twin of
    /// `arrangeInteraction`/`arrangeAdapter` immediately above, same "own
    /// the adapter strongly, inject it as the model's `weak` engine"
    /// wiring (see that pair's own doc comment for the footgun this
    /// avoids).
    let pathTextInteraction: MKPathTextInteractionModel
    private let pathTextAdapter: MKPathTextInteractionAdapter

    /// R-9.4 path options popover presentation state (`PathOptionsPopoverView`).
    var presentedPathOptions = false

    /// R-9.9 "إظهار المسار" (show path) ghost-guide toggle ، applies while
    /// an ARRANGED node whose `derivedFrom` is `.pathText(...)` is in
    /// Arrange Mode (see `arrangedGhostGuidePath` below, which also gates
    /// on `arrangeInteraction.activeOwnerNode` actually being such a
    /// node ، this flag alone does not force the overlay to show for an
    /// unrelated arranged composition).
    var showsPathGhostGuide = false

    /// R-9.9's "the frozen path... it never renders in export": this is
    /// read ONLY by `EditorScene`'s pure-SwiftUI `PathGhostGuideOverlay`
    /// (an overlay `Shape` drawn in the canvas `ZStack`, never touched by
    /// `MKRender`/`MKSnapshotRenderer`/export) ، satisfying the
    /// never-in-export requirement BY CONSTRUCTION, not by a runtime flag
    /// export code has to remember to check.
    var arrangedGhostGuidePath: MKBezierPathData? {
        guard showsPathGhostGuide, let node = arrangeInteraction.activeOwnerNode else { return nil }
        guard case .pathText(let path) = node.derivedFrom else { return nil }
        return path
    }

    /// R-6.11: arrange-then-edit-source conflict ، set when the user
    /// double-taps an already-arranged composition while browsing (not
    /// inside Arrange Mode). Drives `EditorScene`'s confirmation-dialog
    /// binding directly.
    var arrangeSourceEditConflictNodeID: MKNodeID?
    /// R-6.12/FL-13: revert confirmation state.
    var pendingRevertPreflight: MKArrangeRevertPreflight?
    /// R-8.3: form-selector popover state.
    var presentedFormSelectorModel: MKArrangeFormSelectorModel?
    /// R-8.12/D-221: recompose confirmation state (`groupID` + edited-count
    /// preflight).
    var pendingRecomposeConfirmation: (groupID: MKNodeID, preflight: MKArrangeRecomposePreflight)?
    /// R-8.10: transient "fidelity mode was auto-refused" notice.
    var decomposeFidelityNotice: String?
    /// R-7.5 "attach to letter": armed after "فصل الحركة"/an explicit
    /// re-attach request ، the NEXT tap on a glyph while armed completes
    /// the attach instead of a plain selection change. `EditorScene`/
    /// `ArrangeToolbarView` reads this to show an armed-state affordance.
    var pendingMarkReattachID: MKNodeID?

    /// iPad persistent-column visibility (T12 adaptivity); iPhone instead
    /// drives `presentedPanel` as a sheet ، see `EditorScene`.
    var showsLayersColumn = false
    var showsInspectorColumn = false
    var presentedPanel: EditorPanel?

    #if DEBUG
    /// DEBUG-only perf HUD toggle (WS-07's deferred `PerfHUDView` seam ،
    /// see `MKRenderPerfHUDDataSource`/`MKRenderPerfSnapshot`,
    /// `MakhtootKit/Sources/MKRender/RenderSignposts.swift`).
    var showsPerfHUD = false
    /// `@ObservationIgnored`: the `@Observable` macro cannot wrap a `lazy`
    /// stored property (its init-accessor synthesis requires an eagerly-
    /// initialized backing store) ، this value never needs to be an
    /// observation-tracked dependency itself (only its OUTPUT, read via
    /// `currentPerfSnapshot()` on a plain poll timer in `PerfHUDView`, is
    /// ever displayed), so opting it out of tracking is correct, not a
    /// workaround.
    @ObservationIgnored private(set) lazy var perfHUDDataSource: EditorPerfHUDDataSource = EditorPerfHUDDataSource(viewModel: self)
    var lastManipulationFrameDuration: TimeInterval = 0
    #endif

    /// Subtle autosave indicator (T11 AC: "autosave indicator (subtle,
    /// from MKPersistence status)"). Approximated from the document's
    /// `sceneUpdates` stream (every mutation marks dirty; a 2.2 s-since-
    /// last-mutation timer clears it ، matching D-112's ≤2 s debounce
    /// window with a small margin) since `AutosaveController`'s counters
    /// are actor-internal and not published as a live signal.
    private(set) var isDirty = false
    private var lastMutationAt: Date?

    /// D-116 memory-pressure banner (T11 AC: "banner region renders when
    /// WS-07 stub emits stage 2"). Real `MKDegradationController` +
    /// `MKMemoryPressureMonitor` (WS-07), driving a real
    /// `MakhtootDocument.saveNow(reason:)` flush before any degrade
    /// (INV-17/D-223) via `DocumentAutosaveTrigger` below.
    private(set) var memoryBannerText: String?
    private let degradation: MKDegradationController
    private var memoryMonitor: MKMemoryPressureMonitor?

    private var sceneObservationTask: Task<Void, Never>?
    private var dirtyClearTask: Task<Void, Never>?
    private var memoryPollTask: Task<Void, Never>?
    /// P-2/P-3 (AUDIT_2026-07-28.md): last zoom scale reported through
    /// MKCanvasViewController.onViewportChanged (the real
    /// scrollViewDidZoom(_:)/scrollViewDidScroll(_:) delegate callbacks,
    /// replacing the old 150ms poll this property used to be deduped
    /// against). Still epsilon-compared before assigning currentZoomScale
    /// below: scrollViewDidScroll can fire many times per second during a
    /// pure pan (no zoom change at all), and currentZoomScale is
    /// @Observable state the zoom-percentage badge reads, so an
    /// unconditional assignment on every callback would invalidate that
    /// whole view tree far more often than the value actually changes.
    private var lastReportedZoomScale: CGFloat = 1
    /// Public zoom-scale reading for zoom controls — updated live from
    /// MKCanvasViewController.onViewportChanged so the percentage badge
    /// tracks every real zoom change with no polling latency.
    private(set) var currentZoomScale: CGFloat = 1
    /// P-2: last-observed session.mode/session.selection.ids, diffed
    /// against inside handleModeOrSelectionChange() ، the
    /// withObservationTracking replacement for the old 100ms poll's own
    /// lastMode/lastSelection locals. nil until
    /// startModeAndSelectionObservation() first runs (from attach(
    /// canvasViewController:)), matching the old poll's own lifecycle
    /// (nothing to observe before a canvas exists to sync chrome against).
    private var lastObservedMode: MKCanvasMode?
    private var lastObservedSelectionIDs: Set<MKNodeID>?
    /// P-2: UIApplication background/foreground observer tokens for
    /// observeScenePhaseForMemoryLadder() ، this view model is not a
    /// SwiftUI View, so @Environment(\.scenePhase)
    /// (ProjectBrowserView.swift's own pattern this mirrors) isn't
    /// available here; the UIKit-level notification pair is the
    /// equivalent signal reachable from a plain @MainActor class.
    private var didEnterBackgroundObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?

    /// The live text overlay (D-104) ، owned here (not by the UIKit
    /// representable's own coordinator) so toolbar chrome AND the DEBUG
    /// programmatic-typing hook (see `debugSetActiveOverlayText`) share one
    /// source of truth.
    private(set) weak var canvasViewController: MKCanvasViewController?
    private var overlayView: TextEditingOverlayView?

    /// EU-3 (AUDIT_2026-07-28.md): this project's last-known zoom/offset/
    /// selection, loaded once at `init` and consumed exactly once, the
    /// first time `attach(canvasViewController:)` runs ، `nil` after that.
    /// See the "MARK: - EU-3 state restoration" section below for the full
    /// mechanism and why it lives entirely inside this file.
    private var pendingRestorationState: EditorRestorationState?
    /// EU-3: throttle gate for `persistRestorationCheckpointThrottled()`'s
    /// high-frequency `onViewportChanged` call site.
    private var lastRestorationPersistAt: Date = .distantPast

    init(projectID: MKProjectID, rootURL: URL, projectLibrary: any ProjectLibraryProviding, fontProvider: any MKFontProviding) async throws {
        let (document, recovery) = try await MakhtootDocument.open(at: rootURL)
        self.projectID = projectID
        self.packageURL = rootURL
        // EU-3: read-only here ، `session`/`canvasViewController` don't
        // exist yet, so applying it has to wait for
        // `attach(canvasViewController:)` below. Uses the `projectID`
        // PARAMETER, not `self.projectID`, so this can run before every
        // stored property is set (a plain `static` call needs no `self`).
        self.pendingRestorationState = Self.loadRestorationState(for: projectID)
        self.document = document
        self.recovery = recovery
        self.projectLibrary = projectLibrary
        self.fontProvider = fontProvider

        // S-5: this session's fence forbids touching launch code outside
        // `MKPersistence`/this file (AUDIT_2026-07-28.md's fix explicitly
        // allows "a hook it exposes" as the stand-in for "purge once at app
        // launch") ، editor-session OPEN is the closest available choke
        // point, and this app's navigation model only ever has one editor
        // session live at a time (a project is opened, then closed via
        // `EditorScene.finish(_:)`/`close()` above, before another can
        // open), so purging here can never race a DIFFERENT session's
        // in-flight export the way purging on, say, a timer could.
        ExportTempDirectory.shared.purge()

        let session = CanvasSession(document: document)
        self.session = session
        self.layers = LayersModel(session: session)
        self.inspector = InspectorModel(session: session)

        let arrangeAdapter = MKArrangeInteractionAdapter(fonts: fontProvider)
        self.arrangeAdapter = arrangeAdapter
        let arrangeInteraction = MKArrangeInteractionModel(session: session)
        arrangeInteraction.engine = arrangeAdapter
        self.arrangeInteraction = arrangeInteraction

        let pathTextAdapter = MKPathTextInteractionAdapter(fonts: fontProvider)
        self.pathTextAdapter = pathTextAdapter
        let pathTextInteraction = MKPathTextInteractionModel(session: session)
        pathTextInteraction.engine = pathTextAdapter
        self.pathTextInteraction = pathTextInteraction

        // P14 hardening pass (docs/impl-log/WS-07-p14.md): the memory
        // governor + degradation controller are constructed BEFORE the
        // layer tree now (previously the layer tree was built first with no
        // `degradationController:` argument at all ، a real gap: the
        // already-tested stage-fidelity/half-res wiring in
        // `MKLayerTreeController` was never actually reachable from a
        // running app, only from `PerfHarnessTests`). `MKMemoryGovernor`
        // (new, `MKFoundation`) is the cross-module cache registry
        // ARCHITECTURE §12.3 calls for; `layerTree` registers itself below
        // once constructed, so D-116 stage transitions now evict REAL
        // on-canvas bitmap bytes, not just flip a fidelity flag.
        let governor = MKMemoryGovernor()
        let degradation = MKDegradationController(
            autosave: DocumentAutosaveTrigger(document: document),
            governor: governor
        )
        self.degradation = degradation

        let screenScale = UITraitCollection.current.displayScale
        // FC-1 (AUDIT_2026-07-28.md): `layerTree` (the live canvas render
        // tree) now reads through the injected `fontProvider` (this file's
        // own stored-property doc comment above has the full history) ،
        // NOT a throwaway `SystemFontStubProvider()`, so a bold/italic
        // request actually reaches `MKRegistryFontProvider.resolve(_:
        // variant:)`'s real weight/slant-axis resolution instead of
        // silently falling through the protocol-extension default that
        // ignores `variant` entirely.
        // P5.3: the asset provider must exist BEFORE `layerTree` (its
        // `assets:` argument) and before export/thumbnail call sites read
        // it later ، see `BackgroundImageSupport.swift` for why this wasn't
        // wired at all before this session (a real, previously-unreachable
        // gap, not a pre-existing seam this feature merely extends).
        let assetProvider = MKDocumentAssetProvider(assetStore: document.assetStoreHandle())
        self.assetProvider = assetProvider

        let layerTree = MKLayerTreeController(
            fonts: fontProvider,
            assets: assetProvider,
            screenScale: screenScale > 0 ? screenScale : 2,
            degradationController: degradation
        )
        let adapter = MKCanvasRenderAdapter(layerTree: layerTree)
        self.renderAdapter = adapter
        session.geometrySource = adapter
        session.renderBridge = adapter

        sceneObservationTask = nil
        dirtyClearTask = nil
        memoryPollTask = nil

        startSceneObservation()
        startMemoryLadder(with: degradation)
        // P14: register the live layer tree's real bitmap bytes with the
        // governor ، `await` is fine here, `init` is already `async throws`.
        await governor.register(layerTree, priority: .standard)
        // P5.3: the asset provider's decode cache is a real bitmap cost too
        // (full-resolution ingested images) ، same P14 registration pattern.
        await governor.register(assetProvider, priority: .standard)
        // P-5 (AUDIT_2026-07-28.md): the undo stack's own worst-case entry
        // (an `MKInsertNodeCommand` holding an ENTIRE removed node ، e.g. a
        // full arranged composition, per `Commands.swift`'s doc comment)
        // was a real, previously-unreachable memory cost: `setMaxEntries
        // (_:)` already existed but had zero call sites anywhere in the
        // repo, so the D-116 ladder had no way to see or shrink it.
        // `.standard`, not `.offscreenFirst` ، undo/redo history isn't
        // "offscreen content" in the sense that priority distinguishes, and
        // `MKMemoryEvictionPriority` has only these two cases today (no
        // `.low`; adding one is a separate decision per this wave's fence).
        await governor.register(document.undoStack, priority: .standard)

        // P5.3: primes any raster asset the JUST-OPENED scene already
        // references (a document reopened with a persisted image
        // background/asset) ، best-effort, re-syncs the render tree once
        // done so an already-visible layer picks up the resolved bitmap
        // instead of staying on its `.missingAsset` substitution until the
        // next unrelated mutation.
        let openedScene = session.scene
        Task { [weak self] in
            await assetProvider.primeReachableAssets(in: openedScene)
            self?.renderAdapter.sync(to: self?.session.scene ?? openedScene)
        }
    }

    // MARK: - Lifecycle

    private func startSceneObservation() {
        let stream = document.sceneUpdates
        let adapter = renderAdapter
        sceneObservationTask = Task { [weak self] in
            var isFirst = true
            for await scene in stream {
                adapter.sync(to: scene)
                guard let self else { return }
                if isFirst {
                    isFirst = false
                    self.refreshCanvasChrome()
                    continue
                }
                self.markDirty()
                self.refreshCanvasChrome()
            }
        }
    }

    // `workAroundStaleLayerPositionBug()` (WS-13 Session 3's forced
    // zoom-bucket-crossing workaround for a committed transform-only
    // change never reaching the layer) is RETIRED as of WS-13 Session 4 ،
    // fixed at the source in `MKLayerTreeController` (`MKRender
    // /LayerTreeBuilder.swift`): committed transforms now apply as an
    // anchor-adjusted layer-property delta from the bitmap's baked
    // transform, with zero re-raster. See `MakhtootKit/CONTRACTS.md`
    // "P4-exit fixes" §1 and `docs/impl-log/WS-07.md`'s follow-up session
    // ("Fix A"), regression-locked by `MKRenderTests
    // /CommittedTransformSyncTests`. Retiring this saves one full-scene
    // re-rasterization pass per committed mutation.

    private func startMemoryLadder(with degradation: MKDegradationController) {
        let monitor = MKMemoryPressureMonitor(ladder: degradation)
        memoryMonitor = monitor
        Task { await monitor.start() }
        startMemoryBannerPoll()
        // P-2 (AUDIT_2026-07-28.md): "At minimum, suspend all four on
        // .background/.inactive." This view model is not a SwiftUI View
        // (no @Environment(\.scenePhase) available the way
        // ProjectBrowserView.swift reads it), so the UIKit-level
        // background/foreground notifications are the equivalent signal
        // reachable here.
        observeScenePhaseForMemoryLadder()
    }

    /// The 1s memory-banner text poll, factored out of `startMemoryLadder`
    /// so `observeScenePhaseForMemoryLadder()` below can restart it on
    /// `.didBecomeActiveNotification` after `.didEnterBackgroundNotification`
    /// stopped it ، the same task/cancellation shape the original poll
    /// always had, just callable more than once per session now.
    private func startMemoryBannerPoll() {
        memoryPollTask?.cancel()
        memoryPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                // P0.1: `memoryBannerText` has always been `@Observable`
                // state ، `EditorViewModel` itself carries the `@Observable`
                // macro, so every stored property on it (this one included)
                // was tracked from the start; that was never gated on
                // `MakhtootDocument`/`MKUndoStack` becoming `@Observable`
                // separately. `@Observable` notifies on every `set`, equal
                // or not, so the unconditional assignment this loop used to
                // make invalidated the whole editor view tree once per
                // second regardless of whether the banner text actually
                // changed ، that was always a bug, fixed here by only
                // assigning when the value differs.
                let newText = self.degradation.stage >= .stage2 ? MKDegradationController.stage2BannerText : nil
                if self.memoryBannerText != newText {
                    self.memoryBannerText = newText
                }
            }
        }
    }

    /// P-2: stops the banner poll + the actor-hosted `MKMemoryPressureMonitor`
    /// (its own internal `DispatchSource`/2s sampling loop, `MemoryPressureMonitor.swift`)
    /// while backgrounded, and restarts both on return to foreground ،
    /// `MKMemoryPressureMonitor.start()`/`.stop()` are both idempotent
    /// (that type's own doc comments), so this is safe to call even if a
    /// notification pair fires more than expected. Both observer closures
    /// are `@Sendable` (the `NotificationCenter` API's own requirement,
    /// same shape `MKUbiquitousStore.changeNotifications()` already uses
    /// elsewhere in this codebase) ، `weak self` is captured there, then a
    /// `Task { @MainActor in ... }` hop actually touches this
    /// `@MainActor`-isolated view model's state, since `queue: .main`
    /// guarantees WHERE the closure runs at runtime but is not itself
    /// proof to the Swift 6 type checker that the closure is MainActor-
    /// isolated.
    private func observeScenePhaseForMemoryLadder() {
        let center = NotificationCenter.default
        didEnterBackgroundObserver = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.memoryPollTask?.cancel()
                self.memoryPollTask = nil
                await self.memoryMonitor?.stop()
            }
        }
        didBecomeActiveObserver = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.memoryMonitor?.start()
                self.startMemoryBannerPoll()
            }
        }
    }

    /// Called once by `CanvasHostView.makeUIViewController` when the real
    /// `MKCanvasViewController` is created, so this view model can drive
    /// selection-chrome refresh + the text overlay against it.
    func attach(canvasViewController: MKCanvasViewController) {
        self.canvasViewController = canvasViewController
        canvasViewController.arrangeInteraction = arrangeInteraction
        // `MKCanvasViewController.pathTextInteraction` (`MKCanvas`) already
        // exposes this injection point ، same `didSet` → `gestureCoordinator
        // .pathTextInteraction` forwarding `arrangeInteraction` above uses
        // (confirmed by reading `MKCanvasViewController.swift`/
        // `GestureCoordinator.swift` before wiring this: the sibling
        // MakhtootKit session already added it, so no blocked item here).
        canvasViewController.pathTextInteraction = pathTextInteraction
        canvasViewController.onArrangedNodeDoubleTapped = { [weak self] nodeID in
            self?.arrangeSourceEditConflictNodeID = nodeID
        }
        // P-2/P-3 (AUDIT_2026-07-28.md): real `UIScrollViewDelegate`
        // callbacks (`scrollViewDidZoom(_:)`/`scrollViewDidScroll(_:)`,
        // both firing `onViewportChanged`) replace the old 150 ms
        // zoom-bucket poll entirely ، every genuine pan OR zoom now
        // updates the render tree's visible rect and the zoom badge at
        // the moment it happens, not up to 150 ms later. P-3's fix lives
        // HERE: `onViewportChanged` hands over `scrollView.bounds`
        // UNCONVERTED (`MKCanvasViewController`'s own doc comment on that
        // property explains why), so `vc.scrollView.convert(vc.scrollView
        // .bounds, to: vc.contentHostView)` — NOT the raw rect the
        // closure receives — is what actually reaches
        // `setVisibleRect(_:zoomScale:)`; the old poll's bug was passing
        // the raw, unconverted rect straight through.
        canvasViewController.onViewportChanged = { [weak self] _, zoomScale in
            guard let self, let vc = self.canvasViewController else { return }
            if abs(zoomScale - self.lastReportedZoomScale) > 0.0001 {
                self.lastReportedZoomScale = zoomScale
                self.currentZoomScale = zoomScale
            }
            let visibleRect = vc.scrollView.convert(vc.scrollView.bounds, to: vc.contentHostView)
            self.renderAdapter.setVisibleRect(visibleRect, zoomScale: zoomScale)
            // EU-3: checkpoints the live zoom/offset so a background kill
            // (which never reaches `close()`) still has something recent to
            // restore from. Throttled ، this closure fires on every scroll
            // frame during a pan.
            self.persistRestorationCheckpointThrottled()
        }
        renderAdapter.sync(to: session.scene)
        refreshCanvasChrome()
        startModeAndSelectionObservation()
        // EU-3: applies `pendingRestorationState`, if any, to the canvas
        // just attached above (reads it back via `self.canvasViewController`,
        // set as this method's very first statement).
        restoreViewportIfNeeded()
    }

    // MARK: - EU-3 state restoration (AUDIT_2026-07-28.md)

    /// One editor session's UI-chrome snapshot ، zoom, scroll position, and
    /// selection. Deliberately NOT scene content (node geometry, text,
    /// style, which already round-trips through `MakhtootDocument`'s own
    /// journal/scene storage and needs no help here) ، this is view-only
    /// state, persisted to plain `UserDefaults` keyed by `MKProjectID`
    /// (mirrors `AppNavigationModel.hasCompletedOnboarding`'s own
    /// UserDefaults-latch convention, `AppNavigationModel.swift:~67-81`),
    /// NOT inside the `.makhtoot` package itself ، it has no business
    /// living in a document another device might sync down via CloudKit
    /// and expect to render pixel-identically regardless of which device
    /// last had it open.
    ///
    /// **Why this lives entirely inside `EditorViewModel`, not bridged
    /// through `RootShellView`'s `@SceneStorage` the way the audit's fix
    /// note first suggests:** `EditorViewModel` is constructed exactly once,
    /// inside `EditorScene.open()` (`Makhtoot/AppShell/Scenes/Editor/
    /// EditorScene.swift`), which this wave's fence
    /// (EXECUTION_PLAN_2026-07-28.md Wave 3 Agent 3.3) forbids touching.
    /// With no way to pass a restoration payload INTO `init` from outside,
    /// or to call a `restore(_:)` method on the freshly-built instance from
    /// outside, this type has to source and apply its own restoration data
    /// end-to-end. `RootShellView`'s own EU-3 piece (see that file's
    /// `attemptStateRestorationIfNeeded()`) is scoped to what it CAN
    /// control from outside this wall: which project to navigate back into.
    private struct EditorRestorationState: Codable {
        var zoomScale: CGFloat
        var contentOffsetX: CGFloat
        var contentOffsetY: CGFloat
        var selectedNodeIDs: [MKNodeID]
    }

    private static func restorationDefaultsKey(for projectID: MKProjectID) -> String {
        "MKEditorRestoration.\(projectID.rawValue.uuidString)"
    }

    private static func loadRestorationState(for projectID: MKProjectID) -> EditorRestorationState? {
        guard let data = UserDefaults.standard.data(forKey: restorationDefaultsKey(for: projectID)) else { return nil }
        return try? JSONDecoder().decode(EditorRestorationState.self, from: data)
    }

    /// Applies `pendingRestorationState` (if any) to the just-attached
    /// canvas, then clears it. Called once, from the tail of
    /// `attach(canvasViewController:)`.
    ///
    /// Deliberately double-dispatched onto the main queue. `CanvasHostView
    /// .makeUIViewController` (`Makhtoot/AppShell/Scenes/Editor/
    /// CanvasHostView.swift` ، also outside this wave's ownable set, see
    /// this section's header comment) calls `attach(canvasViewController:)`
    /// SYNCHRONOUSLY and only THEN schedules `vc.zoomToFit()` via its own
    /// `DispatchQueue.main.async { ... }`, enqueued strictly AFTER
    /// `attach` returns. A single-level `DispatchQueue.main.async` from
    /// here would still be DEQUEUED before that later enqueue (this
    /// method's caller, `attach`, fully returns before `CanvasHostView`
    /// ever reaches its own dispatch statement, so this method's dispatch
    /// is enqueued first), so `zoomToFit()` would stomp the restored zoom
    /// scale/offset right back to fit-to-canvas one run-loop turn later.
    /// Nesting one extra `DispatchQueue.main.async` level pushes this
    /// restoration to the turn AFTER `zoomToFit()`'s already-queued closure
    /// runs: `DispatchQueue.main` is a strictly FIFO serial queue, so at
    /// the moment `attach()` returns the queue holds
    /// [thisOuterDispatch, zoomToFitDispatch] in that order; when
    /// `thisOuterDispatch` runs it enqueues `thisInnerDispatch`, which
    /// lands AFTER the already-pending `zoomToFitDispatch` ، so the queue
    /// drains `zoomToFit()` before `thisInnerDispatch` runs. This ordering
    /// is deterministic given GCD's FIFO guarantee, not a timing race.
    private func restoreViewportIfNeeded() {
        guard let state = pendingRestorationState else { return }
        pendingRestorationState = nil
        DispatchQueue.main.async { [weak self] in
            // Unwrapped ONCE here (not left as the outer closure's own
            // `Optional`), so the inner closure below re-captures a fresh
            // `[weak self]` from an unambiguous, class-typed local ، the
            // standard "re-weakify across a nested async hop" shape.
            guard let self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let vc = self.canvasViewController else { return }
                let scrollView = vc.scrollView
                let clampedZoom = min(max(state.zoomScale, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
                scrollView.setZoomScale(clampedZoom, animated: false)
                scrollView.setContentOffset(CGPoint(x: state.contentOffsetX, y: state.contentOffsetY), animated: false)
                self.lastReportedZoomScale = clampedZoom
                self.currentZoomScale = clampedZoom
                let validIDs = Set(state.selectedNodeIDs.filter { self.session.scene.node(id: $0) != nil })
                if !validIDs.isEmpty {
                    self.session.setSelection(validIDs)
                    self.lastObservedSelectionIDs = validIDs
                }
            }
        }
    }

    /// Writes the CURRENT zoom/offset/selection, unconditionally. Called
    /// from a deliberate `close()` (the final, authoritative save for that
    /// session, since `close()` also runs the ONLY time a normal "done
    /// editing" flow happens) and from a real selection change (infrequent,
    /// no throttling needed). See `persistRestorationCheckpointThrottled()`
    /// immediately below for the high-frequency viewport-change call site.
    ///
    /// This is what actually makes restoration survive an iOS-initiated
    /// background kill, the finding's own scenario: that path never reaches
    /// `close()` at all, so the checkpoint has to already be on disk from
    /// whenever the user last interacted, not written retroactively as the
    /// app is dying.
    private func persistRestorationCheckpoint() {
        guard let vc = canvasViewController else { return }
        let state = EditorRestorationState(
            zoomScale: vc.scrollView.zoomScale,
            contentOffsetX: vc.scrollView.contentOffset.x,
            contentOffsetY: vc.scrollView.contentOffset.y,
            selectedNodeIDs: Array(session.selection.ids)
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.restorationDefaultsKey(for: projectID))
        lastRestorationPersistAt = Date()
    }

    /// The `onViewportChanged` call site's own entry point ، that closure
    /// can fire many times per second during a pan/zoom gesture, so this
    /// caps actual `UserDefaults` writes to at most ~4/s rather than
    /// persisting on every single callback.
    private func persistRestorationCheckpointThrottled() {
        guard Date().timeIntervalSince(lastRestorationPersistAt) > 0.25 else { return }
        persistRestorationCheckpoint()
    }

    /// **Real bug found and fixed this session** (caught on-simulator, not
    /// by inspection): `syncOverlay()` was originally called ONLY from
    /// `CanvasHostView.updateUIViewController`, on the assumption that
    /// SwiftUI re-invokes a `UIViewControllerRepresentable`'s update method
    /// whenever an `@Observable` property READ INSIDE IT (here,
    /// `session.mode`) changes ، the same Observation integration `body`
    /// gets. In practice, committing text via the DEBUG hook (a `Menu`
    /// button action that touches no `@Observable` property any currently-
    /// displayed `View.body` happens to be tracking) left the just-
    /// committed `TextEditingOverlayView` visibly stuck on screen,
    /// overlapping the now-correctly-rendered engine text underneath it.
    /// The `session.mode` branch below is kept as a safety net for exactly
    /// that class of case (a mode change SwiftUI's own re-render happens
    /// not to observe) ، but as of P2.5/Bug 5 remedy 3, overlay TEARDOWN no
    /// longer depends on it: `TextEditingOverlayView.onFinished` (wired in
    /// `presentOverlay(for:in:)`) now tears the overlay down synchronously
    /// the moment its own `commit()`/`cancel()` runs (tap-outside, swipe-
    /// down, "تم", or losing first responder externally), so by the time
    /// this notices the mode change, `overlayView` is already `nil` and
    /// `syncOverlay()`'s call into `dismissOverlayIfNeeded()` is a harmless
    /// no-op. The branch stays only to keep PRESENTING an overlay working
    /// for any future mode transition into `.editText` that similarly
    /// dodges SwiftUI's re-render (mirroring the debug-hook case this
    /// comment originally documented).
    ///
    /// P-2 (AUDIT_2026-07-28.md): replaces the old 100 ms `Task.sleep`
    /// poll with `withObservationTracking` on `session.mode`/
    /// `session.selection.ids` (both already `@Observable` via
    /// `CanvasSession`) ، reaction is now IMMEDIATE (same run loop turn as
    /// the mutation) instead of up to 100 ms late, and zero work happens
    /// at all between real changes, replacing "wake up ~10×/s forever" with
    /// "wake up exactly when something relevant changed."
    private func startModeAndSelectionObservation() {
        lastObservedMode = session.mode
        lastObservedSelectionIDs = session.selection.ids
        trackModeAndSelection()
    }

    /// `withObservationTracking(_:onChange:)` fires `onChange` exactly
    /// ONCE per registration, the moment any property READ inside `apply`
    /// changes ، continuous observation therefore means re-registering
    /// after every fire, which this does by calling itself again from
    /// inside `onChange`. The `[weak self]` capture in `onChange` (a
    /// `@Sendable` closure, possibly invoked off the mutating thread) is
    /// what makes this self-terminating: once `EditorViewModel` is
    /// deallocated, the next fire's `guard let self` fails and the chain
    /// simply stops re-registering ، no explicit teardown needed in
    /// `close()`, unlike the `Task`-based polls this replaces.
    private func trackModeAndSelection() {
        withObservationTracking {
            _ = self.session.mode
            _ = self.session.selection.ids
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleModeOrSelectionChange()
                self.trackModeAndSelection()
            }
        }
    }

    /// The actual diff-and-react logic `startModePolling()`'s 100 ms loop
    /// used to run inline ، unchanged behavior, just event-driven now
    /// instead of polled. See `trackModeAndSelection()`'s own doc comment
    /// for why the diff (`lastObservedMode`/`lastObservedSelectionIDs`, the
    /// direct replacement for the old poll's local `lastMode`/
    /// `lastSelection` variables) is still needed even though this only
    /// runs ON a real change: `withObservationTracking` only reports THAT
    /// something tracked changed, not WHICH one, since both `session.mode`
    /// and `session.selection.ids` are read inside the same `apply` block.
    private func handleModeOrSelectionChange() {
        if session.mode != lastObservedMode {
            lastObservedMode = session.mode
            syncOverlay()
        }
        // R-7.5 "إرفاق بالحرف" completion: `GestureCoordinator` routes taps
        // through `MKArrangeInteractionModel` directly, with no callback
        // hook this app-layer "armed reattach" state can observe any other
        // way ، once a NEW glyph becomes the sole selection while a
        // reattach is armed, complete it.
        if session.selection.ids != lastObservedSelectionIDs {
            lastObservedSelectionIDs = session.selection.ids
            // EU-3: a real, infrequent selection change ، checkpoint it
            // unthrottled (unlike the viewport-change call site, this isn't
            // a high-frequency event).
            persistRestorationCheckpoint()
            if let pendingMarkID = pendingMarkReattachID,
               let newlySelected = session.selection.single, newlySelected != pendingMarkID,
               let node = arrangeInteraction.activeOwnerNode,
               case .glyph? = node.composition.child(id: newlySelected) {
                completePendingMarkReattach(baseID: newlySelected)
            }
        }
    }

    /// Public entry point `CanvasHostView.updateUIViewController` calls on
    /// every SwiftUI re-render triggered by an `@Observable` change on
    /// `session` (mode/selection) ، keeps the D-104 overlay's presence in
    /// sync with `session.mode` regardless of whether the edit began via a
    /// canvas double-tap (`GestureCoordinator`, inside `MKCanvas`) or a
    /// toolbar "add text" tap (`addLiveTextAtCenter()` below).
    func syncOverlay() {
        guard let vc = canvasViewController else { return }
        switch session.mode {
        case .editText(let nodeID):
            presentOverlay(for: nodeID, in: vc)
        default:
            dismissOverlayIfNeeded()
        }
    }

    /// The selected text node's current string, used as the sample in the
    /// font browser so users see their own text styled in each candidate face.
    var selectedTextForFontSettings: String {
        guard let id = session.selection.single else { return "" }
        switch session.scene.node(id: id) {
        case .liveText(let n): return n.text.string
        case .pathText(let n): return n.text.string
        default: return ""
        }
    }

    // MARK: - EU-4: export progress, cancellation, error surfacing

    /// True while ANY of the five export methods below is in flight ،
    /// drives `EditorScene`'s export sheet spinner + Cancel button.
    private(set) var isExporting = false
    /// Live 0→1 progress for an in-flight tiled-raster/CMYK-PDF export
    /// (`MKExportCoordinator.progressUpdates()`, EU-4) ، `nil` whenever no
    /// export is running, AND for any export whose format/size never
    /// touches the tiled path (SVG, vector PDF, or a raster export small
    /// enough to take the untiled fast path) ، `EditorScene`'s export sheet
    /// falls back to an indeterminate spinner in that case, driven by
    /// `isExporting` alone.
    private(set) var exportProgress: Double?
    /// The active export's cancellation handle ، live only while
    /// `isExporting` is true. `cancelActiveExport()` below is the only
    /// thing that touches it from outside `runExport(_:coordinator:
    /// entitlement:)`.
    private var exportCancellationToken: MKExportCancellationToken?
    /// The export sheet presents this message when an export fails or is cancelled.
    var exportFailureMessage: String?

    /// Bound to the export sheet's Cancel button (`EditorScene
    /// .ExportFormatSheet`). A no-op if no export is currently running, or
    /// if the running export already passed the point where
    /// `MKExportCoordinator`'s cooperation checks are consulted (SVG/vector
    /// PDF never check cancellation at all ، see `MKExportCancellationToken`'s
    /// own doc comment).
    func cancelActiveExport() {
        exportCancellationToken?.cancel()
    }

    /// Runs an export with progress reporting and cancellation.
    private func runExport(
        _ request: MKExportRequest,
        coordinator: MKExportCoordinator,
        entitlement: any MKEntitlementProviding
    ) async -> URL? {
        let token = MKExportCancellationToken()
        exportCancellationToken = token
        isExporting = true
        exportProgress = nil
        let progressStream = await coordinator.progressUpdates()
        let progressTask = Task { [weak self] in
            for await fraction in progressStream {
                self?.exportProgress = fraction
            }
        }
        defer {
            progressTask.cancel()
            isExporting = false
            exportProgress = nil
            exportCancellationToken = nil
        }
        do {
            let result = try await coordinator.export(
                request, scene: session.scene, entitlement: entitlement,
                filenameBase: document.title,
                destinationDirectory: ExportTempDirectory.shared.directoryURL,
                cooperation: token
            )
            return result.fileURL
        } catch {
            exportFailureMessage = Self.userFacingExportErrorMessage(for: error)
            return nil
        }
    }

    /// EU-4: maps every `MKExportError` case (plus a generic fallback for
    /// anything else `MKExportCoordinator.export(...)` could theoretically
    /// throw) to a specific, Arabic, user-facing message ، replaces the old
    /// `catch { return nil }` behavior where a failed export just silently
    /// did nothing.
    private static func userFacingExportErrorMessage(for error: Error) -> String {
        guard let exportError = error as? MKExportError else {
            // Latin gloss: an error occurred while exporting
            return "حدث خطأ أثناء التصدير"
        }
        switch exportError {
        case .cancelled:
            // Latin gloss: export was cancelled
            return "تم إلغاء التصدير"
        case .blocked(.transparentBackgroundNotSupported):
            // Latin gloss: this format does not support a transparent background
            return "هذه الصيغة لا تدعم الخلفية الشفافة"
        case .blocked(.invalidTargetSize), .degenerateTargetSize:
            // Latin gloss: the export dimensions are invalid
            return "أبعاد التصدير غير صالحة"
        case .blocked:
            // Latin gloss: an error occurred while exporting
            return "حدث خطأ أثناء التصدير"
        case .renderingProducedNoImage:
            // Latin gloss: this design could not be rendered for export
            return "تعذّر رسم هذا التصميم للتصدير"
        case .encodingFailed:
            // Latin gloss: the file could not be saved on this device
            return "تعذّر حفظ الملف على هذا الجهاز"
        case .formatNotYetImplemented:
            // Latin gloss: this format is not supported yet
            return "هذه الصيغة غير مدعومة حاليًا"
        }
    }

    /// Exports using the scene's font and asset providers. The coordinator
    /// retains its existing font embedding rules and handles tiled rendering.
    func exportForSharing(_ request: MKExportRequest, entitlement: any MKEntitlementProviding) async -> URL? {
        guard !isExporting else { return nil }
        let coordinator = MKExportCoordinator(
            renderer: MKSnapshotRenderer(fonts: fontProvider, assets: assetProvider),
            fonts: fontProvider,
            assets: assetProvider
        )
        let url = await runExport(request, coordinator: coordinator, entitlement: entitlement)
        if url != nil {
            switch request.format {
            case .jpeg, .pngOpaque, .pngAlpha:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .pdfRaster, .pdfVectorRGB, .pdfVectorCMYK, .svg:
                break
            }
        }
        return url
    }

    func close() async {
        // EU-3: the final, authoritative checkpoint for a deliberate close ،
        // do this BEFORE any teardown below that could tear down
        // `canvasViewController`/`session` state this reads.
        persistRestorationCheckpoint()
        sceneObservationTask?.cancel()
        dirtyClearTask?.cancel()
        memoryPollTask?.cancel()
        await memoryMonitor?.stop()
        // P-2: `trackModeAndSelection()`'s recursive `withObservationTracking`
        // chain needs no explicit cancellation (see its own doc comment ،
        // it self-terminates once `[weak self]` resolves to `nil`), unlike
        // these two `NotificationCenter` tokens, which DO need explicit
        // removal here or `observeScenePhaseForMemoryLadder()`'s closures
        // would keep firing against a deallocating/deallocated view model.
        if let didEnterBackgroundObserver {
            NotificationCenter.default.removeObserver(didEnterBackgroundObserver)
        }
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        dismissOverlayIfNeeded()
        // P8-5 (AUDIT_2026-08-05.md): `MKCompositionRevision`'s counter
        // table is `@MainActor` process-global, and its only per-node
        // removal path (`forget(_:)`) runs from `MKLayerTreeController
        // .sync(to:)`'s removed-node sweep over that controller's OWN
        // layers ، a controller torn down WITH this editor session is
        // simply deallocated, never synced against an emptied scene, so
        // this session's node counters would otherwise accrete forever
        // (`duplicateThenRevertForEditing` mints a fresh `MKNodeID` per
        // invocation). Clearing here is safe even if another scene were
        // somehow live: a lost counter costs at most one extra hash
        // recompute, never a wrong render ، see
        // `MKCompositionRevision.reset()`'s own doc comment.
        MKCompositionRevision.reset()
        // P7.1 (§2.2 project thumbnails, Bug 1): fire-and-forget ، the
        // render/encode/write happen off the main actor (see
        // `generateThumbnailInBackground()`'s own doc comment) and must
        // NOT be awaited here, or `EditorScene.finish(_:)` would block
        // dismissal on a render that can legitimately take a while on a
        // complex scene.
        generateThumbnailInBackground()
        try? await document.saveNow(reason: .documentClose)
        // S-5: purge every export temp file this session may have written
        // (`exportForSharing`/`exportPNGForSharing`/`exportSVGForSharing`/
        // `exportPDFVectorForSharing`/`exportPDFRasterForSharing`, all five
        // routed through `ExportTempDirectory` above) so closing the editor
        // never leaves a full-resolution export sitting in `tmp/` forever.
        ExportTempDirectory.shared.purge()
    }

    /// Stamps the CURRENT scene revision so a thumbnail regenerated by an
    /// edit made outside this close path (not applicable today ، `close()`
    /// is the sole choke point per the master plan ، but keeps the
    /// intent explicit for whoever adds a second caller, e.g. a future
    /// "share" action) is never mistaken for stale content: the filename
    /// itself never changes (`thumbnail.png`, matching `MKManifest
    /// .thumbnail`'s existing convention and `MKProjectRecordCoder`'s sync
    /// assumption), so staleness is instead prevented structurally ، this
    /// is the ONLY place that writes it, always with the scene as it stood
    /// at close time.
    ///
    /// Renders OFF the main actor (`Task.detached`) so a slow/complex scene
    /// never blocks `EditorScene.finish(_:)`'s dismissal, which only awaits
    /// `close()` itself (not this call). Capped at 600 pt on the long edge
    /// (matching the P7.1 creation-time template thumbnail's own cap) and
    /// time-boxed via a `withTaskGroup` race against a 3 s sleep: if the
    /// render hasn't produced bytes within the budget, the result is
    /// discarded (never written) rather than persisting an arbitrarily
    /// stale/expensive thumbnail. Populates BOTH storage mechanisms P7.1's
    /// audit found unwired: the in-package `MKManifest.thumbnail` filename
    /// (`MKProjectRecordCoder` already assumes this may exist and copies it
    /// during sync) and the SwiftData `MKProjectRecord.thumbnailPath` cache
    /// the browser actually reads (via `ProjectLibraryProviding
    /// .recordThumbnailGenerated(_:relativeFilename:)`).
    private func generateThumbnailInBackground() {
        let scene = session.scene
        let packageURL = self.packageURL
        let assetProvider = self.assetProvider
        let fontProvider = self.fontProvider
        let projectID = self.projectID
        let library = self.projectLibrary
        Task.detached(priority: .utility) {
            guard let pngData = await Self.renderThumbnailPNG(scene: scene, assetProvider: assetProvider, fontProvider: fontProvider) else { return }
            let package = DocumentPackage(rootURL: packageURL)
            do {
                try package.writeThumbnail(pngData)
                var manifest = try package.readManifest()
                manifest.thumbnail = "thumbnail.png"
                try package.writeManifest(manifest)
            } catch {
                return // package-level write failed ، don't advance the SwiftData record to point at nothing.
            }
            await library.recordThumbnailGenerated(projectID, relativeFilename: "thumbnail.png")
        }
    }

    /// Renders `scene` to PNG bytes at up to 600 pt on the long edge, or
    /// `nil` if rendering fails OR overruns a 3 s budget (whichever finishes
    /// first via `withTaskGroup`'s `next()`, matching `Task.detached`'s own
    /// "cooperative, not preemptive" cancellation model ، a runaway render
    /// isn't forcibly killed mid-paint, but its result is discarded and
    /// never reaches disk if the timeout task's `nil` wins the race).
    /// `nonisolated` (NOT implicitly `@MainActor`-isolated, despite living
    /// inside this `@MainActor` class): a `static func` on a global-actor
    /// type still inherits that isolation by default, which would defeat
    /// the entire point of calling this from `Task.detached` in
    /// `generateThumbnailInBackground()` above ، `nonisolated` is what
    /// actually gets the render off the main actor.
    private static nonisolated func renderThumbnailPNG(scene: MKScene, assetProvider: MKDocumentAssetProvider, fontProvider: any MKFontProviding) async -> Data? {
        let canvasSize = scene.canvas.size
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        let cap: CGFloat = 600
        let scale = min(min(cap / canvasSize.width, cap / canvasSize.height), 1)
        let region = CGRect(origin: .zero, size: canvasSize)

        return await withTaskGroup(of: Data?.self, returning: Data?.self) { group in
            group.addTask {
                // FC-1: the thumbnail the project browser shows must render
                // through the SAME font provider as the live canvas/export
                // paths above, or a bold/italic project's thumbnail would
                // permanently lie about its own content.
                let renderer = MKSnapshotRenderer(fonts: fontProvider, assets: assetProvider)
                guard let cgImage = renderer.render(scene, region: region, scale: scale, quality: .exportQuality) else { return nil }
                return UIImage(cgImage: cgImage).pngData()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return nil
            }
            guard let first = await group.next() else { return nil }
            group.cancelAll()
            return first
        }
    }

    // MARK: - Dirty/autosave indicator

    private func markDirty() {
        isDirty = true
        lastMutationAt = Date()
        dirtyClearTask?.cancel()
        dirtyClearTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2200))
            guard let self, !Task.isCancelled else { return }
            if let last = self.lastMutationAt, Date().timeIntervalSince(last) >= 2.2 {
                self.isDirty = false
            }
        }
    }

    /// Forces a save right now (toolbar-driven manual save affordance /
    /// pre-export use), bypassing the debounce.
    func saveNow() async {
        try? await document.saveNow(reason: .debounced)
        isDirty = false
    }

    // MARK: - Canvas chrome refresh

    /// `MKCanvasViewController.refreshSelectionChrome()` is private to
    /// `MKCanvas` (this session's fence forbids editing package sources to
    /// expose it) ، `scrollViewDidZoom(_:)` is the one PUBLIC method that
    /// already calls it as a side effect (it's the real
    /// `UIScrollViewDelegate` callback), so re-invoking it with the
    /// current scroll state is the sanctioned way to force a chrome
    /// refresh after an externally-driven mutation (undo/redo, inspector
    /// field edit, layers-panel action) that didn't go through the
    /// on-canvas gesture recognizers.
    func refreshCanvasChrome() {
        guard let vc = canvasViewController else { return }
        vc.scrollViewDidZoom(vc.scrollView)
    }

    // MARK: - Toolbar-driven content creation (T11/packet task 12 API)

    /// **Real bug found and fixed this session** (caught by on-simulator
    /// verification, not by inspection): `CanvasContentAPI.addLiveText`
    /// (`MKCanvas`, outside this session's fence) constructs the new
    /// node's `MKNodeCore` with NO `style:` parameter, so it always gets
    /// `MKStyle.default` ، `fill: .none`. A freshly added Live Text node
    /// is therefore genuinely INVISIBLE (not just hard to see: `LiveTextDrawer
    /// .drawRun` only calls `ctx.setFillColor` inside `if case .solid(let
    /// color) = node.core.style.fill`, so `.none` skips painting a fill
    /// color at all) until something sets a fill. `CanvasContentAPI` has
    /// no parameter to inject one at creation, so this composes a
    /// follow-up `MKBatchCoreCommand` immediately after the insert ،
    /// exactly the same primitive `InspectorModel.setFill` already uses ،
    /// giving new text a sane ink-dark default fill, matching how every
    /// mainstream editor's "add text" tool behaves. Two undo entries
    /// result (insert, then default-fill) rather than one; documented as
    /// a minor, acceptable granularity wrinkle in the final report, not
    /// silently smoothed over.
    /// **P2.1 investigation, resolved (not assumed): this `- 110 / - 20`
    /// offset is CORRECT for live text and must NOT be "fixed" the way
    /// P1.4 fixed the analogous-looking shape offset.** Read
    /// `MKNodeLocalBounds.localBounds(of:)` (`MKRender/Geometry/
    /// NodeLocalBounds.swift`) before touching this: for `.shape`, local
    /// geometry is unit-square-CENTERED on the origin (`ShapeDrawer`'s own
    /// convention, P1.4's finding), so a shape's `core.transform.position`
    /// already IS its center ، subtracting anything there pushed shapes
    /// off-center, which was the P1.4 bug. For `.liveText`, `localBounds`
    /// (`textBounds(text:style:frame:)`) returns
    /// `CGRect(x: 0, y: 0, width:, height:)` ، origin at `(0, 0)`, NOT
    /// centered ، and `MKTransform2D.affineTransform` maps local `(0, 0)`
    /// straight to `position` (scale→rotate→translate, translation last;
    /// `MKTransform2D.swift`'s own doc comment). So a Live Text node's
    /// `position` is its TOP-LEFT corner, confirmed independently by
    /// `LiveTextDrawer.draw`/`drawLine`, which always starts painting at
    /// local `origin.x == 0` (never `-width/2`). Subtracting half of a
    /// guessed size here is therefore the textbook-correct move to CENTER
    /// a top-left-anchored box on the canvas center ، genuinely different
    /// text-positioning convention from shapes, not the same bug. Left
    /// unchanged; `110`/`20` remain a guess only because this call site has
    /// no real text/size yet (blank placeholder, immediate inline edit) ،
    /// `insertTextFromSheet(...)` below uses this exact same top-left
    /// convention but with REAL measured sizes instead of a guess, now
    /// that P2.1 gives it real text/font/size before insertion.
    @discardableResult
    func addLiveTextAtCenter() -> MKNodeID? {
        let center = CGPoint(x: session.scene.canvas.size.width / 2, y: session.scene.canvas.size.height / 2)
        let anchored = CGPoint(x: center.x - 110, y: center.y - 20)
        guard let id = try? session.addLiveText(at: anchored) else { return nil }
        if var core = session.scene.node(id: id)?.core {
            core.style.fill = .solid(MKSolidColor.defaultInk)
            try? session.perform(MKBatchCoreCommand(gestureID: UUID(), newCores: [id: core], label: defaultTextColorLabel))
        }
        return id
    }

    private var defaultTextColorLabel: String {
        // Latin gloss: default text color
        "لون النص الافتراضي"
    }

    // MARK: - P2.1/P2.2/P2.3/P2.6: text insert sheet commit path

    /// P2.6: `MKTextStyle.pointSize`'s own `36` default (see that type's
    /// doc comment) is a text-editor-sized MODEL fallback, not a display
    /// default ، the model has no canvas to scale against. This computes
    /// `TextInsertSheet`'s INITIAL size the same "`shortSide`-relative"
    /// way `addPathText(preset: .arc)`'s radius and `addRectangleAtCenter()`'s
    /// edge already do (`shortSide / 3`, reusing the arc preset's exact
    /// fraction rather than inventing a new one).
    ///
    /// Bug fix (2026-07-29, user report: "default font size is 360 which is
    /// absurdly huge, it should be dynamic to canvas size"). It WAS already
    /// canvas-relative ، the fraction was simply far too coarse. `/3` puts
    /// a single short Arabic word most of the way across a 1080 pt canvas
    /// before the user has typed anything, so the first thing every new
    /// text object needs is to be shrunk. Reusing `addPathText(preset:
    /// .arc)`'s RADIUS fraction was the mistake: the radius of an arc and
    /// the cap height of a headline are not the same kind of quantity, and
    /// borrowing one for the other only looked like consistency.
    ///
    /// `/10` is the headline default: a short word lands at roughly a
    /// third of the canvas width, which reads as "large title" without
    /// being unusable, and it still tracks canvas size (a 2400 pt poster
    /// gets 240 pt, a 640 pt card gets 64 pt). Clamped so degenerate or
    /// extreme canvases can't produce an unreadably small or an absurd
    /// size ، the floor matches `TextInsertSheet`'s own stepper minimum.
    static func defaultInsertPointSize(canvasSize: CGSize) -> Double {
        let shortSide = min(canvasSize.width, canvasSize.height)
        guard shortSide > 0 else { return MKTextStyle.default.pointSize }
        return Double(min(max(shortSide / 10, 8), 400))
    }

    /// P2.1's insert-sheet horizontal placement control. NOT a persisted
    /// `MKTextStyle`/model concept ، neither `MKTextStyle` nor
    /// `MKTextFrameSpec` carries a horizontal-alignment field, and
    /// `LiveTextDrawer.drawLine` always starts every shaped LINE at local
    /// `x == 0` regardless of that line's own width (confirmed by reading
    /// the drawer before adding this), so alignment cannot be expressed as
    /// a property of a single multi-line node. `insertTextFromSheet(...)`
    /// therefore always creates one node per LINE (never embeds a raw
    /// `"\n"` inside one node's `text.string`), and this enum drives the
    /// x-offset computed for each line's node(s) at insert time ، exactly
    /// how a layout tool's "paragraph alignment" behaves when there is no
    /// native multi-line-in-one-run primitive to lean on. `right` is the
    /// default (D-109's RTL-natural choice).
    enum TextInsertAlignment: Hashable {
        case right, center, left
    }

    /// P2.1/P2.2/P2.3: commits `TextInsertSheet`'s configured text as one
    /// or more `MKLiveTextNode`s, positioned/grouped per `splitBySpaces`/
    /// `groupLines`, then selects everything it created. Deliberately never
    /// enters `.editText` mode (D-104's on-canvas overlay): the text is
    /// already fully typed and styled in the sheet, so re-opening the
    /// keyboard here would just reproduce the exact "insert blank +
    /// immediately edit inline" flow this sheet REPLACES (that older flow
    /// is `addLiveTextAtCenter()` above, kept only for the DEBUG/E2E
    /// hooks that still call it directly). Because nothing is committed to
    /// `session` until this method runs, `TextInsertSheet`'s Cancel button
    /// needs no unwind logic of its own (unlike `TextEditingOverlayController
    /// .cancel(session:)`, P2.5's just-fixed restore-on-cancel path for
    /// EXISTING nodes) ، it simply never calls this method, which is a
    /// correct-by-construction "genuine discard" for a sheet that creates
    /// nothing speculative on canvas while open.
    ///
    /// Layout: `fullText` is split on `"\n"` into lines first (blank lines
    /// dropped); each line becomes either ONE node (`splitBySpaces ==
    /// false`) or one node per whitespace-separated token (`splitBySpaces
    /// == true`). Token sizes are measured via the real
    /// `MKNodeLocalBounds.localBounds(of:)` (the same bounds math
    /// `MKLayerTreeController` sizes on-canvas layers with) so placement
    /// uses the SELECTED font/size's real metrics, not a guess ،
    /// inter-token spacing is the one approximation
    /// (`spaceWidthApproximation(pointSize:)`, documented at its own
    /// declaration). Lines stack top-to-bottom by `style.lineHeightMultiple
    /// * style.pointSize`; `alignment` positions each line's block within
    /// the shared max-line-width block, independent of the per-line RTL
    /// token order (the first-typed word in a line is always placed
    /// RIGHTMOST within that line, matching natural Arabic reading order).
    ///
    /// Multiple `MKInsertNodeCommand`/`MKGroupCommand` calls are pushed,
    /// one undo entry each (`MKInsertNodeCommand.coalescingKey` is `nil`,
    /// so a `beginGesture()` bracket would not merge them ، see
    /// `MKUndoStack.perform`'s `let key = command.coalescingKey` coalescing
    /// guard) ، the same "N undo entries for one toolbar action" wrinkle
    /// `addLiveTextAtCenter()`'s own doc comment already accepts for its
    /// 2-command case, generalized here to as many commands as this insert
    /// creates. Documented, not silently smoothed over.
    @discardableResult
    func insertTextFromSheet(
        fullText: String,
        style: MKTextStyle,
        splitBySpaces: Bool,
        groupLines: Bool,
        alignment: TextInsertAlignment
    ) -> [MKNodeID] {
        let lines = Self.tokenizeForInsert(fullText, splitBySpaces: splitBySpaces)
        guard !lines.isEmpty else { return [] }

        let lineHeight = CGFloat(style.lineHeightMultiple * style.pointSize)
        let spaceWidth = Self.spaceWidthApproximation(pointSize: style.pointSize)

        let measuredLines: [(tokens: [(text: String, size: CGSize)], width: CGFloat)] = lines.map { tokens in
            let measured = tokens.map { (text: $0, size: Self.measureSingleLineSize($0, style: style)) }
            let spacing = spaceWidth * CGFloat(max(0, measured.count - 1))
            let width = measured.reduce(0 as CGFloat) { $0 + $1.size.width } + spacing
            return (tokens: measured, width: width)
        }

        let blockWidth = measuredLines.map(\.width).max() ?? 0
        let blockHeight = CGFloat(measuredLines.count) * lineHeight
        let canvasSize = session.scene.canvas.size
        let canvasCenter = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let blockOrigin = CGPoint(x: canvasCenter.x - blockWidth / 2, y: canvasCenter.y - blockHeight / 2)

        var createdTopLevelIDs: [MKNodeID] = []

        for (index, line) in measuredLines.enumerated() {
            let lineY = blockOrigin.y + CGFloat(index) * lineHeight
            let lineLeftX: CGFloat
            switch alignment {
            case .right: lineLeftX = blockOrigin.x + (blockWidth - line.width)
            case .left: lineLeftX = blockOrigin.x
            case .center: lineLeftX = blockOrigin.x + (blockWidth - line.width) / 2
            }
            // RTL token order: the first-typed (logically first) word is
            // placed RIGHTMOST within its line, matching natural Arabic
            // reading order ، cursor starts at the line's right edge and
            // walks leftward as each token is placed.
            var cursorX = lineLeftX + line.width
            var lineNodeIDs: [MKNodeID] = []
            for token in line.tokens {
                cursorX -= token.size.width
                let position = CGPoint(x: cursorX, y: lineY)
                if let id = insertSingleLiveText(token.text, style: style, position: position) {
                    lineNodeIDs.append(id)
                }
                cursorX -= spaceWidth
            }
            if groupLines, lineNodeIDs.count > 1 {
                // P2.3: reuse the already-shipped grouping primitive
                // end-to-end (`MKGroupNode`/`MKGroupCommand`/
                // `CanvasSession.group(name:)`) rather than building
                // anything new. `scene.reparenting(_:intoGroupNamed:...)`
                // gives the new group `MKNodeCore.transform == .identity`
                // and leaves each child's own (already-absolute) transform
                // untouched, so grouping here is visually a no-op ، exactly
                // what's wanted, since these nodes were just placed at
                // their final absolute positions.
                session.setSelection(Set(lineNodeIDs))
                if let groupID = try? session.group(name: lineGroupLabel) {
                    createdTopLevelIDs.append(groupID)
                } else {
                    createdTopLevelIDs.append(contentsOf: lineNodeIDs)
                }
            } else {
                createdTopLevelIDs.append(contentsOf: lineNodeIDs)
            }
        }

        session.setSelection(Set(createdTopLevelIDs))
        return createdTopLevelIDs
    }

    /// One `MKInsertNodeCommand` per call, pre-filled with the same
    /// default ink fill `addLiveTextAtCenter()`/`addPathText(preset:)`
    /// apply as a follow-up command ، done in ONE command here instead,
    /// since (unlike `CanvasSession.addLiveText(at:)`) this call site
    /// builds the `MKNodeCore` itself and can set `style.fill` directly,
    /// with no separate `MKBatchCoreCommand` needed.
    private func insertSingleLiveText(_ text: String, style: MKTextStyle, position: CGPoint) -> MKNodeID? {
        var core = MKNodeCore(name: "نص", transform: MKTransform2D(position: position))
        core.style.fill = .solid(MKSolidColor.defaultInk)
        let node = MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style, frame: .singleLine)
        let wrapped = MKNode.liveText(node)
        guard (try? session.perform(MKInsertNodeCommand(node: wrapped))) != nil else { return nil }
        return wrapped.id
    }

    /// Splits `text` into lines (on `"\n"`, blank lines dropped after
    /// trimming), then each line into whitespace-separated tokens when
    /// `splitBySpaces` is true, or keeps each line as a single one-element
    /// "line" otherwise. Always going through this ONE tokenizer (instead
    /// of an `if splitBySpaces` branch inside `insertTextFromSheet`
    /// itself) is what lets `alignment` apply uniformly in both cases ،
    /// see `TextInsertAlignment`'s own doc comment for why a raw
    /// multi-line node could not have supported that.
    private static func tokenizeForInsert(_ text: String, splitBySpaces: Bool) -> [[String]] {
        let rawLines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !rawLines.isEmpty else { return [] }
        if splitBySpaces {
            return rawLines
                .map { line in line.split(separator: " ").map(String.init).filter { !$0.isEmpty } }
                .filter { !$0.isEmpty }
        }
        return rawLines.map { [$0] }
    }

    /// Real measured size (via `MKNodeLocalBounds.localBounds(of:)`, the
    /// SAME bounds math the render tree sizes on-canvas layers with) of
    /// `text` shaped as a single-line `MKLiveTextNode` in `style` ، used to
    /// place split tokens/lines using the actual selected font/size
    /// instead of a guess.
    private static func measureSingleLineSize(_ text: String, style: MKTextStyle) -> CGSize {
        guard !text.isEmpty else { return .zero }
        let node = MKLiveTextNode(core: MKNodeCore(name: "نص"), text: MKSourceText(string: text), style: style, frame: .singleLine)
        return MKNodeLocalBounds.localBounds(of: .liveText(node)).size
    }

    /// Inter-token spacing when laying out split tokens (P2.2), approximated
    /// as a fraction of point size rather than measured via a second
    /// shaping pass ، a lone space character has no CTLine advance to
    /// measure in isolation (`MKNodeLocalBounds`'s own `textBounds` guards
    /// `!text.string.isEmpty`). `0.3×` point size lands close to a typical
    /// Arabic font's average word-space advance at reading sizes; this is
    /// a STARTING layout the user can still drag-adjust afterward (plain
    /// move, or Arrange Mode), not a persisted typographic guarantee.
    private static func spaceWidthApproximation(pointSize: Double) -> CGFloat {
        CGFloat(pointSize) * 0.3
    }

    private var lineGroupLabel: String {
        // Latin gloss: line
        "سطر"
    }

    /// **Real bug found and fixed this session (P1.4, Bug 13):**
    /// `CanvasContentAPI.addShape` never set `core.transform.scale`, so a
    /// freshly-added shape rendered at the implicit default `(1, 1)` ،
    /// `ShapeDrawer.localPath(for:)`'s canonical unit-square/unit-local
    /// geometry, sized entirely by that scale (see its own doc comment) ،
    /// meaning every shape added from this button was a 1×1 pt box: added,
    /// selected, effectively invisible. On top of that, the old `- 60`
    /// offset treated `center` as the box's TOP-LEFT corner; it is not ،
    /// because the geometry is centered on the origin, `position` already
    /// IS the shape's center, so the offset pushed every shape off-centre
    /// even once sized correctly. Fixed at the source: `addShape` now
    /// takes a `size:` (previous call sites default to the old invisible
    /// `(1, 1)` so nothing else breaks), and this call sizes the rectangle
    /// off the canvas's short side ، `shortSide / 4`, matching
    /// `addPathText(preset:)`'s own circle-preset radius convention just
    /// below ، and passes `center` directly, unmodified.
    ///
    /// **Follow-up fix, same session:** `MKShapeGeometry.rect(cornerRadius:)`
    /// is ALSO unit-square-relative (see that case's doc comment in
    /// `MKModel/MKNode.swift`), exactly like the rect geometry itself ،
    /// `ShapeDrawer.localPath(for:)` builds the rounded rect on the 1×1
    /// unit square and lets `core.transform.scale` blow it up to the real
    /// on-canvas box, so a raw point value here (the original `8`) is
    /// applied BEFORE that scale-up, not after. On a 1×1 pt box that value
    /// was clamped by CoreGraphics to half the side (an invisible circle,
    /// latent because the box itself was invisible); on this fix's real
    /// `edge`-sized box it would render a full CIRCLE instead of a rounded
    /// rectangle (`cornerWidth: 8` on an `edge`-pt-wide rect, `edge` being
    /// `shortSide / 4`, clamps to `edge / 2` well before reaching a
    /// subtle-rounding radius on any canvas this app ships). Dividing the
    /// intended on-canvas radius by `edge` converts it to the same
    /// unit-relative space the geometry itself uses, so the rendered
    /// corner radius is ~8 pt regardless of canvas size.
    private static let rectangleCornerRadiusPoints: Double = 8

    @discardableResult
    func addRectangleAtCenter() -> MKNodeID? {
        let canvasSize = session.scene.canvas.size
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let shortSide = min(canvasSize.width, canvasSize.height)
        let edge = shortSide / 4
        let unitCornerRadius = edge > 0 ? Self.rectangleCornerRadiusPoints / Double(edge) : 0
        var style = MKStyle.default
        style.fill = .solid(MKSolidColor(r: 0.65, g: 0.15, b: 0.15))
        return try? session.addShape(.rect(cornerRadius: unitCornerRadius), at: center, size: CGSize(width: edge, height: edge), style: style)
    }

    // MARK: - Asset Placement (WS-14/P3.2)

    /// Places a browser-selected asset through the model's placement API.
    ///
    /// Both `.placed`/`.placedPattern` hand back a ready-made `MKNode` with
    /// the FULL geometry already inlined (WS-14's self-contained-document
    /// design ، see `MKAssetInstantiator.swift`'s header), inserted through
    /// the SAME `MKInsertNodeCommand` every other toolbar insert action
    /// already uses (`CanvasContentAPI.addShape`/`addLiveText`/…), so
    /// undo/redo/layers/selection all behave identically to any other
    /// placed object ، `MKAssets` supplies geometry, never touches the
    /// undo stack itself.
    @discardableResult
    func placeAsset(_ descriptor: MKAssetDescriptor, using model: MKAssetBrowserModel) async -> MKAssetBrowserModel.PlacementOutcome {
        let canvasSize = session.scene.canvas.size
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let outcome = await model.select(descriptor, at: center, canvasSize: canvasSize)
        switch outcome {
        case .placed(let placement):
            try? session.perform(MKInsertNodeCommand(node: placement.node))
            session.setSelection([placement.node.id])
        case .placedPattern(let placement):
            try? session.perform(MKInsertNodeCommand(node: placement.node))
            session.setSelection([placement.node.id])
        case .premiumRequired:
            break
        }
        return outcome
    }

    // MARK: - Background image (P5.3, Bug 2)

    enum BackgroundImageOutcome: Sendable, Equatable {
        case set
        case failed
    }

    /// Sets the canvas background for both the background sheet and the
    /// new-project photo import.
    ///
    /// Ingest pipeline: downscale to canvas × 2 (`MKFoundation
    /// .MKImageDownscale.downscaledPNG`, the P14 hardening pass's own
    /// bitmap-memory-bounding pattern) → store the resulting bytes in the
    /// document's content-addressed asset store (`MKAssetStore.storeAsset
    /// (data:ext:)`) → prime the synchronous render-path cache
    /// (`assetProvider.prime`, BEFORE the command runs, so the very first
    /// render already resolves it) → set `.image(ref, fit:)` via
    /// `InspectorModel.setBackgroundImage`. No file-timestamp API is used
    /// anywhere in this pipeline (worth stating explicitly: `CGImageSource`/
    /// `CGContext`/`CGImageDestination`/`Data(contentsOf:)` decode/re-encode
    /// bytes only, never touch a file's creation/modification date), so
    /// this feature needs no new `NSPrivacyAccessedAPICategory` entry in
    /// `PrivacyInfo.xcprivacy` beyond what's already declared.
    @discardableResult
    func setBackgroundImage(data: Data) async -> BackgroundImageOutcome {
        let canvasSize = session.scene.canvas.size
        let maxPixelSize = CGSize(width: canvasSize.width * 2, height: canvasSize.height * 2)
        guard let downscaled = MKImageDownscale.downscaledPNG(data, maxPixelSize: maxPixelSize) else { return .failed }

        do {
            // `MKImageDownscale.downscaledPNG` always re-encodes as PNG
            // (its own doc comment explains why: preserving alpha, per
            // P5.4's "present alpha honestly") ، the ORIGINAL file's
            // extension is therefore irrelevant to what's actually stored,
            // so this never needs the caller's source extension at all.
            let ref = try await document.assetStoreHandle().storeAsset(data: downscaled, ext: "png")
            guard assetProvider.prime(ref, data: downscaled) != nil else { return .failed }
            let fit = inspector.backgroundImageFitValue ?? .cover
            inspector.setBackgroundImage(ref, fit: fit)
            return .set
        } catch {
            return .failed
        }
    }

    /// Toggles an existing background image between cover and contain.
    func toggleBackgroundImageFit() {
        guard let currentFit = inspector.backgroundImageFitValue else { return }
        inspector.setBackgroundImageFit(currentFit == .cover ? .contain : .cover)
    }

    /// Reverts to a solid-color background.
    func removeBackgroundImage() {
        inspector.removeBackgroundImage()
    }

    // MARK: - Selection actions (T11/packet toolbar: lock/hide/z-order/group)

    var hasSelection: Bool { !session.selection.isEmpty }
    var hasMultipleSelected: Bool { session.selection.isMultiple }
    var hasSingleSelection: Bool { session.selection.single != nil }

    func groupSelection() {
        _ = try? session.group()
    }

    func ungroupSelection() {
        try? session.ungroup()
    }

    func deleteSelection() {
        try? session.deleteSelection()
    }

    func duplicateSelection() {
        guard let id = session.selection.single else { return }
        try? layers.duplicate(id)
    }

    func toggleLockForSelection() {
        for id in session.selection.ids {
            guard let core = session.scene.node(id: id)?.core else { continue }
            try? session.setLocked(!core.isLocked, for: id)
        }
    }

    func toggleHideForSelection() {
        for id in session.selection.ids {
            guard let core = session.scene.node(id: id)?.core else { continue }
            try? session.setHidden(!core.isHidden, for: id)
        }
    }

    func bringSelectionToFront() {
        guard let id = session.selection.single else { return }
        try? session.reorder(id, toIndex: max(0, session.scene.nodes.count - 1))
    }

    func sendSelectionToBack() {
        guard let id = session.selection.single else { return }
        try? session.reorder(id, toIndex: 0)
    }

    // MARK: - P6 Editing operations (§2.3): select all/deselect all, copy/paste, flip

    func selectAll() {
        session.selectAll()
    }

    func deselectAll() {
        session.deselectAll()
    }

    var canCopySelection: Bool { hasSelection }

    func copySelection() {
        session.copySelectionToPasteboard()
    }

    /// Always enabled (mirrors `UIPasteboard`-backed paste everywhere else
    /// on the platform: whether there is anything pasteable is discovered
    /// by trying, not pre-flighted from a synchronous property) ، a paste
    /// with nothing/malformed data on the pasteboard is a documented no-op
    /// (`CanvasSession.paste(from:)`'s own doc comment), never a crash.
    func pasteFromClipboard() {
        session.pasteFromPasteboard()
    }

    func flipSelectionHorizontally() {
        try? session.flipSelection(axis: .horizontal)
    }

    func flipSelectionVertically() {
        try? session.flipSelection(axis: .vertical)
    }

    /// Whole-composition mirror (`CanvasSession.flipScene(axis:)`) ، a
    /// different operation from the two above, see that method's own doc
    /// comment. Not selection-gated: it acts on the document.
    func flipProjectHorizontally() {
        try? session.flipScene(axis: .horizontal)
        refreshCanvasChrome()
    }

    func flipProjectVertically() {
        try? session.flipScene(axis: .vertical)
        refreshCanvasChrome()
    }

    /// `true` when there is anything on the canvas to mirror.
    var canFlipProject: Bool { !session.scene.nodes.isEmpty }

    // MARK: - P7.4 Merge Design (§2.2)

    /// Resolves `sourceProjectID`'s on-disk package root through this same
    /// view model's own `projectLibrary` (the SAME `ProjectLibraryProviding`
    /// seam `EditorScene.open()` used to resolve THIS project's own root,
    /// and `generateThumbnailInBackground()` above uses to record the
    /// thumbnail path), then hands off to `CanvasSession
    /// .mergeDesign(fromPackageAt:)`. `try?` at this UI-facing boundary
    /// matches every other `CanvasSession` mutator call site in this file
    /// (`flipSelectionHorizontally()` immediately above, etc.) ، a merge
    /// that fails (source project vanished between being listed and being
    /// picked, or its package became unreadable) is a silent no-op, not a
    /// crash.
    func mergeDesign(fromProjectID sourceProjectID: MKProjectID) async {
        guard let url = await projectLibrary.packageRootURL(for: sourceProjectID) else { return }
        try? session.mergeDesign(fromPackageAt: url)
    }

    // MARK: - Arrange Mode (packet task 15, PRD §6-§8)

    /// R-6.1: "تنسيق الحروف" entry action ، enabled on a single selected
    /// Live/Path Text object OR an already-arranged composition (R-6.10:
    /// re-entry resumes editing). Toggling while already in Arrange Mode
    /// exits it (R-6.7 "close").
    var canToggleArrangeMode: Bool {
        if arrangeInteraction.isActive { return true }
        guard let id = session.selection.single, let node = session.scene.node(id: id) else { return false }
        switch node {
        case .liveText, .pathText, .arranged: return true
        default: return false
        }
    }

    /// Bug fix (2026-07-29, user report: "the wand button is very buggy and
    /// unclear in its function"). Two silent failure modes are gone:
    ///
    /// 1. `guard let id = session.selection.single else { return }` used to
    ///    swallow the tap outright. The button is `.disabled` in that state,
    ///    but a disabled control that only dims to 40% and never says WHY
    ///    reads as broken, not as unavailable ، and the guard also caught the
    ///    multi-selection case, where the button is enabled.
    /// 2. Nothing distinguished "entered Arrange Mode" from "nothing
    ///    happened", because until this session's `MKCanvasRenderAdapter`
    ///    fix, entering it left every glyph and mark untappable.
    ///
    /// Every refusal now sets `arrangeInteraction.lastErrorMessage`, which
    /// `ArrangeErrorBannerView` already renders, matching the "every
    /// disabled/refused control states why" rule `enterArrangeMode` itself
    /// follows.
    func toggleArrangeMode() async {
        if arrangeInteraction.isActive {
            arrangeInteraction.exitArrangeMode()
            refreshCanvasChrome()
            return
        }
        guard let id = session.selection.single else {
            arrangeInteraction.reportRefusal(
                session.selection.isEmpty ? .nothingSelected : .multipleSelected)
            return
        }
        await arrangeInteraction.enterArrangeMode(nodeID: id)
        refreshCanvasChrome()
    }

    /// R-6.4 level toggle ("حروف"/letters ⇄ "أشكال"/glyphs).
    func setArrangeGranularity(_ granularity: MKSelectionGranularity) {
        arrangeInteraction.setGranularity(granularity)
        refreshCanvasChrome()
    }

    // MARK: - Path Text (packet task 16, PRD §9, FL-8)

    /// R-9.1's four creation presets, dispatched from `ToolRailView`'s
    /// "نص على مسار" menu.
    enum PathTextPreset {
        case arc, circle, wave, freeform
    }

    /// Builds `preset`'s default geometry centered on the canvas, inserts
    /// it via the existing `CanvasContentAPI.addPathText` (`MKCanvas`),
    /// applies the SAME default-ink-fill follow-up `addLiveTextAtCenter`
    /// documents (the identical `MKStyle.default.fill == .none` invisible-
    /// text bug applies to a freshly-added Path Text node too ، neither
    /// `CanvasContentAPI.addPathText` nor `addLiveText` take a `style:`
    /// override at the toolbar layer), then either opens the text overlay
    /// immediately (FL-8 step 1: "user types") for the three fixed-shape
    /// presets, or ، "حر" (freeform) only ، enters Path-Edit Mode right
    /// away instead, per this deliverable's own explicit instruction (a
    /// freeform path has no useful default TEXT yet, but its ANCHORS are
    /// exactly what a pen-style editor exists to let the user place).
    /// Coordinates: `BezierPathModel`'s presets already encode ABSOLUTE
    /// canvas-space points (see `circle(center:radius:)` etc.), and
    /// `PathTextDrawer.draw(_:into:...)` (`MKRender`, read-only reference)
    /// confirms Path Text is drawn straight from `node.path` with no
    /// `core.transform.position` offset added on top ، so `at: .zero`
    /// (this method's own default, matching `CanvasContentAPI.addPathText`'s
    /// own `at: CGPoint = .zero` default) is the CORRECT node position,
    /// not an omission.
    @discardableResult
    func addPathText(preset: PathTextPreset) -> MKNodeID? {
        let canvasSize = session.scene.canvas.size
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let shortSide = min(canvasSize.width, canvasSize.height)
        let path: MKBezierPathData
        switch preset {
        case .circle:
            path = BezierPathModel.circle(center: center, radius: shortSide / 4).bezierPathData()
        case .arc:
            let radius = shortSide / 3
            path = BezierPathModel.arc(center: center, radius: radius, startAngle: .pi, endAngle: 0).bezierPathData()
        case .wave:
            let width = canvasSize.width * 0.6
            let rect = CGRect(x: center.x - width / 2, y: center.y - 40, width: width, height: 80)
            path = BezierPathModel.wave(rect: rect, periods: 3, amplitude: 30).bezierPathData()
        case .freeform:
            // A gentle default 3-anchor open curve (this deliverable's own
            // "create a gentle default 3-anchor open curve" instruction) ،
            // a shallow single arch, not a straight line, so the very
            // first thing the user sees in the pen editor already looks
            // like a curve worth adjusting.
            let left = CGPoint(x: center.x - shortSide / 4, y: center.y)
            let top = CGPoint(x: center.x, y: center.y - shortSide / 8)
            let right = CGPoint(x: center.x + shortSide / 4, y: center.y)
            let anchors = [
                PathAnchor(point: left, handleOut: CGPoint(x: left.x + shortSide / 10, y: left.y - shortSide / 10)),
                PathAnchor(point: top, handleIn: CGPoint(x: top.x - shortSide / 10, y: top.y + shortSide / 20), handleOut: CGPoint(x: top.x + shortSide / 10, y: top.y + shortSide / 20)),
                PathAnchor(point: right, handleIn: CGPoint(x: right.x - shortSide / 10, y: right.y - shortSide / 10)),
            ]
            path = BezierPathModel(anchors: anchors, isClosed: false).bezierPathData()
        }
        guard let id = try? session.addPathText(path: path, at: .zero, text: CanvasSession.defaultLiveTextPlaceholder) else { return nil }
        if var core = session.scene.node(id: id)?.core {
            core.style.fill = .solid(MKSolidColor.defaultInk)
            try? session.perform(MKBatchCoreCommand(gestureID: UUID(), newCores: [id: core], label: defaultTextColorLabel))
        }
        if preset == .freeform {
            pathTextInteraction.enterPathEditMode(nodeID: id)
        } else {
            session.beginEditingText(nodeID: id)
        }
        return id
    }

    /// R-9.3's "تحرير المسار" (edit path) entry action ، enabled in browse
    /// mode with a single selected live `.pathText` node, OR while
    /// Path-Edit Mode is already active (toggling exits it, same "toggle
    /// closes" convention `canToggleArrangeMode`/`toggleArrangeMode`
    /// establish for Arrange Mode).
    var canTogglePathEditMode: Bool {
        if pathTextInteraction.isActive { return true }
        guard let id = session.selection.single, case .pathText? = session.scene.node(id: id) else { return false }
        return true
    }

    func togglePathEditMode() {
        if pathTextInteraction.isActive {
            presentedPathOptions = false
            pathTextInteraction.exitPathEditMode()
            refreshCanvasChrome()
            return
        }
        guard let id = session.selection.single else { return }
        pathTextInteraction.enterPathEditMode(nodeID: id)
        refreshCanvasChrome()
    }

    // MARK: Revert (R-6.12, FL-13)

    /// R-6.7 "العودة إلى النص" ، opens the confirmation dialog (exact PRD
    /// FL-13 copy, `MKArrangeRevertPreflight`'s static strings).
    func requestRevert() {
        pendingRevertPreflight = arrangeInteraction.revertPreflight()
    }

    func confirmRevert() {
        try? arrangeInteraction.revert()
        pendingRevertPreflight = nil
        refreshCanvasChrome()
    }

    func cancelRevert() {
        pendingRevertPreflight = nil
    }

    // MARK: R-6.11 arrange-then-edit-source conflict (double-tap on an arranged node)

    func resolveArrangeConflictRevertAndEdit() {
        guard let nodeID = arrangeSourceEditConflictNodeID else { return }
        arrangeInteraction.exitArrangeMode()   // no-op if not active
        // `revertAndEdit()` operates on `arrangeInteraction.activeOwnerNode`
        // (the CURRENT arrange-mode target) ، enter arrange mode on the
        // tapped node first (a pure mode transition, R-6.10, since it is
        // already `.arranged`) so the revert targets the right node.
        Task {
            await arrangeInteraction.enterArrangeMode(nodeID: nodeID)
            _ = try? arrangeInteraction.revertAndEdit()
            arrangeSourceEditConflictNodeID = nil
            refreshCanvasChrome()
        }
    }

    func resolveArrangeConflictDuplicateThenEdit() {
        guard let nodeID = arrangeSourceEditConflictNodeID else { return }
        Task {
            await arrangeInteraction.enterArrangeMode(nodeID: nodeID)
            _ = try? arrangeInteraction.duplicateThenRevertForEditing()
            arrangeSourceEditConflictNodeID = nil
            refreshCanvasChrome()
        }
    }

    func resolveArrangeConflictCancel() {
        arrangeSourceEditConflictNodeID = nil
    }

    // MARK: Join break/restore + form selector (§8.1, R-8.2/R-8.3)

    var canBreakOrRestoreJoinForSelection: (breakNext: Bool, breakPrevious: Bool, restoreNext: Bool, restorePrevious: Bool) {
        guard let id = session.selection.single else { return (false, false, false, false) }
        let neighbors = arrangeInteraction.logicalGlyphNeighbors(of: id)
        return (neighbors.next != nil, neighbors.previous != nil, neighbors.next != nil, neighbors.previous != nil)
    }

    func breakJoinWithNextForSelection() {
        guard let id = session.selection.single else { return }
        Task { try? await arrangeInteraction.breakJoinWithNext(id); refreshCanvasChrome() }
    }

    func breakJoinWithPreviousForSelection() {
        guard let id = session.selection.single else { return }
        Task { try? await arrangeInteraction.breakJoinWithPrevious(id); refreshCanvasChrome() }
    }

    func restoreJoinWithNextForSelection() {
        guard let id = session.selection.single else { return }
        Task { try? await arrangeInteraction.restoreJoinWithNext(id); refreshCanvasChrome() }
    }

    func restoreJoinWithPreviousForSelection() {
        guard let id = session.selection.single else { return }
        Task { try? await arrangeInteraction.restoreJoinWithPrevious(id); refreshCanvasChrome() }
    }

    /// R-8.3: opens the form-selector popover for the selected glyph.
    func presentFormSelectorForSelection() {
        guard let id = session.selection.single else { return }
        Task {
            presentedFormSelectorModel = await arrangeInteraction.loadFormSelector(for: id)
        }
    }

    func selectForm(_ form: MKJoiningForm) {
        guard let model = presentedFormSelectorModel else { return }
        try? arrangeInteraction.selectForm(form, for: model.nodeID)
        presentedFormSelectorModel = nil
        refreshCanvasChrome()
    }

    func dismissFormSelector() {
        presentedFormSelectorModel = nil
    }

    // MARK: Ligature decompose/recompose (§8.2, R-8.9-R-8.12)

    var canDecomposeSelection: Bool {
        guard let id = session.selection.single else { return false }
        return arrangeInteraction.canDecompose(id)
    }

    /// R-8.10/R-8.11: `fidelity` defaults to `true` (Q71 default); the
    /// secondary "استخدام الأشكال الافتراضية" action calls this with
    /// `false`.
    func decomposeSelection(fidelity: Bool = true) {
        guard let id = session.selection.single else { return }
        Task {
            let autoRefused = (try? await arrangeInteraction.decompose(id, fidelity: fidelity)) ?? false
            if autoRefused {
                decomposeFidelityNotice = decomposeFidelityAutoRefusedText
            }
            refreshCanvasChrome()
        }
    }

    /// R-8.12: fires the confirmation dialog only when the D-221 dirty
    /// check finds edited components; otherwise recomposes immediately.
    func requestRecomposeSelection() {
        guard let id = session.selection.single, let preflight = arrangeInteraction.recomposePreflight(id) else { return }
        if preflight.requiresConfirmation {
            pendingRecomposeConfirmation = (id, preflight)
        } else {
            try? arrangeInteraction.recompose(id, force: false)
            refreshCanvasChrome()
        }
    }

    func confirmRecompose() {
        guard let pending = pendingRecomposeConfirmation else { return }
        try? arrangeInteraction.recompose(pending.groupID, force: true)
        pendingRecomposeConfirmation = nil
        refreshCanvasChrome()
    }

    func cancelRecompose() {
        pendingRecomposeConfirmation = nil
    }

    // MARK: Marks (§7, R-7.5)

    var canDetachSelectedMark: Bool {
        guard let id = session.selection.single, let node = arrangeInteraction.activeOwnerNode,
              case .mark(let mark)? = node.composition.child(id: id)
        else { return false }
        return mark.attachedTo != nil
    }

    func detachSelectedMark() {
        try? arrangeInteraction.detachSelectedMark()
        refreshCanvasChrome()
    }

    /// R-7.5 "إرفاق بالحرف": arms re-attach mode for the selected (detached)
    /// mark ، the next glyph tap completes the attach (see
    /// `completePendingMarkReattach(baseID:)`, called from the canvas
    /// gesture layer via `GestureCoordinator`'s tap routing once armed).
    func armReattachForSelectedMark() {
        guard let id = session.selection.single else { return }
        pendingMarkReattachID = id
    }

    func completePendingMarkReattach(baseID: MKNodeID) {
        guard let markID = pendingMarkReattachID else { return }
        try? arrangeInteraction.reattachMark(markID, toBase: baseID)
        pendingMarkReattachID = nil
        refreshCanvasChrome()
    }

    func cancelPendingMarkReattach() {
        pendingMarkReattachID = nil
    }

    private var decomposeFidelityAutoRefusedText: String {
        // Latin gloss: the ligature could not maintain its exact shape after decomposition ، default spacing was used instead
        "تعذّر الحفاظ على شكل الرباط بدقة بعد التفكيك ، تم استخدام التباعد الافتراضي بدلاً من ذلك"
    }

    /// P0.1: `MakhtootDocument` and `MKUndoStack` are both `@Observable`
    /// now, so `session.canUndo`/`.canRedo` (computed properties on
    /// `CanvasSession` that forward straight through to
    /// `document.undoStack.canUndo`/`.canRedo`) are tracked end-to-end ،
    /// reading them inside a SwiftUI `body` registers a dependency on
    /// `MKUndoStack.undo`/`.redo` directly. The manual mirror this file
    /// used to keep (`private(set) var canUndo`/`canRedo`, refreshed by a
    /// `refreshUndoRedoState()` call after every mutation) is gone ، these
    /// are plain passthroughs now.
    var canUndo: Bool { session.canUndo }
    var canRedo: Bool { session.canRedo }

    func undo() {
        try? session.undo()
    }

    func redo() {
        try? session.redo()
    }

    // MARK: - DEBUG hooks (this session's own AC: simulator text entry is
    // blocked by tooling ، see docs/impl-log/WS-13.md Session 3 ، so the
    // Arabic-typing commit path must also be triggerable programmatically,
    // exercising the SAME `TextEditingOverlayController.textDidChange`/
    // `commit` code path a real keystroke would use, not a bypass around
    // it).

    #if DEBUG
    /// Mirrors `text` into the active overlay's `UITextView`, then fires
    /// the exact `UITextViewDelegate.textViewDidChange` callback a real
    /// keystroke would produce ، the D-104 mirroring path is unchanged
    /// (700 ms burst coalescing, IME-marked-text suspension, all still
    /// apply). No-op if no overlay is active.
    func debugSetActiveOverlayText(_ text: String) {
        guard let overlayView else { return }
        overlayView.textView.text = text
        overlayView.textViewDidChange(overlayView.textView)
    }

    /// Commits the active overlay (equivalent to tap-outside/Done).
    func debugCommitActiveOverlay() {
        overlayView?.commit()
        // Deterministic, not just observation-eventual: `overlayView.commit()`
        // synchronously flips `session.mode` back to `.browse` (see
        // `handleModeOrSelectionChange()`'s doc comment for the general
        // case this guards), so `syncOverlay()` can safely run immediately
        // here too rather than waiting for the next observation-tracking
        // fire to notice.
        syncOverlay()
    }

    func debugForceMemoryStage(_ stage: MKMemoryStage) {
        Task { [degradation] in
            await degradation.forceTransition(to: stage)
        }
    }

    /// Drag/resize/rotate gestures via `computer-use` mouse-simulation
    /// against the Simulator window were confirmed UNRELIABLE this session
    /// (`left_click_drag` and manual `left_mouse_down`/`mouse_move`/
    /// `left_mouse_up` sequences both produced no visible move ، this is
    /// the exact same tooling-limitation CLASS the packet's own gate
    /// anticipates for text entry, just for pointer drags instead of
    /// keyboard input). This hook exercises the real move/resize/rotate
    /// MODEL path the SAME way `MoveGesture`/`HandleGestures` do at
    /// `endGesture()` ، a real `MKBatchTransformCommand` through
    /// `session.perform`, landing in the undo stack/journal/autosave ،
    /// without depending on a synthetic pointer drag succeeding. Applies a
    /// combined translate + scale (~1.4×) + 15° rotation to the current
    /// selection in ONE committed step (one undo entry).
    func debugApplyTestTransform() {
        guard let id = session.selection.single, var transform = session.scene.node(id: id)?.core.transform else { return }
        transform.position.x += 120
        transform.position.y += 80
        transform.rotation += .pi / 12
        transform.scale.width *= 1.4
        transform.scale.height *= 1.4
        try? session.perform(MKBatchTransformCommand(gestureID: UUID(), newTransforms: [id: transform]))
        refreshCanvasChrome()
    }

    /// Measures the REAL D-114/D-115 manipulation fast-path
    /// (`MKCanvasRenderBridge.applyTransientTransform`, a pure
    /// layer-property update with zero `draw(in:)`/bitmap work per
    /// `MKLayerTreeController`'s own contract) by driving `frameCount`
    /// synthetic frames against the frontmost selected node, wrapped in
    /// the shared `MKSignpost.manipulationFrame` interval so an attached
    /// Instruments/`xctrace` session can also capture it. This is the
    /// honest substitute for an interactive-drag D-115 reading in an
    /// environment where computer-use drag gestures are unreliable
    /// (`docs/impl-log/WS-13.md` Session 3) ، it exercises the exact same
    /// production call the gesture code makes per frame, just driven
    /// programmatically instead of by a finger.
    @discardableResult
    func debugMeasureManipulationFrames(frameCount: Int = 30) -> TimeInterval {
        guard let nodeID = session.selection.single ?? session.selection.ids.first,
              let renderBridge = session.renderBridge,
              let obb = renderAdapter.worldOBB(for: nodeID, in: session.scene) else { return 0 }
        let clock = ContinuousClock()
        let elapsed = MKRenderSignposts.interval(.manipulationFrame) { () -> Duration in
            let start = clock.now
            session.beginGesture()
            for i in 0..<frameCount {
                let dx = CGFloat(i)
                let transform = CGAffineTransform(rotationAngle: obb.rotation)
                    .concatenating(CGAffineTransform(translationX: obb.center.x + dx, y: obb.center.y))
                renderBridge.applyTransientTransform(nodeID: nodeID, transform: transform)
            }
            renderBridge.commitTransients()
            session.endGesture()
            return clock.now - start
        }
        let totalSeconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let perFrame = frameCount > 0 ? totalSeconds / Double(frameCount) : 0
        lastManipulationFrameDuration = perFrame
        return perFrame
    }

    /// Renders the current scene directly via `MKSnapshotRenderer`
    /// (`fontProvider`, the same real provider every other render/export
    /// path in this file now uses ، see this file's `fontProvider` stored-
    /// property doc comment for the FC-1 history), bypassing
    /// `MKLayerTreeController`/CALayer compositing entirely, and writes the
    /// PNG to Documents ، a general-purpose DEBUG diagnostic kept after
    /// WS-13 Session 3's use of the identical technique to isolate the
    /// (now-fixed) Arabic-glyph rendering bug. Useful for any future "is
    /// this a canvas-compositing issue or a renderer issue" question.
    func debugDumpSnapshotPNG() {
        let renderer = MKSnapshotRenderer(fonts: fontProvider, assets: assetProvider)
        guard let image = renderer.render(session.scene, region: CGRect(origin: .zero, size: session.scene.canvas.size), scale: 2, quality: .exportQuality) else { return }
        let uiImage = UIImage(cgImage: image)
        guard let data = uiImage.pngData() else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("debug_snapshot.png")
        try? data.write(to: url)
        MKLog.app.info("debugDumpSnapshotPNG wrote \(url.path, privacy: .public)")
    }

    // MARK: - Arrange Mode DEBUG hooks (WS-06/WS-13's established precedent:
    // computer-use drag gestures + simulator text entry are both unreliable
    // in this environment ، docs/impl-log/WS-13.md Session 3 ، so the
    // Arrange Mode end-to-end flow needs the SAME programmatic-drive
    // pattern `debugSetActiveOverlayText`/`debugApplyTestTransform` already
    // established, exercising the real production model methods, not a
    // bypass around them.)

    /// Arranges the selected Live Text node (or, if already `.arranged`,
    /// just enters Arrange Mode on it ، R-6.10).
    func debugArrangeSelection() {
        guard let id = session.selection.single else { return }
        Task {
            await arrangeInteraction.enterArrangeMode(nodeID: id)
            refreshCanvasChrome()
        }
    }

    /// Selects the first glyph in the active composition and drags it by
    /// `(dx, dy)` in ONE committed step (mirrors `debugApplyTestTransform`'s
    /// "one committed step, one undo entry" shape, at glyph granularity).
    func debugMoveFirstGlyph(dx: CGFloat, dy: CGFloat) {
        guard let node = arrangeInteraction.activeOwnerNode,
              case .glyph(let first)? = node.composition.nodes.first(where: { if case .glyph = $0 { return true }; return false })
        else { return }
        session.setArrangeChildSelection([first.id], granularity: .glyph, compositionScope: node.core.id)
        arrangeInteraction.beginMove()
        arrangeInteraction.updateMove(byDelta: CGSize(width: dx, height: dy))
        arrangeInteraction.endMove()
        refreshCanvasChrome()
    }

    /// Selects the first MARK (tashkeel) in the active composition and
    /// drags it by `(dx, dy)` ، R-7.4's independent mark move.
    func debugMoveFirstMark(dx: CGFloat, dy: CGFloat) {
        guard let node = arrangeInteraction.activeOwnerNode,
              case .mark(let first)? = node.composition.nodes.first(where: { if case .mark = $0 { return true }; return false })
        else { return }
        session.setArrangeChildSelection([first.id], granularity: .glyph, compositionScope: node.core.id)
        arrangeInteraction.beginMove()
        arrangeInteraction.updateMove(byDelta: CGSize(width: dx, height: dy))
        arrangeInteraction.endMove()
        refreshCanvasChrome()
    }

    /// Breaks the join between the composition's first two glyphs
    /// (§8.1's "فك الارتباط") ، the join-break-boundary-picking E2E gate.
    func debugBreakFirstJoin() {
        guard let node = arrangeInteraction.activeOwnerNode else { return }
        let glyphs = node.composition.nodes.compactMap { child -> MKGlyphNode? in
            if case .glyph(let g) = child { return g }
            return nil
        }.sorted { $0.provenance.logicalIndex < $1.provenance.logicalIndex }
        guard let firstID = glyphs.first?.id else { return }
        Task {
            try? await arrangeInteraction.breakJoinWithNext(firstID)
            refreshCanvasChrome()
        }
    }

    /// Selects the composition's first (now join-broken) glyph and picks
    /// the "منفصل" (isolated) form ، R-8.3's form-selector E2E gate.
    func debugSelectIsolatedFormOnFirstGlyph() {
        guard let node = arrangeInteraction.activeOwnerNode,
              case .glyph(let first)? = node.composition.nodes.first(where: { if case .glyph = $0 { return true }; return false })
        else { return }
        Task {
            _ = await arrangeInteraction.loadFormSelector(for: first.id)
            try? arrangeInteraction.selectForm(.isolated, for: first.id)
            refreshCanvasChrome()
        }
    }

    /// Decomposes the composition's first ligature group (if any) ،
    /// §8.2's decompose E2E gate.
    func debugDecomposeFirstLigature() {
        guard let node = arrangeInteraction.activeOwnerNode,
              case .ligature(let group)? = node.composition.nodes.first(where: { if case .ligature = $0 { return true }; return false })
        else { return }
        Task {
            _ = try? await arrangeInteraction.decompose(group.id, fidelity: true)
            refreshCanvasChrome()
        }
    }

    /// Reverts the current arrange-mode composition back to text (R-6.12)
    /// ، bypasses the confirmation UI (the confirmation COPY itself is
    /// covered by `pendingRevertPreflight`'s static strings, verified via
    /// `requestRevert()`/the SwiftUI alert directly; this hook exercises
    /// the underlying committed action for the E2E chain).
    func debugRevertArrangedSelection() {
        try? arrangeInteraction.revert()
        refreshCanvasChrome()
    }

    /// The full Arrange Mode end-to-end drive, launched via the
    /// `-mkE2EArrangeDrive` argument (`ProjectBrowserView.swift`/
    /// `EditorScene.swift`'s matching `.task` hooks) ، because this
    /// environment has NO interactive tap/drag injection available at all
    /// (confirmed via a `System Events` accessibility-access probe this
    /// session; a strictly harder constraint than WS-13's own "computer-use
    /// drag gestures are unreliable" finding), this is the only way to
    /// exercise the real production flow end to end and capture evidence
    /// screenshots from OUTSIDE the app (`xcrun simctl io screenshot`
    /// paced against this method's own `Task.sleep` intervals). Every step
    /// calls the SAME method a real tap/gesture would ، never a bypass.
    /// Logs each step via `MKLog.app` so `xcrun simctl spawn ... log
    /// stream` can also confirm step boundaries precisely, independent of
    /// screenshot timing.
    func debugRunE2EArrangeSequence() async {
        MKLog.app.info("E2E-ARRANGE: step 1 ، create Arabic Live Text")
        guard let textID = addLiveTextAtCenter() else {
            MKLog.app.error("E2E-ARRANGE: addLiveTextAtCenter returned nil ، aborting")
            return
        }
        MKLog.app.info("E2E-ARRANGE: created node \(textID.description, privacy: .public); scene now has \(self.session.scene.nodes.count) node(s)")
        // `session.addLiveText` (`CanvasContentAPI`) already calls
        // `beginEditingText`, but the actual `TextEditingOverlayView`
        // instance is only created asynchronously, once `syncOverlay()`
        // runs off `handleModeOrSelectionChange()`'s observation-tracking
        // fire (P-2: was a 100 ms poll cadence before this session, now an
        // event-driven reaction that lands the same run loop turn ، the
        // sleep margin below was already generous and stays so) ، waiting
        // a beat here avoids a real race (`debugSetActiveOverlayText`
        // silently no-ops against a not-yet-presented overlay, found this
        // session by dumping scene JSON and seeing the placeholder text
        // committed unchanged instead of the intended string).
        try? await Task.sleep(for: .milliseconds(400))
        debugSetActiveOverlayText("مرحبا بالعالم")
        debugCommitActiveOverlay()
        // Evidence-capture aid only (no production behavior change): the
        // canvas has no auto-scroll-to-content on a fresh document, so a
        // node placed at canvas CENTER on a canvas larger than the
        // viewport can land outside the default (0,0) scroll offset ،
        // zoom-to-fit guarantees screenshots taken from here on actually
        // show the content.
        canvasViewController?.zoomToFit()
        try? await Task.sleep(for: .seconds(2))
        debugDumpSceneJSON(label: "after-text-commit")

        MKLog.app.info("E2E-ARRANGE: step 2 ، select + enter Arrange Mode (تنسيق الحروف)")
        session.setSelection([textID])
        await toggleArrangeMode()
        MKLog.app.info("E2E-ARRANGE: mode after toggle = \(String(describing: self.session.mode), privacy: .public), arrangeEngineError=\(self.arrangeInteraction.lastErrorMessage ?? "none", privacy: .public)")
        try? await Task.sleep(for: .seconds(2))

        MKLog.app.info("E2E-ARRANGE: step 3 ، select + move a glyph")
        debugMoveFirstGlyph(dx: 24, dy: -18)
        try? await Task.sleep(for: .seconds(2))

        MKLog.app.info("E2E-ARRANGE: step 4 ، select + move a mark (tashkeel)")
        debugMoveFirstMark(dx: -10, dy: 8)
        try? await Task.sleep(for: .seconds(2))

        MKLog.app.info("E2E-ARRANGE: step 5 ، break a join (فك الارتباط)")
        debugBreakFirstJoin()
        try? await Task.sleep(for: .seconds(2))

        MKLog.app.info("E2E-ARRANGE: step 6 ، form-select (اختيار الشكل)")
        debugSelectIsolatedFormOnFirstGlyph()
        try? await Task.sleep(for: .seconds(2))

        debugDumpSceneJSON(label: "after-all-arrange-edits")
        MKLog.app.info("E2E-ARRANGE: step 7 ، undo chain (undo → redo round trip, bounded to whatever this run actually committed ، never unwinds past the original insert)")
        var undoCount = 0
        while canUndo, undoCount < 2 {
            undo()
            undoCount += 1
            try? await Task.sleep(for: .milliseconds(400))
        }
        while undoCount > 0 {
            redo()
            undoCount -= 1
            try? await Task.sleep(for: .milliseconds(400))
        }
        try? await Task.sleep(for: .seconds(1))
        debugDumpSceneJSON(label: "after-undo-redo-roundtrip")

        MKLog.app.info("E2E-ARRANGE: step 8 ، revert-with-confirm (العودة إلى النص)")
        requestRevert()
        try? await Task.sleep(for: .seconds(2))
        confirmRevert()
        try? await Task.sleep(for: .seconds(1))

        MKLog.app.info("E2E-ARRANGE: step 9 ، save for relaunch-persistence check")
        debugDumpSceneJSON(label: "final")
        await saveNow()
        MKLog.app.info("E2E-ARRANGE: DONE")
    }

    // MARK: - Path-Edit Mode DEBUG hooks (packet task 16's E2E gate ، same
    // computer-use-drag/text-entry-unreliable precedent as the Arrange
    // Mode hooks above; every step below calls a REAL production
    // `MKPathTextInteractionModel` method, never a bypass).

    /// Drags the path's first anchor by `(dx, dy)` ، resolves it via
    /// `nearestHitTarget(at:tolerance:)` at the anchor's own KNOWN current
    /// position (`node.path.segments.first?.start`, the first anchor's
    /// point by `MKBezierPathData`'s own segment convention ، see
    /// `MKPathTextInteractionModel.reversedPath(_:)`'s doc comment for that
    /// convention spelled out) with an unbounded tolerance, guaranteeing an
    /// exact hit rather than depending on a screen-space touch tolerance.
    func debugDragFirstPathAnchor(dx: CGFloat, dy: CGFloat) {
        guard let node = pathTextInteraction.activeNode, let start = node.path.segments.first?.start,
              let target = pathTextInteraction.nearestHitTarget(at: start, tolerance: .greatestFiniteMagnitude), target.id.kind == .anchor
        else { return }
        pathTextInteraction.beginHandleDrag(target.id)
        pathTextInteraction.updateHandleDrag(to: CGPoint(x: target.position.x + dx, y: target.position.y + dy))
        pathTextInteraction.endHandleDrag()
    }

    /// Nudges one laid-out glyph's per-glyph offset (R-9.4) by `(dx, dy)`.
    /// `beginGlyphOffsetDrag(at:)` needs a point that actually lands on a
    /// laid-out glyph (the adapter's own `glyphHitTest`'s ~0.6×point-size
    /// tolerance) ، rather than re-deriving the full shaped layout here
    /// just to find one probe point, this samples a handful of points
    /// along the path's own arc length (`ArcLengthLUT`, the same engine
    /// primitive the adapter itself uses) and tries each via the REAL
    /// `beginGlyphOffsetDrag` until one hits. This sampling is a probe for
    /// a valid input point, not a bypass of the drag itself ، the actual
    /// drag still goes through `beginGlyphOffsetDrag`/
    /// `updateGlyphOffsetDrag`/`endGlyphOffsetDrag` exactly as a real touch
    /// would.
    func debugDragFirstPathGlyph(dx: CGFloat, dy: CGFloat) {
        guard let node = pathTextInteraction.activeNode else { return }
        let lut = ArcLengthLUT(path: BezierPathModel(node.path))
        guard lut.totalLength > 0 else { return }
        let sampleCount = 32
        for i in 0..<sampleCount {
            let length = lut.totalLength * CGFloat(i) / CGFloat(sampleCount)
            let point = lut.point(atLength: length)
            guard pathTextInteraction.beginGlyphOffsetDrag(at: point) != nil else { continue }
            pathTextInteraction.updateGlyphOffsetDrag(byDelta: CGSize(width: dx, height: dy))
            pathTextInteraction.endGlyphOffsetDrag()
            return
        }
        MKLog.app.error("E2E-PATH: debugDragFirstPathGlyph found no glyph under any sampled arc point")
    }

    /// The full Path-Edit Mode end-to-end drive, launched via the
    /// `-mkE2EPathDrive` argument (`ProjectBrowserView.swift`/
    /// `EditorScene.swift`'s matching `.task` hooks, mirroring
    /// `-mkE2EArrangeDrive`'s exact pattern) ، this environment has no
    /// interactive tap/drag injection at all (see
    /// `debugRunE2EArrangeSequence`'s own header for the confirmed finding
    /// this restates), so this is the only way to exercise the real Path
    /// Text production flow end to end and capture evidence screenshots
    /// from OUTSIDE the app.
    func debugRunE2EPathSequence() async {
        MKLog.app.info("E2E-PATH: step 1 ، create circle path text + type «سلام»")
        guard let textID = addPathText(preset: .circle) else {
            MKLog.app.error("E2E-PATH: addPathText(preset: .circle) returned nil ، aborting")
            return
        }
        MKLog.app.info("E2E-PATH: created node \(textID.description, privacy: .public)")
        try? await Task.sleep(for: .milliseconds(400))
        debugSetActiveOverlayText("سلام")
        debugCommitActiveOverlay()
        canvasViewController?.zoomToFit()
        try? await Task.sleep(for: .seconds(2))
        debugDumpSceneJSON(label: "path-after-text-commit")

        MKLog.app.info("E2E-PATH: step 2 ، enter path-edit mode (تحرير المسار)")
        session.setSelection([textID])
        togglePathEditMode()
        MKLog.app.info("E2E-PATH: mode after toggle = \(String(describing: self.session.mode), privacy: .public)")
        try? await Task.sleep(for: .seconds(1))

        MKLog.app.info("E2E-PATH: step 3 ، drag the first anchor")
        debugDragFirstPathAnchor(dx: 40, dy: -30)
        refreshCanvasChrome()
        try? await Task.sleep(for: .seconds(1))
        debugDumpSceneJSON(label: "path-after-anchor-drag")

        MKLog.app.info("E2E-PATH: step 4 ، flip side (above/below)")
        try? pathTextInteraction.toggleAboveBelow()
        try? await Task.sleep(for: .seconds(1))

        MKLog.app.info("E2E-PATH: step 5 ، set start offset (coalesced options gesture)")
        let optionsGestureID = UUID()
        pathTextInteraction.beginOptionsGesture()
        try? pathTextInteraction.setStartOffset(0.25, gestureID: optionsGestureID)
        pathTextInteraction.endOptionsGesture()
        try? await Task.sleep(for: .seconds(1))
        debugDumpSceneJSON(label: "path-after-options")

        MKLog.app.info("E2E-PATH: step 6 ، glyph-offset drag on a laid-out glyph")
        debugDragFirstPathGlyph(dx: 6, dy: -6)
        refreshCanvasChrome()
        try? await Task.sleep(for: .seconds(1))
        debugDumpSceneJSON(label: "path-after-glyph-offset")

        MKLog.app.info("E2E-PATH: step 7 ، exit path-edit, arrange (تنسيق الحروف), toggle ghost guide (إظهار المسار)")
        togglePathEditMode()
        await arrangeInteraction.enterArrangeMode(nodeID: textID)
        showsPathGhostGuide = true
        refreshCanvasChrome()
        try? await Task.sleep(for: .seconds(1))
        debugDumpSceneJSON(label: "path-after-arrange")

        MKLog.app.info("E2E-PATH: step 8 ، nudge one arranged glyph")
        debugMoveFirstGlyph(dx: 16, dy: -10)
        try? await Task.sleep(for: .seconds(1))
        debugDumpSceneJSON(label: "path-after-arrange-nudge")

        MKLog.app.info("E2E-PATH: step 9 ، undo ×2, redo ×2")
        var undoCount = 0
        while canUndo, undoCount < 2 {
            undo()
            undoCount += 1
            try? await Task.sleep(for: .milliseconds(400))
        }
        while undoCount > 0 {
            redo()
            undoCount -= 1
            try? await Task.sleep(for: .milliseconds(400))
        }
        try? await Task.sleep(for: .seconds(1))
        debugDumpSceneJSON(label: "path-after-undo-redo-roundtrip")

        MKLog.app.info("E2E-PATH: step 10 ، save for relaunch-persistence check")
        debugDumpSceneJSON(label: "path-final")
        await saveNow()
        MKLog.app.info("E2E-PATH: DONE")
    }

    /// Diagnostic-only: dumps `session.scene` as JSON to Documents, so this
    /// session's own file-system-based verification pass can read EXACT
    /// scene state at a checkpoint without depending on autosave-debounce
    /// timing or `MakhtootDocument`'s own persisted-file write cadence.
    func debugDumpSceneJSON(label: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(session.scene) else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("debug_scene_\(label).json")
        try? data.write(to: url)
        MKLog.app.info("debugDumpSceneJSON(\(label, privacy: .public)) wrote \(url.path, privacy: .public), nodeCount=\(self.session.scene.nodes.count)")
    }

    // MARK: - TEMPORARY App Store screenshot fixtures (not a WS packet
    // deliverable ، remove after the screenshot capture pass). These mirror
    // `debugRunE2EArrangeSequence`/`debugRunE2EPathSequence` exactly (same
    // "call the real production method, never a bypass" rule) but stop ON
    // the showcased feature state instead of unwinding it, and force both
    // side panels open so `xcrun simctl io screenshot` shows the layers +
    // inspector chrome alongside the canvas.

    func debugRunScreenshotArrangeSequence() async {
        guard let textID = addLiveTextAtCenter() else { return }
        try? await Task.sleep(for: .milliseconds(400))
        debugSetActiveOverlayText("خط عربي جميل")
        debugCommitActiveOverlay()
        canvasViewController?.zoomToFit()
        try? await Task.sleep(for: .seconds(1))

        session.setSelection([textID])
        await toggleArrangeMode()
        try? await Task.sleep(for: .seconds(1))

        debugMoveFirstGlyph(dx: 24, dy: -18)
        try? await Task.sleep(for: .milliseconds(500))
        debugMoveFirstMark(dx: -10, dy: 8)
        try? await Task.sleep(for: .milliseconds(500))

        showsLayersColumn = true
        showsInspectorColumn = true
        refreshCanvasChrome()
        try? await Task.sleep(for: .seconds(1))
    }

    func debugRunScreenshotPathSequence() async {
        guard let textID = addPathText(preset: .circle) else { return }
        try? await Task.sleep(for: .milliseconds(400))
        debugSetActiveOverlayText("بسم الله الرحمن الرحيم")
        debugCommitActiveOverlay()
        canvasViewController?.zoomToFit()
        try? await Task.sleep(for: .seconds(1))

        session.setSelection([textID])
        togglePathEditMode()
        try? await Task.sleep(for: .milliseconds(800))
        debugDragFirstPathAnchor(dx: 30, dy: -20)
        refreshCanvasChrome()
        try? await Task.sleep(for: .milliseconds(800))
        togglePathEditMode()

        showsLayersColumn = true
        showsInspectorColumn = true
        refreshCanvasChrome()
        try? await Task.sleep(for: .seconds(1))
    }
    #endif

    // MARK: - Overlay presentation (D-104)

    private func presentOverlay(for nodeID: MKNodeID, in vc: MKCanvasViewController) {
        if let overlayView, overlayView.controller.nodeID == nodeID {
            return // already presenting this node
        }
        dismissOverlayIfNeeded()

        let frame = overlayFrame(for: nodeID)
        let overlay = TextEditingOverlayView(frame: frame)
        overlay.textView.font = .systemFont(ofSize: initialPointSize(for: nodeID))
        // P2.5/Bug 5 remedy 3: deterministic teardown ، fires synchronously
        // at the end of the overlay's own `commit()`/`cancel()` (tap-
        // outside, swipe-down, "تم", or losing first responder for an
        // external reason), so this no longer waits on
        // `handleModeOrSelectionChange()`'s observation-tracking fire (P-2:
        // a 100 ms poll cadence before this session). `[weak self, weak
        // vc]`: both outlive the closure in practice, but the overlay
        // itself can in principle outlive a deallocated view controller
        // during teardown races.
        overlay.onFinished = { [weak self, weak vc] in
            self?.finishOverlayPresentation(in: vc)
        }
        vc.contentHostView.addSubview(overlay)
        vc.activeTextOverlay = overlay
        overlay.begin(session: session, nodeID: nodeID, initialText: currentText(for: nodeID))
        overlayView = overlay
    }

    /// Requests the overlay commit (a no-op if none is active, or if one is
    /// already mid-finish) ، actual teardown happens via `onFinished` above,
    /// not here, so this stays a thin trigger rather than duplicating the
    /// removal logic `finishOverlayPresentation(in:)` already owns.
    private func dismissOverlayIfNeeded() {
        overlayView?.commit()
    }

    /// The single place that tears the presented overlay down: removes it
    /// from its superview, drops this view model's strong reference, and
    /// clears `MKCanvasViewController.activeTextOverlay` so the tap-outside
    /// recognizer (Bug 5) and the keyboard-avoidance scroll (Bug 6) stop
    /// referencing a dead overlay. Called from `onFinished`, i.e. always
    /// AFTER the overlay's own `commit()`/`cancel()` has already run.
    private func finishOverlayPresentation(in vc: MKCanvasViewController?) {
        overlayView?.removeFromSuperview()
        overlayView = nil
        vc?.activeTextOverlay = nil
    }

    private func currentText(for nodeID: MKNodeID) -> String {
        switch session.scene.node(id: nodeID) {
        case .liveText(let n): return n.text.string
        case .pathText(let n): return n.text.string
        default: return ""
        }
    }

    private func initialPointSize(for nodeID: MKNodeID) -> CGFloat {
        switch session.scene.node(id: nodeID) {
        case .liveText(let n): return CGFloat(n.style.pointSize)
        case .pathText(let n): return CGFloat(n.style.pointSize)
        default: return 36
        }
    }

    private func overlayFrame(for nodeID: MKNodeID) -> CGRect {
        guard let obb = renderAdapter.worldOBB(for: nodeID, in: session.scene) else {
            return CGRect(x: 0, y: 0, width: 240, height: 60)
        }
        let width = max(obb.size.width + 32, 220)
        let height = max(obb.size.height + 24, 48)
        let originX = obb.center.x - width / 2
        let originY = obb.center.y - height / 2
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}

/// iPhone panel presentation target (T12: "panels as detented bottom
/// sheets on iPhone").
enum EditorPanel: String, Identifiable {
    case layers
    case inspector
    var id: String { rawValue }
}

/// Adapts `MakhtootDocument.saveNow(reason:)` to WS-07's `MKAutosaveTriggering`
/// seam (`MKRender/DegradationController.swift`) ، the exact adapter that
/// file's own doc comment says "WS-13's `AppEnvironment` is expected to
/// supply." `@unchecked Sendable`: `MakhtootDocument` is a `@MainActor`,
/// non-`Sendable` class, held here only `weak` and only ever touched via
/// `await` (which Swift hops onto the main actor for automatically) ، the
/// same pattern this file's other MainActor/actor boundary crossings use.
private final class DocumentAutosaveTrigger: MKAutosaveTriggering, @unchecked Sendable {
    private weak var document: MakhtootDocument?

    @MainActor
    init(document: MakhtootDocument) {
        self.document = document
    }

    func flushForMemoryPressure(stage: MKMemoryStage) async {
        let reason: MKSaveReason = (stage == .stage2) ? .memoryPressureStage2 : .memoryPressureStage1
        try? await document?.saveNow(reason: reason)
    }

    func flushJournalOnly() async {
        try? await document?.saveNow(reason: .memoryPressureCritical)
    }
}

