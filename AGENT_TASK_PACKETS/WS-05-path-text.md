# WS-05 — Path Text Engine

Run-1 agent task packet for Makhtoot (مخطوط). Governed by FOUNDATION.md. Owns
`MKPathText`: curved/circular/freeform text on live Bézier paths, RTL-correct.

## 1. Mission

Implement text-on-path for Arabic: a Bézier path model (segments, control points, closed/
open, editable), an arc-length parameterization LUT for accurate distance-along-curve
placement, and a layout engine that walks WS-03's shaped glyphs along the path **in
visual order** (RTL-aware) placing each glyph at its arc position with rotation equal to
the local tangent plus user offsets. Core Text cannot do curved baselines (market study
§4), so this packet owns the 2D geometry: pen advance along arc length, tangent/normal
frames, baseline offset from the path, overflow policy, and closed-path (circular text)
handling. Path Text objects stay LIVE — retype and the text reflows along the path; edit
a control point and the glyphs re-lay — until the user enters Arrange Mode, at which
point WS-04 freezes the placements into an Arranged Composition via the
`PathPlacementProviding` seam you implement.

The mission includes model + engine + editing semantics, not UI: WS-06 renders path
handles and routes gestures; you expose `PathEditModel` (hit-testable control points,
insert/delete point, drag deltas → new path) and pure relayout. Correctness bar: joined
Arabic must remain visually connected along gentle curves (glyph-by-glyph tangent
rotation naturally opens tiny gaps at joins — you implement the mitigation described in
task 8 and document its limits), marks must ride with their bases, and mixed-direction
runs must keep coherent ordering along the path.

## 2. Scope

**IN**
- `BezierPathModel`: anchor points with in/out control handles, open/closed, Codable
  (`MKBezierPathData` interop with WS-02), CGPath bridging, presets (line, arc, circle,
  wave) as constructors.
- Arc-length LUT: adaptive sampling, length queries, point/tangent-at-length, inverse
  (length at nearest point), rebuild-on-edit.
- Path layout engine: shaped glyphs → placements (position, rotation, per-glyph user
  offset slots), RTL logical-reading-order pen, baseline offset, start-offset/alignment along
  path (start/center/end — RTL-aware meaning), overflow policy, closed-path wrap.
- Mark handling: marks placed in their base's rotated frame (offset rotated with base).
- Live editing semantics: text change → relayout; path change → relayout; per-glyph user
  offsets preserved across relayout by cluster identity where possible.
- `PathEditModel` for WS-06 (control-point manipulation API).
- `PathPlacementProviding` implementation for WS-04 arrange-on-path.
- `pathText` scene-node integration (WS-02 node case) + commands for path/text edits.

**OUT**
- Gesture recognition/handle drawing (WS-06). Rendering (WS-07 draws from your
  placements). Arrange node construction (WS-04). Shaping (WS-03).
- Animation along path (v2 — leave the LUT API clean as the extension seam).
- Text inside shapes / area text (not in v1 scope anywhere).

## 3. Dependencies

**Upstream:** WS-01 (`MKFoundation` geometry), WS-02 (`MKBezierPathData`, `pathText`
node, commands), WS-03 (`ShapingCaptureResult` — you consume single-line captures;
multi-line on path is out of scope, enforce single logical line), WS-04 contract
(`PathPlacementProviding` — WS-04 owns the protocol file; coordinate via CONTRACTS.md).
**Stubs:** `SystemFontStubProvider` until WS-09; entitlement stub (path text is not
premium-gated).

**Downstream consumers:** WS-04 (arrange-on-path), WS-06 (path editing UX), WS-07
(rendering placements), WS-08 (export: path text exports as placed glyphs; SVG textPath
is NOT used — see WS-08).

## 4. Locked decisions binding this packet (quoted)

- **D-110**: "Arc-length LUT over the Bézier path; pen advances along arc length in
  visual order (RTL-aware), each glyph gets position = arc point, rotation = local
  tangent, plus user offset. Live Path Text stays reflowable (retype → relayout); Arrange
  freezes to Arranged Composition with per-glyph adjustability retained. Path remains
  editable (control points) in live mode only."
- **D-103** (inherited): shaping only via Core Text capture; no shaper, no presentation
  forms.
- **D-109** (inherited): visual order/bidi levels from capture govern placement order.
- Glossary: "**Path Text object** — live text laid on a Bézier path (still reflowable)
  until arranged."
