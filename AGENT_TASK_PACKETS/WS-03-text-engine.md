# WS-03 — Text Engine (Shaping Capture)

Run-1 agent task packet for Makhtoot (مخطوط). Governed by FOUNDATION.md. Owns
`MKTextEngine`. This is the differentiator packet: everything unique about Makhtoot
(Arrange Mode, per-glyph editing, mark manipulation) stands on the correctness of the
shaping-capture layer you build here.

## 1. Mission

Build the Core Text shaping-capture engine: given a source string and `MKTextStyle`,
construct the `NSAttributedString`, shape it via `CTTypesetterCreateWithAttributedString`
→ `CTLine` → `CTRun`, and extract a complete, queryable `ShapedLine` model — per-glyph
ids, positions, advances, bounds and outline paths, per-run attributes and
`kCTRunStatusRightToLeft`, and (the hard part) the bidirectional cluster map linking
codepoint indices ↔ clusters ↔ glyphs built from `CTRunGetStringIndices`. On top of the
raw capture you deliver the semantic analyzers: mark identification (combining marks incl.
the Qur'anic annotation ranges U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED) with
captured GPOS-derived relative offsets, ligature-cluster detection (many-codepoints→one-
glyph, e.g., lam-alif), the bidi run map with levels and visual indices, joining-state
analysis per letter, Core Text font-feature control (standard/discretionary ligatures),
and the ZWJ joining-form resolver that can produce any of the four contextual forms of
any Arabic letter in any font (D-107).

You never write a shaper (D-103): Apple Core Text is the single source of shaping truth,
and presentation-form codepoints are banned. Your output types are pure `Sendable` values
consumed by WS-04 (arrange derivation), WS-05 (path layout), WS-07 (live-text rendering)
and WS-08 (PDF/SVG text runs). Precision matters: positions you capture become the exact
positions of Arranged Composition nodes, and the maps you build are what make revert-to-
text and two-level (glyph vs. Unicode-letter) editing lossless.

## 2. Scope

**IN**
- Attributed-string builder from `MKTextStyle` (font via `MKFontProviding`, kerning,
  tracking, baseline shift, ligature features, paragraph style with RTL base direction).
- Shaping capture: `ShapedLine` / `ShapedRun` / `ShapedGlyph` value model with glyph ids,
  positions (line-relative), advances, typographic + image bounds, font ref, RTL status.
- Cluster model: codepoint↔cluster↔glyph bidirectional map.
- Bidi run map: run order, `bidiLevel` (derived), visual indices, RTL flags.
- Mark identification + base-attachment capture (relative offsets from shaped positions).
- Ligature cluster detection + constituent codepoint recording.
- Joining analysis (which letters join, current joining state per letter).
- Font feature control: toggle standard/discretionary/contextual ligatures via Core Text
  feature settings before shaping (D-108 last sentence).
- ZWJ joining-form resolver (D-107) returning glyph id + path for a requested
  `JoiningForm`.
- Glyph outline provider (`CTFontCreatePathForGlyph`) with caching.
- Multi-line support: paragraph → lines via typesetter suggested breaks at a given width
  (live text wraps; arranged derivation consumes per-line output).

**OUT**
- Arranged Composition construction (WS-04 consumes your capture).
- Path-following layout (WS-05).
- Canvas text editing overlay / UITextView (WS-06 per D-104).
- Rendering to screen (WS-07) — you provide geometry/paths only.
- Font files, catalog, registration (WS-09) — you consume `MKFontProviding`.

## 3. Dependencies

**Upstream:** WS-01 (`MKFoundation`, `MKRTLUtilities`, logging/signposts), WS-02
(`MKTextStyle`, `MKFontRef`, `JoiningForm`, `MKBezierPathData`). **Stubs you may rely
on:** `SystemFontStubProvider` (SF Arabic) until WS-09 lands — all tests must run against
SF Arabic and, where bundled early by WS-09, Amiri/Noto Naskh; `StubEntitlementResolver`
(engine itself is never gated).

**Downstream consumers:** WS-04 (primary), WS-05, WS-07, WS-08; WS-06 uses the cluster
map for caret/selection mapping between the UITextView overlay and engine geometry.

## 4. Locked decisions binding this packet (quoted)

- **D-103**: "Apple Core Text does all shaping. Build `NSAttributedString` (font,
  features, kerning/tracking, baseline) → `CTTypesetterCreateWithAttributedString` →
  `CTLine`/`CTRun`. Extract per run: `CTRunGetGlyphs`, `CTRunGetPositions`,
  `CTRunGetAdvances`, `CTRunGetStringIndices`, attributes, `kCTRunStatusRightToLeft`.
  Glyph outlines via `CTFontCreatePathForGlyph`. Never write a shaper; never use Unicode
  presentation-forms codepoints for rendering."
