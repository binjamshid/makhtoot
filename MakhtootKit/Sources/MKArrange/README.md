# MKArrange

Owner: WS-04 (`AGENT_TASK_PACKETS/WS-04-arrange-engine.md`). This slice
covers the packet's PLAN P5 core: derivation, provenance, revert, per-node
manipulation primitives, and lossless two-level selection. Deep UX (form
selector *popover*, canvas mark-drag/decompose interaction) is WS-06/P6 —
this module ships the UI-free engine those UIs bind to (`FormSelectorModel`
is engine-owned per the packet; its *rendering* is WS-06's).

## Lifecycle: live ⇄ arranged

```
MKLiveTextNode / MKPathTextNode
        │  ArrangeDeriver.derive(sourceText:style:capture:pathData:placement:)
        │  (async — outline extraction goes through the actor-isolated
        │   MKGlyphPathProvider)
        ▼
ArrangedComposition  (glyph/mark/ligature children + MKSourceTextBackup)
        │
        │  ArrangeCommands.arrangeCommand(...)  →  MKReplaceNodeCommand
        ▼
MKArrangedTextNode  (installed into the scene; undo = instant un-arrange)
        │
        │  JoinController / LigatureDecomposer / MarkAttachmentController /
        │  ArrangeStyleEditor  →  ArrangeCommands.replaceComposition(...)
        │  →  MKReplaceNodesCommand
        │  (every one of these snapshots the FULL replacement
        │  MKArrangedTextNode — owner core + new composition + derivedFrom
        │  — at command-construction time; inverse captures the prior full
        │  node from the pre-apply scene — same absolute-value idiom
        │  `MKPersistence/Undo/Commands.swift` documents for every other
        │  command in the app)
        ▼
MKArrangedTextNode  (edited, still fully provenanced, never reflowed)
        │
        │  RevertService.revertCommand(...)  →  MKReplaceNodeCommand
        │  (confirmation-gated by RevertPreflight; verifies
        │  MKSourceTextBackup.contentHash first — INV-4)
        ▼
MKLiveTextNode / MKPathTextNode  (byte-identical string + style; undo
                                  restores the FULL arranged node, every
                                  manual edit included)
```

Every arrange mutation — node-kind swaps AND composition-internal edits —
now goes through `MKPersistence`'s canonical, journal-codable catalog:
`MKReplaceNodeCommand` for node-kind swaps (`arrangeCommand`/
`revertCommand`, unchanged since P5), `MKReplaceNodesCommand` (via
`ArrangeCommands.replaceComposition`) for everything that mutates
*inside* an already-arranged node. This module's own former local command
type, `MKArrangedCompositionCommand`, is RETIRED (Run-3 session — see
`docs/impl-log/WS-04.md`) — `MKCommandCoder`'s closed switch (`MKPersistence`)
could never reference it, so crash-recovery journal replay silently lost
any in-flight join-break/decompose/mark-move/style-edit arrange operation;
every arrange operation is now journal-replayable end to end.

## Coordinate convention (load-bearing — read before touching geometry)

`MKGlyphLayout.position`/`MKMarkNode.relativeOffset` are stored in
**composition-local, y-up space** — the SAME axis convention Core Text
captures in (`MKTextEngine/CoordinateSpace.swift`), not MKRender's y-down
document space. `MKRender/Geometry/ArrangedGeometry.swift`/`ArrangedDrawer
.swift` (shipped by WS-07, unmodified by this packet) already assume
exactly this convention and apply a single `scaleY(-1)` flip at draw time —
so this module and the shipped renderer agree with **zero code changes on
either side**, verified by `DerivationFidelityTests.swift` rendering
derived compositions through the real `MKSnapshotRenderer`.

Per-line stacking matches `LiveTextDrawer.draw(_:into:quality:report:)`
exactly: `lineOriginY` starts at line 0's ascent and accumulates
`lineHeightMultiple × pointSize` per subsequent line; a glyph's raw Core
Text position `ctPos` becomes `layout.position = (ctPos.x, ctPos.y −
lineOriginY)`. A mark's `relativeOffset` needs **no** line-origin
correction — it's `markCtPos − baseCtPos`, and the constant `lineOriginY`
term cancels in that subtraction, which is exactly why D-220/§6.3 call the
value "base-local" in the first place.

## Fidelity algorithm walkthrough — "لا" (D-221)

Decomposing the lam-alif ligature (`LigatureDecomposer.decompose`):

1. Constituents: `[ل (U+0644), ا (U+0627)]`, in logical order.
2. Joining-preserving forms: re-run `MKJoiningAnalyzer` over the
   composition's full backup source string and look each constituent up by
   its OWN original UTF-16 index — this reproduces "the form it would have
   inside the original sequence" with no first/interior/last
   special-casing (the analyzer's own neighbor rules already give the right
   answer once you ask it about the *original* position).
3. `MKFormResolver` (D-107 ZWJ harvest) resolves each constituent's glyph
   in the resolved form, same font/style as the composition.
4. Natural pen walk: cumulative advances from the two standalone-resolved
   glyphs, left-to-right, starting at 0. `naturalWidth` = sum of both
   advances.
5. Natural scale factor `s_natural = ligature.advance.width / naturalWidth`.
6. **Pre-flight clamp check (D-221, runs BEFORE committing to fidelity):**
   if `s_natural ∉ [0.85, 1.15]`, fidelity mode is refused — falls back to
   `.defaultForms` automatically, `fidelityAutoRefused = true` on the
   result (WS-06 surfaces the existing low-confidence notice UX).
7. Otherwise `scale = s_natural` (already inside the clamp, so `clamp()` is
   a no-op — kept for defensiveness/float rounding) — each constituent's
   composition-local x offset is `scale × naiveX[i]`, edge-aligned to the
   original ligature's own `layout.position.x` by construction (proof: the
   LAST constituent's right edge works out to exactly
   `layout.position.x + scale × naturalWidth = layout.position.x +
   ligature.advance.width`, algebraically, not by a second alignment pass).
