# Makhtoot (مخطوط) — DECISIONS_LOG.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.
> [D-328](#d-328--free-access-for-all-implemented-features) governs current feature
> access. Earlier decisions describe the access model at the time they were recorded.

## Durable Architecture Decision Records — Run 1

This log is the full-rationale expansion of every decision in FOUNDATION.md (D-100…D-126,
FD-01…FD-07) plus the derived sub-decisions Run 1 had to make (D-200+). Records are
formatted for codebase-memory MCP ADR ingestion: Run 3 replays each `## D-xxx` /
`## FD-0x` block verbatim via `manage_adr`. Every record is self-contained.

Authority chain: `_input/BRIEF.md` (locked founder requirements) > FOUNDATION.md
(decision backbone) > this log (rationale). Where this log and FOUNDATION.md disagree,
FOUNDATION.md is right and this log has a bug. Evidence citations `[^n]` refer to the
reference numbers in `docs/makhtoot-market-study.md`. Legal/policy claims not covered by
a market-study citation are marked `VERIFY-AT-SUBMISSION` — no such fact is invented here.

Two founder overrides of market-study recommendations are recorded explicitly and
honestly: D-117 (True CMYK in v1, overriding study §7 deferral advice) and D-209
(no Qur'anic content, overriding study §6 Tanzil-quote recommendation).

## Format note (added 2026-07-20, portfolio house standard — matrix row 5)

Every record already carries a stable, citable id (`D-1xx`/`D-2xx`/`FD-0x`) — the
core requirement of the house pattern. This note adds the two fields the portfolio
review's decision-log pattern names as commonly dropped, **for every entry written
from this date forward**. Existing D-1..D-231/FD-01..FD-07 entries are NOT
retrofitted with these fields (retrofitting would mean inventing migration-impact
and supersession answers after the fact for records whose authors never considered
them — indistinguishable from fabrication); several existing entries already carry
the same information in prose (e.g. D-117 ends `Amended by D-226.`, which is a
supersession pointer in everything but name) and that prose stands as written.

New entries add:
- **Migration impact** — one line: what changes (schema, wire format, call sites,
  shipped copy) if this decision is later reversed, and how expensive that reversal
  is. "Price the reversal" (masoon's phrase) rather than leaving it undiscoverable
  until someone actually tries.
- **Supersedes** — `Supersedes: D-xxx` / `Supersedes: none` header line. When a new
  entry replaces or amends an earlier one, the earlier entry gets a one-line
  retrofit *pointer only* (e.g. `Amended by D-226.`, already this log's existing
  convention per D-117) — never a rewrite of its original content.

Template for new entries:

```
## D-NNN — <one-line title>
Supersedes: D-xxx | none
- **Status**: accepted | open | ⛔ blocking(founder-input)
- **Date**: YYYY-MM-DD
- **Owner**:
- **Context**:
- **Decision**:
- **Alternatives considered**:
- **Consequences**:
- **Migration impact**: what a reversal costs, concretely.
- **Confidence**:
- **Dependencies**:
- **Validation trigger**:
```

---

# Part I — Foundation decisions (D-100…D-126)

## D-100 — Platform: universal iPhone+iPad, iOS 18 minimum, Swift 6, SwiftUI shell + UIKit canvas
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF locks universal iPhone+iPad, one codebase, genuinely adaptive layouts, iOS 18 minimum, Arabic-only RTL UI. The market study's architecture instruction (§12, §14) concludes the app cannot be built on SwiftUI's high-level `Text` view for Arrange Mode and prescribes a SwiftUI-shell / custom-canvas hybrid[^61]. Competitors are either iPad-only one-time-purchase tools (Procreate[^17][^18]) or generator apps with no per-glyph engine at all[^1][^2][^4]. The founder permits UIKit/Core Text/TextKit 2/Core Graphics/Metal wherever needed (Q47).
- **Decision**: One universal app target `Makhtoot`, iOS 18.0 minimum deployment, Swift 6 language mode with strict concurrency checking, Xcode 16.x toolchain. SwiftUI owns the app shell (navigation, project browser, panels, inspector, paywall, settings); the canvas is a UIKit view hosted via `UIViewRepresentable`. `ar` is the only localization and the development region. Size-class-adaptive layouts (compact iPhone: sheet-based panels; regular iPad: persistent side panels) — one codebase, no target forks.
- **Alternatives considered**: (a) iOS 17 minimum for wider reach — rejected: founder locked 18; iOS 18 gives current SwiftData, CKSyncEngine maturity, and RTL API refinements, and v1 ships into an iOS-18+ installed base anyway. (b) iPad-only like Procreate[^17] — rejected: BRIEF locks universal; the social-export use case (story/status presets) is iPhone-centric. (c) Cross-platform (Flutter/React Native/Skia) — rejected: the entire differentiator depends on direct Core Text run introspection (`CTRunGetGlyphs`/`CTRunGetPositions`/`CTRunGetStringIndices`)[^23] and native RTL correctness; bridging that through a portability layer adds risk and violates the no-third-party-dependency stance (D-204). (d) Pure SwiftUI including canvas — rejected: SwiftUI exposes no per-glyph geometry, no fine-grained gesture arbitration at 5,000-node scale, and no layer-level transform control (market study §4, §12)[^20][^61].
- **Consequences**: Positive — full access to Core Text/Core Graphics/TextKit 2; Swift 6 strict concurrency catches data races between editor and export at compile time; single codebase honors the adaptive-layout requirement. Negative — excludes pre-iOS-18 devices; UIKit canvas means a representable seam that must be kept narrow (obligation: canvas communicates with SwiftUI only via the document store and a thin `MKCanvasBridge`); strict concurrency imposes `Sendable` discipline on every engine type (obligation carried by D-102).
- **Confidence**: high — every constraint here is founder-locked or forced by the glyph-engine requirement the whole product rests on.
- **Dependencies**: none (root decision).
- **Validation trigger**: P0 exit: project builds clean under Swift 6 strict concurrency on Xcode 16.x for iPhone and iPad simulators; P4 exit: canvas interaction works identically in compact and regular size classes.

## D-101 — Project layout: one app target + local SPM package MakhtootKit; no third-party deps; xcodebuild + gh only
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Founder Q49 locks tooling to Xcode, `xcodebuild`, `gh` — no XcodeGen/Tuist/Fastlane/external CI unless necessary and justified. Run 3 will be executed by coding agents working workstream-by-workstream (WS-01…WS-15), which needs hard module boundaries so agents cannot silently couple engines. The repo does not exist yet (founder will `git init`, FD-01).
- **Decision**: One `Makhtoot.xcodeproj` with a single app target, plus one local Swift package `MakhtootKit` containing all sixteen library targets listed in FOUNDATION §2 (`MKFoundation`, `MKModel`, `MKTextEngine`, `MKArrange`, `MKPathText`, `MKCanvas`, `MKRender`, `MKColor`, `MKExport`, `MKFonts`, `MKPersistence`, `MKSync`, `MKStore`, `MKAnalytics`, `MKDesignSystem`, `MKAssets`). Dependency directions are exactly the FOUNDATION §2 table; SPM enforces them at compile time. Zero third-party packages (D-204). Build/verify/distribute via `xcodebuild` and `gh`; App Store Connect operations that have no API are Chrome-driven per BRIEF.
- **Alternatives considered**: (a) Many small standalone packages — rejected: version-coordination overhead with zero consumers besides the app. (b) Single monolithic app target with folder groups — rejected: no compiler-enforced boundaries; agent-driven Run 3 would erode layering within days. (c) XcodeGen/Tuist project generation — rejected: founder-prohibited absent necessity; a single stable `.xcodeproj` plus SPM targets makes project-file merge conflicts rare enough not to justify the tool. (d) Fastlane for distribution — rejected: `xcodebuild -exportArchive` + `xcrun altool`/App Store Connect API cover the automatable surface; Q56/Q84 pauses for founder credentials regardless.
- **Consequences**: Positive — compile-time layering; per-target unit test bundles map 1:1 to workstreams; fast incremental builds for agents touching one engine. Negative — SPM resource handling for bundled fonts/assets needs explicit `Resource` declarations (obligation on WS-09/WS-14); the app target stays thin (obligation: no engine logic outside MakhtootKit).
- **Confidence**: high — standard, low-risk structure that directly encodes founder tooling constraints.
- **Dependencies**: D-100, D-204.
- **Validation trigger**: P0 exit: `xcodebuild build test` green from a clean clone with no tooling beyond Xcode + gh; dependency-direction check (no import violating FOUNDATION §2 table) passes in every later phase.

## D-102 — Concurrency model: @MainActor UI/document, Sendable engine services, snapshot-in/value-out rendering
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF performance section demands no artificial caps, continuous memory monitoring, robust autosave, and quantitative budgets — meaning export, autosave, sync, and font installs run concurrently with 120 Hz editing. Swift 6 strict concurrency (D-100) makes the isolation architecture a compile-time contract rather than a convention.
- **Decision**: The mutable document (current `MKScene`, undo stack, selection) is `@MainActor`. Every engine that does heavy work — shaping capture, export rendering, CloudKit sync, font download/install, analytics aggregation — is a `Sendable` service operating exclusively on immutable value snapshots handed to structured-concurrency task groups. The renderer and exporter never see the live document; they receive a copied `MKScene` value (cheap: value-type tree with copy-on-write arrays, D-203). Results return as values applied on the main actor. No locks, no `@unchecked Sendable` in engine code without a written justification comment.
- **Alternatives considered**: (a) Actor-per-engine holding mutable state — rejected: re-entrancy hazards and await-ordering bugs in gesture-hot paths; snapshot passing is simpler to reason about. (b) GCD queues + manual locking — rejected: forfeits Swift 6 compile-time checking. (c) Fully single-threaded with async chunked export on main — rejected: violates D-115 budgets (4K export <10 s cannot share the main thread with 8.3 ms frames).
- **Consequences**: Positive — export/preview can never race the editor (the invariant that makes tiled export D-210 and background autosave D-112 safe); data-race freedom is compiler-verified. Negative — snapshot copying cost must stay negligible, which constrains the model to value types with CoW (obligation on D-111/D-203); engines cannot "reach back" for extra state mid-task — every input must be in the snapshot (occasionally verbose API).
- **Confidence**: high — this is the canonical Swift 6 architecture for editor apps, and the value-type model (D-111) was chosen partly to enable it.
- **Dependencies**: D-100, D-111, D-203.
- **Validation trigger**: P2 exit: zero strict-concurrency diagnostics; P14: Thread Sanitizer clean while running simultaneous edit + autosave + 4K export stress scenario from TEST_MATRIX.

## D-103 — Shaping source of truth: Apple Core Text; never a custom shaper; never presentation-form codepoints
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF locks "Custom native object/layout/rendering layer for Arrange Mode ATOP Apple shaping APIs — no ground-up Arabic shaper." The market study confirms Core Text performs Arabic shaping, joining, bidi reordering, and tashkeel positioning correctly by default, and that the per-glyph geometry needed for Arrange Mode is reachable via `CTRunGetGlyphs`, `CTRunGetPositions`, `CTRunGetStringIndices` with `kCTRunStatusRightToLeft` signaling visual-order reversal[^20][^21][^22][^23] (study §4).
- **Decision**: All shaping is Core Text: build `NSAttributedString` (font, feature settings, kerning/tracking, baseline) → `CTTypesetterCreateWithAttributedString` → `CTLine` → `CTRun` extraction of glyphs, positions, advances, string indices, attributes, and RTL status. Glyph outlines come from `CTFontCreatePathForGlyph`. MKTextEngine is a *capture* layer over Core Text output, never a reimplementation. Unicode presentation-form codepoints (U+FB50–FDFF, U+FE70–FEFF) are banned for rendering or form realization anywhere in the codebase (see D-202 for the joining-form technique that replaces them).
- **Alternatives considered**: (a) Bundle HarfBuzz — rejected: heavyweight third-party dependency (violates D-204) duplicating what the OS shaper already does; would also shape differently from the system in edge cases, breaking the "typing feels native" requirement. (b) Custom shaper — rejected outright by BRIEF; multi-year effort, permanent correctness liability across fonts. (c) Presentation-form codepoint substitution for contextual forms — rejected: modern OpenType Arabic fonts implement shaping via GSUB, not presentation-form cmap coverage; many bundled candidates would render .notdef or inconsistent glyphs (recorded fully in D-202).
- **Consequences**: Positive — shaping correctness, tashkeel positioning, and bidi are inherited from the same engine that renders every Arabic text field on iOS; zero maintenance of script logic. Negative — Makhtoot is coupled to Core Text's public introspection surface; anything Core Text doesn't expose (e.g., which GSUB lookups fired) must be *inferred* from cluster maps (D-105) rather than read directly — an accepted analytical burden. Obligation: per-font cluster-map fixtures in TEST_MATRIX because font GSUB behavior varies.
- **Confidence**: high — study §4 verifies the API path end-to-end, and the constraint is founder-locked.
- **Dependencies**: D-100.
- **Validation trigger**: P3 exit: shaping-capture fixtures (cluster/glyph/position maps) pass on all twenty D-120 candidate fonts for the Arabic verification corpus (lam-alif, tashkeel stacks, Qur'anic-range marks, mixed bidi, both numeral systems).

## D-104 — Typing mode: UITextView (TextKit 2) overlay for input; engine renders the committed object
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF requires typing to behave exactly like a native text field: shaping, IME, selection, tashkeel entry, mixed-script editing. The market study prescribes: "Text input/IME should use standard UIKit/SwiftUI text-editing components bound to the underlying Unicode string (for correct system-level Arabic keyboard behavior)" (§12)[^61]. Meanwhile canvas display and export must be pixel-identical, which a UILabel/UITextView cannot guarantee against the custom renderer.
- **Decision**: While a Live Text object is being edited, a UITextView (TextKit 2) overlay is placed over the object's canvas frame, styled to match the object's font, size, kerning, alignment, and paragraph direction so metrics visually match. All keyboard/IME/selection/marked-text behavior is the system's. On commit (end editing), the overlay is removed, the source string + style flow into MKTextEngine shaping capture, and the object is thereafter drawn only by MKRender — the same path export uses. The overlay is an input device, never a renderer of record. (Expanded trade study in D-201.)
- **Alternatives considered**: (a) Implement `UITextInput` on the canvas view — rejected: months of marked-text/selection/dictation edge cases to reimplement what UITextView gives free (full analysis in D-201). (b) Render *with* UITextView permanently — rejected: cannot guarantee canvas≡export parity, no path text, no per-glyph capture hooks. (c) Off-canvas editing sheet — rejected: breaks WYSIWYG in-place editing expectation.
- **Consequences**: Positive — native Arabic keyboard behavior with zero custom text-input code; engine parity between canvas and export guaranteed by construction. Negative — a visible "editing → committed" swap exists; the overlay must track zoom/transform of the host object (obligation: overlay is only offered for unrotated or axis-aligned editing at reasonable zoom — rotated objects temporarily normalize during editing, documented in PRD §5). Minor metric drift between TextKit 2 preview and Core Text commit is possible; mitigation is shared font/attribute construction code.
- **Confidence**: high — the pattern is standard for canvas editors and endorsed by the market study's own architecture instruction[^61].
- **Dependencies**: D-100, D-103.
- **Validation trigger**: P4/P5 boundary test T-TYPE-*: type the Arabic verification corpus, commit, and confirm engine-rendered output visually matches the overlay within tolerance on all bundled fonts; typing echo <50 ms (D-115).

## D-105 — Cluster model: bidirectional codepoint ↔ cluster ↔ glyph map; marks become Mark Nodes
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Arrange Mode must support both shaped-glyph manipulation and underlying Unicode-letter manipulation with nothing lost when switching levels (BRIEF). The study identifies the bidirectional logical↔visual map as "essential and non-trivial groundwork," built from `CTRunGetStringIndices` with `kCTRunStatusRightToLeft`[^23]. Tashkeel and full Qur'anic-style marks must attach to bases, follow them, and be individually selectable (founder Q11: full mark range).
- **Decision**: For every shaped line, MKTextEngine constructs a three-level map: codepoint index ↔ cluster ↔ glyph id(s). Clusters derive from contiguous equal string-index runs. A cluster with >1 codepoint mapping to 1 glyph is flagged a ligature candidate (lam-alif and discretionary). Combining marks — Unicode general categories Mn/Me, explicitly including U+0610–061A, U+064B–065F, U+0670, and the Qur'anic annotation range U+06D6–06ED — are lifted out as Mark Nodes attached to their base Glyph Node, storing the shaped relative offset (the GPOS mark-attachment result as captured from `CTRunGetPositions` deltas), a follow-base flag (default true), and their source codepoints.
- **Alternatives considered**: (a) Treat mark+base as one opaque glyph unit — rejected: BRIEF requires marks individually selectable/detachable/movable. (b) Recompute mark anchors from font GPOS tables directly — rejected: reimplements shaper internals (violates D-103); the shaped positions already encode the answer. (c) Grapheme-cluster segmentation via `NSString.enumerateSubstrings` alone — insufficient: grapheme clusters don't align with ligature glyph boundaries; the string-index method reflects what the font actually did[^23].
- **Consequences**: Positive — level-switching without loss becomes a lookup, not a heuristic; ligature detection falls out of the same map. Negative — fonts differ in cluster granularity (some fuse mark+base into one glyph); such fonts get a documented capability flag `fusedMarks` and marks are then selectable only as part of the base (limitation surfaced in PRD §7, tested per font). Obligation: the map is part of the persisted Arranged Composition provenance (D-111) so reopening a document never re-derives it against a possibly-updated font.
- **Confidence**: medium — the API path is verified[^23], but per-font cluster behavior variance is the single biggest empirical unknown in the engine; fixtures exist precisely to burn this down.
- **Dependencies**: D-103.
- **Validation trigger**: P3 exit: cluster-map fixtures pass on all bundled fonts, including at least one font with fused mark glyphs handled via the capability flag.
- Amended by D-220.

## D-106 — Arrange derivation: snapshot shaped result into Arranged Composition with Source Text Backup
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF: Arrange Mode is an explicit action creating a separate arranged structure (glyphs, positions, advances, joining state, tashkeel attachments, ligature groups, style state) with the original string retained as a reversible backup; arranged compositions never auto-reflow. Study §4 prescribes exactly this: convert live shaped text into editable vector objects at the moment of entering Arrange Mode, retaining the Unicode source for reflow[^23].
- **Decision**: Entering Arrange Mode snapshots the current shaping capture into an `ArrangedComposition` node: Glyph Nodes (glyph id, font reference, outline path, position, advance, joining state, source codepoints, cluster id, bidi level), Mark Nodes (per D-105), Ligature Groups (member glyph node, constituent codepoints, decomposable flag). The complete source string plus full style state is stored inside the node as the Source Text Backup. Arrangement edits mutate only the composition. Revert-to-text requires an explicit confirmation dialog and replaces the composition with a Live Text object rebuilt from the backup, discarding all manual arrangement. No auto-reflow path exists from arranged state.
- **Alternatives considered**: (a) Keep text live and overlay per-glyph transform deltas on top of reflowing layout — rejected: any retype reshapes and orphans deltas; BRIEF explicitly forbids auto-reflow of arranged content. (b) Destructive conversion without backup — rejected: BRIEF requires reversibility. (c) Dual-live sync (edit text and arrangement simultaneously) — rejected as v1 scope: mapping arbitrary text edits onto arbitrary glyph rearrangements is an unsolved UX problem; the explicit mode switch is the honest model.
- **Consequences**: Positive — clean invariant (INV: an arranged node's geometry is fully self-contained and font-file-independent for display, since outlines are captured); documents survive font updates without visual drift. Negative — captured outline paths grow document size (~measured in P3, budgeted in D-112); reverting loses work by design, hence the confirmation obligation. Obligation: everything needed to re-render must live in the node (outlines, not just glyph ids), so exports and sync never need the original font present for arranged content.
- **Confidence**: high — direct transcription of locked requirements onto the verified Core Text capture path.
- **Dependencies**: D-103, D-105, D-111.
- **Validation trigger**: P5 exit: arrange → transform every node type → revert → confirm restored text is byte-identical to backup; arranged document renders identically with the source font removed from the registry.
- Amended by D-220.

## D-107 — Joining forms after explicit break: ZWJ synthetic-context reshaping
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF: joining is preserved by default; breaking a join is explicit; after a break the user gets a visual selector for isolated/initial/medial/final forms. Realizing "the medial form of ح in this font" requires making the font produce that glyph on demand — but D-103 bans presentation-form codepoints and forbids reading GSUB directly.
- **Decision**: To realize a chosen Joining Form for a single letter, MKArrange shapes a tiny synthetic string through the normal Core Text path in the same font: ZWJ (U+200D) placed to simulate joining context — `ZWJ + letter + ZWJ` for medial, `letter + ZWJ` for initial, `ZWJ + letter` for final, bare letter for isolated — then harvests the resulting glyph id and outline, discarding the ZWJ artifacts (ZWJ is zero-width and produces no visible glyph). The node stores `JoiningForm` enum + resolved glyph id + outline. (Full trade study vs alternatives in D-202.)
- **Alternatives considered**: (a) Presentation-form codepoints — rejected (D-202: unreliable cmap coverage in OpenType-shaped fonts, banned by D-103). (b) Direct GSUB `init/medi/fina/isol` lookup execution — rejected: reimplements shaper internals. (c) Only allow the forms that naturally occur — rejected: BRIEF explicitly requires user choice among all four forms after a break.
- **Consequences**: Positive — font-consistent forms guaranteed for any font whose shaper honors ZWJ (standard Arabic OpenType behavior); zero font-table parsing. Negative — a hypothetical font could mishandle ZWJ context; per-font form fixtures are therefore mandatory before a font ships (obligation folded into WS-09 verification). The synthetic reshape is a few microseconds per invocation — negligible.
- **Confidence**: high — ZWJ join-causing behavior is core Unicode Arabic shaping semantics honored by Core Text; residual per-font risk is fixture-covered.
- **Dependencies**: D-103, D-106; expanded by D-202.
- **Validation trigger**: P6 exit: form-selector fixtures produce correct isolated/initial/medial/final glyphs for every joining-capable letter across all bundled fonts (T-FORM-* in TEST_MATRIX).
- **Amendment note (DF-5, Run-2)**: module ownership reconciled with FOUNDATION — the ZWJ form-resolution primitive (`MKFormResolver`) lives in MKTextEngine; MKArrange invokes it; FOUNDATION governs this ownership split.

## D-108 — Ligature decomposition: reshape constituents in joining context, place to match original bounds; recomposition restores stored glyph
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF: ligatures (lam-alif + discretionary/contextual) must be both single selectable objects and decomposable components; decomposition preserves the original ligature look by default via positioning/kerning; the user may explicitly opt out to default forms (founder Q71). The study lists ligature decomposition as a high-value, high-difficulty gap no competitor offers (§3).
- **Decision**: A Ligature Group stores the original combined glyph (id + outline + bounds) and its constituent codepoints (from the D-105 cluster map). Decomposition reshapes each constituent letter with joining-preserving synthetic context (D-107 technique), then computes per-constituent offsets/scales so the assembled constituents visually match the original ligature bounds — fidelity-first default. An explicit user toggle instead places constituents at default spacing/forms (Q71 opt-out). Recomposition is always available and restores the stored original ligature glyph exactly. Discretionary ligature *availability* is controlled pre-arrangement via Core Text font-feature settings (`kLigaturesType`, OpenType `dlig`/`calt`).
- **Alternatives considered**: (a) Split the ligature outline geometrically (path surgery) — rejected: no reliable letter boundary inside a calligraphic lam-alif; results would be visually wrong and font-specific. (b) Decompose to default forms only — rejected: Q71 requires fidelity-preserving default. (c) Forbid decomposition of non-lam-alif ligatures — rejected: BRIEF includes discretionary/contextual ligatures explicitly.
- **Consequences**: Positive — unique market capability (study §3); recomposition is lossless by construction because the original glyph is stored, not recomputed. Negative — fidelity matching is heuristic (bounds alignment, not stroke continuity); for extreme calligraphic ligatures the seam may show — documented limitation in PRD §8 with the opt-out as the escape hatch. Obligation: per-font ligature fixtures including at least lam-alif in all four joining contexts.
- **Confidence**: medium — mechanism is sound, but visual fidelity across the whole D-120 font list is empirical; fixtures and the Q71 opt-out bound the risk.
- **Dependencies**: D-105, D-106, D-107.
- **Validation trigger**: P6 exit: decompose/recompose round-trip is pixel-identical for the stored-glyph path on all bundled fonts; fidelity-mode visual review passes the manual Arabic verification checklist (Q59 gate).
- Amended by D-221.

## D-109 — Bidi: preserve CTLine run order, per-run RTL status, bidi level + visual index on arranged nodes
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF requires mixed Arabic-English, both numeral systems, and punctuation to behave correctly in typing and in arrangement. The study confirms Core Text implements UBA system-wide and instructs preserving CTLine run boundaries so Latin and Arabic runs stay separately coherent[^23][^24].
- **Decision**: MKTextEngine records the CTLine run list in order with each run's `kCTRunStatusRightToLeft` status. Arranged nodes each carry `bidiLevel` and a `visualIndex` so sub-run ordering is reconstructible after arbitrary user rearrangement. Paragraph base direction comes from `NSParagraphStyle` and defaults to RTL. Selection and keyboard navigation in Live Text follow system behavior (the D-104 overlay); arranged-mode marquee/selection operates in visual space only, where bidi ordering is irrelevant to hit testing but preserved in provenance.
- **Alternatives considered**: (a) Run the UBA independently (custom implementation) — rejected: duplicates Core Text, guaranteed divergence (violates D-103 spirit). (b) Store only visual order and drop logical provenance — rejected: revert-to-text (D-106) and Unicode-level manipulation require logical order retention. (c) Force RTL-only documents — rejected: BRIEF locks mixed-script support.
- **Consequences**: Positive — bidi correctness is inherited, not implemented; provenance suffices for lossless revert. Negative — visual-index bookkeeping must survive grouping/ungrouping and cross-object moves (obligation: bidi metadata is immutable provenance, never recomputed after arrangement).
- **Confidence**: high — inherits the platform's UBA[^24]; the only novel code is bookkeeping.
- **Dependencies**: D-103, D-105, D-106.
- **Validation trigger**: P3/P5 fixtures: mixed Arabic-Latin-numeral corpus round-trips through arrange → revert with byte-identical text; visual order matches a native UITextView rendering of the same string.

## D-110 — Path text: arc-length parameterized Bézier layout, RTL-aware pen, live until arranged
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF locks curved/circular/freeform text on dynamic live Bézier paths (Q72), editable/reflowable along the path until arranged. Core Text has no curved-baseline support; the study assesses custom path placement as "known, solvable but non-trivial 2D geometry," realistic for v1 as a static feature (§4), and flags RTL-correct path text as a differentiator even against Canva/Affinity (§3).
- **Decision**: MKPathText builds an arc-length lookup table over the user's Bézier path (adaptive subdivision to a documented flatness tolerance). Layout shapes the text normally (D-103), then walks glyphs in visual order — RTL-aware, so the pen starts at the path start and advances by each glyph's advance along arc length — assigning each glyph position = arc point, rotation = local tangent angle, plus any user baseline offset. Live Path Text objects reflow on retype and the path itself stays editable via control points. Entering Arrange Mode freezes to an Arranged Composition (D-106) whose nodes keep per-glyph adjustability; the path becomes a non-editing reference stored for provenance.
- **Alternatives considered**: (a) Chord-based placement (straight-line segments between samples) — rejected: visible faceting on tight curves; arc-length LUT is barely more work. (b) Per-character (not per-glyph) placement — rejected: breaks ligatures and marks; placement must operate on shaped glyphs with their cluster relationships (marks follow their base's arc position). (c) Allow path editing after arrangement with automatic re-projection — rejected: contradicts the no-auto-reflow invariant of arranged content; users who want a new path revert first.
- **Consequences**: Positive — headline differentiator (study §3 rates RTL path text medium-high value/defensibility); static-only scope matches v1 (animation is v2 per BRIEF). Negative — extreme curvature causes glyph overlap/gap artifacts; mitigation is a curvature warning plus per-glyph manual adjustment after arrangement (documented in PRD §9). Marks-on-path follow base arc positions — tested explicitly since it is the likeliest visual bug source.
- **Confidence**: high — geometry is well-understood; RTL specifics are handled by operating in visual order over shaped output.
- **Dependencies**: D-103, D-105, D-106.
- **Validation trigger**: P7 exit: circle/wave/sharp-corner fixtures render correct RTL order, tangent rotation, and mark attachment on all bundled fonts; retype-reflow works live; arrange freezes correctly.

## D-111 — Scene graph: immutable value-type tree, decomposed transforms, provenance-carrying arranged children, single canvas
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: The document model must support: unbounded undo/redo (BRIEF), snapshot rendering without races (D-102), Codable persistence (D-112), 5,000-node performance (D-115), and full provenance for arranged content (D-106). The study's instruction prescribes "an internal scene-graph data model … each with transform, style, and Unicode-provenance metadata" (§12, §14).
- **Decision**: `MKScene` is an immutable value-type tree. `MKNode` is an enum: `group`, `liveText`, `pathText`, `arranged`, `shape`, `image`, `background`. Every node carries `id: UUID`, a *decomposed* transform (position, rotation, scale — never a raw matrix), z-order, opacity, style (fill: solid color in v1; stroke; shadow), locked/hidden flags, and a user-visible name. Arranged children are glyph/mark/ligature nodes with provenance (source codepoints, glyph id, font reference, joining form, cluster id, bidi level, captured outline). One canvas per project in v1; the scene root reserves a `pages` seam (single-element array, schema-visible) so multi-page in v2 is additive, not a migration (expanded in D-214).
- **Alternatives considered**: (a) Reference-type (class) node graph — rejected: undo, snapshotting, and Sendable all get harder (full trade study in D-203). (b) Raw 3×3 matrix transforms — rejected: the numeric inspector must show editable X/Y/W/H/rotation (BRIEF); decomposing a matrix back to user-meaningful values is lossy and ambiguous under negative scale; storing decomposed values makes the inspector trivial and round-trip exact. (c) Entity-component store (flat arrays + component tables) — rejected: excellent for engines, hostile to Codable document formats and to human-debuggable scene.json; v1 scale doesn't need it.
- **Consequences**: Positive — undo = keep previous value; render snapshot = copy the value; Codable derivation is mechanical; inspector maps 1:1 to stored fields. Negative — deep-tree updates need path-based mutation helpers (write-once utility in MKModel); memory duplication bounded by CoW (obligation: arrays and outline paths are CoW/shared storage). Obligation: `schemaVersion` gates every persisted change to this shape.
- **Confidence**: high — the requirements triangulate to exactly this design; it is also what D-102/D-112 were designed against.
- **Dependencies**: D-102, D-106; expanded by D-203, D-214.
- **Validation trigger**: P2 exit: model round-trips (encode→decode→re-encode byte-stable) for fixture scenes including a 5,000-node arranged stress document; P14: snapshot copy time within frame budget.

## D-112 — Persistence: file-package documents (JSON scene + assets) + SwiftData metadata index + CKSyncEngine premium sync
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Founder Q50 calls for "one decisive recommendation + alternatives/tradeoffs, evaluated against arranged-object graph scale, undo/redo, autosave, import assets, CloudKit sync." The forces: (1) *Arranged-object graph scale* — a heavily arranged document is thousands of glyph/mark nodes each with outline paths and provenance; documents are large but self-contained, and loaded/saved as a unit while editing. (2) *Undo/redo* — BRIEF requires full undo/redo; the value-type scene (D-111) makes undo a matter of retained prior values, which fights any framework that wants managed mutable objects. (3) *Autosave* — BRIEF performance section requires immediate robust autosave under memory pressure and no-loss crash recovery; incremental autosave <100 ms off-main is a D-115 budget. (4) *Import assets* — raster/SVG/PDF imports are opaque blobs up to tens of MB that belong beside the project, not inside a database row. (5) *CloudKit sync* — premium-only, per-project, user's own iCloud (BRIEF; study §9 endorses CloudKit-keyed-to-Apple-ID to avoid any account system[^56][^57]). Also: no third-party dependencies (D-204), and the app is offline-first with search/folders/export-history over all projects without opening them.
- **Decision**: A hybrid, each store doing only what it is good at:
  1. **Project = `.makhtoot` file package** (a directory the system treats as one file; UTI `com.example.makhtoot.project`, placeholder-derived pending FD-01): `manifest.json` (ids, schemaVersion, canvas size, timestamps, thumbnail refs), `scene.json` (Codable D-111 scene graph), `assets/` (imported raster/SVG/PDF, content-addressed by SHA-256 so duplicates dedupe and sync diffs are cheap), `backups/` (rescue snapshots; Source Text Backups live inside scene nodes, not here), `thumbnail.png`.
  2. **Atomic writes**: serialize to temp file, `rename()` into place — a crash never yields a half-written scene. **Debounced autosave**: ≤2 s after last mutation, plus immediate synchronous save on background transition and memory-pressure stage 3 (D-116). **Crash-recovery journal**: the last un-flushed command batch is appended to a journal file; relaunch replays journal atop the last good scene.json — no-loss recovery as BRIEF demands.
  3. **Undo/redo**: in-memory stack of inverse operations over the value-type scene; unbounded within memory budget; gesture streams coalesce to one command. Undo state is *not* persisted (industry-standard; documented in PRD §21).
  4. **SwiftData store** (application-support, one store) holds ONLY metadata: project list/names/folders, search text, export history, font catalog + favorites + download state, analytics counters, trial/consent records. Never scene content. This powers browser/search/history without touching packages.
  5. **CloudKit sync (premium)**: CKSyncEngine; one record per project — manifest+scene as encrypted asset payloads, imported assets as CKAssets; last-writer-wins per project with conflict-copy fallback (D-208).
- **Alternatives considered**:
  - **(A) SwiftData-only (scene graph as model objects)** — rejected. Scale: thousands of glyph nodes as managed persistent objects means object-graph churn on every gesture; SwiftData's change tracking is per-object, and bulk-transforming 500 selected glyphs would thrash the store. Undo: SwiftData undo integrates with managed-object mutation, which directly conflicts with the immutable value-type scene (D-111) that D-102's race-free rendering depends on; adopting it would force a reference-type model and forfeit snapshot rendering. Autosave: framework-controlled save timing is a poor fit for the "synchronous save on memory-pressure-critical" requirement. Assets: multi-MB blobs in the store degrade its performance and make per-project export/share/backup (a whole project as one shareable unit) awkward. Sync: SwiftData's built-in CloudKit mirroring syncs the whole store — it cannot express "premium users sync projects; free users sync nothing; metadata never syncs," and offers no conflict-copy control. Migration: schema evolution of a deep node hierarchy under a young framework is a real risk for documents users may keep for years; a Codable JSON schema with an explicit `schemaVersion` and hand-written migrations is boring and auditable.
  - **(B) Core Data** — rejected for the same structural reasons as (A) (managed reference objects vs value scene; whole-store NSPersistentCloudKitContainer mirroring vs selective premium sync; blob handling), with more boilerplate and none of SwiftData's Swift-native ergonomics. Its maturity is real but buys nothing here because the scene never wants to be an object graph in the first place.
  - **(C) GRDB / raw SQLite (scene rows in a database)** — rejected. GRDB violates the no-dependency policy (D-204); raw SQLite means hand-writing a persistence layer. The supposed win — partial loading/querying of scene rows — is a non-goal: an open document is fully in memory by design (whole-scene snapshots, D-102), and cross-project queries only need metadata, which SwiftData already covers. Fine-grained row updates would also fight value-type snapshots. No benefit at v1 scale; real cost.
  - **(D) UIDocument/NSDocument + iCloud Drive (document-based app)** — the strongest alternative; rejected on sync-control grounds. UIDocument gives coordination/versioning and iCloud Drive gives "free" sync — but: iCloud Drive sync is all-or-nothing per container and user-controlled in Files, so gating sync behind *premium entitlement* is not cleanly enforceable; conflict handling surfaces as `UIDocumentState.inConflict` with NSFileVersion resolution, which is clumsier than the explicit LWW+copy policy (D-208); documents-in-Drive expose the package to arbitrary external mutation while open; and UIDocument's read/write lifecycle (background queues, `contents(forType:)`) adds ceremony without removing any work — atomic-rename + our own journal already meet the autosave/no-loss bar. We do adopt its *good* ideas: file packages, atomic writes, and `NSFilePresenter`-style coordination where Files-app export is involved. CKSyncEngine keeps sync programmable: entitlement-gated, per-project records, explicit conflict policy, resumable transfers.
  - **(E) Single JSON file per project (no package)** — rejected: multi-MB imported assets would be base64-bloated into the scene file, autosave would rewrite assets on every edit, and content-addressing/dedup would be impossible.
- **Consequences**: Positive — each requirement maps to a mechanism purpose-built for it; documents are portable, inspectable, diffable, and shareable as single units; the scene schema is fully owned (migrations are explicit code, `schemaVersion`-gated); sync is entitlement-gated by construction; zero dependencies. Negative — two stores means an obligation to keep the metadata index consistent with packages on disk (reconciliation pass at launch: orphaned packages re-indexed, dangling index rows pruned — specified in ARCHITECTURE §13); JSON is verbose (mitigated by compact encoding; compression is an extension seam, measured in P2 before deciding); undo does not survive relaunch (accepted, documented). Obligations created: schema-migration test fixtures from every released schemaVersion; journal-replay crash tests; reconciliation tests.
- **Confidence**: high — the alternatives fail on named, concrete requirement axes rather than taste; the chosen design is composed of individually boring, verifiable mechanisms.
- **Dependencies**: D-102, D-111, D-204; expanded by D-208, D-210 interactions; consumed by D-113 (trial records), D-125 (counters).
- **Validation trigger**: P2 exit: crash-kill during rapid mutation recovers with zero data loss across 100 randomized trials; incremental autosave <100 ms off-main at 5,000 nodes; P12: entitlement-gated sync verified (free account never uploads).

## D-113 — Entitlement precedence and resolution: lifetime > subscribed > grace > billingRetry > trial > free; on-device StoreKit 2 verification in v1
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF locks full StoreKit 2: status, restore, lifetime/sub precedence, grace period, billing retry, expiration messaging, and "a decided position on on-device verification vs App Store Server API." The market study confirms: entitlement state should derive from `Transaction.currentEntitlements` with states `.subscribed`/`.expired`/`.inGracePeriod`/`.inBillingRetryPeriod`/`.revoked`, ideally cross-validated server-side[^43]; Apple supports lifetime non-consumables coexisting with subscriptions and *requires* a Restore Purchases mechanism per Guideline 3.1.2(c)[^45][^46][^47]. Apple's grace period auto-retries billing — exact current durations must be re-verified before hardcoding UX copy[^43] (`VERIFY-AT-SUBMISSION`). Makhtoot has no backend (BRIEF: no mandatory account; sync is user-iCloud CloudKit).
- **Decision**: A single source of truth, `MKEntitlementResolver`, observes `Transaction.currentEntitlements` and `Product.SubscriptionInfo.Status` and resolves one `EntitlementState` with strict precedence: `lifetime > subscribed > inGracePeriod > inBillingRetry > trial > free`. Grace and billing-retry states retain full premium access plus a non-blocking "payment issue" banner deep-linking to Apple subscription management[^43]. Verification is on-device StoreKit 2 in v1: Apple's JWS signature check via `VerificationResult` — `.verified` transactions only. App Store Server API integration is a documented extension seam (requires a backend that does not exist in v1), not a v1 feature. Restore Purchases is mandatory UI in the paywall and Settings[^45]. All gating queries (export D-119, fonts D-120–122, sync D-124) consume the resolver via protocol so MKStore stays mockable in tests.
- **Alternatives considered**: (a) Server-side receipt validation via App Store Server API — deferred: study recommends it as "ideal"[^43] but it requires standing infrastructure the product deliberately lacks; the threat it counters (jailbreak-class local tampering) is disproportionate to a $3/mo tool, and the seam is kept. (b) Trusting `Transaction` without verification result checks — rejected: free rigor discarded for nothing. (c) Multiple ad-hoc entitlement checks scattered per feature — rejected: precedence bugs (e.g., expired sub masking lifetime) are exactly what a single resolver prevents; the lifetime-must-never-pay-again rule is an App Review expectation[^45].
- **Consequences**: Positive — one resolver, one precedence table, one test surface; grace/retry generosity minimizes wrongful lockouts. Negative — on-device-only verification is spoofable by determined attackers (accepted, documented risk memo in ARCHITECTURE §18); grace-period *durations* in copy must stay vague ("مهلة سماح") until `VERIFY-AT-SUBMISSION`. Obligation: StoreKit sandbox test plan covering every state transition (Q59 gate).
- **Confidence**: high — precedence and states mirror StoreKit 2's own model[^43]; the no-backend constraint decides the verification question.
- **Dependencies**: D-100, D-123; consumed by D-119, D-121, D-122, D-124 (sync gating).
- **Validation trigger**: P11 exit: StoreKit sandbox matrix (purchase, upgrade, cancel, grace, retry, revoke, restore, lifetime-over-expired-sub) passes; VERIFY-AT-SUBMISSION recheck of grace-period durations before final copy.
- Amended by D-228.

## D-114 — Renderer: Core Graphics + CALayer-per-top-level-node canvas; Metal as documented seam only
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: The study instructs: implement the canvas as a custom rendering surface "backed by Core Graphics (Metal only if profiling later shows a real performance need)" (§14). D-115 sets 8.3 ms ProMotion frame budgets; BRIEF demands zoom/pan, multi-select, guides, snapping at 5,000-node scale. Content is 2D vector (glyph outlines, shapes) + raster images — Core Animation's compositor is already a GPU engine for exactly this.
- **Decision**: MKRender draws node content with Core Graphics into per-node backing stores; the canvas (MKCanvas) is a UIScrollView-zoomable host whose top-level nodes each own a CALayer. Manipulation (drag/rotate/scale) mutates layer transform properties — GPU-composited, no redraw — so gestures hit 60/120 Hz cheaply. Content redraws happen only on style/text change or zoom-scale bucket change, into bitmap-cached layer contents at the current scale. Export shares the same CG drawing code against full-resolution contexts (D-118, D-210) — one drawing truth. Metal is an extension seam documented in ARCHITECTURE §24, to be adopted only if P14 profiling fails budgets.
- **Alternatives considered**: (a) Metal renderer from day one — rejected: large engineering cost, shader text rendering pipeline, and the compositor path likely meets budgets for static 2D scenes; premature. (b) Single flat CG redraw per frame — rejected: full-scene redraw at 5,000 nodes cannot hold 8.3 ms during gestures. (c) SwiftUI Canvas — rejected: no per-node layer transforms, limited caching control, opaque performance. (d) SpriteKit/SceneKit — rejected: scene-graph semantics aimed at games; text fidelity and print-precision vector output are second-class.
- **Consequences**: Positive — cheapest path to budget-meeting interaction; canvas/export parity by shared drawing code. Negative — CALayer count itself becomes a scaling limit (top-level nodes only get layers; arranged children draw into their parent's layer — this is the layer-explosion control); zoom-bucket redraws must be async and cancellable (obligation on MKRender). Metal migration, if ever needed, is isolated behind the renderer protocol.
- **Confidence**: high — matches the study's instruction and standard editor practice; risk is bounded by the Metal seam.
- **Dependencies**: D-102, D-111, D-115.
- **Validation trigger**: P14: Instruments frame-time profile of the TEST_MATRIX stress scenes meets D-115 budgets on ProMotion and A12-class floors; failing that, the Metal seam decision reopens.

## D-115 — Quantitative performance budgets (gates, not aspirations)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF: "Quantitative frame-time, latency, loading, export, memory budgets for all iOS 18 devices," with performance profiling as a release gate (Q59). Budgets must be concrete enough for TEST_MATRIX to pass/fail.
- **Decision**: Binding budgets: manipulation frame time ≤8.3 ms on ProMotion hardware, ≤16.6 ms floor on A12-class; typing echo <50 ms; open typical project (≤100 nodes) <1 s; open heavy project (5,000 nodes) <3 s; incremental autosave <100 ms off main thread; 4K PNG export <10 s on A15; peak editor memory <60% of `os_proc_available_memory` before the D-116 degradation ladder begins. These numbers gate P14 exit and appear as T-PERF-* rows in TEST_MATRIX.
- **Alternatives considered**: (a) Qualitative goals ("feels smooth") — rejected: not gateable, invites drift. (b) Stricter across-the-board budgets (e.g., 8.3 ms everywhere) — rejected: A12-class hardware cannot honestly commit to ProMotion budgets; dishonest gates get ignored. (c) Deferring budget definition to implementation time — rejected: budgets shape architecture (they are why D-114 chose layer transforms and D-102 chose snapshots); they must precede code.
- **Consequences**: Positive — every performance argument in this package resolves to a number; degradation (D-116) has a defined onset. Negative — budgets may prove miscalibrated on real hardware; renegotiation is allowed but must be recorded as a superseding decision, not silently relaxed. Obligation: profiling harness scenes checked into the repo (WS-07).
- **Confidence**: medium — the numbers are informed engineering estimates pending first-device measurement; the *existence and gating role* of budgets is high-confidence.
- **Dependencies**: D-100, D-102, D-114, D-116.
- **Validation trigger**: P14 exit: all T-PERF-* rows green on the device matrix; any red row forces either optimization or a recorded budget-revision decision.

## D-116 — Memory-pressure ladder: monitor, degrade preview, save; tiled export decouples output size from RAM
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF: no artificial caps on canvas/glyph/object counts; continuous memory-pressure monitoring, early warnings, immediate robust autosave, no-loss recovery after termination; soft degradation as an engineering safeguard, not a feature cap. Founder Q76: no artificial export caps — warn near memory limits and autosave.
- **Decision**: MKFoundation hosts a memory monitor combining `DispatchSource` memory-pressure events with periodic `os_proc_available_memory` sampling. Ladder: (1) at 70% usage — drop offscreen bitmap caches, trigger autosave now; (2) at 85% — degrade preview fidelity (half-resolution layer bitmaps, simplified shadow rendering) and show the banner "الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا" (memory nearly full — autosaved); (3) on a critical pressure event — synchronous autosave + journal flush so jetsam termination loses nothing; relaunch restores exactly (D-112 journal). Huge exports never load a full-resolution bitmap: rendering is tiled in bounded strips (D-210), so output size is limited by disk, not RAM.
- **Alternatives considered**: (a) Hard caps on nodes/canvas size — rejected: BRIEF explicitly forbids artificial caps. (b) Reactive-only (respond to system warning, no sampling) — rejected: the system warning can arrive too late for a graceful save on constrained devices; sampling buys the early stages. (c) Purging scene data (not just caches) under pressure — rejected: the scene is the user's work; only derived data (caches, previews) is ever sacrificed.
- **Consequences**: Positive — honors "no caps" honestly: the app degrades previews, never capabilities; no-loss recovery is mechanically guaranteed by stage-3 + journal. Negative — degraded preview is a visible fidelity drop (banner explains it); sampling has minor battery cost (interval tuned in P14). Obligation: jetsam-recovery test (kill under pressure, verify restoration) in TEST_MATRIX.
- **Confidence**: high — mechanisms are standard OS facilities; the ladder stages are tunable parameters, not architecture.
- **Dependencies**: D-112 (journal), D-114 (caches), D-210 (tiled export); thresholds feed D-115.
- **Validation trigger**: P14: forced-jetsam recovery trials pass 100/100; stage transitions observed at intended thresholds on lowest-RAM supported device.
- Amended by D-223.

## D-117 — Color pipeline: extended-sRGB working space; True CMYK print-PDF via ICC conversion at export (founder override of market-study deferral)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: This record documents a founder override, honestly. The market study assessed CMYK/PDF-X compliance as Medium-Low feasibility — Quartz supports CMYK color-space creation (`CGColorSpaceCreateDeviceCMYK`) and PDF/X-1a mandates 4-channel CMYK, but iOS lacks a robust built-in CMYK preview/soft-proofing pipeline and RGB→CMYK shifts are a documented pain point[^40][^41][^42] — and explicitly recommended deferring true CMYK to v1.1/v2, shipping RGB with a disclaimer (§7), repeating the caution in §13. Founder Q75 **locked True CMYK in v1**: premium print PDF must be vector/300-DPI with ICC-profile-aware CMYK output, including a designed color-management pipeline (working spaces, conversions, profile handling, verification). BRIEF codifies the override. The task is therefore not *whether* but *how to contain the scope* so the locked requirement ships without dragging in a desktop-class color suite.
- **Decision**: 
  1. **Working space**: documents store colors as extended-sRGB components (plus optional named swatch); UI picking/display uses P3-aware SwiftUI/UIKit colors. One working space everywhere — no per-document color-space option in v1.
  2. **Conversion point**: exactly one — print-PDF export. Source sRGB values convert to CMYK through an ICC profile loaded via `CGColorSpace(iccData:)`, relative colorimetric intent as performed by Core Graphics conversion[^41]. No CMYK values are authored, stored, or displayed anywhere else in the app.
  3. **Profile**: the bundled CMYK profile is founder decision **FD-03**. Candidates are eciRGB/ISO-Coated-v2-class press profiles, whose redistribution licensing is a known research gap (BRIEF) — never assumed, `VERIFY-AT-SUBMISSION`/founder verification task. Documented fallback: Apple's built-in Generic CMYK profile, explicitly recorded as lower print fidelity.
  4. **PDF output**: vector paths + text (per D-118 embedding rules) drawn into a CMYK-color-space PDF context; the ICC profile is embedded as PDF OutputIntent so the press knows the rendering intent.
  5. **Scope containment (what True CMYK does NOT mean in v1)**: no on-screen soft-proofing (documented limitation in PRD §13 and export UI copy); no PDF/X-1a *certification* claim — the output is "CMYK PDF with embedded OutputIntent," and any "PDF/X" marketing wording is banned unless verified compliant (`VERIFY-AT-SUBMISSION`); no spot colors, no per-object color spaces, no CMYK pickers; verification is via external tooling (desktop Acrobat/Ghostscript channel inspection) as a TEST_MATRIX manual gate, not an in-app feature.
- **Alternatives considered**: (a) **Defer CMYK entirely (market study's recommendation §7)** — rejected solely because founder Q75 locks it; recorded so future readers know the engineering-risk assessment disagreed and why the override stands. (b) **DeviceCMYK without ICC profile** (`CGColorSpaceCreateDeviceCMYK` naively) — rejected: "device CMYK" is press-dependent and uncalibrated; output would vary per RIP with no OutputIntent — fails Q75's "ICC-profile-aware" wording and produces the exact color-shift complaints the study warns about[^42]. (c) **Full color-managed pipeline with soft-proofing and gamut warnings** — rejected as v1 scope: this is the desktop-suite feature set whose cost motivated the study's deferral advice[^40]; the containment list above is precisely the line between "honest CMYK output" and "color suite." (d) **CMYK working space throughout the app** — rejected: UIKit/SwiftUI rendering is RGB; a CMYK working space would make every on-screen color a lie without soft-proofing, doubling complexity for negative user value. (e) **Rasterize-then-convert (export RGB raster, convert to CMYK bitmap)** — rejected: forfeits vector print PDF (locked requirement) and 300-DPI-independent scaling.
- **Consequences**: Positive — the locked requirement ships with a single, auditable conversion point; the profile question is isolated into FD-03 with a working fallback, so no phase blocks on licensing. Negative — colors on screen (sRGB/P3) will not match press output exactly and v1 offers no in-app way to preview that (mandatory honest disclosure in export UI: "قد تختلف الألوان المطبوعة عن ألوان الشاشة" — printed colors may differ from screen); out-of-gamut sRGB colors clip per relative-colorimetric conversion with no warning UI in v1 (documented limitation); external-tool verification adds a manual gate to every export-affecting change. Obligations: FD-03 tracking; CMYK channel-inspection checklist in TEST_MATRIX; ban on PDF/X claims pending verification; the disclaimer string ships in the export flow.
- **Confidence**: medium — the API mechanism is verified feasible[^40][^41], but print-fidelity quality across real presses is unproven until FD-03 resolves and physical print verification happens; confidence in the *containment boundary* itself is high.
- **Dependencies**: D-111 (color storage), D-118 (export matrix), FD-03; overrides market study §7 recommendation by founder authority (Q75).
- **Validation trigger**: Print-PDF export QA phase (P10): external channel inspection confirms 4-channel CMYK + embedded OutputIntent; FD-03 resolution; physical print proof reviewed by founder before any marketing claim about print accuracy.
- Amended by D-226.

## D-118 — Export matrix: one snapshot render path; free JPEG/rasterized-PDF ≤2 MP; premium PNG/transparent-PNG/SVG/vector-CMYK-PDF; no silent flattening
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF locks the tier matrix (free: JPEG + rasterized PDF, 2 MP cap; premium: opaque PNG, transparent PNG, SVG, high-res print PDF) and Q73: premium SVG must preserve fully editable text/vector objects wherever feasible, with outlined paths only as explicitly documented per-feature fallbacks — never silent flattening. The study's export feasibility matrix (§7) confirms each format's iOS-native path: `UIGraphicsImageRenderer`/JPEG, alpha-preserving `CGBitmapContext` PNG, custom SVG serializer (no first-party writer exists), vector PDF, and per-license font embedding in PDF (OFL fonts explicitly permit embedding; commercial fonts must be checked)[^41]. Study §7 recommended outline-everything-in-SVG as the simple path; Q73 overrides toward editability.
- **Decision**: All exports render from an immutable scene snapshot through MKRender's drawing code — never screen capture. Free tier: JPEG and rasterized PDF, both ≤2 MP effective pixels. Premium: opaque PNG, transparent PNG (alpha preserved through the whole pipeline), SVG, vector print PDF (300-DPI floor for rasterized assets, CMYK per D-117). Large rasters render in tiled strips (D-210). PDF: vector paths + live-text runs; live text set in OFL fonts embeds as subsetted text (license-permitted[^28][^26]); non-OFL or embedding-restricted fonts fall back to outlines via a per-license switch in the font's catalog metadata. SVG: custom serializer; Live Text becomes `<text>` (with `@font-face` embedding only where the license allows); arranged/transformed glyphs become `<g><path>` with `data-mk-*` provenance attributes (source text, codepoints, font name) preserving editability intent; every outline fallback is enumerated per-feature in PRD §13 — silent flattening is a defect class.
- **Alternatives considered**: (a) Outline all text in SVG/PDF always (study §7's simpler suggestion) — rejected: Q73 explicitly demands editable text where feasible; outlining stays as the documented fallback, exactly scoped. (b) Third-party SVG library — rejected: D-204; the needed subset (paths, text, groups, images, gradients-later) is small. (c) Screen-capture-based export — rejected: resolution-capped, degradation-ladder-contaminated (D-116), and not color-manageable. (d) WebP/HEIC additions — out of scope; not in the locked matrix; seam only.
- **Consequences**: Positive — canvas/export parity by shared code path; license-driven embedding switch turns a legal constraint into catalog metadata; provenance attributes make Makhtoot SVGs round-trippable in future versions. Negative — custom SVG serializer needs its own fixture suite (external renderer comparison in TEST_MATRIX); the per-license switch depends on WS-09 metadata correctness (wrong metadata = license violation — obligation: embedding right defaults to *outline* unless explicitly verified). 2 MP gating math (effective pixels, aspect-preserving) must be identical across free formats.
- **Confidence**: high — every format's mechanism is study-verified[^41]; the honesty rules (no silent flattening) are locked founder requirements.
- **Dependencies**: D-102, D-111, D-114, D-117, D-119, D-120 (license metadata), D-210.
- **Validation trigger**: P10 exit: export fixture grid (every format × text/arranged/path-text/marks content × free/premium) passes visual + structural checks; Arabic sharpness verified at print resolution per BRIEF; SVG opens correctly in two external renderers.
- Amended by D-227.

## D-119 — Gating: entitlement checks at export + premium-content marking; expired premium locks fonts/photo-backgrounds with replace-or-subscribe flow
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF free-tier gating: resolution, formats, premium elements, locked fonts, photo backgrounds (photo import premium-only; free = solid colors, Q34). Q27 locks post-expiry behavior: projects stay viewable/editable; premium + imported fonts lock; export falls back to free restrictions until re-subscribe or locked content replaced. Q41: free tier must always be able to create with free fonts/solid backgrounds and export JPEG/PDF at 2 MP. Paywall-compliance evidence: no dark patterns, content before paywall, visible dismissal[^50][^51][^45].
- **Decision**: Gating is enforced at two choke points, both querying `MKEntitlementResolver` (D-113): (1) content acquisition (premium font selection, photo-background import, premium asset insertion) — blocked for free users at the point of use with an inline upgrade affordance, never a surprise later; (2) export — the exporter walks the snapshot and computes a `premiumContentPresent` set (premium fonts used, photo backgrounds, premium assets). A free/expired user exporting such a project gets a blocking sheet listing exactly which objects are premium, with two paths: replace (jump-to-object flow, swap to free equivalents) or subscribe. Expired-premium display: locked fonts render from last cached shaping with a lock badge; re-shaping (editing that text) is blocked until unlock or font replacement; photo backgrounds render with lock badge. Nothing is ever deleted or hidden — degraded gracefully, per Q27.
- **Alternatives considered**: (a) Hard-lock projects containing premium content after expiry — rejected: Q27 mandates viewable/editable. (b) Silent downgrade on export (strip premium content automatically) — rejected: destroys work silently; the explicit replace flow keeps the user in control. (c) Gating at project open (upfront nag) — rejected: paywall-pressure pattern the compliance evidence warns against[^51]; gating at the moment of premium value is both kinder and safer.
- **Consequences**: Positive — free tier remains genuinely useful (Q41 honored); the premium-content walk gives exact, honest messaging; review-risk posture matches documented 3.1.2 expectations[^50]. Negative — cached-shaping display for locked fonts requires persisting shaped geometry with the document (already true via D-106 for arranged; Live Text in locked fonts needs a cached render — obligation on MKPersistence); replace-flow UX is nontrivial (WS-08/WS-13 shared task).
- **Confidence**: high — behavior is founder-locked; enforcement-point design follows directly from the single-resolver architecture.
- **Dependencies**: D-113, D-118, D-120, D-121, D-122.
- **Validation trigger**: P11 exit: gating matrix tests (each premium content type × each entitlement state × view/edit/export) pass; expiry simulation shows locks + successful replace-then-export path.
- Amended by D-229.

## D-120 — Bundled starter fonts: OFL-verified-only list; every font ships with captured license + verification record; KFGQPC prohibited
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF mandates curated bundled open-license starter fonts with a concrete acquisition/verification process, and forbids inventing licenses. Market study §5 verifies: Amiri — OFL 1.1, bundling/embedding/redistribution explicitly permitted with attribution + license text[^28][^29][^30]; Noto Naskh Arabic and the broader Noto Arabic family — OFL 1.1[^25][^26][^27][^33]; KFGQPC Uthmanic Script HAFS — proprietary freeware, non-commercial, prohibited from any paid app without written permission[^31][^32]; Alif Type repositories are candidates requiring per-repo license verification[^37]; aggregator font sites are non-authoritative for licensing[^35]. SF Arabic is a system font usable via OS APIs but not redistributable as a file[^21][^34][^22]. Study §5 also notes the OFL-verified set does not yet cover Ruq'ah/Thuluth/Diwani/Maghrebi at production quality.
- **Decision**: The bundled set is OFL-verified-only. Candidate list (each individually subject to the WS-09 verification protocol before inclusion — candidacy is not inclusion): Amiri, Amiri Quran, Noto Naskh Arabic, Noto Kufi Arabic, Noto Sans Arabic, Scheherazade New, Lateef, Harmattan, Reem Kufi, Aref Ruqaa, Mada, Tajawal, Almarai, El Messiri, Markazi Text, Rakkas, Katibeh, Jomhuria, Mirza, Qahiri. WS-09 protocol per font: fetch from the authoritative upstream (foundry repo, not aggregators[^35]); capture the license file verbatim into the repo beside the font; record source URL, commit/version, reserved-font-name obligations; verify Arabic coverage incl. required mark ranges; run the D-103/D-105/D-107 fixture suite. No font ships without its captured license + verification record. KFGQPC/Uthmani-EULA fonts are prohibited absolutely[^31][^32]. Attribution and license texts surface at Settings → Support → Licensing (Q66). Category coverage gaps (true Thuluth/Diwani/Maghrebi) are acknowledged: covered only to the extent OFL fonts exist, with commercial licensing deferred to FD-07.
- **Alternatives considered**: (a) Bundle from aggregator "free font" sites — rejected: study explicitly warns these are non-authoritative[^35]; license risk. (b) Ship KFGQPC for Qur'anic-style category — prohibited: non-commercial EULA[^31][^32], and D-209 removes the Qur'anic-content driver anyway. (c) Smaller safe set (Amiri + Noto only, the study's §5 floor recommendation) — rejected as the *ceiling*: the catalog requires stylistic breadth (BRIEF categories list); the larger candidate list is accepted with per-font verification as the safety mechanism. (d) License commercial foundry fonts for v1 — deferred to FD-07: study found zero verified mobile-embedding commercial licenses (§5)[^35], and BRIEF locks v1 premium to OFL-verified only.
- **Consequences**: Positive — legal posture is auditable per font; App Review substantiation exists in-repo; the prohibition list prevents the single worst legal/reputational risk the study identified[^31]. Negative — some BRIEF catalog categories (Thuluth, Diwani, Maghrebi) will be thin or approximated by OFL near-styles in v1 — honest catalog labeling required (obligation on WS-09 metadata); verification workload is 20 fonts × protocol (budgeted in PLAN P9).
- **Confidence**: high for the process and the verified anchors (Amiri/Noto)[^25]–[^30]; medium for how many of the 20 candidates survive verification — the protocol exists precisely to decide that.
- **Dependencies**: D-103 fixtures, D-118 (embedding rights metadata), D-122, FD-07.
- **Validation trigger**: P9 exit: every shipped font has license file + verification record + passing fixture suite; Licensing screen lists all attributions; zero fonts from non-authoritative sources.
- Amended by D-222.

## D-121 — Premium catalog delivery: static JSON manifest + font files over HTTPS after entitlement confirmation; bundle-in-app as documented fallback
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF locks a downloadable premium catalog with verified redistribution rights, download after entitlement confirmation, "verify App Store policy, fallback = bundle in app." Fonts are content consumed by the app, not executable code — the policy-relevant distinction (expanded in D-206). No backend exists; hosting location is founder decision FD-04.
- **Decision**: The premium catalog is a static JSON manifest (catalog version, font entries: id, family, styles, tags, category, preview assets, file URL, SHA-256, size, license metadata incl. embedding rights) plus font files, hosted on founder-controlled static HTTPS storage (FD-04). MKFonts downloads only after `MKEntitlementResolver` confirms premium; verifies checksum; stores content-addressed in the app container; registers per-process (D-122). Catalog refresh is a simple manifest re-fetch — no server logic. Documented fallback, kept genuinely ready: if hosting is not ready at submission or policy review objects (`VERIFY-AT-SUBMISSION`), premium fonts ship inside the app bundle behind the same entitlement gate — the catalog UI is identical either way because the source is abstracted behind `FontSourceProviding`.
- **Alternatives considered**: (a) On-Demand Resources — rejected (full analysis in D-206: version-coupled to app releases, App Store size/slot constraints, weaker control over gating and retries). (b) CloudKit public database as font CDN — rejected: asset-size and quota ergonomics worse than static HTTPS for multi-MB binaries; no benefit over a static host. (c) Bundle-everything from the start — kept as the fallback rather than the plan: bloats initial download for free users who may never subscribe, and couples catalog growth to app updates.
- **Consequences**: Positive — zero server logic; catalog updates without app releases; checksum + HTTPS gives integrity; the fallback removes schedule risk from FD-04. Negative — entitlement check is client-side (consistent with D-113's accepted posture); founder must stand up static hosting (FD-04) or elect fallback; offline users cannot fetch new premium fonts (already-downloaded fonts work offline — BRIEF's network-use whitelist includes premium font downloads).
- **Confidence**: high — mechanism is minimal and the fallback is complete; policy question is flagged, not assumed.
- **Dependencies**: D-113, D-120 (license metadata schema), D-122, FD-04, D-206.
- **Validation trigger**: P9 exit: download→verify→register→catalog-entry flow passes incl. checksum-failure and resume cases; VERIFY-AT-SUBMISSION policy recheck; FD-04 resolution or fallback election.

## D-122 — Font registration & user import: per-process CTFontManager registration; strict sfnt validation; content-addressed container storage; premium-only import that locks on expiry
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF: user font import via Files picker is premium-only (Q64); formats .ttf/.otf/.ttc/variable; reject unsafe/unsupported with clear errors; imported fonts lock after premium expiry (Q27). The study notes app-bundled/resource fonts load via `CTFontManagerRegisterFontsForURL` in-app registration rather than the system-wide `Fonts` capability[^61].
- **Decision**: All non-system fonts (bundled, premium-downloaded, user-imported) register per-process via `CTFontManagerRegisterFontsForURL(..., .process, ...)` at launch (bundled/downloaded) or on import. User import (premium-gated at the picker entry point): Files picker → sfnt structural validation (magic numbers, required tables — `cmap`, `glyf`/`CFF `, `GSUB` presence checks; accept ttf/otf/ttc/variable; reject woff/woff2/bitmap-only/corrupt) with specific Arabic-language error messages per rejection reason → SHA-256 content-addressed copy into the app container → register → catalog entry flagged `userImported`. On expiry, `userImported` and premium fonts lock per D-119 (cached display, no re-shape, lock badge). Imported files never leave the container (no upload — BRIEF privacy).
- **Alternatives considered**: (a) System-wide font installation via the Fonts capability/profile flow — rejected: heavier UX, unnecessary — fonts are needed only inside Makhtoot[^61]. (b) Accept-anything permissive import — rejected: BRIEF requires clear rejection of unsafe/unsupported; malformed sfnt data crashing Core Text mid-edit is a data-loss vector. (c) Free-tier import — rejected: Q64 locks premium-only. (d) Storing imports by user-visible filename — rejected: collisions and duplicates; content addressing dedupes and stabilizes references from documents.
- **Consequences**: Positive — process-scoped registration keeps the system clean and needs no entitlement; validation protects editor stability; content addressing lets documents reference fonts robustly. Negative — validation is intentionally conservative and may reject exotic-but-valid fonts (error copy invites re-export as ttf/otf); documents referencing an imported font opened on a device without it need the missing-font flow (render arranged content from captured outlines per D-106; Live Text falls back with a warning — specified in PRD §12).
- **Confidence**: high — standard APIs, clear requirements; validation depth is tunable.
- **Dependencies**: D-103, D-113, D-119, D-120, D-121.
- **Validation trigger**: P9 exit: import test set (valid ttf/otf/ttc/variable + corrupt/woff/bitmap rejects) passes with correct Arabic error strings; expiry-lock and missing-font flows verified.
- Amended by D-227.

## D-123 — Trial: app-side 7-day trial from first launch, Keychain + iCloud KVS persistence, earliest-timestamp-wins, clock-rollback guard; no ASC introductory offer in v1
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Founder Q37 locks the trial as starting at FIRST APP LAUNCH, applying to monthly + annual, with persistence such that reinstall cannot trivially reset it, and requires documenting app-side-trial vs Apple-introductory-offer differences. Study §8 documents the Apple-native alternative: introductory offers with `paymentMode = .freeTrial`, per-subscription-group eligibility via `isEligibleForIntroOffer`[^43][^44]. The two mechanisms differ fundamentally: an intro offer starts at *subscription signup* (requires payment-sheet commitment), not first launch, and Apple tracks eligibility per Apple-ID; Q37's launch-anchored universal trial cannot be expressed as an intro offer.
- **Decision**: The 7-day premium trial is app-side, granted to every user at first launch (state machine `active(daysLeft)` → `expired`, resolved into D-113 precedence below billingRetry). Persistence: trial-start timestamp in the Keychain (`kSecAttrAccessibleAfterFirstUnlock`, historically surviving app deletion — behavior noted `VERIFY-AT-SUBMISSION` at implementation) mirrored to iCloud key-value store; the earliest timestamp seen across sources/devices wins; a clock-rollback guard (monotonic anchor comparison) freezes remaining days rather than extending when device time moves backward. No App Store Connect introductory offer is configured in v1 — avoiding double-trial stacking and eligibility divergence (full trade study and App Review presentation duties in D-205). Honesty limits of this persistence are recorded in D-211.
- **Alternatives considered**: (a) ASC introductory offer instead — rejected: cannot start at first launch (Q37); detailed in D-205. (b) Both mechanisms — rejected: a user could consume the app-side trial then the intro offer (14 days unintended), and paywall copy juggling two trial states is a 3.1.2 clarity risk[^50]. (c) UserDefaults-only persistence — rejected: reinstall trivially resets, violating Q37. (d) Server-anchored trial — rejected: no backend exists (BRIEF).
- **Consequences**: Positive — trial UX matches founder intent exactly (value before any payment sheet); no eligibility API complexity. Negative — forgoes the App Store product-page "free trial" badge that intro offers get (D-205 records this); persistence is best-effort against determined resets (D-211); trial state must be honestly presented to App Review as app-functionality gating, not an Apple offer (D-205 obligation).
- **Confidence**: high — the founder requirement uniquely determines the mechanism; risks are bounded and separately recorded.
- **Dependencies**: D-112 (consent/trial records in metadata store), D-113, D-205, D-211.
- **Validation trigger**: P11 exit: reinstall test (delete → reinstall → trial not reset), two-device KVS convergence test (earliest wins), clock-rollback test (no extension); VERIFY-AT-SUBMISSION for Keychain-survival behavior on current iOS.
- Amended by D-224, D-228.

## D-124 — Referral program: architected, compiled, flag-OFF; referrer-only reward; no activation without guideline recheck
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Founder Q78 locks: architect the referral flow but isolate behind a local, server-independent feature flag, default OFF; do not activate without reconfirmation against current App Review guidelines. Study §8 documents the risk base: an actual Apple rejection stated rewarding the *invitation sender* is acceptable but the *receiver* must not be rewarded for downloading/registering, since incentivized downloads influence charts/reviews[^53]; related threads flag IAP-circumvention concerns under 3.1.1[^54]; the restriction is inferred from precedent, not a single quoted rule, so current guideline text must be validated before shipping[^55][^53][^54]. Market study §8's compliant variant: reward the referrer only, on a qualifying action.
- **Decision**: `MKStore/Referral` is fully designed and compiled but inert unless `MKFeatureFlags.referralProgram` is true (compile-time default false, no remote toggle — the flag is local and server-independent per Q78). Design: referrer-only reward of +7 trial days per qualifying event, hard cap of 4 extensions (abuse bound); local code generation + manual code entry for attribution (no server in v1 — the honor-code weakness is recorded in D-212); invitee receives nothing (the documented rejection trigger[^53]). A review-risk memo ships in APP_STORE_CHECKLIST; removal path = delete the Referral folder + flag reference. Activation requires FD-05: founder sign-off after a fresh guideline recheck (`VERIFY-AT-SUBMISSION` by definition).
- **Alternatives considered**: (a) Ship active with referrer-only design — rejected: Q78 explicitly says default OFF pending reconfirmation; precedent shows even conditioned variants got flagged[^53][^54]. (b) Invitee-reward variants — rejected: the exact documented rejection pattern[^53]. (c) Don't architect it at all — rejected: Q78 asks for the architecture; building the seam now is cheap, retrofitting attribution later is not. (d) Server-based attribution — rejected: no backend; also increases 3.1.1 circumvention surface[^54].
- **Consequences**: Positive — v1 review surface contains no referral behavior (flag off = dead code paths, no UI); future activation is a flag+copy exercise, not a build-out. Negative — dead code must not leak strings/UI into the binary review could misread (obligation: referral UI strings compiled out with the flag); honor-code attribution is weak (D-212) — accepted for a trial-days-only reward.
- **Confidence**: high — "OFF and documented" is the one posture consistent with both the founder lock and the rejection evidence.
- **Dependencies**: D-113, D-123, FD-05, D-212.
- **Validation trigger**: FD-05 event: fresh App Review Guidelines 3.1.1/3.2.2 recheck at any proposed activation; v1 submission gate: verify no referral UI/strings reachable in the shipped binary.
- Amended by D-225.

## D-125 — Analytics: opt-in-only, on-device aggregated font-usage counters, anonymous batched upload to CloudKit public DB, kill switch
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF locks the only permitted analytics: anonymous, aggregated, OPT-IN font-usage data (Q43, Q79); never text, projects, identifiers, font files, or user content; consent, aggregation, and data minimization must be specified. Study §9 notes first-party, non-tracking aggregate analytics avoids ATT/tracking-consent complexity entirely and suits the privacy posture[^56][^57]; no third-party SDK is permissible anyway (D-204).
- **Decision**: Default OFF. An explicit switch in Settings enables it; the consent record (version, date) persists in the metadata store (D-112). On-device: counters keyed by fontID accumulate into weekly buckets with counts bucketed into coarse bands (exact counts never leave the device). Upload: anonymous batches to the CloudKit **public** database — a random ephemeral batch UUID per upload, no user-record linkage, no timestamps finer than ISO week, no device/OS/locale fields. A local kill switch (and honoring the Settings toggle immediately) stops collection and deletes pending batches. Full alternatives analysis in D-207.
- **Alternatives considered**: (a) No analytics at all — genuinely considered (study §9 calls App Store Connect analytics possibly sufficient[^56]); rejected because font-usage signal directly drives catalog investment (FD-07) and Q43/Q79 explicitly authorize this single dataset. (b) Custom HTTPS endpoint — rejected: stands up server infrastructure for one counter stream and creates an identifier-shaped access log (D-207). (c) Third-party SDK — prohibited (D-204; tracking/ATT surface[^56]).
- **Consequences**: Positive — App Privacy label stays minimal ("data not linked to you," `VERIFY-AT-SUBMISSION` for exact label taxonomy at submission); the public-DB write path needs no account and no server. Negative — public database means Makhtoot cannot authenticate writers (spam is possible; acceptable for advisory-only data — recorded in D-207); aggregation coarseness limits analytical depth by design. Obligation: privacy-policy text describing exactly this collection; consent versioning.
- **Confidence**: high — the scope is founder-locked to one dataset; the mechanism is the minimal one that ships it.
- **Dependencies**: D-112, D-204, D-207.
- **Validation trigger**: P13 exit: network audit proves zero telemetry bytes leave the device with consent off, and uploaded batch contents match the minimization spec field-for-field; VERIFY-AT-SUBMISSION privacy-label review.

## D-126 — Design system: token-based MKTheme, RTL-first components, Arabic-only strings; baseline aesthetic "حبر ورق" (editable, FD-02)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF: no visual identity exists; a separate design process will produce one; architecture must provide a themeable Arabic-first design-system layer with swappable tokens; baseline aesthetic is subject to founder approval and edits (FD-02). UI is Arabic-only RTL.
- **Decision**: `MKDesignSystem` defines a `MKTheme` protocol: semantic color tokens, an Arabic type ramp (UI font: system SF Arabic — usable via OS APIs without redistribution issues[^21][^34]; display/preview fonts from the catalog), 4-pt spacing grid, radii, elevation, motion-duration tokens. All components (panels, inspector fields, sliders, chips, list rows) are RTL-first: leading/trailing semantics only, mirrored-asset audit, numerals per locale convention. Every UI string lives in the `ar` catalog only (D-200). The default theme implements the baseline aesthetic "حبر ورق" (Ink & Paper) — selection rationale in D-213 — and is FD-02-editable: a re-theme is a token-set swap, no component changes.
- **Alternatives considered**: (a) Hardcoded styling now, design system later — rejected: BRIEF explicitly requires the themeable layer *because* identity work comes later; retrofitting tokens is expensive. (b) Full multi-theme user-facing theming in v1 — rejected: scope; one protocol + one theme keeps the seam without the feature. (c) LTR-built components with `.environment(\.layoutDirection, .rightToLeft)` flips — rejected: flip-based RTL is exactly the class of bugs the WWDC Arabic-design guidance warns about[^24]; components are designed RTL-native.
- **Consequences**: Positive — the future design process lands as a token payload (FD-02); RTL correctness is structural, not patched. Negative — token discipline must be enforced from P1 (obligation: no literal colors/spacing in feature code — lint note in WS-01); SF Arabic type-ramp metrics need real-device review with the design run.
- **Confidence**: high — this is the standard mechanism for the stated constraint; the aesthetic itself is deliberately low-stakes (editable, D-213/FD-02).
- **Dependencies**: D-100, D-200, D-213, FD-02.
- **Validation trigger**: P1 exit: shell + components render RTL-correct from tokens on iPhone/iPad; FD-02: founder approves/edits the baseline after the design run.

---

# Part II — Founder decisions (FD-01…FD-07) — the only open blockers

## FD-01 — Real bundle identifier, team, repository name/organization
- **Status**: founder-pending
- **Date**: 2026-07-17
- **Owner**: Founder
- **Context**: BRIEF marks `com.example.makhtoot` as an explicit placeholder; the repository does not exist (founder will `git init` and name it). Bundle ID cascades into the document UTI (`com.example.makhtoot.project`), IAP product ids, CloudKit container id, and Keychain access groups — all placeholder-derived in FOUNDATION §0.
- **Decision**: PENDING — founder supplies: production bundle id, Apple Developer team, repository name/org. Run-1 recommendation: choose a domain the founder controls (reverse-DNS), decide before P0 scaffold if possible; otherwise the codebase carries a single `MKIdentifiers` constants file so the swap is one-file + project-settings, and CloudKit container/IAP ids are created only after the real id exists (they are not renameable in App Store Connect).
- **Alternatives considered**: Proceeding to StoreKit/CloudKit configuration on placeholder ids — rejected: ASC product ids and CloudKit containers are permanent; creating them on placeholders would strand them.
- **Consequences**: Until resolved: P0–P10 proceed on placeholders (safe — nothing external is registered); P11 (StoreKit config), P12 (CloudKit container), and P15 (distribution) block on the real values. Obligation: `MKIdentifiers` is the only place identifiers appear.
- **Confidence**: high that the isolation strategy makes this non-urgent before P11.
- **Dependencies**: D-101, D-112 (UTI), D-113 (product ids), D-124 (container id).
- **Validation trigger**: Distribution phase gate: real ids present, placeholder grep returns zero hits in shipped configuration.

## FD-02 — Baseline aesthetic "حبر ورق" approval/edit after the design run
- **Status**: founder-pending
- **Date**: 2026-07-17
- **Owner**: Founder
- **Context**: BRIEF: no visual identity exists; a separate design process will produce one; the Run-1 baseline is subject to founder approval and edits (FD-02). D-213 records why "حبر ورق" was selected as the placeholder-quality baseline; D-126 makes any re-theme a token swap.
- **Decision**: PENDING — founder approves, edits, or replaces the "حبر ورق" token set once the design process delivers. Run-1 recommendation: keep "حبر ورق" as the working theme through P1–P14 so screenshots/UX review happen against a coherent aesthetic, and treat the design run's output as a token payload applied late (P14/P15 window) with a visual regression pass.
- **Alternatives considered**: Blocking UI work on identity — rejected: the token architecture (D-126) exists precisely so build and brand decouple.
- **Consequences**: Visual polish phase depends on this; nothing earlier does. A late re-theme risks minor spacing/contrast rework — bounded by token discipline.
- **Confidence**: high — decision is reversible by design.
- **Dependencies**: D-126, D-213.
- **Validation trigger**: Visual polish phase: founder sign-off recorded; token payload applied; RTL visual regression pass green.

## FD-03 — CMYK ICC profile selection + redistribution-license verification (or Apple Generic CMYK fallback)

**FOUNDER-RESOLVED 2026-07-19**

- **Status**: resolved 2026-07-19 (founder) — Option A elected
- **Date**: 2026-07-17 (opened); resolved 2026-07-19
- **Owner**: Founder
- **Context**: D-117's pipeline needs a bundled CMYK ICC profile for conversion and PDF OutputIntent. BRIEF lists ICC profile redistribution licensing (ECI/ICC-class profiles) as a known research gap — founder decision + verification task; nothing is assumed here. The study documents that color accuracy is the pain point that makes profile choice matter[^40][^42].
- **Decision**: RESOLVED — Option A: v1 ships with Apple's built-in Generic CMYK profile, D-117's documented fallback; a licensed press-class ICC profile is deferred to a v1.1 drop-in through the existing `ICCProfileStore` seam (`Sources/MKColor/ICCProfileStore.swift`; `loadBundled()` already prefers a valid CMYK-model bundled file, else Apple Generic CMYK — no architecture change needed to land a real profile later). Supporting facts from WS-08 P10-COMPLETION's ground-truth verification (`docs/impl-log/WS-08.md`), gathered while building the littleCMS (`transicc`) verification corpus: (1) Apple Generic CMYK has zero rendering-intent differentiation — perceptual/relative-colorimetric/saturation (`A2B0`/`A2B1`/`A2B2`) all point at the byte-identical tag-table offset (1928) and size (21523 bytes), one shared LUT reused via ICC indirection, confirmed independently via CoreGraphics and littleCMS; (2) v1 CMYK PDFs are whole-page raster embeds at print resolution, not per-element vector — per-element vector CMYK was found unreachable within the WS-08 packet's fence (Spike C: CoreGraphics does not auto-convert an sRGB `CGColor` into a PDF context's CMYK space; achieving it requires the drawers themselves to construct CMYK `CGColor`s, a `MKRender` change outside WS-08's fence) and is recorded as a post-v1 follow-up. These facts make Option A's fidelity ceiling well-understood, not merely "good enough by default": no intent-based accuracy story exists to advertise, and content is raster not vector at the CMYK stage.
- **Alternatives considered**: Bundling a press profile on assumed "freely distributable" status — prohibited by the no-invented-licenses rule. Blocking v1 ship on ECI/ISO-Coated-class license verification — rejected by founder as unnecessary given D-117's containment already makes the profile swappable data.
- **Consequences**: Positive — v1 ships unblocked; the `ICCProfileStore` seam makes a later licensed-profile drop-in mechanical, no re-architecture. Negative — v1 press fidelity is Apple Generic CMYK's, with no intent differentiation and raster (not vector) CMYK content; marketing/App Store copy must not overstate fidelity (see APP_STORE_CHECKLIST.md FD-03 items). Obligation: license evidence capture (D-120 pattern) applies only once a licensed profile actually lands in v1.1.
- **Confidence**: high — the fallback fully unblocks v1 and is now empirically characterized, not assumed.
- **Dependencies**: D-117, D-118.
- **Validation trigger**: Satisfied for v1 by this resolution. v1.1 drop-in: profile license evidence captured, OutputIntent embeds the elected profile, physical print proof approved.

## FD-04 — Premium font hosting location (static HTTPS) or bundle-fallback election
- **Status**: founder-pending
- **Date**: 2026-07-17
- **Owner**: Founder
- **Context**: D-121 needs founder-controlled static HTTPS storage for the premium catalog manifest + font files, or an explicit election of the bundle-in-app fallback. BRIEF requires the fallback be genuinely ready either way.
- **Decision**: PENDING — founder either provisions static hosting (any static HTTPS host suffices; no server logic is required by D-121's design) or elects the bundle fallback for launch. Run-1 recommendation: elect the bundle fallback for v1 submission if hosting is not trivially available by P9, because v1's premium catalog is OFL-verified-only (D-120) and small enough to bundle; move to hosted delivery when the catalog grows (FD-07 era).
- **Alternatives considered**: Third-party font CDN/service accounts — out of scope for a founder decision record; any static host meets the requirement.
- **Consequences**: Font catalog phase (P9) needs the election; the `FontSourceProviding` abstraction (D-121) makes the choice reversible post-launch. Bundle fallback increases app download size (bounded: OFL set only).
- **Confidence**: high — both paths are fully specified; this is a logistics election.
- **Dependencies**: D-121, D-120.
- **Validation trigger**: P9 gate: elected path exercised end-to-end (hosted download or bundled unlock) in TestFlight build.

## FD-05 — Referral activation (requires fresh guideline recheck) — default stays OFF
- **Status**: founder-pending
- **Date**: 2026-07-17
- **Owner**: Founder
- **Context**: D-124 ships the referral module compiled but inert. Study §8's evidence is rejection precedent, not quoted rule text — invitee rewards were explicitly rejected; referrer-only rewards were called acceptable in the same account; 3.1.1 circumvention concerns apply[^53][^54][^55]. Q78: never activate without reconfirmation against then-current guidelines.
- **Decision**: PENDING (and non-blocking for v1 — the flag defaults OFF forever until this decision). To activate, founder must: (1) commission a fresh read of App Review Guidelines 3.1.1/3.2.2 current text (`VERIFY-AT-SUBMISSION`-class task); (2) accept the D-212 attribution weaknesses or fund a server; (3) approve the referrer-only mechanics and copy. Run-1 recommendation: do not activate in v1.x; revisit only if organic growth stalls, and prefer the qualifying-event definition "invitee converts to paid" (the study's safest variant[^53]).
- **Alternatives considered**: Recorded in D-124.
- **Consequences**: None for v1 (never blocks). Activation without this record's steps would contradict Q78 and the documented rejection evidence.
- **Confidence**: high — inaction is the safe default by construction.
- **Dependencies**: D-124, D-212, D-123.
- **Validation trigger**: Any activation proposal: this record's three steps completed and recorded before the flag flips.

## FD-06 — Family Sharing ON/OFF for lifetime + subscriptions (irreversible per product)
- **Status**: founder-pending
- **Date**: 2026-07-17
- **Owner**: Founder
- **Context**: Study §8: only auto-renewable subscriptions and non-consumables are Family-Sharing-eligible; once turned ON for a product it cannot be turned off — only replaced by deleting and recreating the product[^46][^47][^48][^49]. The $90 lifetime non-consumable is the economically sensitive case (one purchase could serve up to six family members consuming the premium catalog indefinitely — the study's LTV caution in §10 applies[^17]).
- **Decision**: PENDING — founder decides per product before first App Store Connect product creation. Run-1 recommendation: Family Sharing OFF for the $90 lifetime (LTV exposure, irreversibility means OFF→ON remains possible later but ON→OFF does not[^46]); OFF for subscriptions initially for the same optionality reason. Because the setting is per-product and irreversible, deciding *late* (at ASC setup, P11/P15 window) is safe; deciding wrongly is not.
- **Alternatives considered**: ON for goodwill/differentiation — legitimate, but forfeits pricing optionality permanently; deferring products' creation until decided is the risk-free ordering.
- **Consequences**: Blocks App Store Connect product configuration (not code — StoreKit handles shared entitlements transparently either way). Obligation: APP_STORE_CHECKLIST carries this as a hard pre-creation checkpoint.
- **Confidence**: high in the recommendation's reversibility logic (OFF preserves the ON option; ON destroys the OFF option)[^46].
- **Dependencies**: D-113, FD-01.
- **Validation trigger**: ASC product-creation step: decision recorded in the checklist before any product is created; VERIFY-AT-SUBMISSION recheck of current Family Sharing toggle semantics.

## FD-07 — Commercial foundry licensing budget/process (v1.1+; v1 = OFL only)
- **Status**: founder-pending
- **Date**: 2026-07-17
- **Owner**: Founder
- **Context**: Study §5: no commercial (non-OFL) Ruq'ah/Thuluth/Diwani/Kufi/Maghrebi foundry license was verified as mobile-app-embeddable in the research pass; desktop/web licenses must never be assumed to cover iOS bundling[^35]; §13 makes catalog expansion an explicit founder budget/process decision. BRIEF locks v1 premium to OFL-verified fonts only and reserves data-model hooks for future foundry licensing (mechanism 4 of the four font mechanisms).
- **Decision**: PENDING — post-v1: founder approves a licensing budget, target foundries/styles (true Thuluth/Diwani/Maghrebi are the coverage gaps per D-120), and a per-license verification process (explicit mobile-app embedding clause, capture evidence in-repo per the D-120 pattern; PDF/SVG embedding rights recorded per D-118's switch). Run-1 recommendation: let D-125 font-usage analytics (opt-in data) inform which styles justify licensing spend before committing budget.
- **Alternatives considered**: Commissioning original fonts — a valid alternative path within this same decision; recorded for founder consideration, no recommendation either way (cost/quality data absent).
- **Consequences**: Never blocks v1. The catalog schema (D-120/D-121 license-metadata fields incl. embedding rights) is already shaped to receive commercial entries — that was the point of deciding the schema now.
- **Confidence**: high that v1 is unaffected; the decision is purely forward-looking.
- **Dependencies**: D-118, D-120, D-121, D-125.
- **Validation trigger**: v1.1 planning: first commercial font enters the catalog only with captured license evidence including an explicit mobile-embedding clause.

---

# Part III — Derived Run-1 sub-decisions (D-200+)

## D-200 — Localization: single `ar` String Catalog as source of truth; no Latin-fallback catalog in v1
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF locks Arabic-only RTL UI at launch. Xcode localization tooling assumes a development language; shipping a half-hearted English catalog invites drift and doubles string review. Yet future localization must not require re-plumbing.
- **Decision**: The development region and only localization is `ar`. One String Catalog (`Localizable.xcstrings`) with Arabic as the source language; every user-facing string goes through it from day one (no hardcoded literals — same discipline as D-126 tokens). String keys are stable English-ish identifiers (`export.premiumRequired.title`) so future locales attach to keys, not Arabic source text. Docs follow the BRIEF convention: Arabic string + Latin gloss on first use. App Store metadata: Arabic primary; territory strategy per BRIEF (Q46) is a submission-checklist matter, not a code matter.
- **Alternatives considered**: (a) English development language with `ar` translation — rejected: makes Arabic the derived artifact in an Arabic-only product; every review cycle would proofread translations of strings nobody ships. (b) Hardcoded Arabic literals (skip the catalog) — rejected: forfeits future-localization seam and pluralization/format tooling (Arabic's six plural categories need the catalog's plural rules). (c) Dual ar+en at launch — rejected: BRIEF locks Arabic-only; English UI is scope, QA, and review surface with zero locked value.
- **Consequences**: Positive — one reviewed string surface; plural rules handled by the catalog; localization later is additive. Negative — non-Arabic-reading contributors/agents need the key-naming discipline to navigate strings (mitigated by descriptive keys); Xcode UI defaults expecting English development language need one-time project-setting care.
- **Confidence**: high — direct transcription of a locked requirement into tooling reality.
- **Dependencies**: D-100, D-126.
- **Validation trigger**: P1 exit: literal-string lint pass finds zero user-facing strings outside the catalog; pseudo-locale round-trip proves keys (not Arabic text) are the attachment points.

## D-201 — Text input: UITextView overlay chosen over custom UITextInput implementation (expansion of D-104)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: D-104 fixes the overlay pattern; this record preserves the full trade study for why Makhtoot does not implement its own text-input conformance, since that question will recur whenever the overlay's seams show. Typing must be indistinguishable from a native field (BRIEF): Arabic keyboard, tashkeel entry via long-press/popovers, autocorrect, dictation, hardware keyboards, marked text, selection handles, magnifier — all owned by the system when a real UITextView is first responder.
- **Decision**: Never implement `UITextInput` on the canvas in v1. The editing overlay is a real UITextView (TextKit 2) hosting all input; the engine renders committed state. The overlay contract: (1) created on edit-begin, positioned over the object's frame in canvas space at current zoom; (2) fonts/attributes built by the same shared attribute factory the engine uses (single source for metrics); (3) rotated objects normalize to axis-aligned during editing and restore after; (4) commit on resign/tap-outside pushes the string+style into shaping capture (D-103). Live per-keystroke mirroring to the engine render is explicitly *not* attempted — the overlay IS the visual during editing.
- **Alternatives considered**: (a) Custom `UITextInput` conformance on the canvas view — rejected: marked text (Japanese/Arabic transliteration IMEs), dictation insertion, selection-gesture arbitration, and accessibility of the input path are each multi-week correctness projects; Apple's own apps use hosted text views for exactly this reason; every iOS release becomes a re-test liability. (b) `UITextField`-style invisible input proxy (hidden field capturing keystrokes, engine renders live) — rejected: marked-text composition and selection UI break visibly; keystroke-level mirror rendering would still need per-edit reshaping with the overlay problem unsolved. (c) SwiftUI `TextField`/`TextEditor` overlay — rejected: less metric/attribute control than UITextView, no TextKit 2 object access for matching layout, harder first-responder orchestration inside a UIKit canvas.
- **Consequences**: Positive — system-perfect input forever, including future iOS input features, for free. Negative — the editing visual is TextKit 2's layout while the committed visual is the engine's Core Text capture; tiny metric deltas at commit are possible and must stay below a perceptibility threshold (shared attribute factory + fixture comparisons); in-place editing of *rotated* text is compromised (normalize-during-edit), a documented UX tradeoff in PRD §5.
- **Confidence**: high — the rejected paths have well-known failure modes; the accepted path's weaknesses are cosmetic and bounded.
- **Dependencies**: D-103, D-104.
- **Validation trigger**: P4: commit-parity fixtures (overlay screenshot vs engine render) within tolerance across bundled fonts and sizes; marked-text/dictation manual checklist passes (Q59 Arabic verification gate).

## D-202 — Joining-form realization: ZWJ synthetic context chosen over presentation-form codepoints (expansion of D-107)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: D-107 fixes the ZWJ technique. This record preserves why the tempting alternative — Unicode Arabic presentation forms (U+FB50–FDFF, U+FE70–FEFF), which encode isolated/initial/medial/final variants as codepoints — is banned. The requirement: after an explicit join break, offer the user any of the four contextual forms, rendered exactly as the *current font* would render them (BRIEF).
- **Decision**: Realize forms only via ZWJ synthetic-context shaping through the normal Core Text pipeline in the target font (`ZWJ+ح+ZWJ` → medial, etc.), harvesting glyph id + outline from the shaped result. Presentation-form codepoints are banned project-wide for rendering, form realization, storage, and export text content; stored text is always canonical Arabic codepoints + a `JoiningForm` enum where a form was chosen.
- **Alternatives considered**: (a) **Presentation-form codepoints** — rejected on four grounds. *Coverage*: modern OpenType Arabic fonts shape via GSUB from base codepoints and are not required to populate presentation-form cmap entries; several D-120 candidates would produce .notdef or fallback-font glyphs — the form would silently render in the wrong font. *Fidelity*: even when mapped, presentation-form glyphs can bypass the font's contextual GSUB/GPOS refinements (kerning, mark anchors tuned for shaped sequences). *Data hygiene*: presentation forms in stored text corrupt search, revert-to-text (D-106 requires byte-identical backup), and any future text export — they are compatibility characters Unicode itself discourages for interchange. *Consistency*: D-103 already bans them; one technique everywhere. (b) **Executing GSUB `isol/init/medi/fina` features directly via feature settings on a single letter** — rejected: Core Text exposes font *features*, but forcing positional features out of context is font-dependent and undocumented behavior; the ZWJ route uses the shaper's contract as designed. (c) **Caching a form atlas per font at install** — premature optimization; the synthetic reshape is microseconds and cache invalidation would track font versions for no measured gain.
- **Consequences**: Positive — forms are exactly what the font's shaper produces, per font, with zero table parsing; stored text stays canonical. Negative — dependence on correct ZWJ handling per font: a font whose shaping ignores ZWJ joining context would fail form selection, so the WS-09 verification protocol includes a four-form fixture per joining-capable letter (obligation, shared with D-107); ZWJ artifacts must be stripped from harvest results (zero-width, but defensively filtered).
- **Confidence**: high — ZWJ join-causing semantics are core Unicode Arabic behavior honored by the system shaper; fixtures close the per-font tail risk.
- **Dependencies**: D-103, D-107.
- **Validation trigger**: P6: T-FORM-* fixtures — for every bundled font and joining letter, each of the four requested forms yields a glyph from the same font matching the naturally-shaped equivalent context.

## D-203 — Document model: value-type scene graph + snapshot rendering chosen over reference-type object model (expansion of D-111)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: D-111 fixes the value-type tree. This record preserves the trade study against the conventional editor pattern — mutable class-based node graphs with observation — because it will be questioned by anyone arriving from UIKit/AppKit editor traditions. Forces: unbounded undo (BRIEF), race-free concurrent export/autosave (D-102), Codable persistence with explicit migration (D-112), Swift 6 Sendable checking (D-100).
- **Decision**: The scene is `struct`/`enum` values throughout: `MKScene` → `[MKNode]` (enum with associated value payloads). Mutation happens only on the main actor through path-addressed mutation helpers producing new values; CoW keeps copies cheap. Undo = store the inverse operation (or prior sub-value) per command; snapshot for render/export/autosave = copy the value (O(1) until mutation). Identity is by stored `UUID`, not object identity. CALayer objects (D-114) are *derived presentation state* keyed by node id — never the model.
- **Alternatives considered**: (a) **Class-based node graph with Observation/Combine** — rejected: undo requires memento or command journaling bolted onto mutable state; sharing nodes with a background exporter is a data race by construction (requiring deep-copy anyway — at which point values won); `Sendable` conformance would be `@unchecked`; persistence needs a parallel Codable DTO layer, duplicating the model. (b) **Classes + NSUndoManager per-property registration** — rejected: 5,000-node bulk transforms register avalanche undo entries; coalescing gesture streams fights the framework; inverse-command values are simpler and testable. (c) **CRDT-style persistent data structures** — rejected: solves collaborative merge, which v1 does not have (sync is whole-project LWW, D-208); cost without a requirement.
- **Consequences**: Positive — undo, snapshots, Codable, and Sendable all come from one representation choice; model tests are pure-value tests. Negative — path-addressed mutation is less ergonomic than direct object mutation (one utility layer in MKModel absorbs this); accidental full-tree copies in hot loops are a performance foot-gun (profiling obligation, D-115); identity-by-UUID means all cross-references (selection, layers panel, sync records) go through id lookup tables maintained alongside the tree.
- **Confidence**: high — the four forces independently point at values; the pattern is proven in modern document editors.
- **Dependencies**: D-100, D-102, D-111, D-112.
- **Validation trigger**: P2: property-based round-trip and undo-inverse tests green at 5,000 nodes within D-115 budgets; P14: no full-tree-copy hot spots in Instruments.

## D-204 — Zero third-party dependencies in v1
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Founder Q49 locks tooling (Xcode/xcodebuild/gh, no external CI); BRIEF's privacy posture forbids third-party analytics; the study's §14 instruction relies exclusively on first-party frameworks (Core Text, Core Graphics, StoreKit 2, CloudKit)[^61]. Every capability in the requirements maps to a first-party API verified feasible in the study (§4, §7, §8). Agent-driven Run 3 amplifies dependency risk: agents upgrading/patching third-party code create untracked liability.
- **Decision**: MakhtootKit and the app target depend on Apple SDKs only. No SPM remote dependencies, no vendored source imports. The single tempting case — an SVG writer (study §7 mentions a "lightweight open-source SVG-writer" as an option[^41]) — is instead a small custom serializer (D-118), justified because the needed SVG subset is bounded and the provenance-attribute scheme is Makhtoot-specific anyway. Any future exception requires a superseding decision record naming the dependency, license, maintenance posture, and why first-party fails.
- **Alternatives considered**: (a) Permit vetted utility deps (SnapshotTesting, GRDB, swift-collections) — rejected: each is convenience, not capability; v1 test gates are fixture/manual-checklist based (Q59) and D-112 rejected GRDB on its merits. (b) Vendoring (copy source in-repo) — rejected: same audit burden with worse update hygiene; it is a dependency with extra steps.
- **Consequences**: Positive — zero supply-chain/licensing surface beyond fonts and the ICC profile (both already license-tracked); reproducible builds from a bare Xcode install; App Privacy label unpolluted by SDK data collection. Negative — Makhtoot writes and owns an SVG serializer and any future niche utilities (accepted, scoped); some test ergonomics are hand-rolled.
- **Confidence**: high — the requirements were checked capability-by-capability against first-party APIs before this was locked.
- **Dependencies**: D-101; load-bearing for D-112, D-118, D-125.
- **Validation trigger**: Every phase gate: `Package.swift` shows zero remote dependencies; any proposal to add one triggers a superseding ADR, not a quiet edit.

## D-205 — No App Store Connect introductory offer in v1; app-side trial only, with explicit App Review presentation duties (expansion of D-123)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Study §8 documents the Apple-native trial: ASC introductory offer, `paymentMode = .freeTrial`, eligibility via `isEligibleForIntroOffer`, per subscription group per Apple-ID[^43][^44]. Founder Q37 locks a different animal: trial starts at first app *launch* for everyone, before any purchase intent. Running both would stack (app-side 7 days, then a free-trial intro offer at subscribe time = 14 days) and make paywall price disclosure ambiguous — a 3.1.2 clarity risk given reviewers reject confusing trial presentation[^50][^51].
- **Decision**: v1 configures **no introductory offer** on either subscription in App Store Connect. The only trial is the D-123 app-side trial. App Review presentation duties (carried in APP_STORE_CHECKLIST): (1) paywall copy never calls the app-side trial an "App Store free trial" — it is presented as app functionality: "الفترة التجريبية" with exact end date; (2) price disclosure adjacent to the CTA states the real subscription terms with **no** "free trial then…" phrasing sourced from ASC (since none exists): "٣ دولارات شهريًا، يتجدد تلقائيًا" with storefront-localized price via StoreKit display price; (3) App Review notes explain the app-side trial mechanism proactively so the reviewer doesn't hunt for a missing intro offer; (4) the documented difference table (app-side vs intro offer: start trigger, eligibility authority, storefront badge, receipt visibility) lives in ARCHITECTURE §StoreKit per Q37's documentation requirement.
- **Alternatives considered**: (a) Intro offer only (drop app-side) — rejected: violates Q37's first-launch lock; also gates the trial behind the payment sheet, the opposite of the founder's onboarding intent. (b) Both, with app-side trial marking intro-offer ineligibility — impossible: intro-offer eligibility is Apple-controlled per Apple-ID; the app cannot burn it[^43]. (c) Both, accepting stacking — rejected: 14-day accidental trials, incoherent paywall disclosure, review risk[^50].
- **Consequences**: Positive — one trial state machine, one disclosure story, zero eligibility-API complexity. Negative — the App Store product page shows no "free trial" badge (that badge comes only from ASC offers), a real marketing cost, accepted and recorded; if a future founder wants the badge, the migration is: add intro offer, gate it on app-side-trial-never-started, superseding ADR required.
- **Confidence**: high — Q37's lock plus the stacking hazard leaves no coherent alternative.
- **Dependencies**: D-113, D-123.
- **Validation trigger**: VERIFY-AT-SUBMISSION: paywall copy review against current 3.1.2 text; ASC configuration audit confirms zero intro offers before submission.

## D-206 — Premium font delivery: fonts-are-data HTTPS download, not On-Demand Resources (expansion of D-121)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: D-121 fixes HTTPS delivery. This record preserves the ODR trade study. Premise: font files are content data consumed by the renderer, not executable code — downloading content after purchase is the standard pattern the App Store permits for media apps; the policy footing should still be rechecked at submission (`VERIFY-AT-SUBMISSION` — the BRIEF itself demands "verify App Store policy, fallback = bundle in app," and no market-study citation covers ODR policy specifics).
- **Decision**: Premium fonts arrive via direct HTTPS from founder-controlled static hosting (FD-04) after entitlement confirmation, checksum-verified, content-addressed locally. On-Demand Resources is rejected for v1.
- **Alternatives considered**: **On-Demand Resources** — rejected on four grounds. *Version coupling*: ODR asset packs are built into and versioned with each app release; adding a font means an app submission, defeating the catalog's update-independence. *Entitlement gating*: ODR has no purchase-awareness; gating would be app-side anyway, so ODR adds no control — it only relocates hosting to Apple with less flexibility. *Size/slot constraints*: ODR imposes per-pack and total size limits and eviction behavior (the OS may purge packs, forcing re-download logic anyway — so the "OS manages storage" benefit reverses into an availability liability for a tool whose fonts must work offline once downloaded, per BRIEF's offline lock). *Fallback asymmetry*: the mandated fallback (bundle-in-app) shares the FontSourceProviding abstraction with HTTPS trivially; an ODR path would be a third, structurally different source for no gain. **CloudKit assets as delivery** — rejected in D-121 (quota/ergonomics). **Hosted-by-Apple via IAP-hosted content** — rejected: designed for non-consumable content downloads keyed to a purchase, but premium here is a *subscription* whose catalog changes; the mechanism fits poorly and adds ASC packaging steps per font.
- **Consequences**: Positive — catalog updates decouple from releases; offline guarantee holds (downloaded fonts are permanent container files, never OS-evicted); one abstraction covers hosted and bundled sources. Negative — founder must host (or elect fallback, FD-04); Makhtoot owns download resumption/retry (URLSession background transfer — bounded, standard code).
- **Confidence**: high — ODR's coupling and eviction properties conflict directly with locked offline and update-independence requirements.
- **Dependencies**: D-121, D-113, FD-04.
- **Validation trigger**: P9: airplane-mode test — previously downloaded premium fonts fully functional offline; VERIFY-AT-SUBMISSION policy recheck alongside D-121's.

## D-207 — Analytics transport: CloudKit public database chosen over custom endpoint and over no-upload (expansion of D-125)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: D-125 fixes the consent/minimization design. The transport question had three real options given the constraints: no backend exists, no third-party SDK is allowed (D-204), and the only permitted dataset is aggregated font-usage counters (Q43/Q79). Study §9 supports first-party, non-tracking analytics to stay outside ATT territory[^56][^57].
- **Decision**: Upload anonymized weekly batches as records in the CloudKit **public** database of the app's container. Writes use the anonymous CloudKit user context; each batch carries only: random batch UUID, ISO-week string, array of (fontID, bucketed-count-band). No queries back; the founder reads aggregates via CloudKit Dashboard/exports. Kill switch: a `analyticsEnabled` flag record in the public DB read at upload time (server-independent app behavior otherwise; absence = proceed, explicit false = halt) — giving remote stop without any server.
- **Alternatives considered**: (a) **No upload at all** (on-device stats only, or rely on App Store Connect analytics[^56]) — seriously considered; rejected because ASC analytics cannot see font usage, and the entire purpose Q43/Q79 authorizes — steering catalog/licensing investment (FD-07) — requires the font-usage signal off-device. Kept as the trivial fallback: shipping with upload disabled is a one-flag change. (b) **Custom HTTPS endpoint** — rejected: stands up and maintains server infrastructure for one write-only stream; server access logs inherently capture IP+timestamp, creating exactly the identifier-adjacent data the privacy posture excludes; TLS/cert/rotation liability for a solo founder. (c) **CloudKit private DB + founder aggregation job** — rejected: private-DB data lives in each *user's* iCloud, unreachable to the founder by design. (d) Third-party analytics — prohibited (D-204)[^56].
- **Consequences**: Positive — zero servers; Apple infrastructure; no IP-log custody (Apple's edge, not the founder's); anonymous by construction — the public DB record carries no user linkage. Negative — public database is writable by anyone with the container id: spam/poisoning is possible and *accepted* because the data is advisory-only (catalog steering), never business-critical or billing-related — recorded as a known limitation with bucketing/outlier-trimming at read time as the mitigation; CloudKit public-DB quota scales with app's active users (monitored; batches are tiny). Obligation: the privacy policy names CloudKit as processor; the consent screen describes exactly the uploaded fields.
- **Confidence**: medium — mechanism is sound and minimal, but public-DB write abuse and quota behavior at scale are unmeasured; the no-upload fallback bounds the downside completely.
- **Dependencies**: D-125, D-204, D-112 (counter storage), FD-07 (consumer of the data).
- **Validation trigger**: P13: uploaded record schema audit matches the minimization spec; kill-switch record halts uploads in a live test; quota telemetry reviewed at first 10k-user milestone.

## D-208 — Sync conflict policy: last-writer-wins per project + conflict copy "(نسخة متعارضة)" (expansion of D-112 sync)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Premium sync (D-112) is whole-project records via CKSyncEngine. Concurrent edits of the same project on two offline devices *will* happen. v1 has no operational-transform/CRDT machinery (rejected in D-203), and a scene graph of arranged glyph nodes has no meaningful automatic field-level merge: two rearrangements of the same composition cannot be blended sensibly.
- **Decision**: Per-project last-writer-wins on the server record (CKSyncEngine's record-level resolution, using modification metadata), with a safety valve: when the losing device next syncs and detects its local version was overwritten while holding unpushed changes, it preserves its local version as a new project named "<الاسم> (نسخة متعارضة)" (conflicted copy) beside the synced winner. Nothing is ever discarded silently; the user reconciles manually. Conflict copies do not re-sync-loop (they are new project identities).
- **Alternatives considered**: (a) Field/node-level merge — rejected: no semantically safe merge exists for freeform arranged geometry; a "merged" design that neither device ever displayed is worse than either version. (b) Pure LWW without conflict copy — rejected: silent loss of a device's work violates the no-loss ethos that runs through BRIEF's autosave/recovery requirements. (c) Manual conflict-resolution UI (diff/choose per conflict) — rejected for v1: heavy UI for a rare event; the conflict-copy pattern (iCloud Drive precedent) achieves safety with zero new UI beyond a rename. (d) Lock-based editing (project checked out to one device) — rejected: offline-first means locks can't be acquired/released reliably.
- **Consequences**: Positive — deterministic, explainable, loss-free; trivially testable. Negative — users can accumulate conflict copies (acceptable; they created them by concurrent editing and the name says why — copy in PRD §17 explains); whole-project granularity means even disjoint edits conflict (accepted at v1 scale — projects are personal documents, not shared). Obligation: TEST_MATRIX two-device conflict scenario; the naming string is localized and collision-suffixed.
- **Confidence**: high — the pattern is the established document-sync baseline and matches the no-merge reality of the data.
- **Dependencies**: D-112, D-203, D-113 (premium gating of sync).
- **Validation trigger**: P12 exit: two-simulator offline-edit-then-sync trial produces winner + conflict copy with both versions intact, 20/20 runs.

## D-209 — No Qur'anic content of any kind in v1 — founder override of market-study §6 recommendation, recorded divergence
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: **This record explicitly documents a divergence.** Market study §6 verified that Qur'anic *text* is available under permissive terms (Tanzil: CC-BY-3.0, unaltered + attributed; Al Quran Cloud terms similar with faithfulness requirements)[^38][^39] and recommended shipping a "Qur'an-style quote" feature in OFL fonts, deferring only the Uthmani *font* (KFGQPC — non-commercial EULA, prohibited[^31][^32]). Founder Q67–68 **overrode this**: no preloaded Qur'anic content of any kind — no verse data, translations, Uthmani text, special assets, warnings, or locks; user-entered text only, all text treated identically; future sacred-text assets require explicit founder approval plus licensing/accuracy review. BRIEF codifies the override. The founder's prerogative here is also a risk judgment: bundled sacred text carries accuracy/orthography obligations (the study's own faithfulness conditions[^39]) and reputational stakes with a sharia-literate audience that a v1 need not take on.
- **Decision**: v1 ships zero Qur'anic content: no verse database, no Qur'an browser/insert feature, no "Qur'an mode," no special handling, warnings, or locks on any user-typed text (all text is treated identically — this is itself a requirement: Makhtoot does not detect or police sacred text). What *remains* (and must not be confused with content): full Qur'anic-range **mark support** (U+06D6–06ED annotation marks, D-105) because users may type such marks (founder Q11: full marks), and "Qur'anic-style" as a font *category tag* in the catalog (D-120) describing typographic register, not content. The Tanzil-based feature from study §6 is OUT; any future revival is a founder-approval + licensing/accuracy-review event, and the KFGQPC font prohibition (D-120) stands regardless[^31].
- **Alternatives considered**: (a) Ship the study's §6 Tanzil quote feature — rejected by founder lock (Q67–68); recorded so the evidence trail shows the feature was evaluated and vetoed, not overlooked. (b) Ship content with warnings/locks as a middle path — rejected: Q68 explicitly excludes special warnings/locks; the founder chose neutrality over curation. (c) Block users from typing Qur'anic text (avoid the topic entirely) — rejected: "all text treated identically" cuts both ways; policing input is out.
- **Consequences**: Positive — zero sacred-text accuracy/licensing obligations in v1[^38][^39]; the app is religiously neutral infrastructure; removes the KFGQPC temptation entirely. Negative — forfeits a feature the study judged high-value for the target audience (§3 ranked Qur'anic tooling "high" user value) — a deliberate market trade the founder owns; competitors (Ana Khattat's Qur'an browser[^4]) keep that differentiator. Obligation: marketing/App Store copy must not imply Qur'anic features; the catalog's "Qur'anic-style" tag copy is reviewed to mean style only.
- **Confidence**: high — the override is unambiguous, doubly locked (Q67–68 + BRIEF), and internally consistent once the content/marks distinction is drawn.
- **Dependencies**: D-105 (marks stay), D-120 (font prohibition + category tag), BRIEF override clause.
- **Validation trigger**: VERIFY-AT-SUBMISSION: App Store copy and screenshots audited for implied Qur'anic features; grep-level audit that no verse data/assets entered the bundle; any future sacred-content proposal triggers the founder-approval + licensing/accuracy process by reference to this record.

## D-210 — Unbounded export resolution via tiled strip rendering (expansion of D-116/D-118)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Founder Q76: no artificial export caps — premium hi-res means 4K+ and effectively unlimited scaling, bounded only by hardware memory protection with warnings + autosave. The study's §7 row for 4K/unlimited export recommends capping to device-safe dimensions to avoid OOM — Makhtoot instead must make size a disk problem, not a RAM problem, to honor Q76. A 12k×12k RGBA bitmap is ~576 MB; naive whole-canvas contexts die on exactly the devices BRIEF says must not artificially differ.
- **Decision**: Raster exports (JPEG/PNG, and rasterized-PDF page content) render in horizontal strips: allocate one bounded `CGBitmapContext` (strip height chosen so strip bytes stay within a budget derived from current `os_proc_available_memory`, e.g. ≤64 MB), translate the CTM per strip, replay the full scene draw (clipped to the strip), and stream each strip's pixels into an incremental encoder — `CGImageDestination` fed per-strip where the format supports it, with the PNG/JPEG row-streaming path implemented against ImageIO's incremental APIs; the assembled file only ever exists on disk. Vector PDF/SVG are unaffected (resolution-independent, D-118). The memory monitor (D-116) can shrink strip height mid-export; near-limit warnings + pre-export autosave satisfy Q76's protective clause. Effective ceiling becomes disk space + format dimension limits, documented rather than enforced by artificial caps.
- **Alternatives considered**: (a) Device-class dimension caps (study §7's suggestion) — rejected: Q76 explicitly forbids artificial caps; the founder chose warnings over ceilings. (b) Whole-canvas context with best-effort — rejected: OOM kills mid-export lose work and violate the no-loss ethos; jetsam is not a UX. (c) Scale-by-redraw into a smaller context then upscale — rejected: defeats the purpose (print sharpness; BRIEF requires visually verified sharp Arabic at print resolution). (d) Metal render-to-texture tiling — rejected with D-114's reasoning: CG strips reuse the one true drawing path; Metal adds a second rendering truth.
- **Consequences**: Positive — the same code path serves 2 MP free exports and poster-scale premium exports; memory stays flat regardless of output size; Q76 honored honestly. Negative — scene draw replays once per strip (cost linear in strips × draw complexity; bounded by the D-115 export budget which is measured at 4K and stress-checked far beyond); encoder incrementality varies by format — the PNG path needs care to avoid buffering full rows-set in memory (implementation risk flagged to WS-08 with a fixture at pathological sizes); shared-code invariant means strip clipping must not change antialiasing at seams (seam fixtures: strip-boundary pixels identical to whole-render reference at comparable sizes).
- **Confidence**: medium — the architecture is sound and standard for large-raster tools, but ImageIO incremental-encoding behavior at extreme dimensions is an implementation unknown until P10 fixtures run; the fallback (temp-file row spooling then single-pass encode from mapped memory) is designed and costs only disk.
- **Dependencies**: D-114 (shared drawing), D-116, D-118, D-115 (export budget).
- **Validation trigger**: P10: seam-fixture equality at strip boundaries; 12k×12k export completes on the lowest-RAM supported device with flat memory profile; mid-export memory-pressure drill shrinks strips without corrupting output.
- Amended by D-223 (struck claim: "monitor can shrink strip height mid-export" — replaced by static sizing + pause).

## D-211 — Trial persistence honesty limits: what a determined user can still do, and why that is acceptable (expansion of D-123)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Q37 requires that reinstall "cannot trivially reset" the app-side trial. Engineering honesty demands recording what the Keychain+KVS design does *not* prevent, so nobody later mistakes best-effort for tamper-proof — and so the accepted risk is a decision, not an accident. No server exists to anchor identity (BRIEF), which caps the achievable guarantee by construction.
- **Decision**: The persistence design (Keychain `kSecAttrAccessibleAfterFirstUnlock` + iCloud KVS mirror, earliest-timestamp-wins, monotonic rollback guard) defends against the *trivial* resets: app deletion + reinstall (Keychain has historically survived deletion — behavior is an OS implementation detail Apple has changed discussion of over the years, so it is `VERIFY-AT-SUBMISSION` at implementation, with KVS as the second anchor), device migration (KVS follows the iCloud account), clock rollback (monotonic guard freezes rather than extends). **Recorded residual holes**: (1) a user who erases the device (full wipe) and does not restore a backup clears the Keychain; (2) a user who signs out of iCloud (or disables KVS) and *also* wiped locally, or uses a device never signed in, presents no KVS anchor; (3) a different Apple ID + wiped device = a fresh user by every observable signal; (4) jailbroken keychain editing. Combined: a determined user can reset the trial by wiping a device or cycling Apple IDs. **Acceptance rationale**: each reset path costs the user far more friction than $3; the protected asset is a 7-day trial of a $3/mo tool, not a financial control; every stronger fix (server identity, DeviceCheck) either violates the no-backend constraint or adds Apple-service coupling disproportionate to the threat — DeviceCheck specifically is noted as the *one* proportionate future hardening (two bits per device survive erase; requires no owned server but does require App Attest/DeviceCheck integration) and is recorded as the designated extension seam if trial abuse ever measurably matters.
- **Alternatives considered**: (a) DeviceCheck bits in v1 — deferred: adds an Apple service dependency + failure modes at launch for abuse that is hypothetical; seam recorded instead. (b) Server-side identity — rejected: no backend (BRIEF). (c) Fingerprinting heuristics (device characteristics) — rejected: privacy posture (BRIEF) and App Review risk for no reliable gain.
- **Consequences**: Positive — the design meets Q37's actual bar ("not trivially") with zero infrastructure; the residual risk is quantified in friction terms and consciously accepted; the hardening path is pre-designed. Negative — trial-reset abuse is possible and unmeasurable in v1 (no analytics on entitlement state by design — D-125 permits only font counters); if lifetime/subscription conversion underperforms, trial abuse is one confounded hypothesis (accepted).
- **Confidence**: high — the threat model and acceptance are explicit; the only empirical uncertainty (Keychain reinstall survival on current iOS) is flagged for verification.
- **Dependencies**: D-123, D-113, D-125 (what cannot be measured).
- **Validation trigger**: P11: reinstall/rollback/two-device tests pass; VERIFY-AT-SUBMISSION Keychain-survival check; DeviceCheck seam decision reopens only on founder-observed abuse evidence.
- Extended by D-224/D-228.

## D-212 — Referral attribution without a server: honor-code exchange, enumerated weaknesses (expansion of D-124)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: D-124's referral module (flag OFF) needs an attribution design that works with zero backend, because Q78 demands the architecture exist while BRIEF forbids server infrastructure. Attribution is the heart of any referral system; without a server it is structurally weak — this record makes the weakness a documented property, not a discovered surprise, feeding the FD-05 activation decision.
- **Decision**: Attribution is an honor-code code exchange: the referrer's device generates a short human-readable code deterministically derived from a local random seed (no registry — collisions statistically negligible at plausible scale, format includes a checksum to catch typos); the referrer shares it out-of-band (share sheet). The invitee enters the code in Settings; the *invitee's* device records "referred-by" locally (no reward — D-124/[^53]); the qualifying event on the invitee side produces a confirmation code shown to the invitee, which the invitee relays back to the referrer, who enters it to claim +7 days (cap 4, D-124). The confirmation code is HMAC-derived from referrer code + event nonce so it cannot be fabricated without an invitee device that actually performed the event — *but* nothing verifies distinct humans.
- **Alternatives considered**: (a) CloudKit public DB as attribution rendezvous — genuinely tempting (matches D-207's transport) and rejected for this use: unlike advisory analytics, referral records confer *entitlement value* (trial days), and a publicly writable store backing rewards is an abuse design-flaw, not a limitation; it also creates cross-user record linkage adjacent to the privacy posture. (b) Server attribution — rejected: no backend; also the 3.1.1 surface grows[^54]. (c) Universal links/attribution SDKs — third-party dependency (D-204) and tracking-adjacent[^56]. (d) No attribution design at all until a server exists — rejected: Q78 asks for the architecture now; this is the honest zero-infrastructure version.
- **Consequences**: Positive — fully offline-capable, zero infrastructure, satisfies Q78's "architect but isolate" mandate; the HMAC step blocks pure fabrication. **Enumerated weaknesses (accepted, feeding FD-05)**: one human with two devices can self-refer (cap 4 bounds damage to 28 days of trial — bounded, non-monetary); codes can be traded publicly (same bound); no dedup of invitee identity; no revocation. The review-risk memo (D-124) carries these verbatim so FD-05 is decided with eyes open. Obligation: if FD-05 ever green-lights activation, the founder explicitly re-accepts these weaknesses or funds the server variant first.
- **Confidence**: medium — the design meets its constraints, but "honor-code referral" is inherently weak; confidence is high only that the weakness is correctly bounded (trial days, capped) and correctly documented.
- **Dependencies**: D-124, D-123 (trial-day grants), FD-05, D-204.
- **Validation trigger**: FD-05 activation review: weaknesses re-accepted in writing; until then, module unit tests only (flag-off build proves no reachable UI).

## D-213 — Design baseline "حبر ورق" (Ink & Paper): selection rationale (expansion of D-126)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF requires Run 1 to select an editable baseline aesthetic (FD-02 owns final approval) because no identity exists yet but P1 must build real UI. The selection criteria: must not fight the future identity (neutrality), must serve Arabic type as the hero content, and must differentiate from the competitive field's look — the study's competitor set skews skeuomorphic/ornamental (calligraphy apps trading on gold-on-black arabesque clichés[^1][^4]) or generically Western-SaaS (Canva/Express[^13][^16]).
- **Decision**: Baseline theme "حبر ورق" (Ink & Paper): modern Arabic editorial minimalism — warm paper neutrals (background ramp), ink-dark foregrounds, exactly one deep accent (madder-red family, a pigment with manuscript heritage), generous whitespace, calligraphy-forward previews (type specimens as the visual interest, chrome recedes). Rationale per criterion: *Hero content* — a typography tool's UI must lose every contrast battle with the user's artwork; near-neutral chrome guarantees it. *Neutrality for re-theme* — one accent + neutral ramps is the minimal token set; any future identity replaces one hue family and two ramps (D-126 token swap) without component redesign. *Differentiation* — deliberately anti-skeuomorphic against the ornament-heavy category[^1][^4], reading as a professional tool (closer to the Affinity/Procreate register[^17]) rather than a greeting-card generator — aligning with the product's per-glyph-professional positioning (study §1's structural gap). *Cultural register* — paper-and-ink references manuscript practice (مخطوط = manuscript) without pastiche.
- **Alternatives considered**: (a) Dark-studio theme (near-black, jewel accent) — rejected as *baseline*: paper-light canvases dominate real usage (social posts, print), and dark chrome around light canvases creates halation/contrast fatigue; dark mode remains a token-set variant later, not the baseline. (b) Ornamental/heritage theme (arabesque, gold) — rejected: converges on the category cliché the product must escape[^1][^4]; also fights hero content. (c) Pure grayscale utilitarian — rejected: indistinguishable brand surface for FD-02 to react to; one accent gives the founder a concrete editable proposal. 
- **Consequences**: Positive — safe-to-replace by construction; screenshots through P14 look like a coherent product; the rationale gives FD-02 something to accept or argue with rather than a blank page. Negative — warm neutrals are unforgiving about contrast tuning for small UI text (WCAG-level contrast is *not* a v1 gate per BRIEF's accessibility exclusion, but legibility review is in the Q59 manual checklist); madder red must be tuned to avoid error-state connotation in destructive-action contexts (token semantics separate `accent` from `destructive`).
- **Confidence**: medium — aesthetic judgments are cheap to hold and cheap to replace here; confidence is high in the *criteria*, medium in any particular palette surviving FD-02 contact.
- **Dependencies**: D-126, FD-02.
- **Validation trigger**: FD-02: founder approval/edit after the design run; interim: Q59 manual legibility review of P1 shell on-device.

## D-214 — Single-canvas v1 with a first-class multi-page seam (expansion of D-111)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF's canvas scope lists no multi-page requirement for v1, and v2 seams must be "clean extension seams only" (the same discipline as animation). But social content (carousels), print (booklets), and the v2 animation direction all eventually want multiple canvases per project; a v1 schema that hard-codes "one scene = one project" would force a document migration at the worst time.
- **Decision**: v1 exposes exactly one canvas per project in every UI surface (no page UI, no page-add affordance). The *schema* however stores `manifest.json → pages: [pageRef]` and `scene.json` as page 1's scene — an array that v1 always writes with one element and refuses (with a documented error, not a crash) to open with more. All v1 code paths that touch the scene resolve it through a `currentPage` accessor, never a `theScene` singleton assumption. Export, sync records (per-project, containing all pages), thumbnails (page 1), and undo (per-page stack) are specified against the array shape now. Cost measured: the seam is schema + accessor discipline, ~zero runtime weight.
- **Alternatives considered**: (a) Flat single-scene schema, migrate later — rejected: document migrations for files users keep for years are the highest-risk change class (the same reasoning that shaped D-112's schema stance); an additive seam now is nearly free. (b) Full multi-page UI in v1 — rejected: scope creep against a locked v1 canvas list; no requirement pays for the UI, navigation, and export-UX complexity. (c) Multi-canvas as separate projects in a folder — rejected as the future answer: breaks shared assets/styles and sync atomicity; recording it here prevents re-litigating.
- **Consequences**: Positive — v2 multi-page becomes UI work, not migration work; the refuse-to-open-multi-page guard means a v2 document degrades safely (clear error) on a v1 app rather than corrupting. Negative — a permanently single-element array is mild schema noise; the accessor discipline needs one lint/review rule (obligation on WS-02).
- **Confidence**: high — textbook seam: additive, testable, and its absence has a known concrete cost.
- **Dependencies**: D-111, D-112.
- **Validation trigger**: P2: schema fixtures include a synthetic two-page document that v1 rejects with the documented error; v2 planning: seam consumed without scene-schema migration.

---

# Index

| ID | Title | Status | Confidence |
|---|---|---|---|
| D-100 | Platform: universal, iOS 18, Swift 6, SwiftUI shell + UIKit canvas | accepted | high |
| D-101 | One app target + local SPM MakhtootKit; xcodebuild + gh only | accepted | high |
| D-102 | @MainActor document, Sendable engines, snapshot rendering | accepted | high |
| D-103 | Core Text is the only shaper; presentation forms banned | accepted | high |
| D-104 | UITextView (TextKit 2) overlay typing; engine renders committed state | accepted | high |
| D-105 | Bidirectional codepoint↔cluster↔glyph map; marks → Mark Nodes | accepted | medium |
| D-106 | Arrange derivation snapshot + Source Text Backup + confirmed revert | accepted | high |
| D-107 | Joining forms via ZWJ synthetic-context reshaping | accepted | high |
| D-108 | Ligature decomposition: fidelity-first placement, lossless recompose | accepted | medium |
| D-109 | Bidi: preserve run order, per-node bidiLevel + visual index | accepted | high |
| D-110 | Path text: arc-length LUT, RTL-aware pen, live-until-arranged | accepted | high |
| D-111 | Value-type scene graph, decomposed transforms, provenance children | accepted | high |
| D-112 | File-package docs + JSON scene + SwiftData metadata + CKSyncEngine | accepted | high |
| D-113 | Entitlement precedence + on-device StoreKit 2 verification | accepted | high |
| D-114 | Core Graphics + CALayer canvas; Metal as seam only | accepted | high |
| D-115 | Quantitative performance budgets as gates | accepted | medium |
| D-116 | Memory-pressure ladder + no-loss recovery | accepted | high |
| D-117 | True CMYK print PDF via ICC at export (founder override of §7) | accepted | medium |
| D-118 | Export matrix: one render path, license-aware embedding, no silent flattening | accepted | high |
| D-119 | Gating at acquisition + export; expiry locks with replace-or-subscribe | accepted | high |
| D-120 | OFL-verified-only bundled fonts; per-font evidence; KFGQPC prohibited | accepted | high |
| D-121 | Premium catalog: static HTTPS manifest + files; bundle fallback | accepted | high |
| D-122 | Per-process font registration; strict import validation; expiry lock | accepted | high |
| D-123 | App-side 7-day trial, Keychain+KVS, earliest-wins, rollback guard | accepted | high |
| D-124 | Referral architected, compiled, flag OFF; referrer-only design | accepted | high |
| D-125 | Opt-in font-usage analytics; aggregated; CloudKit public DB | accepted | high |
| D-126 | Token-based MKTheme, RTL-first components, ar-only strings | accepted | high |
| FD-01 | Real bundle id / team / repo | founder-pending | high (isolation) |
| FD-02 | Baseline aesthetic approval after design run | founder-pending | high |
| FD-03 | CMYK ICC profile + license verification (or Apple Generic CMYK) | resolved 2026-07-19 (founder) — Apple Generic elected for v1 | high (fallback) |
| FD-04 | Premium font hosting or bundle-fallback election | founder-pending | high |
| FD-05 | Referral activation (guideline recheck) — stays OFF | founder-pending | high |
| FD-06 | Family Sharing per product (irreversible) | founder-pending | high (recommendation) |
| FD-07 | Commercial foundry licensing budget/process (v1.1+) | founder-pending | high |
| D-200 | Arabic-only String Catalog strategy | accepted | high |
| D-201 | UITextView overlay vs custom UITextInput (trade study) | accepted | high |
| D-202 | ZWJ technique vs presentation-form codepoints (trade study) | accepted | high |
| D-203 | Value-type scene + snapshots vs reference-type model (trade study) | accepted | high |
| D-204 | Zero third-party dependencies | accepted | high |
| D-205 | No ASC introductory offer; app-side trial presentation duties | accepted | high |
| D-206 | Fonts-are-data HTTPS delivery vs On-Demand Resources | accepted | high |
| D-207 | Analytics transport: CloudKit public DB vs endpoint vs none | accepted | medium |
| D-208 | Sync conflicts: LWW per project + conflict copy | accepted | high |
| D-209 | No Qur'anic content — recorded override of study §6 | accepted | high |
| D-210 | Tiled strip rendering for unbounded export resolution | accepted | medium |
| D-211 | Trial persistence honesty limits + acceptance rationale | accepted | high |
| D-212 | Serverless referral attribution: honor-code exchange, weaknesses | accepted | medium |
| D-213 | "حبر ورق" baseline selection rationale | accepted | medium |
| D-214 | Single-canvas v1 with first-class multi-page seam | accepted | high |

---

# Traceability — BRIEF.md requirement bullets → decision records

| BRIEF section / bullet | Decision records |
|---|---|
| Product identity: name, placeholder bundle id, repo, themeable design layer | FD-01, D-126, D-213, FD-02 |
| Platform: universal iPhone+iPad, iOS 18, adaptive layouts | D-100 |
| v1 static-only; animation/video = v2 seams | D-100, D-111, D-214 |
| Arabic-only RTL UI | D-100, D-200, D-126 |
| Offline-first; network only for font downloads / sync / opt-in analytics | D-112, D-121, D-206, D-125, D-207 |
| Accessibility not a v1 requirement | D-213 (legibility note), TEST_MATRIX scope (no D-record needed — absence of scope) |
| No templates; shapes/ornaments/frames as placeable assets | D-111 (`shape` nodes), MKAssets module (D-101 map) |
| Native typing behavior (shaping, tashkeel, bidi, numerals) | D-103, D-104, D-105, D-109, D-201 |
| Arrange Mode: derived structure, reversible backup, no auto-reflow | D-106, D-111, D-203 |
| Both glyph-level and Unicode-level manipulation, lossless switching | D-105, D-106, D-109 |
| Joining preserved by default; explicit break + form selector | D-107, D-202 |
| Tashkeel + full Qur'anic-range marks: attached, individually manipulable | D-105, D-106, D-209 (marks vs content distinction) |
| Ligatures: combined + decomposable, fidelity default, opt-out (Q71) | D-108 |
| Per-object typographic/style controls | D-111 (style model), D-106 |
| Curved/circular/freeform Bézier path text (Q72) | D-110 |
| No preloaded Qur'anic content (Q67–68 override of study §6) | D-209, D-120 (KFGQPC prohibition) |
| Canvas: transform tools, guides, snapping, layers, undo/redo, zoom/pan | D-111, D-114, D-115, D-203 |
| Layers panel + numeric inspector | D-111 (decomposed transforms) |
| Autosave, duplicate, folders, search, export history | D-112 |
| Premium iCloud sync (CloudKit, not SIWA) | D-112, D-208, D-113 |
| Imports: raster/SVG/PDF assets; custom fonts premium-only (Q64) | D-112 (assets/), D-122 |
| Four font mechanisms; formats; catalog; licensing screen (Q66) | D-120, D-121, D-122, D-206, FD-04, FD-07, D-126 (app target Licensing screen) |
| Post-expiry lock behavior (Q27) | D-119, D-122 |
| Font acquisition/verification, never invent licenses; KFGQPC prohibited | D-120, FD-03 (same evidence discipline), D-204 |
| Export tiers: free JPEG/PDF 2 MP; premium PNG/transparent/SVG/print PDF | D-118, D-119 |
| Hi-res unlimited scaling, memory-protected (Q76) | D-210, D-116 |
| SVG editability, documented fallbacks only (Q73) | D-118 |
| True CMYK ICC print PDF (Q75 override of study §7) | D-117, FD-03 |
| Export presets + premium custom dimensions | D-118 |
| Free-tier gating incl. photo backgrounds premium (Q34) | D-119 |
| Sharp Arabic output verification at print resolution | D-118, D-115 (gates), TEST_MATRIX |
| No artificial performance caps; monitoring; degradation; recovery | D-115, D-116, D-210 |
| Pricing $3/$30/$90; storefront localization | D-113, D-205, market-study §10 evidence[^13][^16][^17] |
| 7-day launch-anchored trial (Q37); persistence; documented differences | D-123, D-205, D-211 |
| Post-trial free tier always functional (Q41) | D-119, D-123 |
| Lifetime = permanent premium | D-113 |
| Referral: architect, flag OFF, reconfirm guidelines (Q78) | D-124, D-212, FD-05 |
| Full StoreKit 2 incl. verification position | D-113, D-205 |
| No mandatory account; SIWA optional-future only (Q77) | D-112 (CloudKit path), D-113 (no backend) |
| Opt-in anonymous aggregated font analytics only (Q43, Q79) | D-125, D-207 |
| No ads | D-204 (no ad SDKs possible), D-125 (scope lock) |
| Territories (Q46) | APP_STORE_CHECKLIST (submission-time; no architecture decision) |
| SwiftUI-first + permitted lower-level frameworks (Q47) | D-100, D-103, D-114 |
| Tooling: Xcode/xcodebuild/gh only (Q49) | D-101, D-204 |
| Persistence recommendation and alternatives (Q50) | D-112, D-203, D-214 |
| Gates: build, profiling, StoreKit sandbox, manual Arabic checklist (Q59) | D-115, D-113, D-108/D-201 (checklist consumers) |
| Distribution automation with founder pauses (Q56, Q84) | D-101, FD-01, FD-06 |
| Codebase-memory ADR conventions (Q58) | This document's record format (all records) |
| Known research gaps: grace durations, per-font OFL, ICC licensing, referral guidelines, foundry licenses | D-113, D-120, FD-03, FD-05, FD-07 — each carries VERIFY-AT-SUBMISSION or a verification protocol |

---

# Amendments — Run-1 self-review reconciliation (added after cross-document review)

These records resolve tensions surfaced by the deliverable authors during Run-1 self-review.
FOUNDATION.md was amended in place for D-215/D-218-related wording (D-115, D-112).

## D-215 — Pattern backgrounds are premium-gated
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF lists pattern backgrounds as v1 placeable assets, while founder Q34 locks the free tier to solid-color backgrounds only. Neither BRIEF nor FOUNDATION stated pattern-background gating explicitly; WS-14 (T8) required a ruling.
- **Decision**: Pattern backgrounds (and all non-solid background fills) are premium content. Free tier backgrounds = solid colors only, exactly per Q34. Pattern assets remain browsable with lock badges for free users.
- **Alternatives considered**: Free pattern backgrounds (rejected — contradicts the spirit of Q34's "reserve all custom backgrounds for premium"); a small free pattern subset (rejected — complicates the gating matrix for negligible conversion value; founder may soften later, editable).
- **Consequences**: PRD §14 gating matrix row "backgrounds" covers solid/photo/pattern uniformly; MKAssets flags pattern assets `premium`.
- **Confidence**: high — direct extrapolation of a locked founder answer.
- **Dependencies**: D-119, Q34.
- **Validation trigger**: Founder review of the gating matrix before P11 exit; editable without architectural impact.

## D-216 — Price points map to nearest Apple tiers $2.99 / $29.99 / $89.99
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Locked prices "$3 / $30 / $90 USD" do not exist as exact Apple price points; App Store pricing uses Apple's tier list (APP_STORE_CHECKLIST §3).
- **Decision**: Select the nearest standard tiers: $2.99 monthly, $29.99 annual, $89.99 lifetime, with Apple automatic storefront localization. This is the standard interpretation of round-number founder pricing.
- **Alternatives considered**: Next tier up ($3.99 etc.) — rejected, contradicts "$3" intent; custom price points — Apple now permits fine-grained price points, so exact $3.00 may be selectable (VERIFY-AT-SUBMISSION in App Store Connect); if available, founder may prefer it — cosmetic either way.
- **Consequences**: All revenue modeling and App Store copy use $2.99/$29.99/$89.99 until FD-01-era ASC setup confirms available price points.
- **Confidence**: high for intent, medium for exact tier availability.
- **Dependencies**: D-113, APP_STORE_CHECKLIST §3.
- **Validation trigger**: ASC price-point selection during submission setup.

## D-217 — All raster-image import is premium-gated (not only backgrounds)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: PRD author flagged TN-1: Q34 gates photo *backgrounds*, but free users placing raster images as non-background elements was unspecified. Founder Q32 lists "images" among free-tier limits ("export res and format and layers and fonts and images").
- **Decision**: Raster image import (background or placed element) is premium. Free tier composes with text, shapes/ornaments (free-flagged), and solid backgrounds. SVG/PDF import is likewise premium (import is one gated capability, consistent UX).
- **Alternatives considered**: Free placed-images with premium backgrounds only (rejected — trivially circumvents Q34 by placing a full-canvas image); watermarking free image use (rejected — founder chose gating, not watermarks, Q32).
- **Consequences**: PRD R-11.7/G11 stands as written; "premium content present" project flag includes any imported asset.
- **Confidence**: high — Q32 names images as a free-tier gate.
- **Dependencies**: D-119, Q32, Q34.
- **Validation trigger**: Founder review of gating matrix; editable pre-P11.

## D-218 — Cold-launch budget <1 s added to D-115; memory numbers clarified (60 % target / 70 % first trigger)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: BRIEF requires loading budgets; D-115 lacked a cold-launch number (WS-13 derived one) and D-115's "<60 % before degradation" read as conflicting with D-116's 70 % stage-1 trigger (WS-07 flag).
- **Decision**: Cold launch to interactive project browser <1 s on A15-class is a D-115 gate. Memory: 60 % is the engineering design target for editor working set; the D-116 ladder is the enforcement mechanism and its first stage fires at 70 % used. FOUNDATION.md D-115 amended in place.
- **Alternatives considered**: Lowering stage 1 to 60 % (rejected — would shed caches during normal heavy editing, hurting the fast-and-smooth mandate Q52).
- **Consequences**: TEST_MATRIX gains a cold-launch PERF gate at P13/P14 (Run 2 should add T-PERF entry); WS-07 implements D-116 numbers unchanged.
- **Confidence**: high.
- **Dependencies**: D-115, D-116.
- **Validation trigger**: P14 profiling on the device matrix.

## D-219 — Use modern Core Text registration API spelling
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: FOUNDATION D-122 names `CTFontManagerRegisterFontsForURL`, the deprecated spelling; the current API is `CTFontManagerRegisterFontURLs(_:_:_:_:)` with process scope (ARCHITECTURE author flag).
- **Decision**: Implementation uses `CTFontManagerRegisterFontURLs` with `.process` scope; FOUNDATION's older spelling is to be read as this API. Semantics of D-122 unchanged.
- **Alternatives considered**: none material.
- **Consequences**: WS-09 tasks reference the modern API at implementation time.
- **Confidence**: high.
- **Dependencies**: D-122.
- **Validation trigger**: P9 build against the iOS 18 SDK (deprecation warnings = regression).

## Run-2 adversarial-review records

These records resolve findings from the Run-2 adversarial review sweep (orchestrator-approved dispositions, RUN2_DISPOSITIONS.md). D-220–D-229 each amend or extend a specific Run-1 foundation or derived decision, citing the R2-x-y finding ids that drove them. D-230–D-231 recover two ARCHITECTURE §2.1 decisions that ARCHITECTURE had locally numbered "D-200"/"D-201," colliding with this document's own already-assigned D-200/D-201 (Sweep B finding 1).

## D-220 — Mark-attachment geometry made normative (amends D-105/D-106)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 adversarial review (R2-2-1..8) found that D-105/D-106 left the geometry of mark attachment underspecified: the coordinate space of `relativeOffset`, the exact transform composition order for a following mark's world transform, the pivot for a mark's own rotation/scale, the re-attach recomputation formula, non-uniform base-scale behavior, and mark-stack paint ordering (which had been overloading `MKProvenance.visualIndex`) were all left implicit or ambiguous.
- **Decision**: `relativeOffset` lives in BASE-LOCAL space. The normative world transform of a following mark is `composition.affine ∘ base.affine ∘ translate(relativeOffset) ∘ mark.affine`; a mark's own rotation/scale pivots about its relativeOffset-anchored origin because the translate precedes `mark.affine` in the chain. Re-attach recomputes `relativeOffset = base.affine⁻¹(mark.worldPos) − base.affine⁻¹(base.worldPos)` — i.e., in base-local space, never as a raw world-space delta. Non-uniform base scale skews the offset component-wise, falling directly out of the affine chain (no special-casing needed). Mark-stack paint order gets its own dedicated field, `MKMarkNode.stackIndex: Int`, ending the overload of `MKProvenance.visualIndex` for this purpose.
- **Alternatives considered**: none material — this record makes normative a geometry that was already implied by the shaped-capture mechanism (D-105) but never written down precisely enough to implement or test; it is a specification fix, not a design choice among options.
- **Consequences**: Positive — mark placement under base rotation/scale/re-attach becomes numerically testable and font-consistent; the stackIndex field removes an ambiguous dual-purpose field. Negative — none; this only removes ambiguity. Obligation: numeric FUNCTIONAL tests are required (rotate ligature/mark group at 30/90/180/270° with non-uniform scale, assert exact positions against the formula above).
- **Confidence**: high — the formula is a direct, mechanical consequence of the already-adopted affine-chain scene model (D-111) and the shaped-capture mark model (D-105).
- **Dependencies**: D-105, D-106, D-111.
- **Validation trigger**: New numeric mark-position TEST_MATRIX fixtures at 30/90/180/270° plus non-uniform scale, asserting the D-220 formula exactly (DF-8).

## D-221 — Ligature fidelity clamp semantics + recompose dirty-check (amends D-108)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-3-1/3-2/3-3) found three related gaps in D-108's ligature decomposition/recomposition: (1) WS-04's n-ary constituent-placement algorithm was described only in ARCHITECTURE §7.5 prose ("proportional" offsets) rather than as a normative, implementable algorithm, and had no defined behavior when a ligature's natural fit falls outside a workable range; (2) R-8.10's "looks unchanged / Δ≤0.5 pt" requirement did not state the scope within which it actually holds; (3) the recompose dirty-check compared only transform state against the post-decomposition baseline, so a user who edited only style (fill/stroke/opacity/shadow) on a decomposed constituent and then recomposed silently lost that style edit with no confirmation.
- **Decision**: (1) The normative n-ary placement algorithm is WS-04's single affine fit: uniform scale clamped to [0.85, 1.15] plus per-component x-offsets, with the first and last constituent edge-aligned to the original ligature bounds and interior offsets derived from the fit (not from unspecified "proportional" prose); ARCHITECTURE §7.5's prose is subordinated to this normative algorithm. (2) Pre-flight check: if the natural fit falls outside the [0.85, 1.15] clamp, fidelity mode is REFUSED for that ligature and the system automatically falls back to default-forms decomposition with the existing notice UX (mirroring the R-21.9 pattern). R-8.10's "looks unchanged / Δ≤0.5 pt" holds only within the clamp and is reworded accordingly; it stays a P0 requirement with that narrowed scope. (3) The recompose dirty check now compares FULL node state — both transform AND style (fill/stroke/opacity/shadow) — against the post-decomposition baseline; the recompose confirmation fires on any delta in either category, closing the silent style-edit-loss defect.
- **Alternatives considered**: none material — (1)/(3) are specification/bug fixes to an already-adopted mechanism; (2)'s REFUSE-and-fallback choice reuses the existing R-21.9 fallback pattern rather than introducing a new one.
- **Consequences**: Positive — the fidelity path is now fully implementable and testable, including its failure mode; the dirty-check fix eliminates a real data-loss class (silent style loss on recompose). Negative — some ligatures will now visibly refuse fidelity mode and fall back to default forms where they previously had undefined behavior (honest, not a regression). Obligation: new fixtures — decompose-neighbor-overlap, style-only edit before recompose (T-ARR-LIG-STYLE), and clamp-boundary/refusal fixtures.
- **Confidence**: high for (1) and (3) as specification/defect fixes; medium for the clamp bounds' visual adequacy across the full D-120 font list, which remains empirically tested per font.
- **Dependencies**: D-105, D-106, D-107, D-108.
- **Validation trigger**: T-ARR-LIG-STYLE (style-only edit before recompose) and decompose-neighbor-overlap fixtures pass; ligature clamp-refusal fixture exercises the fallback path; R-8.10/R-8.12 PRD wording updated to match (DF-10).

## D-222 — Per-font Arabic fidelity gate (amends D-120)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-1-1/1-2/1-3/1-5/1-7/1-9) found D-120's WS-09 per-font verification protocol used only a reduced sweep (T-AR-58) rather than exercising the arrange-fidelity behaviors (D-105/D-107/D-108) that a font must actually support to ship; it also found no audit step for GPOS cursive attachment (type 3), no documented behavior for single-glyph scaling inside a joined word, and no discretionary-ligature (dlig) decompose fixture beyond lam-alif/الله.
- **Decision**: Every bundled font, at the moment it passes WS-09 license verification, must ALSO pass the arrange-fidelity block: T-AR-31/32/33 plus the decompose/recompose round-trip (T-AR-36..38) — not just the reduced sweep T-AR-58. WS-09's per-font verification protocol gains a GPOS lookup audit step: fonts using cursive attachment (GPOS type 3) on base glyphs are flagged; if any shipped font uses it, D-105's mark-capture model needs a cursive-pair structure before that font ships (recorded as `VERIFY` per font — not resolved here). Single-glyph scale inside a joined word: neighbor glyphs are NOT modified; the resulting stroke overlap/gap is accepted-by-design and documented exactly like the translate case (T-AR-32/33 pattern), with a new manual test added. A dlig discretionary-ligature decompose fixture is added beyond lam-alif/الله.
- **Alternatives considered**: none material — this closes a verification-coverage gap in an already-adopted protocol rather than choosing among design options.
- **Consequences**: Positive — no font ships supporting arrange/ligature features it cannot actually deliver correctly; GPOS cursive-attachment fonts are caught before they surprise the mark model. Negative — verification workload per font increases (T-AR-31/32/33/36-38 for every font, not a reduced sweep); a font found to need cursive-pair support blocks on a D-105 extension that does not yet exist (`VERIFY` per font, honestly unresolved here).
- **Confidence**: medium — the process and audit steps are sound and high-confidence; how many of the D-120 candidate fonts pass the full block, or require GPOS cursive-pair work, is empirical and unresolved by this record.
- **Dependencies**: D-105, D-107, D-108, D-120.
- **Validation trigger**: WS-09 exit: every shipped font passes T-AR-31/32/33 + T-AR-36..38 (not just T-AR-58); GPOS type-3 audit result recorded per font; new dlig fixture passes.

## D-223 — Critical-path autosave is journal-only (amends D-116; adjusts D-210 claim)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-9-1..10) found that D-116's stage-3/critical memory-pressure autosave path was underspecified in a way that risked doing a full re-encode and new large allocations at exactly the moment memory is most constrained — the save meant to protect against jetsam could itself contribute to it. It also found the journal artifact's path inconsistent (WS-02 documents `backups/journal.log`, no canonical name was fixed), the export-under-memory-pressure policy that T-MEM-6 references was referenced but never actually written, and D-210's claim that "the memory monitor can shrink strip height mid-export" had no defined triggering mechanism.
- **Decision**: On stage-3/critical memory pressure, autosave performs a synchronous JOURNAL flush only — append-only, no re-encode, no new large allocations. The full-scene `flushNow()` path runs only at stages 1–2 and on the normal debounced path. INV-17's wording is updated to match this split. The journal artifact is canonically `journal.mkj` at the package root (correcting WS-02's `backups/journal.log`). The export-under-pressure policy that T-MEM-6 references is now actually written: strip sizing stays static (64 MB budget, per D-210); if stage-3 pressure occurs during an active export, the in-flight strip completes, then the export PAUSES before starting the next strip until pressure drops below stage-2, with a cancel option offered to the user. D-210's claim that "the monitor can shrink strip height mid-export" is struck — static sizing plus pause is the actual mechanism. Stage tests must assert save-completes-before-evict ordering at every stage. A `.warning`-level `DispatchSource` memory event with `usedFraction < 70%` forces an immediate sample plus a stage-1 ladder entry (a conservative early trigger).
- **Alternatives considered**: (a) Keep full-scene flush at stage-3 — rejected: this is precisely the re-encode/allocation risk the finding identified during the highest-pressure moment. (b) Retain D-210's "shrink strip height mid-export" as the pressure response — rejected in favor of the simpler, already-bounded static-sizing-plus-pause mechanism, which needs no new dynamic resizing logic under pressure.
- **Consequences**: Positive — the critical-path save can never itself be the allocation that triggers jetsam; the journal path is now unambiguous; the previously-undocumented export policy is written and testable. Negative — an export paused at stage-3 takes longer to complete (acceptable: correctness over speed under pressure); the `.warning`/`usedFraction<70%` trigger fires conservatively and may cost a small amount of extra sampling/autosave activity.
- **Confidence**: high — the mechanisms (append-only journal, static strip budget, pause-not-resize) are simpler than what they replace and close a concrete correctness gap.
- **Dependencies**: D-112 (journal/autosave), D-116, D-210 (tiled export).
- **Validation trigger**: Stage tests assert save-completes-before-evict ordering at every stage; export-pause fixture exercises stage-3-during-active-export; `.warning`/usedFraction<70% early-trigger fixture.

## D-224 — Trial clock guard hardened (amends D-123; extends D-211)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-7-4) found that D-123's reserved `lastObservedBoottime` field was never wired into the clock-rollback guard, and that the guard's existing name, "monotonic guard," did not accurately describe what it does (compares wall-clock-elapsed against an uptime-anchored elapsed measure, not a pure monotonic clock read).
- **Decision**: Wire the reserved `lastObservedBoottime` field: on every trial observation, compare the elapsed time since first launch as anchored by `ProcessInfo.systemUptime` against the elapsed wall-clock time since first launch; if the uptime-elapsed measure exceeds the wall-clock-elapsed measure beyond a tolerance, treat uptime-elapsed as authoritative for trial aging (i.e., the trial ages by uptime, not by a wall clock that has been rolled back). The mechanism's name is corrected from "monotonic guard" to "wall-clock high-water mark + uptime cross-check," which is what it actually is.
- **Alternatives considered**: none material — this wires an already-reserved field per its originally-intended purpose and corrects terminology; it is not a new design choice.
- **Consequences**: D-211's residual-holes list (not edited in place; recorded here per file-ownership rules — see D-211's "extended by D-224/D-228" pointer) gains two items: (1) sustained pre-launch clock rollback is now mitigated by the uptime cross-check *within a single boot session*, but remains resettable by a reboot followed by a fresh rollback — recorded honestly as a residual, not eliminated; (2) subscribe-then-refund trial re-entry is a related residual, addressed by D-228 rather than by this record.
- **Confidence**: high — wiring an already-designed field and renaming it accurately carries low implementation risk; the residual (reboot-then-rollback) is honestly bounded, not closed.
- **Dependencies**: D-123, D-211.
- **Validation trigger**: T-SK-17 extension — sustained pre-launch rollback test; expected result is that the uptime cross-check catches the rollback within a single boot session (DF-8).

## D-225 — Referral dormancy: compile-time exclusion from Release (amends D-124 mechanism; FD-05 activation gate unchanged)

**FOUNDER-CONFIRMED 2026-07-17**

- **Status**: accepted/founder-confirmed 2026-07-17 (FD-05 activation gate unchanged and still founder-pending)
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-12-1..7) found that D-124's runtime-flag-OFF mechanism (`MKFeatureFlags.referralProgram`, compile-time default false but a runtime-checkable flag) still leaves `MKStore/Referral` code and its Arabic UI strings physically present and potentially reachable in the shipped Release binary — a Guideline 2.3.1 (dormant/hidden feature) exposure that a runtime flag alone does not close. It also found RUN1_SELF_REVIEW's claim that referral strings were already isolated in the string catalog to be incorrect (correction owned by W7).
- **Decision**: `MKStore/Referral` and its call sites (`ReferralSection.swift`) are wrapped in `#if MAKHTOOT_REFERRAL_ENABLED`, a compilation flag set only in Debug/internal configurations — never in the Release configuration used for App Store builds. Referral strings move out of the shared `Localizable.xcstrings` catalog into literals/a separate catalog under the same `#if`, so Release localization extraction never surfaces referral vocabulary. CI's `referral-removal-check` is extended to grep the built Release product itself for referral vocabulary (دعوة/إحالة/رمز الدعوة) and fail the build if any is present. APP_STORE_CHECKLIST §7A gains an explicit Guideline 2.3.1 (dormant/hidden feature) analysis.
- **Alternatives considered**: (a) Keep the D-124 runtime-flag-only mechanism — rejected: does not close the Guideline 2.3.1 exposure the finding identified, since code and strings remain physically present in Release. (b) Remove the referral module entirely pending FD-05 — rejected: contradicts Q78's instruction to architect the feature now; compile-time exclusion preserves the architecture while closing the review-risk gap.
- **Consequences**: Positive — a Release build genuinely contains no referral code or strings, closing the 2.3.1 exposure at the binary level rather than only at the UI level; CI now verifies this mechanically instead of by inspection. Negative — Debug/internal builds and Release builds now diverge at compile time (an existing accepted pattern for feature work, but worth noting); any future FD-05 activation requires a build-configuration change, not just a flag flip, which is a slightly heavier activation path than D-124 originally implied. Obligation: RUN1_SELF_REVIEW's string-catalog claim is corrected by W7.
- **Confidence**: high that compile-time exclusion strictly tightens isolation versus the runtime flag; the FOUNDER-CONFIRM flag exists because this changes how a founder-locked decision (D-124) is implemented, not because the change itself is in doubt.
- **Dependencies**: D-124, D-212, FD-05.
- **Validation trigger**: CI `referral-removal-check` greps the built Release product for دعوة/إحالة/رمز الدعوة and fails if present; APP_STORE_CHECKLIST §7A Guideline 2.3.1 analysis completed; founder confirmation of the mechanism change recorded; FD-05's fresh guideline recheck remains the separate, unchanged gate for any future activation.

## D-226 — CMYK conversion audit tightened (amends D-117 execution)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-6-1..6) found execution gaps in D-117's CMYK pipeline: the raster export path did not explicitly set a rendering intent before redraw; D-117's "single conversion point" claim was inaccurate (there are in fact two conversion sites, vector per-color and raster whole-image); TEST_MATRIX's ±1% tolerance had no specified ground-truth method; there was no fixture discriminating perceptual from relative-colorimetric intent on an out-of-gamut color; and two implementation questions (iOS bitmap-context CMYK support, exact CGPDFContext OutputIntent key shape) were unresolved and blocking WS-08.
- **Decision**: (1) The raster path sets `ctx.setRenderingIntent(.relativeColorimetric)` explicitly before redraw; D-117's "single conversion point" claim is rewritten as "two documented, intent-matched conversion sites (vector per-color; raster whole-image)." (2) Verification protocol: the TEST_MATRIX ±1% tolerance stands, but its ground-truth method is now specified — reference CMYK values are computed once with an external ICC-aware tool (littleCMS `transicc` or Argyll `xicclu`; the exact tool used is recorded at implementation) using the same profile and relative colorimetric intent, and checked into the fixture corpus; WS-08 task-3's acceptance criteria are rewritten to match (the "bands" language is removed). (3) A new discriminator fixture is added: a fully saturated out-of-gamut primary (#00FF00) is asserted to differ from the perceptual-intent result by more than tolerance. (4) Two `VERIFY-AT-IMPLEMENTATION` spikes are added, blocking WS-08 task 12: (a) `CGContext(data:space:CMYK)` bitmap-context support on iOS; (b) the exact CGPDFContext OutputIntent auxiliary-key name and value shape (dictionary vs array). (5) A new intent unit test converts a boundary color under `.perceptual` vs `.relativeColorimetric` and asserts divergence.
- **Alternatives considered**: none material — these are execution/verification-methodology fixes to the already-adopted D-117 pipeline, not a reconsideration of the CMYK-at-export decision itself.
- **Consequences**: Positive — the ±1% tolerance now has an auditable, reproducible ground truth instead of an undefined "bands" comparison; the intent-explicitness fix removes a source of platform-default-dependent color drift. Negative — WS-08 task 12 is now explicitly blocked on two VERIFY-AT-IMPLEMENTATION spikes whose outcomes are unknown; if (4)(a) shows no iOS CMYK bitmap-context support, the raster CMYK path needs a fallback design not yet specified (flagged, not resolved, here).
- **Confidence**: medium — the methodology and intent fixes are high-confidence; the two VERIFY-AT-IMPLEMENTATION spikes are genuinely open engineering unknowns.
- **Dependencies**: D-117, D-118, FD-03.
- **Validation trigger**: WS-08 task 12's two VERIFY-AT-IMPLEMENTATION spikes resolved; intent unit test and out-of-gamut discriminator fixture pass; WS-08 task-3 AC rewritten and green.

## D-227 — Export/licensing record + SVG schema reconciliation (amends D-118/D-122)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-5-1..7) found ARCHITECTURE §17.3's `MKLicenseRecord` shape had drifted from WS-09 T2's actual shape, ARCHITECTURE §16.6's SVG provenance schema had drifted from WS-08's actual schema, the OFL Reserved-Font-Names position under subset-embedding (rather than whole-font embedding) was unaddressed, emoji/color-glyph handling was unreconciled between R-21.10 (image element in all contexts) and the arranged-content outline rule, entitlement lapse vs. already-exported-file licensing was unstated, locked-font behavior during export was unspecified, and ownership of the pre-export outline-disclosure UI (R-13.7) was unassigned.
- **Decision**: (1) The canonical `MKLicenseRecord` is WS-09 T2's shape: `fontID, familyName, licenseType, copyrightNotice, reservedFontNames, sourceRepoURL, licenseFileBundlePath, verificationDate, verifiedBy, redistributionConfirmed, embeddingRights` (bitset); ARCHITECTURE §17.3 is rewritten to match, and §16.5/§16.6's `embedPDF`/`embedSVG` consumers become accessors over `embeddingRights`. (2) The canonical SVG provenance schema is WS-08's: space-separated hex codepoints, attributes placed on the per-glyph-group `<g>`, versioned `data-mk-schema="1"`; ARCHITECTURE §16.6 is corrected to match verbatim. (3) SVG `@font-face` embeds a COMPUTED SUBSET, matching the PDF path; the position on OFL Reserved Font Names under subset-embedding is recorded as `VERIFY-AT-SUBMISSION` — no legal assertion is made here. (4) §16.6 gains an emoji/color-glyph row: emoji export as an image element per R-21.10 in ALL contexts, including as a child of an arranged group — a carve-out to the arranged-always-outline rule that reconciles R-21.10 rather than contradicting it. (5) v1 premium-catalog fonts are OFL; embedding rights already present in already-exported files do not lapse with entitlement lapse (one-line note); FD-07 gains a forward-note that any future commercial-font addition will require re-deciding this export-time license boundary. (6) Locked-font-during-export: export uses `lastShapedCache` and never re-shapes; if no cache exists for locked-font live text, export is blocked at the gate with the replace-or-subscribe flow (D-119's existing pattern). (7) The pre-export outline-disclosure UI (R-13.7) is explicitly owned by WS-13 (new task/AC), consumes WS-08's FallbackNote list, and renders BEFORE export commit.
- **Alternatives considered**: none material — items (1)/(2)/(6) are reconciliations of drifted specs back to the already-implemented canonical shapes; (3)/(5) record VERIFY/forward-note status rather than resolving open legal questions; (4)/(7) apply the existing R-21.9-style carve-out pattern and existing gating pattern respectively, rather than introducing new mechanisms.
- **Consequences**: Positive — ARCHITECTURE and the actual WS-08/WS-09 implementations are reconciled to one canonical shape each, removing a spec/implementation divergence risk; export-time licensing behavior is now defined for every case (locked font, lapsed entitlement, emoji-in-arranged-group). Negative — the OFL-under-subset-embedding legal question remains genuinely open (VERIFY-AT-SUBMISSION); FD-07 now carries an additional forward obligation.
- **Confidence**: medium — the reconciliations themselves are high-confidence (they restate what was actually built); the OFL subset-embedding legal position is unresolved by design.
- **Dependencies**: D-118, D-119, D-120, D-122.
- **Validation trigger**: ARCHITECTURE §16.5/§16.6/§17.3 rewritten and reviewed; WS-13 pre-export disclosure task shipped and wired to WS-08's FallbackNote list; export fixture grid (D-118) extended to cover emoji-in-arranged-group and locked-font-during-export cases.

## D-228 — Entitlement UX closures (amends D-113/D-123)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-11-1..6) found five open entitlement-UX gaps: no UX existed for the redundant-subscription case (lifetime purchase while a subscription is active/grace/billingRetry); T-SK-13 carried an unresolved TODO on whether an in-flight export should be affected by mid-export revocation; whether purchase consumes the trial (re: refund/lapse re-entry within the 7-day window) was ambiguous, including copy precedence; the rationale for grace-period access outranking an active trial cushion was never recorded; and `pendingApproval` (Ask-to-Buy) state's relationship to `MKEntitlementResolver` output was unstated.
- **Decision**: (1) New P0 requirement: on a successful lifetime purchase while an active/grace/billingRetry subscription exists, an immediate one-time sheet prompts subscription cancellation with a manage-subscriptions link (not merely a Settings string). (2) Revocation mid-export: D-119's/R-21.55's rule extends to revocation — an export already rendering completes; the next export re-evaluates entitlement (resolving T-SK-13's TODO in this direction). (3) Trial is NOT consumed by purchase: re-entry after refund/lapse within the 7-day trial window is intended behavior, not a bug; copy precedence is recorded — an active trial chip wins over "expired (was premium)" copy; this residual is noted in D-211 via the "extended by D-224/D-228" pointer (bounded: ≤7 days). (4) Grace-over-trial rationale is recorded: billing problems must surface immediately even when a trial cushion is available, because grace is itself time-boxed and fixing payment preserves continuity — this ordering is intentional, not an oversight. (5) One sentence for D-113/§18.2: `pendingApproval` (Ask-to-Buy) is paywall-UI state only, never an entitlement state; `MKEntitlementResolver` output is unchanged until a verified transaction actually arrives.
- **Alternatives considered**: (a) For (1), silently allowing redundant lifetime+subscription without a prompt — rejected: leaves the user paying twice with no nudge to stop, a poor-faith pattern. (b) For (2), cancelling an in-flight export on revocation — rejected: destroys in-progress work for a state change that arrived mid-render; completing the current export and gating the next one is the less destructive rule, consistent with D-119's existing posture.
- **Consequences**: Positive — five previously-undefined entitlement-UX edge cases now have recorded, testable behavior; the grace-over-trial ordering is explained rather than left to look like an inconsistency. Negative — none beyond the residual already accepted in D-211/D-224 (bounded ≤7-day trial re-entry window).
- **Confidence**: high — each closure follows directly from already-adopted precedence (D-113) and gating (D-119) rules; none introduces a new mechanism.
- **Dependencies**: D-113, D-119, D-123, D-211.
- **Validation trigger**: T-SK-18 expanded to the full realizable 3-axis matrix including trial+billingRetry and trial+expired-sub; new post-purchase redundant-subscription prompt test; T-SK-13's TODO closed against the D-228(2) rule (DF-8).

## D-229 — Gating enforcement closures (amends D-119)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: Run-2 review (R2-7-1/2/3/5/6/7) found five gating-enforcement gaps under D-119: the `premiumContentPresent` walk that drives the export gate skipped nodes that were hidden or locked (a render-based rather than presence-based walk, letting hidden premium content escape the export block); `MKExportGate` enforced free-tier preset membership only in UI, not at the engine level; the `AlwaysPremium*`/`AlwaysFree*` test-only entitlement stubs had no build-time guarantee against reaching a Release build; `MKSyncService` (ARCHITECTURE §20) had no entitlement gate mirroring `MKExportGate`'s pattern; and duplicate-of-a-premium-content-project inheritance of flags/locks was undesigned-but-untested.
- **Decision**: (1) The `premiumContentPresent` walk now iterates ALL nodes in the snapshot regardless of `isHidden`/`isLocked` — presence-based, not render-based (new PRD requirement). (2) `MKExportGate` gains a free-tier preset-membership check (G20) enforced at the engine level, not only in UI. (3) Automated stub audit: stub types are `#if DEBUG`-gated so a Release reference fails the build, plus a source-audit test asserting no non-test/non-composition-root reference to `AlwaysPremium*`/`AlwaysFree*` exists. (4) A sync entitlement gate is written into ARCHITECTURE §20's `MKSyncService` code: engine start requires a non-free resolved entitlement state, mirroring the `MKExportGate` pattern. (5) A duplicate-project test is added: duplicating a premium-content project inherits its flag and locks (test only — the underlying design was already correct; this closes the test-coverage gap).
- **Alternatives considered**: none material — all five items close enforcement or test-coverage gaps in the already-adopted D-119 gating model; none reconsiders the gating policy itself.
- **Consequences**: Positive — hidden premium content can no longer escape the export gate by being hidden or locked; sync now has the same entitlement discipline as export; the stub types can no longer silently ship in Release. Negative — none; these are pure hardenings of an already-correct design.
- **Confidence**: high — each closure is a mechanical enforcement fix, not a new policy.
- **Dependencies**: D-113, D-119.
- **Validation trigger**: New hidden-premium-layer export-block test; duplicate-as-expired-user gating test; source-audit test asserting no non-test/non-composition-root reference to the stub types (DF-8).

## D-230 — MKStoreAPI protocol-seam placement (recovers orphaned ARCHITECTURE decision; content per ARCHITECTURE §2.1)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: ARCHITECTURE §2.1 originally minted this decision locally as "D-200," alongside a second local decision it labeled "D-201" (recorded separately as D-231). Those local labels collided with DECISIONS_LOG's own, already-assigned D-200 (Localization: single `ar` String Catalog) and D-201 (Text input: UITextView overlay) — an id collision identified by Sweep B finding 1. This record recovers the orphaned ARCHITECTURE content under a fresh, non-colliding id.
- **Decision**: `MKExport` and `MKSync` must query entitlements without depending on StoreKit. FOUNDATION already notes "entitlement queries via protocol"; concretely, `MKFoundation` hosts the protocol surface — `MKEntitlementProviding`, exposing an async `currentState() -> MKEntitlementState` (snapshot read, resolves in-memory, never blocks on network, per INV-9) and a push `stateUpdates: AsyncStream<MKEntitlementState>` for UI badges/gating banners — and `MKStore` provides the live implementation, injected at app assembly (D-231). `MKEntitlementState` carries the D-113 precedence order (`lifetime > subscribed > inGracePeriod > inBillingRetry > trial > free`) with `isPremium` true for every case but `.free`.
- **Alternatives considered**: none recorded — ARCHITECTURE presents this as a clarification of an already-adopted dependency rule (the module dependency graph already shows `MKExport`/`MKSync` depending only on `MKStoreAPI(protocols)`, not on `MKStore`), not a choice among options.
- **Consequences**: Positive — `MKExport` and `MKSync` remain testable/mockable without a live StoreKit dependency; the protocol boundary is enforced by which module hosts the type (`MKFoundation`, a leaf dependency of both). Negative — none beyond the bookkeeping cost of this record's existence (recovering a mis-numbered decision).
- **Confidence**: high — this is a direct transcription of already-implemented, already-diagrammed ARCHITECTURE content.
- **Dependencies**: D-113 (entitlement precedence/resolver); consumed by D-231 (composition-root wiring).
- **Validation trigger**: Module dependency-graph conformance check (ARCHITECTURE §2.1): `MKExport` and `MKSync` import only `MKFoundation`'s protocol surface, never `MKStore` directly.

## D-231 — Composition-root assembly (`MakhtootAppServices`) (recovers orphaned ARCHITECTURE decision; content per ARCHITECTURE §2.1)
- **Status**: accepted
- **Date**: 2026-07-17
- **Context**: ARCHITECTURE §2.1 originally minted this decision locally as "D-201," colliding with DECISIONS_LOG's own already-assigned D-201 (Text input: UITextView overlay) — the same Sweep B finding 1 that produced D-230. This record recovers the orphaned content under a fresh, non-colliding id.
- **Decision**: The app target owns a single `MakhtootAppServices` composition root, created in `MakhtootApp.init`, which constructs every service, wires protocol seams (including D-230's `MKEntitlementProviding`), and hands scene-level environments to SwiftUI. No singletons exist except `MKLog` (an `os.log` wrapper) and `MKFeatureFlags` (a constant table).
- **Alternatives considered**: none recorded — ARCHITECTURE presents this as the direct consequence of the module dependency graph's leaf/consumer structure, not a choice among options.
- **Consequences**: Positive — dependency injection is explicit and centralized at one construction site, keeping every service testable via protocol substitution at the composition root; the near-total absence of singletons keeps concurrency reasoning (D-102) tractable. Negative — none beyond the bookkeeping cost of this record's existence.
- **Confidence**: high — direct transcription of already-implemented ARCHITECTURE content.
- **Dependencies**: D-230.
- **Validation trigger**: Composition-root code review confirming no additional singletons are introduced beyond `MKLog`/`MKFeatureFlags`, and that every cross-module dependency is constructed/injected at `MakhtootApp.init`.

## Amended index (additions)

| ID | Title | Status | Confidence |
|---|---|---|---|
| D-215 | Pattern backgrounds premium-gated | accepted | high |
| D-216 | Price tiers $2.99/$29.99/$89.99 | accepted | high/medium |
| D-217 | All raster import premium-gated | accepted | high |
| D-218 | Cold-launch budget + memory-threshold clarification | accepted | high |
| D-219 | Modern CTFontManager API spelling | accepted | high |
| D-220 | Mark-attachment geometry normative (amends D-105/D-106) | accepted | high |
| D-221 | Ligature fidelity clamp + recompose dirty-check (amends D-108) | accepted | high/medium |
| D-222 | Per-font Arabic fidelity gate (amends D-120) | accepted | medium |
| D-223 | Critical-path autosave journal-only (amends D-116; adjusts D-210) | accepted | high |
| D-224 | Trial clock guard hardened (amends D-123; extends D-211) | accepted | high |
| D-225 | Referral dormancy: compile-time exclusion (amends D-124) — FOUNDER-CONFIRMED 2026-07-17 | accepted/founder-confirmed 2026-07-17 | high |
| D-226 | CMYK conversion audit tightened (amends D-117) | accepted | medium |
| D-227 | Export/licensing record + SVG schema reconciliation (amends D-118/D-122) | accepted | medium |
| D-228 | Entitlement UX closures (amends D-113/D-123) | accepted | high |
| D-229 | Gating enforcement closures (amends D-119) | accepted | high |
| D-230 | MKStoreAPI protocol-seam placement (recovers orphaned ARCHITECTURE D-200) | accepted | high |
| D-231 | Composition-root assembly `MakhtootAppServices` (recovers orphaned ARCHITECTURE D-201) | accepted | high |

**Founder confirmations 2026-07-17**: D-225 confirmed (referral dormancy compile-time exclusion mechanism). D-201 (normalize-during-edit rotation) and D-207 (CloudKit-record remote kill switch) reaffirmed as recorded. D-222 (per-font fidelity gate) recurring per-font workload acknowledged. D-226's CMYK bitmap-context approach confirmed, spike retained as written. The other three VERIFY-AT-IMPLEMENTATION spikes (OutputIntent key shape, CKSyncEngine min-OS, MKMemoryLadder Swift-6 isolation) remain blocking first-tasks in their owning workstreams per orchestrator judgment — no doc changes needed.

**Founder resolution 2026-07-19**: FD-03 resolved — Apple Generic CMYK elected for v1 (Option A), licensed profile deferred to v1.1 via the `ICCProfileStore` seam. See FD-03's record above for the supporting WS-08 P10-COMPLETION evidence.

*End of DECISIONS_LOG.md — 54 records (27 foundation, 6 founder-pending, 21 derived) plus 12 Run-2 adversarial-review records (D-220–D-231): 66 records total.*

---

# Part II — Android platform decisions (D-300…D-325)

Recorded in Batch 0.5 on 2026-07-30, transcribing
`ANDROID_SPINE.md` §2's frozen `D-300`–`D-325` register into this log's per-record format
(Format note above, 2026-07-20). This is the formal decision record for the founder's
2026-07-30 override of `CLAUDE.md`'s "iPhone and iPad only. No Android port, and none is
planned for v1." and `FOUNDATION.md` D-100 ("Universal iPhone+iPad") — those documents were
not silently contradicted; this run is the mechanism that amends them (`ANDROID_SPINE.md` §0).

**Append-only, by design.** Every record in Part I above (D-100–D-231) is unmodified by this
addition. Where a Part I decision is amended or carved out for Android only — D-100 (by
D-300), D-101 (by D-304), D-103 (replaced on Android only by D-303) — the original record's
iOS-authoritative text stands exactly as written; it is **not** retrofitted with an "Amended
by" pointer the way earlier amendments in this log were (e.g. D-117 → D-226), because this
batch's acceptance criteria require the existing D-1xx–D-231 records to remain byte-identical.
The amendment pointer instead lives in `FOUNDATION.md` §1/§13 and `CLAUDE.md`, per this run's
packet (`ANDROID_TASK_PACKETS/BATCH-0.md`, Agent 0.5). Authority chain for this Part:
`ANDROID_SPINE.md` (frozen spec, founder-authorised) > this log's Part II (transcription).
Where Part II and `ANDROID_SPINE.md` disagree, the spine is right and this log has a bug —
mirroring Part I's own authority-chain rule against `FOUNDATION.md`.

## D-300 — Android platform: phone+tablet+foldable, minSdk 29, Compose, Kotlin 2.1, RTL-first (amends D-100 for Android only)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: The founder's 2026-07-30 override authorizes an Android port of Makhtoot, which `CLAUDE.md` and `FOUNDATION.md` D-100 did not previously permit. FDA-07 locks minSdk at 29 (Android 10), not 26, specifically so the untestable API 26–28 `Picture`+bitmap-cache render fallback (see D-305) is deleted from the plan entirely rather than shipped unexercised.
- **Decision**: Android platform baseline: phone + tablet + foldable form factors, minSdk 29, compileSdk/targetSdk 36, Kotlin 2.1, Jetpack Compose (BOM), AGP 8.7+, JDK 17, NDK r27, Arabic-only UI forced to `ar` regardless of device locale (D-318), RTL-first from the toolchain up — the same `ar`-only UI commitment D-100 makes for iOS.
- **Alternatives considered**: (a) minSdk 26 with the API 26–28 fallback path — rejected: FDA-07 removes an untestable code path entirely rather than leaving it unexercised. (b) No committed toolchain, treat Android as exploratory — rejected: the founder's authorization is a committed decision the 66-agent register (`ANDROID_SPINE.md` §5) depends on having a frozen baseline. (c) A non-native toolchain (KMP/Flutter/RN) — rejected under D-323, not this record.
- **Consequences**: Positive — Android becomes a first-class platform alongside iPhone/iPad without weakening any iOS guarantee; minSdk 29 removes a fallback path that would otherwise ship untested. Negative — Android 9 and below is permanently out of scope; `CLAUDE.md`/`FOUNDATION.md` must both carry the amendment pointer so neither document is read as still saying "no Android port."
- **Migration impact**: Reversing this decision means deleting `android/` and reverting the `CLAUDE.md`/`FOUNDATION.md` pointers to "iPhone and iPad only" — cheap at the doc level, expensive in sunk engineering once Batches 1–9 ship, since the Kotlin/JNI port has no reuse outside Android.
- **Confidence**: high — founder-locked, internally consistent with FDA-07.
- **Dependencies**: FDA-01…FDA-08; amends D-100 (D-100 stays authoritative for iOS, unedited).
- **Validation trigger**: G0/G1 — `bash Scripts/android/gate.sh 0` (D-300…D-325 present in this log) then `gate.sh 1` (`./gradlew assembleDebug` green on all 18 modules under this toolchain).

## D-301 — Project layout: `android/` Gradle build, 18 modules mirroring MakhtootKit 1:1
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: Run 3-style agent-driven execution needs hard module boundaries so 66 concurrent agents cannot silently couple modules, the same forcing function D-101 named for `MakhtootKit`'s 16 targets.
- **Decision**: `android/` Gradle build with 18 modules mirroring the 16 `MakhtootKit` library targets 1:1 plus `:mk-native` (JNI facade, no Swift equivalent) and `:app`; version catalog + convention plugins; Kotlin package root `net.binjamshid.makhtoot`. Dependency edges are regenerated directly from `MakhtootKit/Package.swift`, not from prose (`ANDROID_SPINE.md` §3.2); an earlier draft invented two edges (`:mk-export → :mk-store`, `:mk-sync → :mk-store`) that do not exist — entitlement access from any module is via `MKEntitlementProviding` in `:mk-foundation` instead.
- **Alternatives considered**: (a) Fewer, coarser modules — rejected: breaks the 1:1 port-mapping and reviewability the audited Swift boundary provides. (b) A monolithic `:app` module — rejected for the same reason D-101 rejected it on iOS: no compiler-enforced boundary, and 66 concurrent agents would erode layering within days.
- **Consequences**: Positive — port mapping stays 1:1 and reviewable; compile-time layering matches the audited Swift dependency graph exactly. Negative — Gradle module bootstrapping and `build.gradle.kts` ownership must be centralized (Agent 1.1 is the sole owner during Batches 2–8, `ANDROID_SPINE.md` §3.2) so cross-module edge requests go through `CONTRACT_CHANGES.md` rather than direct edits.
- **Migration impact**: Restructuring module boundaries later means re-deriving the dependency graph from `Package.swift` again and re-running the affected batches' Gradle wiring — bounded but non-trivial once 18 modules are populated.
- **Confidence**: high — mirrors D-101's already-adopted one-package-many-targets shape.
- **Dependencies**: D-300; mirrors D-101 (unamended for iOS).
- **Validation trigger**: G1 — `./gradlew assembleDebug` green on all 18 modules; `CONTRACT_CHANGES.md` contains no `pending` entry.

## D-302 — Concurrency: Kotlin coroutines + StateFlow, Main.immediate UI, immutable scene graph
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: The same race-free rendering guarantee D-102 gives iOS via `@MainActor` + Swift 6 strict concurrency + a value-type scene graph is needed on Android, which has no direct language equivalent to actor isolation.
- **Decision**: Kotlin coroutines + `StateFlow`; UI runs on `Dispatchers.Main.immediate`; engines are pure/dispatcher-agnostic; the scene graph is immutable `data class` values, mirroring `MKScene`'s value-type CoW design (D-111).
- **Alternatives considered**: (a) Raw threads + manual locking — rejected: forfeits the compile-time-adjacent discipline coroutines + immutable data classes provide, the same reason D-102 rejected GCD queues + manual locking on iOS. (b) A mutable, reference-type scene graph with defensive copying at read time — rejected: reintroduces exactly the re-entrancy/race hazards the value-type model exists to prevent.
- **Consequences**: Positive — export/render/sync work operates on immutable snapshots exactly as `MKRender`/`MKExport` do against `MKScene` copies, so the same class of editor-vs-export race is structurally impossible on both platforms. Negative — engines must receive every input in the snapshot, same verbosity trade-off D-102 already accepted on iOS.
- **Migration impact**: Switching away from `StateFlow`/coroutines to a different concurrency model would touch every engine module's public surface — expensive, since it is the isolation contract every later batch's modules are written against from Batch 1's contract stubs onward.
- **Confidence**: high — mirrors D-102 exactly, a proven pattern already shipped on iOS.
- **Dependencies**: D-300, D-301; mirrors D-102 (unamended for iOS).
- **Validation trigger**: G2 — `:mk-foundation :mk-model :mk-color :mk-designsystem` tests green.

## D-303 — Shaping: HarfBuzz + FreeType + ICU BiDi via one JNI facade (replaces D-103 on Android only)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-103 locks Core Text as the iOS shaping source of truth precisely because Core Text has no Android equivalent. The "never write a shaper, never use presentation-form codepoints" invariant (`CLAUDE.md`, D-103) must hold on Android too, but nothing in the Android SDK exposes Core-Text-equivalent per-glyph/cluster introspection.
- **Decision**: HarfBuzz (`hb_shape`) does GSUB/GPOS shaping, FreeType extracts outlines, ICU does paragraph/run BiDi levels — all reached through one JNI facade in `:mk-native`. Never write a shaper; never use presentation-form codepoints, identical to D-103's ban.
- **Alternatives considered**: (a) Android's built-in text shaping (`StaticLayout`/`Paint`) — rejected: it does not expose the per-glyph/cluster geometry Arrange Mode's derivation (D-105/D-106 equivalents) requires, the same reason D-103 rejected building on a higher-level text API and instead used direct `CTRun` introspection. (b) A ground-up custom shaper — rejected outright, same as D-103 on iOS: multi-year effort, permanent correctness liability. (c) Presentation-form codepoint substitution — rejected for the same reasons D-103/D-202 rejected it on iOS: unreliable cmap coverage in GSUB-shaped fonts.
- **Consequences**: Positive — HarfBuzz is the industry-standard drop-in that preserves the "never write a shaper" invariant on a platform with no first-party equivalent to Core Text. Negative — two independent OpenType shaper implementations (Core Text on iOS, HarfBuzz on Android) will diverge on edge cases; this is the plan's highest-named risk (`ANDROID_SPINE.md` §13 R1), mitigated by the D-324 golden-fixture oracle and the D-325 delta register.
- **Migration impact**: Replacing HarfBuzz with a different shaper later means re-deriving every cluster/mark/ligature fixture in `android/fixtures/{shaping,joining,ligature,marks}/**` against the new shaper's output — the single most expensive reversal in this register, since D-303 is load-bearing for every text-engine module built in Batch 3+.
- **Confidence**: medium — the mechanism is sound and industry-standard, but per-font cross-shaper fidelity is empirical and only burned down by the D-325 register through G3.
- **Dependencies**: D-300, D-304 (HarfBuzz/FreeType are the D-304 carve-out); replaces D-103 on Android only — D-103 stays the iOS shaping source of truth, unedited.
- **Validation trigger**: G3 — zero Class-B shaping deltas, Class-A deltas ≤1% of (font × corpus string × glyph) triples, every Class-C row signed off in `android/SHAPING_DELTAS.md` (`ANDROID_SPINE.md` §12).

## D-304 — Third-party carve-out to D-101, Android only: HarfBuzz, FreeType, lcms2, AndroidX/Play Billing/Drive/kotlinx-serialization/OkHttp; no analytics SDK ever
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-101 locks zero third-party dependencies on iOS, achievable because Apple frameworks (Core Text, Core Graphics, CloudKit, StoreKit 2) cover the entire surface. No Android platform equivalent exists for OpenType shaping, font outline extraction, or ICC color management.
- **Decision**: Vendored under `android/mk-native/third_party/`: HarfBuzz (+ `hb-subset`), FreeType, lcms2. ICU comes from the platform. JVM side: AndroidX, Play Billing, Drive REST client libraries, kotlinx-serialization, OkHttp. No analytics SDK, ever — that prohibition is absolute and not part of the carve-out.
- **Alternatives considered**: (a) Zero dependencies on Android too, reimplementing shaping/outline-extraction/color-management from scratch — rejected: this is exactly the "write a custom shaper" outcome D-103/D-303 both forbid; the dependency-free posture was never the actual goal, correctness without reimplementing the OS was. (b) A broader carve-out permitting any convenient library — rejected: the carve-out is scoped to exactly the libraries with no platform equivalent, preserving D-101's spirit (minimize dependencies) even where its letter (zero dependencies) cannot hold.
- **Consequences**: Positive — the carve-out is narrow and named, so it cannot be read as "Android has no dependency discipline"; D-101 stays unamended and fully in force for iOS. Negative — `android/mk-native/third_party/**` needs licence verification per vendored library (`VERIFY-AT-SUBMISSION` posture, `ANDROID_SPINE.md` §9) before submission, mirroring FD-03's CMYK-profile licence caution on iOS.
- **Migration impact**: Removing any one vendored library later requires re-implementing or re-sourcing its function inside `:mk-native` — HarfBuzz/FreeType removal is not realistically reversible without abandoning D-303; lcms2 removal would require an alternative CMS for D-315.
- **Confidence**: high — the carve-out is mechanical and narrowly scoped to named libraries with no platform equivalent.
- **Dependencies**: D-101 (amended for Android only, unedited for iOS); enables D-303, D-310, D-311, D-315.
- **Validation trigger**: G1 — `:mk-native` smoke test passes on arm64-v8a, armeabi-v7a, x86_64.

## D-305 — Rendering: RenderNode (API 29+) is the only path, no API 26–28 fallback
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-114 chose a CALayer-per-top-level-node model on iOS so gesture manipulation stays cheap (layer-property transforms, no redraw) against the D-115 frame budgets. Android's nearest equivalent, `RenderNode`, is only reliable from API 29; FDA-07 locks minSdk at 29 specifically to avoid shipping an untestable API 26–28 fallback.
- **Decision**: Core Graphics → Skia via `android.graphics.Canvas`; one `RenderNode` per top-level node. `RenderNode` (API 29+) is the only path — the API 26–28 `Picture` + bitmap-cache fallback is deleted from the plan entirely per FDA-07's minSdk 29, not merely deprioritized. Metal→Vulkan is a documented seam only, exactly as D-114 keeps Metal as an unexercised extension seam on iOS. **Documented limitation**: `Modifier.blur` is a no-op below API 31, so `MkFloatingBar`'s translucent surface degrades to a flat alpha surface on API 29–30 — visually verified on an API 30 emulator at Batch 8.5.
- **Alternatives considered**: (a) Support API 26–28 via the `Picture`+bitmap-cache fallback — rejected: FDA-07 explicitly deletes this to avoid an untestable code path, not merely to simplify the plan. (b) A Metal/Vulkan renderer from day one — rejected for the same reason D-114 rejected a Metal renderer on iOS: premature engineering cost against an unproven need; Vulkan stays a documented seam.
- **Consequences**: Positive — preserves the cheap-transform-per-node model D-115's frame budgets depend on; removing the untestable fallback path is a net correctness gain, not a scope cut. Negative — no fallback means the `RenderNode` path must simply work on every supported device (`ANDROID_SPINE.md` §13 R8); the blur no-op on API 29–30 is a real, documented visual degradation, not a hidden gap.
- **Migration impact**: Adding a lower-minSdk fallback later means designing and testing the deleted `Picture`+bitmap-cache path from scratch — realistically a new decision, not a revert, since FDA-07's rationale (removing an untestable path) would need to be separately re-litigated.
- **Confidence**: medium — the mechanism mirrors D-114's proven CALayer-per-node model, but the no-fallback commitment and the blur degradation are real, named risks (R8, R9) not yet verified on real hardware.
- **Dependencies**: FDA-07 (minSdk 29); mirrors D-114 (unamended for iOS).
- **Validation trigger**: G4 (render goldens within `android/docs/RENDER_TOLERANCE.md` tolerance) and G8 (`MkFloatingBar` flat-alpha-surface degradation visually checked on an API 30 emulator).

## D-306 — Canvas host: custom `MkCanvasView` via `AndroidView`, owned transform matrix
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: iOS's canvas host is a `UIScrollView`-zoomable `UIView` (D-114); `ScrollView` on Android cannot reproduce `UIScrollView`'s bounce/zoom-bounds/content-inset semantics the canvas gestures depend on.
- **Decision**: Custom `MkCanvasView : View` hosted in Compose via `AndroidView`; pan/zoom is an owned transform matrix driven by `ScaleGestureDetector` + `GestureDetector` + raw pointer tracking, not a `ScrollView`.
- **Alternatives considered**: (a) `ScrollView`/`NestedScrollView` with a custom zoom layer bolted on — rejected: cannot reproduce `UIScrollView`'s bounce/zoom-bounds/content-inset semantics, which would have to be reimplemented on top of it anyway, making the wrapper pure overhead. (b) Delegate pan/zoom entirely to Compose's built-in gesture modifiers — rejected: insufficient control for the 5,000-node manipulation-frame-time budgets D-115 sets, which need direct pointer-event ownership.
- **Consequences**: Positive — full control over gesture arbitration matching `MKCanvas`'s behavior contract. Negative — bounce/zoom-bounds/content-inset semantics must be explicitly reimplemented and explicitly tested (Batch 5.1/5.2a/5.2b), rather than inherited free from a system component.
- **Migration impact**: Reverting to a `ScrollView`-based host would mean losing the fine-grained gesture control the reimplementation was built for, and re-deriving all D-306-dependent gesture tests against different underlying semantics.
- **Confidence**: medium — the pattern is standard for custom canvas editors, but full semantic reimplementation of `UIScrollView`-equivalent behavior is a high fidelity-risk item per `ANDROID_SPINE.md` §3's platform substitution table.
- **Dependencies**: D-300, D-302; replaces the `UIScrollView` half of `MKCanvas`'s mechanism (D-114) — behavior target unchanged.
- **Validation trigger**: G5 — canvas gesture tests green.

## D-307 — Text-editing overlay: transparent EditText + custom InputConnection (mirrors D-104)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-104 keeps canvas/export pixel-identical on iOS by making the `UITextView` overlay display-only during editing; committed rendering always goes through `MKTextEngine`→`MKRender`. The same display-only-overlay discipline is needed on Android.
- **Decision**: Transparent `EditText` + custom `InputConnection` handles IME/Arabic keyboard/selection handles/cursor; committed rendering always goes through `mk-textengine`→`mk-render`, never the overlay.
- **Alternatives considered**: (a) A fully custom `InputConnection`-free touch-based text editor — rejected for the same reason D-104 rejected implementing `UITextInput` on iOS: months of marked-text/selection/dictation edge cases to reimplement what the system input framework gives for free. (b) Render live through the `EditText` permanently — rejected: cannot guarantee canvas≡export parity, same reasoning as D-104's rejection of permanent `UITextView` rendering.
- **Consequences**: Positive — native Arabic IME/keyboard behavior with zero custom text-input logic; canvas/export parity guaranteed by construction, exactly as on iOS. Negative — OEM keyboard behavior varies more on Android than iOS's single first-party keyboard stack, a named medium fidelity risk in the platform substitution table.
- **Migration impact**: Reversing to a fully custom input surface would reopen the entire IME/selection/marked-text problem space D-104's overlay pattern exists to avoid — high cost, not attempted lightly on either platform.
- **Confidence**: medium — the pattern mirrors D-104's proven approach, but IME/selection-handle behavior varying by OEM keyboard is a real, named risk.
- **Dependencies**: D-300, D-306; mirrors D-104 (unamended for iOS).
- **Validation trigger**: G5 — Batch 5.4a IME/interaction tests green (canvas gesture/interaction test suite).

## D-308 — Persistence: `.makhtoot` directory, byte-identical layout to iOS, Room for metadata only
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-112 established the iOS file-package format (`manifest.json`, `scene.json`, `assets/`, `backups/`, `thumbnail.png`) with a SwiftData metadata index that never touches the scene graph. D-309's zip interchange (below) depends on Android's on-disk layout being byte-identical to iOS's.
- **Decision**: `.makhtoot` project as a directory in app-private storage, byte-identical internal layout to iOS; Room replaces SwiftData for metadata only, never the scene graph; atomic write-temp+rename, debounced autosave ≤2 s, journal + crash recovery — the same mechanisms D-112 specifies.
- **Alternatives considered**: none material beyond D-112's own already-adopted rejections (SwiftData/Core-Data-style object-graph storage, GRDB/SQLite scene rows, UIDocument-style whole-container sync) — this record substitutes Room for SwiftData as the metadata-only store, the direct Android analogue, without reopening D-112's underlying storage-shape argument.
- **Consequences**: Positive — byte-identical layout is exactly what makes D-309's zip interchange possible without a translation layer; Room's typed local-database model is a direct SwiftData analogue at the metadata layer. Negative — Room and SwiftData must be kept in schema lockstep by hand, since there is no shared ORM across the two platforms.
- **Migration impact**: Diverging Android's on-disk layout from iOS's later would break D-309's zip interchange outright, requiring a translation layer that does not currently exist — this is the most load-bearing "keep in lockstep" obligation in the whole register.
- **Confidence**: high — low fidelity risk per the platform substitution table (plain filesystem layout, well specified).
- **Dependencies**: D-300; enables D-309; mirrors D-112, substituting Room for SwiftData.
- **Validation trigger**: G3 — persistence journal + crash recovery tests green.

## D-309 — Interchange: zipped `.makhtoot` as the cross-platform document format; iOS gains zip import/export
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: FDA-01 explicitly scopes sync as Android↔Android (Drive) and iOS↔iOS (CloudKit) only — an iOS device and an Android device never see each other's projects via sync. Moving a project between an iPhone and an Android device therefore needs a non-sync mechanism.
- **Decision**: Zipped `.makhtoot` (STORED/DEFLATE, no path-traversal on extract) is the cross-platform document format. Android reads/writes both directory and zip forms; iOS gains zip import/export in Batch 9 · Agent 9.3 (FDA-08); `schemaVersion` + migrator chain are shared and kept in lockstep across both platforms.
- **Alternatives considered**: (a) No cross-platform interchange at all, sync-only — rejected: FDA-01 explicitly does not cover cross-platform sync, so without this mechanism a user could never move a project between an iPhone and an Android device by any means. (b) A new, Android-specific export format instead of reusing `.makhtoot` — rejected: would require a translation layer and abandon the byte-identical-layout benefit D-308 establishes for free.
- **Consequences**: Positive — the only mechanism that lets a user move a project between platforms without cloud sync; extends D-112's already-adopted file-package format rather than inventing a new one. Negative — the shared `schemaVersion`/migrator chain is a new, permanent cross-platform coordination obligation with no iOS-only precedent.
- **Migration impact**: Removing zip interchange later is low-cost on Android (drop the zip read/write path) but strands FDA-08's iOS-side agent's work (Batch 9 · Agent 9.3) as dead code unless separately reverted there too.
- **Confidence**: high — low fidelity risk per the platform substitution table; mechanically well-specified (plain zip semantics over an already byte-identical layout).
- **Dependencies**: D-308; FDA-01, FDA-08; new — no iOS-only precedent, extends D-112.
- **Validation trigger**: G3 (Android read/write of both forms) and G9 (iOS-side zip import/export, Batch 9 · Agent 9.3).

## D-310 — Sync: Google Drive `appDataFolder`, Credential Manager (identity) + GIS AuthorizationClient (Drive scope) (replaces the CloudKit clause of D-112 on Android)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-112 uses CKSyncEngine for premium project sync on iOS; CloudKit has no Android SDK. FDA-01 resolved the premium sync mechanism question as Google Drive's `appDataFolder`. An earlier formulation said "Credential Manager sign-in" handles authorization, which is wrong — Credential Manager returns only a Google ID token and grants no OAuth scopes; the `drive.appdata` scope requires a separate step.
- **Decision**: Google Drive `appDataFolder`, Drive v3 REST. Credential Manager handles identity only. Authorizing `https://www.googleapis.com/auth/drive.appdata` is a separate step via Google Identity Services (GIS) `AuthorizationClient`/`AuthorizationRequest`. One project = one folder of blobs; last-writer-wins + conflict-copy fallback named "(نسخة متعارضة)" — the same policy/naming/engine as `MKSyncDecisionEngine`, reused unchanged; premium-gated.
- **Alternatives considered**: (a) Credential Manager alone for both identity and Drive authorization — rejected: this was the earlier, incorrect formulation; Credential Manager cannot actually obtain the Drive scope, so the two-step Credential-Manager-plus-GIS flow is not a stylistic choice but a functional necessity. (b) A different cloud storage backend (e.g. a founder-run server) — rejected by D-300/`CLAUDE.md`'s no-backend posture; `appDataFolder` is the closest hidden-app-storage analogue to CloudKit's private database without introducing a server.
- **Consequences**: Positive — reusing `MKSyncDecisionEngine`'s conflict policy/naming/engine unchanged keeps conflict semantics identical across platforms, even though the transport differs completely. Negative — no CKSyncEngine equivalent exists, so change-token/quota semantics differ and must be handled explicitly by the new Drive transport (Batch 6.3a); the two-mechanism auth flow (identity + scope authorization) is more moving parts than CloudKit's single container-based model.
- **Migration impact**: Replacing Drive with a different sync backend later means re-deriving the transport layer (6.3a) from scratch while keeping the decision-engine/conflict-policy layer (6.3b) unchanged — the policy layer is the reusable, low-cost-to-preserve part; the transport is not.
- **Confidence**: medium — high fidelity risk per the platform substitution table (no CKSyncEngine equivalent; change-token/quota semantics differ; two-mechanism auth).
- **Dependencies**: FDA-01; D-304 (OkHttp/Drive client libraries); replaces the CloudKit clause of D-112 on Android only — D-112's CloudKit clause stays unamended for iOS.
- **Validation trigger**: G6 — Drive sync round-trips a project including a conflict copy, exercising the Credential Manager + GIS `AuthorizationClient` two-step auth.

## D-311 — Store: Google Play Billing 7+, entitlement precedence mapped to Play states (mirrors D-113)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-113 locks `lifetime > subscribed > inGracePeriod > inBillingRetry > trial > free` precedence via `MKEntitlementResolver` on iOS, with on-device StoreKit 2 verification and no backend. Play Billing's state machine has no 1:1 StoreKit 2 equivalent and exposes no client-side `paymentState`/`subscriptionState` signal.
- **Decision**: Google Play Billing 7+; entitlement precedence (D-113) mapped to Play's states: `lifetime` ← acknowledged INAPP, `subscribed` ← ACTIVE subscription, `inGracePeriod` ← Play grace, `inBillingRetry` ← account hold/paused, `trial` ← D-312, `free` otherwise; on-device RSA signature verification only, no backend; `acknowledgePurchase` within 72 h is a first-class tested work item; restore = `queryPurchasesAsync`, mandatory UI. Play exposes no client-side signal to distinguish grace from billing-retry — both states retain premium and show one generic banner, since a state-specific banner (as on iOS) would require the server-side Play Developer API, which this plan deliberately does not introduce.
- **Alternatives considered**: (a) Introduce the server-side Play Developer API to distinguish grace/hold precisely — rejected: would require standing backend infrastructure, contradicting `CLAUDE.md`'s no-backend posture and D-300/D-304's scope. (b) A single generic "payment issue" state collapsing all of grace/hold/trial-lapsed — rejected: loses the D-113 precedence semantics the resolver already correctly distinguishes for every other state; only grace vs. billing-retry is genuinely unobservable, so only that pair is collapsed in UI copy, not the whole state machine.
- **Consequences**: Positive — the 72 h acknowledgement window and on-device-verification posture mirror D-113's rigor and are handled as first-class tested items rather than an afterthought (unacknowledged purchases auto-refund on Play, a real foot-gun with no iOS analogue). Negative — the grace/billing-retry banner-copy ambiguity is a genuine, permanent Play Billing API limitation (`ANDROID_SPINE.md` §14), not an implementation gap to be closed later.
- **Migration impact**: If the server-side Play Developer API is later introduced to distinguish grace/hold precisely, this decision's banner-copy limitation is removed but a backend dependency is introduced — a significant scope change requiring its own new decision, not a simple reversal.
- **Confidence**: medium — high fidelity risk per the platform substitution table; the grace/hold ambiguity is a documented, unresolvable-without-a-backend API limitation.
- **Dependencies**: D-113 (precedence mirrored), FDA-05 (Play product ids), D-304 (Play Billing library); mirrors D-113's precedence and on-device-verification posture.
- **Validation trigger**: G6 — Play Billing tested against the six `MKSandboxScenarioStub` scenarios.

## D-312 — Trial: 7-day app-side trial, HMAC-signed unencrypted DataStore blob, Auto Backup (mirrors D-123)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-123 persists the iOS trial record in Keychain (`kSecAttrAccessibleAfterFirstUnlock`, survives reinstall) mirrored to iCloud KVS, with earliest-timestamp-wins across devices. An earlier Android formulation proposed an AndroidKeyStore-wrapped blob mirrored to Auto Backup — that formulation is wrong: a Keystore key is destroyed on uninstall, so a Keystore-wrapped blob restored by Auto Backup would be permanently undecryptable, giving zero reinstall survival rather than merely weaker survival.
- **Decision**: 7-day app-side trial for everyone from first launch. The trial record is stored unencrypted but integrity-signed — HMAC with a key embedded in the app binary, tamper-evident, an appropriate posture for a 7-day trial — mirrored to Android Auto Backup (backup rules restricted to exactly that blob, `ANDROID_SPINE.md` §11). Clock-rollback guard via `SystemClock.elapsedRealtime()` anchor, never extends. "Earliest timestamp wins across devices" is deleted as a claim: Auto Backup is a single-slot restore performed once at device setup, not a live sync channel, so there is no cross-device propagation at all.
- **Alternatives considered**: (a) AndroidKeyStore-wrapped blob + Auto Backup — rejected: the Keystore key is destroyed on uninstall, so a restored blob would be permanently undecryptable, a correctness bug (zero reinstall survival), not a documented weakness. (b) Claim iCloud-KVS-style cross-device propagation via Auto Backup — rejected: Auto Backup is a single-slot device-setup restore, not a live sync channel; claiming propagation would be dishonest, violating `PROJECT_DESCRIPTION.md`'s "never invent or silently soften a quality claim" principle.
- **Consequences**: Positive — the HMAC redesign gives actual reinstall survival (via Auto Backup, if the user has not disabled it), correcting a real bug in the earlier Keystore formulation. Negative — Auto Backup can be disabled by the user, unlike Keychain's always-on accessibility class; there is no cross-device propagation at all, a strictly weaker guarantee than iCloud KVS, documented plainly (`ANDROID_SPINE.md` §13 R6) rather than as "weaker than iOS."
- **Migration impact**: Reverting to a Keystore-wrapped blob would reintroduce the zero-reinstall-survival bug this decision exists to fix — not a viable reversal without re-solving the same problem; a future addition of live cross-device trial sync would require a wholly new mechanism, since Auto Backup structurally cannot provide it.
- **Confidence**: medium — the mechanism is sound and the honesty requirement is met, but the reinstall-survival gap (Auto Backup disabled) is a real, documented limitation with no mitigation beyond disclosure.
- **Dependencies**: D-304 (DataStore); mirrors D-123, with the reinstall-survival gap documented as R6.
- **Validation trigger**: G6 — trial clock-rollback guard holds.

## D-313 — Raster export: tiled Bitmap strips, same 2 MP free-tier clamp (mirrors D-118's raster half)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-118 keeps free-tier raster export (JPEG, rasterized PDF) at a 2 MP effective-resolution cap via tiled `CGBitmapContext` strips so output size is bounded by disk, not RAM. The same numeric boundary must hold on Android for the free/premium gate to be identical across platforms.
- **Decision**: Tiled `Bitmap` strips → `Bitmap.compress` for PNG/JPEG; transparent PNG native; output size bounded by disk not RAM; same 2 MP free-tier clamp.
- **Alternatives considered**: none material — this is a direct platform substitution of D-118's raster mechanism (`CGBitmapContext` → `Bitmap`), not a reconsideration of the free/premium boundary itself, which is a product-pricing decision (D-119) out of this record's scope.
- **Consequences**: Positive — the free/premium raster boundary is numerically identical across platforms, so no user-facing behavior differs by device; the tiled-strip technique preserves D-116's "output size limited by disk, not RAM" property. Negative — none beyond the ordinary platform-substitution risk of a low-fidelity-risk item.
- **Migration impact**: Changing the free-tier clamp value later would need to be changed identically on both platforms to preserve parity — a coordinated change, not an Android-only one.
- **Confidence**: high — low fidelity risk per the platform substitution table; both platforms are mature 2D vector rasterizers.
- **Dependencies**: D-305; mirrors D-118's raster half.
- **Validation trigger**: G5 — export goldens (PNG/JPEG) match within tolerance.

## D-314 — PDF export: in-house PDF writer in `:mk-export` (mirrors D-118's PDF half, ports rather than reimplements)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-118 requires vector paths, live-text runs, font subsetting, ICC OutputIntent, and CMYK in the print-PDF export on iOS via `CGPDFContext`. Android's built-in `PdfDocument` has no CMYK support, no output intents, and no controlled font embedding, so it cannot meet the print-PDF bar D-117/D-118 already committed to.
- **Decision**: In-house PDF writer in `:mk-export` — vector paths, live-text runs, font subsetting via `hb-subset`, ICC OutputIntent, CMYK; Android's `PdfDocument` is explicitly rejected as insufficient.
- **Alternatives considered**: (a) Android's built-in `PdfDocument` — rejected: no CMYK, no output intents, no controlled font embedding; cannot meet the already-committed print-PDF bar. (b) A third-party PDF library — rejected under D-304's carve-out scope, which does not extend to PDF generation; the carve-out is limited to libraries with no platform equivalent and no viable in-house alternative, and a from-scratch writer is viable here (if expensive).
- **Consequences**: Positive — mirrors D-118's PDF half conceptually rather than reimplementing `CGPDFContext`'s API shape, so the output PDF structure (vector paths, subset embedding, OutputIntent) matches iOS's committed behavior. Negative — roughly 5,000 LOC of genuinely new code with no CG equivalent to lean on — the single largest net-new engineering item in the whole port (`ANDROID_SPINE.md` §13 R3), split across two agents (5.7a core writer, 5.7b subsetting/CMYK/ICC).
- **Migration impact**: Abandoning the in-house writer in favor of `PdfDocument` later would mean losing CMYK/OutputIntent/controlled-embedding support entirely — not a real reversal option while D-117/D-314's print-PDF commitment stands; the ~5,000 LOC investment is effectively sunk once built.
- **Confidence**: medium — high fidelity risk per the platform substitution table; ~5,000 LOC of new code with no CG equivalent to lean on is a genuinely open engineering risk until Batch 5 fixtures and the founder's external-viewer check (G5) pass.
- **Dependencies**: D-315 (CMYK conversion), D-304 (`hb-subset`); mirrors D-118's PDF half.
- **Validation trigger**: G5 — PDF structural validation (OutputIntent presence, object-stream well-formedness, font-subset integrity) as an automated check, plus the founder's Adobe Acrobat/macOS Preview external-viewer check.

## D-315 — Colour: lcms2 via NDK replaces CGColorSpace(iccData:) for sRGB→CMYK (mirrors D-117)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-117 converts sRGB to CMYK through an ICC profile via `CGColorSpace(iccData:)` at exactly one point — print-PDF export — with relative colorimetric intent. Android has no Core-Graphics-equivalent CMS.
- **Decision**: lcms2 via NDK replaces `CGColorSpace(iccData:)` for sRGB→CMYK with relative colorimetric intent; working space stays extended sRGB, document stores sRGB components; profile choice is FDA-03; no on-screen soft-proofing in v1, same as iOS.
- **Alternatives considered**: none material beyond D-117's own already-adopted rejections (DeviceCMYK without ICC, full soft-proofing pipeline, CMYK working space throughout the app, rasterize-then-convert) — this record substitutes lcms2 for Core Graphics' CMS as the direct Android analogue, without reopening D-117's containment-boundary argument.
- **Consequences**: Positive — lcms2 is the de facto open-source CMS implementing the same relative-colorimetric conversion Core Graphics uses, so the conversion *intent* matches exactly even though the implementation differs. Negative — a different CMS implementation than Core Graphics' means exact numeric CMYK output may differ slightly, a documented medium fidelity risk requiring its own verification pass, mirroring D-117's own "external tooling verification" gate.
- **Migration impact**: Swapping lcms2 for a different CMS later would require re-verifying every CMYK-conversion fixture and re-checking the print-PDF output against external tooling — moderate cost, isolated to the color-conversion module.
- **Confidence**: medium — the mechanism (industry-standard, same conversion intent) is sound; exact numeric parity with Core Graphics' output is a medium, empirically-verified risk per the platform substitution table.
- **Dependencies**: D-304 (lcms2); FDA-03 (profile choice, shared with iOS); mirrors D-117.
- **Validation trigger**: G5 — export goldens (including CMYK PDF path) match within tolerance; FDA-03's profile-licence posture (`VERIFY-AT-SUBMISSION`) carries over unchanged.

## D-316 — Fonts: bundled assets via AssetManager + FreeType/HarfBuzz, SAF import (mirrors D-122)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-122 registers fonts per-process via `CTFontManagerRegisterFontURLs(.process)` on iOS, with Files-picker-driven user import, sfnt validation, and content-addressed copy. `CTFontManagerRegisterFontURLs` has no Android analogue.
- **Decision**: Bundled fonts in `android/app/src/main/assets/fonts/**`, opened by FreeType/HarfBuzz via `AssetManager` fd + `hb_blob` — no extraction to disk, no OS-level registration needed. User import via SAF `ACTION_OPEN_DOCUMENT`, content-addressed copy, the same sfnt table validator ported byte-for-byte with the same Arabic error strings.
- **Alternatives considered**: (a) Extract bundled fonts to disk before opening — rejected: unnecessary I/O and disk usage; HarfBuzz can open fonts directly from an `AssetManager` blob, removing rather than replacing the OS-registration dependency `CTFontManagerRegisterFontURLs` served on iOS. (b) A new, Android-specific font validator — rejected: porting the existing sfnt validator byte-for-byte (with the same Arabic error strings) preserves the exact rejection behavior (`ttf/otf/ttc`/variable accepted, `woff/woff2`/bitmap-only/corrupt rejected) users already see on iOS.
- **Consequences**: Positive — the substitution removes a dependency rather than replacing it 1:1, a genuinely low-risk item; byte-for-byte validator porting keeps rejection behavior and error copy identical across platforms. Negative — none beyond the ordinary porting cost of the validator itself.
- **Migration impact**: Reverting to disk-extracted fonts later would add unnecessary I/O with no correctness benefit — not a meaningful reversal path.
- **Confidence**: high — low fidelity risk per the platform substitution table (the substitution removes a dependency rather than replacing it 1:1).
- **Dependencies**: D-303, D-304; mirrors D-122.
- **Validation trigger**: G3 — font validator rejects the same corpus iOS rejects.

## D-317 — Design system: MkTheme via Compose CompositionLocals, not MaterialTheme (mirrors D-126)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-126 locks a token-based `MKTheme` (semantic colors, Arabic type ramp, spacing/radius/motion tokens) rather than any off-the-shelf design system, since Makhtoot's Arabic-first token system needs full control. All 9 UI-chrome fonts are already bundled custom fonts on iOS, removing an SF-Arabic-equivalent dependency question on Android.
- **Decision**: `MkTheme` via Compose `CompositionLocal`s, not `MaterialTheme`; all 5 themes (Hibr حبر / Kufi كوفي / Naqsh نقش / Raml رمل / Tayf طيف) ported with identical tokens; since all 9 UI-chrome fonts are already bundled custom fonts, there is no system-font dependency to replace.
- **Alternatives considered**: (a) `MaterialTheme` as the theming base with custom tokens layered on top — rejected: `MaterialTheme` would fight, not host, a fully custom Arabic-first token system, the same reasoning that led D-126 to a fully custom `MKTheme` rather than adapting a system design language on iOS. (b) Re-theme with system fonts where the bundled custom fonts don't map cleanly to Compose defaults — rejected: unnecessary, since the UI-chrome fonts are already self-contained bundled assets requiring no OS integration on either platform.
- **Consequences**: Positive — the UI-chrome fonts being self-contained removes what would otherwise be the hardest parity risk (a system-font substitution); all 5 themes port with identical tokens, so visual identity is unchanged across platforms. Negative — none beyond the ordinary porting cost of re-expressing tokens as `CompositionLocal`s instead of SwiftUI environment values.
- **Migration impact**: Adopting `MaterialTheme` later would require re-deriving every component's token mapping and likely re-litigating visual parity with the 5 existing iOS themes — a significant, unforced cost with no correctness benefit.
- **Confidence**: high — low fidelity risk per the platform substitution table (comparable declarative UI paradigms; the hardest parity risk is removed by the fonts already being self-contained).
- **Dependencies**: D-300; mirrors D-126.
- **Validation trigger**: G2 — `:mk-designsystem` tests green.

## D-318 — Localisation: resConfigs("ar"), per-app locale pinned to ar regardless of device locale
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: `CLAUDE.md` and `FOUNDATION.md` D-100 lock Arabic-only UI as a strategic bet, not a gap — this must hold on Android too, on a platform where the OS locale is not the app locale by default (unlike iOS, where `ar` as development region drives the app's locale directly).
- **Decision**: `resConfigs("ar")`, `android:supportsRtl="true"`, per-app locale pinned to `ar` via `locales_config.xml` + `AppCompatDelegate.setApplicationLocales` regardless of device locale; `Scripts/check-localization.sh` gets an Android sibling.
- **Alternatives considered**: (a) Follow the device's system locale and only provide `ar` strings, falling back to a default Android locale for chrome not covered — rejected: Android's default fallback behavior would let system UI leak non-Arabic strings, breaking the Arabic-only bet in a way that cannot happen on iOS's single-locale-app model. (b) Support additional localizations on Android even though iOS stays Arabic-only — rejected explicitly: this is a new platform for the same Arabic-only product, not a new localization; `CLAUDE.md`'s "Localize into other scripts in v1" prohibition is unchanged by this port.
- **Consequences**: Positive — preserves the Arabic-only strategic bet identically on a platform where it takes active enforcement (per-app locale pinning) rather than being the default behavior. Negative — the per-app locale mechanism is new engineering surface with no iOS equivalent, needing its own verification (Batch 1.1's `resConfigs`/locale wiring).
- **Migration impact**: Removing the per-app locale pin would let Android fall back to system locale for any unhandled chrome string — a regression, not a neutral reversal, since it would silently violate the Arabic-only bet.
- **Confidence**: high — low fidelity risk per the platform substitution table (mechanical string-table translation, `ar`-only in both cases).
- **Dependencies**: D-300; mirrors the `ar`-only intent underlying D-100 §Platform and scope.
- **Validation trigger**: G0 — `android/strings/strings.xml` has every Arabic string from `Localizable.xcstrings`.

## D-319 — Accessibility: TalkBack replaces VoiceOver, 48dp touch-target floor, fontScale honoured
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: `CLAUDE.md`'s quality bar requires VoiceOver support and 44pt touch targets on iOS. The direct Android-platform-idiomatic substitutions are TalkBack and the 48dp Android convention.
- **Decision**: TalkBack replaces VoiceOver; touch-target floor 48dp (Android convention) replacing 44pt; `fontScale` honoured throughout; reduce-motion read from `Settings.Global.TRANSITION_ANIMATION_SCALE`.
- **Alternatives considered**: none material — this is a direct platform-idiomatic substitution at the same quality bar `CLAUDE.md` already sets for iOS, not a new accessibility scope decision; `PROJECT_DESCRIPTION.md` records accessibility as explicit founder "no" for v1 beyond baseline platform substitutions, and this record does not expand that scope.
- **Consequences**: Positive — same quality bar as iOS's VoiceOver/44pt requirement, achieved through the platform-idiomatic equivalent mechanism at each point. Negative — TalkBack's screen-reader traversal order and gesture vocabulary differ from VoiceOver's, a named medium fidelity risk requiring its own sweep (Batch 8.5) rather than an assumption of automatic parity.
- **Migration impact**: N/A — this is a baseline platform substitution with no meaningful "reversal" (removing it would mean shipping with no screen-reader support at all, which contradicts the stated quality bar).
- **Confidence**: medium — medium fidelity risk per the platform substitution table (screen-reader traversal order and gesture vocabulary differ by platform).
- **Dependencies**: D-317; new Android-specific elaboration of the accessibility clause in `CLAUDE.md`'s quality bar.
- **Validation trigger**: G8 — TalkBack sweep clean.

## D-320 — Analytics: consent-gated, on-device counters, kill switch ported verbatim (mirrors D-125)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-125 keeps analytics opt-in (default OFF), on-device font-usage bucket counters, with a kill switch and a strict no-text/no-project/no-identifier/no-font-file allowlist. FDA-04 resolves the Android upload transport as a no-op uploader until the founder-controlled static host exists.
- **Decision**: Consent (default OFF, versioned record), on-device font-usage bucket counters, kill switch port verbatim; upload target per FDA-04 (no-op until a founder-controlled host exists, never a third-party analytics SDK); never text, projects, identifiers or font files.
- **Alternatives considered**: none material — analytics has no iOS-specific dependency, so zero behavioral change from D-125 is directly achievable; only the upload transport differs, per FDA-04, and that question was already resolved at the FDA level, not reopened here.
- **Consequences**: Positive — zero behavioral drift from the iOS analytics contract, including the absolute no-third-party-SDK rule; the kill switch and consent-versioning mechanisms transfer without modification. Negative — none beyond the ordinary porting cost of re-expressing the same logic in Kotlin.
- **Migration impact**: Wiring a real upload endpoint later (once FDA-04's static host exists) is a transport-only change with no impact on the consent/counter/kill-switch logic this decision locks.
- **Confidence**: high — low fidelity risk per the platform substitution table (analytics payload shape is unchanged, only the transport moves).
- **Dependencies**: FDA-04; D-308 (Room-backed counters); mirrors D-125 exactly.
- **Validation trigger**: G6 — analytics module burned down alongside store and sync.

## D-321 — Referral: compile-time exclusion from the release AAB (mirrors D-225)
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: D-225 (founder-confirmed 2026-07-17) excludes the referral module and its strings from the Release binary entirely on iOS, not merely flag-gated, because of App Review risk. The same review-risk rationale applies identically to Play Store review.
- **Decision**: Same compile-time exclusion as D-225 — a `referral` source set present only in the debug variant plus `buildConfigField("boolean","REFERRAL_ENABLED",...)`; module and Arabic strings absent from the release AAB entirely; `Scripts/android/referral-release-grep.sh` mirrors the iOS ratchet script that proves the exclusion holds against the actual built binary, not just the source tree.
- **Alternatives considered**: none material — this is a direct mirror of D-225's already-adopted, founder-confirmed mechanism, not a new policy decision; the only new engineering surface is the Android-equivalent build-variant mechanism (source set + `buildConfigField`) and its corresponding grep-proof script.
- **Consequences**: Positive — the review-risk mitigation that already holds on iOS holds identically on Android from day one, with an equivalent binary-level proof mechanism, not just a source-tree convention. Negative — none; this is a pure hardening mirroring an already-correct design.
- **Migration impact**: Reactivating referral on Android would require the same founder reconfirmation against current Play guidelines that FD-05 requires on iOS — not a simple flag flip on either platform.
- **Confidence**: high — mirrors D-225's already-adopted, founder-confirmed mechanism exactly.
- **Dependencies**: D-320; mirrors D-225.
- **Validation trigger**: G9 — referral grep of the release AAB is clean.

## D-322 — Distribution: AAB + Play App Signing, Play Data Safety form, track ladder
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: iOS distributes via App Store Connect with a TestFlight-then-App-Store ladder (`PROJECT_DESCRIPTION.md` Launch direction). Android's standard distribution shape is structurally different (AAB format, Play App Signing, Data Safety form) but parallels the same underlying submission process in spirit.
- **Decision**: AAB + Play App Signing; Play Data Safety form replaces iOS privacy nutrition labels; track ladder internal → closed → production.
- **Alternatives considered**: (a) Universal APK distribution instead of AAB — rejected: AAB + Play App Signing is Play's standard, recommended distribution shape with per-device APK splitting; a universal APK forfeits that without a countervailing benefit. (b) Skip the internal/closed tracks and go straight to production — rejected: mirrors the same reasoning iOS's TestFlight-then-App-Store ladder already embodies (founder device verification before public release), applied to the Play equivalent track ladder.
- **Consequences**: Positive — standard, well-supported Play distribution shape that mirrors the iOS submission ladder in spirit even though the specific mechanisms (Data Safety vs. privacy labels, AAB vs. archive) differ. Negative — none beyond the ordinary porting cost of learning a second store's submission mechanics (FDA-06, Batch 9).
- **Migration impact**: N/A — standard distribution mechanics with no meaningful reversal; changing the track ladder later is a process change, not an architecture one.
- **Confidence**: high — low fidelity risk per the platform substitution table (both are standard app-store back-office consoles).
- **Dependencies**: FDA-06 (Play Console + merchant account); new — no direct iOS decision, parallels the App Store submission process.
- **Validation trigger**: G9 — signed AAB uploads to the internal track; Data Safety complete; referral grep of the release AAB is clean.

## D-323 — No KMP, no Flutter, no React Native
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: The Swift engine (`MakhtootKit`, 38,080 LOC, 1,101 passing tests, zero skips) is shipped and audited. `PROJECT_DESCRIPTION.md`'s product principles put "correctness of the Arabic engine first" ahead of everything else.
- **Decision**: No Kotlin Multiplatform, no Flutter, no React Native. The port is native Kotlin/NDK, using the shipped Swift source as an executable spec.
- **Alternatives considered**: (a) Kotlin Multiplatform, sharing business logic between iOS and Android — rejected: would require rewriting the shipped, tested Swift engine into KMP-compatible Kotlin, discarding the audited implementation rather than porting it, and iOS gains nothing from the rewrite since it already has a working engine. (b) Flutter — rejected: same rewrite cost, plus Flutter's own rendering stack would need to reproduce D-114/D-115's frame-budget model from scratch with no native CALayer/RenderNode analogue. (c) React Native — rejected: same rewrite cost as Flutter, with the added risk of a JS bridge sitting between gestures and the shaping-critical rendering path — directly at odds with D-115's 8.3 ms manipulation-frame budget.
- **Consequences**: Positive — the shipped, tested Swift engine is treated as ground truth (D-324) rather than being discarded; only a native Kotlin/NDK port allows using it as an executable spec module-by-module. Negative — none beyond the inherent cost of a full native port (66 agents, ~62,000 Kotlin LOC) versus a hypothetical shared-logic alternative that was never actually viable given the rewrite cost.
- **Migration impact**: Switching to a cross-platform framework after a native port ships would mean discarding the native Kotlin/NDK codebase entirely and starting over inside that framework's model — this decision is effectively irreversible once Batch 1+ ships meaningful code.
- **Confidence**: high — a policy decision directly enforcing `PROJECT_DESCRIPTION.md`'s own stated principle, not an empirical engineering trade-off.
- **Dependencies**: D-300, D-301; directly enforces `PROJECT_DESCRIPTION.md`'s "correctness of the Arabic engine first" principle at the tooling-choice level.
- **Validation trigger**: G1 — toolchain and module structure established with no cross-platform framework artifacts present.

## D-324 — Parity is enforced by fixtures, not by review
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: `CLAUDE.md`'s quality bar states plainly: "shaping regressions are invisible in review." Two independent shaper implementations (Core Text, HarfBuzz — D-303) make this doubly true across a two-platform port.
- **Decision**: Golden artefacts exported from the iOS engine in Batch 0 are the acceptance oracle for every engine module. Human review cannot reliably catch shaping regressions, so parity is enforced by fixture comparison, not by reviewer judgment.
- **Alternatives considered**: (a) Rely on code review and manual spot-checks for shaping parity — rejected outright by `CLAUDE.md`'s own stated principle, which this record elaborates for a two-shaper world rather than reopening. (b) Generate fixtures independently on each platform and compare aggregate statistics — rejected: per-(font × corpus string × glyph) triple comparison (D-325) is the only granularity that actually catches the class of regression that matters (dropped marks, changed glyph ids, broken ligatures), which aggregate statistics would average away.
- **Consequences**: Positive — the two-platform version of the same rule that already protects the iOS engine; extends `CLAUDE.md`'s "test the text engine with golden fixtures" principle explicitly to a world with two independent shapers. Negative — the fixture-export step (Batch 0 · Agent 0.2) is now a hard prerequisite for every later batch's correctness claims, since without it there is no oracle to compare against.
- **Migration impact**: N/A — this is a testing-methodology decision, not an architecture one; abandoning it would mean falling back to review-based verification, which `CLAUDE.md` already treats as unacceptable for shaping correctness.
- **Confidence**: high — direct elaboration of an already-adopted `CLAUDE.md` principle, not a new empirical claim.
- **Dependencies**: D-303; enables D-325; elaborates `CLAUDE.md`'s "test the text engine with golden fixtures" for a two-shaper world.
- **Validation trigger**: G0 — `android/fixtures/**` (deterministic categories) regenerates byte-identically on a second run.

## D-325 — Shaping-delta register: Class-A/B/C, Class-B is a hard gate failure and can never be registered
Supersedes: none
- **Status**: accepted
- **Date**: 2026-07-30
- **Owner**: Android-port authorization run
- **Context**: Two independent shaper implementations (Core Text, HarfBuzz — D-303) will diverge on edge cases; `ANDROID_SPINE.md` §13 R1 names this the plan's highest risk. Without a classification system, the agent that caused a shaping mismatch could also be the one who authorizes recording it as acceptable — a self-service loophole.
- **Decision**: Any legitimate Core Text ↔ HarfBuzz difference is recorded in `android/SHAPING_DELTAS.md` with font, input, delta, class (A/B/C), and reason. Class A (sub-pixel positional deltas within a stated, agent-tightenable tolerance; line-break opportunity choice; advance rounding) — an agent may register it directly. **Class B (any dropped, added, or reordered mark; any changed glyph id; any broken or differently-composed ligature; any changed joining form; any tashkeel loss) — never acceptable, a hard gate failure, and cannot be registered at all, full stop.** Class C (a legitimate font-behavior difference that is neither a rounding artifact nor a correctness violation) — requires founder sign-off, per row. An unregistered delta, or any Class-B delta, fails the gate.
- **Alternatives considered**: (a) A single "acceptable delta" bucket with agent self-certification — rejected: this is the exact self-service loophole this record exists to close; the agent that caused a mismatch must never be the one who authorizes recording it as acceptable. (b) No delta register at all, requiring 100% shaping identity between Core Text and HarfBuzz — rejected: unrealistic given two genuinely independent OpenType implementations; Class A's tolerance band exists precisely because some sub-pixel/rounding divergence is expected and harmless, and demanding zero divergence would either block the plan indefinitely or push agents toward silently ignoring real mismatches.
- **Consequences**: Positive — mechanically enforces `CLAUDE.md`'s non-negotiable "never silently mis-shape Arabic, drop tashkeel, or break a ligature" invariant across two independent shaper stacks, not just one; the three-class system removes the self-certification loophole by construction. Negative — Class-C rows require founder sign-off per row, a new per-decision bottleneck with no iOS-side precedent (iOS has only one shaper, so this class of question never arose there).
- **Migration impact**: Loosening the Class-B "never acceptable" rule later would directly contradict `CLAUDE.md`'s shaping-correctness invariant and would need to be a new, explicitly founder-approved decision, not a routine amendment — this rule is designed to be maximally hard to walk back.
- **Confidence**: medium — the mechanism itself is high-confidence (a direct, mechanical enforcement of an already-adopted principle), but the underlying risk it manages (real HarfBuzz/Core Text divergence across the 45-family font catalog) is a genuine, only-empirically-resolved unknown.
- **Dependencies**: D-303, D-324; new mechanism required specifically because Android introduces a second shaper; enforces `CLAUDE.md`'s "shaping correctness is non-negotiable."
- **Validation trigger**: G3 — zero Class-B deltas, Class-A deltas ≤1% of (font × corpus string × glyph) triples, every Class-C row signed off in `android/SHAPING_DELTAS.md`.

## Amended index (Android additions)

| ID | Title | Status | Confidence |
|---|---|---|---|
| D-300 | Android platform baseline (amends D-100 for Android only) | accepted | high |
| D-301 | Project layout: `android/` Gradle, 18 modules | accepted | high |
| D-302 | Concurrency: coroutines + StateFlow (mirrors D-102) | accepted | high |
| D-303 | Shaping: HarfBuzz/FreeType/ICU (replaces D-103 on Android only) | accepted | medium |
| D-304 | Third-party carve-out to D-101, Android only | accepted | high |
| D-305 | Rendering: RenderNode-only (mirrors D-114) | accepted | medium |
| D-306 | Canvas host: `MkCanvasView` owned transform matrix | accepted | medium |
| D-307 | Text-editing overlay: EditText + InputConnection (mirrors D-104) | accepted | medium |
| D-308 | Persistence: directory, byte-identical layout (mirrors D-112) | accepted | high |
| D-309 | Interchange: zipped `.makhtoot`, iOS gains zip I/O (FDA-08) | accepted | high |
| D-310 | Sync: Drive `appDataFolder` (replaces CloudKit clause of D-112) | accepted | medium |
| D-311 | Store: Play Billing 7+ (mirrors D-113) | accepted | medium |
| D-312 | Trial: HMAC-signed DataStore blob + Auto Backup (mirrors D-123) | accepted | medium |
| D-313 | Raster export: tiled Bitmap, 2 MP clamp (mirrors D-118) | accepted | high |
| D-314 | PDF export: in-house writer (mirrors D-118) | accepted | medium |
| D-315 | Colour: lcms2 via NDK (mirrors D-117) | accepted | medium |
| D-316 | Fonts: AssetManager + SAF import (mirrors D-122) | accepted | high |
| D-317 | Design system: `MkTheme` via CompositionLocals (mirrors D-126) | accepted | high |
| D-318 | Localisation: `resConfigs("ar")`, per-app locale pin | accepted | high |
| D-319 | Accessibility: TalkBack, 48dp (Android elaboration) | accepted | medium |
| D-320 | Analytics: verbatim port (mirrors D-125) | accepted | high |
| D-321 | Referral: compile-time exclusion (mirrors D-225) | accepted | high |
| D-322 | Distribution: AAB + Play Console | accepted | high |
| D-323 | No KMP/Flutter/React Native | accepted | high |
| D-324 | Parity enforced by fixtures, not review | accepted | high |
| D-325 | Shaping-delta register, Class-B hard gate | accepted | medium |

**Founder authorization 2026-07-30**: Android port authorized, overriding D-100 (`FOUNDATION.md`) and `CLAUDE.md`'s "iPhone and iPad only. No Android port" statement. `ANDROID_SPINE.md` is the frozen shared specification this Part transcribes; where this Part and the spine disagree, the spine is correct (mirroring Part I's own authority-chain rule).

*End of DECISIONS_LOG.md Part II — 26 records (D-300–D-325). Combined with Part I: 80 records total (54 Run 1/Run 2 + 26 Android-port, Batch 0 · Agent 0.5, 2026-07-30).*

---

# DECISIONS_LOG.md Part III — Cross-platform identity and entitlement

*Opened 2026-08-07. Part III holds records that span iOS and Android simultaneously and
therefore belong to neither Part I (iOS) nor Part II (Android port). Its first record,
D-326, is **proposed, not accepted** — it exists to be decided, and no code depends on it
until it is.*

## D-326 — Sign in with Apple as cross-platform identity, backed by a minimal entitlement service (PROPOSED — supersedes the no-backend clause of D-300/`CLAUDE.md` if accepted)

Supersedes: none yet. **If accepted**, amends `CLAUDE.md`'s "Never: add a backend, accounts,
or a network dependency without a new `D-###`" (this record is that `D-###`), narrows
D-212's serverless-attribution rationale, and adds a third entitlement signal source to
D-113/D-311 without changing either precedence order.

- **Status**: **proposed — founder decision required**. Nothing in this record is
  implemented. `MKFeatureFlags` gains no flag, `MKEntitlementResolver` is untouched, and
  no network call exists anywhere in the tree as a result of writing this.
- **Date**: 2026-08-07
- **Owner**: founder request, 2026-08-07 ("wire SIWA for cross-platform subscription sync
  and referrals")
- **Context**: The founder asked for Sign in with Apple to carry a subscription across the
  iOS and Android builds and to make referral attribution real. Investigation established
  that **no subset of this is achievable with the current architecture**, for reasons that
  are structural rather than preferential:

  1. **SIWA on Android has no serverless form.** iOS uses
     `ASAuthorizationAppleIDProvider` (`AuthenticationServices`) and needs no server to
     obtain an identity token. Android has no native SIWA SDK; the only path is Apple's
     web flow — a **Services ID** (a separate identifier from `net.binjamshid.makhtoot`)
     plus a registered return URL, `response_type=code`, `response_mode=form_post`. The
     token exchange at `appleid.apple.com/auth/token` requires a `client_secret` that is an
     ES256 JWT signed with a Sign in with Apple private key (`.p8`, ≤6-month validity).
     **That key cannot ship inside an APK**; a return URL must terminate somewhere. Both
     facts independently require a server.
  2. **Entitlements cannot cross the platform divide on-device.** An iOS StoreKit purchase
     is confirmable to an Android device only through the **App Store Server API**
     (`GET /inApps/v1/subscriptions/{transactionId}`, authenticated by an ES256 JWT signed
     with an App Store Connect API key). Play→iOS needs the **Play Developer API**
     (`purchases.subscriptionsv2.get`, service-account OAuth). Both are server-side by
     construction — Apple and Google publish no client-callable equivalent. D-311 already
     accepted a *worse user-facing outcome* (collapsing grace and billing-retry into one
     generic banner) specifically to avoid standing up the Play Developer API; that
     trade-off was made on this same constraint.
  3. **CloudKit cannot be the rendezvous.** D-310 records that CloudKit has no Android SDK
     — the reason Android sync went to Google Drive `appDataFolder` at all. Drive
     `appDataFolder` is per-Google-account and invisible to iOS, so it is not a shared
     store either. There is no existing transport that both platforms can reach.
  4. **The CloudKit public database is disqualified on its own terms.** D-207 uses it for
     advisory analytics, and D-212 explicitly considered and rejected it for referral:
     records that confer entitlement value must not sit in a publicly writable store —
     "an abuse design-flaw, not a limitation." Entitlement records are strictly more
     valuable than referral records, so the rejection applies a fortiori.

  The existing architecture anticipated exactly this request.
  `MKStore/Docs/ServerAPISeam.md` names `MKEntitlementVerifying` (ARCHITECTURE §24.5) as
  the landing point and states that server-side referral confirmation is what closes the
  `Referral/REVIEW_RISK_MEMO.md` §4 gap. This record proposes taking that seam.

- **Decision (proposed)**: Adopt SIWA as an **optional** identity anchor and stand up a
  minimal entitlement service. Five components:

  1. **Identity.** iOS: `ASAuthorizationAppleIDProvider` behind an
     `MKIdentityProviding` protocol in `MKFoundation` (protocol-in-MKFoundation,
     implementation-in-a-concrete-module, per the D-230 rule). Android: Apple's web flow
     in a Custom Tab against the Services ID. The stable SIWA `user` string is the
     account key on both platforms. Apple's private-relay email is never required — the
     app requests name/email scope **not at all**, since entitlement sync needs only the
     subject identifier.
  2. **Purchase↔identity linkage.** Use the platform-sanctioned mechanisms rather than
     inventing one: StoreKit's `Transaction.appAccountToken` (a UUID set at purchase time,
     returned in the transaction *and* in App Store Server Notifications V2) and Play
     Billing's `obfuscatedAccountId`. Both map to the SIWA subject server-side. This is the
     canonical linkage and avoids any receipt-scraping heuristic.
  3. **Entitlement service.** One endpoint — `GET /v1/entitlement` returning the D-113
     state — plus two webhook sinks (App Store Server Notifications V2, Play Real-time
     Developer Notifications) writing to a single `subject → entitlement` table. It stores
     the SIWA subject, the current entitlement state, and its expiry. It stores no
     document content, no font data, no analytics, and no email address.
  4. **Resolver integration.** `MKEntitlementVerifying` gains a server conformer alongside
     the existing on-device one. Per `ServerAPISeam.md`, the server signal is **merged as
     an additional input**, never a replacement: `MKEntitlementPrecedence.resolve` is a
     pure function over opaque signals and does not change at all. Offline behaviour is
     unchanged — INV-9's "never blocks on network" holds, with the last server answer
     cached and the on-device StoreKit signal always authoritative for the local store.
  5. **Referral.** Server-confirmed qualifying events replace D-212's honor-code relay,
     closing the enumerated self-referral and code-trading weaknesses. This is the *only*
     part of the referral problem a server solves; it does not build the missing UI (see
     the scope note in D-327).

- **Alternatives considered**:
  (a) **Do nothing; keep D-309 zipped-`.makhtoot` interchange as the only cross-platform
      story.** This is the current, coherent design and remains the recommendation if the
      founder is not prepared to operate a server indefinitely. Cost: a user who buys on
      iPhone buys again on Android. For a $2.99/mo product this may be cheaper than the
      alternative in both money and risk.
  (b) **Sign in with Google instead of Apple.** Rejected as *worse*, not better: it has a
      genuine Android SDK but on iOS it is a third-party dependency (D-204 prohibits) and
      would still require the same server for the entitlement table. Identity provider is
      not the hard part — the entitlement table is.
  (c) **Receipt-string copy/paste between devices.** Rejected: transferable secrets that
      confer entitlement are trivially shared, and it is a worse abuse surface than the
      honor-code referral D-212 already flagged as weak.
  (d) **A serverless function only for the SIWA token exchange, keeping entitlement
      on-device.** Rejected: it solves (1) but not (2). The entitlement table is the
      irreducible server-side component, so a token-exchange-only function buys an
      identity that nothing can act on.
  (e) **Third-party entitlement platform (RevenueCat/Adapty).** Genuinely the shortest
      path — these exist precisely to solve cross-platform entitlement — and rejected on
      D-204 (zero third-party dependencies) and D-207's privacy posture: it puts purchase
      data and a user identifier in a processor the privacy policy would have to name. If
      the founder is willing to amend D-204, this alternative deserves reopening on its
      merits, and this record should not be read as having dismissed it lightly.

- **Consequences**:
  - **Positive** — the only design that delivers what was asked; takes a seam the
    architecture already named rather than inventing structure; closes D-212's referral
    weaknesses properly; `MKEntitlementPrecedence` and every downstream consumer
    (`MKExport`, `MKFonts`, `MKSync`) are untouched because they code against
    `MKEntitlementProviding` (D-230).
  - **Negative — operational.** A solo founder acquires a permanently-operated service
    with TLS, key rotation (the SIWA `.p8` client secret expires every 6 months and
    *will* silently break sign-in on expiry), webhook uptime, and a database. D-207
    rejected a custom HTTPS endpoint partly on this exact liability.
  - **Negative — privacy label.** This is the sharpest consequence. The App Privacy label
    is currently "data not linked to you" (D-125/D-207), built on there being no account.
    A `subject → entitlement` table is by definition data linked to an identified user,
    and server access logs capture IP + timestamp — "exactly the identifier-adjacent data
    the privacy posture excludes," in D-207's own words. The label, the privacy policy,
    and `PrivacyInfo.xcprivacy` all change. Play's Data Safety form (D-322) changes too.
  - **Negative — App Review.** Guideline 5.1.1(v) requires the app stay fully usable
    signed-out, so sign-in must be strictly optional and the paywall must not gate on it.
    Guideline 4.8 is not triggered (SIWA would be the only login offered).
  - **Negative — effort.** Realistically multi-week, and the ongoing operational cost has
    no end date. This is not a sprint item.

- **Migration impact**: Reversible on the client (the server conformer is additive and can
  be unregistered, restoring today's on-device-only behaviour exactly). **Not reversible
  on the privacy label** — once shipped as account-linked, reverting to "not linked to
  you" requires a further review cycle and honest deletion of stored subjects.

- **Confidence**: **high** on the problem analysis — the four constraints above are
  properties of Apple's and Google's published APIs, not judgement calls, and each is
  independently sufficient to require a server. **Low** on the proposal being the right
  *business* call: alternative (a) may well be correct for a product at this price point,
  and alternative (e) is only excluded by a decision (D-204) the founder can revisit.

- **Dependencies**: D-113 and D-311 (precedence orders, unchanged), D-230
  (`MKEntitlementProviding` seam), D-204 (blocks alternative (e) as written), D-207 and
  D-125 (privacy posture this record breaks), D-212 (weaknesses this record closes),
  D-322 (Play Data Safety), FD-05 (referral activation, separate gate).

- **Validation trigger**: Founder decision. If accepted: a written re-acceptance of the
  privacy-label change specifically, before any code; then `MKEntitlementVerifying` lands
  with the on-device conformer still registered by default and the server conformer behind
  a flag, so the seam ships provably inert before it ships live.

---

## D-327 — FD-05 granted for iOS: referral activated and included in Release (amends D-225; D-321 unchanged, Android stays dormant)

Supersedes: none. **Amends D-225** (founder-confirmed 2026-07-17) on iOS only, by defining
`MAKHTOOT_REFERRAL_ENABLED` in the Release configuration that D-225 reserved for exclusion.
**D-321 is untouched** — Android referral remains excluded and dormant.

- **Status**: accepted — founder decision 2026-08-07
- **Date**: 2026-08-07
- **Owner**: founder
- **Context**: FD-05 ([D-124](#), [D-212](#), [DECISIONS_LOG.md §FD-05](#)) has stood
  PENDING since 2026-07-17 with a Run-1 recommendation not to activate in v1.x. The founder
  granted it on 2026-08-07 and directed that the feature be built out fully on iOS.
  Investigation at that time established the referral module was **engine-only**: 194 lines
  across `MKReferralCodeGenerator`/`MKReferralLedger`/`MKReferralRedemption`, with no
  `ReferralSection.swift`, no Settings entry, no Arabic strings, no share or entry surface.
  `MAKHTOOT_REFERRAL_ENABLED` was additionally defined in **no** build configuration
  (`project.pbxproj` sets only `DEBUG`), so the engine compiled in zero configurations
  including tests. Activation was therefore a feature build, not a flag flip.
- **Decision**:
  1. **FD-05 is granted for iOS.** Per D-212's explicit obligation ("if FD-05 ever
     green-lights activation, the founder explicitly re-accepts these weaknesses or funds
     the server variant first"), the founder re-accepts the enumerated D-212 attribution
     weaknesses, recorded here verbatim so the acceptance is auditable: *one human with two
     devices can self-refer (cap 4 bounds damage to 28 days of trial — bounded,
     non-monetary); codes can be traded publicly (same bound); no dedup of invitee
     identity; no revocation.* The server variant that would close these is
     [D-326](#d-326), which remains **proposed** and unfunded.
  2. **`MAKHTOOT_REFERRAL_ENABLED` is defined in Debug and Release** for the app target and
     unconditionally for the `MKStore` package target. This is the specific clause of D-225
     that this record amends: D-225 required the flag be set "ONLY in Debug/internal build
     configurations, never in Release."
  3. **The UI is built**: `ReferralSection.swift` under the same `#if`, reached from the
     Settings root, with Arabic strings as in-file literals (D-225's string-catalog
     isolation rule is *retained* — referral vocabulary still never enters
     `Localizable.xcstrings`, so localization extraction stays clean even though the
     binary now contains the feature).
  4. **`Scripts/referral-release-grep.sh` is inverted, not deleted.** Its D-225 role was to
     prove absence; its D-327 role is to prove *presence and completeness* — a Release
     build that contains the engine symbols but not the UI strings would mean a half-shipped
     feature, which is a worse 2.3.1 exposure than either extreme. The script keeps its
     exit-code contract; only the polarity and message text change.
  5. **Android is explicitly out of scope.** D-321 stands as written and Android referral
     stays dormant. See the open defect in Consequences.
- **Alternatives considered**: (a) Activate on both platforms simultaneously — not chosen;
  the founder scoped this to iOS, and Android's referral has a live defect (below) that
  must be fixed before any Android referral decision is meaningful. (b) Build the UI but
  keep Release excluded (Debug/internal only) — offered and not chosen; it would have
  preserved D-225 intact and allowed evaluation before commitment, at the cost of not being
  testable via TestFlight, which uses the Release configuration.
- **Consequences**:
  - **Positive** — the feature is real and reachable for the first time; D-225's
    string-catalog isolation and the CI ratchet both survive in amended form rather than
    being dropped.
  - **Negative — App Review exposure, the sharpest cost.** D-225 exists precisely because
    referral code and strings physically present in a Release binary is a **Guideline 2.3.1**
    (dormant/hidden feature) exposure, and the reward mechanic is a **Guideline 3.1.1**
    surface. Both risks are now live and knowingly accepted. `APP_STORE_CHECKLIST` §7A's
    2.3.1 analysis is rewritten from "feature is absent" to "feature is present, complete,
    and user-reachable" — the *only* form of this feature that is defensible at review.
    A half-built referral in a Release binary would be the worst of both worlds.
  - **Negative — the honor-code weaknesses are now shipping**, not theoretical. Bounded at
    28 trial days and non-monetary, per D-212's own bounding.
  - **Negative — D-225's founder-confirmed status is amended by a later founder decision.**
    This is legitimate (FD-05 was always the founder's gate) but means D-225 must be read
    together with this record, never alone.
  - **OPEN DEFECT, Android, pre-existing and unrelated to this activation**: D-321 specifies
    referral lives in "a `referral` source set present only in the debug variant." It does
    not. It is at `android/mk-store/src/main/kotlin/.../referral/`, `mk-store/src/` contains
    only `main`, and `android/app/build.gradle.kts` links it via an unconditional
    `implementation(project(":mk-store"))`. `MkReferralCodeGenerator`, `MkReferralLedger`
    and `MkReferralRedemption` will therefore compile into the release AAB, and
    `Scripts/android/referral-release-grep.sh` greps for exactly those symbols — it will
    fail the first time a release AAB is built at Batch 9. `REFERRAL_ENABLED` gates `:app`
    behaviour only, not the presence of the classes. **This is a D-321 violation in
    uncommitted work and is not fixed by this record.**
- **Migration impact**: Reversible — removing the two `MAKHTOOT_REFERRAL_ENABLED`
  definitions restores D-225's behaviour exactly, and the grep script's polarity flips back.
  The UI code would remain in the tree, compiled out, which is D-124's original
  "architect but isolate" posture.
- **Confidence**: **high** that the implementation matches what was asked and that the
  mechanism is correctly recorded. **Low** that this is the right product call — Run-1's
  recommendation against v1.x activation was made on grounds (weak attribution, review
  surface) that this record does not change, only accepts.
- **Dependencies**: D-124, D-212 (weaknesses re-accepted), D-225 (amended), D-321
  (unchanged), D-123 (trial-day grants), FD-05 (granted), D-326 (the unfunded fix).
- **Validation trigger**: `Scripts/referral-release-grep.sh` passes in its inverted form
  against a Release build; the referral flow is exercised end-to-end on device;
  `APP_STORE_CHECKLIST` §7A rewritten; the Android D-321 defect tracked separately.

---

**Part III register**

| ID | Title | Status | Confidence |
|---|---|---|---|
| D-326 | SIWA cross-platform identity + minimal entitlement service | **proposed — founder decision required** | high (analysis) / low (business call) |
| D-327 | FD-05 granted for iOS; referral activated in Release (amends D-225) | accepted/founder 2026-08-07 | high (mechanism) / low (product call) |

*End of DECISIONS_LOG.md Part III — 2 records (D-326–D-327), 2026-08-07.*

---

## D-328 — Free access for all implemented features

- **Date** · 2026-11-22
- **Status** · Accepted
- **Context** · The owner directed that all implemented Makhtoot features be free and
  that access no longer depend on subscriptions, one-time purchases, trials, or
  referral rewards.
- **Decision** · iPhone and iPad use a local free-access provider at the existing
  editor, export, font, and sync boundaries. Keep existing access contracts and
  saved-document fields for compatibility. Remove the paywall, in-app purchase and
  trial flows, and referral trial rewards from the app. Retain an Apple Account link
  for managing subscriptions from earlier App Store versions. Project sync
  requires a saved opt-in and an available iCloud account. Continue to enforce font
  licenses and technical resource limits. Apply the same nonbilling policy to the
  Android scaffold and remove its trial backup configuration.
- **Precedence** · Supersedes paid-access requirements in D-112, D-113, D-118–D-119,
  D-121–D-124, D-215–D-217 and their implementation refinements, including D-225,
  D-228–D-229 and D-327. Supersedes the billing, trial, referral, and paid-access
  portions of the Android design in D-310–D-313 and D-321. The proposed
  cross-platform subscription identity service in D-326 is superseded by this
  policy.
- **Verification** · Exercise a first launch, open an existing document with
  legacy access flags, and verify unrestricted access to the implemented editing,
  font, import, and export paths. Verify that project sync stays off until a user
  enables it, and that Settings links to Apple for earlier subscriptions.