- **D-105**: "Build a bidirectional map — codepoint index ↔ cluster ↔ glyph(s) — from
  `CTRunGetStringIndices`. A cluster with >1 codepoint and 1 glyph = ligature candidate
  (e.g., lam-alif); combining marks (Unicode categories Mn/Me, incl. U+0610–061A,
  U+064B–065F, U+0670, U+06D6–06ED Qur'anic annotation range) become Mark Nodes attached
  to their base Glyph Node with recorded relative offset (GPOS result captured from
  shaped positions)."
- **D-107**: "To realize a chosen form for a letter, reshape the single letter in a
  synthetic context using U+200D ZWJ (e.g., ZWJ+ح+ZWJ for medial) through the same font,
  then harvest that glyph. Guarantees font-consistent contextual forms without
  presentation-form cmap dependence. Store as `JoiningForm` enum + resolved glyph id."
- **D-108** (feature control sentence): "Discretionary ligatures toggled via Core Text
  font features (`kLigaturesType` / OpenType `dlig`/`calt` feature settings) before
  arrangement."
- **D-109**: "Preserve CTLine run order and `kCTRunStatusRightToLeft` per run; arranged
  nodes keep `bidiLevel` + visual index so Latin/Arabic sub-runs stay coherent; paragraph
  base direction from `NSParagraphStyle` (default RTL)."
- **D-115** (relevant budget): "typing echo <50 ms" — your shaping capture is on that
  path; single-line reshape must be far under budget.

## 5. Task breakdown (ordered)

1. **`AttributedBuilder.swift`**: `func makeAttributedString(text: String, style:
   MKTextStyle, fonts: MKFontProviding) -> NSAttributedString`. Applies `CTFont`,
   `kCTKernAttributeName`/tracking, baseline offset, ligature feature attributes, and an
   `NSParagraphStyle` with `baseWritingDirection = .rightToLeft` by default (override
   from style). *Accept:* attribute dump test verifies every style knob lands as the
   expected Core Text attribute.
2. **Feature settings** `FontFeatureControl.swift`: build `CTFontDescriptor` feature
   dictionaries — `kLigaturesType` with `kCommonLigaturesOnSelector` /
   `kRareLigaturesOnSelector` (discretionary) / off selectors; plus OpenType tags via
   `kCTFontOpenTypeFeatureTag` ("liga", "dlig", "calt", "rlig" — note `rlig` must NEVER
   be disabled: required ligatures like lam-alif are non-negotiable in Arabic). *Accept:*
   with dlig ON vs OFF in Amiri (or SF Arabic fallback), shaping of a known
   discretionary-ligature pair produces different glyph counts; `rlig` disable attempts
   are rejected by API design (no such option exposed).
3. **`ShapedModels.swift`**: `ShapedGlyph {glyphID: CGGlyph, position: CGPoint, advance:
   CGSize, fontRef, runIndex, indexInRun, stringIndices: Range-ish [Int],
   typographicBounds: CGRect, isMark: Bool (filled by task 8), clusterID}` ;
   `ShapedRun {glyphs, isRTL: Bool, bidiLevel: Int, attributes, fontRef, visualOrder}` ;
   `ShapedLine {runs (visual order), ascent, descent, leading, width, sourceRange}` ;
   `ShapedParagraph {lines}`. All `Sendable`/value types. *Accept:* compiles; documented
   coordinate convention (origin = line origin, y-up Core Text space; conversions to
   UIKit y-down provided as pure funcs).
4. **`ShapingEngine.swift` capture core**: typesetter → `CTTypesetterCreateLine` (full
   range, single-line API) → iterate `CTLineGetGlyphRuns`; per run copy glyphs,
   positions, advances, string indices, attributes; read `CTRunGetStatus` for
   `.rightToLeft` (and `.nonMonotonic` — record it; non-monotonic clusters occur with
   reordered marks). *Accept:* for "بسم" glyph count > 0, positions strictly decreasing
   x is NOT assumed (positions are visual already); golden test captures stored for
   SF Arabic and asserted stable per OS run (regenerate-on-mismatch flow documented).
5. **Multi-line**: `func shapeParagraph(_:, width: CGFloat?) -> ShapedParagraph` using
   `CTTypesetterSuggestLineBreak` loop; nil width = single line. Line origins stacked by
   ascent/descent/leading + style line-height multiplier. *Accept:* two-line Arabic
   fixture wraps at expected break; line 2 sourceRange continues line 1.
6. **Cluster map** `ClusterMap.swift` (the tricky one). Algorithm:
   a. For each run, `CTRunGetStringIndices` gives, per glyph, the FIRST codepoint index
      (UTF-16 based — convert once to `String.Index`/scalar indices and keep both) of the
      cluster that produced it.
   b. Group consecutive glyphs (in run glyph order) sharing the same string index into a
      glyph-set; the set of distinct string indices in the run, sorted logically, defines
      cluster boundaries: cluster k spans codepoints [idx_k, next_distinct_idx) within
      the run's string range (for RTL runs the glyph order is reversed relative to
      logical order — sort by string index for boundary computation, DO NOT assume glyph
      order).
   c. Assign `ClusterID` per (line, logical start index). Build maps:
      `codepointToCluster: [Int: ClusterID]` (every scalar in span),
      `clusterToGlyphs: [ClusterID: [GlyphSlot]]`, `glyphToCluster`.
   d. Classify: 1 codepoint→1 glyph = simple; >1 codepoints→1 glyph = **ligature
      candidate**; 1 codepoint→N glyphs = multi-glyph cluster (rare; keep as unit);
      cluster containing base + Mn/Me marks where marks got their own glyphs = base+marks
      cluster (marks separated in task 8, cluster retained).
   *Accept:* fixtures — "لا" → one cluster, 2 codepoints, 1 glyph, ligature candidate;
   "بَ" → one cluster, base glyph + mark glyph; "به" → two clusters; round-trip: every
   codepoint maps to exactly one cluster; every glyph to exactly one cluster.
