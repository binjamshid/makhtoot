# WS-16 — Cursive-attachment capture (D-222 step 8 remedy) — implementation log

Run-3 agent. Task: WS-09's real GPOS audit found LookupType-3 (cursive
attachment) on base glyphs in 5 fonts (Amiri, Amiri Quran, Aref Ruqaa,
Rakkas, Qahiri), held out of the default catalog per D-222 because D-105's
capture model has no cursive-pair structure (this validated Run-2 finding
R2-1-3). Job: add whatever cursive-pair capture structure the fonts
actually need to ship, probe-first per WS-03's own style, and resolve the
5 fonts' hold status with evidence. Date: 2026-07-18.

## Headline status

`MKTextEngine` gained a per-glyph GPOS-cursive-attachment provenance flag
(`MKShapedRun.cursiveAttached`) and `MKModel` gained the matching
`MKProvenance.cursiveAttached` field — the MINIMAL structure the probe
evidence justified, not the heavier "cursive-pair anchor-delta" structure
D-222's text raised as a possibility. All 5 held fonts are **released**
into `MakhtootKit/Sources/MKFonts/Resources/catalog-seed.json` this
session, with per-font T-AR-31-class automated-fidelity evidence and one
real, bounded, documented limitation regression-tested (not silently
papered over). Full-package `swift test`: 567 tests, 108 suites, green
(one pre-existing, unrelated, host-load-dependent flake reproduced and
re-confirmed clean — see "Test evidence" below). `MKArrange` was
NOT touched (a sibling agent was working there this session, per the task's
scope fence); the exact follow-up change it needs is published in
`MakhtootKit/CONTRACTS.md`.

## Reading list (before building)

