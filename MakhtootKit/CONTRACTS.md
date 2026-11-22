# MakhtootKit — cross-packet contracts

WS-01 packet §5 task 21. This is the authoritative list of every public
stub protocol/type WS-01 ships to unblock parallel development, its owning
packet, and the exact replacement plan. Any workstream consuming one of
these must code against the **protocol**, not the stub concrete type, so
swapping in the real implementation in `App/AppEnvironment.swift` (owned by
WS-13) requires no call-site changes.

| Stub protocol / type | Location | Consumed by | Real implementation | Replacement owner |
|---|---|---|---|---|
| ~~`MKEntitlementProviding` (protocol)~~ **REPLACED (WS-10, done)** | `Sources/MKFoundation/Entitlement/MKEntitlementProviding.swift` (protocol unchanged — still the shared contract; see WS-10's own deviation note below for why no associated values were added to `MKEntitlementState`) | WS-03..WS-08 (anywhere a premium-capability check is needed) | `MKStore.MKEntitlementResolver` — observes `Transaction.currentEntitlements` + `Product.SubscriptionInfo.Status`, resolves D-113 precedence via the pure `MKEntitlementPrecedence.resolve` function; exposes a `nonisolated` synchronous `state` (lock-guarded snapshot, so `MKExportGate`/`MKFontLockController`'s existing synchronous-read call sites needed zero changes) plus `states() -> AsyncStream<MKEntitlementState>` for push consumers. Wired at `Makhtoot/AppShell/AppContainer.swift`'s composition root this session — `AlwaysPremiumEntitlementStub` is `#if DEBUG`-gated and no longer referenced there; `Scripts/stub-source-audit.sh` (WS-10) enforces this going forward. | **Done — WS-10 (`MKStore`)** |
| `StubEntitlementResolver` (concrete stub, always `.lifetime`) | `Sources/MKFoundation/Entitlement/StubEntitlementResolver.swift` | Tests and pre-WS-10 development wiring only — never `AppEnvironment.swift`/`AppContainer.swift` production wiring; left in place (unchanged) for `MKFoundationTests` and any other module's test target that already depends on it — WS-10 did not touch this file. `MKStore.MKSandboxScenarioStub`/`TestEntitlementStub` (`#if DEBUG`) are the newer, richer test doubles WS-10 ships alongside it (six named scenario presets + a mutable stub), not a replacement for it. | Superseded in production wiring — WS-10 (`MKStore`) |
| `MKFontProviding` (protocol) | `Sources/MKFoundation/Stubs/MKFontProviding.swift` | WS-03 (`MKTextEngine`), WS-07 (`MKRender`) shaping/render fixture work before the real catalog exists | `MKFonts.FontRegistry` — bundled catalog + premium downloads + user imports, license/coverage metadata | WS-09 (`MKFonts`) |
| `SystemFontStubProvider` (concrete stub, system SF Arabic only) | `Sources/MKFoundation/Stubs/MKFontProviding.swift` | Same as above | `MKFonts.FontRegistry` | WS-09 (`MKFonts`) |
| ~~`MKDocumentStoring` (protocol)~~ **REPLACED (WS-02, done)** | `Sources/MKFoundation/Stubs/MKDocumentStoring.swift` (protocol unchanged — still the shared contract) | WS-03..WS-08 test/dev harnesses needing "open/save a document" | `MKPersistence.MKFilePackageDocumentStore` (real file-package-backed `MKDocumentStoring` conformer, atomic write-temp+rename per document blob) for generic protocol call sites; **`MKPersistence.MakhtootDocument`** (richer API: current `MKScene`, `MKUndoStack`, live `AsyncStream<MKScene>` scene updates, journal+autosave) is the intended migration target for real editor code — see `docs/impl-log/WS-02.md`'s `MakhtootDocument.swift` note for why these are two separate types rather than one. | Done — WS-02 (`MKPersistence`) |
| ~~`InMemoryDocumentStore` (concrete stub, in-memory only, no crash recovery)~~ **REPLACED (WS-02, done)** | `Sources/MKFoundation/Stubs/MKDocumentStoring.swift` (left in place for now — still referenced by pre-WS-02 test fixtures in other modules; no production `AppEnvironment.swift` wiring exists yet since WS-13 hasn't run) | Same as above | `MKPersistence.MKFilePackageDocumentStore` | Done — WS-02 (`MKPersistence`) |

## WS-07 (`MKRender`) — renderer bring-up contract (P4)

Published within WS-07's first work hour per its packet's "contract-first
duty" so WS-06 (`MKCanvas`, built concurrently) can code against these
protocols/types immediately. This section covers the **P4 renderer
bring-up slice** only — the D-116/D-223 memory-pressure ladder below ships
as hooks/seams in P4; the full hardening pass (device-verified budgets,
governor-wide cache registration, perf harness) is P14 per PLAN.md.

**Dependency-graph correction (deviation, logged here + docs/impl-log/WS-07.md):**
DEPENDENCY_GRAPH.md §2.1's diagram draws only `MKRender --> MKModel` and
`MKRender --> MKTextEngine`. In practice `MKModel`/`MKTextEngine` do not
`@_exported import MKFoundation`, so any MKRender public API spelling a
MKFoundation type by name (`MKNodeID`, `MKTransform2D`, `MKFontHandle`,
`MKFontProviding`, …) requires `import MKFoundation` directly, and Swift
Package Manager requires that to be a **declared** target dependency, not
merely a transitive one (verified empirically: `import MKFoundation`
without the Package.swift edge fails to compile). `Package.swift`'s
`MKRender` target now lists `MKFoundation` explicitly. This is not a new
architectural layer — `MKModel` and `MKTextEngine` already both depend on
`MKFoundation` — just an explicit edge the diagram omitted.

### Renderer core

```swift
// MKRender
public enum MKRenderQuality: Sendable, Hashable {
    case editorPreview(stage: MKMemoryStage)   // §11.4/§12.4 — stage ≥ .stage2 half-res + cheap shadows
    case exportQuality                          // NEVER degrades (D-118)
}

public struct MKSceneRenderer: Sendable {
    public init(fonts: any MKFontProviding = SystemFontStubProvider())
    /// The ONLY drawing entry point (INV-2, INV-6, ARCHITECTURE §11.1).
    /// Synchronous, callable from any queue — `scene` is an immutable
    /// Sendable value (D-102).
    public func render(_ scene: MKScene, region: CGRect, into ctx: CGContext,
                        scale: CGFloat, quality: MKRenderQuality) -> MKRenderReport
}

public struct MKRenderReport: Sendable, Equatable {
    public var substitutions: [MKRenderSubstitution]   // missing asset/outline/font events
    public var nodeCount: Int
    public var duration: TimeInterval
}
public struct MKRenderSubstitution: Sendable, Equatable {
    public enum Kind: Sendable, Equatable { case missingAsset, missingOutline, missingFont }
    public var nodeID: MKNodeID
    public var kind: Kind
    public var detail: String
}
```

### Snapshot / thumbnail rendering (consumed by WS-02 thumbnails, WS-08 export strips, WS-04 fidelity tests)

```swift
public struct MKSnapshotRenderer: Sendable {
    public init(fonts: any MKFontProviding = SystemFontStubProvider())
    public func render(_ scene: MKScene, region: CGRect, scale: CGFloat,
                        quality: MKRenderQuality) -> CGImage?
    public func renderThumbnail(_ scene: MKScene, longEdge: CGFloat) -> CGImage?
    /// The canonical flipped (top-left origin, y-down) bitmap context every
    /// MKRender destination (canvas layer bitmap, thumbnail, export strip)
    /// is built through — see README "Coordinate conventions". WS-08 uses
    /// this directly for its own tiled export strips.
    public static func makeFlippedBitmapContext(width: Int, height: Int, scale: CGFloat) -> CGContext?
}
```

### Layer-tree host (WS-06's attach point, D-114)

```swift
@MainActor
public protocol RenderTreeProviding: AnyObject {
    var hostLayer: CALayer { get }
    func sync(to scene: MKScene)
    /// 60/120 Hz hot path (§11.2/§14.3): layer-property-only update inside a
    /// `CATransaction` with actions disabled — zero draw/bitmap work.
    func applyTransientTransform(nodeID: MKNodeID, transform: CGAffineTransform)
    func commitTransients()
    func setVisibleRect(_ visibleRect: CGRect, zoomScale: CGFloat)
    /// Test/HUD observability (task 5 accept criterion); resets on read.
    func consumeRasterizationCount() -> Int
}
```

`StubRenderTree` (flat colored rects per node, zero CG drawing) ships
immediately so WS-06 is unblocked; `MKLayerTreeController` (real
implementation, `LayerTreeBuilder.swift`) lands the same day per the
packet's task ordering. Both conform to `RenderTreeProviding` — WS-06
codes against the protocol only.

### Hit testing (consumed by WS-06's gesture/selection policy)

```swift
public struct MKHitResult: Sendable, Equatable {
    public var nodeID: MKNodeID
    public var childID: MKNodeID?   // set when the hit is an arranged glyph/mark/ligature
    public var distance: CGFloat    // 0 = direct containment hit; >0 = slop/proximity hit
}
public struct HitTester: Sendable {
    public init()
    /// Single topmost hit — `allHits(at:in:).first`.
    public func node(at point: CGPoint, in scene: MKScene) -> MKHitResult?
    /// Every VISIBLE node under `point`, topmost first — the ordered
    /// candidate list ARCHITECTURE §10.3 tap-cycling needs. Hidden nodes
    /// are excluded; LOCKED nodes are INCLUDED (locked is policy-only,
    /// §11.2 — per the founder ruling on PRD R-4.6, tap-selection
    /// SKIPPING locked nodes is a canvas-side POLICY filter over this
    /// stack, not something `HitTester` itself decides).
    public func allHits(at point: CGPoint, in scene: MKScene) -> [MKHitResult]
    /// Full ancestor-composed world transform + node-local (pre-transform)
    /// bounds for ANY node id (top-level or nested inside groups) — build
    /// an oriented bounding box by applying `worldTransform` to
    /// `localBounds`'s four corners (MKRender does not own an OBB type;
    /// `MKCanvas.MKOrientedRect` does — this exposes the two inputs it
    /// needs, not a competing type).
    public func worldGeometry(of nodeID: MKNodeID, in scene: MKScene)
        -> (localBounds: CGRect, worldTransform: CGAffineTransform)?
    /// Precise (non-bounding-box) point-in-node test for one
    /// already-identified node id — confirms a point is inside the node's
    /// ACTUAL painted geometry (shape path, glyph-level arranged hit,
    /// live-text block, path proximity), not just its OBB/AABB. Typical
    /// use: narrow candidates via `worldGeometry`'s OBB, then confirm with
    /// this. Composes the full ancestor chain, same as `worldGeometry`.
    public func containsPrecise(nodeID: MKNodeID, worldPoint: CGPoint, in scene: MKScene) -> Bool
    public func arrangedChild(at point: CGPoint, in node: MKArrangedTextNode,
                               compositionWorldTransform: CGAffineTransform) -> MKHitResult?
    /// P4-scoped stand-in for WS-05's arc-length LUT `nearestLength`
    /// (MKPathText doesn't exist yet) — direct sampling, same tolerance
    /// contract. WS-05 (P7) may replace the implementation without an API
    /// change once its LUT lands.
    public func pathProximity(to point: CGPoint, on path: MKBezierPathData,
                               tolerance: CGFloat) -> (length: CGFloat, distance: CGFloat)?
}
```

**Gaps #1/#2 (flagged by WS-06, `docs/impl-log/WS-06.md`) — closed above,
same day:** `worldGeometry(of:in:)` + `containsPrecise(nodeID:worldPoint:in:)`
close gap #1 (bounds/OBB read query — `MKCanvasGeometrySource.worldOBB`/
`containsPrecise` build on these directly, one small adapter for the
`MKOrientedRect` construction since `MKRender` correctly does not import
`MKCanvas`'s OBB type); `allHits(at:in:)` closes gap #2 (ordered hit
stack for §10.3 tap-cycling), returning ALL visible nodes with locked ones
INCLUDED per the founder's PRD R-4.6 ruling (mid-session correction: tap
selection skips locked nodes as a canvas-side policy filter, not a
`HitTester`-level exclusion — `HitTester` reports what's really there).

