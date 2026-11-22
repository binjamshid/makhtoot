# MKPathText

Owner: WS-05 (`AGENT_TASK_PACKETS/WS-05-path-text.md`), D-110. Arc-length
parameterized Bézier layout for RTL/bidi text on live, editable paths,
live-editing semantics, and the `PathPlacementProviding` conformance WS-04
uses to freeze path placements into an Arranged Composition.

## Module map

| File | Owns |
|---|---|
| `BezierPathModel.swift` | Editable anchor/handle path model, `MKBezierPathData` bridging, presets (line/arc/circle/wave) |
| `ArcLengthLUT.swift` | Adaptive arc-length lookup table (D-110's core numeric machinery) |
| `PathLayoutOptions.swift` | Engine-level layout knobs (persisted slice + engine-only extensions) |
| `PathGlyphPlacement.swift` | Runtime placement/result types, user-offset carry-over key |
| `PathLayoutEngine.swift` | The layout algorithm (task 4) + join-continuity mitigation (task 8) |
| `PathEditModel.swift` | Pure anchor/handle editing operations (task 10) |
| `PathTextCommands.swift` | `MKCommand` builders for `pathText` node mutations (task 11) |
| `PathPlacementProvider.swift` | `PathPlacementProviding` conformance for WS-04 (task 12) |

## Coordinate frames

Two conventions meet at this module's boundary, and it is important not to
confuse them:

1. **Canvas/document space (Y-DOWN, top-left origin).** `MKPathTextNode
   .path` (an `MKBezierPathData`) is authored here — the same space as
   every other node's `MKNodeCore.transform`, and the space WS-06's
   gesture handlers report drag points in. `PathLayoutEngine` itself makes
   **no assumption** about which convention its input is in — it is pure
   vector math over whatever `CGPoint`s it is given. A LIVE renderer
   (WS-07's eventual real path-text drawer, replacing the
   `PathTextDrawer`/`MKPolylineArcLength` stand-in — see "Seam WS-07
   should adopt" below) calls `PathLayoutEngine.layout` with the path
   exactly as authored (Y-DOWN) and gets Y-DOWN placements back, ready to
   feed straight into a `CGContext` translate/rotate, matching
   `PathTextDrawer`'s existing usage pattern.
2. **Composition-local space (Y-UP).** `MKArrange.ArrangeDeriver`'s own
   file header is normative here: every `MKGlyphLayout.position` is
   Y-UP, because it is captured straight off `CTRunGetPositions` with no
   flip applied anywhere in the pipeline (`ArrangedDrawer` applies the
   ONE compensating flip at draw time, uniformly for path-derived and
   plain-Live-Text glyphs alike). `MKPathTextPlacementProvider
   .forArrangeOnPath` is the ONE call site in this module that needs to
   bridge the two: it flips the authored path's `y` once
   (`flippedY(_:)`), builds the LUT/layout entirely in that flipped
   space, and hands the result straight to `ArrangeDeriver` — no further
   conversion needed on either side. This is a "flip the input, then
   compute" ordering, not "compute, then negate the answer" — the two are
   NOT equivalent in general (rotation signs interact with translation
   asymmetrically once a normal-offset is added), and only the
   flip-first ordering keeps `MKTransform2D.rotation`'s meaning
   consistent with the render-time flip `ArrangedDrawer` applies.

## Logical reading order pen advance (D-110, DF-6a)

**DF-6a correction (binding on this module, overriding the WS-05 packet's
own task 4a/4b prose).** The packet's task 4 describes the pen order as
"visual order (RTL-aware)" with an elaborate `flowDirection`
(`rtlNatural`/`pathForward`) option. That name was a corrected misnomer —
`ARCHITECTURE.md` §9.4 and `TEST_MATRIX.md` T-PTH-2 both call it what it
actually is: **logical reading order**. There is one pen order, not a
`flowDirection` switch: each bidi run advances in its own internal order
(the RTL Arabic run right-to-left through its own glyphs, LTR Latin/digit
runs left-to-right through theirs), chained run-by-run in the paragraph's
LOGICAL (typed) sequence.

**Implementation finding.** `MKTextEngine.MKClusterMap.clusters`
(`ClusterMap.swift`, WS03-A2) is already built by sorting every raw
cluster — from every run, across the whole line — by UTF-16
`utf16Range.lowerBound` ascending. UTF-16 offset **is** logical (typed)
position, by definition, independent of script direction. So walking
`line.clusterMap.clusters` in its own array order already realizes DF-6a's
"logical reading order, chained run-by-run" directly — no separate
per-run-reversal pass is needed. `PathLayoutEngine.layout` does exactly
this single walk.

### Worked example: «Hello سلام World ٤٥» on an open path

Typed order (UTF-16 offsets): `H-e-l-l-o` (0–4) · space (5) · `س-ل-ا-م`
(6–9, RTL) · space (10) · `W-o-r-l-d` (11–15) · space (16) · `٤-٥`
(17–18, Arabic-Indic digits, captured as their own LTR-flagged run per
`docs/impl-log/WS-03.md`'s WS03-A2 probe finding). `clusterMap.clusters`
is sorted by exactly these offsets, so the pen walk visits `H, e, l, l, o,
" ", س, ل, ا, م, " ", W, o, r, l, d, " ", ٤, ٥` in that order — each
cluster's arc span is `[cursor, cursor + advance)`, `cursor` strictly
increasing throughout, with **zero** special-casing at either direction
switch (5↔6 and 10↔11 in the offsets above). This is exactly
`PathLayoutEngineTests.multiSwitchFixtureArcOffsetsMonotonic`'s assertion.

### Worked example: «الرقم٤٥» (no-space digit adjacency)

الرقم (ا-ل-ر-ق-م, UTF-16 0–4) is immediately followed by ٤٥ (5–6) with NO
separating codepoint. Because the pen walk is driven purely by
`utf16Range.lowerBound` ordering (not by "does a run boundary need a
gap"), the ٤ cluster's span starts at exactly `cursor` right after م's
span ends — no phantom gap, no double count. `PathLayoutEngineTests
.noSpaceDigitAdjacencyHasNoGapOrOverlap` locks this down numerically.

## Join-continuity mitigation (task 8) and its limits

Per-glyph tangent rotation on a curved path opens tiny visual gaps at
Arabic letter joins (shaping happened on the flat line — the connected
FORMS are already correct; only their world-space rotation on the curve
can misalign the join stroke). Three mitigations, all on by default:

1. **Rotate about the advance-span midpoint, not the leading edge**
   (task 4c) — the anchor for both position AND (by default) rotation is
   `frame(atLength: (spanStart + spanEnd) / 2)`. This alone removes most
   visible cracking on gentle curves (`r ≥ 4×` font size, per the packet's
   accept bar).
2. **Curvature clamp** (task 8.2): if the tangent swings by more than
   `maxJoinAngleDegrees` (default 25°) across ONE glyph's own span (i.e.
   between `frame(atLength: spanStart).tangent` and
   `frame(atLength: spanEnd).tangent`), that glyph's ROTATION source
   switches from the midpoint tangent to the normalized average of its own
   two span-edge tangents — smoothing the glyph's own orientation across a
   locally sharp turn. Position is never moved by this — only the
   rotation SOURCE changes; moving position away from the arc-length
   midpoint would reintroduce exactly the cracking mitigation #1 fixes.
3. **`curvatureWarning` flag** (task 8.3): set on `PathLayoutResult` when
   any two ADJACENT base glyphs' final (post-clamp) rotations differ by
   more than `curvatureWarningThresholdDegrees` (default 40°) — WS-06's
   surface for "المنحنى حاد جدًا لاتصال الحروف" (the curve is too sharp
   for letter joins).

**Documented limit (v1, by design — no glyph warping).** None of the
above ever distorts a glyph outline. On a sufficiently sharp turn, a
visible micro-gap or micro-overlap at a join CAN still occur even with the
clamp active — the clamp reduces the worst case, it does not guarantee
zero visible seam on an arbitrarily tight curve. Actual glyph warping
(bending the outline itself to follow curvature, the way some vector
tools do) is an explicit v2 extension seam (`ARCHITECTURE.md` §24) — the
LUT/layout API is deliberately kept clean of any per-glyph outline
transform so that seam can be added later without touching this module's
placement math.

## Overflow (task 4e)

`PathLayoutOptions.overflow`: `.clip` (glyphs whose span exceeds the
path's remaining length are excluded from `placements`, with the clipped
UTF-16 range recorded in `OverflowInfo` — never silently dropped without a
record) or `.continueTangent` (default: glyphs beyond the end are placed
via straight extension along the exit tangent, always flagged). Closed
paths never overflow in this sense — `PathLayoutEngine.layoutClosed` wraps
arc length modulo `totalLength + closedPathGap` instead (task 4e's other
branch).

## Marks and arrange-on-path

`ArrangeDeriver` (verified by reading `Sources/MKArrange/ArrangeDeriver.swift`
directly) never calls `PathPlacementProviding.placement(for:lineIndex:)`
for a MARK's own glyph address — a mark's baked `MKMarkNode.relativeOffset`
is added to its BASE's already-placed position, unrotated, with the D-220
rotation-composition happening later at render/hit-test time
(`MKArrangedGeometry`). This module's conformer therefore only needs to
answer for BASE (pen-advancing) glyph addresses, which is exactly what
`MKPathTextPlacementProvider` does (`byAddress` is built from
`layout.placements` filtering `!isMark`). One consequence, inherited from
`ArrangeDeriver`'s own design rather than introduced here: a FREE/detached
mark (`attachedTo == nil`, §6.3) on arranged path text keeps its flat
straight-baseline position rather than following the path — this is an
`ArrangeDeriver`-level gap (outside this packet's fence), flagged in
`docs/impl-log/WS-05.md` for whoever next owns that file.

## Known schema gap: per-glyph user offsets are not yet persisted

**RESOLVED (Run-3 PATH-UX session).** This gap is closed:
`MKModel.MKPathTextNode` now carries `glyphOffsets: [MKPathGlyphOffsetKey:
MKPathGlyphOffset]` (`MKPathGlyphOffsetKey`/`MKPathGlyphOffset` declared in
`Sources/MKModel/MKPathGlyphOffset.swift`; the field itself is additive on
`MKPathTextNode` — `decodeIfPresent ?? [:]`, no `schemaVersion` bump), and
`PathTextCommands.setGlyphOffset(_:forKey:nodeID:in:gestureID:)` is a real,
coalescable `MKReplaceNodesCommand` builder over it, with `PathTextCommands
.persistedUserOffsets(from:)` converting the persisted map into the
`[PathClusterProvenanceKey: PathGlyphUserOffset]` shape
`PathLayoutEngine.layout` already consumed. `PathTextOffsetStore` (below)
is retained as a legacy, session-scoped convenience — nothing routes
through it in preference to the real command path anymore, but it has not
been removed. `PathLayoutOptions`' other engine-only fields (`alignment`,
`baselineOffsetMagnitude`, `overflow`, `insideOut`, `closedPathGap`,
`letterSpacingExtra`, join-continuity thresholds) remain unresolved — the
rest of this section describes that residual status accurately. Full
detail and tests: `docs/impl-log/WS-05.md`'s PATH-UX addendum.

Packet tasks 3/9/11 ask for per-glyph user offsets (independent nudges a
user applies to individual glyphs while text is still live-on-path) to
round-trip through `MKPathTextNode`'s Codable persistence, keyed by
cluster provenance. The SHIPPED `MKModel.MKPathTextNode` (WS-02) has no
field for this — only `core`/`text`/`style`/`path`/`layout`
(`startOffset`/`side`/`spacingMode`). `MKModel` sources are outside this
packet's fence (`MKPathText` sources/tests + `Package.swift` only), so:

- `PathLayoutEngine.layout` DOES fully support user offsets — it accepts a
  `[PathClusterProvenanceKey: PathGlyphUserOffset]` dictionary and folds
  each entry into every matching glyph's final position/rotation. This is
  real, tested (`PathLayoutEngineTests.userOffsetAppliesAndSurvivesRelayout`),
  load-bearing engine behavior.
- `PathTextOffsetStore` (`PathTextCommands.swift`) is a session-scoped,
  non-`Codable`, non-`MKCommand`-integrated holder for these offsets —
  what WS-06 can wire up TODAY.
- The actual fix is a small, additive `MKModel.MKPathTextNode` field
  (e.g. `userOffsets: [String: MKPathGlyphOffsetRecord]`, keyed by an
  encoded `PathClusterProvenanceKey`) plus wiring `PathTextCommands
  .setGlyphOffset` as a real `MKReplaceNodesCommand` builder over it —
  flagged as a durable follow-up in `docs/impl-log/WS-05.md`, not silently
  dropped.

`PathLayoutOptions`' engine-only fields (`alignment`, numeric
`baselineOffsetMagnitude`, `overflow`, `insideOut`, `closedPathGap`,
`letterSpacingExtra`, join-continuity thresholds) have the same status:
fully functional in the engine, not yet round-tripped through
`MKPathTextNode.layout` (which only carries the three-field
`MKModel.MKPathLayoutOptions`). `PathLayoutOptions.init(node:)` seeds the
persisted slice and leaves the rest at documented defaults.

## Seam WS-07 should adopt (do not edit `MKRender` here)

`MKRender/Drawers/PathTextDrawer.swift` ships a documented STAND-IN
(`MKPolylineArcLength`, WS-07's own deviation 5): a fixed-subdivision
polyline sampler with no adaptive tolerance, no live-edit support, no join
mitigation, and — importantly — its glyph-walk order is the RAW per-run
`run.glyphs` array in `line.runs` iteration order (visual order within
each run, runs in `CTLine` visual order), NOT logical reading order —
correct-looking only for pure single-direction text. This module is the
real replacement. WS-07 (or whoever next owns `MKRender`) should replace
`PathTextDrawer.draw`'s body with:

1. Build (or reuse a cached) `ArcLengthLUT(path: BezierPathModel(node.path))`.
2. Call `PathLayoutEngine.layout(line:path:options:)` (or `.layoutClosed`
   for `node.path.isClosed`) with `PathLayoutOptions(node: node.layout)`.
3. For each non-mark placement, draw its glyph translated to `.position`
   and rotated by `.rotation` (same `ctx.translateBy`/`ctx.rotate`/
   `ctx.scaleBy(x:1,y:-1)` idiom `PathTextDrawer` already uses — only the
   position/rotation SOURCE changes, not the draw call shape).
4. For each mark placement, draw its own glyph (or the base's, per
   `MKMarkAttachment.markGlyph == nil`'s fused case) the same way.

No `MKRender` files were edited by this packet (out of fence) — this
section is the coordination note the calling context asked for.