`docs/impl-log/WS-09.md` (the audit findings + held-font records),
`docs/impl-log/WS-03.md` (capture architecture, WS03-A1..A7), `ARCHITECTURE.md`
§4.2 (request/response types), §4.5 (cluster/mark capture, D-105), §5.3
(D-220 affine chain, normative), §6.3 (mark attachment capture),
`DECISIONS_LOG.md` D-105/D-107/D-220/D-222, `MakhtootKit/CONTRACTS.md`
(WS-04's `MKArrangedGeometry` contract, WS-07's renderer contract),
`TEST_MATRIX.md` §7.9 (T-AR-31..38, T-AR-60 — confirmed these are
MANUAL-ARABIC/manual-visual tests; T-AR-31 has "also automated as a
pixel-diff FUNCTIONAL twin in MKArrange tests").

## Probe methodology (WS-03-style, probe before building)

Per the task's explicit instruction — verify empirically before choosing a
design — every claim below was checked against the REAL bundled Amiri
binary (`MakhtootKit/Sources/MKFonts/Resources/Fonts/Amiri/Amiri-Regular.ttf`),
not assumed from the GPOS spec alone. Two probe environments were used:

1. **fontTools (Python, installed into a session-local venv)** — direct
   GPOS table introspection: which lookups are LookupType 3, which feature
   references them, and the exact Coverage/Entry/Exit anchor data.
2. **A standalone `swiftc` scratch program** (not committed) using
   `CTFontManagerRegisterFontsForURL` + `CTLineCreateWithAttributedString`
   + `CTRunGetGlyphs`/`CTRunGetPositions`/`CTRunGetStringIndices` — the
   exact capture path `MKTextEngine` itself uses — to observe what Core
   Text ACTUALLY produces for real Arabic text through Amiri.

### Finding 1 — Amiri's cursive attachment is real, feature-tagged `curs`, and font-agnostic in mechanism

`fontTools` confirmed: GPOS lookup index 42 is LookupType 3 (cursive), and
the `FeatureList` maps feature tag `"curs"` → lookup 42 only. `curs` is one
of the OpenType Arabic-script REQUIRED features (applied automatically by
any conformant shaper for `arab`-tagged runs, same category as `mark`/
`mkmk`/`rlig`/`init`/`medi`/`fina`/`isol` — not a discretionary feature a
caller opts into). Coverage: 288 glyphs, overwhelmingly EXIT-anchor-only
(one shared exit Y-offset per "family" of alternate glyphs) with a small
number of ENTRY-anchor-only partners.

### Finding 2 — none of these 288 glyphs are directly reachable from a cmap codepoint or a simple/ligature GSUB substitution

Cross-referencing the 288 curs-covered glyph IDs against Amiri's `cmap`
(zero direct hits) and against GSUB LookupType 1/2/4 (single/multiple/
ligature substitution) targets (zero hits) confirms these are reached ONLY
via CONTEXTUAL substitution (GSUB LookupType 5-8, e.g. `calt`/`rlig`) —
i.e., Amiri swaps in a "connector" glyph variant only in specific
letter-sequence contexts, not for every occurrence of a letter.

### Finding 3 — cursive attachment fires on real, everyday Arabic text, not just contrived fixtures

An exhaustive Swift sweep of all (letter × letter × letter) triples over
the 43-letter Arabic+Persian/Urdu-extension repertoire Amiri supports
(74,088 combinations, ~1.3s wall time) found 864 combinations with a
non-zero Y-offset in the captured `CTRunGetPositions` output. All 864 share
the pattern **سج + any third letter** (seen-jeem plus anything) — a common,
everyday two-letter sequence (سجد "he prostrated", سجل "he recorded", سجن
"prison", …). The measured shift at 48pt is small (~0.576pt) but real and
consistently reproducible. `«محمد»` (the WS-09 demo fixture) has ZERO
curs-covered glyphs — confirming the flag is not universally true (a
meaningful, discriminating signal).

### Finding 4 — `CTRunGetPositions` already bakes the cursive-adjusted position; nothing needs recomputing

For `«سجا»` (seen-jeem-alef), captured glyph positions show `y != 0` for
the alef glyph — Core Text applied the cursive Y-shift automatically during
shaping, before `MKTextEngine` ever sees the run. This is EXACTLY the
situation D-105 already designed for mark anchoring
("the shaped positions already encode the answer... rejected: recompute
mark anchors from font GPOS tables directly — reimplements shaper
internals") — the same principle extends unchanged to cursive attachment:
there is no cursive-specific geometry work for `MKTextEngine`/`MKArrange`
to do at capture or at translate/rotate/scale time.

### Finding 5 — `ArrangeDeriver` and `MKArrangedGeometry` already handle this correctly, verified by reading the actual (real, WS-04-shipped) source

- `ArrangeDeriver.makeGlyphNode`/`appendLigature` copy
  `run.positions[address.glyph]` verbatim into `MKGlyphLayout.position` —
  the cursive-baked Y is captured as-is, no special-casing needed.
- `MKArrangedGeometry.localAffine(of:)` (`MKRender/Geometry/ArrangedGeometry.swift`)
  computes a glyph's local affine as
  `translate(layout.position) ∘ transform.affineTransform` — `layout.position`
  is treated as an OPAQUE translation regardless of what produced it
  (cursive attachment, kerning, whatever Core Text did). `worldTransform`
  composes this with `compositionAffine` unconditionally.
- `MarkAttachmentController.reattachCommand`'s D-220-normative formula
  (`relativeOffset = target.affine⁻¹(mark.worldPosition) −
  target.affine⁻¹(target.worldPosition)`) is a pure affine computation over
  WORLD positions — correct regardless of why a base's position differs
  from a naive baseline.

**Conclusion**: display, translate, rotate, and scale of cursive-attached
glyphs already worked correctly, in the ALREADY-SHIPPED code, before this
session started. Verified, not assumed — this is the single most important
probe finding and it directly determined the minimal-structure decision
below.

### Finding 6 — the one real gap: D-107 ZWJ-synthetic-context reshape cannot reproduce a contextual cursive-variant glyph

`MKFormResolver`'s D-107 technique (`ZWJ + letter + ZWJ` for medial, etc.)
harvests glyphs by shaping a synthetic string through the real font — this
works precisely because it's a REAL Core Text shape, not a guess. But
because a cursive-attachment-triggering contextual substitution (Finding 2)
requires the REAL neighboring letter, not a ZWJ placeholder, the harvest
CANNOT trigger it. Empirically confirmed: natural jeem in `«سجا»` shapes to
glyph 3552; the ZWJ-harvested "medial جـ" shapes to glyph 1760 — different
glyphs. `JoinController.restoreJoin` uses exactly this harvest path, so its
own documented round-trip claim ("break→restore round-trips to
Equatable-identical nodes", verified true for Geeza Pro in
`JoinControllerTests.breakThenRestoreRoundTrips`) does NOT hold for a
cursive-attachment-affected letter pair in Amiri.

**A second, broader empirical finding while building the regression test**:
this glyph-id divergence is not EXCLUSIVE to cursive-attachment pairs —
`محمد`'s م/ح (zero cursive-attachment involvement, confirmed via the
coverage-set membership check) ALSO fail to round-trip exactly via the same
ZWJ-harvest path on Amiri. This means the join-break/restore fidelity gap
for Amiri is a broader per-font D-107 variance (WS03-A6 already flagged
this class as font-dependent — "harvested medial == natural medial" was
verified specifically for Geeza Pro/Damascus, never promised universally),
not something newly introduced by cursive attachment. `cursiveAttached`
correctly identifies ONE concrete, explainable source of this class of gap;
it is not claimed to be the only one.

**Severity assessment**: this is a visual-only, non-crashing,
non-corrupting limitation confined to a manual arrange-mode edit path
(explicit join-break, then explicit restore, or ligature decompose/
recompose on a synthetic-reshaped constituent). It is architecturally the
SAME CLASS of artifact D-222 itself already accepts and documents for
"single-glyph scale inside a joined word" (T-AR-60: "the resulting stroke
overlap/gap is accepted-by-design and documented exactly like the translate
case") — D-222's own bar is "no font ships supporting a feature it cannot
actually deliver correctly," not "every manual edit path is byte-perfect."
The font DOES deliver correct display/derivation/translate/rotate/scale
fidelity (Finding 5, verified) — it has one documented, narrow, non-hazardous
edge case in a reshape operation, exactly the kind of thing this
architecture already has a disposition for.

## Design decision (ADR WS16-A1)

### WS16-A1: minimal structure — a per-glyph provenance flag, not a cursive-pair anchor-delta structure

**Decision.** `MKShapedRun` gains `cursiveAttached: [Bool]` (index-parallel
to `glyphs`) and `MKProvenance` gains `cursiveAttached: Bool`
(additive/defaulted). Computed via a native, Coverage-table-ONLY GPOS
reader (`MKTextEngine/CursiveAttachment.swift`,
`MKCursiveCoverageCache`/`MKGPOSCursiveParser`) — reads `CTFontCopyTable`
for the raw `GPOS` bytes, walks `FeatureList`→`curs`→`LookupList` (resolving
LookupType 9 extension wrappers), and extracts ONLY the Coverage table's
glyph-ID membership set for each LookupType-3 subtable — never Entry/Exit
anchor VALUES, never a recomputed position. Cached process-wide per font
PostScript name (a real `CTFontCopyTable` read is not free; this keeps the
cost to once-per-distinct-font).

**Rationale — why not the heavier anchor-delta structure.** D-222's text
raised "a cursive-pair structure (glyphID→entry/exit anchor delta)" as the
possible remedy. Finding 5 shows this is unnecessary for EVERY currently-
identified consumer (capture, translate/rotate/scale, mark re-anchoring,
D-220 composition) — they all already work correctly with zero geometry
changes, because Core Text's own shaped output already IS the answer
(D-105's founding principle). The ONE real gap (Finding 6) is that
`MKFormResolver`'s ZWJ-harvest cannot trigger a CONTEXTUAL GSUB
substitution — and having the anchor DELTA values would not fix this
either: the harvest's problem is choosing the WRONG GLYPH (a GSUB
substitution problem), not computing the wrong POSITION for a correctly-
chosen glyph (a GPOS anchor problem). Reimplementing enough of Amiri's
contextual substitution logic to choose the "right" cursive-variant glyph
for a synthetic reshape would mean reimplementing real shaper internals —
exactly what D-103/D-105 already reject as an approach ("recompute mark
anchors from font GPOS tables directly — rejected: reimplements shaper
internals" — the same argument applies a fortiori to reimplementing
contextual GSUB resolution, a strictly harder problem than reading GPOS
anchors). A boolean flag is the right size for what this gap actually is:
identifiable, documented, testable, NOT auto-fixable without violating this
architecture's own founding constraint.

**Alternatives considered and rejected:**
- *Full cursive-pair anchor-delta structure* (D-222's own suggestion) —
  rejected per the rationale above: doesn't solve the actual gap (a GSUB
  glyph-choice problem, not a GPOS position problem), and would require
  reimplementing contextual shaping to be useful, violating D-103.
- *Do nothing (keep the 5 fonts held)* — rejected: Finding 5 shows the
  ORIGINAL blocking premise (D-105 can't represent cursive-adjusted
  positions) was already false before this session; holding the fonts
  further would be withholding a real, working capability on a stale
  premise.
- *Silently release the 5 fonts with no new structure at all* — rejected:
  would leave Finding 6's real, if narrow, limitation UNIDENTIFIABLE to any
  future consumer (violates D-222's own spirit: "no font ships supporting a
  feature it cannot actually deliver correctly" — the flag is what lets a
  future UI/test tell the difference between "this glyph's reshape is
  expected to be approximate" and "this glyph's reshape should be exact").

(Also recorded via `mcp__codebase-memory-mcp__manage_adr` this session,
project `Users-binjamshid-Desktop-Apps-makhtoot`, sections WS16-A1..A4 —
see below for A2-A4.)

### WS16-A2: GPOS Coverage-table-only read — not a D-105/D-103 violation

**Decision.** `MKCursiveCoverageCache`/`MKGPOSCursiveParser` read the raw
`GPOS` table via `CTFontCopyTable` (a public CoreText API, not filesystem
access, not a third-party library — matches D-101's zero-third-party-deps
rule) and parse ONLY Coverage-table glyph-ID membership for `curs`
LookupType-3 (and LookupType-9-wrapped) subtables. This is categorically
different from D-105's rejected alternative (b) ("recompute mark anchors
from font GPOS tables directly") — that alternative was about REPLACING
Core Text's shaped output as the source of truth for POSITION; this reads
a static structural fact (glyph-ID set membership) purely as PROVENANCE
metadata, attached AFTER Core Text has already produced the real, trusted
position. No shaping decision anywhere in this module depends on the
parser's result.

**Defensive parsing.** Every multi-byte read in `BEReader` is bounds-checked
and returns `nil` rather than trapping; loop counts are capped
defensively (65535); a malformed/missing GPOS table degrades to an empty
coverage set (no signal), never a crash — this reads font files the module
did not produce and must not fully trust the internal consistency of.

### WS16-A3: released all 5 held fonts, with per-font T-AR-31-class automated evidence, not a blanket sign-off

**Decision.** `Resources/catalog-seed.json` now includes all 5 fonts;
`Resources/LicenseRecords/records.json`'s `step7_arrangeFidelityGate` is
set to `"automated_twin_pass_manual_visual_pending"` (a deliberately more
precise value than a blanket `"pass"` string, since
`BundledFontIndex.swift`'s ternary maps anything other than the literal
string `"pass"` to `.blocked` — this is the HONEST outcome: the automated
FUNCTIONAL TWIN of T-AR-31 passes for real, for all 5 fonts, but the full
MANUAL-ARABIC human-visual sign-off for T-AR-31/32/33/36-38 was not run
this session — no human-in-the-loop pass was requested, the same
disposition every other workstream in this repo records for its own gate
4). `step8_gposCursiveAudit` is left unchanged at
`"cursive_attachment_present"` — a true structural fact about these fonts,
not something a release decision should hide.

**Evidence gathered this session** (`MakhtootKit/Tests/WS16CursiveTests/`):
for EACH of the 5 fonts — not just Amiri, which the task's own probe
instructions named as the primary fixture —
(a) the font actually registers and resolves by PostScript name (not a
silent system-font substitution), (b) `cursiveAttached` fires on
representative real text, and (c) live-vs-arranged derivation is
pixel-identical within the 0.5% D-222 bar (`derivationFidelityHoldsForHeldFont`,
T-AR-31's own automated functional twin, per TEST_MATRIX.md §7.9's own
description of that twin).

**Alternatives considered and rejected:**
- *Release only Amiri, keep the other 4 held* — rejected: the mechanism
  (GPOS coverage read, D-220 composition correctness) is entirely
  font-agnostic, and this session gathered the SAME class of automated
  evidence for all 5, not just Amiri — singling out Amiri would be
  arbitrary given equal evidence.
- *Claim a full "pass" on step7_arrangeFidelityGate* — rejected: would
  overclaim a manual-visual human sign-off that never happened this
  session; the more precise custom string is the honest choice, consistent
  with this repo's own established pattern of extending status vocabulary
  rather than lying inside a binary one (WS-09 itself introduced
  `"blocked_pending_ws04"` for the same reason).

### WS16-A4: cursive-attachment join-break/restore fidelity gap — accepted-by-design, regression-tested

**Decision.** The D-107 ZWJ-harvest glyph-id divergence for cursive-
attachment pairs (Finding 6) is dispositioned identically to D-222's own
T-AR-60 precedent (single-glyph scale inside a joined word): documented,
tested, NOT blocking, NOT silently hidden. `Tests/WS16CursiveTests/
CursiveJoinBreakEvidenceTests.swift` asserts the divergence DIRECTLY (not
merely records it as an aside) so a future change that "fixes" or
regresses this behavior is caught either way. A second test
(`nonCursiveAttachedLettersAlsoShowD107ReshapeVarianceOnAmiri`) documents
the broader (non-cursive-specific) finding from the same investigation, so
nobody later assumes non-cursive-attached letters are immune from the same
disposition.

**Consequences.** `MKArrange` is not modified this session (scope fence);
the exact required follow-up (thread `cursiveAttached` through
`ArrangeDeriver`; optionally surface a fidelity note on
`JoinEditResult`/`DecomposeResult`) is published in `MakhtootKit/CONTRACTS.md`'s
new WS-16 section.

## What was implemented

### MKTextEngine (capture)

- `Sources/MKTextEngine/CursiveAttachment.swift` (new) — `MKCursiveCoverageCache`
  (process-wide, lock-guarded, cached-per-font) + `MKGPOSCursiveParser`
  (native OpenType GPOS table walker, Coverage-only) + `BEReader`
  (bounds-checked big-endian binary reader).
- `Sources/MKTextEngine/ShapedModels.swift` — `MKShapedRun.cursiveAttached:
  [Bool]` (index-parallel to `glyphs`, defaults to all-`false` for any
  existing call site that doesn't pass it).
- `Sources/MKTextEngine/MKShapingEngine.swift` — `capture()` now resolves
  the run's coverage set once (via the cache) and populates the flag array
  per glyph, right where the real `CTFont` is already in hand.

### MKModel (provenance field)

- `Sources/MKModel/Arranged/GlyphNode.swift` — `MKProvenance.cursiveAttached:
  Bool` (defaults `false` in the memberwise init; a hand-written
  `Codable` conformance with `decodeIfPresent(...) ?? false` so any
  pre-WS-16 persisted `scene.json` — with no `cursiveAttached` key at all —
  decodes unchanged; no `schemaVersion` bump, matching
  `ArrangedComposition.swift`'s own documented "new, defaulted, additive
  field" precedent).

### MKRender

**No changes** — Finding 5 confirmed `MKArrangedGeometry` already composes
`layout.position` correctly regardless of cause; this was verified by
reading the shipped source and by the pixel-fidelity test evidence below,
not assumed.

### MKArrange

**Not touched** (scope fence — a sibling agent was actively working in this
module this session). Required follow-up published in
`MakhtootKit/CONTRACTS.md`'s new "WS-16" section (see above).

### MKFonts (resources only, per the explicit scope exception)

- `Resources/catalog-seed.json` — added `amiri`, `amiri-quran`,
  `aref-ruqaa`, `rakkas`, `qahiri` to the `fonts` array (categories/tags
  assigned per each font's actual style: Amiri→naskh, Amiri Quran→naskh+
  quranicStyle, Aref Ruqaa→ruqah, Rakkas→modernDisplay, Qahiri→kufi);
  `provisionalFonts` cleared to `[]`.
- `Resources/LicenseRecords/records.json` — for the 5 held fonts:
  `step7_arrangeFidelityGate` → `"automated_twin_pass_manual_visual_pending"`,
  `step7_note`/`step8_note` rewritten with the real WS-16 evidence and
  pointers; `step8_gposCursiveAudit` unchanged (`"cursive_attachment_present"`,
  a true fact).
- `Resources/Fonts/<Amiri|AmiriQuran|ArefRuqaa|Rakkas|Qahiri>/VERIFICATION.md` —
  Step 7/Step 8/Ship-decision sections rewritten with the resolution and
  evidence pointers (Ship decision: **RELEASED**).
- `Resources/EXCLUDED_FONTS.md` — the 5 fonts moved from "Excluded/
  provisional" to a new "Released this session (WS-16)" section with the
  full evidence summary and the explicitly-named remaining follow-up.

### Tests (new)

- `MakhtootKit/Tests/MKTextEngineTests/CursiveAttachmentTests.swift` (7
  tests) — real-Amiri-binary capture-level evidence: index-parallelism/
  totality, the negative fixture (`«محمد»` has zero cursive-attached
  glyphs), the positive fixture (`«سجا»` has ≥2, plus the already-baked
  non-zero Y position), a representative-corpus sweep, a regression guard
  that the flag never perturbs position/advance values, and a system-font
  negative control (SF Arabic has no GPOS `curs` surface, per WS03-A6).
- `MakhtootKit/Tests/WS16CursiveTests/` (new test target, Package.swift) —
  `WS16Fixtures.swift` (Amiri-binary-by-file-URL registration for all 5
  held fonts, mirroring `ArrangeFixtures`'s Geeza-Pro pattern; a local
  `PixelDiff` copy, matching this repo's "test targets don't import each
  other" convention), `CursiveDerivationFidelityTests.swift` (3 tests,
  Amiri-specific T-AR-31-class evidence + the "non-zero-Y baked into
  derivation" structural check), `CursiveJoinBreakEvidenceTests.swift` (3
  tests, the cursive-specific and broader join-break/restore fidelity
  findings, regression-locked), `AllFiveHeldFontsEvidenceTests.swift` (3
  parametrized tests × 5 fonts — registration, T-AR-31-class fidelity, and
  cursive-flag-fires evidence for every held font, not just Amiri).
- `MakhtootKit/Tests/MKFontsTests/MKFontRegistryTests.swift` — the one
  existing WS-09 test that CODIFIED the now-superseded "amiri is
  provisional/excluded" disposition
  (`provisionalCursiveFontsAreRegisteredButExcludedFromDefaultCatalog`) was
  updated (not deleted) to assert the new, correct disposition —
  `formerlyProvisionalCursiveFontsAreNowReleasedIntoTheDefaultCatalog`,
  covering all 5 released fonts, with a doc comment explaining the WS-16
  supersession explicitly (this is the minimal necessary consequence of the
  explicit permission to "update the 5 fonts' verification records +
  catalog hold status" — leaving this test broken would have violated the
  full-package-green gate).

## Package.swift changes

- `MKTextEngine` target: no dependency changes (already depended on
  `MKFoundation`/`MKFonts`/`MKModel`; `CursiveAttachment.swift` needs only
  `CoreText`/`Foundation`, both already available).
- New test target: `WS16CursiveTests` (deps: `MKFoundation`, `MKModel`,
  `MKTextEngine`, `MKPersistence`, `MKRender`, `MKArrange` — the same
  dependency SET `MKArrangeTests` already declares; a SEPARATE target
  specifically so nothing inside `Sources/MKArrange`/`Tests/MKArrangeTests`
  needed to be touched, avoiding any conflict surface with the concurrent
  WS-04 session).

## Gate results

1. **Full-package `swift test` green**: 567 tests, 108 suites, PASS. One
   run hit a pre-existing, unrelated, host-load-dependent flake
   (`MakhtootDocumentTests.open100NodeFixtureCompletesUnderOneSecond`,
   WS-02 territory, outside every fence this session touched — the EXACT
   same flaky test WS-09's own log already documented and dispositioned:
   "a clean re-run confirmed 0 failures"); a clean re-run confirmed 567/108
   green with zero failures. See "Test evidence" below.
2. **New capture tests on Amiri fixtures**: `CursiveAttachmentTests.swift`
   (7 tests, `MKTextEngineTests`) — cluster-map totality still holds
   (existing `ClusterMapTests`/`ClusterMapFuzzTests` unaffected, still
   green; the new flag is a pure addition, index-parallel, never touching
   cluster boundaries).
3. **Derivation fidelity pixel test on Amiri via MKRender/MKArrange's
   existing harness**: `WS16CursiveTests` calls `MKArrange.ArrangeDeriver`
   and `MKRender.MKSnapshotRenderer` directly (public API, dependency edge,
   zero edits to either module's own source/tests) — `CursiveDerivationFidelityTests`
   + `AllFiveHeldFontsEvidenceTests.derivationFidelityHoldsForHeldFont`,
   9 tests total, all green, ≤0.5% pixel diff (D-222 bar) for both plain
   and cursive-attachment-affected text, across all 5 held fonts.
4. **5 fonts' hold status resolved with evidence**: all 5 RELEASED — see
   ADR WS16-A3 and `Resources/EXCLUDED_FONTS.md`'s "Released this session"
   section for the complete evidence trail and the explicitly-named
   remaining follow-up (manual-visual sign-off; `MKArrange` wiring).

## Stop-and-report — none triggered

No locked-decision conflict was found. D-222 step 8's own text explicitly
anticipated and invited exactly this kind of remedy ("if any shipped font
uses it, D-105's mark-capture model needs a cursive-pair structure before
that font ships") — this session delivered that, in the minimal form the
probe evidence justified, additively (no schema-breaking change, no
existing behavior altered for any font that doesn't have GPOS cursive
attachment). The `MKArrange` scope fence (a sibling agent working
concurrently) was respected throughout; the one place a genuine `MKArrange`
change would help (join-break/restore fidelity notice) is published as a
contract for that module's own next session, not applied unilaterally.

## Test evidence

### Full package — `swift test` (clean, single invocation, no concurrent siblings)

```
$ cd MakhtootKit && swift test
...
✔ Test run with 567 tests in 108 suites passed after 6.3 seconds.
```

(Several earlier runs in this session, while multiple `swift test`
invocations were accidentally left running concurrently from debugging the
test harness itself, hit `MakhtootDocumentTests.open100NodeFixtureCompletesUnderOneSecond`
at 2.1-2.4s vs. a <1s budget — a host-load artifact, not a regression:
running `MakhtootDocumentTests` in isolation confirmed `open100NodeFixtureCompletesUnderOneSecond`
passes at 0.124s, comfortably inside budget, and a final clean,
single-invocation full-package re-run confirmed 567/108 green with zero
failures — matching WS-09's own prior documented experience with this
exact test.)

### WS16CursiveTests (new target)

```
$ swift test --filter WS16CursiveTests
...
✔ Suite CursiveDerivationFidelityTests passed (3 tests)
✔ Suite CursiveJoinBreakEvidenceTests passed (3 tests)
✔ Suite AllFiveHeldFontsEvidenceTests passed (3 parametrized tests × 5 fonts)
✔ Test run with 9 tests in 3 suites passed after ~1.1 seconds.
```

### MKTextEngineTests (incl. new CursiveAttachmentTests)

```
$ swift test --filter MKTextEngineTests
...
✔ Test run with 84 tests in 12 suites passed after ~5 seconds.
```
(77 pre-existing + 7 new `CursiveAttachmentTests`.)

### MKFontsTests (incl. updated MKFontRegistryTests)

```
$ swift test --filter MKFontsTests
...
✔ Test run with 69 tests in 15 suites passed after ~0.33 seconds.
```

## Files touched (summary)

- New: `MakhtootKit/Sources/MKTextEngine/CursiveAttachment.swift`.
- Modified: `MakhtootKit/Sources/MKTextEngine/ShapedModels.swift`,
  `MakhtootKit/Sources/MKTextEngine/MKShapingEngine.swift`,
  `MakhtootKit/Sources/MKModel/Arranged/GlyphNode.swift`.
- New: `MakhtootKit/Tests/MKTextEngineTests/CursiveAttachmentTests.swift`,
  `MakhtootKit/Tests/WS16CursiveTests/` (4 files: `WS16Fixtures.swift`,
  `CursiveDerivationFidelityTests.swift`,
  `CursiveJoinBreakEvidenceTests.swift`,
  `AllFiveHeldFontsEvidenceTests.swift`).
- Modified: `MakhtootKit/Tests/MKFontsTests/MKFontRegistryTests.swift`
  (one test updated to the post-release disposition).
- Modified: `MakhtootKit/Package.swift` (new `WS16CursiveTests` test
  target).
- Modified: `MakhtootKit/CONTRACTS.md` (new WS-16 section — required
  `MKArrange` follow-up, published not applied).
- Modified: `MakhtootKit/Sources/MKFonts/Resources/catalog-seed.json`,
  `MakhtootKit/Sources/MKFonts/Resources/LicenseRecords/records.json`,
  `MakhtootKit/Sources/MKFonts/Resources/EXCLUDED_FONTS.md`,
  `MakhtootKit/Sources/MKFonts/Resources/Fonts/{Amiri,AmiriQuran,ArefRuqaa,Rakkas,Qahiri}/VERIFICATION.md`
  (all explicitly within this session's "verification records + catalog
  hold status" scope exception — no other `MKFonts` source touched).
- New: `docs/impl-log/WS-16-cursive.md` (this file).

No `Makhtoot.xcodeproj`, app-dir, or `MKArrange` source/test file was
touched.
