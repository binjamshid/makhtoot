# WS-04 — Arrange Mode Engine

Run-1 agent task packet for Makhtoot (مخطوط). Governed by FOUNDATION.md. Owns
`MKArrange`. This packet turns WS-03's shaping capture into the product's headline
feature: Arrange Mode (وضع الترتيب).

## 1. Mission

Implement the derivation pipeline that converts a Live Text object (or Path Text object)
into an **Arranged Composition** — the non-reflowing structure of `GlyphNode`s,
`MarkNode`s and `LigatureGroup`s defined in WS-02's model — with complete provenance
(source codepoints, glyph ids, font refs, joining forms, cluster ids, bidi levels,
visual indices) and a retained `SourceTextBackup` making the operation reversible. On top
of derivation you implement the four manipulation mechanics the founder locked: join
break/restore with a visual 4-form selector (isolated/initial/medial/final realized via
WS-03's ZWJ resolver), ligature decompose/recompose with visual-fidelity offsets
(decomposed constituents keep the original ligature's look by default; explicit opt-out
to default forms), mark attach/detach/follow-base behavior, and revert-to-text with
confirmation that discards manual arrangement and restores the live text object.

Everything is expressed as `MKCommand`s over the value-type scene (WS-02 undo stack), so
every arrange operation is undoable and autosaved. The engine is UI-free: WS-06 renders
the form-selector popover and confirmation dialogs; you expose pure models
(`FormSelectorModel`, decompose options, revert preflight) they bind to. Fidelity is the
bar: entering Arrange Mode must be pixel-identical to the live rendering (positions come
straight from capture), and revert must restore the exact original string and style.

## 2. Scope

**IN**
- `ArrangeDeriver`: ShapingCaptureResult (+ path layout from WS-05 when arranging path
  text) → `ArrangedComposition` inside an `arranged` scene node; pixel-fidelity checks.
- Two-level editing support: mapping utilities glyph-level ↔ Unicode-letter-level
  selection (cluster map retained in the composition) so switching levels loses nothing.
- Join break/restore engine + `FormSelectorModel` (valid forms, previews, coerced flags).
- Ligature decompose/recompose engine with fidelity-offset placement + opt-out.
- Mark attachment controller: attach/detach/move/follow-base propagation rules.
- Revert-to-text service (confirmation contract, restoration, discard semantics).
- Arrange-time snapshot of style state; per-node transform/style edit helpers used by
  the inspector (thin wrappers emitting `MKCommand`s).
- Arrange of multi-line live text (per-line node groups preserving line origins).

**OUT**
- Gesture handling, selection UI, popover UI (WS-06).
- Shaping/capture internals (WS-03), path layout math (WS-05).
- Rendering (WS-07). Export provenance serialization (WS-08 reads model fields).
- No auto-reflow of arranged content ever — not a feature to build, an invariant to
  enforce (INV: arranged nodes never reshape implicitly).

## 3. Dependencies

**Upstream:** WS-01 (`MKFoundation`), WS-02 (`MKModel` arranged types, commands, undo),
WS-03 (`ShapingCaptureResult`, `FormResolver`, `GlyphPathProvider`), WS-05 only for
arrange-on-path entry point (interface: WS-05 hands you glyph placements in path space;
you may develop against a straight-line fake conforming to the same
`PathPlacementProviding` protocol). **Stubs you may rely on:** `SystemFontStubProvider`
(SF Arabic) until WS-09; `StubEntitlementResolver` (Arrange Mode is not premium-gated —
BRIEF gives free tier "full editing").

**Downstream consumers:** WS-06 (invokes derive/break/decompose/revert via commands;
binds FormSelectorModel), WS-07 (renders arranged nodes), WS-08 (SVG/PDF provenance),
WS-13 (menu wiring).

## 4. Locked decisions binding this packet (quoted)

- **D-106**: "Entering Arrange Mode snapshots the shaped result into an Arranged
  Composition: Glyph Nodes (glyph id, font ref, path, position, advance, joining state,
  source codepoints), Mark Nodes (attached, relative offset, follow-base default),
  Ligature Groups (member glyph node + constituent codepoints + decomposable flag).
  Source string + full style state stored as Source Text Backup; revert requires
  confirmation and discards arrangement."
- **D-107**: "To realize a chosen form for a letter, reshape the single letter in a
  synthetic context using U+200D ZWJ … then harvest that glyph. … Store as `JoiningForm`
  enum + resolved glyph id."
- **D-108**: "Decomposing a Ligature Group reshapes constituents with joining-preserving
  context, then places them with computed offsets matching the original ligature bounds
  (visual fidelity default); user opt-out switches to default spacing/forms.
  Recomposition restores the stored original ligature glyph."
- **D-109**: "arranged nodes keep `bidiLevel` + visual index so Latin/Arabic sub-runs
  stay coherent."
- **D-111**: "Arranged children: glyph/mark/ligature nodes with provenance (codepoints,
  glyph id, font reference, joining form, cluster id)."
