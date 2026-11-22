# WS-07 — Rendering & Performance

Run-1 agent task packet for Makhtoot (مخطوط). Governed by FOUNDATION.md. Owns
`MKRender`: the Core Graphics scene renderer, CALayer preview tree, bitmap caches, the
D-116 degradation ladder, snapshot rendering for export/thumbnails, hit-test geometry,
and the os_signpost instrumentation that makes the D-115 budgets verifiable gates.

## 1. Mission

Implement the single rendering truth for Makhtoot: a pure Core Graphics scene renderer
that draws any immutable `MKScene` snapshot — live text (via WS-03 shaping capture),
path text (via WS-05 placements), arranged compositions (glyph/mark/ligature node
outlines with styles), shapes, images, backgrounds — identically whether the destination
is the on-canvas CALayer tree, a thumbnail, or WS-08's export contexts. D-114 fixes the
strategy: one CALayer per top-level node whose contents are CG-drawn bitmaps at current
zoom, with transform changes applied as cheap layer-property updates so 60/120 Hz
manipulation never redraws content; Metal is only a documented extension seam.

The performance half is equally binding: implement the D-116 memory-pressure ladder
(cache drops → preview degradation with the Arabic warning banner trigger → critical
synchronous autosave via WS-02), bitmap cache management keyed by zoom/scale, tile-based
rendering support for huge canvases, and the `os_signpost` instrumentation for every
D-115 budget (manipulation frame, typing echo, document open, autosave, export) so
TEST_MATRIX perf gates run against real traces, not guesses. You also own hit-test
geometry (point→node, point→glyph/mark inside arranged nodes, path proximity) consumed
by WS-06's policy layer.

## 2. Scope

**IN**
- `SceneRenderer`: draw(scene:in ctx:region:scale:options) — full CG implementation for
  all seven node kinds; style pipeline (fill, stroke, shadow, opacity, blend normal);
  render options (preview vs export quality, degradation stage).
- `RenderTreeProviding` + `LayerTreeBuilder`: CALayer-per-top-level-node tree, diffing
  scene snapshots → minimal layer updates, transient-transform fast path for WS-06
  gestures, zoom-scale re-rasterization policy.
- Bitmap caches: per-node content bitmaps keyed (nodeContentHash, scaleBucket), LRU with
  byte budget, offscreen eviction; shadow/expensive-effect caching.
- Degradation ladder (D-116) controller + memory monitoring
  (`DispatchSource.makeMemoryPressureSource` + periodic `os_proc_available_memory`).
- `SnapshotRenderer`: synchronous/async rendering of a scene snapshot to CGImage/
  context at arbitrary scale — used for thumbnails (WS-02 stores bytes), WS-04 fidelity
  tests, WS-08 exports (WS-08 owns tiling/orchestration; you expose region rendering).
- Hit-test geometry: `HitTester` — z-ordered node hit, arranged-child hit (glyph path
  containment + mark bounds + 44 pt slop support), path-text proximity (via WS-05 LUT
  nearestLength), transform-aware.
- `RenderSignposts`: the D-115 instrumentation + lightweight in-app perf HUD (DEBUG).
- Live-text rendering fidelity vs the D-104 overlay (pixel-identity verification
  fixtures with WS-06).

**OUT**
- Gesture/selection policy, chrome drawing (WS-06 draws chrome into its own layer using
  your coordinate helpers).
- Export file encoding, color conversion, tiling orchestration (WS-08/MKColor).
- Shaping (WS-03), arrangement (WS-04), path layout (WS-05) — you consume their outputs.
- Metal renderer (extension seam doc only, D-114).

## 3. Dependencies

**Upstream:** WS-01 (`MKFoundation` signpost names, logging), WS-02 (scene model,
snapshots stream, fixtures, `saveNow(reason:)` for ladder stage 3), WS-03 (capture for
live text), WS-05 (placements for path text). WS-04 arranged nodes are pure model data
(WS-02 types) — renderable without MKArrange import. **Stubs you may rely on:**
`SystemFontStubProvider`; `StubEntitlementResolver` (rendering itself ungated; locked-
font badge rendering is WS-09/WS-13 chrome, not yours). **You must ship early**: the
`RenderTreeProviding` protocol + a flat-color stub renderer in your first milestone so
WS-06 can start (CONTRACTS.md).