- BRIEF: "Curved/circular/freeform text on dynamic live Bézier paths; editable/
  reflowable along path until arranged; arranged path text keeps independent glyph
  adjustments (Q72: Bézier)."
- **D-115** (relevant): manipulation frame ≤8.3 ms ProMotion — control-point drag
  relayout must fit the frame budget for typical strings.

## 5. Task breakdown (ordered)

1. **`BezierPathModel.swift`**: `PathAnchor {point, handleIn?, handleOut?}`, ordered
   anchors, `isClosed`, cubic segment enumeration, CGPath emission, Codable via
   `MKBezierPathData`. Constructors: `line(from:to:)`, `arc(center:radius:start:end:)`,
   `circle(center:radius:)`, `wave(rect:periods:amplitude:)`. *Accept:* round-trip
   Codable; CGPath segment count matches anchors; circle length ≈ 2πr within 0.1 %.
2. **`ArcLengthLUT.swift`**: adaptive subdivision per cubic (flatness tolerance 0.05 pt,
   min 16 / max 512 samples per segment), cumulative length table;
   `point(atLength:)`, `tangent(atLength:)` (normalized), `frame(atLength:) ->
   (point, tangent, normal)`, `totalLength`, binary-search lookup with linear interp;
   `nearestLength(to point:)` for hit mapping. *Accept:* analytic checks — line exact;
   circle point/tangent error < 0.2 pt / 0.5° at 100 sampled lengths; LUT build for a
   6-segment path < 1 ms.
3. **Placement model** `PathGlyphPlacement {glyphSlot (run/index refs), clusterID,
   arcLength: CGFloat, position: CGPoint, rotation: CGFloat, userOffset: CGPoint,
   userRotation: CGFloat, isMark, baseClusterID?}` + `PathLayoutResult {placements,
   overflow: OverflowInfo, pathLength}`. Codable-free runtime type; user offsets persist
   in the `pathText` node keyed by `clusterID` + occurrence index. *Accept:* type review
   vs CONTRACTS.md; persistence of offsets round-trips via node Codable.
4. **Core layout algorithm** `PathLayoutEngine.layout(capture:path:options:)` — the
   tricky part, implement exactly:
   a. Take the single `ShapedLine`; iterate glyphs in **visual order** (WS-03
      `visualIndex`, left→right). For an RTL paragraph the visually-leftmost glyph is
      the LAST logical character — correct behavior: the pen starts at the path start
      and lays visual-left-to-right, so along the path the text reads correctly when the
      path flows left→right in RTL reading (see option `flowDirection` below).
   b. `flowDirection` option (`rtlNatural` default | `pathForward`): `rtlNatural` maps
      arc length so text runs from path START in the RIGHT-to-left reading direction —
      i.e., pen position for visual index i = startOffset + (lineWidth −
      glyphVisualRightEdge(i)); this makes the FIRST typed letter sit at the path start,
      which is what an Arabic user expects when drawing a path right-to-left or a
      circle. `pathForward` lays visual-left-to-right from the start (for LTR-flowing
      decorative paths). Document both with diagrams.
   c. Each base glyph: its pen span = [penX, penX + advance.width) mapped through the
      direction function to arc lengths; anchor arc position = span CENTER (rotating
      about glyph center, not leading edge, dramatically reduces join cracking on
      curves); `position = frame(atLength: anchorLen).point + normal * baselineOffset +
      rotate(userOffset, tangentAngle)`; `rotation = tangentAngle + userRotation`.
      Glyph is drawn with its outline translated so its advance-center aligns to anchor.
   d. Marks: skip pen advance; place in base frame — `position = basePlacement.position
      + rotate(markRelativeOffset, baseRotation)`, `rotation = baseRotation`.
   e. Overflow: glyphs whose span exceeds `totalLength`: open path → `OverflowInfo`
      lists clipped cluster range, glyphs beyond end continue along the end tangent
      (straight extension, flagged) — never dropped silently; closed path → wrap modulo
      length with optional gap (`closedPathGap` points, default 0).
   *Accept:* straight-line path reproduces plain-text layout within 0.5 pt (identity
   sanity); circle fixture places "بسم الله الرحمن الرحيم" with monotonic arc positions,
   no NaNs, marks riding bases; overflow fixture reports correct clipped range.
5. **Kerning/tracking on path**: pen advances use captured advances (which already
   include kerning/tracking from the attributed build); add `letterSpacingExtra` option
   applied between cluster spans (useful on tight curves). *Accept:* extra spacing
   spreads glyphs without rotating errors.
