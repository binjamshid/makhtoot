# MKRender

Owner: WS-07 (`AGENT_TASK_PACKETS/WS-07-rendering-performance.md`). This
implementation covers the **P4 renderer bring-up slice** of that packet
(PLAN.md P4 — "MKRender (renderer bring-up portion)"); the D-116/D-223
memory-pressure ladder ships as hooks/seams here, not the full P14
hardening pass (device-verified budgets, cross-module governor wiring,
the full perf harness). See `docs/impl-log/WS-07.md` for the run log,
deviations, and the P14 handoff list.

## One truth, three destinations

```
MKScene (immutable value type, D-102)
        │
        ▼
MKSceneRenderer.render(_:region:into:scale:quality:)   ← the ONLY drawing entry point (INV-2/INV-6)
        │
        ├──► MKLayerTreeController   (canvas preview — layer.contents = cached bitmap, D-114)
        ├──► MKSnapshotRenderer      (thumbnails — WS-02 stores the bytes)
        └──► MKSnapshotRenderer      (export strips — WS-08 tiles via MKTileRenderer's bounds math)
```

Every destination goes through `MKSnapshotRenderer.makeFlippedBitmapContext`
+ `MKSceneRenderer.render` — there is exactly one context-creation helper
and one drawing entry point in the module, which is what makes D-104/D-118
pixel-identity a structural guarantee rather than something tested for and
hoped to stay true.

## Coordinate conventions

- **Document/canvas space** (`MKNode.core.transform`, `MKCanvasSpec.size`,
  arranged `layout.position`/`relativeOffset` as consumed here): origin
  top-left, **y increases downward** — matching D-114's UIKit canvas host
  and every mainstream design tool. `MKTransform2D.rotation`'s doc comment
  says "counter-clockwise positive (CoreGraphics convention)" — applied
  literally (the standard CG rotation matrix) regardless of the ambient
  y-direction; in a y-down space this reads as visually CLOCKWISE on
  screen. This is not "fixed" anywhere, because canvas preview and export
  share the identical transform math end to end — whichever way it reads
  visually, it reads the SAME way everywhere, which is the actual
  correctness requirement (D-118).
- **Core Text / font-space content** (glyph positions, glyph outline
  paths from `CTFontCreatePathForGlyph`/`MKPathData`): **y-up**, per
  `MKTextEngine/CoordinateSpace.swift`'s explicit convention ("never flips
  or rewrites a captured position"). Every drawer that touches this
  content applies exactly ONE local axis flip at the boundary where it
  enters document space:
  - `LiveTextDrawer`: the standard CoreText-into-a-flipped-context idiom —
    translate to the line's document-space origin, `scaleBy(x: 1, y: -1)`,
    then call `CTFontDrawGlyphs` with RAW (un-flipped) captured positions.
  - `ArrangedDrawer`/`MKArrangedGeometry`: the flip is folded into what
    `ArrangedDrawer` passes as `MKArrangedGeometry`'s `compositionAffine`
    parameter (`CGAffineTransform(scaleX: 1, y: -1)`, composed with the
    node's own `core.transform` — see `Drawers/ArrangedDrawer.swift`'s file
    comment for the full reasoning, including why this is a **documented
    judgment call** pending WS-04/`MKArrange`, which will pin down what
    coordinate convention `layout.position`/`relativeOffset` are actually
    derived in once it exists).
  - `PathTextDrawer`: same per-glyph local flip as `LiveTextDrawer`.
- **Node-local "unit space"** (`MKShapeNode`/`MKImageNode`): `MKShapeGeometry
  .rect`/`.ellipse` and `MKImageNode` have no separate width/height field in
  the schema — this module treats their local content as a canonical
  `[-0.5, 0.5] × [-0.5, 0.5]` unit square, with the node's `transform.scale`
  carrying the actual on-canvas size (`ShapeDrawer`/`ImageDrawer` file
  comments). `.polygon`/`.path` geometry stores its own absolute local
  points instead and does not use this convention.

## Cache/bucket policy

- **Zoom buckets** (`MKScaleBucket`, §11.3): powers of √2 from 0.025× to
  64×, quantized DOWN to the nearest bucket at or below the raw zoom —
  content never renders blurrier than the actual zoom. `contentsScale =
  screenScale × scaleBucket`.
- **Content hash** (`MKContentHash`, task 7): stable digest of a node's
  paint-affecting fields, EXCLUDING `transform`/`opacity` (those are layer
  properties, §11.2) — keys both `BitmapCache` and
  `MKLayerTreeController`'s re-rasterization decision. A transform-only
  edit never invalidates the hash; a fill/stroke/text/geometry edit always
  does.
