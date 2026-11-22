# Batch 5 — Canvas, assets, export (11 agents)

Theme: `mk-canvas` (the largest module in the plan — 6,580 LOC across 29 files), `mk-assets`
(2,675 LOC / 24 files), `mk-export` (3,342 LOC / 22 files). Depends on **G4** (`mk-arrange`,
`mk-pathtext`, `mk-render` green — the `mk-canvas` agents consume `MkRenderTreeProviding`/
`MkHitTester` from `:mk-render`, the arrange/path-text interaction seams from `:mk-arrange`/
`:mk-pathtext`; `mk-export` consumes the scene renderer, tiled snapshot rendering and content
hashing from `:mk-render`). Dispatch the eleven assignments together so they run concurrently. Gate: **G5**.

**Four agents from the original 7-agent register were not one unit of work and are split by
letter suffix here, per spine `§5.2`** (a citation of "5.2"/"5.4"/"5.5"/"5.7" without a suffix
in older material means "both halves together"): `5.2` → **5.2a** (gesture arbitration state
machine) / **5.2b** (snapping, guides, grid, geometry helpers); `5.4` → **5.4a** (IME
text-editing overlay) / **5.4b** (arrange + path-text interaction models); `5.5` → **5.5a**
(generators, model, library, manifest, browser) / **5.5b** (instantiation, provenance,
thumbnails, contact sheet); `5.7` → **5.7a** (PDF core writer) / **5.7b** (font subsetting,
Type0/CIDFontType2 embedding, CMYK, OutputIntent/ICC). Total: 5.1, 5.2a, 5.2b, 5.3, 5.4a, 5.4b,
5.5a, 5.5b, 5.6, 5.7a, 5.7b = **11 agents**.

**Carried invariant from Batch 4 (still binding here):** committed rendering is always the
shaping-capture→render path (D-104/D-303); nothing in this batch may introduce a second
drawing path (e.g. a `View.draw()`-to-bitmap capture standing in for the renderer) for canvas
preview, thumbnails, or export. `:mk-canvas` hosts and drives `:mk-render`'s output — it never
re-implements drawing itself.

---

### Batch 5 · Agent 5.1 — `mk-canvas` view, session, modes, zoom/pan

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port the canvas host itself: the `View` that hosts the render tree, the
`@MainActor` session view-model spine every other `:mk-canvas` file (this batch's other three
canvas agents, and Batch 7's editor shell) binds to, the interaction-mode enum, the content
API Batch 7's toolbars call to add objects, the checkerboard/grid presentation primitives, and
the geometry-source seam over `:mk-render`'s hit-testing/OBB queries. **D-306 is the load-
bearing decision for this agent**: a custom `MkCanvasView : View`, owned transform matrix, pan/
zoom driven by `ScaleGestureDetector` + `GestureDetector` + raw pointer tracking — explicitly
**not** a `ScrollView`, because `UIScrollView`'s zoom/pan semantics (bounce, zoom-bucket
crossing, content inset, deceleration) have no Android equivalent and must be hand-built and
hand-tested here.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift` | Port source — `UIScrollView` host, zoom 0.1×–64×, `viewForZooming`, double-tap-to-fit |
| `MakhtootKit/Sources/MKCanvas/CanvasSession.swift` | Port source — the `@MainActor` view-model spine |
| `MakhtootKit/Sources/MKCanvas/CanvasMode.swift` | Port source — `MKCanvasMode` (browse/editText/arrange/pathEdit) |
| `MakhtootKit/Sources/MKCanvas/CanvasContentAPI.swift` | Port source — `addLiveText`/`addPathText`/`addShape`/`addImage` for Batch 7's toolbar |
| `MakhtootKit/Sources/MKCanvas/CheckerboardPattern.swift` | Port source — transparent-canvas checkerboard |
| `MakhtootKit/Sources/MKCanvas/GridLines.swift` | Port source — pure grid math, screen-only presentation |
| `MakhtootKit/Sources/MKCanvas/Geometry/MKCanvasGeometrySource.swift` | Port source — `MKCanvasGeometrySource`/`MKCanvasRenderBridge`, the local seam over `:mk-render`'s `worldGeometry`/`containsPrecise`/`applyTransientTransform` |
| `MakhtootKit/Tests/MKCanvasTests/CanvasContentAPITests.swift`, `CanvasSessionTests.swift`, `MKCanvasViewControllerViewportCallbackTests.swift`, `MKCanvasHapticsTests.swift`, `FlipSceneTests.swift`, `FlipSessionTests.swift`, `CanvasTestSupport.swift` | Tests to port |
| `AUDIT_2026-07-28.md` P-2 finding | The 150 ms zoom-scale poll `EditorViewModel.swift:425` is app-shell scope (Batch 7), but the FIX it recommends — replacing polling with `scrollViewDidZoom`/`scrollViewDidScroll` delegate callbacks — is exactly what `MKCanvasViewControllerViewportCallbackTests.swift` regression-locks; port the CALLBACK-BASED design from day one, never a polling loop, on the Android side |
| `MakhtootKit/CONTRACTS.md` "WS-06 (`MKCanvas`) — consumption seam over WS-07's contract" section | `MKCanvasGeometrySource`/`MKCanvasRenderBridge` exact shapes and the two documented WS-07 contract-gap closures (`worldGeometry`/`containsPrecise`/`allHits`) this agent's geometry source adapts |
| `android/mk-render/src/main/kotlin/.../MkRenderTreeProviding.kt`, `MkHitTester.kt` (Batch 4 output) | The real contract this agent's `MkCanvasGeometrySource` adapts over |
| `android/PARITY_MATRIX.md`, `android/API_SURFACE.md` | Batch 0 outputs |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All seven of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.4 already stubbed — no orphaned stub paths outside this list.
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasViewController.kt` (the `MkCanvasView : View` + its Compose `AndroidView` host)
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasSession.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasMode.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasContentAPI.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCheckerboardPattern.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkGridLines.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkCanvasGeometrySource.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasContentAPITests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasSessionTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasViewControllerViewportCallbackTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasHapticsTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkFlipSceneTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkFlipSessionTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasTestSupport.kt` (shared test helper — 5.2a/5.2b/5.3/5.4a/5.4b's suites read this, do not edit it)
- `android/docs/impl-log/BATCH-5.1.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`, every
`android/mk-canvas/src/main/kotlin/...` path owned by 5.2a/5.2b/5.3/5.4a/5.4b (see this file's
ownership matrix appendix).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKCanvasViewController.swift` | 417 | `MkCanvasViewController.kt` | D-306: `UIScrollView` host → custom `MkCanvasView : View` with an OWNED `Matrix` transform, hosted in Compose via `AndroidView`. Zoom range 0.1×–64× (R-4.4's product-visible range is 2.5%–6400%, an editor-level clamp layered on top — port both ranges distinctly, do not conflate the raw view's technical zoom limits with the product-facing indicator's range). `viewForZooming`/double-tap-to-fit → `ScaleGestureDetector.OnScaleGestureListener` + a custom fit-to-screen computation. **Emit explicit viewport-change callbacks (a Kotlin `Flow`/listener interface mirroring `scrollViewDidZoom`/`scrollViewDidScroll`) from the FIRST implementation — never a polling loop**, per the AUDIT P-2 fix direction this file's own test (`MkCanvasViewControllerViewportCallbackTests`) locks in. |
| `CanvasSession.swift` | 256 | `MkCanvasSession.kt` | `@MainActor` → constrained to `Dispatchers.Main.immediate` (D-302), `@Observable`/published state → `StateFlow`. This is the spine 5.2a's gesture coordinator, 5.2b's snap engine, 5.3's selection/layers/inspector models, and 5.4a/5.4b's IME/arrange/path-text interaction models all read from — keep its public surface matching `android/API_SURFACE.md` exactly so those sibling agents (running concurrently) can code against it without waiting on this agent to finish. |
| `CanvasMode.swift` | 29 | `MkCanvasMode.kt` | `enum class` — `browse`/`editText`/`arrange`/`pathEdit`. `.arrange` routes to 5.4b's `MkArrangeInteractionModel`, `.pathEdit` to 5.4b's `MkPathTextInteractionModel`. |
| `CanvasContentAPI.swift` | 74 | `MkCanvasContentAPI.kt` | Extension functions on `CanvasSession` — `addLiveText(at:)` (default placeholder "اكتب هنا", opens the IME overlay immediately), `addPathText(preset:)`, `addShape(_:)`, `addImage(assetRef:)`. Batch 7's toolbar calls these directly; keep them free of any UI-toolkit import. |
| `CheckerboardPattern.swift` | 44 | `MkCheckerboardPattern.kt` | Pure pattern-tile geometry, no UIKit dependency in Swift — keep the Kotlin port equally free of `android.graphics`/Compose drawing calls where the Swift original is pure math; the actual paint call belongs to whatever chrome layer 5.1's view controller owns. |
| `GridLines.swift` | 32 | `MkGridLines.kt` | Pure math, screen-only presentation, reuses the same `MKSnapGuide`-shaped descriptor 5.2b's `MkSnapEngine`/`MkGuideRenderer` produce — do not invent a second guide-line primitive. |
| `Geometry/MKCanvasGeometrySource.swift` | 138 | `geometry/MkCanvasGeometrySource.kt` | `MkCanvasGeometrySource`/`MkCanvasRenderBridge` interfaces adapting `:mk-render`'s real `HitTester.worldGeometry`/`containsPrecise` and `RenderTreeProviding.applyTransientTransform`/`commitTransients` (Batch 4 output — by the time this batch runs those are the REAL conformers, not the iOS mid-flight local-seam workaround the Swift file's header describes; port the FINAL shape, not the historical stopgap). |

**Tasks.**
1. Port `MkCanvasMode.kt` and `MkCanvasContentAPI.kt` first (small, unblocks nothing critical but
   trivial to clear).
2. Port `geometry/MkCanvasGeometrySource.kt` against Batch 4's real `HitTester`/
   `RenderTreeProviding` — this is a thin adapter, not a redesign.
