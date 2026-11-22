# Android Port — Batch 3 Task Packets

Batch 3 · Theme: **textengine (HarfBuzz bridge + line breaking split) ×2, textengine ×2 more ·
persistence ×3 · fonts core** · Gate: **G3**

Depends on G2 (`:mk-foundation`, `:mk-model`, `:mk-color`, `:mk-designsystem` green;
`:mk-model` proven byte-identical on the scene codec). Every `:mk-textengine`,
`:mk-persistence`, and `:mk-fonts` file this batch touches already exists as a
`throw MkNotYetPorted(...)` stub from Batch 1 · Agents 1.3/1.4. This batch is **8 agents**, not 7:
Agent 3.1 is split into **3.1a** (HarfBuzz shaping bridge + shaped models) and **3.1b** (line
breaking and paragraph layout — from-scratch ICU `BreakIterator` code with no `CTTypesetter`
equivalent to port, which is why it cannot share an agent with the bridge; spine §5.2). Dispatch
all eight agents in one message; they run concurrently and own disjoint file sets (Appendix).
Source of truth is the shipped Swift code at `MakhtootKit/Sources/**`, read in full for every file
listed in each port map below — real LOC via `wc -l`, no placeholders.

This is the batch where Core Text is replaced by HarfBuzz + FreeType through `:mk-native`
(D-303). Shaping correctness is non-negotiable (`CLAUDE.md`): a change that mis-shapes Arabic,
drops tashkeel, or breaks a ligature is never acceptable on either platform. Every legitimate
HarfBuzz↔Core Text difference must be recorded in `android/SHAPING_DELTAS.md` (D-325); an
unregistered delta fails G3.

---

### Batch 3 · Agent 3.1a — `mk-textengine` HarfBuzz shaping bridge + shaped models