- **`BitmapCache`**: LRU by bytes, default budget 256 MB (task 8's
  "15% of `os_proc_available_memory`" half is `VERIFY-AT-IMPLEMENTATION` —
  see `MemoryPressureMonitor.swift`'s file comment on why that Darwin
  symbol can't be exercised from this sandboxed toolchain); eviction order
  is offscreen-first, then LRU. `MKLayerTreeController` does not yet wire
  its OWN per-node bitmaps through `BitmapCache` (it holds one bitmap per
  live `CALayer` directly via `layer.contents`, which is itself a natural
  cache — a P14 pass may route through `BitmapCache` explicitly for
  cross-layer budget accounting).

## Ladder state machine (D-116/D-223 — hooks/seams, P4 scope)

```
normal(0) ──70%──► stage1(1) ──85%──► stage2(2) ──.critical event──► critical(3)
   ▲                  │                  │                              │
   └──────────────────┴─── 10 s below (threshold − 5 pts) ──────────────┘
```

- Stage 1/2 entry: `MKAutosaveTriggering.flushForMemoryPressure(stage:)`
  (full debounced-flush-equivalent) BEFORE cache eviction/fidelity change
  (INV-17/D-223 save-before-degrade ordering, `MKDegradationController
  .transition(to:)`).
- Critical entry: `MKAutosaveTriggering.flushJournalOnly()` — D-223's
  journal-only, no-re-encode path — never `flushForMemoryPressure`.
- `.warning` DispatchSource events force AT LEAST stage 1 immediately,
  regardless of the concurrent sample's own reading (§12.3's conservative-
  reaction rule); `.critical` events map directly to `.critical` and are
  never downgraded.
- `MKRenderFidelity`: `.reduced` at stage ≥ 2 — half-res layer bitmaps
  (contentsScale halved, a P14 wiring point once `MKLayerTreeController`
  reads `MKDegradationController.fidelity`), simplified shadows (flat 30%-
  alpha offset fill, no blur — `MKStylePainting.paintReducedShadowIfNeeded`),
  low image interpolation. **Export quality never degrades** — `MKRenderQuality
  .exportQuality.fidelity` is always `.full`.
- What P14 still owns: real `os_proc_available_memory()` sampling (Darwin,
  iOS-only symbol, unverifiable from this macOS-host sandboxed toolchain —
  `MKMemorySampling` documents the gap), wiring `MKDegradationController`
  into `MKLayerTreeController`'s actual bitmap render path so `.reduced`
  visibly changes on-screen output, and the cross-module `MKMemoryGovernor`
  ARCHITECTURE §12.3 sketches (outside this packet's fence — it's declared
  `// MKFoundation`).

## Metal extension seam (D-114)

Not implemented — D-114 is explicit that Metal is "a documented extension
seam only (adopt only if profiling gates fail)." The seam point, if P14
profiling ever requires it: `MKSceneRenderer`'s public surface
(`render(_:region:into:scale:quality:) -> MKRenderReport`) is CoreGraphics-
context-shaped by necessity (export/PDF paths need `CGContext`), but
`MKLayerTreeController`'s `layer.contents = CGImage` assignment pattern
(never a `CALayer` subclass override of `-drawLayer:inContext:`) means a
future Metal path could replace `MKLayerTreeController`'s internal
rasterization call with an `MTLTexture`-backed render + `CGImage` bridge
(or a `CAMetalLayer`-backed sibling conforming to the same
`RenderTreeProviding` protocol) without changing WS-06's call sites at all
— `RenderTreeProviding` was deliberately kept CALayer-shaped but rendering-
technology-agnostic in its method signatures (no `CGContext` appears in the
protocol itself) for exactly this reason.

## Known P4-scope simplifications (not gaps — each is a decision, documented at its call site)

- **`MKSceneSnapshot`** (ARCHITECTURE §3.5's illustrative wrapper —
  `scene` + `fontHandles` + `assetURLs` + `renderIntent` + `entitlement`)
  was never built by WS-02; `MKSceneRenderer` accepts `MKScene` directly
  (already immutable/`Sendable`, satisfying D-102/INV-2 on its own) and
  resolves fonts/assets via the `MKFontProviding`/`MKAssetProviding`
  protocol seams instead. See `AssetProviding.swift`.
- **Path text** (`PathTextDrawer`, `HitTester.pathProximity`): a
  self-contained polyline arc-length sampler stands in for WS-05's real
  `ArcLengthLUT` (P7, not yet built) — see `Drawers/PathTextDrawer.swift`.
- **Decomposed-ligature geometry** and **non-following/detached mark**
  handling are documented extrapolations of D-220, not literal formula
  text — see `Geometry/ArrangedGeometry.swift`'s file comment.
- **Perf HUD**: `MKRenderPerfSnapshot`/`MKRenderPerfHUDDataSource`
  (`RenderSignposts.swift`) expose the DATA; the SwiftUI view
  (`Makhtoot/App/Debug/PerfHUDView.swift`, packet §8) is app-target code
  outside this packet's fence (`MKRender sources/tests` only) — WS-13 owns
  building it against this data source.
- **`os_signpost` categories**: `manipulationFrame`/`typingEcho`/
  `documentOpen`/`autosave`/`export` reuse `MKFoundation.MKSignpost`
  (WS-01); `renderTile`/`layerSync`/`pathRelayout`/`arrangeDerive` are a
  new `MKRenderSignpost` enum in THIS module (`MKFoundation` is outside
  this packet's fence) — see `RenderSignposts.swift`.

## Testing

`MKRenderTests` — golden/tolerance-based drawer tests, `SceneRenderer`
composition + determinism tests, `SnapshotRenderer` thumbnail tests,
`ContentHash` invalidation tests, `BitmapCache` budget/eviction tests,
`HitTester` geometry tests, `MKDegradationController`/`MKMemoryPressureMonitor`
ladder-walk tests, the `T-ARR-1`/`T-ARR-2` D-220 numeric formula tests, and
the D-104/D-118 canvas-vs-export pixel-identity test
(`T-RENDER-FID-CANVAS-EXPORT`).