### D-220 arranged-geometry chain (also consumed by WS-04/`MKArrange` when it lands, P5)

```swift
public enum MKArrangedGeometry {
    /// `composition.affine ∘ child.affine` for a glyph/ligature child
    /// (§5.3 normative). For a decomposed ligature, callers pass each
    /// COMPONENT glyph individually — see README "Decomposed ligature
    /// geometry" for the documented judgment call.
    public static func worldTransform(ofChild childID: MKNodeID, in composition: ArrangedComposition,
                                       compositionAffine: CGAffineTransform) -> CGAffineTransform?
    /// `composition.affine ∘ base.affine ∘ translate(relativeOffset) ∘ mark.affine`
    /// for a following mark (§5.3 normative, base-local `relativeOffset`).
    public static func worldTransform(ofMark markID: MKNodeID, in composition: ArrangedComposition,
                                       compositionAffine: CGAffineTransform) -> CGAffineTransform?
}
```

### Memory-pressure ladder — hooks/seams only (D-116/D-223; full hardening is P14)

```swift
public enum MKMemoryStage: Int, Sendable, Comparable { case normal = 0, stage1, stage2, critical }
public enum MKRenderFidelity: Sendable, Equatable { case full, reduced }

/// The autosave seam the ladder calls at stage transitions (INV-17/D-223:
/// save-before-degrade). WS-13/`AppEnvironment` wires an adapter over
/// MKPersistence's real `AutosaveController`/`MakhtootDocument.saveNow(reason:)`
/// (see docs/impl-log/WS-07.md) — MKRender does not import MKPersistence
/// (not a DEPENDENCY_GRAPH edge), matching the CONTRACTS.md stub-protocol
/// pattern used elsewhere in this file.
public protocol MKAutosaveTriggering: Sendable {
    func flushForMemoryPressure(stage: MKMemoryStage) async   // stages 1–2: full debounced-equivalent flush
    func flushJournalOnly() async                              // critical: D-223 journal-only, no re-encode
}

@MainActor
public final class MKDegradationController {
    public init(autosave: (any MKAutosaveTriggering)? = nil)
    public private(set) var stage: MKMemoryStage
    public var fidelity: MKRenderFidelity { get }
    /// D-116's exact banner copy, posted on entering stage2.
    public static let stage2BannerText = "الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا"
    public func transition(to stage: MKMemoryStage) async
}

public actor MKMemoryPressureMonitor {
    /// Injectable for tests (task 10 accept: "unit tests with injected
    /// readings walk 0→1→2→3 and back"); defaults to real
    /// `os_proc_available_memory()` sampling + `DispatchSource
    /// .makeMemoryPressureSource` in production.
    public init(sampler: (@Sendable () -> Double)? = nil,
                ladder: MKDegradationController)
    public func start()
    public func stop()
    /// Test seam: force one sample cycle synchronously.
    public func sampleNow() async
}
```

### P4-exit fixes (2026-07-18) — the editor's two app-side workarounds can be RETIRED

Both WS-13 Session 3 CRITICAL package bugs (`docs/impl-log/WS-13.md`,
Bugs 1–2) are fixed at the source; the corresponding app-side workarounds
are now dead weight and should be deleted by the next WS-13 session:

1. **`EditorViewModel.workAroundStaleLayerPositionBug()` — retire.**
   `MKLayerTreeController` now applies a COMMITTED transform-only change
   (move/resize/rotate, content hash unchanged) as an anchor-adjusted
   layer-property delta from the bitmap's baked transform — zero
   re-raster, no cache-busting needed. The forced zoom-bucket crossing
   (which cost a full-scene re-rasterization per mutation) is obsolete.
   Regression-locked by `MKRenderTests/CommittedTransformSyncTests`
   (committed move pixel-matches the export path with
   `consumeRasterizationCount() == 0`; committed AND transient rotation
   pivot about the correct anchor — the transient delta math was also
   quietly wrong for rotation/scale before this fix, masked by
   translation-only drag tests).
2. **`Makhtoot/AppShell/Scenes/Editor/MKAppFontProvider.swift` — retire.**
   `MKFoundation.SystemFontStubProvider` now honors the requested
   PostScript name (round-trip-verified by-name resolution, then the
   language-tagged UI font, then the SF Arabic cascade member resolved
   via `CTFontCreateForStringWithLanguage`), restoring the
   shaping↔drawing font-consistency invariant whose violation garbled
   Arabic (SF-Arabic glyph IDs drawn through SF-UI's glyph table). Note
   the app workaround's own `CTFontCreateWithName(".SFArabic")` approach
   is RUNTIME-FRAGILE — on the macOS 26 host CoreText refuses
   dot-prefixed name requests and silently substitutes TimesNewRoman —
   so retiring it in favor of the fixed stub is a correctness upgrade,
   not just cleanup. Regression-locked by
   `MKRenderTests/FontStubProviderTests` (green on the iOS 26.5
   simulator, the runtime where WS-13 observed the garbling).

`BitmapCache` registers its byte count locally (`accountedBytes`) and
exposes `purgeOffscreen()`/`purgeAll()` matching the shape ARCHITECTURE
§12.3's (not-yet-built) `MKMemoryAccountable`/`MKMemoryGovernor` expect —
so a future cross-module governor (P14, likely WS-01-owned since
`MKMemoryGovernor` is declared `// MKFoundation` in ARCHITECTURE §12.3, a
target outside this packet's fence) can register MKRender's caches without
an API change on the MKRender side. See docs/impl-log/WS-07.md.

## WS-06 (`MKCanvas`) — consumption seam over WS-07's contract (P4)