3. Port `MkCanvasSession.kt` — the shared spine. Publish its public surface early (within the
   batch's first work hour, mirroring the CONTRACTS.md contract-first duty pattern) since
   5.2a/5.2b/5.3/5.4a/5.4b all bind to it.
4. Port `MkCanvasViewController.kt` — the custom view + zoom/pan transform math + the
   viewport-callback interface. This is the largest, riskiest file in this agent's scope:
   `UIScrollView` gives iOS zoom-bounds clamping, zoom-scale bucketing, content inset,
   deceleration/bounce and the `scrollViewDidZoom`/`scrollViewDidScroll` callbacks essentially
   for free; every one of those must be hand-written and hand-tested here. Write
   `MkCanvasViewControllerViewportCallbackTests.kt` alongside the implementation, not after.
5. Port `MkCheckerboardPattern.kt`, `MkGridLines.kt`.
6. Port all seven test files.
7. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-5.1.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-canvas:testDebugUnitTest` green
- `./gradlew :mk-canvas:lintDebug` green
- Requirements covered: `R-4.1`, `R-4.2`, `R-4.3`, `R-4.4`, `R-4.5`
- Tests ported: `T-CVS-6` (zoom/pan fidelity), `T-CVS-9` (adaptive layout smoke — the view-
  host half; the panel-reflow half is Batch 7)
- Fixtures consumed: `android/fixtures/canvas/**` (Batch 0)
- Zoom-bounds clamping, zoom-scale bucketing, content inset, deceleration and bounce are all
  explicitly unit-tested (D-306's own instruction) — not merely "the view doesn't crash"
- Viewport changes are reported via listener/`Flow` callbacks with **zero polling loop**
  anywhere in this agent's port (explicit code-inspection acceptance item, P-2 intent)
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.1.md`

---

### Batch 5 · Agent 5.2a — `mk-canvas` gesture arbitration state machine

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port the gesture arbitration layer (drag/resize/rotate/marquee/move) — the split
of the original Agent 5.2 that owns the actual `MotionEvent` state machine. **This is the
highest-risk file-for-file port in the batch**: `UIGestureRecognizer`'s simultaneous-recognition
and failure-requirement arbitration has no Android equivalent — `MkGestureCoordinator` becomes
an explicit hand-written `MotionEvent` state machine, not a thin API substitution. Sibling agent
5.2b owns snapping/guides/geometry-helper math this agent's handle-drag and move-gesture code
calls into; both are `:mk-canvas`, both depend only on G4, and neither edits the other's files.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKCanvas/Gestures/GestureCoordinator.swift` | Port source — `MKGestureRouter`, the arbitration core |
| `MakhtootKit/Sources/MKCanvas/Gestures/HandleGestures.swift` | Port source — 8 resize handles + rotate handle drag math wiring |
| `MakhtootKit/Sources/MKCanvas/Gestures/MarqueeController.swift` | Port source — marquee rect → hit-set, intersect/contain modes |
| `MakhtootKit/Sources/MKCanvas/Gestures/MoveGesture.swift` | Port source — pan-on-selection → coalesced transform commands |
| `MakhtootKit/Tests/MKCanvasTests/GestureUndoCoalescingTests.swift`, `HandleGeometryRegressionTests.swift`, `MarqueeControllerTests.swift` | Tests to port |
| `android/mk-canvas/src/main/kotlin/.../MkCanvasSession.kt` (5.1's port target, same batch) | Gesture handlers call into the session's command-issuing API — code against `android/API_SURFACE.md`'s documented shape |
| `android/mk-canvas/src/test/kotlin/.../MkCanvasTestSupport.kt` (5.1's owned file, same batch) | Shared test helper this agent's suites import — read only |
| `android/mk-canvas/src/main/kotlin/.../geometry/MkAnchoredResize.kt`, `MkOrientedRect.kt` (5.2b's port targets, same batch) | `MkHandleGestures`/`MkGestureCoordinator` drive resize/rotate through these — code against the documented Swift shapes in `android/API_SURFACE.md`, do not wait on 5.2b finishing |
| `MakhtootKit/Sources/MKPersistence/Undo/MKCommand.swift` | Gesture-driven transforms coalesce into ONE undo command per continuous gesture (R-4.17) — this agent's coalescing-key scheme must match that contract |
| `FOUNDATION.md` §4/§5 (R-4.7, R-4.8) | Rotation snap angles, alignment-guide snap threshold |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All four of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.4 already stubbed — no orphaned stub paths outside this list.
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkGestureCoordinator.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkHandleGestures.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkMarqueeController.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkMoveGesture.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkGestureUndoCoalescingTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkHandleGeometryRegressionTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkMarqueeControllerTests.kt`
- `android/docs/impl-log/BATCH-5.2a.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`, every
`android/mk-canvas/src/main/kotlin/...` path owned by 5.1/5.2b/5.3/5.4a/5.4b, including
`MkSnapEngine.kt`/`MkGuideRenderer.kt`/`geometry/**` (5.2b's exclusive files).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Gestures/GestureCoordinator.swift` | 473 | `gestures/MkGestureCoordinator.kt` | **The main risk item.** `UIGestureRecognizer` arbitration (simultaneous recognition, failure requirements between e.g. pan-vs-pinch-vs-handle-drag) → an explicit `MotionEvent`-driven state machine: a sealed-class gesture-state model (`Idle`/`Panning`/`Scaling`/`Rotating`/`DraggingHandle`/`Marqueeing`/…) with hand-written transition rules replacing what `UIGestureRecognizer`'s `require(toFail:)`/delegate methods gave for free. This is genuinely new design work, not a lookup-table substitution — budget review time accordingly and document the state machine's transition table in the impl log. |
| `Gestures/HandleGestures.swift` | 242 | `gestures/MkHandleGestures.kt` | Drives 5.2b's `MkAnchoredResize` from `MkGestureCoordinator`'s `DraggingHandle` state. |
| `Gestures/MarqueeController.swift` | 51 | `gestures/MkMarqueeController.kt` | Pure rect math over `MKHitCandidate` (5.3's `MkHitTestPolicy.kt` type — code against the documented shape) — no gesture-recognizer/View dependency in this file, keep it that way in Kotlin. |
| `Gestures/MoveGesture.swift` | 119 | `gestures/MkMoveGesture.kt` | Per-frame transform commands with a coalescing key (`move-<gestureID>`) so an entire drag collapses to one undo command (R-4.17/T-CVS-8). |

**Tasks.**
1. Port `gestures/MkMarqueeController.kt`, `gestures/MkMoveGesture.kt`, `gestures/
   MkHandleGestures.kt` — each is a focused piece the coordinator dispatches to. Code
   `MkHandleGestures.kt` against 5.2b's documented `MkAnchoredResize`/`MkOrientedRect` API
   surface rather than waiting on 5.2b to finish.
2. Port `gestures/MkGestureCoordinator.kt` last, once its dependents exist. Design and document
   the `MotionEvent` state machine BEFORE writing test code against it; this file's own impl
   log entry should include the transition table.
3. Port all three test files. `HandleGeometryRegressionTests` is a pure-math property test and
   should be the easiest to get to full parity; `GestureUndoCoalescingTests` needs a
   `MotionEvent`-sequence test harness (synthetic pointer event injection) since there is no
   `UIGestureRecognizer`-equivalent test double to reuse.
4. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-5.2a.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-canvas:testDebugUnitTest` green
- `./gradlew :mk-canvas:lintDebug` green
- Requirements covered: `R-4.1`, `R-4.6` (marquee half), `R-4.7`
- Tests ported: `T-CVS-1`, `T-CVS-2`, `T-CVS-3`, `T-CVS-8`
- Fixtures consumed: `android/fixtures/canvas/**`
- The `MotionEvent` gesture state machine's transition table is documented in the impl log
- A continuous drag/resize/rotate gesture collapses to exactly one undo command (T-CVS-8's
  "press undo 3× restores original transform" contract) — explicit test, not incidental
  coverage
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.2a.md`

---

### Batch 5 · Agent 5.2b — `mk-canvas` snapping, guides, geometry helpers

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port the snap-candidate engine and guide rendering, and the pure geometry math
behind anchored resize, group transforms, and the oriented-bounding-box type every selection
outline/handle/marquee/snap candidate is expressed in — the split of the original Agent 5.2
that owns pure math and chrome rendering rather than gesture arbitration. Sibling agent 5.2a's
`MkHandleGestures`/`MkGestureCoordinator` drive this agent's `MkAnchoredResize`/`MkOrientedRect`
directly; this agent has no dependency back onto 5.2a.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKCanvas/SnapEngine.swift` | Port source — candidate snap lines, threshold/hysteresis |
| `MakhtootKit/Sources/MKCanvas/GuideRenderer.swift` | Port source — chrome-layer guide rendering |
| `MakhtootKit/Sources/MKCanvas/Geometry/MKAnchoredResize.swift` | Port source — anchored-scaling/aspect-lock/rotation-snap math |
| `MakhtootKit/Sources/MKCanvas/Geometry/MKGroupTransform.swift` | Port source — group/ungroup matrix math |
| `MakhtootKit/Sources/MKCanvas/Geometry/MKOrientedRect.swift` | Port source — the canonical OBB type |
| `MakhtootKit/Tests/MKCanvasTests/SnapEngineTests.swift`, `GeometryMathTests.swift` | Tests to port |
| `android/mk-canvas/src/main/kotlin/.../MkCanvasSession.kt` (5.1's port target, same batch) | This agent's engine reads the session's node list — code against `android/API_SURFACE.md`'s documented shape |
| `android/mk-canvas/src/test/kotlin/.../MkCanvasTestSupport.kt` (5.1's owned file, same batch) | Shared test helper this agent's suites import — read only |
| `FOUNDATION.md` §4/§5 (R-4.7, R-4.8) | Rotation snap angles, alignment-guide snap threshold |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All five of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.4 already stubbed — no orphaned stub paths outside this list.
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSnapEngine.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkGuideRenderer.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkAnchoredResize.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkGroupTransform.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkOrientedRect.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSnapEngineTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkGeometryMathTests.kt`
- `android/docs/impl-log/BATCH-5.2b.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`, every
`android/mk-canvas/src/main/kotlin/...` path owned by 5.1/5.2a/5.3/5.4a/5.4b, including
`gestures/**` (5.2a's exclusive files).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `SnapEngine.swift` | 206 | `MkSnapEngine.kt` | Pure math over plain candidate arrays — canvas edges/center, sibling node edges/centers (max 200 candidates by proximity), equal-spacing triples. Snap threshold 4 pt (R-4.8; note the Swift header's own "6 view-pt" comment references a different, zoom-normalized figure for a different consumer — use R-4.8's PRD-locked 4 pt for the canvas snap threshold and record which applies where if the two diverge), hysteresis to prevent flicker. |
| `GuideRenderer.swift` | 107 | `MkGuideRenderer.kt` | Chrome-layer guide-line drawing (accent color, hairline) from `MKSnapGuide` descriptors — `CALayer`-based chrome → a Compose overlay/custom `View` draw pass. |
| `Geometry/MKAnchoredResize.swift` | 208 | `geometry/MkAnchoredResize.kt` | Pure numeric math for the 8 resize handles + 1 rotate handle: anchored scaling (opposite handle/center with modifier), aspect lock (corner default proportional, edge free), rotation about selection center with angle snap (0/±45/±90/180°, R-4.7). Operates on `MkOrientedRect`, returns a new one — never mutates. Consumed directly by 5.2a's `MkHandleGestures`. |
| `Geometry/MKGroupTransform.swift` | 38 | `geometry/MkGroupTransform.kt` | Pure matrix math backing group→transform→ungroup round-tripping (T-CVS-2's property-test contract: relative positions preserved through group rotate). |
| `Geometry/MKOrientedRect.swift` | 147 | `geometry/MkOrientedRect.kt` | The canonical OBB — every selection outline, handle, marquee candidate, and snap candidate is expressed in this shape. `MKModel` carries no node "size" field by design (content extent is a rendering concern) — this type is where canvas-side size/bounds live, mirroring the Swift design exactly. |

**Tasks.**
1. Port `geometry/MkOrientedRect.kt` first — everything else in this agent (and 5.2a's
   `MkHandleGestures`) depends on it. Publish its shape early since 5.2a codes against it
   concurrently.
2. Port `geometry/MkAnchoredResize.kt` and `geometry/MkGroupTransform.kt` (pure math, no
   gesture dependency, fastest to get green).
3. Port `MkSnapEngine.kt`, `MkGuideRenderer.kt`.
4. Port both test files — `GeometryMathTests` is a pure-math property test and should be the
   easiest to get to full parity.
5. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-5.2b.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-canvas:testDebugUnitTest` green
- `./gradlew :mk-canvas:lintDebug` green
- Requirements covered: `R-4.7`, `R-4.8`
- Tests ported: (none of the T-CVS numbered ids are exclusively this agent's — its two test
  files back R-4.7/R-4.8 acceptance directly; T-CVS-1/2/3/8 remain 5.2a's per its own packet)
- Fixtures consumed: `android/fixtures/canvas/**`
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.2b.md`

---

### Batch 5 · Agent 5.3 — `mk-canvas` selection, hit-test, layers, inspector, keys

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port the selection state model, its chrome-layer visual (outlines + handles),
the hit-test POLICY layer (tap cycling, lock/hide exclusion — geometry itself lives in
`:mk-render`'s `HitTester`, Batch 4), the layers panel model, the numeric inspector model, the
copy/paste/flip/select-all editing operations, and the hardware-keyboard command map —
important for Android tablets and DeX/ChromeOS, where `UIKeyCommand` has no analogue.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKCanvas/SelectionState.swift` | Port source — single/multi selection, glyph/mark/ligature granularity |
| `MakhtootKit/Sources/MKCanvas/SelectionChromeLayer.swift` | Port source — selection outline + handle layout |
| `MakhtootKit/Sources/MKCanvas/HitTestPolicy.swift` | Port source — tap-cycling, 44 pt slop → **48dp per D-319**, lock/hide policy filter over `:mk-render`'s raw hit stack |
| `MakhtootKit/Sources/MKCanvas/LayersModel.swift` | Port source — flattened ordered list, arranged-node child sections |
| `MakhtootKit/Sources/MKCanvas/InspectorModel.swift` | Port source — the largest file in this agent's scope; numeric X/Y/W/H/rotation + style bindings |
| `MakhtootKit/Sources/MKCanvas/EditingOperations.swift` | Port source — copy/paste/select-all/deselect/flip |
| `MakhtootKit/Sources/MKCanvas/KeyCommands.swift` | Port source — `UIKeyCommand` → hardware key map |
| `MakhtootKit/Tests/MKCanvasTests/HitTestPolicyTests.swift`, `InspectorModelTests.swift`, `LayersModelTests.swift`, `MergeDesignSessionTests.swift` | Tests to port |
| `android/mk-canvas/src/main/kotlin/.../MkCanvasSession.kt` (5.1's port target, same batch) | This agent's models bind to the session — code against the documented API |
| `android/mk-render/src/main/kotlin/.../MkHitTester.kt` (Batch 4 output) | `MkHitTestPolicy.kt` is a POLICY filter over this — locked-nodes-included-in-stack is `MkHitTester`'s job, tap-selection-skips-locked is this agent's job (R-4.6 founder ruling, mirrored from the iOS CONTRACTS.md gap-closure note) |
| `FOUNDATION.md` §9 (D-126), `D-319` (Batch 0 §0.5 output — accessibility touch-target floor) | 44pt→48dp substitution, RTL-first component conventions |
| `TEST_MATRIX.md` §6 (T-CVS-4, T-CVS-5, T-CVS-7) | Layers/inspector/lock-hide exact contract |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All seven of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.4 already stubbed — no orphaned stub paths outside this list.
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSelectionState.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSelectionChromeLayer.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkHitTestPolicy.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkLayersModel.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkInspectorModel.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkEditingOperations.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkKeyCommands.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkHitTestPolicyTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkInspectorModelTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkLayersModelTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkMergeDesignSessionTests.kt`
- `android/docs/impl-log/BATCH-5.3.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`, every
`android/mk-canvas/src/main/kotlin/...` path owned by 5.1/5.2a/5.2b/5.4a/5.4b.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `SelectionState.swift` | 83 | `MkSelectionState.kt` | `MKSelectionGranularity` → `enum class`; single/multi, additive tap, marquee intersect/contain modes, glyph/mark/ligature granularity inside an arranged node (via Batch 4's `LevelMapping`), locked/hidden exclusion. |
| `SelectionChromeLayer.swift` | 195 | `MkSelectionChromeLayer.kt` | `CALayer`/`CAShapeLayer` overlay → a Compose overlay/custom `View` draw pass. Multi-select union bounds + 8 resize handles + rotate handle above-top-center; handles scale-invariant (constant screen size across zoom — compute handle size in screen space, not canvas space, exactly as the Swift file does). |
| `HitTestPolicy.swift` | 145 | `MkHitTestPolicy.kt` | Tap → `:mk-render`'s `HitTester.node(at:)` respecting z-order, `isLocked`/`isHidden` skip. Touch slop: **44 pt (iOS) → 48dp (D-319 Android convention)** for thin-stroke hit inflation — this is a genuine numeric substitution, not a 1:1 constant copy. Inside an `arranged` node in Arrange Mode, hit-testing routes to glyph/mark/ligature granularity per Batch 4's geometry. |
| `LayersModel.swift` | 314 | `MkLayersModel.kt` | `@MainActor` → main-dispatcher-confined class. Flattened ordered list (top-first) with sections for arranged-node children (glyphs "حرف", marks "تشكيل", ligatures "لام-ألف/رباط" — R-10.1/R-10.3) when expanded. Virtualized list for 5,000+ nodes (D-115 heavy budget) — the Kotlin model must expose the same lazy/paginated access shape Compose's `LazyColumn` needs, not a single flat `List` materialized eagerly. |
| `InspectorModel.swift` | 662 | `MkInspectorModel.kt` | The largest file here. `@MainActor` → main-dispatcher-confined. X/Y/W/H/rotation + style bindings (R-10.6); Arabic-Indic AND European digit input acceptance (R-10.7) — port the digit-normalization logic exactly, this is Arabic-correctness-adjacent (locale-appropriate display, `ar` decimal separator, RTL field alignment); mixed-selection "—" display + apply-to-all-selected semantics (R-10.8); W/H field semantics differ by node type — Live Text W edits wrap width (H derived, read-only), Arranged Composition W/H scale the composition aspect-locked by default (R-10.9). |
| `EditingOperations.swift` | 331 | `MkEditingOperations.kt` | Copy/Paste (internal scene-node pasteboard vs. external-text → new Live Text object, R-4.11), Select All/Deselect All, Flip Horizontal/Vertical. `MKPasteError` → sealed exception class. Android pasteboard = `ClipboardManager` with a custom `ClipData` MIME type for internal scene-node paste, falling back to plain-text paste as a new Live Text object exactly like iOS's external-text path. |
| `KeyCommands.swift` | 132 | `MkKeyCommands.kt` | `UIKeyCommand` → Compose `onKeyEvent`/`onPreviewKeyEvent` + an explicit hardware key map (arrow-key nudge 1pt/⇧10pt, Ctrl+Z/Ctrl+Shift+Z undo/redo, Ctrl+G/Ctrl+Shift+G group/ungroup, Ctrl+D duplicate, Delete). Important for Android tablets and DeX/ChromeOS hardware-keyboard sessions — this has no iOS-parity shortcut, it is new coverage surface (⌘ on iOS → Ctrl on Android's convention; document the exact modifier-key mapping table in the impl log). |

**Tasks.**
1. Port `MkSelectionState.kt` first — `HitTestPolicy`, `LayersModel`, `InspectorModel`, and
   `EditingOperations` all reference it.
2. Port `MkHitTestPolicy.kt` against Batch 4's real `MkHitTester.kt` — apply the 44pt→48dp
   substitution explicitly and record it in the impl log.
3. Port `MkSelectionChromeLayer.kt`.
4. Port `MkLayersModel.kt` with the virtualization contract in mind from the start — retrofitting
   lazy access after building an eager list is expensive; design for `LazyColumn` consumption
   up front.
5. Port `MkInspectorModel.kt` — the largest, most detail-dense file. Build the Arabic-Indic/
   European digit normalizer as a small internal utility with its own focused unit tests before
   wiring it into every field.
6. Port `MkEditingOperations.kt`.
7. Port `MkKeyCommands.kt`, documenting the iOS-shortcut → Android-hardware-key mapping table.
8. Port all four test files.
9. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-5.3.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-canvas:testDebugUnitTest` green
- `./gradlew :mk-canvas:lintDebug` green
- Requirements covered: `R-4.6`, `R-4.9`, `R-4.10`, `R-4.11`, `R-4.12`, `R-4.13`, `R-4.14`,
  `R-10.1`–`R-10.10`
- Tests ported: `T-CVS-4`, `T-CVS-5`, `T-CVS-7`
- Fixtures consumed: `android/fixtures/canvas/**`
- 48dp touch-target floor verified by an explicit test (D-319), not merely inherited from the
  44pt Swift constant
- Layers panel model exposes a lazily-consumable shape verified against a 5,000+-node fixture
  (D-115 heavy budget) — no eager full-list materialization in the test
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.3.md`

---

### Batch 5 · Agent 5.4a — `mk-canvas` IME text-editing overlay

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port D-307's transparent-`EditText`-plus-custom-`InputConnection` overlay for
Arabic IME/keyboard/selection correctness. **This is the highest-risk UI agent in the plan.**
Arabic IME correctness, RTL selection handles, cursor placement inside shaped RTL text, and
composing-region handling are genuinely hard on Android and have no drop-in equivalent to
TextKit 2's `UITextView`. The original Agent 5.4 packet carried this file alongside the
Arrange/Path-Text interaction models (now sibling agent 5.4b); this agent owns only the IME
overlay so its risk is not diluted by unrelated scope.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKCanvas/TextEditingOverlay.swift` | Port source — overlay lifecycle state machine, coalesced text mirroring, commit/cancel |
| `MakhtootKit/Tests/MKCanvasTests/TextEditingOverlayTests.swift` | Tests to port |
| `FOUNDATION.md` §3 (D-104), D-307 (Batch 0 §0.5 output) | Overlay/committed-render metrical-identity contract, the Android IME architecture decision |
| `android/mk-canvas/src/main/kotlin/.../MkCanvasSession.kt` (5.1's port target, same batch) | The overlay is activated by `MkCanvasMode.editText` transitions on the session |
| `TEST_MATRIX.md` §6/§7.10 (T-CVS-10, T-CVS-11) | Exact IME/selection acceptance contract |

**Owns (creates or edits — no other agent may touch these).** The path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite the
stub body as part of landing the real implementation (see Tasks, final item). This agent's single
Kotlin target is a 1:1 mechanical transform of its Swift source landing at exactly the path
Batch 1 · Agent 1.4 already stubbed — no orphaned stub path outside this list.
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkTextEditingOverlay.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkTextEditingOverlayTests.kt`
- `android/docs/impl-log/BATCH-5.4a.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`, every
`android/mk-canvas/src/main/kotlin/...` path owned by 5.1/5.2a/5.2b/5.3/5.4b, including
`arrange/**`/`pathtext/**` (5.4b's exclusive files).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `TextEditingOverlay.swift` | 532 | `MkTextEditingOverlay.kt` | D-307: transparent `EditText` + a custom `InputConnection` implementation, replacing the `UITextView`(TextKit 2) overlay. The overlay lifecycle state machine (appear on double-tap/`addLiveText`, coalesced text mirroring while composing, commit on tap-outside, cancel-with-full-restore) ports 1:1 in SHAPE but the IME plumbing itself is new Android-specific work: `InputConnection.setComposingText`/`finishComposingText`/`setComposingRegion`, `InputConnection.getCursorCapsMode`, and correct `ExtractedText`/selection reporting for RTL text. `MKTashkeelInput` (long-press tashkeel entry helper) → a Kotlin equivalent wired to the IME's long-press-popup or a custom accessory strip, whichever the Arabic Gboard/keyboard convention actually needs — verify against a real Arabic Android keyboard during implementation, don't assume iOS's long-press behavior transfers. Committed rendering after overlay dismissal is ALWAYS the shaping-capture→render path (D-104/D-303) — the overlay is display-only during composition, never the source of truth for committed glyphs. |

**Tasks.**
1. **Treat the `InputConnection` implementation as the riskiest single deliverable in Batch 5.**
   Prototype against a real Arabic system keyboard (Gboard Arabic) early — do not assume the
   Swift lifecycle state machine's shape alone guarantees correct Android IME behavior.
   Composing-region handling, cursor placement inside HarfBuzz-shaped RTL runs, and
   selection-handle positioning in RTL text are the specific correctness surfaces to prove out,
   not merely "text appears when typed."
2. Port `MkTextEditingOverlay.kt`.
3. Port `MkTextEditingOverlayTests.kt`.
4. Explicitly test: Arabic IME composing (tashkeel long-press or accessory entry), RTL
   selection-handle drag correctness, cursor placement at a bidi-run boundary, and cancel-
   during-composition full restore. These map to T-CVS-10/T-CVS-11 and are the acceptance
   bar, not incidental coverage.
5. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stub at the path in
   this agent's Owns list above; name the superseded stub path in
   `android/docs/impl-log/BATCH-5.4a.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-canvas:testDebugUnitTest` green
- `./gradlew :mk-canvas:lintDebug` green
- Requirements covered: `R-5.1`
- Tests ported: `T-CVS-10`, `T-CVS-11`
- Fixtures consumed: `android/fixtures/canvas/**`
- Arabic IME correctness (tashkeel entry, composing region, cursor placement in shaped RTL
  text, RTL selection handles) is verified by dedicated tests, not inferred from "compiles and
  the overlay appears" — this is the explicit, called-out acceptance bar for the highest-risk
  agent in the plan (spine's own framing)
- Committed rendering after overlay dismissal round-trips through the shaping-capture→render
  path with zero divergence from the overlay's displayed content (D-104 parity)
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.4a.md`

---

### Batch 5 · Agent 5.4b — `mk-canvas` arrange and path-text interaction models

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port the two mode-specific interaction models (Arrange Mode, Path-Edit Mode) plus
their engine-providing seams and chrome layer — the split of the original Agent 5.4 that owns
the two interaction models rather than the IME overlay (sibling agent 5.4a), so the overlay's
IME risk does not dilute review attention on this agent's Arrange/Path-Text correctness surface,
and vice versa.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKCanvas/Arrange/MKArrangeInteractionModel.swift` | Port source — Arrange Mode canvas interaction (largest single file in this agent's scope) |
| `MakhtootKit/Sources/MKCanvas/Arrange/MKArrangeEngineProviding.swift` | Port source — the seam over Batch 4's `:mk-arrange` engine |
| `MakhtootKit/Sources/MKCanvas/PathText/MKPathTextInteractionModel.swift` | Port source — Path-Edit Mode canvas interaction |
| `MakhtootKit/Sources/MKCanvas/PathText/MKPathTextEngineProviding.swift` | Port source — the seam over Batch 4's `:mk-pathtext` engine |
| `MakhtootKit/Sources/MKCanvas/PathText/PathEditChromeLayer.swift` | Port source — anchor/handle chrome for path editing |
| `MakhtootKit/Tests/MKCanvasTests/ArrangeInteractionModelTests.swift`, `ArrangeInteractionTestSupport.swift`, `PathTextInteractionModelTests.swift`, `PathTextInteractionTestSupport.swift` | Tests to port |
| `android/mk-arrange/src/main/kotlin/**`, `android/mk-pathtext/src/main/kotlin/**` (Batch 4 output) | The real arrange/path-text engines this agent's interaction models drive |
| `android/mk-canvas/src/main/kotlin/.../MkCanvasSession.kt` (5.1's port target, same batch) | Mode-specific interaction models are activated by `MkCanvasMode` transitions on the session |
| `android/mk-canvas/src/main/kotlin/.../MkSelectionChromeLayer.kt` (5.3's port target, same batch) | `MkPathEditChromeLayer` mirrors this file's pure-geometry/`View`-drawing architectural split — code against the documented shape, do not wait on 5.3 |
| `TEST_MATRIX.md` §7.9 (T-AR-46…50) | Exact arrange/path-text-editing acceptance contract |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All five of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.4 already stubbed — no orphaned stub paths outside this list.
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/arrange/MkArrangeInteractionModel.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/arrange/MkArrangeEngineProviding.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathTextInteractionModel.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathTextEngineProviding.kt`
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathEditChromeLayer.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkArrangeInteractionModelTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkArrangeInteractionTestSupport.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkPathTextInteractionModelTests.kt`
- `android/mk-canvas/src/test/kotlin/net/binjamshid/makhtoot/mk/canvas/MkPathTextInteractionTestSupport.kt`
- `android/docs/impl-log/BATCH-5.4b.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`, every
`android/mk-canvas/src/main/kotlin/...` path owned by 5.1/5.2a/5.2b/5.3/5.4a, including
`MkTextEditingOverlay.kt` (5.4a's exclusive file).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Arrange/MKArrangeInteractionModel.swift` | 603 | `arrange/MkArrangeInteractionModel.kt` | The largest single file in this agent's scope. Canvas-side Arrange Mode interaction: per-node selection/drag/style edits routed through Batch 4's `:mk-arrange` `MkArrangeCommands`/`MkArrangeStyleEditor`, level-toggle UI state, break-join/decompose/recompose/detach/reattach affordances wired to `MkJoinController`/`MkLigatureDecomposer`/`MkMarkAttachmentController`. Must preserve R-6.3 (never auto-reflow) as a canvas-level guarantee too — no gesture path in this file may silently trigger a reshape. |
| `Arrange/MKArrangeEngineProviding.swift` | 191 | `arrange/MkArrangeEngineProviding.kt` | `MkArrangeFormOption`, `MkArrangeFormSelectorModel`, `MkArrangeRevertPreflight`, `MkArrangeRecomposePreflight`, `MkArrangeSourceEditConflict` → `data class`/sealed class. `MkArrangeEngineProviding` interface is the seam `MkArrangeInteractionModel` drives — the REAL conformer wires Batch 4's `:mk-arrange` types directly (no iOS-style "not yet landed" stopgap needed here since `:mk-arrange` already exists by this batch). |
| `PathText/MKPathTextInteractionModel.swift` | 372 | `pathtext/MkPathTextInteractionModel.kt` | Canvas-side Path-Edit Mode interaction: anchor/handle drag → Batch 4's `MkPathEditModel` operations, live relayout during path edits (R-9.3), arrange-on-path entry. |
| `PathText/MKPathTextEngineProviding.swift` | 242 | `pathtext/MkPathTextEngineProviding.kt` | `MkPathHandleID`, `MkPathHitTarget`, `MkPathHandleMode`, `MkPathGlyphHit` → `data class`/`enum class`. `MkPathTextEngineProviding` interface — real conformer wires Batch 4's `:mk-pathtext` directly. |
| `PathText/PathEditChromeLayer.swift` | 197 | `pathtext/MkPathEditChromeLayer.kt` | Pure geometry enum (`PathEditChromeGeometry`, unit-testable without a `View`) mirroring 5.3's `MkSelectionChromeLayer`'s architectural split, plus the `View`-drawing half for anchors/handles chrome. |

**Tasks.**
1. Port `arrange/MkArrangeEngineProviding.kt` and `pathtext/MkPathTextEngineProviding.kt`
   first (small, unblocks the two interaction models).
2. Port `arrange/MkArrangeInteractionModel.kt` against Batch 4's real `:mk-arrange` engine.
3. Port `pathtext/MkPathEditChromeLayer.kt` and `pathtext/MkPathTextInteractionModel.kt`.
4. Port all four test files.
5. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-5.4b.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-canvas:testDebugUnitTest` green
- `./gradlew :mk-canvas:lintDebug` green
- Requirements covered: `R-6.5`, `R-6.6`, `R-6.7`, `R-6.9`, `R-6.10`, `R-6.11`,
  `R-9.1`, `R-9.3`, `R-9.4`, `R-9.7`
- Tests ported: (T-AR-46…50 per `TEST_MATRIX.md` §7.9 — verify each id against the real test
  matrix before writing its Kotlin twin, same discipline as Batch 4 · Agent 4.2)
- Fixtures consumed: `android/fixtures/canvas/**`
- R-6.3 (never auto-reflow) holds as a canvas-level guarantee — no gesture path in
  `MkArrangeInteractionModel` silently triggers a reshape (explicit test, not incidental)
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.4b.md`

---

### Batch 5 · Agent 5.5a — `mk-assets` generators, model, library, manifest, browser

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port the `mk-assets` "catalog" half — 17 of the module's 24 source files: the five
procedural generators (basic shapes, ornaments, frames, calligraphic elements, pattern tiles),
the shared authoring-time geometry model, the in-memory asset library and manifest codec, and
the asset-browser model/search/favorites surface. This is the split of the original single-agent
5.5 packet; sibling agent 5.5b owns instantiation/provenance/thumbnails/contact-sheet (the
"usage and QA" half). **Judgment call, recorded here since spine only names "generators, model,
library, manifest" for this half:** `browser/**` (4 files) is assigned to 5.5a rather than 5.5b
because asset browsing is a catalog-consumption concern (search/favorites/sections over
`MkAssetLibrary`), not an instantiation or provenance concern — it has no natural home in 5.5b's
scope.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKAssets/Browser/*.swift`, `Generators/*.swift`, `Library/*.swift`, `Model/*.swift` (17 files, listed in the port map below) | Port source |
| `MakhtootKit/Tests/MKAssetsTests/{MKAssetBrowserModel,MKAssetDescriptor,MKAssetManifestResource,MKAssetNamingLint,MKBasicShapes,MKCalligraphic,MKFrames,MKOrnaments,MKPatternBackground,MKUserDefaultsAssetMetadataStore}Tests.swift`, `TestSupport/FreeEntitlementStub.swift` | Tests to port |
| `PRD.md` §11 (R-11.1–R-11.5) | Category lock (five BRIEF-locked categories, no invented ones), "not templates" rule, pattern-background premium gating |
| `MakhtootKit/CONTRACTS.md` (search "MKAssets"/"WS-14") if present, else `docs/impl-log/WS-14.md` | Design rationale for the dependency-fence discipline (`MKAssets` depends ONLY on `MKModel`, never `MKPersistence`/`MKRender`) |
| `android/fixtures/assets/**` (Batch 0) | Manifest goldens |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All seventeen of
this agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at
exactly the path Batch 1 · Agent 1.4 already stubbed — no orphaned stub paths outside this list.
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetBrowserModel.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetFavoritesStoring.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetSearchNormalizer.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkUserDefaultsAssetMetadataStore.kt` (→ Android: backed by `DataStore`, not `UserDefaults` — see port map)
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkBasicShapeGenerator.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkCalligraphicGenerator.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkFrameGenerator.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkOrnamentGenerator.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkPatternTileGenerator.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/library/MkAssetLibrary.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/library/MkAssetManifestCodec.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetCategory.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetDescriptor.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetGeometry.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetPathBuilder.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetProvenance.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkPatternFill.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetBrowserModelTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetDescriptorTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetManifestResourceTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetNamingLintTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkBasicShapesTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkCalligraphicTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkFramesTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkOrnamentsTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkPatternBackgroundTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkUserDefaultsAssetMetadataStoreTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/TestSupport/MkFreeEntitlementStub.kt` (shared test helper — 5.5b's suites read this, do not edit it)
- `android/docs/impl-log/BATCH-5.5a.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`,
`android/mk-assets/src/main/kotlin/.../instantiation/**`, `provenance/**`, `rendering/**`
(5.5b's exclusive files).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Browser/MKAssetBrowserModel.swift` | 156 | `browser/MkAssetBrowserModel.kt` | Sections by category, search, favorites, premium badge state, recents, placement API. |
| `Browser/MKAssetFavoritesStoring.swift` | 58 | `browser/MkAssetFavoritesStoring.kt` | `MKAssetMetadataStoring` protocol + `MKInMemoryAssetMetadataStore` actor → `interface` + a coroutine-`Mutex`-guarded in-memory conformer. Stub-protocol pattern preserved: real `:mk-persistence`-backed conformer wires later at the composition root (Batch 7), same as iOS. |
| `Browser/MKAssetSearchNormalizer.swift` | 48 | `browser/MkAssetSearchNormalizer.kt` | Tashkeel-stripping + hamza/ta-marbuta/alif-maqsura unification. `MKAssets` has no `:mk-persistence` dependency edge (frozen module-graph fence, same as iOS) so this is a SECOND, small, deliberately-duplicated copy of the shared Arabic normalizer logic `:mk-persistence`'s `SearchNormalizer` also has — port the duplication as-is, do not "fix" it by adding a cross-module dependency without a `CONTRACT_CHANGES.md` entry. |
| `Browser/MKUserDefaultsAssetMetadataStore.swift` | 102 | `browser/MkUserDefaultsAssetMetadataStore.kt` | `UserDefaults`-backed actor → Jetpack `DataStore<Preferences>`-backed class (D-304: AndroidX DataStore is the JVM-side substitution for lightweight local prefs). Same "stub now, real `:mk-persistence` conformer later" posture. |
| `Generators/MKBasicShapeGenerator.swift` | 131 | `generators/MkBasicShapeGenerator.kt` | ≥10 basic shapes, all free tier. Programmatic geometry via `MkAssetPathBuilder`, no bitmap assets. |
| `Generators/MKCalligraphicGenerator.swift` | 146 | `generators/MkCalligraphicGenerator.kt` | ≥10 calligraphic divider/flourish elements — DRAWN paths (variable-width outlines via `MkAssetPathBuilder.ribbon`), never font glyphs, never derived from any font file (sidesteps OFL reserved-name/scope concerns — preserve this discipline exactly, do not "simplify" by sampling a font outline). |
| `Generators/MKFrameGenerator.swift` | 158 | `generators/MkFrameGenerator.kt` | ≥8 frames, ≥3 free. Hollow-border silhouettes via opposite-wound outer/inner boundaries (nonzero fill rule produces the hole) — port the exact winding-order discipline, a naive same-direction pair will fill solid instead of hollow. |
| `Generators/MKOrnamentGenerator.swift` | 259 | `generators/MkOrnamentGenerator.kt` | ≥16 original Arabic ornaments, free: 6, premium: 10. Aniconic geometry/floral abstraction only — no text, no Qur'anic content (§2 OUT of scope, R-11.1's "license-clear" discipline). |
| `Generators/MKPatternTileGenerator.swift` | 109 | `generators/MkPatternTileGenerator.kt` | ≥8 pattern-background tiles, ALL premium (D-215/R-11.4 — free tier backgrounds are solid colors only). |
| `Library/MKAssetLibrary.swift` | 57 | `library/MkAssetLibrary.kt` | The aggregated v1 asset set, built once in-memory from the five generators — no I/O, no JSON parsing at runtime for the ~57 authored assets; keep it equally cheap in Kotlin (object construction, not resource-file parsing, for the runtime source of truth). Read by 5.5b's `MkAssetProvenanceLibrary`/`MkAssetInstantiator`. |
| `Library/MKAssetManifestCodec.swift` | 88 | `library/MkAssetManifestCodec.kt` | `Codable` manifest (`assets-manifest.json` in module resources) → `kotlinx.serialization`, resource loaded from `android/mk-assets/src/main/resources/` (or `assets/` per the module's Gradle resource convention — confirm against Batch 1's scaffold). |
| `Model/MKAssetCategory.swift` | 38 | `model/MkAssetCategory.kt` | The five BRIEF-locked categories, Arabic names verbatim (أشكال/زخارف/إطارات/عناصر/خلفيات) — `enum class`, no invented categories (R-11.1's explicit lock). |
| `Model/MKAssetDescriptor.swift` | 130 | `model/MkAssetDescriptor.kt` | `MkFrameNineSliceInsets` + `MkAssetDescriptor` → `data class`, `@Serializable`. |
| `Model/MKAssetGeometry.swift` | 180 | `model/MkAssetGeometry.kt` | Authoring-time vector representation (subpaths + fill rule + styleable regions), layered on top of `:mk-model`'s `MkBezierSegment` (reused, not redefined). |
| `Model/MKAssetPathBuilder.swift` | 263 | `model/MkAssetPathBuilder.kt` | Shared geometry primitives every generator builds on: regular/star polygons, circular arcs (kappa-based cubic Bézier approximation), rounded rects, variable-width "ribbon" paths. |
| `Model/MKAssetProvenance.swift` | 84 | `model/MkAssetProvenance.kt` | Mirrors the font-license-capture discipline (FOUNDATION §12: no invented legal/policy facts) for non-font bundled assets. `MkAssetOrigin` → sealed class/enum; `MkAssetForbiddenSourceMarkers` → validated constant list. Consumed by 5.5b's `MkAssetProvenanceLibrary` derivation. |
| `Model/MKPatternFill.swift` | 49 | `model/MkPatternFill.kt` | Vector tile + tile size + repeat mode + two styleable colors (background/motif). ALL premium gated (D-215). |

**Tasks.**
1. Port `model/**` first (category, descriptor, geometry, path-builder, provenance, pattern
   fill) — every generator depends on these, and 5.5b's provenance derivation depends on
   `MkAssetProvenance`/`MkAssetDescriptor`. Publish their shapes early since 5.5b codes against
   them concurrently.
2. Port the five `generators/**` files. Preserve category free/premium counts exactly (basic
   shapes: all free; ornaments: 6 free / 10 premium; frames: ≥3 free of ≥8; calligraphic: all
   free; pattern tiles: all premium) — these counts are load-bearing for `TestFixtures`/
   T-AST-1 and for the paywall discovery surface (R-11.4).
3. Port `library/MkAssetLibrary.kt` (aggregates the five generators) and
   `library/MkAssetManifestCodec.kt`. Publish `MkAssetLibrary.standard`'s shape early — 5.5b's
   `MkAssetProvenanceLibrary`, `MkAssetInstantiator` and `MkAssetThumbnailRenderer` all read it.
4. Port `browser/**`.
5. Port all ten test files + the shared `TestSupport/MkFreeEntitlementStub.kt` helper.
6. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-5.5a.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-assets:testDebugUnitTest` green
- `./gradlew :mk-assets:lintDebug` green
- Requirements covered: `R-11.1`, `R-11.4` (generator/library half)
- Tests ported: `T-AST-1`
- Fixtures consumed: `android/fixtures/assets/**` — manifest goldens
- The five BRIEF-locked categories are the only categories the `enum class` exposes — no
  invented sixth category
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.5a.md`

---

### Batch 5 · Agent 5.5b — `mk-assets` instantiation, provenance, thumbnails, contact sheet

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port the `mk-assets` "usage and QA" half — the remaining 7 of the module's 24
source files: instantiation (placement into scene nodes, pattern-fill instantiation, the
premium-content ledger), the license-provenance discipline mirroring fonts' (no asset ships
without a recorded provenance record, derived by construction from 5.5a's library), and the
deterministic thumbnail renderer + QA contact-sheet generator. This agent also owns closing the
known iOS contact-sheet test flake, since `MkAssetContactSheetGenerator`/its test live here.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKAssets/Instantiation/*.swift`, `Provenance/*.swift`, `Rendering/*.swift` (7 files, listed in the port map below) | Port source |
| `MakhtootKit/Tests/MKAssetsTests/{AssetProvenanceAudit,MKAssetContactSheet,MKAssetInstantiation,MKAssetProvenance,MKAssetThumbnail,MKPremiumContentMarking}Tests.swift` | Tests to port |
| `PRD.md` §11 (R-11.1–R-11.5) | Pattern-background premium gating, provenance-record requirement |
| `A memory note on this repo's known flaky-test pattern (see Tasks 2)` | `MKAssetContactSheetTests` fails intermittently in FULL Swift test runs only (passes with `--filter`) — writes real PNG evidence to a shared path and can leave a stale zero-byte temp file behind; this is an ORDERING/SHARED-STATE dependency the Android port must not reproduce |
| `android/mk-assets/src/main/kotlin/.../library/MkAssetLibrary.kt`, `model/MkAssetDescriptor.kt`, `model/MkAssetProvenance.kt` (5.5a's port targets, same batch) | `MkAssetProvenanceLibrary`'s derivation and `MkAssetInstantiator`/`MkAssetThumbnailRenderer` read `MkAssetLibrary.standard` directly — code against the documented Swift shapes in `android/API_SURFACE.md`, do not wait on 5.5a finishing |
| `android/mk-assets/src/test/kotlin/.../TestSupport/MkFreeEntitlementStub.kt` (5.5a's owned file, same batch) | Shared test helper this agent's premium-content tests import — read only |
| `android/mk-render/src/main/kotlin/.../MkSnapshotRenderer.kt` (Batch 4 output) | `MkAssetThumbnailRenderer` renders through this — single-render-path invariant |
| `android/fixtures/assets/**` (Batch 0) | Provenance/thumbnail goldens |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All seven of this
agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at exactly the
path Batch 1 · Agent 1.4 already stubbed — no orphaned stub paths outside this list.
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkAssetInstantiator.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkPatternInstantiator.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkPremiumContentLedger.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/provenance/MkAssetProvenanceLibrary.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/provenance/MkAssetProvenanceStore.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/rendering/MkAssetContactSheetGenerator.kt`
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/rendering/MkAssetThumbnailRenderer.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetProvenanceAuditTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetContactSheetTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetInstantiationTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetProvenanceTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkAssetThumbnailTests.kt`
- `android/mk-assets/src/test/kotlin/net/binjamshid/makhtoot/mk/assets/MkPremiumContentMarkingTests.kt`
- `android/docs/impl-log/BATCH-5.5b.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`,
`android/mk-assets/src/main/kotlin/.../browser/**`, `generators/**`, `library/**`, `model/**`
(5.5a's exclusive files), `TestSupport/MkFreeEntitlementStub.kt` (5.5a's exclusive test file).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Instantiation/MKAssetInstantiator.swift` | 112 | `instantiation/MkAssetInstantiator.kt` | `place(asset:) -> MkNode`. `MkPlacementRecord` → `data class`. |
| `Instantiation/MKPatternInstantiator.swift` | 90 | `instantiation/MkPatternInstantiator.kt` | Pattern-background instantiation; the Swift file documents a `:mk-model` schema gap it works around without adding a dependency edge — replicate the same documented workaround, do not silently "fix" the schema here (that is `:mk-model`'s call, out of this agent's fence). |
| `Instantiation/MKPremiumContentLedger.swift` | 63 | `instantiation/MkPremiumContentLedger.kt` | On placing any `isPremium` asset, the document gains a `premiumContent.assets` flag entry (removing the last premium asset clears it). The actual manifest field this feeds lives in `:mk-model` (out of this agent's fence, coordinate via `android/docs/CONTRACT_CHANGES.md` if the field doesn't already exist from Batch 2). |
| `Provenance/MKAssetProvenanceLibrary.swift` | 60 | `provenance/MkAssetProvenanceLibrary.kt` | One `MkAssetProvenance` record per asset in 5.5a's `MkAssetLibrary.standard`, DERIVED from each descriptor (never hand-maintained as a parallel list) — this is what makes "every manifest asset has provenance" true by construction; port the derivation, not a hand-copied list. |
| `Provenance/MKAssetProvenanceStore.swift` | 44 | `provenance/MkAssetProvenanceStore.kt` | Runtime lookup surface + `provenance-records.json` snapshot codec. |
| `Rendering/MKAssetContactSheetGenerator.swift` | 92 | `rendering/MkAssetContactSheetGenerator.kt` | Debug/QA visual contact-sheet tooling, consumed by tests only (not shipped app UI). **See Tasks 2 — this is the file behind the known-flaky iOS test; the Android port must write to per-test-run unique paths, never a shared fixed filename, to avoid reproducing the ordering dependence.** |
| `Rendering/MKAssetThumbnailRenderer.swift` | 158 | `rendering/MkAssetThumbnailRenderer.kt` | Deterministic thumbnail rasterizer: runtime render (via `:mk-render`'s `MkSnapshotRenderer` — consistent with the single-render-path invariant) + LRU cache, chosen over checked-in static art to avoid stale-art drift. `actor` → coroutine-`Mutex`-guarded cache class. |

**Tasks.**
1. Port `provenance/**` (library, store) first — depends on 5.5a's model types and
   (indirectly, by derivation) on 5.5a's generators via `MkAssetLibrary.standard`; implementing
   the derivation function against the documented generator API surface before 5.5a's
   generators are fully populated is fine since it's a pure function over `MkAssetDescriptor`
   values.
2. Port `instantiation/**` (instantiator, pattern instantiator, premium content ledger).
3. **Before porting `rendering/MkAssetContactSheetGenerator.kt` and its test, address the known
   iOS ordering-dependence bug directly**: on iOS, `MKAssetContactSheetTests` writes real PNG
   evidence to a path under `docs/impl-log/WS-14-contact-sheets/` and intermittently
   collides/loses a race only in FULL test-suite runs (passes reliably under `--filter`
   isolation), sometimes leaving a stale zero-byte temp file behind — this is a
   shared-fixed-path / test-ordering dependency, not a flaky assertion. The Kotlin port must
   NOT reproduce this: give every test run a unique temp/output path (e.g. a JUnit `@TempDir`
   or a UUID-suffixed filename under the Gradle build dir), and make no assumption about which
   other tests have or haven't run first. This is an explicit, testable acceptance item (Task 5
   below), not a suggestion. The Kotlin tests overall must be order-independent — this is the
   same discipline the spine asks of Batch 5 · Agent 5.5's contact-sheet-equivalent suite,
   because the iOS contact-sheet tests are flaky in full runs only.
4. Port `rendering/MkAssetThumbnailRenderer.kt`.
5. Port all six test files. Run the full `:mk-assets:testDebugUnitTest` suite at least twice in
   a row (not just once) before declaring this agent done, specifically to catch any
   reintroduced ordering dependence in the contact-sheet-equivalent tests — this is the direct
   Android-side verification of Task 3's fix.
6. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
   in this agent's Owns list above; name each superseded stub path in
   `android/docs/impl-log/BATCH-5.5b.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-assets:testDebugUnitTest` green **on two consecutive runs**, not just one
  (the explicit check for the ordering-dependence class of bug this packet calls out) — tests
  must be order-independent
- `./gradlew :mk-assets:lintDebug` green
- Requirements covered: `R-11.2`, `R-11.3`, `R-11.5`
- Tests ported: (this agent's six test files back R-11.2/R-11.3/R-11.5 acceptance directly;
  T-AST-1 remains 5.5a's per its own packet)
- Fixtures consumed: `android/fixtures/assets/**` — provenance/thumbnail goldens
- Every asset in 5.5a's `MkAssetLibrary.standard` has exactly one `MkAssetProvenance` record
  (T12-equivalent audit, derived-by-construction per the port map note)
- Contact-sheet-equivalent tests write to per-run-unique paths — verified by code inspection
  as an explicit acceptance item, not merely "tests are green"
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.5b.md`

---

### Batch 5 · Agent 5.6 — `mk-export` raster, SVG, presets, gate, free-tier budget, outlining

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Port the export coordinator (the single choke point every format routes
through), the entitlement/content gate, presets, request/result/fallback-note models, raster
encoding, tiled huge-raster export, the hand-rolled SVG serializer + text writer + provenance
helpers, per-license text outlining, and the supporting license/embedding-rights seams.
**Carries forward AUDIT finding FC-2 as a hard, explicit requirement**: on iOS, PNG/JPEG
export bypasses `MKExportGate`/`MKFreeTierBudget` entirely by calling the snapshot renderer
directly — the Android port must route **every** export format through `MkExportCoordinator`
from day one, with no equivalent shortcut ever introduced. **There is no `:mk-export` →
`:mk-store` dependency edge** (spine `§2` D-311's register entry, `§3.2`) — `MkExportGate`
reads entitlement state through the `MKEntitlementProviding` protocol living in `:mk-foundation`
(a dependency `:mk-export` already has), never through a direct `:mk-store` import. This is what
resolves the apparent Batch 5 (export) / Batch 6 (store) ordering inversion an earlier, wrong
dependency table implied: export never needed store to exist first.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKExport/ExportCoordinator.swift` | Port source — the single choke point (`actor`), P10-EARLY raster + P10-COMPLETION PDF/SVG dispatch |
| `MakhtootKit/Sources/MKExport/ExportGate.swift` | Port source — D-229 entitlement/content gating, enforced at engine level |
| `MakhtootKit/Sources/MKExport/ExportPresets.swift` | Port source — preset catalog, data not code |
| `MakhtootKit/Sources/MKExport/ExportRequest.swift` | Port source — `MKExportFormat`/`MKExportRequest` |
| `MakhtootKit/Sources/MKExport/ExportResult.swift` | Port source — `MKExportResult`/`MKExportError` |
| `MakhtootKit/Sources/MKExport/FreeTierBudget.swift` | Port source — 2 MP effective pixel budget, aspect-preserving clamp |
| `MakhtootKit/Sources/MKExport/RasterEncoders.swift` | Port source — JPEG/PNG encode with DPI metadata |
| `MakhtootKit/Sources/MKExport/TiledRasterExporter.swift` | Port source — the memory-safety core, D-210/D-223 static 64 MB strip sizing |
| `MakhtootKit/Sources/MKExport/SVGSerializer.swift` | Port source — hand-rolled, dependency-free XML writer |
| `MakhtootKit/Sources/MKExport/SVGTextWriter.swift` | Port source — Live Text → `<text>`, subset-embedding assessment |
| `MakhtootKit/Sources/MKExport/SVGProvenance.swift` | Port source — low-level XML/path-data helpers |
| `MakhtootKit/Sources/MKExport/TextOutlining.swift` | Port source — D-118/§16.5 per-license outline switch |
| `MakhtootKit/Sources/MKExport/MKFilenameSanitizer.swift` | Port source — Arabic-safe filename sanitizer |
| `MakhtootKit/Sources/MKExport/FallbackNote.swift` | Port source — the "never silent" carrier every result surfaces |
| `MakhtootKit/Sources/MKExport/MKOutlineSubstitutePainter.swift` | Port source — minimal glyph-outline paint routine |
| `MakhtootKit/Sources/MKExport/MKEmbeddingRestrictionWalker.swift` | Port source — finds nodes whose font lacks embedding rights for the target format |
| `MakhtootKit/Sources/MKExport/FontLicenseProviding.swift` | Port source — `FontLicenseProviding` + `AllOFLLicenseStub` |
| `MakhtootKit/Sources/MKExport/MKExportFontDataProviding.swift` | Port source — SVG `@font-face` raw-bytes seam |
| `MakhtootKit/Tests/MKExportTests/**` (17 of the 20 files — see port map) | Tests to port |
| `AUDIT_2026-07-28.md` FC-2 finding | **Read before writing `MkExportCoordinator.kt`** — the exact bypass bug (`exportForSharing()`/`exportPNGForSharing()` skip the gate on iOS) this Android port must never introduce |
| `AUDIT_2026-07-28.md` P-4 finding | Same root cause as FC-2 (raster export bypassing the tiled exporter) — the Android fix is the same: route through the coordinator, always |
| `FOUNDATION.md` §6 (D-117, D-118, D-119) | Export matrix, gating, color-pipeline contract (SVG/raster half; CMYK/PDF half is 5.7a/5.7b) |
| `android/mk-render/src/main/kotlin/.../MkSnapshotRenderer.kt`, `MkTileRenderer.kt`, `MkContentHash.kt` (Batch 4 output) | `MkTiledRasterExporter`/`MkExportCoordinator` render through these directly |
| `android/fixtures/export/**` (Batch 0) | Raster/SVG byte-goldens |

**Owns (creates or edits — no other agent may touch these).** Every path below supersedes the
identically-named Batch 1.4 contract stub at the same path (spine §3.3); delete/overwrite each
stub body as part of landing the real implementation (see Tasks, final item). All eighteen of
this agent's Kotlin targets are 1:1 mechanical transforms of their Swift source landing at
exactly the flat `mk-export/.../export/` path Batch 1 · Agent 1.4 already stubbed — no orphaned
stub paths outside this list. (This is unlike sibling agents 5.7a/5.7b, whose PDF writers move
into a new `pdf/` subdirectory that Batch 1's stubs did not anticipate — see those agents'
packets.)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportCoordinator.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportGate.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportPresets.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportRequest.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportResult.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFreeTierBudget.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkRasterEncoders.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkTiledRasterExporter.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgSerializer.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgTextWriter.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgProvenance.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkTextOutlining.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFilenameSanitizer.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFallbackNote.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkOutlineSubstitutePainter.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkEmbeddingRestrictionWalker.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFontLicenseProviding.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportFontDataProviding.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkExportCoordinatorProgressTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkExportCoordinatorTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkExportGateTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkExportPresetsTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkFallbackNoteTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkFlipSvgExportTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkFreeTierBudgetTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkFilenameSanitizerTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkOutlinedRtlMultiLineAlignmentTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkRasterEncodersTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgBackgroundImageTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgBoldItalicAndPathHighlightParityTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgRtlMultiLineAlignmentTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgSerializerTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgTextDecorationTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/Support/**` (shared test helper dir — 5.7a/5.7b's PDF tests read this, do not edit it)
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/MkTiledRasterExporterTests.kt`
- `android/docs/impl-log/BATCH-5.6.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`,
`android/mk-export/src/main/kotlin/.../pdf/**` (5.7a/5.7b's exclusive files), the corresponding
`pdf/MkPdf*Tests.kt` (5.7a/5.7b's exclusive test files). Also never touch the flat, non-`pdf/`
Batch 1.4 stub files `MkPdfVectorExporter.kt`, `MkPdfRasterExporter.kt`, `MkPdfOutputIntent.kt`,
`MkPdfPrintCmykExporter.kt` directly under `mk-export/.../export/` — despite sitting outside
`pdf/**`, these four are 5.7a's/5.7b's to delete (they are the orphaned pre-reorganization stub
paths for the four files 5.7a/5.7b re-home into `pdf/`), not this agent's.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `ExportCoordinator.swift` | 397 | `MkExportCoordinator.kt` | `actor` → coroutine-based class confined to a dedicated dispatcher (D-302). **This is where FC-2 is closed on Android**: every `MKExportFormat` case (jpeg, pngOpaque, pngAlpha, and — via 5.7a/5.7b's writers — svg/pdfRaster/pdfVectorRGB/pdfVectorCMYK) dispatches from THIS single function, taking `entitlement` as a required parameter with no bypass entry point anywhere in the module's public API. Do not add a second public export function that skips `ExportGate`/`FreeTierBudget` for "convenience" (e.g. a quick-share shortcut) — that is exactly the bug this agent exists to not reproduce. `MKExportHistoryRecording` protocol + `MKNoOpExportHistoryRecording` stub → `interface` + object; real conformer wires at the composition root (Batch 7). |
| `ExportGate.swift` | 180 | `MkExportGate.kt` | D-229: `(request, entitlementState, contentFlags) -> allowed | blocked(reason)`. `premiumContentPresent` iterates **ALL** nodes regardless of `isHidden`/`isLocked` — presence-based, not render-based (T-EXP-16). Free-tier preset-membership check enforced HERE at engine level, not only in UI (mirrors D-229(2)'s explicit instruction). |
| `ExportPresets.swift` | 124 | `MkExportPresets.kt` | `MkExportPreset`/`MkExportPresetCatalog` — presets are DATA (a `presets.json` resource), not hardcoded Kotlin — port the resource-driven design, not a hardcoded `when` table. `MkCustomDimensionValidator` for premium custom exact dimensions. |
| `ExportRequest.swift` | 183 | `MkExportRequest.kt` | `MKExportFormat` (jpeg(quality)/pngOpaque/pngAlpha/svg/pdfRaster/pdfVectorRGB/pdfVectorCMYK), `MKExportColorTarget`, `MKExportTarget`, `MKExportBackground`, `MKExportRequest` → sealed classes/`data class`/`@Serializable`. |
| `ExportResult.swift` | 57 | `MkExportResult.kt` | `url, pixelSize, format, fallbacksApplied: [FallbackNote], colorProvenance, duration` — `data class`. `MKExportError` → sealed exception class. |
| `FreeTierBudget.swift` | 31 | `MkFreeTierBudget.kt` | `effectivePixelBudget = 2_000_000`; aspect-preserving downscale to fit; actual size reported. Applied AT RENDER, never by post-hoc downscaling a larger render (R-13.2). |
| `RasterEncoders.swift` | 56 | `MkRasterEncoders.kt` | `ImageIO` destinations with DPI metadata → `Bitmap.compress` with `ExifInterface` DPI tag writing where the target format supports it (JPEG/PNG DPI metadata handling differs per Android encoder — verify what's actually settable and document any gap in the impl log rather than silently dropping the DPI metadata requirement, R-13.9's 300-DPI floor depends on this being readable by print tooling). JPEG quality 0.85 default; opaque PNG composites canvas background; alpha PNG renders clear background (premium only). |
| `TiledRasterExporter.swift` | 278 | `MkTiledRasterExporter.kt` | The memory-safety core. D-210/D-223: STATIC 64 MB strip sizing, never shrunk mid-export (T-MEM-6); stage-3/critical pressure PAUSES before the next strip (never aborts an in-flight strip) with a resumable cancel option. Uses Batch 4's `SnapshotRenderer`/`TileRenderer` directly — same tiling math, same `makeFlippedBitmapContext`-equivalent factory. "8192×8192 PNG export peaks < 300 MB resident" is this file's own explicit acceptance criterion on iOS — carry the same peak-memory ceiling forward as an Android acceptance criterion (T-EXP-5). |
| `SVGSerializer.swift` | 400 | `MkSvgSerializer.kt` | Hand-rolled, dependency-free XML writer (D-101/D-304's "no third-party XML library" carried to Android — no XML-building library dependency here either, plain `StringBuilder`/manual escaping). Live Text (OFL font) → `<text>` with `direction`/`unicode-bidi` + `@font-face` when license allows; Arranged/transformed glyphs → `<g><path>` with `data-mk-*` provenance attributes (R-13.6). |
| `SVGTextWriter.swift` | 238 | `MkSvgTextWriter.kt` | Live-text → `<text>`. The Swift file's own header documents a KNOWN LATENT gap: SVG cannot currently embed the font FILE for a resolved bold/italic cut because `MKExportFontDataProviding` is keyed by font ref and a resolved cut has no catalog entry (wired conformer is the no-op stub) — port this AS a documented, tracked gap (a comment + an `android/docs/CONTRACT_CHANGES.md` entry noting it mirrors the iOS `FIXME`), not as something silently fixed or silently reproduced without acknowledgment. |
| `SVGProvenance.swift` | 134 | `MkSvgProvenance.kt` | `SVGXML` (escaping/indent helpers), `SVGShapeGeometry` (path-data serialization) — low-level, no third-party deps. |
| `TextOutlining.swift` | 372 | `MkTextOutlining.kt` | D-118/§16.5 per-license text-vs-outline switch — extracts glyph-outline substitutes for non-embeddable fonts (feeds 5.6's own SVG path AND 5.7a's PDF outline path via `MkOutlineSubstitutePainter`). |
| `MKFilenameSanitizer.swift` | 36 | `MkFilenameSanitizer.kt` | Arabic-safe filename sanitization — default export filename = project name (R-13.15); test fixture «مشروعي الأول.png» ports directly. |
| `FallbackNote.swift` | 164 | `MkFallbackNote.kt` | `FallbackReason` (sealed/enum), `FallbackNote` — the "never silent" carrier (Q73/D-118) every `ExportResult` surfaces for any applied downscale/outline/rasterization. |
| `MKOutlineSubstitutePainter.swift` | 148 | `MkOutlineSubstitutePainter.kt` | Minimal fill(+stroke) paint routine for glyph-outline substitutes into a raster/PDF context — Android target here is `Canvas` (PDF-context painting is 5.7a's concern, but the shared paint routine lives in this agent per the spine's file list). |
| `MKEmbeddingRestrictionWalker.swift` | 104 | `MkEmbeddingRestrictionWalker.kt` | Finds every `.liveText`/`.pathText` node whose font lacks the target format's embedding right, computing each node's full world transform via the same closed-form chain `TiledRasterExporter` uses — replicate that closed-form transform computation exactly, do not import `:mk-canvas`/`:mk-render` transform utilities across the dependency fence to "share" it if the Swift original deliberately replicates instead of importing (verify against the actual Swift source before deciding; the header comment explains the choice). |
| `FontLicenseProviding.swift` | 80 | `MkFontLicenseProviding.kt` | `interface FontLicenseProviding` + `AllOflLicenseStub` (v1 stub: all-OFL) — real conformer fed by `:mk-fonts` metadata wires at the composition root (Batch 7). |
| `MKExportFontDataProviding.swift` | 32 | `MkExportFontDataProviding.kt` | `interface` + `MkNoFontDataProviding` no-op stub — SVG `@font-face` raw font-BYTES seam, distinct from `FontLicenseProviding` (rights vs. bytes). Real conformer wires `:mk-fonts`' registry at the composition root. |

**Tasks.**
1. **Read `AUDIT_2026-07-28.md`'s FC-2 and P-4 findings before writing `MkExportCoordinator.kt`**
   (spine's explicit instruction).
2. Port `MkExportResult.kt`, `MkExportRequest.kt`, `MkFallbackNote.kt`, `MkFilenameSanitizer.kt`,
   `MkFreeTierBudget.kt` first (small, dependency-free data types).
3. Port `MkExportGate.kt` — the D-229 gate. Write `MkExportGateTests.kt`'s hidden-premium-layer
   case (T-EXP-16 equivalent) before moving on; this is the presence-based-walk correctness
   backstop.
4. Port `MkExportPresets.kt` (resource-driven, not hardcoded).
5. Port `MkRasterEncoders.kt`, `MkTiledRasterExporter.kt` — the memory-safety core.
6. Port `MkTextOutlining.kt`, `MkOutlineSubstitutePainter.kt`, `MkEmbeddingRestrictionWalker.kt`,
   `MkFontLicenseProviding.kt`, `MkExportFontDataProviding.kt` (the licensing/outlining seam
   cluster).
7. Port `MkSvgProvenance.kt`, `MkSvgTextWriter.kt`, `MkSvgSerializer.kt` — document the known SVG
   bold/italic font-embedding gap explicitly (see port map note) rather than silently fixing or
   silently reproducing it without acknowledgment.
8. Port `MkExportCoordinator.kt` LAST, once every writer/gate/budget piece it dispatches to
   exists. **Write the explicit "every format routes through this coordinator, no bypass"
   test (the FC-2 regression guard) as this agent's first test in the coordinator's own test
   file** — verify by code inspection AND by attempting (in a test) to construct any export
   path that skips `ExportGate`/`FreeTierBudget`, asserting no such path exists in the public
   API.
9. Port all 15 test files (this agent's list above, excluding the 3 PDF-specific files and
   the `PDFOutputIntent` test which don't apply here).
10. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs at every path
    in this agent's Owns list above; name each superseded stub path in
    `android/docs/impl-log/BATCH-5.6.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-export:testDebugUnitTest` green
- `./gradlew :mk-export:lintDebug` green
- Requirements covered: `R-13.1`–`R-13.8`, `R-13.12`, `R-13.13`, `R-13.15`
- Tests ported: `T-EXP-1`, `T-EXP-2`, `T-EXP-3`, `T-EXP-4`, `T-EXP-5`, `T-EXP-6`, `T-EXP-7`,
  `T-EXP-10`, `T-EXP-11`, `T-EXP-15`, `T-EXP-16`
- Fixtures consumed: `android/fixtures/export/**` — raster/SVG byte-goldens
- **FC-2 explicit acceptance test**: every `MkExportFormat` this agent's coordinator handles
  (jpeg, pngOpaque, pngAlpha) requires an `entitlement` parameter and runs through
  `MkExportGate`+`MkFreeTierBudget`; a test asserts no alternate public entry point renders
  raster output without going through `MkExportCoordinator`
- 8192×8192 tiled PNG export peak memory stays under the same 300 MB-class ceiling the iOS
  acceptance criterion states (T-EXP-5), verified on the JVM unit-test harness's available
  memory-tracking mechanism
- Hidden premium content still blocks export (T-EXP-16, presence-based walk) — explicit test
- `MkExportGate`'s entitlement lookup goes through `MKEntitlementProviding` (`:mk-foundation`)
  only — code inspection confirms no `:mk-store` import anywhere in `:mk-export`
- Stub count for every file in this agent's port map reaches 0

**Impl log.** `android/docs/impl-log/BATCH-5.6.md`

---

### Batch 5 · Agent 5.7a — `mk-export` PDF core writer

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Build the low-level PDF 1.7 writer primitives — object model, xref/trailer, content
stream operator serialization, raster image XObjects — and the two writers that need only those
primitives: the vector/shape PDF writer (paths, shapes, arranged/path-text as vector operators)
and the free-tier rasterized-PDF page-wrapper. This is an in-house PDF writer per **D-314**,
since `android.graphics.pdf.PdfDocument` supports none of CMYK, output intents, or controlled
font embedding — there is no `PdfDocument` equivalent to lean on, only the PDF 1.7 spec itself.
**The original single-agent 5.7 packet owned 328 Swift LOC expanding to an estimated ~5,000
Kotlin LOC with no 1:1 Swift source to port from — a 15× expansion, not one unit of work**, which
is why it is now split by PDF-writer layer rather than by Swift file: this agent (5.7a) owns the
generic writer plumbing plus the two writers with no font-embedding-rights complexity; sibling
agent 5.7b owns everything about font subsetting, Type0/CIDFontType2 embedding, CMYK, and
OutputIntent/ICC. 5.7a's `MkPdfVectorExporter` calls into 5.7b's font-embedding conformer through
a seam this agent defines — the same "protocol here, real conformer there" pattern Batch 4 ·
Agent 4.1/4.3 already established for `MkPathPlacementProviding`.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKExport/PDFVectorExporter.swift` | Port source — vector paths + live-text runs via a CG PDF context, subset-embedding (this agent ports the path/shape half; the font-embedding half is delegated to 5.7b through this agent's own seam) |
| `MakhtootKit/Sources/MKExport/PDFRasterExporter.swift` | Port source — free-tier rasterized PDF, single-page wrapper around an already-rendered raster |
| `MakhtootKit/Tests/MKExportTests/PDFVectorExporterTests.swift`, `PDFRasterExporterTests.swift` | Tests to port |
| `android/mk-export/src/main/kotlin/.../MkTiledRasterExporter.kt` (5.6's port target, same batch) | `MkPdfRasterExporter` wraps an already-tiled/assembled `Bitmap` from this — code against the documented shape, do not wait on 5.6 finishing |
| `android/mk-export/src/test/kotlin/.../Support/**` (5.6's owned dir, same batch) | Shared test helper this agent's PDF tests import — read only |
| `D-314` (Batch 0 §0.5 output) | The in-house-PDF-writer decision itself and its stated rejection rationale for `PdfDocument` |
| `TEST_MATRIX.md` §7.12/§11 (T-AR-52, T-AR-56, T-EXP-8) | Page/MediaBox and vector-operator exact numeric contract |
| `android/fixtures/export/**` (Batch 0) | PDF byte-goldens (vector, raster) |
| `:mk-native`'s `hb-subset` JNI facade (Batch 1 output, D-304) | Not called directly by this agent, but `MkPdfVectorExporter`'s live-text path depends on 5.7b's subsetting output through the seam — named here so the dependency is visible |

**Owns (creates or edits — no other agent may touch these).** Five of the seven `main/`
targets below (`MkPdfObjectModel.kt`, `MkPdfXrefWriter.kt`, `MkPdfContentStreamWriter.kt`,
`MkPdfImageXObjectWriter.kt`, `MkPdfFontEmbeddingProviding.kt`) have no Swift source and
therefore no Batch 1 stub to supersede — they are new. The other two
(`pdf/MkPdfRasterExporter.kt`, `pdf/MkPdfVectorExporter.kt`) DO have Swift sources
(`PDFRasterExporter.swift`, `PDFVectorExporter.swift`), but **Batch 1 · Agent 1.4 stubbed them
at a different, flat path** — `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/
MkPdfRasterExporter.kt`/`MkPdfVectorExporter.kt`, with no `pdf/` subdirectory, because the Swift
files live directly under `Sources/MKExport/` with no PDF-specific subdirectory to mirror. This
agent's own port map deliberately reorganizes the PDF writer into a new `pdf/` subdirectory, so
those two flat Batch 1 stub paths are **orphans that nothing else in the plan deletes** unless
named here. Both flat stub paths are therefore added to this agent's Owns list below,
specifically so this agent deletes them (see Tasks, final item) — this agent's real
implementations live at the `pdf/`-prefixed paths, and the flat paths must end up containing
nothing (deleted), not a second copy.
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfObjectModel.kt` (new — indirect objects, dictionaries, arrays, name objects, streams; no Swift source, D-314's "in-house writer" starting point)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfXrefWriter.kt` (new — xref table + trailer)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfContentStreamWriter.kt` (new — content-stream operator serialization: `m`/`l`/`c`/`re`/`f`/`S`/`W n`/`q`/`Q`/`cm`/`g`/`rg`/`k`/`K` etc.; 5.7b's CMYK writer reads this, does not edit it)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfImageXObjectWriter.kt` (new — raster image XObject embedding)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfFontEmbeddingProviding.kt` (new — the seam interface `MkPdfVectorExporter` calls for live-text font embedding; 5.7b provides the real conformer, same pattern as `MkPathPlacementProviding` in Batch 4)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfVectorExporter.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfRasterExporter.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfVectorExporter.kt` (**orphaned Batch 1.4 stub** at the flat pre-reorganization path — `PDFVectorExporter.swift` → this exact path per Batch 1 · Agent 1.4's port map; delete it, do not leave it compiling alongside the real `pdf/MkPdfVectorExporter.kt`)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfRasterExporter.kt` (**orphaned Batch 1.4 stub** at the flat pre-reorganization path — `PDFRasterExporter.swift` → this exact path per Batch 1 · Agent 1.4's port map; delete it, do not leave it compiling alongside the real `pdf/MkPdfRasterExporter.kt`)
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfObjectModelTests.kt` (new coverage — no Swift twin, register as `T-AND-*` per spine §5.3/§16)
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfContentStreamWriterTests.kt` (new coverage — `T-AND-*`)
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfVectorExporterTests.kt`
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfRasterExporterTests.kt`
- `android/docs/impl-log/BATCH-5.7a.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`, every
`android/mk-export/src/main/kotlin/.../MkExportCoordinator.kt` and the rest of 5.6's exclusive
files, `android/mk-export/src/main/kotlin/.../pdf/MkPdfFontSubsetter.kt`,
`MkPdfType0FontEmbedder.kt`, `MkPdfOutputIntent.kt`, `MkPdfPrintCmykExporter.kt` (5.7b's
exclusive files — see this file's ownership matrix appendix).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| *(no Swift source — new)* | — | `pdf/MkPdfObjectModel.kt`, `pdf/MkPdfXrefWriter.kt` | The PDF 1.7 object model (indirect objects, dicts, arrays, streams) and cross-reference table/trailer. Core Graphics gives iOS this for free via its PDF context; Android has no equivalent, so this is genuinely new code, not a port — the reason D-314 flagged the whole PDF writer as the hardest new-code surface in the plan. |
| `PDFRasterExporter.swift` | 36 | `pdf/MkPdfRasterExporter.kt` | Free-tier rasterized PDF: single-page wrapper around an already-tiled/assembled `Bitmap` (from 5.6's `MkTiledRasterExporter`) at preset pt size, via `MkPdfImageXObjectWriter`. Never re-renders — this file's only job is the page-wrapping. Correct page size; no text objects present (T-AR-52's exact acceptance). |
| `PDFVectorExporter.swift` | 81 | `pdf/MkPdfVectorExporter.kt` | Shapes/arranged/path-text as vector path operators via `MkPdfContentStreamWriter`; live text drawn as actual glyph-run operators dispatched through `MkPdfFontEmbeddingProviding` (5.7b's real conformer supplies the Type0/CIDFontType2 program built from `:mk-native`'s `hb-subset` output). License switch: non-embeddable fonts → outlines (via 5.6's `MkTextOutlining`/`MkOutlineSubstitutePainter`) + PDF `/DeviceRGB`; embeddable OFL fonts → live text objects with the subset font embedded through the seam. |
| *(no Swift source — new)* | — | `pdf/MkPdfImageXObjectWriter.kt`, `pdf/MkPdfFontEmbeddingProviding.kt` | XObject (`/Subtype /Image`) embedding for raster tiles, and the font-embedding seam interface. Estimated Kotlin LOC for this agent's whole scope: **~2,800** of the PDF writer's overall ~5,000-LOC estimate (5.7b carries the remaining ~2,200) — both figures are estimates to validate during implementation, not commitments, exactly as the original single-agent packet's ~5,000 figure was. |

**Tasks.**
1. **Before writing any PDF bytes, specify the exact feature set this agent's writers target**
   (spine's explicit requirement) and record it at the top of `android/docs/impl-log/
   BATCH-5.7a.md`: PDF 1.7; content streams with vector path operators (`m`/`l`/`c`/`re`/`f`/
   `S`/`W n` etc.); XObjects (`/Subtype /Image`) for raster tiles; a 300 DPI raster-asset floor
   (R-13.9/T-AR-57). Font embedding, CIDToGIDMap and CMYK operators are 5.7b's feature-set
   statement, not this agent's — do not restate or second-guess them here.
2. Port `pdf/MkPdfObjectModel.kt` and `pdf/MkPdfXrefWriter.kt` first — every other file in this
   agent (and 5.7b's writers) builds on them. Publish their shape early since 5.7b codes against
   them concurrently.
3. Port `pdf/MkPdfContentStreamWriter.kt` (the `k`/`K` CMYK operators live here even though only
   5.7b's writer emits them — this agent owns the generic operator serializer per the "core
   writer" split) and `pdf/MkPdfImageXObjectWriter.kt`.
4. Define `pdf/MkPdfFontEmbeddingProviding.kt` — the seam `MkPdfVectorExporter` calls for live
   text. Publish its shape early so 5.7b can build the real conformer concurrently rather than
   sequentially.
5. Port `pdf/MkPdfRasterExporter.kt` (simplest — a page-wrapper, no font-embedding dependency).
6. Port `pdf/MkPdfVectorExporter.kt` against the documented `MkPdfFontEmbeddingProviding` shape
   — do not block on 5.7b's real conformer landing first; a stub conformer is enough to keep
   this agent's own tests green, with the real conformer wired at the composition root (Batch 7)
   same as the module's other seams.
7. Port all four test files (two ported, two new object-model/content-stream unit suites) as
   BYTE-GOLDEN tests against `android/fixtures/export/**`'s PDF goldens where a golden exists.
8. Register the two new test files' ids as `T-AND-*` in `TEST_MATRIX.md` per spine §5.3/§16.
9. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs this agent's
   real implementations supersede. For `MkPdfObjectModel.kt`/`MkPdfXrefWriter.kt`/
   `MkPdfContentStreamWriter.kt`/`MkPdfImageXObjectWriter.kt`/`MkPdfFontEmbeddingProviding.kt`
   there is no Batch 1 stub to delete (no Swift source, so Batch 1 never stubbed them) —
   record that explicitly, do not silently skip it. For `pdf/MkPdfVectorExporter.kt` and
   `pdf/MkPdfRasterExporter.kt`, the Batch 1 · Agent 1.4 stub sits at a DIFFERENT, flat path
   (`MkPdfVectorExporter.kt`/`MkPdfRasterExporter.kt` directly under `mk-export/.../export/`,
   no `pdf/` subdirectory) because this agent's `pdf/` reorganization has no Swift-side
   directory to mirror — delete both flat stub files as part of this task, not merely
   overwrite-in-place, since the real implementation now lives at a different path entirely.
   Name every superseded stub path (including both flat orphans) in
   `android/docs/impl-log/BATCH-5.7a.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-export:testDebugUnitTest` green
- `./gradlew :mk-export:lintDebug` green
- Requirements covered: `R-13.9` (raster-floor half)
- Tests ported: `T-EXP-8`
- Fixtures consumed: `android/fixtures/export/**` — PDF byte-goldens (vector, raster)
- `MkPdfVectorExporter`'s vector/shape path produces byte-identical structural output (object
  tree, content-stream operators) to the golden for at least one non-text fixture, independent
  of whether 5.7b's font-embedding conformer is real or stubbed
- `MkPdfRasterExporter` never re-renders — code inspection confirms it only wraps an existing
  `Bitmap`
- Stub count for every file in this agent's port map reaches 0, including the two orphaned flat
  Batch 1.4 stubs (`mk-export/.../export/MkPdfVectorExporter.kt`,
  `mk-export/.../export/MkPdfRasterExporter.kt`) — `bash Scripts/android/stub-count.sh` finds no
  `MkNotYetPorted` throw at either flat path after this agent is done, and neither file exists
  on disk any longer (deleted, not left as dead code)

**Impl log.** `android/docs/impl-log/BATCH-5.7a.md`

---

### Batch 5 · Agent 5.7b — `mk-export` PDF font subsetting, CMYK, OutputIntent

**Depends on:** G4 · **Parallel-safe with:** every other Batch 5 agent

**Mission.** Build the font-subsetting/Type0/CIDFontType2-embedding conformer for 5.7a's PDF
font-embedding seam, the premium print CMYK writer, and the OutputIntent/ICC builder — the half
of the original single-agent 5.7 packet concerned with font-embedding rights and color, as
opposed to 5.7a's generic writer plumbing. **CIDToGIDMap correctness is this agent's central
risk**: get it wrong and glyph ids silently resolve to the wrong glyph in the exported PDF — a
shaping-correctness failure by another name (CLAUDE.md "Never"), even though it happens after
`:mk-textengine`'s shaping is already correct.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKExport/PDFPrintCMYKExporter.swift` | Port source — premium print CMYK PDF |
| `MakhtootKit/Sources/MKExport/PDFOutputIntent.swift` | Port source — the `aux` dictionary / OutputIntent builder, D-226 spike-verified shape |
| `MakhtootKit/Tests/MKExportTests/PDFPrintCMYKExporterTests.swift` | Tests to port |
| `android/mk-export/src/main/kotlin/.../pdf/MkPdfObjectModel.kt`, `MkPdfXrefWriter.kt`, `MkPdfContentStreamWriter.kt`, `MkPdfFontEmbeddingProviding.kt` (5.7a's port targets, same batch) | This agent's CMYK writer and font-embedding conformer build directly on these — code against the documented shapes in `android/API_SURFACE.md`, do not wait on 5.7a finishing |
| `android/mk-export/src/main/kotlin/.../MkTextOutlining.kt`, `MkOutlineSubstitutePainter.kt`, `MkEmbeddingRestrictionWalker.kt`, `MkExportFontDataProviding.kt` (5.6's port targets, same batch) | The license-switch outline path and font-byte embedding seam this agent's subsetting conformer wires against — code against the documented shape, do not wait on 5.6 finishing |
| `android/mk-export/src/test/kotlin/.../Support/**` (5.6's owned dir, same batch) | Shared test helper this agent's PDF tests import — read only |
| `FOUNDATION.md` §6 (D-117), `D-315` (Batch 0 §0.5 output) | Color-pipeline / CMYK contract, lcms2-via-NDK substitution for `CGColorSpace(iccData:)` |
| `FDA-03` (spine §1) | CMYK ICC profile: lcms2 synthetic generic CMYK default for Android (Apple Generic CMYK is NOT redistributable in an APK — do not copy it); upgrade seam marked `VERIFY-AT-SUBMISSION` |
| `TEST_MATRIX.md` §7.12/§11 (T-AR-56, T-EXP-9, T-EXP-13, T-EXP-14) | CMYK/OutputIntent/subset-embedding exact numeric contract |
| `android/fixtures/export/**` (Batch 0) | PDF byte-goldens (CMYK) |
| `:mk-native`'s `hb-subset` JNI facade (Batch 1 output, D-304) | Font subsetting for Type0/CIDFontType2 embedding |
| `:mk-color`'s lcms2 binding (Batch 2 · Agent 2.3 output) | sRGB→CMYK conversion this writer's CMYK path calls into |

**Owns (creates or edits — no other agent may touch these).** Two of the four `main/` targets
below (`MkPdfFontSubsetter.kt`, `MkPdfType0FontEmbedder.kt`) have no Swift source and therefore
no Batch 1 stub to supersede — they are new. The other two (`pdf/MkPdfOutputIntent.kt`,
`pdf/MkPdfPrintCmykExporter.kt`) DO have Swift sources (`PDFOutputIntent.swift`,
`PDFPrintCMYKExporter.swift`), but **Batch 1 · Agent 1.4 stubbed them at a different, flat
path** — `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/
MkPdfOutputIntent.kt`/`MkPdfPrintCmykExporter.kt`, with no `pdf/` subdirectory, because the
Swift files live directly under `Sources/MKExport/` with no PDF-specific subdirectory to mirror.
This agent's own port map (matching sibling 5.7a's) deliberately reorganizes the PDF writer into
a new `pdf/` subdirectory, so those two flat Batch 1 stub paths are **orphans that nothing else
in the plan deletes** unless named here. Both flat stub paths are therefore added to this
agent's Owns list below, specifically so this agent deletes them (see Tasks, final item).
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfFontSubsetter.kt` (new — wraps `:mk-native`'s `hb-subset` JNI facade)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfType0FontEmbedder.kt` (new — Type0/CIDFontType2 dictionary construction + `CIDToGIDMap`; the real conformer of 5.7a's `MkPdfFontEmbeddingProviding`)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfOutputIntent.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfPrintCmykExporter.kt`
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfOutputIntent.kt` (**orphaned Batch 1.4 stub** at the flat pre-reorganization path — `PDFOutputIntent.swift` → this exact path per Batch 1 · Agent 1.4's port map; delete it, do not leave it compiling alongside the real `pdf/MkPdfOutputIntent.kt`)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfPrintCmykExporter.kt` (**orphaned Batch 1.4 stub** at the flat pre-reorganization path — `PDFPrintCMYKExporter.swift` → this exact path per Batch 1 · Agent 1.4's port map; delete it, do not leave it compiling alongside the real `pdf/MkPdfPrintCmykExporter.kt`)
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfType0FontEmbedderTests.kt` (new coverage — no Swift twin, register as `T-AND-*`)
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfOutputIntentTests.kt` (new coverage — `T-AND-*`; the Swift side has no dedicated `PDFOutputIntentTests.swift`, OutputIntent is exercised only inside `PDFPrintCMYKExporterTests.swift` on iOS)
- `android/mk-export/src/test/kotlin/net/binjamshid/makhtoot/mk/export/pdf/MkPdfPrintCmykExporterTests.kt`
- `android/docs/impl-log/BATCH-5.7b.md`

**Never touch.** `MakhtootKit/**` (read-only), any other module under `android/**`, every
`android/mk-export/src/main/kotlin/.../MkExportCoordinator.kt` and the rest of 5.6's exclusive
files, `android/mk-export/src/main/kotlin/.../pdf/MkPdfObjectModel.kt`, `MkPdfXrefWriter.kt`,
`MkPdfContentStreamWriter.kt`, `MkPdfImageXObjectWriter.kt`, `MkPdfFontEmbeddingProviding.kt`
(the interface — this agent implements it, never edits it), `MkPdfVectorExporter.kt`,
`MkPdfRasterExporter.kt` (5.7a's exclusive files — see this file's ownership matrix appendix).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `PDFOutputIntent.swift` | 92 | `pdf/MkPdfOutputIntent.kt` | Builds the OutputIntent auxiliary dictionary using the D-226 spike-verified shape. Android target: `/OutputIntent` dictionary with `/S /GTS_PDFX` (or the documented non-X variant the iOS shape uses — match exactly), `/OutputConditionIdentifier`, `/DestOutputProfile` an ICCBased stream embedding the FDA-03 profile bytes (lcms2 synthetic generic CMYK — NOT Apple Generic CMYK, which is not redistributable in an APK). Port the exact dictionary keys/structure the D-226 spike verified, not a re-derived approximation. Built on 5.7a's `MkPdfObjectModel`. |
| `PDFPrintCMYKExporter.swift` | 119 | `pdf/MkPdfPrintCmykExporter.kt` | Premium print CMYK PDF, built on 5.7a's `MkPdfContentStreamWriter` (`k`/`K` operators) and this agent's own `MkPdfOutputIntent`/`MkPdfType0FontEmbedder`. Both D-226 spikes (referenced by the Swift header as resolved) must be re-verified against `:mk-color`'s Android lcms2 binding before this writer is considered correct — do not assume the iOS spike verdicts transfer byte-for-byte to a different ICC engine (Core Graphics `CGColorSpace(iccData:)` vs. lcms2 via NDK); re-run the equivalent numeric verification this agent's own tests require (T-EXP-9/T-EXP-13/T-EXP-14 style checks) against the Android CMYK path specifically. |
| *(no Swift source — new)* | — | `pdf/MkPdfFontSubsetter.kt`, `pdf/MkPdfType0FontEmbedder.kt` | Font subsetting via `:mk-native`'s `hb-subset` and Type0/CIDFontType2 dictionary construction with a CORRECT `CIDToGIDMap` — on iOS this is handled inside Core Graphics' PDF context's own font-embedding machinery, which has no Android equivalent, so this is genuinely new code. Get the `CIDToGIDMap` wrong and glyph ids silently resolve to the wrong glyph. Estimated Kotlin LOC for this agent's whole scope: **~2,200** of the PDF writer's overall ~5,000-LOC estimate (5.7a carries the remaining ~2,800) — both figures are estimates to validate during implementation. |

**Tasks.**
1. **Before writing any PDF bytes, specify the exact feature set this agent's writers target**
   (spine's explicit requirement) and record it at the top of `android/docs/impl-log/
   BATCH-5.7b.md`: Type0/CIDFontType2 font embedding of `hb-subset` output with a CORRECT
   `CIDToGIDMap`; `/DeviceCMYK` color operators (`k`/`K`); an `/OutputIntent` with the FDA-03
   ICC profile embedded as an ICCBased stream.
2. Port `pdf/MkPdfOutputIntent.kt` first, against 5.7a's documented `MkPdfObjectModel` shape —
   do not block on 5.7a finishing.
3. Port `pdf/MkPdfFontSubsetter.kt` and `pdf/MkPdfType0FontEmbedder.kt` — this is where the
   CIDToGIDMap / Type0 font-embedding correctness work concentrates. Build and verify the
   font-embedding path against a SINGLE simple fixture (a short Latin or simple-joining Arabic
   string) before attempting the full T-AR-56-class fixture with mixed shapes/arranged
   text/CMYK. `MkPdfType0FontEmbedder` is the real conformer of 5.7a's `MkPdfFontEmbeddingProviding`
   — wire it against 5.7a's documented interface shape, not a redesigned one.
4. Port `pdf/MkPdfPrintCmykExporter.kt` — re-verify the D-226 spike math against `:mk-color`'s
   Android lcms2 binding specifically (see port-map note); do not assume the iOS numeric
   verdicts transfer to a different ICC engine without checking.
5. Port `MkPdfPrintCmykExporterTests.kt` as a BYTE-GOLDEN test against `android/fixtures/
   export/**`'s CMYK PDF goldens (T-EXP-9-class CMYK tolerance ±1%, matching the iOS contract),
   plus the two new `MkPdfType0FontEmbedderTests.kt`/`MkPdfOutputIntentTests.kt` suites.
6. Register the two new test files' ids as `T-AND-*` in `TEST_MATRIX.md` per spine §5.3/§16.
7. **Structural validation only — no external-viewer step.** Per spine `§6` G5, "opens correctly
   in Adobe Acrobat and macOS Preview" is a **founder gate task performed by hand between
   batches**, not something a headless agent can do or should log as having verified. This
   agent's own acceptance bar is structural: object tree well-formedness, embedded font-subset
   integrity, and OutputIntent presence, checked programmatically against the produced PDF
   bytes — not opened in any external application by this agent.
8. **Batch 1 stub supersession.** Delete/overwrite the Batch 1.4 contract stubs this agent's
   real implementations supersede. For `MkPdfFontSubsetter.kt`/`MkPdfType0FontEmbedder.kt`
   there is no Batch 1 stub to delete (no Swift source, so Batch 1 never stubbed them) —
   record that explicitly, do not silently skip it. For `pdf/MkPdfOutputIntent.kt` and
   `pdf/MkPdfPrintCmykExporter.kt`, the Batch 1 · Agent 1.4 stub sits at a DIFFERENT, flat path
   (`MkPdfOutputIntent.kt`/`MkPdfPrintCmykExporter.kt` directly under `mk-export/.../export/`,
   no `pdf/` subdirectory) because this agent's `pdf/` reorganization (matching 5.7a's) has no
   Swift-side directory to mirror — delete both flat stub files as part of this task, not
   merely overwrite-in-place, since the real implementation now lives at a different path
   entirely. Name every superseded stub path (including both flat orphans) in
   `android/docs/impl-log/BATCH-5.7b.md` per spine §3.3.

**Acceptance.**
- `./gradlew :mk-export:testDebugUnitTest` green
- `./gradlew :mk-export:lintDebug` green
- Requirements covered: `R-13.10`, `R-13.11`
- Tests ported: `T-EXP-9`, `T-EXP-13`, `T-EXP-14`
- Fixtures consumed: `android/fixtures/export/**` — PDF byte-goldens (CMYK)
- CMYK conversion matches the checked-in external-tool-derived reference values within ±1%
  tolerance (T-EXP-9's exact contract), verified against the Android lcms2 path specifically
  (not assumed from the iOS CoreGraphics path)
- CIDToGIDMap correctness verified — extracted text/glyph ids from a produced PDF round-trip
  to the correct codepoints for at least one Arabic joining-context fixture
- OutputIntent embeds the FDA-03 lcms2 synthetic generic CMYK profile bytes, never Apple
  Generic CMYK (explicit redistribution-legality check, not merely a functional one)
- **Structural validation, programmatic and agent-run**: object tree well-formedness, embedded
  subset integrity, and OutputIntent-dictionary presence are asserted by test/tooling in this
  agent's own suite — the external-viewer open-in-Acrobat/Preview check is explicitly **not**
  part of this agent's acceptance bar; it is a founder gate task recorded at G5 (spine `§6`/`§7`),
  and this packet must not claim to have performed it
- Stub count for every file in this agent's port map reaches 0, including the two orphaned flat
  Batch 1.4 stubs (`mk-export/.../export/MkPdfOutputIntent.kt`,
  `mk-export/.../export/MkPdfPrintCmykExporter.kt`) — `bash Scripts/android/stub-count.sh` finds
  no `MkNotYetPorted` throw at either flat path after this agent is done, and neither file
  exists on disk any longer (deleted, not left as dead code)

**Impl log.** `android/docs/impl-log/BATCH-5.7b.md`

---

## Appendix — file-ownership matrix (collision proof)

| Path prefix | 5.1 | 5.2a | 5.2b | 5.3 | 5.4a | 5.4b | 5.5a | 5.5b | 5.6 | 5.7a | 5.7b |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `android/mk-canvas/src/main/kotlin/.../MkCanvasViewController.kt` | ✅ | | | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkCanvasSession.kt` | ✅ | | | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkCanvasMode.kt` | ✅ | | | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkCanvasContentAPI.kt` | ✅ | | | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkCheckerboardPattern.kt` | ✅ | | | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkGridLines.kt` | ✅ | | | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../geometry/MkCanvasGeometrySource.kt` | ✅ | | | | | | | | | | |
| `android/mk-canvas/src/test/kotlin/.../{MkCanvasContentAPI,MkCanvasSession,MkCanvasViewControllerViewportCallback,MkCanvasHaptics,MkFlipScene,MkFlipSession}Tests.kt` + `MkCanvasTestSupport.kt` | ✅ | | | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../gestures/{MkGestureCoordinator,MkHandleGestures,MkMarqueeController,MkMoveGesture}.kt` | | ✅ | | | | | | | | | |
| `android/mk-canvas/src/test/kotlin/.../{MkGestureUndoCoalescing,MkHandleGeometryRegression,MkMarqueeController}Tests.kt` | | ✅ | | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkSnapEngine.kt` | | | ✅ | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkGuideRenderer.kt` | | | ✅ | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../geometry/{MkAnchoredResize,MkGroupTransform,MkOrientedRect}.kt` | | | ✅ | | | | | | | | |
| `android/mk-canvas/src/test/kotlin/.../{MkSnapEngine,MkGeometryMath}Tests.kt` | | | ✅ | | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkSelectionState.kt` | | | | ✅ | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkSelectionChromeLayer.kt` | | | | ✅ | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkHitTestPolicy.kt` | | | | ✅ | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkLayersModel.kt` | | | | ✅ | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkInspectorModel.kt` | | | | ✅ | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkEditingOperations.kt` | | | | ✅ | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkKeyCommands.kt` | | | | ✅ | | | | | | | |
| `android/mk-canvas/src/test/kotlin/.../{MkHitTestPolicy,MkInspectorModel,MkLayersModel,MkMergeDesignSession}Tests.kt` | | | | ✅ | | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../MkTextEditingOverlay.kt` | | | | | ✅ | | | | | | |
| `android/mk-canvas/src/test/kotlin/.../MkTextEditingOverlayTests.kt` | | | | | ✅ | | | | | | |
| `android/mk-canvas/src/main/kotlin/.../arrange/**` | | | | | | ✅ | | | | | |
| `android/mk-canvas/src/main/kotlin/.../pathtext/**` | | | | | | ✅ | | | | | |
| `android/mk-canvas/src/test/kotlin/.../{MkArrangeInteractionModel,MkArrangeInteractionTestSupport,MkPathTextInteractionModel,MkPathTextInteractionTestSupport}Tests.kt` | | | | | | ✅ | | | | | |
| `android/mk-assets/src/main/kotlin/.../{browser,generators,library,model}/**` (17 files) | | | | | | | ✅ | | | | |
| `android/mk-assets/src/test/kotlin/.../{MkAssetBrowserModel,MkAssetDescriptor,MkAssetManifestResource,MkAssetNamingLint,MkBasicShapes,MkCalligraphic,MkFrames,MkOrnaments,MkPatternBackground,MkUserDefaultsAssetMetadataStore}Tests.kt` + `TestSupport/MkFreeEntitlementStub.kt` | | | | | | | ✅ | | | | |
| `android/mk-assets/src/main/kotlin/.../{instantiation,provenance,rendering}/**` (7 files) | | | | | | | | ✅ | | | |
| `android/mk-assets/src/test/kotlin/.../{MkAssetProvenanceAudit,MkAssetContactSheet,MkAssetInstantiation,MkAssetProvenance,MkAssetThumbnail,MkPremiumContentMarking}Tests.kt` | | | | | | | | ✅ | | | |
| `android/mk-export/src/main/kotlin/.../MkExportCoordinator.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkExportGate.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkExportPresets.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkExportRequest.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkExportResult.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkFreeTierBudget.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkRasterEncoders.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkTiledRasterExporter.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../Mk{Svg}{Serializer,TextWriter,Provenance}.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkTextOutlining.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkFilenameSanitizer.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkFallbackNote.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkOutlineSubstitutePainter.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkEmbeddingRestrictionWalker.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkFontLicenseProviding.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../MkExportFontDataProviding.kt` | | | | | | | | | ✅ | | |
| `android/mk-export/src/test/kotlin/.../{MkExportCoordinatorProgress,MkExportCoordinator,MkExportGate,MkExportPresets,MkFallbackNote,MkFlipSvgExport,MkFreeTierBudget,MkFilenameSanitizer,MkOutlinedRtlMultiLineAlignment,MkRasterEncoders,MkSvgBackgroundImage,MkSvgBoldItalicAndPathHighlightParity,MkSvgRtlMultiLineAlignment,MkSvgSerializer,MkSvgTextDecoration,MkTiledRasterExporter}Tests.kt` + `Support/**` | | | | | | | | | ✅ | | |
| `android/mk-export/src/main/kotlin/.../pdf/{MkPdfObjectModel,MkPdfXrefWriter,MkPdfContentStreamWriter,MkPdfImageXObjectWriter,MkPdfFontEmbeddingProviding,MkPdfVectorExporter,MkPdfRasterExporter}.kt` | | | | | | | | | | ✅ | |
| `android/mk-export/src/main/kotlin/.../{MkPdfVectorExporter,MkPdfRasterExporter}.kt` (flat, non-`pdf/` — orphaned Batch 1.4 stub paths 5.7a deletes) | | | | | | | | | | ✅ | |
| `android/mk-export/src/test/kotlin/.../pdf/{MkPdfObjectModel,MkPdfContentStreamWriter,MkPdfVectorExporter,MkPdfRasterExporter}Tests.kt` | | | | | | | | | | ✅ | |
| `android/mk-export/src/main/kotlin/.../pdf/{MkPdfFontSubsetter,MkPdfType0FontEmbedder,MkPdfOutputIntent,MkPdfPrintCmykExporter}.kt` | | | | | | | | | | | ✅ |
| `android/mk-export/src/main/kotlin/.../{MkPdfOutputIntent,MkPdfPrintCmykExporter}.kt` (flat, non-`pdf/` — orphaned Batch 1.4 stub paths 5.7b deletes) | | | | | | | | | | | ✅ |
| `android/mk-export/src/test/kotlin/.../pdf/{MkPdfType0FontEmbedder,MkPdfOutputIntent,MkPdfPrintCmykExporter}Tests.kt` | | | | | | | | | | | ✅ |
| `android/docs/impl-log/BATCH-5.{1,2a,2b,3,4a,4b,5a,5b,6,7a,7b}.md` | ✅ (5.1) | ✅ (5.2a) | ✅ (5.2b) | ✅ (5.3) | ✅ (5.4a) | ✅ (5.4b) | ✅ (5.5a) | ✅ (5.5b) | ✅ (5.6) | ✅ (5.7a) | ✅ (5.7b) |

No two agents in this batch write the same path.

**`mk-canvas` — all 29 files across 6 agents, verified against the real Swift source tree
(`wc -l` totals):** 5.1 = 7 files / 990 LOC; 5.2a = 4 files / 885 LOC; 5.2b = 5 files / 706 LOC;
5.3 = 7 files / 1,862 LOC; 5.4a = 1 file / 532 LOC; 5.4b = 5 files / 1,605 LOC. File sum:
7+4+5+7+1+5 = **29**. LOC sum: 990+885+706+1,862+532+1,605 = **6,580**, matching the module
total exactly (5.2a+5.2b = 1,591 = the original undivided 5.2's total; 5.4a+5.4b = 2,137 = the
original undivided 5.4's total).

**`mk-assets` — all 24 files across 2 agents:** 5.5a = 17 files / 2,056 LOC (`Browser/` 4/364 +
`Generators/` 5/803 + `Library/` 2/145 + `Model/` 6/744); 5.5b = 7 files / 619 LOC
(`Instantiation/` 3/265 + `Provenance/` 2/104 + `Rendering/` 2/250). File sum: 17+7 = **24**.
LOC sum: 2,056+619 = **2,675**, matching the module total exactly.

**`mk-export` — all 22 Swift-sourced files across 3 agents:** 5.6 = 18 files / 3,014 LOC
(raster/SVG/gate/budget/outlining cluster, unchanged from the original register); 5.7a = 2
Swift-sourced files / 117 LOC (`PDFRasterExporter.swift` 36 + `PDFVectorExporter.swift` 81) plus
5 Kotlin-only files with no Swift source (`MkPdfObjectModel`, `MkPdfXrefWriter`,
`MkPdfContentStreamWriter`, `MkPdfImageXObjectWriter`, `MkPdfFontEmbeddingProviding`); 5.7b = 2
Swift-sourced files / 211 LOC (`PDFOutputIntent.swift` 92 + `PDFPrintCMYKExporter.swift` 119)
plus 2 Kotlin-only files with no Swift source (`MkPdfFontSubsetter`, `MkPdfType0FontEmbedder`).
Swift-sourced file sum: 18+2+2 = **22**. Swift-sourced LOC sum: 3,014+117+211 = **3,342**,
matching the module total exactly. The 7 Kotlin-only new files (no Swift source, per D-314's
"in-house PDF writer, no `PdfDocument` equivalent to lean on") are additional new-code surface
on top of that 22/3,342 baseline, estimated at ~2,800 Kotlin LOC (5.7a) + ~2,200 Kotlin LOC
(5.7b) ≈ ~5,000 Kotlin LOC total for the whole PDF writer — the same estimate the original
single-agent 5.7 packet carried, now split by writer-layer rather than by Swift file since there
is no 1:1 Swift source to split by.

**Orphaned-stub note (spine §3.3's non-1:1 case, the one instance of it in this batch):** the 4
Swift-sourced PDF files (`PDFRasterExporter.swift`, `PDFVectorExporter.swift` — 5.7a;
`PDFOutputIntent.swift`, `PDFPrintCMYKExporter.swift` — 5.7b) are the only rows in this entire
batch where the Kotlin implementation path diverges from the path Batch 1 · Agent 1.4 already
stubbed. Batch 1.4 stubbed all four flat, directly under `mk-export/.../export/`, because the
Swift originals have no PDF-specific subdirectory to mirror; this batch's own 5.7a/5.7b packets
deliberately re-home all PDF writer code under a new `pdf/` subdirectory that does not exist on
the Swift side. Every other file in this batch — all of `mk-canvas` (5.1/5.2a/5.2b/5.3/5.4a/
5.4b), all of `mk-assets` (5.5a/5.5b), and the other 18 files of `mk-export` (5.6) — is a
mechanical `Mk`-prefix transform landing at exactly its Batch 1 stub path, so no other agent in
this batch owns an orphaned stub. 5.7a's and 5.7b's own packets each name their two flat orphan
paths explicitly in Owns/Tasks/Acceptance.

> **Writer note:** as in Batch 4, individual `Tests/MK*Tests/*.swift`-to-agent assignment is
> this packet's judgment call where the spine names source files but not test files —
> assignments trace each test file to the source file(s) it exercises, verified against the
> real `Tests/` directory listings, so that within each cluster of sibling agents sharing a
> module (5.1/5.2a/5.2b/5.3/5.4a/5.4b in `mk-canvas`; 5.5a/5.5b in `mk-assets`; 5.6/5.7a/5.7b in
> `mk-export`) every test file has exactly one owner. Shared-file exceptions, each explicit in
> the ownership matrix above and in the affected agents' "Reads"/"Owns" sections:
> `MkCanvasTestSupport.kt` (owned by 5.1, read by 5.2a/5.2b/5.3/5.4a/5.4b),
> `TestSupport/MkFreeEntitlementStub.kt` under `mk-assets` (owned by 5.5a, read by 5.5b), and
> `Support/**` under `mk-export`'s test tree (owned by 5.6, read by 5.7a/5.7b) — these mirror the
> same shared-fixture pattern Batch 4 already established for `MkArrangeTestFixtures.kt`/
> `MkPixelDiff.kt` and `MkFixtures.kt`. `MkPdfFontEmbeddingProviding.kt` is a fourth, different
> kind of cross-agent reference within `mk-export`: 5.7a owns and defines the interface, 5.7b
> owns the real conforming implementation — the same "protocol here, real conformer elsewhere"
> pattern as Batch 4's `MkPathPlacementProviding` (4.1 defines it, 4.3 conforms to it), not a
> shared-file exception.