**Downstream consumers:** WS-06 (layer tree + hit geometry + fast path), WS-08
(SnapshotRenderer region API), WS-02 (thumbnail bytes), WS-04 (fidelity test renderer),
WS-13 (perf HUD toggle, degradation banner trigger).

## 4. Locked decisions binding this packet (quoted)

- **D-114**: "Core Graphics scene renderer; canvas = UIScrollView-zoomable UIView with a
  CALayer per top-level node (transform changes are layer-property updates → cheap
  60/120 Hz manipulation); node content drawn by CG into layer contents at current zoom
  scale with bitmap caching. Metal is a documented extension seam only (adopt only if
  profiling gates fail)."
- **D-115**: "manipulation frame time ≤8.3 ms on ProMotion hardware, ≤16.6 ms floor on
  A12-class; typing echo <50 ms; open typical project (≤100 nodes) <1 s, heavy (5 000
  nodes) <3 s; incremental autosave <100 ms off main thread; 4K PNG export <10 s on
  A15; peak editor memory <60 % of `os_proc_available_memory` before degradation
  begins."
- **D-116**: "monitor `DispatchSource` memory-pressure events + periodic
  `os_proc_available_memory` sampling. Stages: (1) 70 % — drop offscreen bitmap caches,
  autosave now; (2) 85 % — degrade preview fidelity (half-res layer bitmaps, simplified
  shadows), warn user banner 'الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا'; (3) critical
  event — synchronous autosave + journal flush; recovery on relaunch restores exactly.
  Huge exports render tiled (bounded strips) so output size is limited only by disk,
  not RAM."
- **D-102**: "renderer works on immutable scene snapshots (value-type scene graph) so
  export/preview never race the editor."
- **D-118** (fidelity contract): "single render path from the scene snapshot (never
  screen capture)."
- **D-104** (fidelity contract): "committed rendering of Live Text objects is always the
  MKTextEngine→MKRender path so canvas and export are pixel-identical."

## 5. Task breakdown (ordered)

1. **`RenderTreeProviding` protocol + stub** (unblocks WS-06): layer tree attach point,
   `sync(to scene:)`, `applyTransientTransform(nodeID:transform:)`,
   `commitTransients()`, visible-rect/zoom notifications. Stub renders flat colored
   rects per node. *Accept:* WS-06 canvas runs against the stub; CONTRACTS.md updated.
2. **Node content drawers**: `ShapeDrawer` (path fill/stroke), `ImageDrawer` (asset
   bitmap via WS-02 asset store, aspect modes), `BackgroundDrawer` (solid color v1),
   `LiveTextDrawer` (shape via WS-03 → draw glyph runs with `CTFontDrawGlyphs` per run,
   correct y-flip, styles applied per node — fill color, stroke as path stroke of glyph
   outlines when set, shadow via CG shadow state), `PathTextDrawer` (WS-05 placements →
   per-glyph translate/rotate + draw outline path), `ArrangedDrawer` (glyph/mark/
   ligature nodes: stored outline paths with per-node transforms/styles, honoring
   z within composition and visual coherence). *Accept:* golden-image tests per drawer
   on fixtures (tolerance-based diff ≤0.5 %); live text drawn via engine matches WS-03
   harness geometry.
3. **`SceneRenderer` composition**: traverse scene in z-order, apply node transforms
   (decomposed → CGAffineTransform), opacity via transparency layers only when
   needed (opacity <1 with overlapping children), clip to region, scale-aware. Options:
   `.editorPreview(stage:)`, `.exportQuality`. *Accept:* full-scene golden tests on
   `fixture-arabic-basic` + arranged + path fixtures at 1×/3×; export-quality render of
   the same scene is pixel-identical across two invocations (determinism).