`MKCanvas` was built concurrently with WS-07's renderer bring-up (above).
As of this note, WS-07's `RenderTreeProviding`/`HitTester` are published
here as a contract but not yet present in `Sources/MKRender/`'s actual
build (verified by inspection, re-checked at session end) — WS-07 is
mid-flight on its own committed contract. Rather than block or guess,
`MKCanvas` declares its OWN local seam with signatures mirroring the
published contract exactly, so wiring the real types in later (once they
land) is a one-line substitution, not a redesign:

```swift
// MKCanvas/Geometry/MKCanvasGeometrySource.swift
@MainActor
public protocol MKCanvasGeometrySource: AnyObject {
    func worldOBB(for nodeID: MKNodeID, in scene: MKScene) -> MKOrientedRect?
    func containsPrecise(nodeID: MKNodeID, worldPoint: CGPoint, in scene: MKScene) -> Bool // has a default
}

@MainActor
public protocol MKCanvasRenderBridge: AnyObject {
    func applyTransientTransform(nodeID: MKNodeID, transform: CGAffineTransform)
    func commitTransients()
}
```

**Two confirmed contract gaps for WS-07 (not invented around — flagged for
a follow-up, full detail in `docs/impl-log/WS-06.md`):**

1. Neither `RenderTreeProviding` nor `HitTester` exposes a per-node
   world-bounds/OBB READ query anywhere — `HitTester.node(at:in:)` is a
   point-in/point-out test, `RenderTreeProviding` is write-only
   (`applyTransientTransform`). `MKCanvasGeometrySource.worldOBB(for:in:)`
   above has no real conformer to attach to yet — marquee selection,
   snapping candidates, selection-chrome placement, handle math, and
   `InspectorModel`'s W/H fields all need this and currently run only
   against a synthetic test double (`Tests/MKCanvasTests
   /CanvasTestSupport.swift`'s `FakeGeometrySource`). Recommendation: add
   a bounds/OBB accessor to `RenderTreeProviding` (or a sibling protocol).
2. `HitTester.node(at:in:)` returns a single best hit, not an ordered
   candidate list — ARCHITECTURE §10.3's tap-cycling ("repeated taps...
   walk the `hits` array") cannot be built on it as published.
   `MKCanvas/HitTestPolicy.swift` implements the full cycling/ordering/
   tolerance/locked-hidden-exclusion policy against a candidate list a
   caller supplies (today: gap 1 again). Recommendation: a multi-hit query
   on `HitTester`, or `MKCanvas` builds its own list once gap 1 is closed.

`MKCanvasRenderBridge`'s method NAMES are intentionally identical to
`RenderTreeProviding`'s (`applyTransientTransform`, `commitTransients()`)
so that once `RenderTreeProviding` builds for real, any conformer of it
already satisfies `MKCanvasRenderBridge` verbatim — no adapter needed
beyond passing the same instance through.

`MKCanvas`'s undo-command layer also added four LOCAL conformers of the
public, open `MKCommand` protocol (`MKCanvasMultiTransformCommand`,
`MKCanvasMultiCoreCommand`, `MKCanvasTextEditCommand`,
`MKCanvasUngroupCommand` — `Sources/MKCanvas/Commands/
MKCanvasCompositeCommands.swift`) that WS-02's closed `MKCommandCoder`
switch could not encode — meaning `CommandJournal.append` threw
`unknownCommandType` for them and those gestures were silently exempt from
crash-recovery replay.

**RESOLVED (WS-02 session 2, coordinator-directed — see
`docs/impl-log/WS-02.md` session 2 for full detail). Canvas side: converge
by adopting the canonical primitives and retiring your local conformers.**
`MKPersistence/Undo/Commands.swift` now ships journal-codable canonical
equivalents, matching the canvas conformers' semantics (including
coalescing-key formats) so adoption is drop-in:

| Retire (MKCanvas local) | Adopt (canonical, `MKPersistence`) | Notes |
|---|---|---|
| `MKCanvasMultiTransformCommand` | `MKBatchTransformCommand(gestureID:newTransforms:)` | same `[MKNodeID: MKTransform2D]` shape, same `"move-\(gestureID)"` coalescing key |
| `MKCanvasMultiCoreCommand` | `MKBatchCoreCommand(gestureID:newCores:label:)` | same `[MKNodeID: MKNodeCore]` shape, same `"core-\(gestureID)"` key, same Arabic default label |
| `MKCanvasTextEditCommand` | `MKTextEditCommand(nodeID:newNode:burstKey:)` | same opaque-replace + caller-supplied `burstKey` contract (§14.3, 700 ms window) |
| `MKCanvasUngroupCommand` | `MKUngroupCommand(groupID:)` | the upstream transform-composition bug is FIXED in the canonical command — it now composes the group's own transform into each child before splicing (same math as `MKGroupTransform.worldTransform`, inlined since `MKPersistence` cannot import `MKCanvas`); regression-tested in `Tests/MKPersistenceTests/CommandPropertyTests.swift` |

All four canonical types round-trip through `MKCommandCoder`
(`"batchTransform"`/`"batchCore"`/`"textEdit"` cases added; `"ungroup"`
already existed) and are covered by per-type coding round-trip tests plus
a journal-replay test including a batch command
(`Tests/MKPersistenceTests/CommandCoderTests.swift`) — the D-223/no-loss
guarantee now holds for these gesture classes. Any FUTURE module-local
`MKCommand` conformer will hit the same journal-invisibility issue:
prefer adding the command to the canonical catalog + `MKCommandCoder`
(coordinate with whoever owns `MKPersistence/Undo/`) over shipping a
module-local conformer.

### WS-06 path-edit seam over `MKPathText` (task 16, PLAN P7)

Same class of gap as the WS-07 consumption seam above, this time against
`MKPathText` (P7, landed after this seam was first needed): `Package.swift`'s
`MKCanvas` target does not depend on `MKPathText`, so `MKCanvas` declares
its own local seam mirroring `MKPathText`'s hit-testing/handle vocabulary,
spelled entirely in terms of `MKModel.MKPathTextNode` +
`MKPersistence.MKCommand` (full detail, real bugs found, and test evidence:
`docs/impl-log/WS-06.md` Session 4 and `docs/impl-log/WS-13.md` Session 6):

```swift
// MKCanvas/PathText/MKPathTextEngineProviding.swift
@MainActor
public protocol MKPathTextEngineProviding: AnyObject {
    func hitTargets(for node: MKPathTextNode) -> [MKPathHitTarget]
    func nearestHitTarget(to point: CGPoint, for node: MKPathTextNode, tolerance: CGFloat) -> MKPathHitTarget?
    func curvatureWarning(for node: MKPathTextNode) -> Bool
    func moveAnchorCommand(_ anchorID: UUID, to newPoint: CGPoint, moveHandles: Bool, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)?
    func moveHandleCommand(_ handleID: MKPathHandleID, to newPoint: CGPoint, mode: MKPathHandleMode, nodeID: MKNodeID, in scene: MKScene, coalescingKey: String) -> (any MKCommand)?
    func insertAnchorCommand(near point: CGPoint, nodeID: MKNodeID, in scene: MKScene) -> (command: any MKCommand, anchorID: UUID)?
    func deleteAnchorCommand(_ anchorID: UUID, nodeID: MKNodeID, in scene: MKScene) -> (any MKCommand)?
    func toggleClosedCommand(nodeID: MKNodeID, in scene: MKScene) -> (any MKCommand)?
    func glyphHitTest(at point: CGPoint, node: MKPathTextNode) -> MKPathGlyphHit?
    func setGlyphOffsetCommand(_ offset: MKPathGlyphOffset, forKey key: MKPathGlyphOffsetKey, nodeID: MKNodeID, in scene: MKScene, gestureID: UUID) -> (any MKCommand)?
}
```

Four structural mirror types accompany it: `MKPathHandleID`
(`{anchorID: UUID, kind: .anchor/.handleIn/.handleOut}`), `MKPathHitTarget`
(`{id: MKPathHandleID, position: CGPoint}`), `MKPathHandleMode`
(`.mirrored`/`.free`), `MKPathGlyphHit`
(`{key: MKPathGlyphOffsetKey, position: CGPoint, currentOffset:
MKPathGlyphOffset}`). The app-layer conformer is
`Makhtoot/AppShell/Scenes/Editor/MKPathTextInteractionAdapter.swift` (see
`docs/impl-log/WS-13.md`). By design, R-9.4's path-options edits
(`startOffset`/`side`/`spacingMode`) and reverse-direction do NOT route
through this seam at all — `MKPathLayoutOptions` is a plain,
already-`MKModel`-owned Codable struct `MKCanvas` can mutate directly via
the generic `MKReplaceNodesCommand`, and reversing a Bézier path's
direction is self-contained cubic-Bézier algebra with no `MKPathText`
dependency — so both stay local to `MKCanvas`/`MKPathTextInteractionModel`
rather than adding seam methods with no real cross-module algorithm behind
them.