6. **Alignment & start offset**: `startOffset` (points along arc), `alignment`
   (`start`/`center`/`end` of the laid text within the path length — computed after
   width known; in `rtlNatural`, `start` means the path start = first letter). *Accept:*
   center alignment centers text on an arc fixture; RTL semantics documented + tested.
7. **Baseline offset & side**: `baselineOffset` signed (positive = normal side); flipping
   text to the inside of a circle = rotate placement by π option `insideOut` (glyphs
   upright on the inner side). *Accept:* circle inside/outside fixtures visually verified
   in harness; screenshots logged.
8. **Join-continuity mitigation**: per-glyph tangent rotation breaks Arabic connections
   on curves. Mitigations (all on by default, documented limits): (1) rotate about
   advance-center (task 4c); (2) curvature clamp — if |Δtangent| between adjacent base
   glyphs exceeds `maxJoinAngle` (default 25°), subdivide: place the glyph with the
   AVERAGE of edge tangents instead of center tangent; (3) expose
   `curvatureWarning` in `PathLayoutResult` when any adjacent-pair Δtangent > 40° so
   WS-06 can show "المنحنى حاد جدًا لاتصال الحروف" (curve too sharp for letter joins).
   NO glyph distortion/warping in v1 (extension seam note). *Accept:* gentle arc
   (r ≥ 4× font size) shows visually continuous joins in harness screenshots; sharp-turn
   fixture sets the warning flag.
9. **Relayout stability**: on text edit, re-shape (WS-03) and re-layout; carry over
   `userOffset`s by matching `clusterID` provenance (same codepoints + ordinal); on path
   edit, keep all user offsets (arc lengths recomputed). *Accept:* appending a letter
   keeps prior glyph offsets; moving a control point keeps offsets.
10. **`PathEditModel.swift`**: expose anchors + handles as hit targets (ids), operations:
    move anchor, move handle (with `mirrored`/`free` handle mode), insert anchor at
    nearest-length, delete anchor, toggle closed; each emits a path-mutation
    `MKCommand` (coalescing key per drag). *Accept:* all ops keep the path valid
    (≥2 anchors open / ≥3 closed); undo round-trips; insert-at-point lands within 1 pt
    of the tapped location on the curve.
11. **`pathText` node integration**: node stores `BezierPathModel` data, source text,
    style, layout options, user offsets; commands: setText, setStyle, setPath,
    setOptions, setGlyphOffset(clusterKey:) — all coalescable. *Accept:* full node
    Codable round-trip including offsets and options.
12. **`PathPlacementProviding` conformance** for WS-04: yields final per-glyph
    position+rotation (including user offsets) so `ArrangeDeriver` bakes them into
    `GlyphNode`/`MarkNode` transforms; after arrange, the path itself is retained ONLY
    inside `SourceTextBackup.pathData` (D-110: path editable in live mode only).
    *Accept:* arrange-on-path integration test with WS-04: derived nodes match live
    placements within 0.1 pt; revert restores a live path-text node with the same path.
13. **Perf**: relayout (no reshape) of 60-glyph string on 8-segment path < 2 ms; full
    reshape+relayout < 6 ms (fits 8.3 ms frame with headroom for WS-06/07 work); LUT
    rebuild throttled to once per frame during drags. *Accept:* signpost measurements
    recorded (`pathRelayout` signpost).
14. **Harness**: DEBUG `PathTextHarnessView` — path presets, control-point dragging,
    live typing, toggles for flowDirection/insideOut/baselineOffset, overlay of frames/
    tangents. *Accept:* used to produce §6 screenshot evidence.
15. **Docs**: `MKPathText/README.md` — coordinate frames, direction-mapping math from
    task 4b with a worked circle example, join-continuity limits, v2 seams (animation,
    glyph warping). *Accept:* reviewed against ARCHITECTURE.md §9 outline.

## 6. Arabic-correctness notes (fixtures)

- **"بسم الله الرحمن الرحيم" on a circle** (the classic): `rtlNatural` flow must read
  correctly clockwise starting at the top; marks (shadda, superscript alef) stay with
  bases at all angles including upside-down region with `insideOut` both states.
- **"لا"-containing string on an arc**: ligature is ONE placement (one base glyph) —
  never split by the path.