4. **`SnapshotRenderer`**: `render(scene:region:scale:options) -> CGImage` (sync, any
   queue — snapshots are Sendable values per D-102) + async batch API; thumbnail
   pipeline (long-edge 512 px, JPEG-encodable output handed to WS-02). *Accept:*
   thumbnail for fixtures generated <50 ms (100-node, simulator); WS-04 fidelity tests
   switch to this renderer.
5. **`LayerTreeBuilder`**: one CALayer per top-level node; layer.contents = cached
   bitmap at `scaleBucket` (zoom quantized to powers-of-√2 buckets to bound
   re-rasterization); scene diff (by node id + content hash) → add/remove/update only
   changed layers; z via sublayer order; hidden/locked mapped (`isHidden`; locked is
   policy-only, still rendered). *Accept:* editing one node re-rasterizes exactly one
   layer (instrumented count); scroll/zoom produces no content redraw until zoom
   settles into a new bucket (hysteresis 1 bucket).
6. **Transient-transform fast path**: `applyTransientTransform` sets layer transform
   properties inside a `CATransaction` with actions disabled; `commitTransients`
   reconciles with the committed scene (WS-06 already issued commands). *Accept:*
   drag test with signposts shows zero `draw(in:)`/bitmap work during gesture
   (`T-PERF-FRAME-*` prerequisite).
7. **Content hashing**: stable hash of node content-affecting fields (excludes
   transform/opacity — those are layer properties) to key caches and diffs; text nodes
   include style + string + font ref; arranged nodes include child geometry digest.
   *Accept:* transform-only edit does not invalidate cache; fill-color edit does.
8. **`BitmapCache`**: LRU by bytes (budget = min(256 MB, 15 % of
   `os_proc_available_memory` at init, recomputed on ladder stage change)); entries
   (nodeContentHash, scaleBucket); eviction order — offscreen first, then LRU;
   `purgeOffscreen()`, `purgeAll()` for the ladder. *Accept:* unit tests for budget/
   eviction; instrumented memory stays under budget while zooming across the 5 000-node
   fixture.
9. **Huge-node tiling support**: nodes whose bitmap at current bucket would exceed
   64 MB render via `CATiledLayer`-free manual tiles (layer contents = mosaic sublayers)
   OR direct-draw layer (`drawsAsynchronously` CG path) — choose direct-draw for v1
   simplicity, document tradeoff; expose region rendering used by WS-08 strips.
   *Accept:* a 12 000×12 000 pt background scene pans without >64 MB single
   allocations; region render returns correct sub-rect (pixel-compare vs full render
   crop).
10. **Memory monitor + ladder controller** (D-116): `MemoryPressureMonitor` actor —
    DispatchSource events + 2 s `os_proc_available_memory` sampling; thresholds: used
    fraction ≥70 % → stage 1 (purge offscreen caches + `saveNow(reason: .memoryPressure)`);
    ≥85 % → stage 2 (half-res bitmaps: scaleBucket −1, simplified shadows — flat alpha
    fill, no blur; post banner event with the exact D-116 Arabic string
    "الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا"); critical DispatchSource event → stage 3
    (synchronous `saveNow` + journal flush, then purgeAll). De-escalation with
    hysteresis (drop a stage only after 10 s below threshold −5 pts). *Accept:* unit
    tests with injected readings walk 0→1→2→3 and back; stage 2 visually verified
    (degraded but legible Arabic text); stage-3 path proven by WS-02 recovery test
    invoked under simulated critical event.