- BRIEF (binding requirements): "Arranged compositions never auto-reflow. Every glyph,
  mark, and ligature component is independently selectable/transformable"; "Both levels
  supported: shaped-glyph manipulation AND underlying Unicode-letter manipulation";
  "Joining preserved by default; breaking joins is explicit"; "Tashkeel … attach to base
  by default, follow it, and are individually selectable/detachable/movable".

## 5. Task breakdown (ordered)

1. **`PathPlacementProviding` protocol** (shared seam with WS-05): supplies per-glyph
   final position + rotation for arrange-on-path; ship `IdentityPlacement` (straight
   baseline) used for plain live text. *Accept:* protocol documented; WS-05 signs off on
   the shape (record in CONTRACTS.md).
2. **`ArrangeDeriver.swift` core**: input `(sourceText, MKTextStyle,
   ShapingCaptureResult, PathPlacementProviding)` → `ArrangedComposition`. Per shaped
   glyph: create `GlyphNode` with outline path (from `GlyphPathProvider`), position =
   captured line-relative position transformed to node-local space, advance, joining
   form (from `JoiningAnalyzer`), source codepoints + `clusterID` + `bidiLevel` +
   `visualIndex` (D-109/D-111). Marks → `MarkNode` with `attachedTo` base id,
   `relativeOffset` from capture, `followsBase = true`. Ligature clusters →
   `LigatureGroup` wrapping the glyph node, `constituentCodepoints`,
   `decomposable = true` (false for single-codepoint clusters). Multi-line: one child
   group per line with line origin offsets. Store `SourceTextBackup{string, style,
   pathData?}`. *Accept:* derived composition for "بسم الله" has node counts consistent
   with capture; every GlyphNode has non-empty codepoints; every MarkNode resolves its
   base; every node id unique.
3. **Fidelity invariant test**: render (via WS-07 snapshot renderer once available; until
   then, a local CG rasterizer in tests) live text vs derived composition of the same
   fixtures at 3× scale; per-pixel diff ≤ 0.5 % differing pixels. Fixtures: "لا",
   "مُحَمَّدٌ", "عام ٢٠٢٦ / 2026", two-line paragraph. *Accept:* diff gate passes; the
   local test rasterizer draws both through identical CG state (no antialias variance).
4. **`arrangeCommand`**: `MKCommand` replacing a `liveText`/`pathText` node with the
   `arranged` node at same transform/z; inverse restores the original node exactly.
   *Accept:* undo of arrange restores byte-identical source node (Equatable).
5. **Two-level mapping utilities** `LevelMapping.swift`: for a selected set of glyph/
   mark/ligature nodes, return the covering codepoint ranges (letter level) and vice
   versa — letter selection → node set (via retained cluster map, stored in
   `ArrangedComposition.clusterIndex`). Used by WS-06 to switch selection granularity.
   *Accept:* selecting the lam-alif ligature node ↔ codepoints {ل,ا} both directions;
   selecting fatha's base letter includes the base but not the mark at letter level with
   `includeMarks` option toggling it.
6. **`JoinController.break`**: breaking the join between adjacent letters A|B (user picks
   a boundary): affected letters are re-realized via `FormResolver` — A gets its
   pre-boundary form recomputed as if at word-end (final or isolated depending on its
   other neighbor), B as if word-start (initial or isolated). Replace glyph ids + paths
   in place, KEEP positions (no reflow — D-106 spirit: arranged geometry is user-owned;
   width delta is recorded in `formDelta` metadata but not auto-applied), set
   `joinBrokenAfter` flag on A's node. Marks follow their bases. *Accept:* breaking
   م|ح in derived "محمد": م becomes final-form glyph, ح becomes initial-form; positions
   unchanged; undo restores original glyph ids/flags.