**Depends on:** G2 · **Parallel-safe with:** every other Batch 3 agent
(including its sibling 3.1b, which reads this agent's output but does not edit it)

**Mission.** Port the shaping-capture core — `MKShapingEngine` (single-line capture only —
`shapeSingleLine`/`capture`, **not** `shapeParagraph`), `ShapingService`, `ShapingRequest`,
`ShapedModels`, `AttributedBuilder`, `GlyphPathProvider` (6 files, 847 LOC) — to `:mk-textengine`.
This is where Core Text's `CTLine`/`CTRun` capture is replaced by HarfBuzz `hb_buffer`/`hb_shape`
and FreeType glyph-outline extraction through `:mk-native`. This agent was split from a single
"Agent 3.1" into 3.1a/3.1b because line breaking and paragraph layout (owned by sibling Agent
3.1b) is genuinely new code with no `CTTypesetter` equivalent to port from, and does not belong in
the same unit of work as this HarfBuzz-bridge port. The two hardest correctness risks in this
agent's own scope: (1) the HarfBuzz buffer must be fed as UTF-16, not UTF-8 or raw codepoints, or
every persisted `utf16Range` in every arranged composition silently corrupts (`§8` task 3 below);
(2) `HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS` does **not** reproduce Core Text's per-character
cluster semantics for ligatures — see the `MKShapingEngine.swift` port-map row.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKTextEngine/MKShapingEngine.swift`, `ShapingService.swift`, `ShapingRequest.swift`, `ShapedModels.swift`, `AttributedBuilder.swift`, `GlyphPathProvider.swift` (6 files) | Source of truth for this port |
| `android/fixtures/shaping/**` (Batch 0.2) | Golden glyph ids/positions/advances/cluster maps/bidi levels per family — the acceptance oracle for this agent (D-324) |
| `android/fixtures/ligature/**` (Batch 0.2), specifically Core Text's per-component index entries for zero-advance ligature continuation glyphs | The measurable baseline for the cluster-merge divergence this agent's `capture()` must reproduce or explicitly diverge from (see port map) |
| `:mk-native`'s HarfBuzz/FreeType JNI facade (Batch 1.2) | The `hb_buffer_create`/`hb_buffer_add_utf16`/`hb_shape`/`FT_Load_Glyph`/`FT_Outline_Decompose` entry points this module calls through |
| `android/SHAPING_DELTAS.md` (create if absent) | D-325's delta register — every legitimate HarfBuzz↔Core Text difference must land here, classified A/B/C per spine §12 |
| `ANDROID_SPINE.md` §2 (D-303, D-325), §12 (delta classification) | The shaping-replacement decision, delta-register mechanism, and the A/B/C classification every registered delta must carry |
| `FOUNDATION.md` §3 (D-103) | iOS shaping-source-of-truth decision this module replaces |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/{MkShapingEngine,MkShapingService,MkShapingRequest,MkShapedModels,MkAttributedStringBuilder,MkGlyphPathProvider}.kt`
- `android/mk-textengine/src/test/kotlin/net/binjamshid/makhtoot/mk/textengine/{MkShapingEngine,MkShapingService,MkGlyphPathProvider}Test.kt`
- `android/SHAPING_DELTAS.md` (new — this agent creates it; every later text-engine/arrange/render
  agent, including sibling 3.1b, that finds a legitimate delta appends to it, never removes
  another agent's rows)
- `android/docs/impl-log/BATCH-3.1a.md`

**Never touch.** `:mk-textengine`'s other files (owned by 3.1b/3.2/3.3 — in particular, the
paragraph/line-breaking entry point is 3.1b's new file, not a function this agent implements
inside `MkShapingEngine.kt`). `:mk-native`'s C++ sources themselves (a needed binding change goes
to `android/docs/CONTRACT_CHANGES.md`). Any other `android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKShapingEngine.swift` (single-line portion only — `shapeSingleLine`, `capture`, `makeAttributed`'s two-pass kerning; the `shapeParagraph` multi-line entry point is Agent 3.1b's, see below) | 239 (whole file; this agent implements everything except the `shapeParagraph` body) | `MkShapingEngine.kt` | `CTTypesetterCreateWithAttributedString` → build an `hb_buffer_t` per bidi run (via `:mk-native`). **Buffer encoding is mandatory and explicit, not left to the native binding's default**: call `hb_buffer_add_utf16(buffer, text, textLength, itemOffset, itemLength)` — never `hb_buffer_add_utf8` or `hb_buffer_add_codepoints` — because `MkShapedModels`' `utf16Range`/`utf16Start`/`utf16Length` fields (Agent 3.1a's own `ShapedModels.swift` row below) assume `hb_glyph_info_t.cluster` values are indices into a UTF-16 buffer; HarfBuzz cluster values are indices into whatever encoding the caller fed the buffer, so feeding UTF-8 or codepoint-array input would silently corrupt every `utf16Range` in every persisted arranged composition without a single test failing locally. Add a dedicated unit test asserting `hb_buffer_add_utf16` is the call used (e.g. a surrogate-pair input whose cluster index would differ visibly under UTF-8 byte-offset indexing) — this is an explicit, checkable invariant, not merely a code-review expectation. Then set `hb_buffer_set_cluster_level(HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS)`, `hb_buffer_set_direction(HB_DIRECTION_RTL/HB_DIRECTION_LTR)` per ICU BiDi run (Batch 3.2 supplies the run map), `hb_buffer_set_script`/`hb_buffer_set_language`, then `hb_shape(font, buffer, features)`. **The cluster-level flag is not a drop-in parity guarantee** — corrected from an earlier draft that asserted it "matches Core Text's own cluster-boundary semantics": `HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS` **merges** the clusters of every character that forms a ligature into one shared cluster value, while `CTRunGetStringIndices` emits one per-character index entry per component, with zero-advance glyphs standing in for the non-first components. This is exactly the signal `LigatureDetector.swift` (Agent 3.3) uses to learn how many characters a ligature spans, and what `MKArrange/LigatureDecomposer.swift` (361 LOC, Batch 4's largest Arrange file) needs for component-level decomposition — a merged cluster silently loses that per-component boundary. Do not assume the two are interchangeable; prove it per family against `android/fixtures/ligature/**`'s Core Text per-component index entries (Batch 0.2), and where they diverge, this is a genuine, measurable Class B/C candidate (spine §12) for `android/SHAPING_DELTAS.md`, never a self-issued Class A pass. `CTLine`/single-line capture (`shapeSingleLine`) becomes: run ICU BiDi paragraph analysis (Batch 3.2) → one `hb_buffer` per bidi run → `hb_shape` each → concatenate results in visual order exactly as `CTLineGetGlyphRuns` already returns visually ordered runs, so the *output shape* (`MkShapedLine.runs` in visual order) is preserved even though the *construction path* is now explicit instead of delegated to one Core Text call. Kern-override two-pass logic (`makeAttributed`) ports unchanged as an algorithm (shape once to learn cluster boundaries, apply `hb_feature_t` `kern` adjustments — see 3.3's `MkFontFeatureControl` — on the second pass). `capture(_:...)` (the per-run glyph/position/advance/index/status extraction loop) → iterate `hb_buffer_get_glyph_infos`/`hb_buffer_get_glyph_positions`, mapping `hb_glyph_info_t.codepoint`→glyph id, `hb_glyph_info_t.cluster`→ the `CTRunGetStringIndices` equivalent (subject to the merge-divergence caveat above), `hb_glyph_position_t.x_advance/y_advance/x_offset/y_offset` (each in 26.6 fixed-point, `/64.0` to points — a new scale step Core Text's float output never needed) → `MkShapedRun.advances`/`.positions`, `hb_buffer_get_direction() == HB_DIRECTION_RTL` → `MkShapedRun.isRTL`. The cursive-attachment coverage lookup (`MKCursiveCoverageCache`, this file's `capture` loop) is owned by Agent 3.3 (`CursiveAttachment.swift`) — call its ported entry point, do not re-implement here. `shapeParagraph`'s public signature is ported here as a thin delegator (constructor/parameter-injected) to Agent 3.1b's new paragraph-layout entry point — this agent does not implement line breaking itself. |
| `ShapingService.swift` | 141 | `MkShapingService.kt` | `actor` + LRU cache (cost = glyphCount × 64 bytes, 32 MB default) → Kotlin `class` guarded by `kotlinx.coroutines.sync.Mutex`, same `LinkedHashMap`-based LRU-eviction-by-total-cost loop. `OSSignposter.beginInterval("typingEcho")`/`endInterval` (wrapping single-line shapes, the D-115/`R-22.2` <50 ms typing-echo budget) → `androidx.tracing.Trace.beginSection("typingEcho")`/`endSection()` (per Batch 2.1's `MkLog`/`MkSignpost` port). `captureResult(_:)` (full capture + joining/mark/ligature analysis for Batch 4's Arrange derivation) calls into 3.3's `MkJoiningAnalyzer`/`MkMarkAttacher`/`MkLigatureDetector` — same cross-file dependency shape as the Swift original, ported 1:1 as an algorithm. |
| `ShapingRequest.swift` | 40 | `MkShapingRequest.kt` | `MkShapingRequest` data class (text/style/frame) + `fontHandle` extension property — direct port, `Hashable` → Kotlin `data class` auto-`equals`/`hashCode`. |
| `ShapedModels.swift` | 229 | `MkShapedModels.kt` | `MkGlyphAddress`, `MkResolvedRunAttributes`, `MkShapedRun`, `MkLineMetrics`, `MkShapedLine`, `MkShapedParagraph` — direct field-for-field data-class port. `CGPoint`/`CGSize` arrays → `List<MkPoint>`/`List<MkSize>` (Batch 2.1's geometry types). `boxWidth`/`boxHeight(lineHeight:)`/`lineOriginX(lineWidth:baseDirection:)` (pure measurement math, the MASTER-PLAN Phase-2 RTL-alignment and text-clipping bug fixes) port unchanged — these are exactly the functions `:mk-canvas`/`:mk-render` (Batch 4/5) depend on to agree on the same painted extent, so any deviation here is a downstream rendering bug, not just a text-engine one. `MkShapedParagraph` is the type Agent 3.1b's line-breaking output populates — read its shape, do not redefine it. |
| `AttributedBuilder.swift` | 107 | `MkAttributedStringBuilder.kt` | `NSAttributedString`/`NSMutableParagraphStyle` has **no Android analogue** — there is no "build a rich, range-styled string object" step in the HarfBuzz pipeline. This becomes a plain Kotlin data mapper: `MkAttributedStringBuilder.make(text: MkSourceText, style: MkTextStyle, resolveFont: (MkTextStyle) -> NativeFontHandle, extraKerning: List<...>): MkAttributedSpec` producing a small intermediate spec (base font handle + paragraph direction + per-range `[MkStyleRun → resolved font/kern/baseline]` list + forced-direction override flag) that `MkShapingEngine` consumes to configure each `hb_buffer` and its per-range `hb_feature_t` ranges directly — same two responsibilities (whole-string base attributes, per-range style-run overrides) as the Swift file, restructured around HarfBuzz's shape-call-parameters model instead of an attributed-string object model. The forced-direction override (`kCTWritingDirectionOverride`, for `.rightToLeftOverride`) → `hb_buffer_set_direction(HB_DIRECTION_RTL)` set unconditionally on the buffer regardless of the run's own detected script direction. |
| `GlyphPathProvider.swift` | 91 | `MkGlyphPathProvider.kt` | `actor` + LRU cache (512 entries default) → Kotlin `class` + `Mutex`, same cache-key shape (`postScriptName`/font-handle, pointSize, glyphID). `CTFontCreatePathForGlyph` → `FT_Load_Glyph(face, glyphIndex, FT_LOAD_NO_SCALE)` + `FT_Outline_Decompose(outline, &funcs, user)` through `:mk-native`, with the FreeType outline-decompose callback set (`move_to`/`line_to`/`conic_to`/`cubic_to`) writing directly into `:mk-model`'s flat `MkPathData` command stream (op-codes 0/1/2/3/4 exactly as `Batch 2.2`'s port map defines) — **this native call already produces the flat command list**, so unlike the iOS side (`MKPathData.from(_ cgPath:)` converting a `CGPath` after the fact), there is no intermediate `android.graphics.Path` object in this path at all; the JNI boundary hands back `DoubleArray`/`FloatArray` command data directly. Negative-caching of glyphs with no outline (`MKPathData(commands: [])` → `null` at the public API) ports unchanged. |

**Tasks.**
1. Read all 6 Swift files above in full; confirm the 847 LOC total via `wc -l`.
2. Confirm `:mk-native`'s Batch-1.2 HarfBuzz/FreeType JNI facade exposes buffer-create,
   `hb_buffer_add_utf16`, direction/script/language/cluster-level setters, `hb_shape`,
   glyph-info/position readback, and `FT_Load_Glyph`/`FT_Outline_Decompose` entry points; file
   any gap to `android/docs/CONTRACT_CHANGES.md` rather than editing `:mk-native` directly.
3. Port `MkShapedModels`/`MkShapingRequest` first (pure data shapes, zero native dependency).
4. Port `MkAttributedStringBuilder`'s intermediate spec, then `MkShapingEngine`'s single-line
   capture path, using `hb_buffer_add_utf16` explicitly at every buffer-construction call site;
   write the surrogate-pair UTF-16-cluster-indexing test described in the port map before moving
   on. Prove single-line shaping matches `android/fixtures/shaping/**` for every family.
5. Prove or disprove the `HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS` cluster-merge-vs-Core-Text
   divergence against `android/fixtures/ligature/**`'s per-component index entries; register any
   real divergence in `android/SHAPING_DELTAS.md` with its correct A/B/C class (spine §12) — a
   dropped or merged ligature-component boundary that changes what downstream cluster/ligature
   code sees is a Class B candidate, not something this agent may self-register as Class A.
6. Add a thin `shapeParagraph` delegator on `MkShapingEngine` to Agent 3.1b's paragraph-layout
   entry point (read 3.1b's public shape once it lands; coordinate the exact call signature via
   `android/docs/CONTRACT_CHANGES.md` if the two disagree — do not implement line-breaking here).
7. Port `MkGlyphPathProvider`.
8. Run every family in `android/fixtures/shaping/**` through the ported engine; for any
   genuine, explainable divergence (font/input/delta/reason), add a row to
   `android/SHAPING_DELTAS.md` with its A/B/C class rather than silently accepting or silently
   forcing a match.
9. Port the existing `MKTextEngineTests` shaping-capture cases (`T-TXT-1`, `T-TXT-9`, `T-TXT-10`,
   `T-TXT-11`) 1:1 as JUnit tests against the same fixtures.

**Acceptance.**
- `./gradlew :mk-textengine:testDebugUnitTest` green
- `./gradlew :mk-textengine:lintDebug` green
- Requirements covered: `R-5.2` (contextual shaping typing behaviour), `R-5.9` (variable-font axis
  exposure depends on font resolution reaching this engine), `R-22.2` (typing echo <50 ms)
  — `R-5.5` (line-breaking/wrapping) is Agent 3.1b's, not this agent's
- Tests ported: `T-TXT-1` (shaping capture parity with CTLine drawing — re-scoped to "parity with
  the golden fixtures," the Core Text baseline itself), `T-TXT-9` (numeral systems), `T-TXT-10`
  (kerning/tracking/baseline survive capture), `T-TXT-11` (empty/degenerate input safety)
- Fixtures consumed: `android/fixtures/shaping/**`, `android/fixtures/ligature/**` (cluster-merge
  divergence check) across all 45 bundled families
- G3's shaping-parity denominator (spine §12): measured per **(font family × corpus string ×
  glyph) triple**, not "fixtures" — gate passes iff **zero Class-B deltas**, **Class-A deltas
  ≤ 1% of triples**, and **every Class-C row is signed off** in `android/SHAPING_DELTAS.md`; the
  earlier "≥ 99% of golden fixtures" wording named no unit and is retired
- `hb_buffer_add_utf16` is the buffer-construction call at every shaping call site in this
  agent's files (`grep -rn 'hb_buffer_add_' android/mk-textengine/src/main/kotlin/.../MkShapingEngine.kt`
  finds only `hb_buffer_add_utf16`), with a passing surrogate-pair cluster-indexing test
- Stub count for this agent's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-3.1a.md`

---

### Batch 3 · Agent 3.1b — `mk-textengine` line breaking and paragraph layout

**Depends on:** G2, and reads Agent 3.1a's `MkShapingEngine.kt`/
`MkShapedModels.kt` (same-batch, concurrent — read the signatures, coordinate any mismatch via
`android/docs/CONTRACT_CHANGES.md`) · **Parallel-safe with:** every other Batch 3 agent

**Mission.** Implement multi-line paragraph layout — the Android replacement for
`MKShapingEngine.swift`'s `shapeParagraph` (`CTTypesetterSuggestLineBreak`-driven on iOS) — as new
code with **no Swift source to port line-for-line**. HarfBuzz has no line-breaking or
paragraph-layout API at all; it only shapes a single run of text handed to it. This agent exists
as its own unit of work, split out from what was originally "Agent 3.1," precisely because this
gap makes it a different kind of task from the HarfBuzz-bridge port in 3.1a: from-scratch
ICU `BreakIterator`-driven algorithm design, not a mechanical Swift→Kotlin translation. The
central correctness risk is that a different, legally-valid line-breaking algorithm can choose a
different break point than Core Text at the same width — this is expected, not a defect, but it
must be classified and signed off correctly (spine §12), not pre-registered as a blanket pass.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKTextEngine/MKShapingEngine.swift` (`shapeParagraph` only — the function this agent's new code replaces; every other part of this file is Agent 3.1a's) | The behavioral contract (inputs/outputs, `MkShapedParagraph` shape) this agent's new algorithm must satisfy, even though the line-breaking algorithm itself does not port line-for-line |
| Agent 3.1a's `MkShapingEngine.kt` (`shapeSingleLine`), `MkShapedModels.kt` (read, do not edit — same-batch sibling output) | The single-line shaping entry point this agent's greedy-fit loop calls per candidate span, and the `MkShapedParagraph`/`MkShapedLine` types this agent populates |
| `android/fixtures/shaping/**` (Batch 0.2), multi-line cases specifically | Used to verify output is a legible, correctly-ordered wrap — not a break-point-for-break-point byte match (no such oracle exists for this agent, see Mission) |
| `android/SHAPING_DELTAS.md` (work item 3.1a owns creation, append only) | Where this agent's Class C line-breaking-algorithm-class delta is recorded, pending founder sign-off |
| `ANDROID_SPINE.md` §2 (D-303, D-325), §12 (delta classification, Class C sign-off requirement) | The shaping-replacement decision and — critically for this agent — the corrected rule that a whole-algorithm-class delta is Class C (founder sign-off per row), not something an agent may pre-register as a blanket pass before running |
| `FOUNDATION.md` §3 (D-103) | iOS shaping-source-of-truth decision this module replaces |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkParagraphLayoutEngine.kt` (new — no direct Swift source, see Mission)
- `android/mk-textengine/src/test/kotlin/net/binjamshid/makhtoot/mk/textengine/MkParagraphLayoutEngineTest.kt`
- `android/docs/impl-log/BATCH-3.1b.md`

**Never touch.** `MkShapingEngine.kt`, `MkShapingService.kt`, `MkShapingRequest.kt`,
`MkShapedModels.kt`, `MkAttributedStringBuilder.kt`, `MkGlyphPathProvider.kt` (3.1a's — this agent
calls into `MkShapingEngine.shapeSingleLine` but does not edit its file). `android/SHAPING_DELTAS.md`
is append-only for this work item. Work item 3.1a owns creation. `:mk-textengine`'s other files (owned by
3.2/3.3). `:mk-native`'s C++ sources. Any other `android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKShapingEngine.swift`'s `shapeParagraph` function (no separate Swift file — this is the multi-line entry point inside the file Agent 3.1a otherwise owns) | *(counted in 3.1a's 239-LOC total; this agent's Kotlin is new code, not a line-count-matched port)* | `MkParagraphLayoutEngine.kt` | HarfBuzz has no `CTTypesetter` equivalent. Use `android.icu.text.BreakIterator.getLineInstance(Locale("ar"))` to enumerate legal line-break opportunities over the paragraph's UTF-16 text, then a greedy fit loop: shape each candidate span via Agent 3.1a's `MkShapingEngine.shapeSingleLine`, sum `hb_glyph_position_t.x_advance` (already unscaled to points by 3.1a's `capture()`), and back off to the last legal break opportunity that fits `maxWidth`, assembling one `MkShapedLine` per accepted line into the `MkShapedParagraph` result type 3.1a's `MkShapedModels.kt` defines. This is genuinely new algorithm design, not a line-for-line port — there is no Core Text source to translate. |

**Tasks.**
1. Read `MKShapingEngine.swift`'s `shapeParagraph` function and its call sites in full; read
   Agent 3.1a's `MkShapedModels.kt`/`MkShapingEngine.kt` (`shapeSingleLine`) signatures once they
   land (same-batch, concurrent — coordinate via `android/docs/CONTRACT_CHANGES.md` if the
   expected signature differs from what 3.1a actually ships).
2. Design the ICU `BreakIterator`-based greedy-fit line-breaking loop described in the port map.
3. Implement `MkParagraphLayoutEngine`, calling Agent 3.1a's `shapeSingleLine` per candidate span;
   wire the thin delegator on `MkShapingEngine.shapeParagraph` that 3.1a's own Task 6 adds.
4. Verify output against `android/fixtures/shaping/**`'s multi-line cases for "legible, correctly-
   ordered wrap," not byte-identical break points — no such 1:1 oracle exists, since a different,
   legally-valid algorithm may choose a different break point at the same width.
5. Register the line-breaking-algorithm-class difference in `android/SHAPING_DELTAS.md` (append
   only) as a **Class C** entry (spine §12) — an algorithm-class difference that is neither a
   sub-pixel/rounding artifact (Class A) nor a correctness violation (Class B), and therefore
   requires founder sign-off per row. **Do not pre-register this as a blanket Class A pass before
   running** — an earlier draft of this packet let the line-breaking algorithm be self-registered
   as a delta class before execution, which the spine correction retires explicitly.
6. Port or write new JUnit tests covering: paragraph wraps at a legal ICU break opportunity,
   never mid-cluster; RTL paragraph line order; mixed Arabic-Latin paragraph wrap; degenerate
   input (empty string, single overlong word exceeding `maxWidth`).

**Acceptance.**
- `./gradlew :mk-textengine:testDebugUnitTest` green
- `./gradlew :mk-textengine:lintDebug` green
- Requirements covered: `R-5.5` (line-breaking/wrapping)
- Tests ported: no direct `T-TXT-*` id names this agent's algorithm 1:1 (no Core Text line-for-
  line source exists); new tests cover the cases in Task 6, and this agent's output continues to
  satisfy whichever `T-TXT-*` multi-line acceptance case in `TEST_MATRIX.md` exercises
  `shapeParagraph`'s public contract
- Fixtures consumed: `android/fixtures/shaping/**`, multi-line cases, for legibility/ordering
  verification only (not a byte-diff oracle)
- The line-breaking-algorithm-class delta is registered in `android/SHAPING_DELTAS.md` as Class C
  with founder sign-off recorded, not pre-registered as Class A
- Stub count for this agent's owned file reaches 0

**Impl log.** `android/docs/impl-log/BATCH-3.1b.md`

---

### Batch 3 · Agent 3.2 — `mk-textengine` cluster / bidi / coordinate maps

**Depends on:** G2 · **Parallel-safe with:** every other Batch 3 agent

**Mission.** Port `ClusterMap`, `BidiMap`, `CoordinateSpace` (3 files, 310 LOC) to
`:mk-textengine`. ICU BiDi via `android.icu.text.Bidi`. The bidirectional
codepoint↔cluster↔glyph map (D-105) is the contract Arrange Mode (Batch 4) depends on; it must
reproduce the iOS goldens exactly.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKTextEngine/ClusterMap.swift`, `BidiMap.swift`, `CoordinateSpace.swift` (3 files) | Source of truth for this port |
| `android/fixtures/shaping/**` (Batch 0.2) | Cluster/bidi maps embedded in the shaping goldens — the acceptance oracle |
| Agent 3.1a's `MkShapedModels.kt`, `MkShapingEngine.kt` (read, do not edit — this agent's output feeds directly into 3.1a's `capture()`) | The `MkShapedRun` shape this agent's builders consume |
| `FOUNDATION.md` §3 (D-105, D-109) | iOS cluster-model and bidi decisions this module reproduces |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/{MkClusterMap,MkBidiMap,MkCoordinateSpace}.kt`
- `android/mk-textengine/src/test/kotlin/net/binjamshid/makhtoot/mk/textengine/{MkClusterMap,MkBidiMap}Test.kt`
- `android/docs/impl-log/BATCH-3.2.md`

**Never touch.** `:mk-textengine`'s other files (owned by 3.1a/3.1b/3.3 — this agent's builders are
*called by* 3.1a's `capture()` per the existing Swift dependency shape, but 3.1a owns that call
site; a needed signature change goes to `android/docs/CONTRACT_CHANGES.md`). Any other
`android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `ClusterMap.swift` | 187 | `MkClusterMap.kt` | `MkCluster` (id/utf16Range/codepoints/glyphs/kind — `Kind` sealed class: `Simple`/`Ligature`/`BaseWithMarks(baseCount)`/`MarkOnly`/`Control`) + `MkClusterMap` (clusters/glyphToCluster/utf16ToCluster) + `MkClusterMapBuilder.build(runs, sourceUtf16)`. The construction algorithm (`CTRunGetStringIndices`-derived: group glyphs by shared string index within a run, sort distinct indices ascending to restore logical order within an RTL run whose glyph array is visually left-to-right, then sort ALL runs' raw clusters by `utf16Range.lowerBound` to restore logical order across visually-reordered runs), sourced from `hb_glyph_info_t.cluster` instead of `CTRunGetStringIndices` (set by Agent 3.1a via `HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS`). **This is not a drop-in field-rename** — corrected from an earlier draft that asserted the two cluster models "match" and need "only a different field name at the read site." The real risk: HarfBuzz's monotone cluster levels **merge** the clusters of every character forming a ligature into one shared `cluster` value, whereas `CTRunGetStringIndices` emits a per-character index entry for each component of a ligature, with zero-advance glyphs standing in for the non-first components — this per-component signal is exactly how `LigatureDetector.swift` (Agent 3.3) learns how many characters a ligature spans, and what `MKArrange/LigatureDecomposer.swift` (361 LOC, Batch 4's largest Arrange file) needs for component-level decomposition. Building this file's `Kind.Ligature` classification on a merged HarfBuzz cluster therefore risks silently losing a boundary Core Text's per-character indices preserved. Verify per-family against `android/fixtures/ligature/**`'s Core Text per-component index entries (Agent 0.2's goldens, required to capture that per-component data per spine §12) rather than assuming the semantics carry over; treat any measured divergence as a real `android/SHAPING_DELTAS.md` row with its correct A/B/C class, never a silent pass. `classify(codepoints:glyphCount:)` (pure logic over `MkMarkClassifier.isMark`/`isControlFormatter`, from Agent 3.3) ports unchanged. |
| `BidiMap.swift` | 84 | `MkBidiMap.kt` | `MkBidiRun` (utf16Range/level/isRTL/visualOrdinal) + `MkBidiMap` (baseDirection/runs/glyphVisualIndex) + `MkBidiMapBuilder.build(runs, baseDirection)`. iOS derives only a **coarse two-level** value per run (`CTRunGetStatus(.rightToLeft)` is the only bidi signal Core Text exposes per run — level `1` for RTL, `2` for an LTR run embedded in an RTL paragraph, `0` for LTR-in-LTR) because that is all D-109 has to work with. Android's `android.icu.text.Bidi` exposes the **true UBA embedding level** per run directly (`Bidi.getLevelAt(index)`, `Bidi.getRuns()`) — genuinely more information than the iOS engine ever had. **Decision, recorded here and in `SHAPING_DELTAS.md`:** keep the same coarse two-level derivation this file documents (`isRTL` per run → level 1; else `2` if the paragraph is RTL, `0` if not), computed from `Bidi.getRuns()`'s own per-run direction rather than the ICU embedding level, so Arrange Mode's `MkProvenance.bidiLevel` field carries the *same value space* cross-platform (D-324's fixture-as-oracle requirement) even though Android's ICU BiDi could derive something finer. Do not silently ship the finer ICU levels — that is an unregistered behavioral difference the golden fixtures would not catch (the fixtures only assert what iOS produced) and would surface as a real divergence the first time `MkProvenance.bidiLevel` is compared or persisted cross-platform. The visual-order run walk (runs already in `MkShapedLine.runs` visual order, `glyphVisualIndex` built as a plain left-to-right enumeration over `(run, glyph)` pairs in that array order) ports unchanged — HarfBuzz shaping per bidi run, concatenated in the visual order Agent 3.1a's `hb_buffer` construction already established, reproduces the same "runs are already visual order" precondition Core Text's `CTLineGetGlyphRuns` gave for free. |
| `CoordinateSpace.swift` | 39 | `MkCoordinateSpace.kt` | `flippedForUIKit(_:frameHeight:)` → `flippedForAndroidView(point: MkPoint, frameHeight: Float): MkPoint`, same `y' = frameHeight - y` flip (Android `Canvas`/`View` space is also y-down, same flip requirement as UIKit). **New scale step with no iOS analogue**: HarfBuzz glyph positions/advances are 26.6 fixed-point integers (`hb_position_t`, 1/64th-of-a-point units) — Agent 3.1a's `capture()` already divides by 64.0 when building `MkShapedRun.positions`/`.advances`, so by the time a position reaches this file's coordinate-space helpers it is already in the same "plain float points, y-up, line-relative" space `CTRunGetPositions` returned directly; document that the 26.6 unscaling happens upstream (3.1a), not duplicated here, so this file's contract (pure y-flip, nothing else) stays identical to the Swift original. |

**Tasks.**
1. Read all 3 Swift files above in full; confirm the 310 LOC total via `wc -l`.
2. Port `MkClusterMap`/`MkClusterMapBuilder`, sourcing from `hb_glyph_info_t.cluster` per the
   note above; prove cluster boundaries match `android/fixtures/shaping/**` for every family
   (ligature/mark/simple/control classification must match exactly — this is the D-105 contract
   Batch 4's Arrange Mode is built on).
3. Port `MkBidiMap`/`MkBidiMapBuilder` using `android.icu.text.Bidi`, implementing the coarse
   two-level derivation decision above, not ICU's finer levels.
4. Port `MkCoordinateSpace`.
5. Delete or overwrite the Batch 1 contract-stub body at each of this agent's 3 owned paths —
   `MkClusterMap.kt`, `MkBidiMap.kt`, `MkCoordinateSpace.kt` — replacing every
   `throw MkNotYetPorted(...)` body with the real implementation (spine §3.3).
6. Port the existing `MKTextEngineTests` cluster/bidi cases (`T-TXT-2`, `T-TXT-3`) 1:1 as JUnit
   tests against the same fixtures.

**Acceptance.**
- `./gradlew :mk-textengine:testDebugUnitTest` green
- `./gradlew :mk-textengine:lintDebug` green
- Requirements covered: `R-6.4` (dual-level model depends on the cluster map's codepoint↔glyph
  bidirectionality), `R-5.3` (mixed Arabic-English bidi), `R-6.14` (letter-level range selection
  across a bidi-run boundary depends on this map's run/level data)
- Tests ported: `T-TXT-2` (cluster map bidirectionality), `T-TXT-3` (bidi run map preservation)
- Fixtures consumed: `android/fixtures/shaping/**`, `android/fixtures/ligature/**` (cluster-merge
  divergence check) across all 45 bundled families
- The coarse two-level bidi derivation is recorded as an explicit, deliberate design decision
  (not a gap) in `android/SHAPING_DELTAS.md`
- Any measured HarfBuzz-cluster-merge-vs-Core-Text-per-component divergence is registered in
  `android/SHAPING_DELTAS.md` with its correct A/B/C class (spine §12), not silently absorbed into
  `Kind.Ligature` classification
- Stub count for this module's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-3.2.md`

---

### Batch 3 · Agent 3.3 — `mk-textengine` joining, forms, marks, ligatures, features

**Depends on:** G2 · **Parallel-safe with:** every other Batch 3 agent

**Mission.** Port `JoiningAnalyzer`, `JoiningTypeTable`, `FormResolver`, `CursiveAttachment`,
`MarkAttachment`, `MarkClassifier`, `LigatureDetector`, `FontFeatureControl` (8 files,
1,038 LOC) to `:mk-textengine`. ZWJ form harvesting (D-107) works identically under HarfBuzz —
this agent must prove it with the Batch-0 per-letter-per-family goldens. Mark classification
covers U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED. This agent additionally owns
`MakhtootKit/Tests/WS16CursiveTests/` (4 files, 450 LOC) — the cursive-attachment fidelity
evidence suite for the five held fonts, previously in no packet anywhere in the plan despite being
load-bearing for the Arrange invariant `CLAUDE.md` calls non-negotiable; its evidence assertions
are re-run at Batch 8.2.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKTextEngine/JoiningAnalyzer.swift`, `JoiningTypeTable.swift`, `FormResolver.swift`, `CursiveAttachment.swift`, `MarkAttachment.swift`, `MarkClassifier.swift`, `LigatureDetector.swift`, `FontFeatureControl.swift` (8 files) | Source of truth for this port |
| `MakhtootKit/Tests/WS16CursiveTests/AllFiveHeldFontsEvidenceTests.swift` (86 LOC), `CursiveDerivationFidelityTests.swift` (101 LOC), `CursiveJoinBreakEvidenceTests.swift` (155 LOC), `WS16Fixtures.swift` (108 LOC) | The cursive-attachment fidelity evidence suite this agent additionally owns (verified via `find MakhtootKit/Tests/WS16CursiveTests`/`wc -l` — 450 LOC total) |
| `android/fixtures/joining/**`, `android/fixtures/ligature/**`, `android/fixtures/marks/**` (Batch 0.2) | Per-letter-per-family joining-form harvest goldens, ligature detect/decompose/recompose goldens, mark-attachment offset goldens — the acceptance oracle |
| Agent 3.1a's `MkShapingEngine.kt`, `MkGlyphPathProvider.kt` (read, do not edit — `MkFormResolver` calls both directly, same dependency shape as the Swift original) | The shaping/outline entry points this agent's form harvester and cursive-coverage cache call into |
| Agent 3.2's `MkClusterMap.kt` (read, do not edit — `MkMarkAttacher`/`MkLigatureDetector` operate over its output) | The cluster classification this agent's mark/ligature detectors consume |
| `ANDROID_SPINE.md` §2 (D-303, D-325), §12 (delta classification) | ZWJ-harvest and `hb_feature_t` mapping notes, and the A/B/C class every registered delta from this agent must carry |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/{MkJoiningAnalyzer,MkJoiningTypeTable,MkFormResolver,MkCursiveCoverageCache,MkGposCursiveParser,MkMarkAttacher,MkMarkClassifier,MkLigatureDetector,MkFontFeatureControl}.kt`
- `android/mk-textengine/src/test/kotlin/net/binjamshid/makhtoot/mk/textengine/{MkJoiningAnalyzer,MkFormResolver,MkCursiveCoverageCache,MkMarkAttacher,MkMarkClassifier,MkLigatureDetector,MkFontFeatureControl}Test.kt`
- `android/mk-textengine/src/test/kotlin/net/binjamshid/makhtoot/mk/textengine/ws16cursive/{AllFiveHeldFontsEvidenceTest,CursiveDerivationFidelityTest,CursiveJoinBreakEvidenceTest,MkWs16Fixtures}.kt`
- `android/docs/impl-log/BATCH-3.3.md`

**Never touch.** `:mk-textengine`'s other files (owned by 3.1a/3.1b/3.2). `:mk-native`'s C++
sources. Any other `android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `JoiningAnalyzer.swift` | 81 | `MkJoiningAnalyzer.kt` | `MkLetterJoining` (utf16Index/scalar/state) + `MkJoiningAnalyzer.analyze(text)`. Pure Unicode-scalar logical-order walk applying the UCD joining-type rules (`joinsPrevious`/`joinsNext` from neighbor `MkJoiningType`) — zero Core Text dependency in the Swift original, direct 1:1 port to Kotlin code-point iteration. |
| `JoiningTypeTable.swift` | 106 | `MkJoiningTypeTable.kt` | `MkJoiningType` enum + the UCD `ArabicShaping.txt`-derived range tables (`rightJoining`/`joinCausing`/`nonJoining`/`dualJoining`) + `joiningType(of:)`/`validForms(for:)`. Pure static data + range-membership checks, zero platform dependency — direct 1:1 port, every `ClosedRange<UInt32>` becoming a Kotlin `IntRange`, same UCD citations kept in the KDoc. |
| `FormResolver.swift` | 183 | `MkFormResolver.kt` | `MkResolvedForm` data class + `actor MKFormResolver` → Kotlin `class` + `Mutex`-guarded cache. Per spine's explicit instruction, **the D-107 synthetic-ZWJ-context technique itself needs no algorithmic change under HarfBuzz**: build the same four synthetic contexts (`L` isolated / `L+ZWJ` initial / `ZWJ+L+ZWJ` medial / `ZWJ+L` final), shape each through Agent 3.1a's `MkShapingEngine.shapeSingleLine`, then pick the glyph whose cluster covers the letter's UTF-16 index via Agent 3.2's `MkClusterMap` — every step of this file calls into already-ported sibling code, so this port is close to line-for-line once 3.1a/3.2 are green. The per-font caveat (some fonts don't honor a *leading* ZWJ for medial/final synthetic contexts) is a font-behavior fact, not a Core-Text-specific one — re-verify it against the bundled font set under HarfBuzz and update the caveat's font list in the KDoc if it differs (record any difference in `android/SHAPING_DELTAS.md` as a Class C row — a per-font behavioral fact is neither a rounding artifact nor a correctness violation, so it needs founder sign-off, not a self-issued Class A pass). The cache key's `isBold`/`isItalic` fields carry over unchanged (Phase-A bold/italic variant resolution, Batch 3.7's `MkRegistryFontProvider`). |
| `CursiveAttachment.swift` | 254 | `MkCursiveCoverageCache.kt` + `MkGposCursiveParser.kt` | `MKCursiveCoverageCache` (`NSLock`-guarded `[String: Set<UInt16>]`) → Kotlin `object`/`class` with a `synchronized` block or `java.util.concurrent.locks.ReentrantLock` guarding a `MutableMap<String, Set<Int>>`, same per-process-lifetime cache-by-PostScript-name shape. `CTFontCopyTable(font, kCTFontTableGPOS, ...)` (raw GPOS table bytes) → `hb_face_reference_table(face, HB_TAG('G','P','O','S'))` (through `:mk-native`) — **the entire `MKGPOSCursiveParser`/`BEReader` byte-level table walker (the bulk of this file's 254 LOC) ports essentially unchanged**: it is a hand-rolled, bounds-checked, big-endian binary reader over raw `Data`/`ByteArray` with zero CoreText API surface beyond the one table-bytes-fetch call this substitution replaces — same FeatureList→lookup-index resolution, same LookupType-3/LookupType-9-extension-unwrap walk, same Coverage-table-format-1/format-2 glyph-id enumeration, same "never trap on malformed input, degrade to empty coverage" contract. This is the clearest evidence in this whole batch that D-303's "never write a shaper" boundary was already respected on iOS — this parser never touched Core Text's shaping internals, only its own raw-table-bytes accessor, which HarfBuzz exposes just as directly. |
| `MarkAttachment.swift` | 129 | `MkMarkAttacher.kt` | `MkMarkAttachment` + `MkMarkAttacher.attachments(in: line)`. Pure logic over Agent 3.2's `MkClusterMap`/`MkShapedLine` (nearest-preceding-base backward walk across cluster/run boundaries, `markPosition - basePosition` computed directly from already-captured `MkShapedRun.positions`) — zero direct shaping-API dependency in the Swift original (it reads captured positions, it does not re-query Core Text), so this ports as a pure algorithm unchanged. |
| `MarkClassifier.swift` | 104 | `MkMarkClassifier.kt` | `MkMarkClass` enum + the explicit D-105 Unicode ranges (honorifics U+0610–061A, harakat U+064B–065F, superscript alef U+0670, Qur'anic annotations U+06D6–06ED minus the three documented spacing-sign exceptions U+06DD/U+06DE/U+06E9) + `controlFormatters` set (ZWJ/ZWNJ/bidi-control) + `isMark(_:)`/`classify(_:)`/`isControlFormatter(_:)`. The explicit-range checks port unchanged (pure data). The fallback path — `scalar.properties.generalCategory ∈ {.nonspacingMark, .enclosingMark}` for any Mn/Me scalar the explicit ranges don't name — has no Kotlin-stdlib equivalent at the same granularity; use `android.icu.lang.UCharacter.getType(codepoint)` (ICU, already a platform/NDK dependency per D-303/D-304) checked against `UCharacterCategory.NON_SPACING_MARK`/`ENCLOSING_MARK`, which is the direct ICU equivalent of Swift's `Unicode.Scalar.Properties.generalCategory` for exactly these two categories. |
| `LigatureDetector.swift` | 110 | `MkLigatureDetector.kt` | `MkLigatureKind` enum (`required`/`discretionary`/`contextual`) + `MkDetectedLigature` + `MkLigatureDetector.detect(in:activeSetting:)`. Pure logic over Agent 3.2's `MkClusterMap` (single-glyph-realizing-multiple-non-mark-codepoints detection, lam+alef-family required-ligature heuristic) — zero direct shaping-API dependency, direct 1:1 port. |
| `FontFeatureControl.swift` | 71 | `MkFontFeatureControl.kt` | This is the one file in this agent's set with a genuine **structural** substitution, per D-303's explicit mapping: `kCTFontFeatureSettingsAttribute` dictionaries + `CTFontCreateCopyWithAttributes` (Core Text's model — reconfigure the *font object*, features live on the font, every subsequent shape/outline call against that font inherits them) → an array of `hb_feature_t` (`{tag: 'dlig'/'liga'/'calt', value: 0/1, start: 0, end: HB_FEATURE_GLOBAL_END}`) passed as a **parameter to each `hb_shape()` call** (HarfBuzz's model — features are shape-call-scoped, not font-object-scoped; there is no "feature-configured font" to create or cache). `featureSettings(for:)` → `hbFeatures(for: MkLigatureSetting): List<HbFeature>` returning the same three cases' tag/value pairs (`.standard`→empty list; `.discretionaryOn`→`dlig=1,calt=1`; `.off`→`liga=0,dlig=0`, `calt` deliberately left untouched at every setting per the required-shaping-outranks-maximal-off rule). `font(_:applying:)` (returns a reconfigured `CTFont`) has **no return value on the Android side** — instead, `MkShapingEngine`'s per-shape `hb_shape()` call site takes the `hbFeatures(for:)` list directly as an argument, so this function's Android shape is `fun hbFeatures(for: MkLigatureSetting): List<HbFeature>`, a pure data mapper with no font-object round trip. `ligatureAttributeValue(for:)` (the paired `NSAttributedString.Key.ligature` 0/1 value) has **no HarfBuzz analog and is dropped**: there is no separate string-attribute ligature toggle in the `hb_shape` model — the `liga`/`dlig` `hb_feature_t` entries above are the complete feature-control surface, so this function is not ported, its one caller (Agent 3.1's `MkAttributedStringBuilder`) simply has one fewer attribute to set. `rlig` (required ligatures) stays deliberately uncontrollable exactly as on iOS: no case of `MkLigatureSetting`/`hbFeatures(for:)` ever emits an `rlig` `hb_feature_t` entry, so the closed-enum-is-the-rejection-mechanism property carries over unchanged — verify with the same "«لا» stays one glyph even at `.off`" test. |

**Tasks.**
1. Read all 8 Swift files above in full, plus all 4 `WS16CursiveTests` files; confirm the
   1,038 LOC and 450 LOC totals via `wc -l`.
2. Port `MkJoiningTypeTable`/`MkJoiningAnalyzer` (pure data + logic, zero dependency on
   3.1a/3.2's output).
3. Port `MkMarkClassifier` (pure data + ICU category fallback).
4. Port `MkFontFeatureControl`'s `hbFeatures(for:)` mapper; coordinate with Agent 3.1a on the
   exact `hb_shape()` call-site signature this feeds (file to
   `android/docs/CONTRACT_CHANGES.md` if 3.1a has already landed a conflicting signature).
5. Port `MkCursiveCoverageCache`/`MkGposCursiveParser` (the near-unchanged byte-parser).
6. Port `MkMarkAttacher`/`MkLigatureDetector` (pure logic over 3.2's cluster map).
7. Port `MkFormResolver` last (depends on 3.1a's shaping engine and 3.2's cluster map both being
   green); prove ZWJ form harvesting matches `android/fixtures/joining/**` for every letter in
   every bundled family, and note any per-font leading-ZWJ caveat divergence as a Class C
   `SHAPING_DELTAS.md` row.
8. Delete or overwrite the Batch 1 contract-stub body at each of this agent's 9 owned paths —
   `MkJoiningAnalyzer.kt`, `MkJoiningTypeTable.kt`, `MkFormResolver.kt`,
   `MkCursiveCoverageCache.kt`, `MkGposCursiveParser.kt`, `MkMarkAttacher.kt`,
   `MkMarkClassifier.kt`, `MkLigatureDetector.kt`, `MkFontFeatureControl.kt` — replacing every
   `throw MkNotYetPorted(...)` body with the real implementation (spine §3.3).
9. Prove ligature detection/classification matches `android/fixtures/ligature/**` and mark
   attachment offsets match `android/fixtures/marks/**`, including the full Qur'anic annotation
   range (U+06D6–06ED) and its three documented non-mark exceptions.
10. Port the existing `MKTextEngineTests` joining/mark/ligature/feature cases (`T-TXT-4` through
    `T-TXT-7`) 1:1 as JUnit tests against the same fixtures.
11. Port all 4 `WS16CursiveTests` files (the five-held-font cursive-attachment fidelity evidence
    suite) 1:1 as JUnit tests; confirm they pass against the ported `MkCursiveCoverageCache`/
    `MkGposCursiveParser`/`MkFormResolver` — this is the same evidence Batch 8.2 re-runs, not a
    one-off check.

**Acceptance.**
- `./gradlew :mk-textengine:testDebugUnitTest` green
- `./gradlew :mk-textengine:lintDebug` green
- Requirements covered: `R-7.1`, `R-7.2` (full mark coverage incl. Qur'anic range, identification
  at derivation), `R-8.1`, `R-8.3`, `R-8.4` (joining preserved by default, form selector, D-107
  realization technique), `R-8.5` (letters with fewer than four forms), `R-8.8` (mandatory
  lam-alif ligature family), `R-5.7` (discretionary ligature toggle)
- Tests ported: `T-TXT-4` (mark classification incl. Qur'anic range), `T-TXT-5` (ZWJ
  synthetic-context form resolution), `T-TXT-6` (non-joining letters yield only two forms),
  `T-TXT-7` (font feature control / ligature toggles); `WS16CursiveTests`' four evidence files
  ported with no `T-*` id of their own (Batch 8.2 re-runs the same evidence)
- Fixtures consumed: `android/fixtures/joining/**`, `android/fixtures/ligature/**`,
  `android/fixtures/marks/**` across all 45 bundled families
- ZWJ form harvesting proven identical under HarfBuzz per family, with any per-font divergence
  registered in `android/SHAPING_DELTAS.md` as a classed (A/B/C, spine §12) row
- All 4 `WS16CursiveTests` files pass against the ported cursive-attachment code
- Stub count for this module's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-3.3.md`

---

### Batch 3 · Agent 3.4 — `mk-persistence` document package

**Depends on:** G2 · **Parallel-safe with:** every other Batch 3 agent

**Mission.** Port `DocumentPackage`, `MakhtootDocument`, `AutosaveController`, `CommandJournal`,
`CrashRecovery`, `ExportTempDirectory`, `PackageImportValidator`, `Internal/PersistenceSupport`
(8 files, 1,326 LOC) to `:mk-persistence`. D-308 directory form + D-309 zip form, atomic
temp+rename, ≤2 s debounce, journal-only critical flush per D-223, path-traversal-safe zip
extraction.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKPersistence/DocumentPackage.swift`, `MakhtootDocument.swift`, `AutosaveController.swift`, `CommandJournal.swift`, `CrashRecovery.swift`, `ExportTempDirectory.swift`, `PackageImportValidator.swift`, `Internal/PersistenceSupport.swift` (8 files) | Source of truth for this port |
| `android/mk-model/src/main/kotlin/.../model/**` (Batch 2.2 output — read, do not edit) | `MkScene`/`MkManifest`/`MkSceneCodec` types this module reads/writes |
| `ANDROID_SPINE.md` §2 (D-308, D-309, D-323) | Directory-form + zip-form persistence layout and the shared migrator-chain lockstep requirement |
| `FOUNDATION.md` §4 (D-112) | iOS persistence decision this module mirrors |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/{MkDocumentPackage,MkMakhtootDocument,MkAutosaveController,MkCommandJournal,MkCrashRecovery,MkExportTempDirectory,MkPackageImportValidator}.kt`
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/internal/{MkAtomicIo,MkContentHash,MkSceneRevision,MkCrc32,MkDebouncer,MkFileLocations}.kt`
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkZipPackage.kt` (new — D-309's zip-form read/write, no direct Swift source since this is new to Android's persistence layer)
- `android/mk-persistence/src/test/kotlin/net/binjamshid/makhtoot/mk/persistence/**` (this agent's files only, not 3.5's/3.6's test packages)
- `android/docs/impl-log/BATCH-3.4.md`

**Never touch.** `:mk-persistence`'s `Undo/**` (3.5's), `Metadata/**` + `AssetStore.kt` (3.6's).
Any other `android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `DocumentPackage.swift` | 146 | `MkDocumentPackage.kt` | `MkManifest` (manifestVersion/projectID/schemaVersion/title/canvas/createdAt/modifiedAt/thumbnail/assetIndexDigest/premiumContentPresent) as a `@Serializable data class` — same forward-tolerant "unknown keys decode-ignore" property kotlinx-serialization gives for free with `ignoreUnknownKeys = true`. `MkDocumentPackage` (rootURL + manifestURL/sceneURL/journalURL/assetsDirURL/backupsDirURL/thumbnailURL computed paths, `create(at:...)`, `readManifest`/`writeManifest`, `readScene`/`writeScene`, `writeThumbnail`) — direct 1:1 port over `java.io.File`, no `FileWrapper` equivalent needed (Android has none either, matching the Swift file's own "direct-FS, no FileWrapper" framing). `JSONEncoder.dateEncodingStrategy = .iso8601`/`JSONDecoder.dateDecodingStrategy = .iso8601` (manifest's `createdAt`/`modifiedAt`) → a custom `kotlinx.serialization.KSerializer<Instant>` producing the exact same ISO-8601 string format `ISO8601DateFormatter`'s default produces (verify fractional-seconds/`Z`-suffix format matches — `java.time.format.DateTimeFormatter.ISO_INSTANT` is close but not guaranteed byte-identical without an explicit pattern; this is a concrete parity risk to verify empirically against a real manifest, not assumed). D-309's zip form (new, no line-for-line Swift analog — this agent additionally implements `MkZipPackage`: read/write the identical internal layout — `manifest.json`, `scene.json`, `assets/`, `backups/`, `thumbnail.png` — into/out of a `.zip` container via `java.util.zip.ZipOutputStream`/`ZipInputStream`, STORED/DEFLATE per entry, with every extracted entry's name checked against path-traversal (`entry.name` containing `..` or resolving outside the destination root) before it is written, mirroring `PackageImportValidator`'s own defense-in-depth shape below). |
| `MakhtootDocument.swift` | 292 | `MkMakhtootDocument.kt` | `@MainActor @Observable final class` → a plain Kotlin `class` (constructed and used from `Dispatchers.Main.immediate` per D-302) exposing `scene: StateFlow<MkScene>` instead of an `@Observable var scene` (Compose UI collects the `StateFlow` directly; there is no Swift-`Observable`-macro equivalent needed since Compose's own `State`/`Flow` collection already provides recomposition-on-change). `sceneUpdates: AsyncStream<MkScene>` (the renderer-facing live-scene stream) → `sceneUpdates: SharedFlow<MkScene>` (a hot, replay-1 `MutableSharedFlow`), same "yields current scene immediately on subscription, then again after every mutation" contract. `apply(_:)`/`undo()`/`redo()`/`rename(to:)`/`saveNow(reason:)` port as direct algorithmic translations — same baseRev-then-perform-then-journal-then-schedule-autosave sequencing, same D-223 `.memoryPressureCritical` → `criticalJournalFlush`-only routing (never `flushNow`). The P-6/P-7 hardening this file already carries (mutation-counter-cached scene hash to skip redundant re-hashing; `referencedAssetRefs(in:)` walking the real scene graph for `AssetStore.sweepOrphans` instead of a hardcoded empty set) ports unchanged as algorithms — this is the *already-fixed* behavior per `EXECUTION_PLAN_2026-07-28.md` Wave 1 · Agent 1.3, and Android must ship the fix, not a naive re-derivation of the pre-fix bug. `Task { ... }` fire-and-forget journal-append/autosave-schedule calls → `CoroutineScope(Dispatchers.IO).launch { ... }` (or a scope owned by the document's lifecycle), same non-blocking-caller shape. `MKFilePackageDocumentStore` (the `MkDocumentStoring`-conforming blob store, `MKFoundation`'s stub replacement) ports as `MkFilePackageDocumentStore`, same content-addressed-by-project-id blob layout. |
| `AutosaveController.swift` | 192 | `MkAutosaveController.kt` | `actor` → Kotlin `class` + `Mutex`. `MKDebouncer` (cancel-and-restart delayed task) → a coroutine-`Job`-cancel-and-relaunch debounce (ported here as `internal/MkDebouncer.kt`, shared with this agent's other files). Save ordering (assets → `scene.json` → `manifest.json` → journal-truncate, INV-7/§13.5) ports unchanged — this exact ordering is a correctness invariant, not an implementation detail, and must not be reordered on the Android side. `flushNow`'s hash-unchanged skip-the-write fast path and `criticalJournalFlush`'s journal-only D-223 path both port as direct algorithm translations. `awaitFlushes(atLeast:)`'s race-free "check-before-suspend" continuation-registration pattern ports via `kotlinx.coroutines.sync.Mutex` + a suspended-continuation list guarded the same way (the Swift actor gives this for free by construction; the Kotlin `Mutex`-guarded equivalent must be written explicitly to preserve the same "no window between check and register" guarantee). `OSSignposter` "autosave" interval → `Trace.beginSection("autosave")`/`endSection()`. |
| `CommandJournal.swift` | 144 | `MkCommandJournal.kt` | `actor` → Kotlin `class` + `Mutex`. `FileHandle.seekToEnd()`/`.write(contentsOf:)`/`.truncate(atOffset: 0)` → `java.io.RandomAccessFile` opened in `"rw"` mode: `seek(file.length())` + `write(bytes)` for append, `setLength(0)` for truncate — direct 1:1 operational mapping. The JSON-Lines line format (`{"seq","ts","baseRev","cmdJSON","crc32"}`, one command per line, `cmdJSON` stored as a JSON **string** not a nested object specifically so CRC verification re-hashes the exact bytes read back) ports unchanged, same rationale preserved in the KDoc. `MKCRC32` (this file's hand-rolled table-based CRC32) is **not re-implemented** here — `java.util.zip.CRC32` is a standard-library, output-identical (same IEEE 802.3 polynomial) replacement; call it directly from `internal/MkCrc32.kt` as a thin wrapper matching the `hex(_:)` convenience signature, rather than porting the Swift file's own 256-entry table-generation code, which exists on iOS only because Foundation has no built-in CRC32. `readValidRecords()` (stop-at-first-CRC-or-structural-mismatch, preserving the damaged remainder) ports as a direct algorithm translation over `ByteArray`. |
| `CrashRecovery.swift` | 92 | `MkCrashRecovery.kt` | `MkCrashRecoveryResult` data class + `recover(package:savedScene:journal:)`. Direct algorithm port: verify each record's `baseRev` against the running `MkSceneRevision.hash(scene)` chain, replay the valid prefix, stop at first mismatch, write a rescue snapshot (`backups/rescue-<timestamp>.scene.json`) before returning. `ISO8601DateFormatter` (rescue-file timestamp naming, `:` replaced with `-` for filesystem safety) → the same custom ISO-8601 formatter this agent builds for `DocumentPackage`'s manifest dates, reused here for naming consistency. |
| `ExportTempDirectory.swift` | 72 | `MkExportTempDirectory.kt` | `FileManager.default.temporaryDirectory` → `context.cacheDir` (Android's app-private cache convention — closer in spirit to iOS's temp directory than `context.filesDir`, since the OS may reclaim `cacheDir` under storage pressure, matching "these are disposable export scratch files" intent). `"MKExports"` subdirectory, `urlForExport(ext:)`, `purge()` — direct 1:1 port. |
| `PackageImportValidator.swift` | 120 | `MkPackageImportValidator.kt` | `MkPackageImportLimits` (maxTotalBytes=200MB, maxFileCount=5000, allowedTopLevelMembers) + `MkPackageImportValidationError` sealed class (`ByteCapExceeded`/`FileCountCapExceeded`/`UnexpectedMember`) + `MkDocumentPackage.validateForImport(at:limits:)`. `FileManager.enumerator(at:includingPropertiesForKeys:)` → `java.io.File.walkTopDown()` (Kotlin stdlib) for a plain local-`File` source tree, enforcing the identical top-level-allowlist-first-then-byte/file-count-cap-walk order (cheap rejection before a potentially-huge subtree walk). **New scope beyond the Swift source**: an externally-supplied package can also arrive as a SAF `content://` tree (from `ACTION_OPEN_DOCUMENT_TREE`/a share intent) rather than a plain `File`, which has no `java.io.File.walkTopDown()` access — add a parallel `DocumentFile`-based enumeration path (`androidx.documentfile.provider.DocumentFile.listFiles()`, recursive) applying the same caps, used when the import source is a SAF `Uri` rather than a local path. Also owns D-309's zip-import validation counterpart: reject a zip entry whose name contains `..` or whose extracted path would resolve outside the destination root, applied during `MkZipPackage`'s extraction (this file's `DocumentPackage.swift`-sibling `MkZipPackage.kt`, also owned by this agent) — this is genuinely new logic with no line-for-line Swift source, since iOS v1 has no zip form to validate. |
| `Internal/PersistenceSupport.swift` | 268 | `internal/{MkAtomicIo,MkContentHash,MkSceneRevision,MkCrc32,MkDebouncer,MkFileLocations}.kt` (split, one Kotlin file per logical utility rather than one bundle file, matching the grouping this Swift file's own doc comment describes) | `MKAtomicIO.write(_:to:)` → `MkAtomicIo.write(data, to = file)`: write to a temp file in a **sibling scratch directory outside the destination's own directory** (`context.filesDir/MkAtomicWriteScratch`, mirroring S-7's fix — never inside the `.makhtoot` package directory itself), then `File.renameTo(destination)`. Android's `File.renameTo` is atomic on the same volume for the filesystems internal app storage actually uses (ext4/f2fs), matching POSIX `rename(2)` semantics closely enough for this invariant — **not guaranteed** to the same cross-filesystem degree iOS/APFS gives, so this is a documented parity assumption, verified by this batch's own crash-recovery/journal tests (G3 gate), not merely assumed correct from the API name. `.completeFileProtectionUnlessOpen` (iOS Data Protection, S-6) has **no Android analogue** — Android's file-based encryption (FBE) is OS-level and app-transparent with no per-file protection-class API — this line item is **dropped**, not substituted with a fabricated equivalent; note this explicitly as a documented, accepted platform difference (Android's own OS-level encryption already covers the "device-locked data at rest" threat model this iOS option addressed). `MKContentHash.sha256Hex` → `java.security.MessageDigest.getInstance("SHA-256")` (drop CryptoKit, standard-library replacement). `MKSceneRevision.hash`/`fnv1aHex` (word-chunked FNV-1a over `MkSceneCodec.encode(scene)` bytes) ports as the same algorithm over `ByteArray` via `java.nio.ByteBuffer` word-sized gets in place of `withUnsafeBytes`/`loadUnaligned` — same byte-order care (little-endian word unpacking matching Apple-platform little-endian, verify JVM `ByteBuffer` order is explicitly set to `LITTLE_ENDIAN` since JVM default is big-endian, unlike the Swift original's implicit little-endian assumption). `MKCRC32` → superseded by `java.util.zip.CRC32` (see `CommandJournal.swift`'s row above — do not port the hand-rolled table). `MKDelayScheduling`/`MKTaskSleepScheduler`/`MKDebouncer` (test-seam-friendly cancel-and-restart delay abstraction) → a Kotlin `interface MkDelayScheduling { suspend fun delay(interval: Duration) }` + `MkTaskSleepScheduler` (`kotlinx.coroutines.delay`) + `MkDebouncer` (`Job`-cancel-and-relaunch), same test-injectable-scheduler shape for deterministic debounce tests. `MKFileLocations.documentsProjectsDirectory()`/`.applicationSupportDirectory()`/`.atomicWriteScratchDirectory()` → `context.filesDir/Projects`, `context.filesDir` (Android has no Application-Support/Documents split the way iOS does — `context.filesDir` serves both roles; keep the same two logical directory *names* as subdirectories under it for structural parity with the Swift layout, even though the OS-level directory split collapses to one root), `context.filesDir/MkAtomicWriteScratch`. |

**Tasks.**
1. Read all 8 Swift files above in full; confirm the 1,326 LOC total via `wc -l`.
2. Port `internal/{MkAtomicIo,MkContentHash,MkSceneRevision,MkCrc32,MkDebouncer,MkFileLocations}.kt`
   first — every other file in this agent's set depends on them.
3. Port `MkDocumentPackage` (directory form) and prove `create`/`readManifest`/`writeManifest`/
   `readScene`/`writeScene` round-trip against a fresh package.
4. Port `MkCommandJournal`/`MkCrashRecovery` and prove the baseRev-chain replay-with-damaged-tail
   behavior against deliberately-truncated/corrupted journal fixtures.
5. Port `MkAutosaveController`/`MkMakhtootDocument`, wiring `MkUndoStack` (Agent 3.5's — read
   its public API, do not edit its file) into `apply`/`undo`/`redo`.
6. Port `MkExportTempDirectory`, `MkPackageImportValidator` (both the local-`File` and SAF
   `DocumentFile` enumeration paths).
7. Build `MkZipPackage` (D-309's new zip-form read/write) with path-traversal-safe extraction,
   and wire its validation into `MkPackageImportValidator`.
8. Delete or overwrite the Batch 1 contract-stub body at each of this agent's owned paths —
   `MkDocumentPackage.kt`, `MkMakhtootDocument.kt`, `MkAutosaveController.kt`,
   `MkCommandJournal.kt`, `MkCrashRecovery.kt`, `MkExportTempDirectory.kt`,
   `MkPackageImportValidator.kt`, and the six `internal/**` files — replacing every
   `throw MkNotYetPorted(...)` body with the real implementation (spine §3.3). `MkZipPackage.kt`
   is new (D-309) and has no Batch 1 stub to supersede.
9. Port the existing `MKPersistenceTests` cases for this file set (`T-MDL-3` through `T-MDL-6`,
   `T-MDL-10`, `T-MDL-11`) 1:1 as JUnit tests, plus new zip-form round-trip and path-traversal
   rejection tests with no direct Swift-test analog.

**Acceptance.**
- `./gradlew :mk-persistence:testDebugUnitTest` green
- `./gradlew :mk-persistence:lintDebug` green
- Requirements covered: `R-3.1` (project = `.makhtoot` package), `R-3.3`, `R-3.4` (debounced
  ≤2 s autosave, invisible/no save button), `R-22.4` (incremental autosave <100 ms off main
  thread), `R-22.8` (zero-data-loss guarantee), `R-22.9` (determinism), `R-22.14` (persistence
  per D-112, amended by D-308/D-309 for Android)
- Tests ported: `T-MDL-3` (file-package structure), `T-MDL-4` (atomic autosave write-temp+rename),
  `T-MDL-5` (debounced autosave timing), `T-MDL-6` (crash-recovery journal replay), `T-MDL-10`
  (document open under renamed/moved package), `T-MDL-11` (multi-file save-order crash window)
- Fixtures consumed: none checked in by Batch 0 specifically for persistence (this module's
  correctness is proven against locally-constructed packages/journals, not a golden byte
  comparison — persistence layout is behavioral, not numeric)
- Persistence journal + crash recovery tests green (G3 gate)
- Font validator rejects the same corpus iOS rejects (cross-reference with Agent 3.7 — this
  agent does not own that test, only confirms the G3 gate line item is satisfied jointly)
- Stub count for this module's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-3.4.md`

---

### Batch 3 · Agent 3.5 — `mk-persistence` undo

**Depends on:** G2 · **Parallel-safe with:** every other Batch 3 agent

**Mission.** Port `Undo/Commands`, `MKCommand`, `MKCommandCoder`, `UndoStack`,
`MKProjectChange` (5 files, 956 LOC) to `:mk-persistence`. Memory-accounted, coalesced gestures,
unbounded within budget.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKPersistence/Undo/MKCommand.swift`, `Undo/MKCommandCoder.swift`, `Undo/UndoStack.swift`, `Undo/Commands.swift`, `MKProjectChange.swift` (5 files) | Source of truth for this port |
| `android/mk-model/src/main/kotlin/.../model/**` (Batch 2.2 output — read, do not edit) | `MkScene`/`MkNode` types every command mutates |
| `android/mk-foundation/src/main/kotlin/.../foundation/MkMemoryGovernor.kt` (Batch 2.1 output — read, do not edit) | `MkMemoryAccountable` interface `MkUndoStack` conforms to |
| `ANDROID_SPINE.md` §2 (D-302) | Concurrency model this module's `@MainActor`-equivalent class respects |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/{MkCommand,MkCommandCoder,MkUndoStack,MkCommands}.kt`
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkProjectChange.kt`
- `android/mk-persistence/src/test/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/**`
- `android/docs/impl-log/BATCH-3.5.md`

**Never touch.** `:mk-persistence`'s document-package files (3.4's), `Metadata/**` +
`AssetStore.kt` (3.6's). Any other `android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Undo/MKCommand.swift` | 60 | `undo/MkCommand.kt` | `MkCommand` interface (`id`/`name`/`coalescingKey`/`apply(to: MkScene): MkScene`/`inverse(against: MkScene): MkCommand`) + `MkPersistenceError` sealed class (`nodeNotFound`/`unknownCommandType`/`documentPackageNotFound`/`malformedManifest`/`malformedJournalLine`) + `MkNoOpCommand` (the safe inverse-cannot-be-computed fallback) — direct 1:1 port. Same Arabic command-label convention (`"تحريك"`, `"تدوير"`, …) preserved verbatim per KDoc. |
| `Undo/MKCommandCoder.swift` | 73 | `undo/MkCommandCoder.kt` | The Swift hand-rolled closed-catalog `switch`/`Tagged<Payload>` wrapper is **not** the best-fit Kotlin shape here: port `MkCommand` as a `@Serializable sealed interface` with each of the 17 concrete commands (Agent's own `MkCommands.kt`) as a `@SerialName`-annotated subtype, and let `kotlinx.serialization.json.Json { classDiscriminator = "kind" }` produce the identical `{"kind": "...", ...payload-fields-flattened-or-nested-per-choice}` shape natively via `Json.encodeToString<MkCommand>(command)`/`decodeFromString<MkCommand>(json)` — this eliminates the manual `encode`/`decode` `switch` entirely while reproducing the same `{"kind","payload"}`-style envelope `CommandJournal` (Agent 3.4) reads/writes. Confirm the exact nesting (`kind` sibling-level vs. `payload`-nested) matches what `CommandJournal`'s line format expects before finalizing — coordinate via `android/docs/CONTRACT_CHANGES.md` if 3.4 already assumes a specific shape. |
| `Undo/UndoStack.swift` | 194 | `undo/MkUndoStack.kt` | `@MainActor @Observable final class MKUndoStack` → Kotlin `class` (used from `Dispatchers.Main.immediate`) exposing `undo: StateFlow<List<MkCommand>>`/`redo: StateFlow<List<MkCommand>>` in place of `@Observable var undo`/`var redo`. `beginGesture()`/`endGesture()`/`perform(_:currentScene:)`/`undoLast(currentScene:)`/`redoLast(currentScene:)` port as direct algorithm translations — same absolute-value-command coalescing correctness argument (`apply` always SETS, `inverse` always captures the absolute PRIOR value, so "keep first inverse, discard the rest" is correct regardless of coalesced-step count) carried over verbatim in the KDoc, since it is a property of the command catalog's design, not of Swift specifically. `evictIfNeeded()`'s looped 25%-at-a-time eviction (P-5's fix: looped, not single-pass, so a governor-driven `setMaxEntries` cap crossed by more than one eviction slice still converges) ports unchanged. `MkMemoryAccountable` conformance (`accountedBytes()` sampling the 20 most-recent pooled entries via `MkCommandCoder.encode` and extrapolating; `evictOffscreen()` = halve `maxEntries`; `evictAll()` = clear both stacks) ports as the same sampled-estimate algorithm, same rationale (encoding every entry on every governor query would itself be the O(stack-size) anti-pattern this whole exercise fights). |
| `MKProjectChange.swift` | 25 | `MkProjectChange.kt` | `MkProjectChange` sealed class (`Created(MkProjectSummary)`/`Modified(MkProjectSummary)`/`Renamed(UUID, newTitle: String)`/`Deleted(UUID)`) — direct 1:1 port. Depends on Agent 3.6's `MkProjectSummary` (read its public shape, do not edit its file). |
| `Undo/Commands.swift` | 604 | `undo/MkCommands.kt` | All 17 concrete commands (`MkInsertNodeCommand`, `MkInsertNodesCommand`, `MkRemoveNodeCommand`, `MkReorderCommand`, `MkTransformCommand`, `MkStyleCommand`, `MkLockHideCommand`, `MkRenameCommand`, `MkCanvasSpecCommand`, `MkRestoreTopLevelNodesCommand`, `MkGroupCommand`, `MkUngroupCommand`, `MkReplaceNodeCommand`, `MkReplaceNodesCommand`, `MkBatchTransformCommand`, `MkBatchCoreCommand`, `MkTextEditCommand`) as `@Serializable data class`es implementing `MkCommand`, each a direct field-for-field port of its Swift counterpart's `apply`/`inverse` pair — same absolute-set/absolute-capture shape throughout (e.g. `MkTransformCommand.inverse(against:)` captures the pre-apply transform value from `scene`, never a relative delta), same Arabic `name` label per command (`"إدراج عنصر"`, `"حذف عنصر"`, `"إعادة ترتيب الطبقات"`, `"لصق"`, …), same `coalescingKey` scheme (e.g. `MkReorderCommand`'s `"reorder:\(nodeID)"`) for gesture-coalescing eligibility. |

**Tasks.**
1. Read all 5 Swift files above in full; confirm the 956 LOC total via `wc -l`.
2. Port `MkCommand`/`MkNoOpCommand`/`MkPersistenceError`, then all 17 concrete commands in
   `MkCommands.kt` as `@Serializable` sealed-interface subtypes.
3. Port `MkCommandCoder` around the sealed-interface polymorphic serializer; coordinate the exact
   JSON envelope shape with Agent 3.4's `MkCommandJournal` consumer.
4. Port `MkProjectChange` (depends only on Agent 3.6's `MkProjectSummary` public shape).
5. Port `MkUndoStack`, including `MkMemoryAccountable` conformance; wire nothing into a governor
   here (that caller lives in `:mk-render`'s degradation controller, a later batch) — this agent
   only makes the conformance available.
6. Delete or overwrite the Batch 1 contract-stub body at each of this agent's owned paths —
   `undo/MkCommand.kt`, `undo/MkCommandCoder.kt`, `undo/MkUndoStack.kt`, `undo/MkCommands.kt`,
   `MkProjectChange.kt` — replacing every `throw MkNotYetPorted(...)` body with the real
   implementation (spine §3.3).
7. Port the existing `MKPersistenceTests`/`Undo`-adjacent cases (`T-MDL-7`) plus the gesture-
   coalescing extension case (drag/pinch-resize/rotate → 3 undo steps) 1:1 as JUnit tests.

**Acceptance.**
- `./gradlew :mk-persistence:testDebugUnitTest` green
- `./gradlew :mk-persistence:lintDebug` green
- Requirements covered: `R-2.12` (undo/redo global, crosses mode switches), `R-4.1` (canvas
  manipulation undo coverage — drag/resize/rotate/multi-select), `R-22.9` (determinism: same
  command sequence → same resulting scene)
- Tests ported: `T-MDL-7` (undo/redo command-stack integrity), plus the gesture-coalescing
  extension case (3 discrete manipulations → exactly 3 undo steps, redo replays identically)
- Fixtures consumed: none checked in by Batch 0 specifically for undo (behavioral, not numeric,
  correctness)
- Stub count for this module's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-3.5.md`

---

### Batch 3 · Agent 3.6 — `mk-persistence` Room metadata index

**Depends on:** G2 · **Parallel-safe with:** every other Batch 3 agent

**Mission.** Port `Metadata/**` (`MetadataStore`, `MetadataModels`, `MetadataSummaries`,
`SearchNormalizer`, `LaunchReconciler`) + `AssetStore` (6 files, 1,001 LOC) to `:mk-persistence`.
SwiftData → Room with the identical schema and the identical rule: metadata only, never scene
content, never scene text (only project titles and layer names are searchable). Includes the
Room migration scaffolding.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKPersistence/Metadata/MetadataStore.swift`, `Metadata/MetadataModels.swift`, `Metadata/MetadataSummaries.swift`, `Metadata/SearchNormalizer.swift`, `Metadata/LaunchReconciler.swift`, `AssetStore.swift` (6 files) | Source of truth for this port |
| `android/mk-model/src/main/kotlin/.../model/**` (Batch 2.2 output — read, do not edit) | `MkScene`/`MkCanvasSpec`/`MkAssetRef` types this module reads |
| Agent 3.4's `MkDocumentPackage.kt` (read, do not edit — `duplicateProject`/`LaunchReconciler` open packages via it) | The package-open API this module calls |
| `ANDROID_SPINE.md` §2 (D-308) | Package-directory layout `LaunchReconciler` scans |
| `FOUNDATION.md` §4 (D-112, INV-14) | The locked "metadata only, never scene text content" rule this module must not violate |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/{MkMetadataStore,MkMetadataModels,MkMetadataSummaries,MkSearchNormalizer,MkLaunchReconciler}.kt`
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/AssetStore.kt`
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkMetadataDatabase.kt` (new — Room `@Database` + DAOs + migration scaffolding, no direct 1:1 Swift file since SwiftData's `ModelContainer`/`Schema` construction is implicit where Room's is explicit)
- `android/mk-persistence/src/test/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/**`, `.../AssetStoreTest.kt`
- `android/docs/impl-log/BATCH-3.6.md`

**Never touch.** `:mk-persistence`'s document-package files (3.4's), `Undo/**` +
`MkProjectChange.kt` (3.5's — this module *produces* `MkProjectChange` events but does not own
the type declaration). Any other `android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Metadata/MetadataModels.swift` | 270 | `metadata/MkMetadataModels.kt` | `@Model` SwiftData classes → `@Entity` Room data classes: `MkProjectRecord` (`@Entity(tableName = "project_records")`, `@PrimaryKey val projectID: UUID`, same 14 fields — title/folderID/createdAt/modifiedAt/canvasWidth/canvasHeight/thumbnailPath/searchText/premiumContentPresent/packageRelativePath/syncState/lastSyncedChangeTag/isOrphaned), `MkFolderRecord`, `MkExportRecord`, `MkFontCatalogRecord` (tier `Int` — 0 bundled/1 premium/2 userImported, same pinned raw values as `MkFontOrigin` in Batch 3.7, kept in lockstep), `MkFontFavoriteRecord`, `MkAnalyticsCounterRecord`, `MkConsentRecord`, `MkTrialRecord` (display-cache mirror only, same "truth = the real secure-store trial clock" caveat, D-312's Keystore-wrapped DataStore rather than D-123's Keychain), `MkTombstoneRecord` — same `MK`-prefix-kept-for-consistency naming rationale as the Swift file's own header note. `MkMetadataSchema.models` (the flat entity list) → the `@Database(entities = [...], version = 1)` annotation on `MkMetadataDatabase`, listing the same 9 entities. `java.util.UUID` fields need Room `TypeConverter`s (`UUID ↔ String`), and `Date`/`Instant` fields likewise (`TypeConverter` to epoch millis) — Room has no native UUID/Date column type, unlike SwiftData's native `UUID`/`Date` support; add one shared `MkRoomConverters` object registered on the database. |
| `Metadata/MetadataStore.swift` | 308 | `metadata/MkMetadataStore.kt` | `@ModelActor public actor MetadataStore` → a Kotlin `class MkMetadataStore(private val db: MkMetadataDatabase)` with every method a `suspend fun` delegating to Room DAOs (Room's generated DAO methods are themselves suspend-safe and already serialize writes per-database, giving the same "context isolated to this store" property the `@ModelActor` macro provided). Port every method 1:1: `listProjects(folderID:)`, `project(id:)`, `addProject(...)`, `rename(projectID:to:)`, `move(projectID:toFolder:)`, `updateSearchText(projectID:sceneSearchText:)`, `markOrphaned(projectID:orphaned:)`, `setThumbnailPath(projectID:relativeFilename:)`, `markModified(projectID:modifiedAt:contentHash:)`, `deleteProject(id:)`, `tombstones()`, `recordTombstone(id:)`, `clearTombstone(id:)`, `duplicateProject(id:documentsRootURL:)` (deep-copies the `.makhtoot` package via Agent 3.4's `MkDocumentPackage`, same `"نسخة"` (copy) title-suffix convention), `updateSyncState(projectID:syncState:lastSyncedChangeTag:)`, `listFolders()`, `createFolder(name:sortOrder:)`, `renameFolder(id:to:)`, `deleteFolder(id:)`, `search(_:)`, `recordExport(...)`, `exportHistory(projectID:)`. `changesContinuation: AsyncStream<MkProjectChange>.Continuation?` (the WS-11/sync change-publish stream, single-consumer, replaced on every `changes` property re-access) → a `MutableSharedFlow<MkProjectChange>` (`replay = 0`, `extraBufferCapacity` sized for the same "don't block a write on a slow consumer" property), exposed as `val changes: Flow<MkProjectChange>` — same single-logical-consumer contract (Batch 6.3's Drive sync engine), same event set (`created`/`modified`/`renamed`/`deleted`), same "search-text/thumbnail-path/sync-state updates are local metadata only and do NOT publish a change event" exclusions preserved exactly (these three exclusions are a deliberate sync-noise-reduction decision, not an oversight — carry the same KDoc rationale forward). |
| `Metadata/MetadataSummaries.swift` | 116 | `metadata/MkMetadataSummaries.kt` | `MkProjectSummary`/`MkFolderSummary`/`MkExportSummary` — plain immutable data classes, direct 1:1 port. Room DAOs return `@Entity` types directly (Room has no `PersistentModel`-is-not-`Sendable`-across-actor-boundary restriction the way SwiftData does, since Room entities are plain POJOs/data classes already safe to return from a `suspend fun`), so `MkMetadataStore`'s public methods map `@Entity` → summary at the return boundary in a small `toSummary()` extension function, preserving the same "public API never leaks the persistence-framework-bound type" boundary the Swift file's header explains, even though Kotlin/Room does not *require* it the way Swift 6 strict concurrency did — kept as a deliberate API-design choice for the same reason (repository layer should not leak its storage-framework's row type to callers). |
| `Metadata/SearchNormalizer.swift` | 78 | `metadata/MkSearchNormalizer.kt` | `MkSearchNormalizer.normalize(_:)`/`matches(query:in:)` (strip tashkeel U+064B–U+0652, unify أ/إ/آ→ا and ة→ه, lowercase) — pure Unicode logic, direct 1:1 port over Kotlin code points. `MkSearchTextExtractor.extract(scene:title:)` (title + every node's `core.name`, recursively into groups — **never** `MkLiveTextNode.text.string`/`MkPathTextNode.text.string`/`MkArrangedTextNode.composition.sourceBackup.sourceString`) ports unchanged, preserving the same locked INV-14 decision this Swift file documents at length (the packet's own literal task wording asked for content-text search; the Swift implementation deliberately does not do that, per `FOUNDATION.md` D-112 as amended) — **do not "fix" this to match a more literal reading of the spine's Batch-3.6 mission text**; the locked decision governs, exactly as it does on iOS, and this port map's own KDoc must carry the same explanatory note forward so a future reader does not "correct" it back to content search. |
| `Metadata/LaunchReconciler.swift` | 63 | `metadata/MkLaunchReconciler.kt` | `LaunchReconciler.reconcile(store:projectsRootURL:)` — direct algorithmic port: scan `Projects/` for `.makhtoot` packages (directory-form; D-309's zip form is not a *stored* project layout so it is out of scope for this scan), reconcile against the Room index (add missing, mark-orphaned-then-un-orphan on reappearance, mark orphaned when a package disappears). `FileManager.contentsOfDirectory` → `File.listFiles()`, `pathExtension == "makhtoot"` filter ports unchanged. |
| `AssetStore.swift` | 166 | `AssetStore.kt` (mirrors the Swift file's own top-level, non-`Metadata/`-nested location) | `actor MKAssetStore` → Kotlin `class` + `Mutex`. `assetURL(for:)`'s S-2 defense-in-depth (`standardizedFileURL.path.hasPrefix(assetsDirURL...)` check, guarding against a hand-crafted `MkAssetRef` constructed via the plain memberwise initializer bypassing `Batch 2.2`'s decode-time digest/ext validation) → `file.canonicalFile.path.startsWith(assetsDir.canonicalFile.path)`, same "assert after building the URL, throw `MkAssetPathError.pathEscapesAssetsDirectory` on violation" shape — `java.io.File.canonicalPath` resolves `..`/symlinks the same way `standardizedFileURL` does, so this is a direct 1:1 defense-in-depth port, not a weaker approximation. `storeAsset(data:ext:)` (SHA-256-dedup content-addressed write), `assetData(for:)`, `hasAsset(_:)` port unchanged. `sweepOrphans(referencedBy:)` — the P-7-fixed version (skips the sweep when `MkManifest.assetIndexDigest` matches AND no prior-cycle orphans remain to finalize; one-cycle grace period before permanent deletion; deletes only the orphans directory's *current* contents rather than `removeItem`-then-recreate the whole directory) ports as the same algorithm, same two-part skip condition preserved exactly (both halves matter for correctness, per the Swift file's own extended comment on why "digest unchanged" alone is insufficient). |

**Tasks.**
1. Read all 6 Swift files above in full; confirm the 1,001 LOC total via `wc -l`.
2. Design `MkMetadataDatabase` (`@Database`, version 1, all 9 entities) and
   `MkRoomConverters` (UUID/Date type converters); write the Room migration scaffolding —
   `MIGRATION_1_2` placeholder pattern + a documented convention for adding future migrations,
   even though no real schema change exists yet (mirrors `MkSceneMigratorRegistry`'s own
   identity-migrator-first precedent from Batch 2.2).
3. Port `MkMetadataModels` (all 9 `@Entity` classes) against the finalized database shape.
4. Port `MkMetadataSummaries`, `MkSearchNormalizer`/`MkSearchTextExtractor` (pure logic, no Room
   dependency).
5. Port `MkMetadataStore`'s DAO-backed methods, including the `MutableSharedFlow`-based
   `changes` stream with the same three no-publish exclusions.
6. Port `MkLaunchReconciler`, `AssetStore`.
7. Delete or overwrite the Batch 1 contract-stub body at each of this agent's owned paths —
   `metadata/MkMetadataStore.kt`, `metadata/MkMetadataModels.kt`,
   `metadata/MkMetadataSummaries.kt`, `metadata/MkSearchNormalizer.kt`,
   `metadata/MkLaunchReconciler.kt`, `AssetStore.kt` — replacing every
   `throw MkNotYetPorted(...)` body with the real implementation (spine §3.3).
   `metadata/MkMetadataDatabase.kt` is new (no direct Swift analogue, see port map) and has no
   Batch 1 stub to supersede.
8. Port the existing `MKPersistenceTests` cases (`T-MDL-8`, `T-MDL-9`) plus `AssetStoreTests`'
   orphan-sweep-skip/orphan-sweep-deletes-only-prior-cycle cases 1:1 as JUnit/Room in-memory-
   database tests.

**Acceptance.**
- `./gradlew :mk-persistence:testDebugUnitTest` green
- `./gradlew :mk-persistence:lintDebug` green
- Requirements covered: `R-3.2` (autosave/duplicate/project browser local storage), `R-3.6`
  (folders), `R-3.7` (search — title + indexed searchable text only), `R-3.8` (duplicate with
  "نسخة" suffix), `R-3.9` (delete), `R-3.10` (export history record)
- Tests ported: `T-MDL-8` (SwiftData/Room metadata index contains no scene data), `T-MDL-9`
  (project browser operations — list/search/folder/duplicate/delete)
- Fixtures consumed: none checked in by Batch 0 specifically for the metadata index
  (behavioral correctness, not numeric)
- `grep -rn 'sourceString\|MkLiveTextNode.text\|MkPathTextNode.text' android/mk-persistence/src/main/kotlin/.../metadata/MkSearchNormalizer.kt`
  returns nothing (INV-14 enforcement — search text never includes scene text content)
- Room migration scaffolding present and documented even though version stays at 1
- Stub count for this module's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-3.6.md`

---

### Batch 3 · Agent 3.7 — `mk-fonts` registry, validator, coverage, storage, user import

**Depends on:** G2 · **Parallel-safe with:** every other Batch 3 agent

**Mission.** Port `MKFontRegistry`, `MKFontRegistrar`, `MKFontValidator`, `MKFontImporter`,
`MKFontStorageManager`, `MKCoverageAnalyzer`, `MKFontSearchIndex`, `BundledFontIndex`,
`MKFontTypes`, `MKFontsCTFontSendable`, `MKFontError`, `MKFontsResources` (12 files, 1,517 LOC)
to `:mk-fonts`. Per D-316: no OS font registration exists or is needed; the validator is pure
sfnt byte parsing and ports directly, with the same Arabic rejection messages. SAF import.
`CTFont` handles → `:mk-native` face/font handles with explicit lifetimes.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/MKFonts/MKFontRegistry.swift`, `MKFontRegistrar.swift`, `MKFontValidator.swift`, `MKFontImporter.swift`, `MKFontStorageManager.swift`, `MKCoverageAnalyzer.swift`, `MKFontSearchIndex.swift`, `BundledFontIndex.swift`, `MKFontTypes.swift`, `MKFontsCTFontSendable.swift`, `MKFontError.swift`, `MKFontsResources.swift` (12 files) | Source of truth for this port |
| `android/strings/font-manifest.json` (Batch 0.4) | Family → `android/app/src/main/assets/fonts/<family>/<file>` mapping + licence record this module's `BundledFontIndex` reads |
| `android/fixtures/resources/catalog-seed.json` (Batch 0.4, copied verbatim) | Catalog seed data this module's `BundledFontIndex` decodes |
| `:mk-native`'s HarfBuzz/FreeType face-handle JNI facade (Batch 1.2) | The face/font handle lifetime API this module manages |
| `ANDROID_SPINE.md` §2 (D-316) | The no-OS-registration decision and the SAF-import/byte-for-byte-validator requirement |
| `FOUNDATION.md` §7 (D-120, D-122) | iOS bundled-font-set and registration/import decisions this module mirrors (minus system-wide registration, which has no Android analogue) |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/{MkFontRegistry,MkFontRegistrar,MkFontValidator,MkFontImporter,MkFontStorageManager,MkCoverageAnalyzer,MkFontSearchIndex,MkBundledFontIndex,MkFontTypes,MkFontError,MkFontsResources}.kt`
- `android/mk-fonts/src/test/kotlin/net/binjamshid/makhtoot/mk/fonts/**` (this agent's files only — the premium-catalog/downloader/lock-controller/licensing test package under `MKFonts` belongs to Batch 6.5, not this agent)
- `android/docs/impl-log/BATCH-3.7.md`

**Never touch.** `:mk-fonts`'s premium-catalog files (`MKFontCatalog.swift`, `CatalogManifest.swift`,
`MKCatalogManifestFetchService.swift`, `MKFontDownloader.swift`, `MKLicenseRecord.swift`,
`MKFontCatalogStore.swift`, `MKLicensingDataSource.swift`, `MKFontLockController.swift`,
`MKPremiumDelivery.swift` — Batch 6.5's). Any other `android/mk-*` module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MKFontRegistry.swift` | 349 | `MkFontRegistry.kt` | `actor` → Kotlin `class` + `Mutex`, same registries (`recordsByID`/`licensesByID`/`evidenceByID`/`provisionalIDs`/`coverageByID`). `loadBundled(index:)` (registers every bundled font whose `records.json` entry has `redistributionConfirmed == true`) ports unchanged as the "no record → no registration" gate. `CTFontManagerRegisterFontURLs(.process)`/`registerURL(_:)`/`unregisterURL(_:)` have **no Android analogue at all** — per D-316, there is no OS-level process-scoped font-registration service to call; these are **not ported as registration calls**. Instead, `registerURL`'s role (making a font's PostScript name resolvable process-wide) is replaced by opening and caching a `:mk-native` face handle (`hb_blob_create_from_file` + `hb_face_create` + `hb_font_create`, or the FreeType equivalent `FT_New_Face`) keyed by the font's file path/`AssetManager` descriptor, with **explicit lifetime management** (the handle is retained for the registry's process lifetime, released only via `remove(_:)`) — per spine's explicit "CTFont handles → :mk-native face/font handles with explicit lifetimes" note. `ctFont(for:postScriptName:size:)` → `nativeFontHandle(for:postScriptName:size:)`, resolving to the cached native handle (throwing the ported `MkFontError.FontLocked`/`UnknownFont` under the same conditions — locked-font re-shape refusal, D-119, ports unchanged as a business rule independent of the handle-resolution mechanism). **The entire system-wide (`.persistent` scope) installation surface is dropped, not ported**: `installFontSystemWide(fontID:)`, `uninstallFontSystemWide(fontID:)`, `refreshSystemInstalledStatus()`, `isFontSystemInstalled(fontID:)`, `systemInstalledFontIDs()` (roughly 90 of this file's 349 LOC) have no Android concept to map onto — there is no OS-level "install this font system-wide with a user-consent dialog" API on Android the way `CTFontManagerRegisterFontURLs(.persistent)` provides on iOS. Confirm in the impl log that no PRD `R-12.x`/`R-20.x` requirement depends on this capability (it is an iOS-only convenience surfaced nowhere in `PRD.md`'s font requirements) before dropping it, and record the drop explicitly rather than silently omitting the port-map row. `registerDownloaded`/`registerImported`/`remove`/`setLocked` (T6/T17 registration and expiry-lock surface) port unchanged, minus the now-native-handle-based registration call. `recordsDidChange: AsyncStream<[MkFontRecord]>` → `recordsDidChange: Flow<List<MkFontRecord>>` (a `MutableSharedFlow`, same "yield current snapshot immediately, then on every mutation" contract). `coverageReport(for:)` delegates to this agent's own `MkCoverageAnalyzer`. |
| `MKFontRegistrar.swift` | 28 | `MkFontRegistrar.kt` | `registerBundledFontsAtLaunch()` — direct port, thin bootstrap wrapper around `MkFontRegistry.loadBundled()`, same `Trace.beginSection("fontsBundledRegistration")` signpost. `MKRegistryFontProvider` (the real `MKFontProviding` conformer replacing `SystemFontStubProvider`) → `MkRegistryFontProvider` resolving through the native face-handle cache instead of `CTFontCreateWithName`. Phase-A bold/italic variant resolution (`CTFontCreateCopyWithSymbolicTraits` static-cut lookup, then `CTFontCopyVariationAxes`/`wght`/`slnt` variable-axis fallback, "genuine cut or nothing, never synthesize") → FreeType's own variable-font axis API (`FT_Get_MM_Var` to enumerate axes, `FT_Set_Var_Design_Coordinates` to apply a `wght`/`slnt` value) through `:mk-native`, applied only when the font's own axis table reports the axis exists — same two-tier "static family member first, then a real variable axis, else return unchanged" resolution order, same "never synthesize" hard rule (synthetic emboldening degrades Arabic letter joins) carried over as a hard requirement on the native binding. |
| `MKFontValidator.swift` | 197 | `MkFontValidator.kt` | The hand-rolled, bounds-checked sfnt table-directory walker (`readU32`/`readU16`/`readTag`/`parseNameTable`, `validate(_:)`/`validateCollection(_:)`/`validateSingleFont(_:headerOffset:formatOverride:)`) is **pure byte-math over raw `Data`, zero CoreText dependency in the Swift original** — per D-316's explicit instruction, this ports essentially byte-for-byte to Kotlin over `ByteArray`, same magic-number constants (`sfntTrueType = 0x00010000`, `sfntOpenTypeCFF = 'OTTO'`, `sfntCollection = 'ttcf'`, `woff = 'wOFF'`, `woff2 = 'wOF2'`), same accept set (ttf/otf/ttc/variable via `fvar` table presence) and reject set (WOFF/WOFF2 by magic number, bitmap-only via missing `glyf`/`CFF ` table, structurally corrupt/truncated via the same offset+length-past-buffer bounds checks), **same Arabic rejection messages** (via `MkFontError`, this agent's own port below) — this is the file the spine calls out by name as porting directly. |
| `MKFontImporter.swift` | 87 | `MkFontImporter.kt` | `actor` → Kotlin `class`. `importFont(from:originalFilename:)`: entitlement gate (`entitlements.isEntitled(.fontImport)`, throwing `MkFontError.PremiumRequired`) → sfnt validation (`MkFontValidator`, this agent's own) → SHA-256 content-addressed copy → `.process` register → catalog entry `userImported` — ports as the same pipeline. The Files-picker security-scoped `sourceURL` (caller-managed `startAccessingSecurityScopedResource`/`stopAccessingSecurityScopedResource` bracketing, this actor only reads bytes) → a SAF `ACTION_OPEN_DOCUMENT` `Uri` (caller-managed persistable-URI-permission bracketing via `ContentResolver.takePersistableUriPermission`), this class reading bytes via `context.contentResolver.openInputStream(uri)` — same "this actor/class does not manage scope/permission lifetime, only reads bytes" boundary. `Application Support/Fonts/Imported/<sha256>.<ext>` → `context.filesDir/fonts/imported/<sha256>.<ext>`. Idempotent-import-of-identical-bytes (checks the registry for an existing `fontID` before writing) ports unchanged. |
| `MKFontStorageManager.swift` | 51 | `MkFontStorageManager.kt` | `actor` → Kotlin `class`. `delete(_:referencingProjectTitles:)` (`DeletionOutcome`: `.deleted`/`.deletedWithProjectReferenceWarning(String)`/`.notFound`/`.refusedBundled`) — direct port, same "bundled fonts never deletable (nothing on a writable volume to free)" refusal, same Arabic project-reference warning string. |
| `MKCoverageAnalyzer.swift` | 86 | `MkCoverageAnalyzer.kt` | `MkRangeCoverage`/`MkCoverageReport` + `analyze(font)`. `CTFontCopyCharacterSet`/`CFCharacterSetIsLongCharacterMember` (per-scalar membership query against the font's declared coverage) → a `:mk-native` cmap-coverage query — either `hb_face_collect_unicodes(face)` (HarfBuzz's own Unicode-coverage-set collector, the most direct 1:1 analogue) returning a set this Kotlin layer intersects against each defined range, or an `FT_Get_Char_Index`-per-scalar sweep if the `hb_set_t` binding is not yet exposed by `:mk-native` — prefer the `hb_face_collect_unicodes` route and file a `CONTRACT_CHANGES.md` entry if `:mk-native` needs a new export for it. Same defined ranges (arabic/arabicSupplement/arabicExtendedA/presentationFormsAB-informational-only/tashkeel/quranicMarks/arabicIndicDigits/extendedArabicIndicDigits/basicLatin) and same `supportsTashkeel`(≥80%)/`supportsQuranicMarks`(≥50%)/`supportsLatin`(≥80%) thresholds ported verbatim. |
| `MKFontSearchIndex.swift` | 89 | `MkFontSearchIndex.kt` | `MkFontSearchIndex.Entry` + `search(query, in: entries)` (empty-query → full catalog sorted by category then name; scored substring/prefix/exact matching with a favorites boost) — pure logic, direct 1:1 port. `String.folding(options: [.diacriticInsensitive, .caseInsensitive], locale:)` → `android.icu.text.Transliterator.getInstance("Any-Latin; NFD; [:Nonspacing Mark:] Remove; NFC")` composed with `.lowercase(Locale("ar"))`, or equivalently `java.text.Normalizer.normalize(NFD)` + a combining-mark-strip regex + lowercase — recommend the ICU `Transliterator` route since ICU is already a platform/NDK dependency (D-303/D-304) and its behavior is closer to Foundation's `.folding` than a hand-rolled NFD+regex pass. The explicit alef/teh-marbuta/alef-maqsura unification table (أإآٱ→ا, ة→ه, ى→ي) ports unchanged as its own pre-pass before the ICU fold, same as the Swift original layers it before `.folding`. |
| `BundledFontIndex.swift` | 250 | `MkBundledFontIndex.kt` | `Bundle.url(forResource:withExtension:subdirectory:)` → `context.assets.open("Fonts/<Family>/<file>")`/`context.assets.list("LicenseRecords")` etc. (`AssetManager`, per D-316: bundled fonts live in `android/app/src/main/assets/fonts/**`, opened via `AssetManager` file descriptor + `hb_blob`, no extraction to disk). `records.json`/`catalog-seed.json` decode → `kotlinx.serialization.json.Json.decodeFromString` over the `AssetManager`-read bytes, same `MkRecordsFileEntry`/`MkCatalogSeedFile` shapes (`@Serializable data class` ports of the Swift `Codable` structs). The "no record → no registration" gate (`redistributionConfirmed` must be `true`) ports unchanged. `directoryName(forFontID:fallback:)` (kebab-case `fontID` → PascalCase asset-directory name, e.g. `"noto-naskh-arabic"` → `"NotoNaskhArabic"`) ports unchanged as pure string logic — verify this matches the actual `android/app/src/main/assets/fonts/**` directory names Batch 0.4 produced (if 0.4 kept the Swift-side PascalCase directory convention verbatim, no change needed; if it flattened to kebab-case to match typical Android asset-naming convention, this function's output convention must be updated to match — confirm against `android/strings/font-manifest.json` before assuming either). `builtInArabicNames` (the ~42-entry fontID→Arabic-name fallback table) ports as a verbatim `Map<String, String>` literal, byte-for-byte from the Swift dictionary — no re-transliteration, no re-typing from memory. |
| `MKFontTypes.swift` | 156 | `MkFontTypes.kt` | `MkFontID` (`typealias MkFontID = String`), `MkFontOrigin` enum (pinned ordinals 0/1/2 — bundled/premiumDownloaded/userImported, matching Batch 3.6's `MkFontCatalogRecord.tier: Int` column exactly, kept in lockstep between the two modules), `MkFontCategory` enum (10 BRIEF-locked categories with Arabic display names, ported verbatim), `MkFontFileFormat` (ttf/otf/ttc — woff/woff2 deliberately absent as explicit-rejection cases, not members), `MkFontFace`, `MkFontRecord` + `defaultFace` (the weight-nearest-400 selection logic, fixing the "faces sorted alphabetically by filename silently picks a Bold/Black cut as default" bug — this fix ports unchanged as it is already the corrected, shipped behavior). |
| `MKFontsCTFontSendable.swift` | 14 | *(no Kotlin file — see note)* | This file exists solely to satisfy Swift 6 strict-concurrency `Sendable` checking for the opaque `CTFont` Core Foundation type crossing actor boundaries (`extension CTFont: @retroactive @unchecked Sendable {}`). Kotlin/JVM has no equivalent compile-time actor-isolation checker for a native handle type crossing a `class`+`Mutex` boundary, so **nothing needs porting here** — record this explicitly in the impl log as a deliberate zero-Kotlin-output row, not a silently-skipped file. |
| `MKFontError.swift` | 83 | `MkFontError.kt` | `MkFontError` sealed class (`PremiumRequired`/`UnknownFont(fontID)`/`ChecksumMismatch`/`Offline`/`UnsupportedFormat(detected)`/`CorruptFile`/`FontLocked(fontID)`/`RegistrationFailed(underlying)`/`LicenseRecordMissing(fontID)`) implementing `MkError` (Batch 2.1's interface) — direct port, **every Arabic message carried over byte-for-byte** including the WOFF-specific sub-message ("صيغة WOFF غير مدعومة ، استخدم TTF أو OTF") the spine's mission text explicitly calls out. `RegistrationFailed`'s meaning shifts slightly (no OS registration call exists to fail on Android, per this agent's `MkFontRegistry.kt` row above) but the case and its Arabic message are kept for the analogous native-face-handle-open failure, so callers throughout this module and Batch 3.1a's `MkGlyphPathProvider` share one error vocabulary. |
| `MKFontsResources.swift` | 9 | *(no Kotlin file — see note)* | `Bundle.module` indirection exists only because SPM's synthesized `Bundle.module` accessor is `internal` and cannot appear in a `public` API's default-argument position directly. Android's `AssetManager` (`context.assets`) is already the single global resource accessor with no equivalent internal/public visibility conflict to work around — **no Kotlin file is needed as a substitute indirection layer**; every call site in this agent's other files reads `context.assets` (or an injected `AssetManager` for testability) directly. Record this explicitly in the impl log alongside `MKFontsCTFontSendable.swift`'s row, for the same "confirm intentional, not overlooked" reason. |

**Tasks.**
1. Read all 12 Swift files above in full; confirm the 1,517 LOC total via `wc -l`.
2. Confirm `:mk-native`'s Batch-1.2 facade exposes face/font-handle open-from-`AssetManager`-
   descriptor and open-from-file-path entry points with explicit release semantics, plus a
   Unicode-coverage-set query (`hb_face_collect_unicodes` or equivalent); file gaps to
   `android/docs/CONTRACT_CHANGES.md`.
3. Port `MkFontError`, `MkFontTypes` first (pure data, zero native dependency).
4. Port `MkFontValidator` (pure byte-parsing, zero native dependency) and prove it rejects the
   exact same corpus the iOS `MKFontValidatorTests` rejection-corpus fixture rejects, with the
   same Arabic messages.
5. Port `MkBundledFontIndex` against `android/strings/font-manifest.json` /
   `android/fixtures/resources/catalog-seed.json`; verify the kebab-case→PascalCase (or
   confirmed-otherwise) directory-name mapping against the real asset tree Batch 0.4 produced.
6. Port `MkFontRegistry`/`MkFontRegistrar`, wiring the native face-handle cache; explicitly drop
   (and document the drop of) the system-wide-install surface.
7. Port `MkCoverageAnalyzer`, `MkFontSearchIndex`, `MkFontImporter`, `MkFontStorageManager`.
8. Delete or overwrite the Batch 1 contract-stub body at each of this agent's 9 Kotlin-producing
   owned paths — `MkFontRegistry.kt`, `MkFontRegistrar.kt`, `MkFontValidator.kt`,
   `MkFontImporter.kt`, `MkFontStorageManager.kt`, `MkCoverageAnalyzer.kt`,
   `MkFontSearchIndex.kt`, `MkBundledFontIndex.kt`, `MkFontTypes.kt`, `MkFontError.kt` —
   replacing every `throw MkNotYetPorted(...)` body with the real implementation (spine §3.3).
   `MKFontsCTFontSendable.swift` and `MKFontsResources.swift` have no Kotlin target (see their
   port-map rows) and therefore no stub to supersede.
9. Port the existing `MKFontsTests` cases for this file set (`T-FNT-1`, `T-FNT-5`, `T-FNT-8`)
   1:1 as JUnit tests against the ported rejection-corpus and coverage-analysis fixtures.

**Acceptance.**
- `./gradlew :mk-fonts:testDebugUnitTest` green
- `./gradlew :mk-fonts:lintDebug` green
- Requirements covered: `R-12.1` (bundled starter fonts, free and premium), `R-12.3` (user font
  import via Files/SAF picker, premium-only), `R-12.6` (character coverage per catalog entry),
  `R-12.9` (font-lifecycle events)
- Tests ported: `T-FNT-1` (bundled font registration at launch), `T-FNT-5` (import rejection
  corpus), `T-FNT-8` (character coverage reporting)
- Fixtures consumed: `android/strings/font-manifest.json`,
  `android/fixtures/resources/catalog-seed.json`
- Font validator rejects the same corpus iOS rejects, with the same Arabic error strings (G3 gate
  line item, shared with Agent 3.4's acceptance criterion)
- The system-wide-install-surface omission and the two zero-Kotlin-output files
  (`MKFontsCTFontSendable.swift`, `MKFontsResources.swift`) are recorded explicitly in the impl
  log, not silently absent
- Stub count for this module's owned files reaches 0

**Impl log.** `android/docs/impl-log/BATCH-3.7.md`

---

## Appendix — file-ownership matrix (collision proof)

| Path (prefix) | 3.1 | 3.2 | 3.3 | 3.4 | 3.5 | 3.6 | 3.7 |
|---|---|---|---|---|---|---|---|
| `android/mk-textengine/.../{MkShapingEngine,MkShapingService,MkShapingRequest,MkShapedModels,MkAttributedStringBuilder,MkGlyphPathProvider}.kt` | ✅ | | | | | | |
| `android/SHAPING_DELTAS.md` | ✅ (creates) | | | | | | |
| `android/mk-textengine/.../{MkClusterMap,MkBidiMap,MkCoordinateSpace}.kt` | | ✅ | | | | | |
| `android/mk-textengine/.../{MkJoiningAnalyzer,MkJoiningTypeTable,MkFormResolver,MkCursiveCoverageCache,MkGposCursiveParser,MkMarkAttacher,MkMarkClassifier,MkLigatureDetector,MkFontFeatureControl}.kt` | | | ✅ | | | | |
| `android/mk-persistence/.../{MkDocumentPackage,MkMakhtootDocument,MkAutosaveController,MkCommandJournal,MkCrashRecovery,MkExportTempDirectory,MkPackageImportValidator,MkZipPackage}.kt` | | | | ✅ | | | |
| `android/mk-persistence/.../internal/**` | | | | ✅ | | | |
| `android/mk-persistence/.../undo/**`, `MkProjectChange.kt` | | | | | ✅ | | |
| `android/mk-persistence/.../metadata/**`, `AssetStore.kt` | | | | | | ✅ | |
| `android/mk-fonts/.../{MkFontRegistry,MkFontRegistrar,MkFontValidator,MkFontImporter,MkFontStorageManager,MkCoverageAnalyzer,MkFontSearchIndex,MkBundledFontIndex,MkFontTypes,MkFontError,MkFontsResources}.kt` | | | | | | | ✅ |
| `android/docs/impl-log/BATCH-3.1.md` | ✅ | | | | | | |
| `android/docs/impl-log/BATCH-3.2.md` | | ✅ | | | | | |
| `android/docs/impl-log/BATCH-3.3.md` | | | ✅ | | | | |
| `android/docs/impl-log/BATCH-3.4.md` | | | | ✅ | | | |
| `android/docs/impl-log/BATCH-3.5.md` | | | | | ✅ | | |
| `android/docs/impl-log/BATCH-3.6.md` | | | | | | ✅ | |
| `android/docs/impl-log/BATCH-3.7.md` | | | | | | | ✅ |

No file has two owners. `:mk-textengine` is split three ways at the file level (3.1 owns the
shaping core + `SHAPING_DELTAS.md`'s creation; 3.2 owns cluster/bidi/coordinate; 3.3 owns
joining/forms/marks/ligatures/features) with a read-only dependency chain 3.3→3.1/3.2 and
3.2→(none within the module) matching the Swift originals' own internal call graph — every agent
reads its sibling agents' output files and writes only its own. Work item 3.1 owns the
creation of `SHAPING_DELTAS.md`. Work items 3.1, 3.2, and 3.3 and later render and
arrange work may append rows. Each row belongs to the work item responsible for
that part of the port map. `:mk-persistence` is split four ways (3.4 document-package + `internal/`
utilities + the new zip-form; 3.5 undo + `MkProjectChange`; 3.6 metadata + `AssetStore.kt`) —
disjoint at the file level, confirmed by the path list above. `:mk-fonts` in this batch is 3.7
alone; Batch 6.5 owns the remaining (premium-catalog) files in the same module later. Confirms
spine §4 ground rule 1 (exclusive file ownership) and ground rule 9 (no agent in this batch
touches anything outside `android/`).

> **Writer note:** three structural (not cosmetic) platform substitutions in this batch carry the
> most execution risk and deserve explicit founder/reviewer attention at G3: (1) Agent 3.1's
> HarfBuzz-has-no-line-breaking-API gap, requiring genuinely new ICU-`BreakIterator`-based code
> with no Core Text line-for-line source to port from; (2) Agent 3.4's ISO-8601 date-format and
> `File.renameTo`-atomicity parity assumptions, both flagged as "verify empirically, do not
> assume" in the port map; (3) Agent 3.7's dropped system-wide-font-installation surface, which
> this port map argues is safe to drop (no PRD requirement depends on it) but should be confirmed
> against the final `android/PARITY_MATRIX.md` (Batch 0.1) rather than taken on this document's
> word alone.
