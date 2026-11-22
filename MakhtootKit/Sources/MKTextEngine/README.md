# MKTextEngine

Owner: WS-03 (`AGENT_TASK_PACKETS/WS-03-text-engine.md`). Two-pass build:
the early spike (capture on MKFoundation types) and the P3-completion pass
(MKModel integration + the full analyzer/service surface). Full ADRs,
session logs, deviations, and evidence: `docs/impl-log/WS-03.md`.

## Surface

**Request side** (real MKModel types — the WS03-A1 seam is resolved):
- `MKShapingRequest` (`ShapingRequest.swift`) — `MKSourceText` (string +
  per-range `MKStyleRun` overrides) + `MKTextStyle` + `MKTextFrameSpec`.

**Capture core**:
- `MKShapingEngine` (`MKShapingEngine.swift`) — pure, uncached
  `CTTypesetter`/`CTLine`/`CTRun` capture (D-103), incl. the two-pass
  per-cluster-pair kerning-override pipeline and multi-line wrapping.
- `MKAttributedStringBuilder` (`AttributedBuilder.swift`) — the single
  attributed-string construction path (base attrs + style-run overrides +
  forced-RTL writing direction for `.rightToLeftOverride`).
- `MKFontFeatureControl` (`FontFeatureControl.swift`) — D-108
  `MKLigatureSetting` → OpenType feature settings on the **font**. `rlig`
  is not controllable by design (packet task 2).
- `ShapedModels.swift` — `MKShapedRun`/`MKShapedLine`/`MKShapedParagraph`,
  raw verbatim capture. `CoordinateSpace.swift` documents the y-up
  line-local convention + the one UIKit flip helper.

**Maps & analyzers**:
- `MKClusterMap`/`MKClusterMapBuilder` (`ClusterMap.swift`) — D-105
  codepoint ↔ cluster ↔ glyph; each `MKCluster` mints a durable
  `MKClusterID` (MKFoundation UUID phantom type → `MKProvenance.clusterID`).
- `MKBidiMap`/`MKBidiMapBuilder` (`BidiMap.swift`) — D-109 run capture +
  per-glyph global visual indices (→ `MKProvenance.visualIndex`).
- `MKMarkClassifier` (`MarkClassifier.swift`) — D-105 ranges → MKModel
  `MKMarkClass`. `MKMarkAttacher` (`MarkAttachment.swift`) — mark→base
  resolution with `CGSize` relative offsets (→ `MKMarkNode.relativeOffset`).
- `MKLigatureDetector` (`LigatureDetector.swift`) — required/
  discretionary/contextual detection records with feature-state provenance.
- `MKJoiningTypeTable`/`MKJoiningAnalyzer` (`JoiningTypeTable.swift`,
  `JoiningAnalyzer.swift`) — UCD ArabicShaping-derived joining types,
  per-letter `MKJoiningState` (MKModel type), `validForms` metadata
  (right-joining letters expose {isolated, final} only — T-TXT-6).

**Form resolution & outlines**:
- `MKFormResolver` (`FormResolver.swift`) — D-107 ZWJ synthetic-context
  harvest, cached per (font, size, scalar, form), with right-joining
  coercion + `wasCoerced`.
- `MKGlyphPathProvider` (`GlyphPathProvider.swift`) — `CTFontCreatePathForGlyph`
  → MKModel `MKPathData` (1000/em), LRU cache, negative caching for
  outline-less glyphs.

**Facade**:
- `MKShapingService` (`ShapingService.swift`) — the D-102 actor:
  full-request-hash LRU cache (cost = glyphs × 64 B, 32 MB default,
  ARCHITECTURE §4.7), `typingEcho` signpost (D-115) on the single-line
  path, and `captureResult(_:)` bundling marks/ligatures/joining per line
  for WS-04. `invalidateCache()` is the WS-09 (font re-registration) /
  WS-07 (memory ladder) hook.

## Coordinate system

Positions in `MKShapedRun.positions` are exactly what `CTRunGetPositions`
returned: **line-origin-relative, Core Text y-up**. No rounding or
reinterpretation at capture (INV-6). Paragraph line stacking is a
rendering concern (MKRender, P4).

