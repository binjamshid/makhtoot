# SVG `@font-face` subset embedding — deferred follow-up

**Status**: v1 (this session) ships **FULL-font** `@font-face` embedding
for fonts with `.svg` embedding rights (`SVGTextWriter.swift`). A computed
SUBSET (D-227(3)'s originally-specified shape, matching the PDF vector
writer's automatic subset-embedding via `CTFontDrawGlyphs`) is **not**
implemented — recorded here as a deliberate deferral, per the packet's own
instruction: *"if a correct minimal subsetter is too large for this
session, ship FULL-font embedding for OFL-verified fonts with a documented
size tradeoff + subsetting as a recorded follow-up... do NOT ship a
half-correct subsetter."*

## Why a minimal subsetter was assessed as too large to ship safely

A correct TrueType/OpenType subsetter needs to, at minimum:

1. Determine the used-glyph set (from the shaped runs actually emitted).
2. Rewrite `glyf`/`loca` (TrueType outlines) or `CFF ` (PostScript
   outlines) to include only those glyphs, remapping every glyph ID
   reference throughout the file consistently.
3. Rewrite `cmap` so remaining Unicode → glyph-ID mappings stay correct
   after remapping.
4. Patch `hmtx`/`hhea`/`maxp`'s glyph-count-dependent fields.
5. Regenerate `head.checkSumAdjustment` and the whole-file checksum (fonts
   with an incorrect checksum are rejected outright by some strict
   parsers).
6. Handle composite glyphs (`glyf` component references) correctly when
   subsetting TrueType outlines — a component glyph not itself in the
   requested subset must still be retained (transitively).

This is a genuine, nontrivial binary-format transform with several
interacting tables that must all stay internally consistent, or the
resulting font either fails to parse (most viewers) or silently renders
wrong glyphs (worse — a viewer that leniently ignores a bad checksum but
uses a stale/incorrect `glyf` offset table). Building this from scratch,
with no dependency (D-101: zero third-party dependencies in v1), inside a
single session, carries real correctness risk that a "full font, just
bigger" fallback does not.

## Decision

Ship FULL-font embedding now (a strictly valid, spec-compliant
`@font-face` payload — just larger than a subset would be) and record
subsetting as a follow-up, rather than risk shipping a subsetter that
occasionally produces a malformed font (an objectively worse outcome: a
malformed embedded font can break the ENTIRE SVG file in strict viewers,
whereas a larger-than-necessary valid font only costs file size).

## Size tradeoff (documented, not measured this session)

A typical Arabic OFL font's full TTF/OTF file is commonly in the
100 KB – 2 MB range depending on how many OpenType features/glyph variants
it carries; a subset containing only the glyphs a given SVG export
actually uses is often an order of magnitude smaller for short text (a few
KB) but converges toward the full file size for long/varied text (e.g. a
Qur'anic passage exercising most of the glyph repertoire). The tradeoff is
therefore most costly for SHORT-text exports (a social-media caption in a
5 MB font embeds the whole 5 MB) and least costly for long/varied text.

## Reserved Font Names note (D-227(3), unchanged)

Whether subsetting an OFL font with Reserved Font Names would even satisfy
the RFN clause is a SEPARATE, still-open legal question
(`VERIFY-AT-SUBMISSION`, per D-227(3)) — this deferral does not resolve or
depend on that question either way; full-font embedding sidesteps it
entirely (the RFN clause concerns MODIFIED/subset redistributions, not
verbatim embedding), which is an independent point in favor of the
full-font decision above, not the deciding one.

## What a future subsetting pass should reuse

- `MKExportFontDataProviding` (`MKExportFontDataProviding.swift`) is
  already the seam a subsetter would sit behind — a real conformer could
  compute the used-glyph set from the SAME `MKShapingEngine` output
  `SVGTextWriter`/`TextOutlining` already produce and return SUBSET bytes
  instead of the whole file, with zero call-site changes in
  `SVGSerializer`/`SVGTextWriter`.
- The PDF vector writer needs no equivalent work: `CTFontDrawGlyphs`
  writing into a `CGContext`-backed PDF already performs CORRECT automatic
  subset embedding as a CoreGraphics/CoreText built-in behavior — this
  deferral is SVG-only.