8. Vertical: every constituent is baseline-aligned (`Δy = 0`) EXCEPT the
   alef in a lam-alif pair specifically, which gets `Δy = ligature outline
   top − alef's own standalone outline top` (a closed-form top-edge
   alignment — the packet's "least-squares 2-term fit" description,
   simplified to the 2-constituent case it's actually used for).
9. `fidelityOffsets[id] = (scale − 1) × naiveX[i]` for x, `Δy` for y —
   stored on the group for exact reproducibility (never recomputed at
   render time).
10. Marks attached to the ligature (`group.attachedMarks`) re-point to the
    nearest constituent by horizontal-overlap distance, offset recomputed
    to preserve absolute position (tie → later logical index).

Measured fidelity numbers (fixture: "لا", Geeza Pro, 36pt) are logged in
`docs/impl-log/WS-04.md` alongside the property-test seeds per the packet's
§10 duty.

## Recompose dirty check — no extra model storage needed

D-221's widened recompose dirty check ("compare FULL current node state —
transform AND style — against the state captured immediately after
decomposition") needs a baseline to diff against. `MKModel` has no
dedicated snapshot field for "the constituents' state right after
decompose" separate from their live (possibly-edited) values — and this
module cannot add one (outside its fence). The fix needs no new storage at
all: every freshly-decomposed constituent is initialized with `transform ==
.identity` (all NEW placement lives in `layout.position`/
`fidelityOffsets`, never in the user-delta field) and `style ==
group.style` (the ligature GROUP's own top-level style field, a SIBLING of
the `state` enum, left completely untouched by decompose/recompose). So the
baseline for ANY constituent, at ANY later moment, is simply `(.identity,
group.style)` — a direct comparison, not a stored snapshot. See
`LigatureDecomposer.swift`'s file header for the full reasoning (ADR
WS04-A4).

## Invariants this module enforces