7. **`JoinController.restore`**: inverse operation — restore stored original glyph ids
   (kept in `preBreakSnapshot` inside the node) and clear flags. *Accept:* break→restore
   round-trips to Equatable-identical nodes.
8. **`FormSelectorModel`** (D-106/D-107 + BRIEF "offer a visual selector"): for a broken
   letter, expose the four `JoiningForm` options with per-form preview path + advance
   (from `FormResolver`), `isValid` (right-joining letters: initial/medial invalid —
   resolver `wasCoerced` → disabled option), current selection; `select(form:)` emits an
   `MKCommand` swapping glyph id/path and recording `chosenForm`. *Accept:* model for ح
   lists 4 valid options with distinct previews; for د exactly isolated+final enabled;
   command undoable.
9. **`LigatureDecomposer.decompose` (fidelity mode, D-108, algorithm normative per
   D-221)** — the tricky algorithm:
   a. Constituents C1..Cn from `constituentCodepoints` (logical order).
   b. Realize each constituent with joining-preserving context: constituent i gets the
      joining form it would have INSIDE the original sequence (C1 initial-or-isolated
      per outer neighbors + `joinBrokenAfter` state; inner constituents medial/final) —
      forms computed by `JoiningAnalyzer` on the constituent string embedded in its
      original neighborhood, glyphs via `FormResolver`.
   c. Fidelity placement — THIS is the normative n-ary placement algorithm (D-221; any
      "proportional" description elsewhere, e.g. ARCHITECTURE §7.5 prose, is subordinated
      to this spec): shape the constituent string standalone (same font/features) to get
      natural relative advances; solve a single affine fit — uniform scale CLAMPED to
      [0.85, 1.15] + per-component x-offsets — mapping the standalone assembly's union
      bounds onto the ORIGINAL ligature glyph's bounds, with the first and last
      constituents edge-aligned to the original bounds and interior constituents'
      `fidelityOffset`s read directly off the fit (not a proportional approximation).
      `fidelityOffset` = fitted position − naive advance position. Store
      `fidelityOffsets` on each new GlyphNode + keep the original glyph id/path in
      `LigatureGroup.recomposeSnapshot`.
   d. Marks that were attached to the ligature glyph re-attach to the nearest constituent
      by horizontal overlap of mark x-center vs constituent bounds (tie → later-in-
      logical-order base, documented); offsets recomputed to preserve absolute position.
   e. Pre-flight clamp-refusal fallback (D-221): before applying step c, compute the
      natural (unclamped) scale factor the fit would require. If it falls outside
      [0.85, 1.15], fidelity mode is REFUSED for that ligature — decomposition
      automatically falls back to default-forms mode (task 10) with the existing notice
      UX (mirrors the R-21.9 low-confidence pattern) instead of silently applying a
      distorted clamped fit.
   *Accept:* decomposing "لا": two GlyphNodes (lam final-ish form per context, alef),
   union bounds within 2 % of original ligature bounds, per-pixel overlay diff of the
   assembly vs original ≤ documented threshold (fidelity is approximate — record actual
   number, holds only within the clamp per D-221); marks preserved in "لَا" case; a
   fixture whose natural fit exceeds the clamp asserts automatic fallback to
   default-forms mode with the notice surfaced.