7. **Bidi map** `BidiMap.swift`: capture run visual order from `CTLineGetGlyphRuns`
   order; derive `bidiLevel` (RTL run in RTL paragraph = 1, LTR embedded = 2; LTR
   paragraph inverse — derive from run RTL status + paragraph base direction; store
   level, do not re-implement UBA), assign each glyph a global `visualIndex` left→right
   across the line. *Accept:* "عام 2026 ميلادي" → three runs, digits run flagged LTR,
   visual order matches on-screen order; "١٢٣" stays inside the RTL run (Arabic-Indic
   digits are not direction-breaking); map is stable under re-shaping.
8. **Mark identification** `MarkClassifier.swift`: a glyph is a mark when its cluster's
   originating scalar(s) are in Unicode categories Mn/Me — implement via
   `Unicode.Scalar.Properties.generalCategory` plus explicit inclusion table for
   U+0610–061A, U+064B–065F, U+0670, U+06D6–06DC, U+06DF–06E4, U+06E7–06E8,
   U+06EA–06ED (Qur'anic annotation subranges that are Mn; U+06DD/U+06DE/U+06E9 are
   enclosing/other — classify per actual category, include in table with comments).
   For each mark glyph record: base glyph (nearest preceding non-mark glyph in the same
   cluster, else preceding cluster's base — kashida/space bases documented),
   `relativeOffset = markPosition − basePosition` (this IS the GPOS result per D-105).
   *Accept:* fixtures — "بَ" fatha offset above base; "بِ" kasra below (negative y in
   UIKit space); "شَدَّةٌ": shadda+damma-tanwin stack on the dal — two marks, distinct
   offsets, both based on same glyph; U+0670 superscript alef in "الرَّحْمَٰن" detected.
9. **Ligature detection** `LigatureDetector.swift`: from cluster classification, emit
   `DetectedLigature {clusterID, glyphSlot, constituentScalars, kind}` where kind ∈
   {required (lam-alif family: lam + alef/alef-madda/alef-hamza…), discretionary
   (present only when dlig on), contextual}. Kind heuristic: lam+alef pairs = required;
   others = discretionary-if-dlig-else-contextual; store the active feature settings so
   WS-04 records provenance. *Accept:* "لا", "لأ", "لإ", "لآ" each → required ligature;
   "الله" → cluster analysis captured (font-dependent: SF Arabic/Amiri shape the
   lam-lam-ha + shadda + superscript-alef specially; assert ≥1 multi-codepoint cluster
   and marks attached; document per-font expectations rather than hardcoding one glyph
   count).
10. **Joining analysis** `JoiningAnalyzer.swift`: per Arabic letter scalar, look up
    joining type (dual/right/non-joining) from a bundled table (derived from Unicode
    ArabicShaping semantics — encode the table in Swift, cite UCD in comments, no runtime
    file); compute current `JoiningForm` per letter from neighbors (respecting ZWJ/ZWNJ
    and transparent marks which do not break joining). *Accept:* "محمد": م initial,
    ح medial, م medial, د final; "درس": د isolated-then… د is right-joining so ر after د
    starts a new joining region — assert د final/isolated correctly per position; marks
    in "مُحَمَّد" do not alter the forms.
11. **ZWJ form resolver** `FormResolver.swift` (D-107): to get form F of letter L in font
    fnt: synth strings — isolated: "L"; initial: "L\u{200D}"; medial:
    "\u{200D}L\u{200D}"; final: "\u{200D}L". Shape with the same attributes (minus
    kerning/tracking), find the glyph whose cluster contains L (ignore any ZWJ-produced
    glyphs — ZWJ clusters map to the ZWJ index), return `{glyphID, path, advance,
    form}`. Cache per (font, scalar, form). Edge: right-joining letters (د ذ ر ز و …)
    have no initial/medial — resolver returns the nearest valid form + `wasCoerced` flag
    so WS-04's form selector can disable invalid options. *Accept:* for ح all four forms
    yield four distinct glyph ids in SF Arabic; for د requesting medial returns final/
    isolated variant with `wasCoerced = true`; resolved medial ح glyph id equals the
    glyph id observed for ح inside shaped "محمد".
12. **Glyph outline provider** `GlyphPathProvider.swift`: `CTFontCreatePathForGlyph`
    → `MKBezierPathData`; LRU cache keyed (fontRef, glyphID); y-flip helper to UIKit
    space. *Accept:* path for lam-alif glyph non-empty; cache hit test.
13. **Engine facade** `MKShapingEngine` (Sendable service per D-102):
    `shape(text:style:width:) -> ShapedParagraph` plus analyzers bundled into
    `ShapingCaptureResult {paragraph, clusterMap, bidiMap, marks, ligatures, joining}`.
    Signpost `typingEcho` around single-line reshape. *Accept:* 60-char Arabic line full
    capture < 5 ms on simulator (headroom under the 50 ms echo budget, D-115).
14. **Determinism + tolerance policy**: document that glyph ids/metrics vary per OS/font
    version; tests assert structure (counts, mappings, relations) not raw ids, except
    same-process consistency checks (resolver vs. shaped-context glyph equality).
    *Accept:* test suite contains zero hardcoded glyph ids.
15. **Fuzz/property tests**: random mixes of Arabic letters, tashkeel, digits (both
    sets), Latin, punctuation, ZWJ/ZWNJ; invariants — every scalar in exactly one
    cluster; marks always have a base or documented fallback; visual indices are a
    permutation; no crash on empty/whitespace/mark-only ("ً" standalone) input.
    *Accept:* 10 000 iterations clean.
16. **Docs**: `MKTextEngine/README.md` — coordinate systems, cluster algorithm walkthrough
    with the "لا" and "شَدَّةٌ" worked examples, tolerance policy, consumer guide for
    WS-04/05/07/08. *Accept:* examples compile as doc tests or unit tests.

## 6. Arabic-correctness notes (fixture set — reuse verbatim in tests)

- **لا** family: "لا لأ لإ لآ" — required ligatures; never two separate glyphs.
- **الله** — lam-lam-ha with shadda + U+0670; capture marks and cluster structure;
  per-font documented expectations (SF Arabic vs Amiri differ).
- **شدّة+فتحة stacks**: "شَدَّةٌ", "مُحَمَّدٌ" — shadda U+0651 combined with fatha/damma/
  tanwin must yield stacked marks with distinct captured offsets (shadda closer to base).
- **Qur'anic marks**: "بِسۡمِ ٱللَّهِ" (U+06E1 small high sukun, U+0671 alef wasla) and a
  U+06D6-series sample "قَالَ ۖ" — marks classified, wasla is a LETTER not a mark.
- **Mixed bidi**: "عام ٢٠٢٦" (Arabic-Indic digits stay in RTL run), "عام 2026",
  "سعر 3$ فقط", "Makhtoot مخطوط" — run maps assert order.
- **Kashida**: "مـحـمـد" with U+0640 tatweel — tatweel is a joining letter-like base;
  joining analysis must keep م initial before it; marks can sit on tatweel.
- **ZWNJ**: "می" vs "م‌ی" (U+200C) — joining broken by ZWNJ captured in joining analysis.
- Never normalize or reorder the user's codepoints; capture is read-only over the source.

## 7. Packet acceptance criteria (gates)

- **Build gate**: `MKTextEngineTests` green via `xcodebuild test` (`T-TEXT-*`).
- **Structural correctness**: all §6 fixtures pass mapping/classification assertions
  (`T-TEXT-CLUSTER-*`, `T-TEXT-MARK-*`, `T-TEXT-LIG-*`, `T-TEXT-BIDI-*`,
  `T-TEXT-FORM-*`).
- **D-115 pre-gate**: single-line capture < 5 ms simulator; recorded via `typingEcho`
  signpost for WS-07's device-level verification (`T-PERF-TYPE-*`).
- **Manual Arabic check**: debug harness view (DEBUG-only) rendering captured glyph
  boxes + mark attachment vectors over the fixtures, visually verified and screenshots
  logged (`T-ARABIC-M-TEXT-*`).
- **Ban check**: grep gate — no U+FB50–FDFF/U+FE70–FEFF literals outside
  `MKRTLUtilities` detection tables.

## 8. Deliverables

- `MakhtootKit/Sources/MKTextEngine/MKShapingEngine.swift`, `AttributedBuilder.swift`,
  `FontFeatureControl.swift`, `ShapedModels.swift`, `ShapingCapture.swift`,
  `ClusterMap.swift`, `BidiMap.swift`, `MarkClassifier.swift`, `LigatureDetector.swift`,
  `JoiningAnalyzer.swift`, `JoiningTypeTable.swift`, `FormResolver.swift`,
  `GlyphPathProvider.swift`, `CoordinateSpace.swift`, `README.md`
- `MakhtootKit/Tests/MKTextEngineTests/*` (fixtures per §6, fuzz suite, golden-capture
  utilities)
- DEBUG harness: `Makhtoot/App/Debug/ShapingHarnessView.swift`

## 9. References

- ARCHITECTURE.md: §4 Text Engine (Shaping Capture), §6 Tashkeel/Marks Mechanics,
  §7 Ligature & Joining Mechanics, §8 Bidi Model.
- PRD.md: §5 Typing & Live Text, §7 Tashkeel & Marks, §8 Ligatures & Joining,
  §21 Edge-Case Compendium.
- BRIEF.md: "Arabic text & glyph engine" section (all bullets).
- Market study §4: Core Text feasibility and `CTRunGetPositions` visual-order/
  `kCTRunStatusRightToLeft` groundwork[^20][^21][^22][^23]; bidi WWDC22 reference[^24].

## 10. Codebase-memory MCP duties

- `manage_adr`: "WS03-A1: cluster-map algorithm & non-monotonic run handling",
  "WS03-A2: ZWJ form-resolver design incl. right-joining coercion",
  "WS03-A3: mark classification table & Qur'anic subranges", "WS03-A4: golden-capture
  tolerance policy (no hardcoded glyph ids)".
- Implementation log after tasks 6, 8, 11, 15 with fixture pass evidence.
- Verification evidence: harness screenshots for each §6 fixture, fuzz run summary,
  signpost timing table.
- Record per-font expectation notes ("الله" in SF Arabic vs Amiri) as a durable memory
  entry for WS-04/WS-09 agents.

## 11. Traceability

| BRIEF requirement | Packet coverage |
|---|---|
| Arabic engine — normal typing: shaping, contextual forms, ligatures, tashkeel, bidi, mixed Arabic-English, Arabic-Indic + Latin numerals, punctuation | T1, T4 (capture core; whole packet) |
| Arabic engine — both levels: store codepoint sequences + resolved glyph/shaping-form references | T6 (bidirectional cluster map) |
| Arabic engine — joining preserved by default; breaking explicit; visual selector for isolated/initial/medial/final | T10 (`JoiningAnalyzer`), T11 (`FormResolver`; selector UI: WS-04/WS-06) |
| Arabic engine — tashkeel + full Qur'anic/Uthmani marks attach to base, follow it | T8 (`MarkClassifier`) |
| Arabic engine — ligatures (lam-alif + discretionary/contextual) | T2 (feature control), T9 (`LigatureDetector`) |
| Engineering — Core Text/TextKit 2/etc. permitted; no ground-up Arabic shaper | T1, T4 (D-103 realized) |
| Performance — typing echo <50 ms budget (D-115) | T13 |