11. **Degradation rendering modes**: `.editorPreview(stage:)` plumbed through drawers —
    stage ≥2 uses half-res + cheap shadows; export path NEVER degrades (D-118 quality
    unaffected; if memory can't support export, WS-08 tiling handles it). *Accept:*
    golden tests confirm export output identical regardless of active ladder stage.
12. **`HitTester`**: `node(at point:)` (topmost-first, transform-aware, alpha-aware
    optional for images off in v1 — bounds hit), `arrangedChild(at:in:)` (glyph outline
    `CGPath.contains` with 4 pt outset fallback to bounds; marks get min 12 pt box),
    `pathControl(at:on:)` (delegates to WS-05 LUT `nearestLength` within 8 pt),
    returns hit metadata (node id, child id, distance). *Accept:* unit tests on rotated/
    scaled nodes; glyph-level hits on the "لا" arranged fixture; performance <0.5 ms on
    5 000-node fixture (spatial index: simple z-sorted bounds prefilter).
13. **`RenderSignposts` + perf HUD**: implement all reserved WS-01 signpost names —
    `manipulationFrame` (CADisplayLink-driven interval in canvas), `typingEcho`
    (overlay keystroke → engine echo, co-instrumented with WS-06), `documentOpen`,
    `autosave` (WS-02 emits, you own the category taxonomy), `export`, plus
    `renderTile`, `layerSync`, `pathRelayout`, `arrangeDerive` categories; DEBUG HUD
    overlay showing rolling frame time, memory %, ladder stage, cache bytes. *Accept:*
    `xctrace`-recordable schema documented in README; HUD toggles from debug menu.
14. **Perf harness + budget verification**: scripted scenarios over WS-02 fixtures —
    open 100/5 000 nodes, drag 1/10/60 nodes, zoom sweep, typing burst; runs as an
    XCTest performance suite (simulator numbers) + documented on-device procedure for
    A12-class floor and ProMotion targets. *Accept:* all D-115 editor budgets pass on
    simulator with recorded traces; device checklist filed to TEST_MATRIX
    (`T-PERF-*` rows) for the P14 hardening phase.
15. **Pixel-identity fixtures (D-104/D-118)**: canvas-preview render vs SnapshotRenderer
    export-quality render of identical snapshots — diff ≤0.1 % on all §6 fixtures; plus
    WS-06 overlay-vs-committed bounds check support. *Accept:* automated diff suite
    green (`T-RENDER-FID-*`).
16. **Docs**: `MKRender/README.md` — render-path diagram (one truth, three
    destinations), cache/bucket policy, ladder state machine, Metal extension-seam note
    (D-114), coordinate conventions. *Accept:* reviewed against ARCHITECTURE.md §11/§12
    outlines.

## 6. Arabic-correctness notes

- Golden fixtures must include: "بسم الله الرحمن الرحيم" live text (marks render above/
  below correctly at 1× and 8× zoom), arranged "لا" + decomposed variant, "شَدَّةٌ"
  (stacked marks — shadow rendering must not double-darken overlapping mark/base
  shadows: shadow applied per node, documented), path-text circle fixture, mixed
  "عام ٢٠٢٦ Design 2026".
- Glyph stroke (outline style) strokes the OUTLINE path — verify counters (عين/ه loops)
  render with even-odd/nonzero rule matching CTFontCreatePathForGlyph output; fixture:
  stroked "هلا" shows open counters.
- Half-res degradation must keep tashkeel legible at typical zoom — manual check row in
  the Arabic checklist.
- Never rasterize text through UILabel/screen capture anywhere (D-118); grep gate for
  `UIGraphicsGetImageFromCurrentImageContext`/`drawHierarchy` in MKRender = zero.
- RTL is irrelevant to raw CG geometry, but run order from WS-03 must be preserved when
  drawing per-run so overlapping script runs composite deterministically.

## 7. Packet acceptance criteria (gates)

- **Build gate**: `MKRenderTests` green (`T-RENDER-*`).
- **Fidelity gates**: golden suite ≤0.5 % per-drawer, ≤0.1 % preview-vs-export
  (`T-RENDER-FID-*`); WS-04 fidelity tests re-run green on SnapshotRenderer.
- **D-115 gates**: task 14 scenario table complete — simulator pass + device procedure
  documented (`T-PERF-FRAME-*`, `T-PERF-OPEN-*`, `T-PERF-TYPE-*`; export budget row
  handed to WS-08).
- **D-116 gate**: ladder unit tests + simulated-pressure integration test incl. WS-02
  recovery (`T-PERF-MEM-*`); banner string exact match to D-116.
- **Manual Arabic checklist**: §6 rows verified with screenshots at stages 0 and 2
  (`T-ARABIC-M-RENDER-*`).

## 8. Deliverables

- `MakhtootKit/Sources/MKRender/RenderTreeProviding.swift`, `StubRenderTree.swift`,
  `SceneRenderer.swift`, `RenderOptions.swift`, `Drawers/ShapeDrawer.swift`,
  `Drawers/ImageDrawer.swift`, `Drawers/BackgroundDrawer.swift`,
  `Drawers/LiveTextDrawer.swift`, `Drawers/PathTextDrawer.swift`,
  `Drawers/ArrangedDrawer.swift`, `LayerTreeBuilder.swift`, `ContentHash.swift`,
  `BitmapCache.swift`, `TileRenderer.swift`, `SnapshotRenderer.swift`,
  `MemoryPressureMonitor.swift`, `DegradationController.swift`, `HitTester.swift`,
  `RenderSignposts.swift`, `README.md`
- `MakhtootKit/Tests/MKRenderTests/*` (golden suite + diff utilities, cache/ladder/
  hit tests, perf harness)
- DEBUG: `Makhtoot/App/Debug/PerfHUDView.swift`
- CONTRACTS.md update (fast path + region-render API for WS-08).

## 9. References

- ARCHITECTURE.md: §11 Rendering & Preview, §12 Performance & Memory, §3 Scene Graph &
  Data Model, §10 Canvas & Interaction, §16 Export Pipelines (render-path contract),
  §24 Extension Seams (Metal), §25 Risks & Mitigations.
- PRD.md: §4 Canvas Editor, §22 Non-Functional Requirements, §21 Edge-Case Compendium
  (memory recovery cases), §19 Offline Behavior.
- BRIEF.md: "Performance" (all bullets), "Canvas & projects".
- Market study: §12 (Core Graphics canvas, "Metal only if profiling later shows a real
  performance need")[^61]; §7 export table rows on device-adaptive rasterization[^40].

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS07-A1: scaleBucket quantization + re-raster hysteresis",
  "WS07-A2: direct-draw choice for huge nodes over CATiledLayer (v1)",
  "WS07-A3: ladder thresholds/hysteresis implementation of D-116",
  "WS07-A4: content-hash cache keying (transform excluded)".
- Implementation log after tasks 6, 10, 14 with signpost traces attached/summarized.
- Verification evidence: golden-diff summary, D-115 scenario table (simulator +
  device-procedure doc), ladder walk test output, stage-2 legibility screenshots.
- Store the perf-baseline table as durable memory for the P14 hardening phase and note
  any budget at risk (candidate Metal-seam triggers per D-114).

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Performance: no artificial caps on canvas size/glyph count/object count | Tasks 8–10 (rest: WS-06 Task 19) |
| Continuous memory-pressure monitoring, early warnings, robust autosave, no-loss recovery | Task 10 (rest: WS-02 recovery) |
| Controlled soft degradation (preview fidelity, virtualized layer lists) as safeguards, not caps | Task 11 (rest: WS-06 Task 10 for layer-list virtualization) |
| Quantitative frame-time/latency/loading/export/memory budgets for all iOS 18 devices | Tasks 13–14 (rest: WS-06 Task 19, WS-08 Task 19) |
| Canvas & projects: visual layers (CALayer-per-node rendering) | Task 5 |
| Normal typing: committed rendering pixel-identical to overlay (D-104) | Tasks 2 (`LiveTextDrawer`), 15 |
| Arranged compositions: independently selectable/transformable glyph/mark/ligature rendering (fill/outline/shadow) | Task 2 (`ArrangedDrawer`) |
| Tashkeel + Qur'anic marks render correctly (attachment, stacking, no shadow double-darkening) | §6 Arabic-correctness notes, Task 2 |
| Ligatures: combined + decomposed rendering fidelity | Task 2 (`ArrangedDrawer`) |
| Curved/circular/freeform text on Bézier paths | Task 2 (`PathTextDrawer`) |
| Export: Premium Hi-Res unlimited scaling subject to memory; warn near limits | Task 9 (rest: WS-08) |
| Engineering: Core Graphics/Metal permitted where needed | Task 16 (Metal extension-seam doc, D-114) |