10. **Decompose opt-out (default-forms mode)**: same constituents, but placed by natural
    advances from the standalone shaping, no fidelity fit (D-108 "user opt-out switches
    to default spacing/forms"). Option object `DecomposeOptions{fidelity: Bool = true}`.
    *Accept:* opt-out layout differs from fidelity layout; both undoable.
11. **`LigatureDecomposer.recompose`**: restore `recomposeSnapshot` original glyph node,
    re-absorb marks (restore original attachments), remove constituents. Dirty check
    (D-221, amends the prior transform-only check — fixes silent style-edit loss): before
    recomposing, compare each constituent's FULL current node state — transform AND style
    (fill/stroke/opacity/shadow) — against the state captured immediately after
    decomposition. Blocked (throws typed error with Arabic message "لا يمكن إعادة الدمج
    بعد تعديل الأجزاء" unless `force`) on ANY delta in that comparison, not transform
    alone — WS-06 shows the choice "استبدال التعديلات" (replace edits) as a confirmation
    whenever the dirty check trips. *Accept:* decompose→recompose with no edits =
    Equatable round-trip; a transform-only edit throws unless forced (as before); a
    style-only edit (e.g. recolor a constituent, no transform change) also throws unless
    forced (T-ARR-LIG-STYLE fixture — this is the regression the widened check fixes).
12. **`MarkAttachmentController`**: detach (mark keeps absolute position, `attachedTo`
    nil, `followsBase` false); re-attach to any base glyph — recomputes `relativeOffset`
    in the BASE's component-local space per D-220's normative formula
    (`relativeOffset = base.affine⁻¹(mark.worldPos) − base.affine⁻¹(base.worldPos)`),
    never as a raw world-space delta; move-while-attached updates `relativeOffset`;
    follow-base: when a base GlyphNode's transform changes, all attached marks with
    `followsBase` translate/rotate/scale with it — implemented as command expansion in
    the arrange command layer (base transform command also rewrites dependent marks) so
    the scene stays a flat value tree. *Accept:* moving ب in derived "بَ" moves the
    fatha; after detach it doesn't; re-attach to a different base works and undo restores
    prior attachment.
13. **Style/transform edit helpers**: per-node fill/opacity/stroke/shadow, kerning-like
    nudge (position deltas), baseline shift; group operations across a selection —
    emitted as coalescable `MKCommand`s for WS-06 inspector bindings. *Accept:*
    multi-select recolor of 3 glyph nodes = 1 undo step.
14. **`RevertService`** (D-106): preflight report {editedNodeCount, willDiscard:
    Bool = true} for the confirmation UI ("سيتم تجاهل الترتيب اليدوي" — manual
    arrangement will be discarded); `revertCommand` replaces `arranged` node with a
    rebuilt `liveText`/`pathText` node from `SourceTextBackup` (string + style + path
    data), same transform/z. Undo of revert restores the full arranged node. *Accept:*
    revert of an edited composition yields live text identical to pre-arrange original
    (string byte-equal, style Equatable); undo restores every manual edit.
15. **Never-reflow invariant enforcement**: `arranged` nodes ignore text-style mutations
    that would require reshaping (font change/size change APIs on arranged nodes are
    scale/transform ops only, or routed to revert-first flow). Add debug assertion +
    typed error `MKError.arrangedNodeCannotReshape`. *Accept:* attempting a font swap on
    an arranged node throws; scale path works.
16. **Multi-line + bidi coherence checks**: derive a two-line mixed fixture
    "التصميم Design\nعام ٢٠٢٦ — 2026"; assert per-line groups, visual indices per line,
    Latin sub-run nodes carry `bidiLevel` even, Arabic odd. *Accept:* assertions pass;
    manual harness screenshot logged.
17. **Perf pass**: derive 500-glyph paragraph < 100 ms off-main; break/decompose ops
    < 16 ms so WS-06 can run them inside an interaction. *Accept:* signpost measurements
    recorded (`arrangeDerive` signpost added to `MKSignpost`).
18. **Docs**: `MKArrange/README.md` — lifecycle diagram (live ⇄ arranged), fidelity
    algorithm walkthrough with "لا" numbers, invariants list. *Accept:* reviewed against
    ARCHITECTURE.md §5 outline.

## 6. Arabic-correctness notes (fixtures)

- **لا**: the canonical ligature — derive, decompose (fidelity + opt-out), recompose,
  revert; all four flows in one integration test.
- **الله**: derive must attach shadda and U+0670 correctly; decomposition availability is
  font-dependent — if the font produced a single cluster, `decomposable = true` and
  constituents are ا ل ل ه realized with correct forms (medial lams). Do not hardcode
  glyph counts; assert relations.
- **شدّة+فتحة**: "دَّ" in "شَدَّةٌ" — two stacked marks follow the dal on move; detaching
  only the fatha leaves shadda following.
- **Join break**: "محمد" break each boundary in turn; verify the 4-form selector shows
  correct valid sets (م dual-joining → 4; د right-joining → 2).
- **Mixed bidi**: "عام ٢٠٢٦ vs 2026" — arranged Latin digits remain LTR-ordered
  visually; letter-level selection of the Latin run maps to contiguous codepoints.
- **Tatweel**: "مـد" — tatweel becomes a GlyphNode (it is a letter-like base, not a
  mark); breaking around it behaves like a dual-joining letter.
- Revert confirmation strings in Arabic with Latin gloss comments; never auto-revert.

## 7. Packet acceptance criteria (gates)

- **Build gate**: `MKArrangeTests` green (`T-ARR-*`).
- **Fidelity gate**: live-vs-derived pixel diff ≤ 0.5 % on all §6 derivation fixtures
  (`T-ARR-FID-*`); ligature fidelity-decompose overlay within documented threshold
  (`T-ARR-LIG-*`).
- **Reversibility gate**: property test — random op sequences (break/restore/decompose/
  recompose/detach/attach/edit) fully undo to the derivation state; revert restores
  source exactly (`T-ARR-UNDO-*`, `T-ARR-REV-*`); gains the style-only-edit case per
  D-221's widened recompose dirty check — a sequence containing a style-only edit (no
  transform change) between decompose and recompose must trip the confirmation/force
  gate exactly like a transform edit does (`T-ARR-LIG-STYLE`).
- **Manual Arabic checklist**: harness walkthrough of §6 fixtures with screenshots
  (`T-ARABIC-M-ARR-*`).
- **Perf**: derive/ops budgets of task 17 met (`T-PERF-ARR-*`), supporting the D-115
  manipulation frame budget downstream.

## 8. Deliverables

- `MakhtootKit/Sources/MKArrange/ArrangeDeriver.swift`, `PathPlacementProviding.swift`,
  `LevelMapping.swift`, `JoinController.swift`, `FormSelectorModel.swift`,
  `LigatureDecomposer.swift`, `DecomposeOptions.swift`, `MarkAttachmentController.swift`,
  `ArrangeCommands.swift`, `RevertService.swift`, `ArrangeInvariants.swift`, `README.md`
- `MakhtootKit/Tests/MKArrangeTests/*` (fixtures, pixel-diff utilities, property tests)
- DEBUG harness: `Makhtoot/App/Debug/ArrangeHarnessView.swift`
- CONTRACTS.md update (PathPlacementProviding seam).

## 9. References

- ARCHITECTURE.md: §5 Arrange Mode Engine, §6 Tashkeel/Marks Mechanics, §7 Ligature &
  Joining Mechanics, §8 Bidi Model, §14 Undo/Redo & Autosave.
- PRD.md: §6 Arrange Mode, §7 Tashkeel & Marks, §8 Ligatures & Joining, §10 Layers &
  Inspector (edit helpers), §21 Edge-Case Compendium.
- BRIEF.md: "Arabic text & glyph engine" (Arrange Mode bullets, Q71 ligature fidelity).
- Market study §4: decompose-at-arrange strategy and provenance rationale[^23]; §3 gap
  matrix rows 1–2 (defensibility context).

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS04-A1: fidelity-fit algorithm for ligature decomposition (affine fit +
  stored offsets)", "WS04-A2: break-join keeps positions, records formDelta",
  "WS04-A3: follow-base implemented as command expansion over flat value tree",
  "WS04-A4: recompose blocked after constituent edits unless forced".
- Implementation log after tasks 3, 9, 14 with fidelity numbers and property-test seeds.
- Verification evidence: pixel-diff artifacts summary, harness screenshots per fixture,
  measured thresholds (store the actual ligature-fidelity percentage achieved).
- Update the per-font expectations memory entry started by WS-03 with arrange-level
  findings for Amiri/Noto once WS-09 fonts land.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Arabic engine — Arrange Mode creates separate arranged-composition structure derived from shaped run; retained source backup; revert w/ confirmation discards manual arrangement | T2 (`ArrangeDeriver`), T14 (`RevertService`) |
| Arabic engine — arranged compositions never auto-reflow; every glyph/mark/ligature independently selectable/transformable | T13 (edit helpers), T15 (never-reflow invariant enforcement) |
| Arabic engine — both levels: shaped-glyph AND Unicode-letter manipulation, switching level loses nothing | T5 (`LevelMapping`) |
| Arabic engine — joining preserved by default; breaking explicit; visual selector for isolated/initial/medial/final | T6–T8 (`JoinController`, `FormSelectorModel`) |
| Arabic engine — tashkeel attach to base by default, follow it, individually selectable/detachable/movable/transformable | T12 (`MarkAttachmentController`) |
| Arabic engine — ligatures: combined selectable object AND decomposable components; decomposition preserves original look by default, explicit opt-out to default forms (Q71) | T9–T11 (`LigatureDecomposer` fidelity/opt-out/recompose) |
| Arabic engine — per-object kerning/tracking/baseline shift/scale/rotation/opacity/outline/shadow/fill | T13 |
| Arabic engine — arranged path text keeps independent glyph adjustments | T1 (`PathPlacementProviding` seam), T2 (arrange-on-path input) |