- **No implicit reshape (INV-1).** `MKArrangeInvariants
  .assertReshapeAllowed` + `MKArrangeError.arrangedNodeCannotReshape` —
  there is no font/size/feature-change entry point anywhere in this
  module's public API for an arranged node; the only route is
  revert-first.
- **Source backup immutability (INV-4).** `MKSourceTextBackup.contentHash`
  is verified (`RevertService.verifyBackupIntegrity`) before every revert;
  a mismatch throws rather than silently reverting to a possibly-corrupted
  value.
- **Never presentation-form codepoints.** Every glyph resolution path
  (`ArrangeDeriver`'s consumption of `MKShapingCaptureResult`,
  `MKFormResolver` via `JoinController`/`LigatureDecomposer`/
  `FormSelectorModel`) goes through Core Text shaping/ZWJ harvest only —
  this module never constructs or compares a U+FB50-range presentation-form
  scalar.
- **D-220 mark affine chain, normative.** `MarkAttachmentController
  .reattach` implements the exact formula (`target.affine⁻¹(mark
  .worldPosition) − target.affine⁻¹(target.worldPosition)`), independently
  of `MKRender`'s own D-220 implementation (`MKArrangedGeometry`) — the two
  never share code, so their agreement (`T-ARR-3`) is a real cross-check.
- **Both levels lose nothing.** `LevelMapping`/`ArrangedCompositionIndex`
  read `MKProvenance` directly; switching levels is a VIEW change over one
  retained composition, never a data conversion.

## Documented deviations from the packet's literal task prose