## Cluster algorithm walkthrough

D-105: `CTRunGetStringIndices` gives, per glyph, the UTF-16 index of the
*first* codepoint of the cluster that produced it. `MKClusterMapBuilder`
inverts that (see its doc comment for the 6-step algorithm). Worked
examples:

**"لا" (lam + alef, 2 codepoints).** One glyph; both codepoints share
`stringIndex 0` → one cluster, 2 codepoints, 1 glyph → `.ligature` —
D-105's ligature candidate exactly.

**"شَدَّةٌ" (7 codepoints).** Against system SF Arabic: three runs (all RTL —
shaping-internal split, not bidi), six logical clusters:
`[ش][fatha][د+shadda-fused][fatha][ة][tanwin]`. `MKMarkAttacher` reports
**4** marks, each resolved to a base; the fused shadda has
`markGlyph == nil` (no distinct glyph) but is still enumerated — "no mark
is orphaned."

## Per-font / per-OS capture notes (durable — re-verify at WS-09)

Captured against system SF Arabic + Geeza Pro, Xcode 26.6 / iOS 26.5 sim
/ macOS 26 host:

- **«الله»** (no tashkeel typed) → **one glyph** for all 4 codepoints in
  SF Arabic. Font-dependent; do not assume Amiri matches.
- **Harakat get their own `.markOnly` cluster** in SF Arabic; **shadda
  fuses** into its base's glyph. `MKMarkAttacher` therefore resolves bases
  by walking backward across cluster boundaries, not same-cluster
  membership.
- **Arabic-Indic digits split into their own non-RTL run** (`عام ٢٠٢٦`),
  differing from ARCHITECTURE §8.3's illustrative phrasing. Faithful
  capture is the requirement (D-109); flagged for the next §8.3 editor.
- **D-107 leading-ZWJ limitation in the system SF font**: `.SFNS`/SF
  Arabic ignores a *leading* U+200D — medial/final synthetic contexts come
  back initial/isolated. Geeza Pro and Damascus (bundled, macOS + iOS)
  honor D-107 fully: all four forms distinct, harvested medial == natural
  medial in «محمد» (verified in tests). Consequence for WS-04: the form
  picker on system-font text cannot offer real medial/final harvests until
  the text uses a real Arabic font — WS-09's Amiri/Noto fixtures resolve
  this for shipped fonts. `FormResolverTests` runs against Geeza Pro via a
  test-local `MKFontProviding` conformer.
- **Feature settings round-trip only for supported features**: Core Text
  silently drops an OpenType feature setting the font doesn't implement
  (e.g. `dlig` on SF Arabic / AAT-only fonts). Harmless; the dlig
  glyph-count-difference test (T-TXT-7) joins the WS-09 Amiri re-run.

## Tolerance policy (packet task 14)

Zero hardcoded glyph ids. Structure only: counts, mappings, relations,
offset *signs*. The one allowed glyph-id comparison is the same-process
consistency check (harvested form vs natural context, `FormResolverTests`),
which never leaves the process or the font.

## Consumer guide (WS-04/05/07/08)

- Use `MKShapingService` (cached, signposted) on interactive paths;
  `MKShapingEngine` directly for batch/offline analysis.
- `captureResult(_:)` is the WS-04 derivation input: paragraph + per-line
  marks/ligatures/joining, all in absolute (full-string) UTF-16 indices.
- Never re-derive cluster/bidi maps from `runs` by hand.
- `MKCluster.id`, `MKBidiMap.glyphVisualIndex`, `MKMarkAttachment
  .relativeOffset`, `MKLetterJoining.state`, `MKDetectedLigature
  .activeSetting`, `MKGlyphPathProvider`'s `MKPathData` — each maps 1:1
  onto the MKModel provenance field WS-04 must fill (`clusterID`,
  `visualIndex`, `MKMarkNode.relativeOffset`, `MKGlyphNode.joining`,
  ligature provenance, `MKGlyphNode.outline`).