- **"شَدَّةٌ" on a wave**: stacked marks keep their stack order in the rotated frame at
  crest and trough.
- **Mixed bidi on path**: "عام ٢٠٢٦ Design" — the LTR sub-run occupies a contiguous arc
  span and reads left-to-right along the flow; assert visual-order contiguity.
- **Numerals**: "١٢٣٤٥" and "12345" both remain sequential along the path.
- Sharp-corner star path: curvatureWarning set; no crash, no NaN transforms.
- Tatweel stretch "مـــد" on a curve: tatweels are base glyphs, joins visually continuous
  on gentle curves (this is the join-mitigation stress fixture).

## 7. Packet acceptance criteria (gates)

- **Build gate**: `MKPathTextTests` green (`T-PATH-*`).
- **Geometry gate**: LUT analytic accuracy tests; straight-line identity test
  (`T-PATH-LUT-*`, `T-PATH-ID-*`).
- **Manual Arabic checklist**: harness screenshots for every §6 fixture reviewed
  (`T-ARABIC-M-PATH-*`); join continuity on gentle curves confirmed by eye (documented
  subjective gate — this is the founder-facing quality bar).
- **Perf gate**: task 13 budgets met, recorded for WS-07's device verification
  (`T-PERF-PATH-*`, supports D-115 manipulation budget).
- **Integration gate**: WS-04 arrange-on-path round-trip test passes (`T-PATH-ARR-*`).

## 8. Deliverables

- `MakhtootKit/Sources/MKPathText/BezierPathModel.swift`, `ArcLengthLUT.swift`,
  `PathLayoutEngine.swift`, `PathLayoutOptions.swift`, `PathGlyphPlacement.swift`,
  `PathEditModel.swift`, `PathTextCommands.swift`, `PathPlacementProvider.swift`,
  `README.md`
- `MakhtootKit/Tests/MKPathTextTests/*` (analytic geometry tests, layout fixtures,
  offset-stability tests, integration test with MKArrange)
- DEBUG harness: `Makhtoot/App/Debug/PathTextHarnessView.swift`
- CONTRACTS.md update (placement provider conformance notes).

## 9. References

- ARCHITECTURE.md: §9 Path Text Engine, §5 Arrange Mode Engine (freeze seam), §10 Canvas
  & Interaction (edit model consumers), §24 Extension Seams (animation/warping).
- PRD.md: §9 Path Text, §6 Arrange Mode (arrange-on-path), §21 Edge-Case Compendium.
- BRIEF.md: "Curved/circular/freeform text on dynamic live Bézier paths…" bullet (Q72).
- Market study §4, paragraph on text-on-path: "Core Text does not natively support
  curved baselines… compute a path parameterization (arc length lookup table),
  reverse-map to correct RTL glyph advance order, and rotate each glyph to the local
  path tangent" — this packet is that plan made concrete.

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS05-A1: rtlNatural direction mapping (first letter at path start)",
  "WS05-A2: rotate-about-advance-center + curvature clamp join mitigation, no glyph
  warping in v1", "WS05-A3: user-offset carry-over keyed by cluster provenance".
- Implementation log after tasks 4, 8, 12 with measured accuracy/perf numbers.
- Verification evidence: harness screenshots (circle/arc/wave/star fixtures, inside/
  outside), signpost table, integration test transcript with WS-04.
- Record the documented join-continuity limitation as a durable memory note for the
  founder-review phase (P7 in PLAN.md).

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Arabic engine — curved/circular/freeform text on dynamic live Bézier paths (Q72) | T1 (`BezierPathModel`), T4 (`PathLayoutEngine`) |
| Arabic engine — editable/reflowable along path until arranged (retype → relayout; path edit → relayout) | T9 (relayout stability), T10 (`PathEditModel`) |
| Arabic engine — arranged path text keeps independent glyph adjustments | T12 (`PathPlacementProviding` conformance for WS-04) |
| Arabic engine — per-object position/rotation via path tangent + user offsets | T4c (anchor position/rotation, `userOffset`/`userRotation`) |
| Arabic engine — joining preserved by default (joined Arabic stays visually connected) | T8 (join-continuity mitigation) |
| Arabic engine — tashkeel attach to base, follow it | T4d (marks placed in base's rotated frame) |
| Arabic engine — mixed Arabic-English bidi runs stay coherent | T4a–b (visual-order flow direction) |
| Performance — manipulation frame ≤8.3 ms budget (D-115) | T13 |