(Full detail in each file's header comment; summarized here per the
packet's own request to "stop-and-report on locked-decision conflicts.")

- **Task 7 "restore" mechanism.** Re-resolves both letters' forms via the
  same D-107 ZWJ harvest used for `breakJoin` (matching ARCHITECTURE §7.3
  literally: "Restoring a join re-resolves both letters' forms the same
  way and clears `brokenByUser`"), rather than reading a stored
  `preBreakSnapshot` field — `MKGlyphNode` has no such field, and adding
  one is outside this packet's fence (`MKModel`). Still satisfies
  "break→restore round-trips to Equatable-identical nodes" because D-107's
  harvest is designed to reproduce exactly the glyph Core Text would have
  chosen in true context.
- **`ArrangedComposition.nodes` ordering.** Emitted in LOGICAL cluster
  order (not a separate visual-order walk) — `provenance.visualIndex` still
  carries the accurate visual order for consumers that need it (WS-06 tab
  cycling). Safe for pixel fidelity because `MKArrangedGeometry` composes
  every child's world transform independently — see
  `ArrangeDeriver.swift`'s file header for the full argument.
- **Multi-line "child group per line".** `MKArrangedChild`'s closed D-111
  set has no group/line-wrapper case. Satisfied structurally by baking each
  line's origin offset directly into every child's `layout.position` (a
  flat list, already spatially partitioned per line) rather than an
  explicit nested grouping node.
- **Fused-mark substitution noise.** A `.baseWithMarks` cluster where Core
  Text fused the mark into the base glyph (no distinct glyph to extract)
  still gets its own `MKMarkNode` (provenance/selectability, D-105 "no mark
  is orphaned") with a `nil` outline — `MKRender`'s `ArrangedDrawer` records
  a benign `.missingOutline` substitution when it draws these (correct
  visual result: nothing extra to paint, the pixels are already in the
  base's own outline). Flagged for WS-07/WS-08 as a possible future
  `isProvenanceOnly` flag if a consumer ever gates on a zero-substitution
  report.

## P6 completion (Run-3, this session — see `docs/impl-log/WS-04.md` Session 3)

- **WS-16 `cursiveAttached` threaded through derivation.** Every
  `MKProvenance` this module constructs (`ArrangeDeriver.makeGlyphNode`/
  `appendLigature`/`appendMarkOnly`) now carries `cursiveAttached`, mirrored
  straight off `MKShapedRun.cursiveAttached[glyphIndex]` at the exact glyph
  captured — pure provenance, never consulted by geometry (WS-16's own
  Finding 5: the captured position already IS the cursive-adjusted answer).
- **Join-break/decompose fidelity note surfaced.** `JoinController
  .JoinEditResult` and `LigatureDecomposer.DecomposeResult` both gained a
  `cursiveFidelityNote: Bool` field — `true` when the original (pre-reshape)
  node(s) were `cursiveAttached`, meaning the D-107 ZWJ-harvest reshape may
  not reproduce the exact contextual glyph a real neighbor would trigger
  (WS-16 Finding 6). Same accepted-by-design, non-blocking disposition as
  D-222's T-AR-60 (single-glyph scale inside a joined word) — a hint for a
  future canvas consumer, not a correctness requirement.
- **Multi-mark stack manipulation completion.** `MarkAttachmentController
  .reattach` now assigns a non-colliding `stackIndex` when a mark moves to a
  base that already has sibling marks (paint/z-order metadata,
  `MarkNode.swift`'s own "shadda below, fatha above" doc comment) — computed
  as one past the highest sibling index on the target, excluding the mark
  itself (so a same-base round-trip, e.g. T-ARR-3's detach→rotate→re-attach,
  stays a no-op). Real-derivation regression coverage added for the packet
  §6 شدّة+فتحة fixture (two stacked marks on a dal: both follow on base
  move; detaching only one leaves its sibling still following) —
  `MarkAttachmentControllerTests.stackedMarksBothFollowTheDalOnMove`/
  `.detachingOnlyOneStackedMarkLeavesItsSiblingFollowing`. Real-font finding
  logged there: Geeza Pro's `MKMarkAttacher` output FUSES shadda+fatha into
  one combined `MKMarkNode`, while Amiri keeps them as two separately
  stack-indexed nodes — both legitimate, font-dependent capture outcomes;
  the fixture uses Amiri since it needs the two-marks-separately case.
- **D-222 per-font arrange-fidelity sweep.** `Tests/MKArrangeTests/
  PerFontArrangeFidelitySweepTests.swift` — the automated functional twin of
  T-AR-31 (derivation fidelity) and T-AR-36..38 (decompose/opt-out/recompose
  round trip) run across all 20 fonts currently released into
  `Sources/MKFonts/Resources/catalog-seed.json`. All 20 pass derivation
  fidelity (≤0.5%); all 20 complete decompose→recompose without error
  (لا fuses into a decomposable ligature on 12 of the 20 — font-dependent,
  not a failure, matching this repo's own "do not hardcode glyph counts"
  precedent; of those 12, 7 land inside the D-221 clamp and 5 correctly
  auto-refuse to default-forms mode). Full per-font table in
  `docs/impl-log/WS-04.md` Session 3.

## Deferred to the next slice (P6 / WS-06)

- Popover/chip rendering for `FormSelectorModel` (the model itself ships
  now).
- Gesture-driven mark drag, ligature decompose/recompose confirmation UI,
  join-break boundary picking UI — all WS-06 (`MKCanvas`), out of this
  packet's scope regardless of slice.
- ~~`MKArrangedCompositionCommand` journal-coder registration~~ **DONE**
  (Run-3 session): the type is retired in favor of `MKPersistence`'s
  canonical `MKReplaceNodesCommand`, already registered in
  `MKCommandCoder`'s closed switch — every arrange operation (derive,
  revert, join break/restore, decompose, recompose, mark attach/detach/
  move, style/transform edits) is journal-replayable end to end. See
  `docs/impl-log/WS-04.md` and `Tests/MKArrangeTests/JournalRoundTripTests.swift`.
- Arrange-on-path (`PathPlacementProviding` ships as a seam; WS-05 owns the
  real arc-length conformer and the arrange-on-path integration test).
- DEBUG harness (`Makhtoot/App/Debug/ArrangeHarnessView.swift`, packet §8) —
  outside this run's fence (`Makhtoot/App/` is explicitly excluded).