`MKCanvasViewController` gained a `pathTextInteraction:
MKPathTextInteractionModel?` injection property (mirrors the existing
`arrangeInteraction` property's `didSet`-forwarding pattern) and a
`pathEditChrome: PathEditChromeLayer` property, refreshed from
`refreshSelectionChrome()` alongside the existing selection chrome.

### WS-06 arrange-mode seam over `MKArrange` (task 15, deferred to P4-CANVAS-LANE) — documentation gap closed P14

Same class of gap as the two seams immediately above (WS-07's
`RenderTreeProviding`/`HitTester` and WS-05's `MKPathText` hit-testing),
this time against `MKArrange` (P5, landed after WS-06's own P4 session
needed arrange-mode UX): `Package.swift`'s `MKCanvas` target does not (and
per WS-06's own fence may not) depend on `MKArrange`, so `MKCanvas`
declares its own local seam — `Sources/MKCanvas/Arrange/
MKArrangeEngineProviding.swift` — spelled entirely in terms of types it
already has access to (`MKModel`'s arranged-node types — `MKArrangedTextNode`,
`ArrangedComposition`, `MKArrangedChild`, `MKGlyphNode`, `MKMarkNode`,
`MKJoiningForm` are all `MKModel` declarations, not `MKArrange` ones — plus
a handful of small `MKArrange`-owned result/option types mirrored below)
and `MKPersistence.MKCommand`. This file existed since WS-06's own session
but was never published here — flagged as a P14 documentation-only gap
(`docs/impl-log/WS-07-p14-run3.md`, backlog item 4) and closed now, no
source change:

```swift
// MKCanvas/Arrange/MKArrangeEngineProviding.swift
@MainActor
public protocol MKArrangeEngineProviding: AnyObject {
    // Entry & derivation (R-6.1, R-6.2)
    func deriveArrangeCommand(sourceNodeID: MKNodeID, in scene: MKScene) async throws -> (any MKCommand)?

    // Revert (R-6.12, FL-13)
    func revertPreflight(for node: MKArrangedTextNode) -> MKArrangeRevertPreflight
    func revertCommand(arrangedNodeID: MKNodeID, node: MKArrangedTextNode) throws -> any MKCommand

    // Level mapping (R-6.4, R-6.14)
    func nodeIDs(forUTF16Range range: Range<Int>, in composition: ArrangedComposition, includeMarks: Bool) -> Set<MKNodeID>
    func utf16Ranges(forNodeIDs ids: Set<MKNodeID>, in composition: ArrangedComposition) -> [Range<Int>]
    func clusterSiblings(of id: MKNodeID, in composition: ArrangedComposition) -> Set<MKNodeID>

    // Join break/restore + form selector (§8.1)
    func breakJoinCommand(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode) async throws -> any MKCommand
    func restoreJoinCommand(nodeAID: MKNodeID, nodeBID: MKNodeID, ownerNode: MKArrangedTextNode) async throws -> any MKCommand
    func formSelectorModel(for nodeID: MKNodeID, ownerNode: MKArrangedTextNode) async -> MKArrangeFormSelectorModel?
    func formSelectionCommand(selecting form: MKJoiningForm, from model: MKArrangeFormSelectorModel, ownerNode: MKArrangedTextNode) -> (any MKCommand)?

    // Ligature decompose/recompose (§8.2)
    func canDecompose(groupID: MKNodeID, ownerNode: MKArrangedTextNode) -> Bool
    func decomposeCommand(groupID: MKNodeID, ownerNode: MKArrangedTextNode, fidelity: Bool) async throws -> (command: any MKCommand, fidelityAutoRefused: Bool)
    func recomposePreflight(groupID: MKNodeID, ownerNode: MKArrangedTextNode) -> MKArrangeRecomposePreflight
    func recomposeCommand(groupID: MKNodeID, ownerNode: MKArrangedTextNode, force: Bool) throws -> any MKCommand

    // Marks (§7)
    func detachMarkCommand(markID: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)?
    func reattachMarkCommand(markID: MKNodeID, toBase: MKNodeID, ownerNode: MKArrangedTextNode) -> (any MKCommand)?

    // Per-child style/transform edit helpers (task 13, R-6.5)
    func nudgePositionCommand(by delta: CGSize, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand
    func setTransformCommand(_ transform: MKTransform2D, forChildID id: MKNodeID, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand
    func setStyleCommand(_ style: MKStyle, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand
    func setOpacityCommand(_ opacity: Double, forChildIDs ids: Set<MKNodeID>, ownerNode: MKArrangedTextNode, gestureID: UUID) -> any MKCommand
}
```

Four structural mirror types accompany it (same file): `MKArrangeFormOption`
(`{form, isValid, achieved, previewOutline, previewAdvance, glyphID}` —
mirrors `MKArrange.MKFormOption`), `MKArrangeFormSelectorModel`
(`{nodeID, scalar, currentForm, options: [MKArrangeFormOption]}` — mirrors
`MKArrange.FormSelectorModel`), `MKArrangeRevertPreflight`
(`{editedNodeCount, willDiscard}`, plus R-6.12/FL-13's exact Arabic
confirmation copy as static constants — mirrors `MKArrange.RevertService
.RevertPreflight`), `MKArrangeRecomposePreflight`
(`{editedComponentCount, requiresConfirmation}`, plus R-8.12's exact
confirmation copy — mirrors the D-221 recompose dirty-check payload).
`MKArrangeSourceEditConflict` (R-6.11's exact choice-sheet copy) is a
standalone enum of static constants, not a structural mirror of anything
in `MKArrange`.

The app-layer conformer is `Makhtoot/AppShell/Scenes/Editor/
MKArrangeInteractionAdapter.swift` — every method a near-verbatim pass-
through to the matching `MKArrange` API (`ArrangeDeriver`, `RevertService`,
`LevelMapping`, `JoinController`, `FormSelectorModel`, `LigatureDecomposer`,
`MarkAttachmentController`, `ArrangeStyleEditor`), the same "one-line
substitution, not a redesign" promise `MKCanvasRenderAdapter` delivers for
`MKCanvasGeometrySource`/`MKCanvasRenderBridge` and
`MKPathTextInteractionAdapter` delivers for `MKPathTextEngineProviding`
above. Unlike those two siblings, this seam has no OPEN contract gap
recorded against it — `MKArrange`'s real API (published in this file's
"WS-04 (`MKArrange`) — arrange-engine contract" section below) already
covers everything `MKCanvas`'s arrange-mode UX needs; this subsection is a
documentation-parity fix only (the seam was fully implemented and in
production use, just never written down here), not a functional change.

## Module placeholder markers

Every non-WS-01 `MakhtootKit` target ships exactly one
`<Module>Placeholder.swift` file with `public enum <Module>Info { public
static let owner = "WS-xx" }`, naming the packet that replaces the stub
with real code. This is not a protocol contract (nothing consumes
`<Module>Info` at runtime) — it exists so `search_code`/`grep` against the
repo immediately surfaces which packet owns an empty target, and so the
module compiles (an SPM target needs at least one source file). See
`README.md` in this directory for the full module list, or
`FOUNDATION.md` §2 for the authoritative module→workstream map.

## WS-04 (`MKArrange`) — arrange-engine contract (P5 slice)

Published per the packet's task 1 accept criterion ("protocol documented;
WS-05 signs off on the shape"). This section covers the PLAN P5 slice only
(derivation, provenance, revert, per-node manipulation primitives,
both-levels selection) — form-selector *popover* rendering and
canvas-level mark/ligature manipulation UX are WS-06/P6, out of this
packet's scope regardless of slice.

### `PathPlacementProviding` — the WS-05 arrange-on-path seam

```swift
// MKArrange
public struct MKPathGlyphPlacement: Sendable, Equatable {
    public var position: CGPoint       // composition-local (y-up, see coordinate-convention note below)
    public var tangentAngle: CGFloat   // radians, same convention as MKTransform2D.rotation
}

public protocol PathPlacementProviding: Sendable {
    /// `nil` = no path override for this glyph, use the straight-baseline
    /// shaped position (every plain Live-Text derivation hits this for
    /// every glyph via `IdentityPlacement`).
    func placement(for address: MKGlyphAddress, lineIndex: Int) -> MKPathGlyphPlacement?
}

public struct IdentityPlacement: PathPlacementProviding {
    public init()
    public func placement(for address: MKGlyphAddress, lineIndex: Int) -> MKPathGlyphPlacement? { nil }
}
```

WS-05 develops its own arc-length-LUT conformer against this protocol
without needing `ArrangeDeriver`'s internals; `ArrangeDeriver` develops
against `IdentityPlacement` without needing WS-05 to exist. Neither side
blocks the other.

### `ArrangeDeriver` — the D-106 pipeline

```swift
public struct ArrangeDeriver: Sendable {
    public init(fonts: any MKFontProviding = SystemFontStubProvider())
    /// async: outline extraction goes through the actor-isolated
    /// MKGlyphPathProvider (INV-1/INV-13 — extraction happens once here,
    /// arranged rendering never asks the font again).
    public func derive(
        sourceText: String, style: MKTextStyle, capture: MKShapingCaptureResult,
        pathData: MKBezierPathData? = nil, placement: any PathPlacementProviding = IdentityPlacement()
    ) async -> ArrangedComposition
}
```

**Coordinate convention (normative, consumed by `MKRender`'s already-shipped
`ArrangedGeometry`/`ArrangedDrawer` with ZERO changes on that side):**
`MKGlyphLayout.position`/`MKMarkNode.relativeOffset` are composition-local,
**y-up** — the same axis convention Core Text captures in, not MKRender's
y-down document space. Per-line stacking matches `LiveTextDrawer`'s own
`lineOriginY` computation exactly. Full derivation in `ArrangeDeriver.swift`'s
file header and `MKArrange/README.md`.

### Command layer — one new type, everything else reuses `MKPersistence`'s catalog

```swift
// Node-kind swaps (liveText/pathText ⇄ arranged): MKPersistence's EXISTING
// MKReplaceNodeCommand, unchanged — its own doc comment already names this
// exact use.
public enum ArrangeCommands {
    public static func arrangeCommand(
        sourceNodeID: MKNodeID, core: MKNodeCore, composition: ArrangedComposition, derivedFrom origin: MKArrangeOrigin
    ) -> any MKCommand   // MKReplaceNodeCommand under the hood
}

// Composition-internal mutations (join break/restore, ligature
// decompose/recompose, mark attach/detach/move, per-node style/transform
// edits): the ONE new MKCommand type this module adds.
public struct MKArrangedCompositionCommand: MKCommand, Codable {
    public var ownerNodeID: MKNodeID
    public var newComposition: ArrangedComposition
    public var label: String
    public var coalescingKeySuffix: String?   // nil = never coalesces
}
```

**RESOLVED (WS-02 session 3, coordinator-directed — see
`docs/impl-log/WS-02.md` session 3). Arrange side: converge by adopting
the canonical command and retiring `MKArrangedCompositionCommand`.**
`MKCommandCoder` can never reference `MKArrange` types (the dependency
edge runs `MKArrange → MKPersistence`), so the resolution is a canonical,
GENERIC structural-replace command in `MKPersistence/Undo/Commands.swift`,
journal-codable (`"replaceNodes"` coder case, enforced by the
catalog-sweep test):

| Retire (MKArrange local) | Adopt (canonical, `MKPersistence`) | Notes |
|---|---|---|
| `MKArrangedCompositionCommand(ownerNodeID:newComposition:label:coalescingKeySuffix:)` | `MKReplaceNodesCommand(nodeID:newNode:label:coalescingKeySuffix:)` | Build the full replacement node value (`.arranged(updatedNode)` — the controller already holds the composition; read the current node's core from the scene it is building the command against) instead of passing the composition alone. Same label passthrough; same optional-coalescing contract (`nil` default = one-shot structural op — derive/revert/decompose/recompose; per-gesture suffix for slider-style continuous edits — the key becomes `"replaceNodes-<suffix>"` instead of `"arrange-<suffix>"`, behaviorally equivalent since keys only need consistency within one gesture bracket). Multi-node form `MKReplaceNodesCommand(newNodes:label:...)` also available. |

Two deliberate semantic differences to be aware of when migrating
(both consistent with the catalog's absolute-value idiom): (1) the
canonical command snapshots the FULL node (core included) rather than
reading the core at apply time — under journal replay the `baseRev` chain
guarantees the replay base equals the creation base, so results are
identical; (2) a target that is missing throws
`MKPersistenceError.nodeNotFound` and a target of the wrong node kind is
simply replaced (no `sourceNodeNotArranged` guard — callers construct
replacements from the live scene, making that check redundant at the
command layer; keep kind validation in the controller if wanted).
`ArrangeCommands.arrangeCommand`'s existing use of `MKReplaceNodeCommand`
(already journal-codable) may stay as-is or move to
`MKReplaceNodesCommand` for the label — either is journal-safe.

### Engine primitives (P5 slice — pure models/controllers, no UI)

```swift
public enum LevelMapping {
    public static func nodeIDs(forUTF16Range: Range<Int>, in: ArrangedComposition, includeMarks: Bool = true) -> Set<MKNodeID>
    public static func utf16Ranges(forNodeIDs: Set<MKNodeID>, in: ArrangedComposition) -> [Range<Int>]
}

public struct JoinController: Sendable {
    public func breakJoin(_ a: MKGlyphNode, _ b: MKGlyphNode, style: MKTextStyle) async throws -> JoinEditResult
    public func restoreJoin(_ a: MKGlyphNode, _ b: MKGlyphNode, style: MKTextStyle) async throws -> JoinEditResult
}

public struct FormSelectorModel: Sendable, Equatable {
    public static func build(for: MKNodeID, in: ArrangedComposition, style: MKTextStyle, fonts: any MKFontProviding) async -> FormSelectorModel?
    public func command(selecting: MKJoiningForm, ownerNodeID: MKNodeID, composition: ArrangedComposition) -> (any MKCommand)?
}

public struct LigatureDecomposer: Sendable {
    public func decomposeCommand(groupID: MKNodeID, ownerNodeID: MKNodeID, composition: ArrangedComposition, options: DecomposeOptions = .fidelityDefault) async throws -> any MKCommand
    public func recomposeCommand(groupID: MKNodeID, ownerNodeID: MKNodeID, composition: ArrangedComposition, force: Bool = false) throws -> any MKCommand
}

public struct MarkAttachmentController: Sendable {
    public func detachCommand(markID:ownerNodeID:composition:) -> (any MKCommand)?
    public func reattachCommand(markID:toBase:ownerNodeID:composition:) -> (any MKCommand)?   // D-220 normative formula
    public func moveCommand(markID:byDelta:ownerNodeID:composition:gestureID:) -> (any MKCommand)?
}

public struct RevertService: Sendable {
    public func preflight(for: ArrangedComposition) -> RevertPreflight   // {editedNodeCount, willDiscard}
    public func revertCommand(arrangedNodeID: MKNodeID, node: MKArrangedTextNode) throws -> any MKCommand
}

public enum MKArrangeInvariants {
    public static func assertReshapeAllowed(on: MKArrangeNodeKind) throws   // throws MKArrangeError.arrangedNodeCannotReshape
}
```

(This snippet reflects the P5-slice signatures at time of writing; Session 2
already migrated every `ownerNodeID:`/`composition:` pair above to a single
`ownerNode: MKArrangedTextNode` parameter — see the "Command layer" table
above. Session 3/P6 additionally added `cursiveFidelityNote: Bool` to
`JoinController.JoinEditResult` and `LigatureDecomposer.DecomposeResult`.
Full, current signatures live in the source files themselves; this snippet
is illustrative, not re-synced on every session per this file's own
convention elsewhere.)

Full detail (algorithms, documented deviations, ADRs) in
`Sources/MKArrange/README.md` and `docs/impl-log/WS-04.md`.

## WS-16 (`docs/impl-log/WS-16-cursive.md`) — cursive-attachment provenance, required `MKArrange` follow-up

D-222 step 8 held 5 fonts (Amiri, Amiri Quran, Aref Ruqaa, Rakkas, Qahiri)
out of the catalog pending a "cursive-pair structure" in D-105's capture
model (GPOS LookupType 3 present on their base glyphs). WS-16 resolved this
— probed empirically that `CTRunGetPositions` already bakes the
cursive-adjusted position into capture and that `MKArrangedGeometry`'s D-220
affine chain composes `layout.position` as an opaque translation regardless
of what produced it, so display/translate/rotate/scale of cursive-attached
glyphs already work correctly with **zero geometry changes** — and shipped
the minimal structure D-222 actually needed: a per-glyph provenance flag,
not a full anchor-delta structure. Full evidence, probe transcripts, and
ADRs WS16-A1..A4 in `docs/impl-log/WS-16-cursive.md`. The 5 fonts are now
released into `Resources/catalog-seed.json` (`Resources/EXCLUDED_FONTS.md`'s
"Released this session" section has the complete disposition).

**What shipped (MKTextEngine, MKModel — this session, no MKArrange edits):**

```swift
// MKTextEngine — ShapedModels.swift
public struct MKShapedRun: Hashable, Sendable {
    // ...existing fields...
    /// Index-parallel to `glyphs`. `true` when the glyph ID is a member of
    /// the font's GPOS 'curs' (LookupType 3) coverage table — a Coverage-
    /// table-ONLY read (`MKCursiveCoverageCache`/`MKGPOSCursiveParser`,
    /// CursiveAttachment.swift), never anchor values, never feeding into
    /// any position computation.
    public var cursiveAttached: [Bool]
}

// MKModel — Arranged/GlyphNode.swift
public struct MKProvenance: Hashable, Sendable, Codable, Equatable {
    // ...existing fields...
    /// Additive/defaulted (`= false`); decodes `false` for any pre-WS-16
    /// scene.json with no `cursiveAttached` key — no schemaVersion bump.
    public var cursiveAttached: Bool
}
```

**RESOLVED (Run-3 WS-04 P6 session, `docs/impl-log/WS-04.md` Session 3).**
Items 1-2 below are now implemented: `ArrangeDeriver` threads
`cursiveAttached` through every `MKProvenance` it builds, and
`JoinController.JoinEditResult`/`LigatureDecomposer.DecomposeResult` both
gained a `cursiveFidelityNote: Bool` field surfacing the WS-16 Finding 6
disposition. Item 3 (no `MarkAttachmentController`/`MKArrangedGeometry`/
`ArrangedDrawer` change needed) is unchanged/confirmed. Item 4 (test
coverage once wired) is done —
`Tests/MKArrangeTests/JoinControllerTests.swift`'s
`breakJoinSurfacesCursiveFidelityNoteOnAmiriSeenJeem`/
`.breakJoinDoesNotSurfaceCursiveFidelityNoteOnNonCursiveFont` and
`Tests/MKArrangeTests/LigatureDecomposerTests.swift`'s
`decomposeSurfacesCursiveFidelityNoteFromOriginalProvenance`. Original
follow-up text preserved below for the historical record.

**Required follow-up for whoever next touches `MKArrange`** (not done this
session — out of this session's scope fence, which excluded `MKArrange`
sources/tests because a sibling agent was actively working there):

1. **Thread the flag through derivation.** `ArrangeDeriver`'s
   `makeGlyphNode`/`appendLigature`/`appendBaseWithMarks`/`appendMarkOnly`
   (`Sources/MKArrange/ArrangeDeriver.swift`) each build an `MKProvenance`
   from a `cluster`/`address` pair that has direct access to the owning
   `MKShapedRun` (`line.runs[address.run]`) — read
   `run.cursiveAttached[address.glyph]` and pass it as `MKProvenance`'s new
   `cursiveAttached:` parameter (defaults to `false` today, so this is a
   pure additive change, zero risk to existing behavior until wired).
2. **Treat a cursive-attached join-break/restore or ligature-decompose as
   the SAME accepted-by-design, documented class D-222 already establishes
   for single-glyph scale inside a joined word (T-AR-60/TEST_MATRIX.md
   §7.9)** — not a bug to silently paper over, not something to block on.
   Concretely: `JoinController.breakJoin`/`restoreJoin`
   (`Sources/MKArrange/JoinController.swift`) and
   `LigatureDecomposer.decompose` (`Sources/MKArrange/LigatureDecomposer.swift`)
   reshape a glyph via `MKFormResolver`'s D-107 ZWJ-synthetic-context
   technique, which — confirmed empirically this session
   (`docs/impl-log/WS-16-cursive.md` ADR WS16-A4) — does not always
   reproduce the exact natural glyph id for a `cursiveAttached == true`
   glyph (ZWJ cannot trigger the contextual GSUB substitution that feeds a
   font's `curs` feature). Recommendation: surface this via
   `JoinEditResult`/`DecomposeResult` (e.g. a `fidelityNote`-style field, or
   reuse the existing `fidelityAutoRefused`-style notice pattern
   `LigatureDecomposer` already has for the D-221 clamp case) so a future
   WS-06/canvas consumer CAN show the user an honest "the connecting stroke
   may not match exactly" hint for these specific letters — optional
   polish, not a correctness requirement (the operation already completes
   cleanly and produces a valid, non-corrupting result either way, per
   `CursiveJoinBreakEvidenceTests.swift`'s regression coverage).
3. **No change needed to `MarkAttachmentController`, `MKArrangedGeometry`,
   or `ArrangedDrawer`/`HitTester`** — verified this session that mark
   re-anchoring (`relativeOffset` recomputation) and the D-220 world-
   transform composition are already correct regardless of whether a base
   glyph's position happens to include a cursive adjustment (the affine
   chain treats `layout.position` as opaque, exactly as it should — see
   the ADR for the full argument). Flagged here only so nobody "fixes" a
   non-bug in response to this note.
4. **Test coverage once wired**: `Tests/MKArrangeTests/JoinControllerTests.swift`/
   `LigatureDecomposerTests.swift` can add an Amiri-backed
   `cursiveAttached`-flagged fixture (mirroring
   `Tests/WS16CursiveTests/CursiveJoinBreakEvidenceTests.swift`'s pattern,
   which is a temporary stand-in in a separate test target precisely
   because it duplicates what belongs in `MKArrangeTests` once the flag is
   wired through the real `ArrangeDeriver` path — `WS16CursiveTests`
   re-derives the flag directly from `MKShapingService`'s capture result to
   demonstrate the prediction is correct today, independent of this
   follow-up landing).

## WS-05 (`MKPathText`) — path text engine contract (P7)

Published per `AGENT_TASK_PACKETS/WS-05-path-text.md`'s instruction to
publish the public API early and note the `MKRender` sampler-replacement
seam. Full design rationale/worked examples: `Sources/MKPathText/README.md`.
Evidence/deviations: `docs/impl-log/WS-05.md`.

**Dependency-graph additions (deviations, logged here + `Package.swift` +
`docs/impl-log/WS-05.md`, same precedent WS-03/06/07 already established
for their own targets):** `DEPENDENCY_GRAPH.md`'s diagram draws only
`MKPathText --> MKModel, MKPathText --> MKTextEngine`. `MKPathText`'s
`Package.swift` target now also depends on `MKFoundation` (public API
spells `MKID`/`MKGlyphAddress`/`MKClusterID` directly — same empirically-
verified reasoning WS-03/06/07 logged), `MKPersistence` (`PathTextCommands.swift`
builds `MKCommand`/`MKReplaceNodesCommand`, no cycle — `MKPersistence`
depends only on `MKModel`/`MKFoundation`), and `MKArrange` (`PathPlacementProvider.swift`
conforms to `MKArrange.PathPlacementProviding` — Swift requires importing
the module that declares a protocol to conform to it; `MKArrange` never
depends on `MKPathText`, so this edge is acyclic).

### DF-6a binding note

The pen order is **logical reading order**, not "visual order" — the
WS-05 packet's own task 4a/4b prose used the superseded name.
`ARCHITECTURE.md` §9.4 and `TEST_MATRIX.md` T-PTH-2 are authoritative;
`PathLayoutEngine`'s `flowDirection` option from the packet's prose was
dropped entirely (there is one pen order). See
`Sources/MKPathText/PathLayoutEngine.swift`'s file header and
`README.md`'s worked examples for the full reasoning (walking
`MKClusterMap.clusters` in its own array order already realizes DF-6a
directly, since that array is built by a global UTF-16-offset sort).

### Core types

```swift
// MKPathText
public struct BezierPathModel: Hashable, Sendable {
    public var anchors: [PathAnchor]     // {id, point, handleIn?, handleOut?}
    public var isClosed: Bool
    public init(_ data: MKModel.MKBezierPathData)
    public func bezierPathData() -> MKModel.MKBezierPathData
    public func cgPath() -> CGPath
    public var isValid: Bool             // >=2 anchors open / >=3 closed
    public static func line(from:to:) -> BezierPathModel
    public static func arc(center:radius:startAngle:endAngle:) -> BezierPathModel
    public static func circle(center:radius:) -> BezierPathModel
    public static func wave(rect:periods:amplitude:) -> BezierPathModel
}

public struct ArcLengthLUT: Sendable {
    public init(path: BezierPathModel)
    public init(segments: [MKModel.MKBezierSegment])
    public let totalLength: CGFloat
    public let segmentCount: Int
    public func point(atLength:) -> CGPoint
    public func tangent(atLength:) -> CGVector
    public func frame(atLength:) -> (point: CGPoint, tangent: CGVector, normal: CGVector)
    public func segmentAndLocalT(atLength:) -> (segmentIndex: Int, localT: CGFloat)
    public func nearestLength(to: CGPoint) -> CGFloat
}

public enum PathLayoutEngine {
    public static func layout(
        line: MKTextEngine.MKShapedLine, lineIndex: Int = 0, path: BezierPathModel,
        options: PathLayoutOptions, userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [:]
    ) -> PathLayoutResult
    public static func layout(
        line: MKTextEngine.MKShapedLine, lineIndex: Int = 0, lut: ArcLengthLUT,
        options: PathLayoutOptions, userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [:]
    ) -> PathLayoutResult
    /// Closed-path variant: arc length wraps modulo `totalLength + closedPathGap`.
    public static func layoutClosed(
        line: MKTextEngine.MKShapedLine, lineIndex: Int = 0, lut: ArcLengthLUT,
        options: PathLayoutOptions, userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [:]
    ) -> PathLayoutResult
}
```

### The `PathPlacementProviding` conformer (WS-04 seam, task 12)

```swift
public struct MKPathTextPlacementProvider: MKArrange.PathPlacementProviding {
    public init(layout: PathLayoutResult, lineIndex: Int = 0)
    public func placement(for address: MKTextEngine.MKGlyphAddress, lineIndex: Int) -> MKArrange.MKPathGlyphPlacement?

    /// Builds a provider ready for `ArrangeDeriver.derive(..., placement:)` —
    /// performs the ONE y-flip reconciling canvas Y-DOWN path authoring
    /// with `ArrangeDeriver`'s composition-local Y-UP convention (worked
    /// example: `README.md`'s "Coordinate frames" section).
    public static func forArrangeOnPath(
        line: MKTextEngine.MKShapedLine, lineIndex: Int = 0, path: MKModel.MKBezierPathData,
        options: PathLayoutOptions, userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [:]
    ) -> (provider: MKPathTextPlacementProvider, result: PathLayoutResult)
}
```

Verified end-to-end against the REAL `MKArrange.ArrangeDeriver`/`RevertService`
(not a fake): `Tests/MKPathTextTests/PathPlacementProviderTests.swift` —
derived glyph nodes match live placements within 0.1 pt (task 12 accept),
and an arrange→revert round trip restores a live `pathText` node on the
identical path.

### Known schema gap (flagged per the packet's "stop-and-report on
locked-decision conflicts" instruction — not a D-1xx conflict, a fence/
schema gap)

**RESOLVED (Run-3 PATH-UX session).** Closed by
`MKModel.MKPathGlyphOffsetKey`/`MKPathGlyphOffset`
(`Sources/MKModel/MKPathGlyphOffset.swift`) +
`MKPathTextNode.glyphOffsets: [MKPathGlyphOffsetKey: MKPathGlyphOffset]`
(`Sources/MKModel/MKNode.swift`, additive, `decodeIfPresent ?? [:]`, no
`schemaVersion` bump — the same pattern WS-16's `MKProvenance
.cursiveAttached` already established) plus
`PathTextCommands.setGlyphOffset(_:forKey:nodeID:in:gestureID:)` (a real,
coalescable `MKReplaceNodesCommand` builder,
`Sources/MKPathText/PathTextCommands.swift`) and `PathTextCommands
.persistedUserOffsets(from:)` (the persisted→engine-input conversion seam).
`PathTextOffsetStore` is retained as a legacy, session-scoped convenience —
see `Sources/MKPathText/README.md`'s "Known schema gap" section for the
current framing, and `docs/impl-log/WS-05.md`'s PATH-UX addendum for full
detail and tests. Original gap text preserved below for the historical
record.

Packet tasks 3/9/11 ask for per-glyph user offsets round-tripping through
`MKPathTextNode`'s Codable persistence. The shipped `MKModel.MKPathTextNode`
(WS-02) has no field for this. `PathLayoutEngine` fully supports user
offsets at the engine level (`[PathClusterProvenanceKey: PathGlyphUserOffset]`
input, tested); persistence needs a small additive `MKModel.MKPathTextNode`
field, out of this packet's fence (`MKPathText` sources/tests +
`Package.swift` only). `PathTextOffsetStore` (`PathTextCommands.swift`) is
the session-scoped stand-in shipped today. Full detail:
`Sources/MKPathText/README.md`'s "Known schema gap" section.

Related, smaller gap inherited from `ArrangeDeriver`'s own design (not
introduced by this packet): a FREE/detached mark on arranged path text
keeps its flat straight-baseline position rather than following the path,
because `ArrangeDeriver` never queries `PathPlacementProviding` for a
mark's own address (see README's "Marks and arrange-on-path" section).

### Seam `MKRender` should adopt (not edited by this packet)

`MKRender/Drawers/PathTextDrawer.swift`'s `MKPolylineArcLength` stand-in
(WS-07's own documented deviation 5) should be replaced with
`ArcLengthLUT` + `PathLayoutEngine.layout`/`.layoutClosed` — see
`Sources/MKPathText/README.md`'s "Seam WS-07 should adopt" section for
the exact adoption steps. No `MKRender` files were touched by this packet.

## WS-08 (`MKColor`/`MKExport`) — P10-EARLY contract (license seam + region-render usage)

Published per the packet's §10 codebase-memory duty and the "CONTRACTS.md
update (license seam; region-render usage)" deliverable. Covers ONLY this
session's P10-EARLY slice (MKColor pipeline; JPEG/PNG/transparent-PNG
writers; tiled strip rendering; export request/gate types; free-tier
budget/presets) — full detail and the two D-226 spike verdicts are in
`docs/impl-log/WS-08.md`.

### `FontLicenseProviding` — the WS-08-owned license seam

```swift
// MKExport
public protocol FontLicenseProviding: Sendable {
    func isLockableFont(_ fontRef: MKFontRef) -> Bool
    func embeddingRights(_ fontRef: MKFontRef) -> MKEmbeddingRights   // MKFonts.MKEmbeddingRights, D-227(1)
}
public struct AllOFLLicenseStub: FontLicenseProviding { public init() }
```

**Drift note** (same class as D-227's own reconciliations): this seam was
specified in the WS-08 packet before WS-09 shipped its real
`MKFontRegistry` (`licenseRecord(for:) -> MKLicenseRecord?`, an
actor-isolated, async catalog). `FontLicenseProviding` is intentionally
synchronous (needed inside `ExportGate`'s synchronous `MKScene` walk) and
reuses `MKFonts.MKEmbeddingRights` directly rather than a parallel bitset.
`AllOFLLicenseStub.isLockableFont` answers from `MKFontRef` alone
(`userImported` flag, or a `"premium."`-prefixed `fontID` — §17.1's naming
convention), with NO registry round trip — this is a heuristic, not a
license lookup, and is documented as such in `FontLicenseProviding.swift`.
**Whoever builds the deferred PDF/SVG writers (P10-completion) should
prefer a real conformer backed by `MKFontRegistry` at the composition
root**, not extend the stub.

### Region-render usage (WS-07's contract, as consumed by `MKExport`)

`MKExport` calls exactly two WS-07 entry points, both already published in
this file's WS-07 section above — no new `MKRender` API was needed:

- `MKSnapshotRenderer.render(_:region:scale:quality:)` — every raster
  export tile/whole-canvas render (`MKTiledRasterExporter`), always with
  `quality: .exportQuality` (D-118: export never degrades).
- `MKTileRenderer.tileRects(covering:scale:maxBytes:)` — the D-210/D-223
  strip-bounds math, reused verbatim (not reimplemented) for
  `MKTiledRasterExporter`'s own tiling.

`MKExportGate`/`MKExportCoordinator` accept `MKScene` directly (no
`MKSceneSnapshot` wrapper exists anywhere in `MKModel`/`MKPersistence` —
confirmed absent, same finding WS-07's own CONTRACTS.md entry above already
logged for its own consumers).

### `MKExportMemoryCooperating` — the D-223 stage-3 pause/cancellation seam

```swift
// MKExport
public protocol MKExportMemoryCooperating: Sendable {
    func isCancelled() -> Bool
    func shouldPauseBeforeNextStrip() -> Bool
}
public struct MKNoOpMemoryCooperation: MKExportMemoryCooperating   // default
```

Not yet wired to WS-07's real `MKMemoryPressureMonitor`/
`MKDegradationController` (`MKRender → MKExport` is already a real
dependency edge, so a real conformer reading `MKDegradationController
.stage` is a composition-root task, not a new cross-module protocol) — a
P10-completion/WS-13 follow-up, same as WS-07's own P4/P14 memory-ladder
wiring split (CONTRACTS.md's WS-07 section, "hooks/seams only").

### Package.swift correction (D-230)

`MKExport`'s SPM dependency list no longer includes `MKStore` (was a
direct violation of D-230's "`MKExport`/`MKSync` depend only on
`MKFoundation`'s protocol surface, never `MKStore` directly" — fixed this
session, `MKFoundation` added instead, needed anyway for
`MKEntitlementProviding`/`MKEntitlementState`/`MKPremiumCapability`).
**`MKSync` has the identical defect and was NOT fixed** (WS-11's module,
outside this packet's fence) — flagged in `docs/impl-log/WS-08.md`.

## WS-08 (`MKColor`/`MKExport`) — P10-COMPLETION contract additions (Run-3)

Adds the PDF/SVG writers on top of the P10-EARLY contract above. Full
detail (including the CMYK "Spike C"/"Spike D" findings) is in
`docs/impl-log/WS-08.md`.

### `MKSceneRenderer` reused DIRECTLY for vector PDF (new consumption
pattern, still zero new `MKRender` API)

`PDFVectorExporter` calls `MKSceneRenderer.render(_:region:into:scale:
quality:)` — the SAME entry point `MKSnapshotRenderer` wraps for raster —
but hands it a PDF `CGContext` (`CGContext(url:mediaBox:auxiliaryInfo:)`)
instead of a bitmap context. This works with ZERO `MKRender` changes:
`MKSceneRenderer.render` makes no assumption about the context's backing
store, and CoreGraphics' PDF `CGContext` records every `ctx.fill`/
`ctx.strokePath`/`CTFontDrawGlyphs` call as real PDF vector/text
operators. This is D-118/§16.3's "no per-format drawing code — only
per-format context construction" made concrete for a SECOND context type
(PDF, not just bitmap) — confirmed by decompressing a produced PDF's
content stream and finding real path-painting operators (`PDFVectorExporterTests
.contentStreamContainsVectorPathOperators`).

### `MKArrangedGeometry` reused DIRECTLY for SVG (public MKRender API, no
new dependency edge)

`SVGSerializer.renderArranged` calls `MKArrangedGeometry.Index`/
`.worldTransform(ofChild:index:compositionAffine:)`/`.worldTransform(ofMark:
index:compositionAffine:)` — the SAME public geometry helper
`MKRender/Drawers/ArrangedDrawer.swift` uses — so the SVG writer's
per-glyph transform math is provably the SAME formula the renderer uses,
not a re-derivation. `MKExport` already depended on `MKRender`; no new
edge was needed.

### The license-outline-substitution seam (new this session — the genuine
gap `MKRender` cannot close without an out-of-fence edit)

`MKRender`'s `LiveTextDrawer`/`PathTextDrawer` have NO license/embedding-
rights concept (by design — the single render path draws identically
regardless of caller). D-118/§16.5's per-license text-vs-outline switch is
therefore implemented ENTIRELY in `MKExport`, via two new types:

```swift
// MKExport
enum MKEmbeddingRestrictionWalker {
    struct Entry { /* id, worldTransform, style, opacity, fontPostScriptName, kind */ }
    static func restrictedTextNodes(in: MKScene, fontLicense:, right: MKEmbeddingRights, scale:) -> [Entry]
    static func hiding(_ ids: [MKNodeID], in: MKScene) -> MKScene   // same "value-copy, one field flipped" pattern as ExportCoordinator.preparedScene
}
enum MKTextOutlining {
    struct GlyphOutline { /* path, localTransform, codepoints, ctFont, glyphID, isColorGlyph */ }
    static func outlineLiveText(_:fonts:) -> [GlyphOutline]
    static func outlinePathText(_:fonts:) -> [GlyphOutline]
    static func isEmojiCluster(_:) -> Bool
    static func emojiGlyphPNGData(ctFont:glyph:) -> Data?
}
```

`PDFVectorExporter` uses BOTH: hide the restricted node in a scene copy
(so `MKSceneRenderer.render` skips it), render the rest normally, then
draw the outline substitute directly with `MKOutlineSubstitutePainter`.
`SVGSerializer` reuses `MKTextOutlining` directly (no walker/flat-CTM step
needed — SVG's native nested `<g transform>` composes automatically, see
`docs/impl-log/WS-08.md`'s writeup). `MKTextOutlining` re-shapes via
`MKShapingEngine`/`MKPathText.PathLayoutEngine` — the SAME engines
`LiveTextDrawer`/`PathTextDrawer` call — never a competing shaping
implementation. `Package.swift`: `MKExport` gained `MKTextEngine`/
`MKPathText` dependencies for this (both already transitive via `MKRender`
— no new architectural layer, just a direct edge for symbols this module
now spells by name).

### `MKExportFontDataProviding` — the SVG `@font-face` font-bytes seam

```swift
// MKExport
public protocol MKExportFontDataProviding: Sendable {
    func fontFileData(for fontRef: MKFontRef) -> Data?
}
public struct MKNoFontDataProviding: MKExportFontDataProviding   // v1 default: no bytes, `<text>` falls back to family-name-only
```

Same "stub now, real conformer at the composition root" pattern as
`FontLicenseProviding`/`MKExportHistoryRecording` — a real conformer reads
`MKFontRegistry.record(for:)?.faces.first?.fileURL`. SVG embeds the FULL
font file (not a subset) for OFL-licensed fonts — subsetting was assessed
and deliberately deferred (`Sources/MKExport/SUBSETTING_FOLLOWUP.md`).

### `PDFOutputIntent` — Spike D (this session's OWN empirical correction)

`kCGPDFXOutputIntentSubtype` must be the LITERAL string `"GTS_PDFX"` —
CoreGraphics silently discards the ENTIRE OutputIntent dictionary for any
other value (verified by decompressing a produced PDF and finding no
`/OutputIntents` key at all when a custom "not a claim" subtype string was
tried first). D-226(4)'s "no PDF/X claim under fallback" is honored at the
Swift/app-copy level (`MKICCProfileProvenance.mayClaimPDFX`) instead of in
the PDF dictionary itself — full writeup in `PDFOutputIntent.swift`'s
header and `docs/impl-log/WS-08.md`.

### CMYK vector PDF — "Spike C": a real, fence-driven architectural limit

`PDFPrintCMYKExporter` does NOT produce true per-element vector CMYK
content. Empirically verified this session: a `CGContext`/PDF context has
no fixed "native colorspace" (unlike a bitmap context) — color is entirely
per-operator, driven by whichever `CGColorSpace` the active `CGColor`
carries, and `ctx.setFillColor(_ color: CGColor)` (the exact call every
`MKRender` drawer makes) tags its operator with the CGColor's OWN
colorspace, ignoring both the context's prior `setFillColorSpace` state
and `ctx.setRenderingIntent`. Achieving real per-element CMYK requires the
DRAWERS themselves to construct CMYK `CGColor`s before painting — a
`MKRender` source change, outside this packet's fence. `PDFPrintCMYKExporter`
instead renders the WHOLE PAGE via the existing tiled-raster pipeline
(RGBA, correct opacity compositing per Spike A), converts it ONCE via
`MKColor.CMYKConverter.convertWholeImage` (explicit `.relativeColorimetric`,
D-226(1)), and embeds that single CMYK image with a real, Spike-B-verified
OutputIntent. Every CMYK export carries `FallbackReason
.cmykContentRasterized` (never silent). Full finding + reproduction in
`docs/impl-log/WS-08.md` and `PDFPrintCMYKExporter.swift`'s header.

## Design-system tokens (not a stub — WS-01 owns this permanently)

`MKDesignSystem`'s `MKTheme` protocol + `InkPaperTheme` default
implementation are **not** a stub layer for another workstream to replace;
WS-01 owns the design system for the life of the project. Other
workstreams may add new components to `MKDesignSystem/Components/` as
their features need them, but the token protocol (`MKTheme`) and its
default conformer are shared, permanent infrastructure — see
`FOUNDATION.md` §9 (D-126) and FD-02 (founder-editable baseline aesthetic,
not a code-ownership handoff).

## WS-10 (`MKStore`) — entitlement/StoreKit contract (P11)

`MKStore` depends on `MKFoundation` alone (D-101/D-230 — never a direct
target dependency from `MKExport`/`MKFonts`/`MKSync`, only the
`MKEntitlementProviding` protocol surface those modules already coded
against since WS-01). This session's real implementation:

- **`MKEntitlementResolver`** conforms to `MKEntitlementProviding`
  unmodified (`var state: MKEntitlementState { get }`, synchronous,
  `nonisolated`, lock-guarded snapshot) — every existing downstream call
  site (`MKExportGate.evaluate`, `MKFontLockController.reconcile(with:)`)
  needed zero changes to receive the real resolver instead of
  `StubEntitlementResolver`/`AlwaysPremiumEntitlementStub`.
- **Broadcast**: `MKEntitlementResolver.states() -> AsyncStream<MKEntitlementState>`
  is a concrete method on the resolver, NOT a protocol requirement — kept
  off `MKEntitlementProviding` deliberately so adding it never breaks any
  existing conformer (`StubEntitlementResolver`, test fakes in
  `MKExportTests`/etc.) that only implements the synchronous half. Callers
  that want push updates (this session wired
  `MKFontLockController.observe(_:)` at `AppContainer`'s composition
  root — see `Makhtoot/AppShell/AppContainer.swift`) get the stream
  out-of-band from the concrete resolver type, not through the protocol.
- **`MKEntitlementState` itself is unchanged** (still no associated
  values on `.subscribed`/`.inGracePeriod`) — grace-period expiration
  dates and renewal info live in a NEW companion type,
  `MKStore.MKEntitlementDetail`, published alongside (not instead of) the
  plain state. See that type's own header comment for the full "why not
  widen the enum" reasoning — this was a deliberate, logged deviation
  from the WS-10 packet's own T1 pseudocode, not an oversight.
- **`MKSandboxScenarioStub`/`TestEntitlementStub`** (`MKStore/Testing/`,
  `#if DEBUG`-gated): six named scenario presets (`free, trialDay3,
  expired, grace, billingRetry, lifetime`) plus a mutable stub, both
  conforming to `MKEntitlementProviding` — available to any module's test
  target that wants richer entitlement scenarios than
  `StubEntitlementResolver`'s fixed `.lifetime` (not yet adopted by
  `MKExportTests`/`MKFontsTests`'s own fakes this session — those stay as
  they are, out of this packet's fence; this is a forward-looking
  availability note, not a migration).
- **Composition root**: `Makhtoot/AppShell/AppContainer.swift` now
  constructs `MKProductCatalog` → `MKTrialManager` → `MKEntitlementResolver`
  → `MKPurchaseController` together (in that order, sharing instances) and
  kicks off `resolver.startTransactionListener()` + the first
  `resolver.resolve()` in a detached `Task` at `init` (never blocking
  `init`, same synchronous-`<1ms`-`init` rule the font registrar already
  established). Full swap-log entry in that file's own header comment.

Full task-by-task log, test evidence, and deviations: `docs/impl-log/WS-10.md`.
