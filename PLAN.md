# Makhtoot (مخطوط) — PLAN.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.
## Phased, Dependency-Ordered Program Plan (Run 1)

This plan conforms to FOUNDATION.md (authoritative). Phases are exactly P0–P15 from
FOUNDATION §11; workstream packets are exactly WS-01..WS-15. Decision references use
D-1xx ids (FOUNDATION) and FD-0x founder decisions. Requirement references point to
`_input/BRIEF.md` bullets. No calendar dates are used anywhere: effort is expressed as
relative size S / M / L / XL, and ordering is expressed purely as dependency structure
(see DEPENDENCY_GRAPH.md for the per-edge rationale).

> **Status | Built? | Verified against source on 2026-07-20** — **partially built.**
> `docs/impl-log/WS-01.md` through `WS-14.md` exist (plus a `WS-16-cursive.md`
> follow-up) — those workstreams have implementation logs recording what actually
> shipped, including 11 documented deviations from this plan's Run-1 design.
> **WS-15 (distribution/P15) has no impl-log and has not started**: no archive, no
> TestFlight build, no App Store submission exists (see README "Shipped vs.
> planned"). Phase-level G-BUILD/G-PERF gate claims below were not independently
> re-run this pass. Where this document and the code disagree, the code wins
> (README "Authority rule").

**Quality-gate vocabulary used throughout** (BRIEF "Engineering — Gates (Q59)"):
- **G-BUILD** — `xcodebuild` build success for the `Makhtoot` app target + all
  `MakhtootKit` library targets, Swift 6 strict concurrency, zero errors.
- **G-PERF** — performance profiling against the quantitative D-115 budgets
  (manipulation frame time ≤8.3 ms ProMotion / ≤16.6 ms A12-class floor; typing echo
  <50 ms; open ≤100-node project <1 s and 5,000-node <3 s; incremental autosave
  <100 ms off-main; 4K PNG export <10 s on A15; peak editor memory <60% of
  `os_proc_available_memory` before degradation).
- **G-STORE** — StoreKit sandbox + StoreKit Testing (Xcode) test passes for the
  purchase/restore/entitlement scenarios defined in TEST_MATRIX.md.
- **G-ARABIC** — the manual Arabic-script verification checklist (TEST_MATRIX.md)
  executed by a human-driven pass on device/simulator: shaping, contextual forms,
  ligatures, tashkeel, bidi, numerals, punctuation, and — after P5 — arranged-glyph
  fidelity checks.

Every phase's exit criteria name the subset of these gates that must pass. G-BUILD is
mandatory at every phase exit; the other gates attach where they first become
meaningful and then remain regression gates for all later phases.

---

## 1. Program shape at a glance

The program is a single dependency spine — model → text engine → canvas → arrange —
with subsystems (fonts, export, store, sync, analytics, assets) attached at the
earliest point their upstream contracts stabilize. Two structural rules govern the
whole plan:

1. **The differentiator gets the longest soak time.** The Arabic text/glyph engine
   (P3) and Arrange Mode (P5–P6) are the product (BRIEF "Arabic text & glyph engine —
   the differentiator"; market study §1/§3: no competitor has per-glyph editing).
   They enter the build as early as the module graph permits and every later phase
   exercises them, so shaping-capture defects surface with maximum remaining runway.
2. **Premium is stubbed, not blocking.** `MKStore` exposes an entitlement protocol
   from P0; P4–P10 develop against an always-premium stub so no feature work waits on
   StoreKit. P11 flips the stub to the real resolver and adds gating enforcement
   (D-113, D-119). See DEPENDENCY_GRAPH.md "Stub strategy".

### Milestone table

| Milestone | Phase | Meaning (demoable state) | Gates at exit | Effort |
|---|---|---|---|---|
| M0 «هيكل» (Skeleton) | P0 | Project builds, runs, empty RTL shell, flags + logging live | G-BUILD | S |
| M1 «مظهر» (Look) | P1 | Design-system components render; navigable app shell, RTL-first | G-BUILD | M |
| M2 «ذاكرة» (Memory) | P2 | Documents create/save/reopen/undo; crash-recovery proven | G-BUILD | L |
| M3 «حرف» (Letter) | P3 | Shaped Arabic renders via engine identically to system text; cluster map verified | G-BUILD, G-ARABIC(v1 checklist) | XL |
| M4 «لوحة» (Canvas) | P4 | Type, select, move, transform Live Text + shapes on canvas at frame budget | G-BUILD, G-PERF(interim), G-ARABIC | L |
| M5 «ترتيب» (Arrange) | P5 | Arrange Mode: per-glyph select/transform, revert-to-text round-trip | G-BUILD, G-ARABIC(arrange) | XL |
| M6 «تشكيل» (Marks) | P6 | Marks attach/detach/move; ligature decompose/recompose; joining forms | G-BUILD, G-ARABIC(full) | XL |
| M7 «مسار» (Path) | P7 | RTL text on live Bézier paths; arrange-on-path | G-BUILD, G-ARABIC(path) | L |
| M8 «عناصر» (Assets) | P8 | Ornaments/shapes/frames placeable; raster/SVG/PDF import | G-BUILD | M |
| M9 «خطوط» (Fonts) | P9 | Full bundled set verified + catalog + premium download + user import | G-BUILD, G-ARABIC(per-font) | L |
| M10 «تصدير» (Export) | P10 | All export formats incl. SVG editability + CMYK PDF; print-sharpness verified | G-BUILD, G-PERF(export), G-ARABIC(export) | XL |
| M11 «اشتراك» (Premium) | P11 | Real entitlements, trial, paywall, gating enforcement | G-BUILD, G-STORE | L |
| M12 «مزامنة» (Sync) | P12 | Premium CloudKit project sync with conflict copies | G-BUILD, G-STORE(entitlement-gated sync) | M |
| M13 «خصوصية» (Privacy) | P13 | Opt-in analytics, settings, licensing screen complete | G-BUILD | S |
| M14 «صلابة» (Hardening) | P14 | All D-115 budgets green on device matrix; memory ladder proven | G-BUILD, G-PERF(full), G-ARABIC(regression) | L |
| M15 «نشر» (Ship) | P15 | Distribution-Ready definition met; submission executed | ALL gates + APP_STORE_CHECKLIST.md | M |

Total effort profile: 3×S/M-light, 5×M, 5×L, 4×XL — the XL mass sits on the
differentiator (P3, P5, P6) and on export (P10), matching the risk ranking in market
study §3 (per-glyph editing = very high value/high difficulty; CMYK = medium-low
feasibility, kept in v1 by founder override Q75).

---

## 2. Phases

### P0 — Scaffold

**Objective.** A building, runnable, correctly structured empty app: one
`Makhtoot.xcodeproj` app target + local SPM package `MakhtootKit` with all §2 module
targets declared (empty or near-empty), Swift 6 strict concurrency on, `ar`-only
localization with development region `ar`, placeholder bundle id
`net.binjamshid.makhtoot` (FD-01 applied), and the cross-cutting utilities every later
packet needs on day one.

**Scope in.**
- Project + package layout per D-101; module targets and their dependency
  declarations exactly as FOUNDATION §2 (so illegal imports fail at compile time from
  the first commit).
- `MKFoundation`: geometry/transform value types, RTL utilities, id generation,
  structured logging, error taxonomy, `MKFeatureFlags` with `referralProgram`
  default **OFF** (D-124), memory-pressure monitor skeleton (D-116 sources wired,
  ladder actions stubbed).
- Protocol seams that unblock parallelism: `MKEntitlementProviding` (with
  `AlwaysPremiumEntitlements` stub), `MKFontProviding` (system-font-backed stub),
  `MKAnalyticsRecording` (no-op). See DEPENDENCY_GRAPH.md §5.
- `xcodebuild` command-line build/test invocations documented and proven; codebase-
  memory MCP project indexed; ADR-0001 (project layout) recorded.

**Scope out.** Any UI beyond a blank RTL root scene; any persistence; any Core Text
work; no third-party dependencies in v1 (D-101/D-204).

**Entry criteria.** Run-1 package accepted; founder has *not* yet supplied FD-01
(explicitly not blocking — placeholder ids are used until P15).

**Exit criteria (gates).** G-BUILD on simulator + device destination via
`xcodebuild`; all module targets compile with declared dependency edges only; a
smoke launch shows an RTL root view with `ar` locale; unit-test target runs (even if
near-empty).

**Deliverable artifacts.** Xcode project + SPM package skeleton; `MKFoundation`
sources; stub protocol definitions; ADR-0001; implementation log + verification
evidence (build transcript) in codebase memory.

**Workstreams.** WS-01 (scaffold portion).

**Effort.** S.

**Risks retired.** Toolchain risk (Swift 6 strict concurrency viability across all
targets); module-boundary risk (dependency rules enforced mechanically); "tooling
creep" risk (proves Xcode+xcodebuild+gh suffice, Q49).

**Founder pause.** None. (FD-01 now applied: `net.binjamshid.makhtoot`.)

---

### P1 — Design System & Shell

**Objective.** `MKDesignSystem` (D-126) plus the navigable app shell: project
browser scaffold, editor scene placeholder, settings skeleton — everything RTL-first,
Arabic-only, themeable via `MKTheme` tokens so the future visual-identity process
(BRIEF "Product identity") re-themes without refactoring.

**Scope in.**
- `MKTheme` protocol + default «حبر ورق» (Ink & Paper) theme (FD-02, editable):
  semantic colors, Arabic type ramp (system SF Arabic for UI), 4-pt spacing grid,
  radii, elevation, motion tokens.
- RTL-first component kit: panels, inspector field primitives, sliders, chips,
  toolbar/tab primitives, banner (used later by memory-pressure D-116 and grace-
  period D-113 messaging).
- App shell navigation: project browser (empty state), editor scene container,
  Settings → Support → Licensing placeholder route (Q66), paywall route placeholder.
- Onboarding placeholder (content later; structure now so trial-start-at-first-launch
  instrumentation in P11 has a home, Q37).

**Scope out.** Real project lists (P2), real canvas (P4), paywall content (P11),
final aesthetics (post-design-run FD-02). Accessibility work beyond what SwiftUI
gives for free (BRIEF Q53: not a v1 requirement — no material scope).

**Entry criteria.** P0 exit.

**Exit criteria (gates).** G-BUILD; component gallery debug screen renders all kit
components in RTL on iPhone + iPad size classes; theme swap (token override) changes
the whole shell with no per-view edits; navigation reaches all placeholder scenes.

**Deliverable artifacts.** `MKDesignSystem` target; app-target navigation shell;
component gallery; ADR (theme architecture); screenshots as verification evidence.

**Workstreams.** WS-01 (design-system portion), WS-13 (shell/browser scaffold start).

**Effort.** M.

**Risks retired.** RTL layout risk in SwiftUI components (found now, not during
feature UI); re-theme risk (token discipline proven before any feature UI exists).

**Founder pause.** None blocking. FD-02 flagged: the «حبر ورق» baseline proceeds as
the editable default; founder approval/edit lands before the visual-polish window in
P14 (FOUNDATION §10: FD-02 blocks "Visual polish phase", not P1).

---

### P2 — Model & Persistence

**Objective.** The value-type scene graph (D-111) and the decisive persistence stack
(D-112): `.makhtoot` file-package documents, atomic debounced autosave with
journaling and crash recovery, in-memory undo/redo command stack, and the SwiftData
metadata index (projects, folders, search, export history, font-catalog state,
analytics counters, trial/consent records).

**Scope in.**
- `MKModel`: `MKScene`/`MKNode` enum tree with all cases (`group`, `liveText`,
  `pathText`, `arranged(text)`, `shape`, `image`, `background`), decomposed
  transforms, style (solid fill v1, stroke, shadow), locked/hidden/name, z-order;
  arranged-child node types (Glyph/Mark/Ligature) with provenance fields — the
  *schema* exists now even though nothing produces arranged nodes until P5, so the
  Codable contract and `schemaVersion: 1` migration seam are stable early.
- `MKPersistence`: file-package layout (`manifest.json`, `scene.json`, `assets/`
  content-addressed, `backups/`, `thumbnail.png`); write-temp+rename atomicity;
  ≤2 s debounced autosave plus immediate autosave on background/memory-pressure
  hooks; crash-recovery journal replay; undo/redo inverse-command stack with gesture
  coalescing; SwiftData metadata store (metadata ONLY — never scene graph, D-112).
- Project browser becomes real: create, duplicate, rename, folders, search, delete
  (BRIEF "Canvas & projects": all users get local autosave, duplicate, folders,
  search, export history).
- Fault-injection tests: kill -9 during save, disk-full, journal replay.

**Scope out.** CloudKit sync (P12 — but the D-112 record-shape decision is honored
now so sync bolts on without schema change); asset import pipelines (P8); rendering.

**Entry criteria.** P0 exit (P1 not strictly required, but browser UI lands on P1
components — see DEPENDENCY_GRAPH.md parallelization map: P1 ∥ P2 after P0).

**Exit criteria (gates).** G-BUILD; round-trip property tests (scene → JSON → scene
identity) pass incl. arranged-node schema; crash-recovery fault tests pass with zero
data loss (BRIEF Performance: "no-loss recovery after termination"); autosave
measured <100 ms off-main on a representative scene (early D-115 datapoint); browser
CRUD + search works on device.

**Deliverable artifacts.** `MKModel`, `MKPersistence` targets; document format spec
(in ARCHITECTURE §13 terms); fault-injection test suite; ADR (D-112 restated with
implementation notes); verification evidence: recovery-test logs.

**Workstreams.** WS-02.

**Effort.** L.

**Risks retired.** Persistence-choice risk (D-112 proven with real fault tests before
any feature depends on it); undo-model risk (value-type inverse commands validated);
schema-migration risk (versioned envelope from day one).

**Founder pause.** None.

---

### P3 — Text Engine

**Objective.** `MKTextEngine`: Core Text shaping *capture* (D-103) — the single
hardest correctness surface in the product. Attributed-string build →
CTTypesetter/CTLine/CTRun introspection; per-run glyphs/positions/advances/string
indices; the bidirectional cluster map (D-105); bidi run map (D-109); joining
analysis and ZWJ-technique form resolution (D-107); font-feature control
(`kLigaturesType`/`dlig`/`calt`, D-108); glyph outline extraction via
`CTFontCreatePathForGlyph`.

**Scope in.**
- Shaping-capture API returning immutable shaped-run structures consumed later by
  MKRender (P4) and MKArrange (P5).
- Cluster model: codepoint ↔ cluster ↔ glyph maps; ligature-candidate detection
  (>1 codepoint → 1 glyph); combining-mark classification for the full ranges named
  in D-105 (U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED Qur'anic annotation range —
  BRIEF Q11 "full" Uthmani-style marks) with GPOS-resolved relative offsets.
- Joining analysis per letter (Joining Form: isolated/initial/medial/final) and the
  synthetic-context ZWJ reshape harvest (D-107) as an engine primitive.
- Bidi: per-run `kCTRunStatusRightToLeft`, bidiLevel + visual index retention,
  paragraph base direction RTL default (D-109).
- **Fixture strategy (fonts-before-engine bring-up):** a minimal P3 fixture set of
  2–3 already-verified OFL fonts (Amiri, Noto Naskh Arabic — verified per BRIEF
  "market study §5 verified so far") registered via the P0 `MKFontProviding` stub
  path. The *full* WS-09 catalog/verification program stays in P9; the engine must
  not hardcode any font. Rationale in DEPENDENCY_GRAPH.md edge E-F1.
- Golden-fixture corpus: canonical Arabic strings (joining chains, lam-alif, tashkeel
  stacks, Qur'anic-style mark clusters, mixed Arabic/Latin, Arabic-Indic + Latin
  numerals, punctuation) with expected cluster/glyph topology assertions.

**Scope out.** Any UI; Arrange derivation (P5); path layout (P7); UITextView overlay
(P4, D-104). No ground-up shaper ever (BRIEF Engineering: "no ground-up Arabic
shaper"); no presentation-form codepoints (D-103).

**Entry criteria.** P0 exit; P2 `MKModel` types available for provenance structs
(engine work may begin against P0 foundation alone; model coupling arrives late in
the phase — see graph).

**Exit criteria (gates).** G-BUILD; golden-fixture suite green across the fixture
fonts; engine-rendered lines are visually identical to `UILabel` rendering of the
same attributed strings (side-by-side harness) — first G-ARABIC checklist execution
(typing-level items); ZWJ form harvest produces correct contextual forms for all four
Joining Forms across fixture fonts; cluster map round-trips on every corpus entry.

**Deliverable artifacts.** `MKTextEngine` target; fixture corpus + comparison
harness (this harness is reused by TEST_MATRIX for every later G-ARABIC run); ADR
(shaping-capture invariants, INV-numbered); verification evidence: harness image
pairs + fixture logs.

**Workstreams.** WS-03 (+ the thin WS-09 slice that registers fixture fonts).

**Effort.** XL.

**Risks retired.** THE existential technical risk: that Core Text introspection
cannot yield a faithful, manipulable capture of shaped Arabic (market study §4 says
it can — P3 proves it in code). Also: cluster-mapping ambiguity risk, ZWJ technique
risk across real fonts, bidi run-order risk.

**Founder pause.** None.

---

### P4 — Canvas Core

**Objective.** The interactive editor: `MKCanvas` (UIScrollView + CALayer tree,
D-114) + `MKRender` (Core Graphics scene renderer, bitmap caches, degradation-ladder
hooks) + the D-104 typing model (UITextView/TextKit 2 overlay for input; committed
rendering always via MKTextEngine→MKRender so canvas and export are pixel-identical).

**Scope in.**
- Canvas host: zoom/pan, selection (tap/marquee/multi-select), transform handles
  (drag/resize/rotate), alignment guides, snapping, grouping, lock/hide, z-order —
  the full BRIEF "Canvas & projects" v1 interaction list.
- Live Text objects end-to-end: create → overlay edit (IME-correct Arabic typing) →
  commit → engine-rendered node; typing echo instrumented (<50 ms, D-115).
- Layers panel (text objects, images, shapes; arranged/marks rows appear in P5–P6)
  and numeric inspector (X/Y/W/H/rotation + style fields) on P1 components.
- Undo/redo wired to every gesture (coalesced, P2 stack); autosave triggers on
  mutation.
- Renderer snapshot discipline (D-102): render from immutable scene snapshots.
- Hit-testing geometry in MKRender; layer-property transforms for cheap 60/120 Hz
  manipulation.

**Scope out.** Arrange Mode (P5); path text (P7); asset import (P8); performance
*hardening* beyond instrumentation (P14 — but budgets are measured from P4 onward so
regressions are visible immediately).

**Entry criteria.** P2 exit (model+persistence) AND P3 exit (engine) — the two
spines join here. P1 components required for panels.

**Exit criteria (gates).** G-BUILD; G-ARABIC typing checklist on-device (native-feel
Arabic typing: shaping, tashkeel entry, mixed-run editing per BRIEF "Normal typing
behaves like a native text field"); interim G-PERF: manipulation frame time within
D-115 budgets on at least one ProMotion and one A12-class device for ≤100-node
scenes; open-project <1 s (typical); undo/redo correct across all gesture types;
save/reopen preserves everything.

**Deliverable artifacts.** `MKCanvas`, `MKRender` targets; editor scene UI; layers
panel + inspector; Instruments profiles (baseline) as verification evidence; ADR
(canvas/layer architecture, overlay-commit lifecycle).

**Workstreams.** WS-06, WS-07 (renderer bring-up portion), WS-13 (editor chrome).

**Effort.** L.

**Risks retired.** Editor-feel risk (frame-time architecture proven before feature
load grows); D-104 overlay risk (IME correctness vs pixel-identical commit); "canvas
and export disagree" risk structurally eliminated (single render path, D-118).

**Founder pause.** None.

---

### P5 — Arrange Mode

**Objective.** The differentiator's core: `MKArrange` derivation of an Arranged
Composition from a Live Text object (D-106) — Glyph Nodes, Mark Nodes, Ligature
Groups with full provenance; Source Text Backup retention; confirmed revert; per-node
independent selection/transformation on canvas; both shaped-glyph and
Unicode-letter manipulation levels with lossless level switching (BRIEF: "Store
codepoint sequences + resolved glyph/shaping-form references so switching level
loses nothing").

**Scope in.**
- Arrange derivation snapshot (glyph id, font ref, path, position, advance, joining
  state, source codepoints; marks attached with relative offsets + follow-base
  default; ligature groups flagged decomposable).
- Canvas integration: entering/leaving Arrange Mode; per-glyph selection, move,
  rotate, scale, opacity, fill, outline/stroke, shadow (BRIEF per-object style
  list); arranged compositions never auto-reflow.
- Revert-to-text with confirmation dialog («استعادة النص الأصلي» / restore original
  text) discarding arrangement (D-106).
- Unicode-letter level UI: select by source letter → highlights mapped glyph(s) via
  the P3 cluster map; edits at letter level re-derive affected clusters only.
- Layers panel rows for arranged glyph/mark nodes; inspector fields for kerning,
  tracking, baseline shift, per-node transforms (BRIEF "Per-object" list; line
  height on parent group).
- Persistence of arranged nodes (schema landed in P2; now exercised end-to-end).

**Scope out.** Join breaking + form selector UI, ligature decomposition UX, mark
detach/move UX — P6 (the P5/P6 split is: *derivation + whole-glyph manipulation* vs
*sub-structure surgery*). Path-text arrangement (P7).

**Entry criteria.** P4 exit.

**Exit criteria (gates).** G-BUILD; G-ARABIC arrange checklist: visual identity at
the derivation instant (arranged render == live render pixel-comparison via the P3
harness); every glyph/mark independently selectable/transformable; revert round-trip
restores exact source string + style; save/reopen of arranged scenes lossless;
undo/redo across derivation and per-glyph edits; level-switch loses nothing on the
golden corpus.

**Deliverable artifacts.** `MKArrange` target (derivation half); arrange UX on
canvas; extended G-ARABIC checklist section; ADR (derivation invariants + provenance
model); verification evidence: pixel-diff outputs, round-trip logs.

**Workstreams.** WS-04 (derivation + manipulation portion).

**Effort.** XL.

**Risks retired.** Derivation-fidelity risk (the "does arranged text look exactly
like the text the user had" moment); provenance-loss risk; revert-safety risk. This
is the phase Run 2 must attack hardest (see §4 below).

**Founder pause.** None.

---

### P6 — Marks / Ligatures / Forms

**Objective.** Sub-glyph surgery: tashkeel and Qur'anic-style mark
attach/detach/move/transform (D-105 semantics on canvas), ligature
decomposition/recomposition with visual-fidelity default and explicit opt-out
(D-108, BRIEF Q71), explicit join breaking with the four-form visual selector
(D-107, BRIEF: "After a break, offer a visual selector for
isolated/initial/medial/final contextual forms").

**Scope in.**
- Mark Nodes: follow-base by default (moving base carries marks), individually
  selectable/detachable/movable/transformable; re-attach.
- Ligature Groups: select-as-unit; decompose (constituents reshaped in
  joining-preserving context, placed to match original ligature bounds); opt-out to
  default spacing/forms; recompose restores stored original glyph; discretionary
  ligature toggling pre-arrangement via font features.
- Join break/restore on arranged nodes; form selector UI showing the four ZWJ-
  harvested contextual forms rendered in the object's own font.
- Edge-case handling per PRD §21 items covering: marks on ligatures, multi-mark
  stacks, breaking inside a ligature's neighborhood, fonts lacking `dlig`.

**Scope out.** Nothing new structurally — this phase completes `MKArrange`.

**Entry criteria.** P5 exit.

**Exit criteria (gates).** G-BUILD; G-ARABIC full arrange checklist: lam-alif +
discretionary ligature decompose/recompose fidelity across all fixture fonts
(pixel-diff within documented tolerance on decompose-default); mark stacks
(fatha+shadda, Qur'anic annotation marks) detach/move/reattach correctly; all four
joining forms harvest correctly for a letter sample spanning joining classes; revert
still exact after arbitrary P6 operations; persistence round-trip of every P6 state;
arranged nodes reject feature-mutation attempts with `MKError.arrangedNodeCannotReshape`
(T-ARR-NOREFLOW).

**Deliverable artifacts.** `MKArrange` completed; form-selector + ligature +
mark UX; expanded golden corpus (mark/ligature torture set); ADR (decomposition
fidelity model); verification evidence.

**Workstreams.** WS-04 (completion).

**Effort.** XL.

**Risks retired.** Ligature-fidelity risk (D-108's "looks unchanged after
decomposition" promise); mark-attachment risk across fonts with differing GPOS
quality; form-harvest robustness risk (fonts with incomplete contextual coverage —
rejected with clear errors rather than wrong glyphs).

**Founder pause.** None.

---

### P7 — Path Text

**Objective.** `MKPathText` (D-110): live, editable/reflowable RTL/bidi text on
dynamic Bézier paths (arc-length LUT, logical-reading-order pen advance, tangent rotation,
per-glyph user offset), plus arrange-on-path freezing to an Arranged Composition
with per-glyph adjustability retained (BRIEF Q72: Bézier).

**Scope in.**
- Arc-length parameterization; RTL-aware advance along path; glyph transform =
  arc point + local tangent + user offset.
- Live mode: retype → relayout; path control-point editing live-only (D-110);
  circle/arc/freeform path creation UI on canvas.
- Arrange-on-path: freeze via the P5 derivation pipeline (reuse, not fork);
  arranged path text keeps independent glyph adjustments; path ceases to be
  editable after arrangement (documented, per D-110).
- Bidi on path: Latin sub-runs remain coherent in visual order (D-109 carried onto
  the path domain).

**Scope out.** Any animation along paths (v2 seam only, BRIEF "Platform and
scope"); text-on-path for multi-line frames (single line per path in v1, PRD §9).

**Entry criteria.** P5 exit (derivation pipeline is a dependency; P6 is not — P7
can run in parallel with P6, see parallelization map).

**Exit criteria (gates).** G-BUILD; G-ARABIC path checklist: joining preserved along
curvature for canonical corpus; mixed-direction runs correct on closed and open
paths; live re-edit reflows; arrange-on-path then per-glyph adjust then
save/reopen lossless; degenerate paths (tiny radius, self-intersection) fail soft
with user-visible messaging, never crash.

**Deliverable artifacts.** `MKPathText` target; path tools UI; corpus extension
(curved fixtures); ADR (arc-length + RTL ordering model); verification evidence.

**Workstreams.** WS-05.

**Effort.** L.

**Risks retired.** RTL-on-path correctness risk (market study §3 flags this as a
differentiator vs Canva/Affinity whose path text is LTR-oriented); reuse risk
(proves the P5 derivation pipeline generalizes rather than being canvas-special).

**Founder pause.** None.

---

### P8 — Assets & Imports

**Objective.** `MKAssets` (bundled, license-clear vector shapes, Arabic ornaments,
frames, calligraphic elements, pattern backgrounds + asset browser) and the import
pipeline for raster images, SVG, and PDF as placeable assets/backgrounds (BRIEF
"Canvas & projects — v1 imports"). Photo-background gating *hooks* (free = solid
colors only, Q34) recorded on the model now, enforced in P11.

**Scope in.**
- Bundled asset collection: original or license-verified vector assets only (BRIEF:
  reusable shapes/ornaments/frames/calligraphic elements/pattern backgrounds ARE
  v1); license records captured per asset (same evidentiary discipline as fonts —
  never invent licenses).
- Import: Files/photo picker → validation → content-addressed copy into the
  document package `assets/` (P2 layout) → placeable node. SVG parsed to vector
  scene subtree where feasible; PDF placed as page-backed asset; raster placed with
  downsample-on-demand rendering.
- Background node type behavior: solid color (free) vs photo background (marks
  project "premium content present", D-119 metadata now, enforcement P11).
- Asset browser UI (P1 components); template extension seam documented only (BRIEF:
  no templates in v1, Q61–62 — minimal seam, zero UI).

**Scope out.** User *font* import (P9 — fonts are a licensing-sensitive subsystem,
not a generic asset); any preloaded Qur'anic content of any kind (Q67–68 — none,
ever, in any asset pack; asset review checklist includes an explicit "no verse
content" check).

**Entry criteria.** P4 exit (canvas placement); P2 asset store.

**Exit criteria (gates).** G-BUILD; import matrix tests (valid/corrupt/huge
raster, SVG feature subset, multi-page PDF) pass with Arabic-language error
messages; bundled assets render crisply at zoom; asset license manifest complete
with zero unverified entries; memory behavior with large rasters within P4 baseline
budgets.

**Deliverable artifacts.** `MKAssets` target + import pipeline in
`MKPersistence`/app target; asset license manifest; asset browser UI; verification
evidence.

**Workstreams.** WS-14.

**Effort.** M.

**Risks retired.** Import-robustness risk; asset-licensing risk (evidence
discipline proven on the easier asset case before the font catalog scales it);
scope-creep risk (template seam stays a seam).

**Founder pause.** None.

---

### P9 — Fonts

**Objective.** The full `MKFonts` subsystem (D-120..D-122): verified bundled
starter set, premium catalog with entitlement-gated HTTPS download, user font
import (premium), catalog UX (previews, styles, tags, favorites, search, the ten
BRIEF categories), character-coverage reporting, license metadata surfaced at
Settings → Support → Licensing (Q66), and expiry-locking hooks (D-119, enforced
P11).

**Scope in.**
- **WS-09 verification protocol executed per candidate font** (D-120 list: Amiri,
  Amiri Quran, Noto Naskh Arabic, Noto Kufi Arabic, Noto Sans Arabic, Scheherazade
  New, Lateef, Harmattan, Reem Kufi, Aref Ruqaa, Mada, Tajawal, Almarai, El
  Messiri, Markazi Text, Rakkas, Katibeh, Jomhuria, Mirza, Qahiri): capture license
  file from authoritative source, record verification evidence, include ONLY on
  pass. Amiri + Noto families are pre-verified (market study §5 [^25–^30]); all
  others are candidates until their per-repo record exists (BRIEF "Known research
  gaps"). KFGQPC/Uthmani fonts prohibited (non-commercial EULA, market study §6).
- Per-process registration (`CTFontManagerRegisterFontURLs(.process)`, D-122, amended by D-219);
  replace the P0 `MKFontProviding` stub with the real registry (engine fixtures
  now run across the *entire* verified set — G-ARABIC per-font pass).
- Premium catalog: static JSON manifest + font files on founder-controlled hosting
  (FD-04) with entitlement confirmation before download (D-121); documented
  fallback = bundle premium fonts behind entitlement if hosting unready at
  submission.
- User import (premium-only, Q64): Files picker → sfnt validation (ttf/otf/ttc/
  variable accepted; woff/woff2/bitmap-only/corrupt rejected with specific Arabic
  errors) → content-addressed copy → register → `userImported` catalog flag.
- Catalog UX: previews rendered via MKTextEngine (dogfoods the engine), category
  browse (Naskh, Ruq'ah, Thuluth, Diwani, Kufi, Maghrebi, modern display,
  Qur'anic-style, handwriting, Arabic-Latin bilingual), favorites, search, coverage
  info; licensing detail screen content.
- Commercial-foundry data-model hooks only (mechanism 4, BRIEF; FD-07 is post-v1).

**Scope out.** Entitlement *enforcement* of premium/imported font locking (P11
flips it; the lock metadata and cached-shaping display path are built now per
D-119); paid foundry licenses (FD-07, v1 ships OFL-verified only).

**Entry criteria.** P3 exit (engine renders previews); P2 (catalog store); P8
pattern for license evidence. Runs in parallel with P5–P7 (see map).

**Exit criteria (gates).** G-BUILD; every bundled font has a captured license file
+ verification record (hard gate — "No font ships without" D-120); G-ARABIC
engine-fixture pass across all bundled fonts; download flow works against FD-04
hosting or the documented fallback is activated and recorded; import validation
matrix green; category/search/favorites UX complete.

**Deliverable artifacts.** `MKFonts` target; font license evidence pack (feeds
APP_STORE_CHECKLIST); catalog UI; FD-04 decision record; ADR (registration +
locking model); verification evidence.

**Workstreams.** WS-09.

**Effort.** L.

**Risks retired.** Font-licensing legal risk (the evidence pack is the App Review
substantiation); catalog-delivery App Store policy risk (D-121 fallback ready);
per-font engine-compatibility risk (fixtures across the whole set, catching fonts
whose GPOS/GSUB quality breaks arrange assumptions *before* users do).

**Founder pause.** **FD-04** (premium font hosting location or bundle-fallback
election) — required to close P9's download exit criterion; the fallback keeps the
phase completable if the founder chooses bundling.

---

### P10 — Export

**Objective.** `MKExport` + `MKColor` (D-117, D-118): the full export matrix from
scene snapshots — free JPEG + rasterized PDF at ≤2 MP; premium opaque/transparent
PNG, SVG with preserved editability, vector print PDF with true CMYK ICC output;
presets; tiled huge-raster rendering; export history.

**Scope in.**
- `MKColor`: extended-sRGB working space, P3-aware display, sRGB document storage;
  ICC pipeline: sRGB → CMYK via `CGColorSpace(iccData:)` with relative
  colorimetric intent; profile embedded as PDF OutputIntent (D-117). Bundled
  profile per **FD-03** (candidate eciRGB/ISO Coated v2 class profiles require
  redistribution-license verification — never assumed; documented fallback: Apple
  Generic CMYK, lower fidelity). No on-screen soft-proofing in v1 (documented
  limitation; verification via external tooling in TEST_MATRIX).
- `MKExport`: single render path from immutable snapshots (never screen capture,
  D-118); tiled CGBitmapContext strips so output size is disk-limited, not
  RAM-limited (D-116); 2 MP effective gating math for free formats; presets
  (social/story/static-reel/messaging-status/wallpaper/print ratios at 2 MP
  baseline; premium custom exact dimensions); export-history records (all users)
  into the P2 metadata store.
- SVG serializer: Live Text → `<text>` (+`@font-face` embed only when license
  allows); arranged/transformed glyphs → `<g><path>` with `data-mk-*` provenance
  attributes; every outline fallback documented per-feature, never silent (Q73,
  D-118).
- PDF: vector paths + live-text runs; OFL fonts subset-embed as text, others
  outline per license switch; 300-DPI raster-asset floor for print PDF.
- Hi-res promise: 4K+ dims, effectively unlimited scaling bounded only by hardware
  memory protection with warnings + autosave near limits (Q76 — no artificial
  caps).
- Print-sharpness verification protocol: visual verification of sharp Arabic output
  at print resolution across all formats (BRIEF Export final bullet), executed as a
  G-ARABIC export section.

**Scope out.** Entitlement enforcement wiring (export calls the entitlement
protocol — still the always-premium stub until P11; the free/premium branch logic
is fully implemented and unit-tested against a fake entitlement provider now).

**Entry criteria.** P5 exit minimum (arranged content must exist to prove SVG/PDF
provenance output); P9 strongly preferred prior/parallel (license-driven
embed-vs-outline switch needs real license metadata); P6–P8 content types folded in
as they land.

**Exit criteria (gates).** G-BUILD; G-PERF export budget (4K PNG <10 s on A15;
tiled export of an oversize canvas completes without memory-ladder stage 3);
G-ARABIC export section: pixel-sharp Arabic at print resolution in every format,
SVG reopened in external tools shows editable text where promised and provenance
attributes on outlined groups; CMYK PDF inspected with external tooling shows
correct OutputIntent + plausible conversion (full fidelity QA depends on FD-03);
free-tier matrix produces exactly JPEG/rasterized-PDF ≤2 MP against the fake
free-entitlement provider.

**Deliverable artifacts.** `MKExport`, `MKColor` targets; SVG serializer spec
(documented fallback table); CMYK pipeline doc + FD-03 decision record;
export-history UI; verification evidence incl. external-tool inspection reports.

**Workstreams.** WS-08.

**Effort.** XL.

**Risks retired.** CMYK-on-iOS feasibility risk (market study §7 rated Medium-Low
and recommended deferral; founder Q75 overrides — P10 proves the pipeline or
surfaces the fallback early enough for FD-03 resolution); SVG-editability-promise
risk (Q73's "wherever feasible" made concrete as a documented fallback table);
huge-export OOM risk (tiling proven).

**Founder pause.** **FD-03** (CMYK ICC profile selection + license verification, or
Apple Generic CMYK fallback) — blocks final print-PDF export QA sign-off within
P10; pipeline work proceeds against the fallback profile meanwhile.
**RESOLVED 2026-07-19 (founder): Apple Generic CMYK elected for v1, licensed profile = v1.1 seam.**

---

### P11 — Store & Gating

**Objective.** Replace the always-premium stub with the real `MKStore`: StoreKit 2
products/purchase/restore, entitlement resolution with D-113 precedence
(lifetime > subscribed > grace > billingRetry > trial > free), app-side 7-day
first-launch trial (D-123, Keychain + iCloud KVS, clock-rollback guard), paywall UI
(on P1 design system), free-tier gating enforcement everywhere (D-119), expiry
locking of premium/imported fonts and photo backgrounds, and the flag-isolated
inert referral module (D-124, default OFF).

**Scope in.**
- Products: `net.binjamshid.makhtoot.premium.monthly` / `.annual` / `.lifetime`
  (FD-01 applied — real bundle ID confirmed); $2.99/mo, $29.99/yr, $89.99 lifetime with Apple
  storefront localization (BRIEF Monetization, mapped per D-216).
- `MKEntitlementResolver` observing `Transaction.currentEntitlements` +
  `Product.SubscriptionInfo.Status`; on-device JWS verification via
  `VerificationResult` (D-113; App Store Server API = documented seam, not v1).
- Trial: starts at FIRST APP LAUNCH, monthly+annual applicability (Q37); Keychain
  `kSecAttrAccessibleAfterFirstUnlock` persistence surviving reinstall + iCloud KVS
  mirror, earliest-timestamp-wins, monotonic clock-rollback guard (never extends);
  state machine `active(daysLeft)` → `expired`; documented app-side-trial vs Apple
  introductory-offer differences (D-123: no ASC intro offer in v1).
- Post-trial free tier exactly per Q41: full editing retained; premium functions
  blocked; free fonts + solid backgrounds + JPEG/PDF 2 MP always available.
- Expiry behavior per Q27/D-119: projects stay viewable/editable; premium +
  imported fonts lock (cached-shaping display + lock badge, re-shape blocked);
  photo backgrounds lock; export falls to free matrix until re-subscribe or
  locked content replaced (replace-or-subscribe flow).
- Paywall: price/term disclosure adjacent to CTA, visible dismiss, restore
  purchases UI mandatory, grace/billing-retry banners with Arabic messaging
  (market study §8 compliance points; exact grace durations =
  VERIFY-AT-SUBMISSION, BRIEF "Known research gaps").
- Referral: `MKStore/Referral` compiled inert behind `MKFeatureFlags.
  referralProgram` OFF; referrer-only +7-day design, abuse cap (max 4), review-risk
  memo, removal = delete folder + flag (D-124; activation requires FD-05 and is
  never a v1 blocker).
- **Stub flip:** app wiring switches `MKEntitlementProviding` from
  `AlwaysPremiumEntitlements` to the resolver; a full-app gating sweep verifies
  every premium touchpoint (fonts, photo backgrounds, premium assets, export
  formats/resolution, custom dimensions, sync toggle, font import) now enforces.
- StoreKit Testing (Xcode) config + sandbox test plan execution (G-STORE).

**Scope out.** Any server; any third-party/social login (SIWA not triggered —
account-optional design, market study §8 Guideline 4.8 analysis); referral
activation.

**Entry criteria.** P10 exit (export gating is the most intricate consumer);
P9 exit (font locking targets exist). P1 paywall route.

**Exit criteria (gates).** G-BUILD; **G-STORE full pass**: purchase each product,
restore, lifetime-overrides-subscription precedence, trial expiry transitions,
grace/billing-retry simulated states, reinstall-does-not-reset-trial, sandbox run
on device; gating sweep checklist 100% (no premium leak with entitlement=free, no
false lock with entitlement=lifetime); referral flag OFF verified inert in the
shipped configuration; automated S1 stub audit passes (Release build fails on any
non-test/non-composition-root reference to `AlwaysPremium*`/`AlwaysFree*`, D-229);
hardened-clock tests pass (wall-clock high-water mark + uptime cross-check,
D-224).

**Deliverable artifacts.** `MKStore` target; paywall + settings-subscription UI;
trial persistence design note; referral review-risk memo; gating sweep checklist
results; ADR (entitlement architecture); verification evidence: StoreKit test
logs.

**Workstreams.** WS-10.

**Effort.** L.

**Risks retired.** Entitlement-precedence bugs (single resolver + tests); trial
reset abuse (Keychain+KVS proven across reinstall); paywall App Review rejection
risk (3.1.2 compliance items built-in); free-tier leak/lock errors (sweep).

**Founder pause.** **FD-05** noted (referral stays OFF; activation would require
guideline recheck — never blocks v1). **FD-06** (Family Sharing ON/OFF per
product — irreversible) must be *decided* before App Store Connect product
creation; the decision is captured in this phase's ASC-prep notes and executed in
P15.

---

### P12 — Sync

**Objective.** `MKSync` (D-112 CloudKit clause): CKSyncEngine-based premium project
sync on the user's own iCloud account (never SIWA, Q77) — one record per project
(manifest+scene as encrypted-asset payloads, assets as CKAssets), last-writer-wins
with conflict copy «نسخة متعارضة» (conflicting copy), account-state and
quota/error handling, entitlement-gated activation.

**Scope in.**
- CKSyncEngine integration over the P2 document store; change tracking from
  autosave commits; push/pull scheduling; offline queue (BRIEF Offline: network
  allowed only for premium sync, font downloads, opt-in analytics).
- Conflict policy: last-writer-wins per project + conflict copy fallback surfaced
  in the browser.
- Account states: no-iCloud, quota-exceeded, restricted — Arabic messaging, sync
  disabled gracefully, app fully usable offline regardless.
- Entitlement gate: sync available to premium/lifetime only (BRIEF "Canvas &
  projects"); expiry pauses sync without data loss.
- iCloud/CloudKit entitlement changes to the app target (container
  `iCloud.net.binjamshid.makhtoot`, FD-01 applied) — entitlement changes are
  provisioning-sensitive, see §4.

**Scope out.** Cross-user collaboration/sharing (v2); server-side anything;
sync of the SwiftData metadata index beyond what project records imply.

**Entry criteria.** P11 exit (real entitlements gate sync); P2 document store
stable since M2.

**Exit criteria (gates).** G-BUILD; two-device sync scenario passes (create/edit/
conflict/delete propagation with conflict copy appearing); airplane-mode edit →
reconnect → converge; free-account sync correctly unavailable; G-STORE-adjacent
check: entitlement flip mid-session pauses/resumes sync correctly; no main-thread
stalls from sync activity (D-115 frame budget maintained during sync).

**Deliverable artifacts.** `MKSync` target; sync settings UI; conflict-copy UX;
ADR (record shape + conflict policy); verification evidence: two-device logs.

**Workstreams.** WS-11.

**Effort.** M.

**Risks retired.** CloudKit schema-shape risk; conflict-handling data-loss risk;
"offline-first violated by sync" risk (proven that sync is strictly additive).

**Founder pause.** None (container id finalization rides FD-01 in P15).

---

### P13 — Analytics / Settings

**Objective.** `MKAnalytics` (D-125) and the completed Settings surface: opt-in
(default OFF) anonymous aggregated font-usage analytics with CloudKit public-DB
batched upload; consent versioning; kill switch; Settings → Support → Licensing
fully populated (fonts + assets attribution, Q66); remaining settings (sync
toggle, subscription management links, privacy policy/terms links, export
defaults).

**Scope in.**
- On-device counters (fontID → usage buckets) recorded via the P0
  `MKAnalyticsRecording` seam (no-op until consent); weekly-granularity,
  bucketed-count anonymous batches, random ephemeral batch UUID, no user record
  link (D-125). Never text/projects/identifiers/font files (BRIEF Accounts/data/
  privacy).
- Consent UI: explicit opt-in switch, versioned consent record in metadata store;
  revocation stops upload + clears pending batches.
- Licensing screen: every bundled font + asset license text/attribution/foundry/
  commercial-status/coverage/source links (Q66 placement).
- Privacy-policy/terms link plumbing (documents themselves are founder-supplied
  legal content — never invented; placeholders marked for P15 checklist).

**Scope out.** Any third-party analytics SDK (prohibited by D-125); any tracking
requiring ATT (none by design).

**Entry criteria.** P9 (font catalog ids stable), P11 (settings shell carries
subscription UI), P12 (CloudKit plumbing patterns reusable).

**Exit criteria (gates).** G-BUILD; consent-off = provably zero network analytics
traffic (network log evidence); opt-in upload round-trip visible in CloudKit
public DB with anonymity properties verified against the D-125 checklist;
licensing screen content matches the P9 evidence pack 1:1.

**Deliverable artifacts.** `MKAnalytics` target; Settings/Licensing UI complete;
privacy-data-flow note (feeds App Privacy labels in P15); verification evidence.

**Workstreams.** WS-12.

**Effort.** S.

**Risks retired.** Privacy-posture risk (nutrition-label simplicity preserved,
market study §9); consent-compliance risk; attribution-completeness risk (OFL
requires shipped license text — now verifiably shipped).

**Founder pause.** None.

---

### P14 — Performance Hardening

**Objective.** Take the instrumented-but-organic performance state of P4–P13 to
green across the full device matrix: every D-115 budget, the complete D-116
memory-pressure ladder with recovery proof, degradation controls (preview
fidelity, virtualized layer lists) as engineering safeguards — never feature caps
(BRIEF Performance: no artificial caps on canvas size, glyph count, object
count).

**Scope in.**
- Profiling campaign (Instruments: Time Profiler, Allocations, Core Animation,
  Hangs) on the device matrix defined in TEST_MATRIX (ProMotion iPad Pro class,
  mid iPhone, A12-class floor device) across scenario scripts: 5,000-node open
  <3 s, sustained arrange-mode manipulation, huge-raster documents, path-text
  editing, tiled 4K+ exports.
- Memory-pressure ladder end-to-end: stage 1 (70% — drop offscreen caches +
  autosave), stage 2 (85% — half-res bitmaps, simplified shadows, banner
  «الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا» / memory nearly full — autosaved),
  stage 3 (critical — synchronous autosave + journal flush); kill-under-pressure →
  relaunch → exact restore (BRIEF: no-loss recovery).
- Optimization backlog burn-down: bitmap-cache tuning, layer virtualization for
  large layer panels, snapshot diffing, autosave I/O batching.
- Metal seam decision point: adopt ONLY if a D-115 gate cannot be met with Core
  Graphics (D-114); adoption would be an ADR + founder-visible scope note.
- Final visual-polish pass on FD-02-approved aesthetic.

**Scope out.** New features (hard freeze — only gate-driven changes); artificial
limits of any kind.

**Entry criteria.** P10 exit mandatory (export perf is gated here); realistically
after P13 so the profiled build is feature-complete.

**Exit criteria (gates).** **G-PERF full pass** on the whole device matrix, every
D-115 number, with archived Instruments traces as evidence; memory-ladder
scenario passes 10/10 runs with zero data loss; **G-ARABIC regression** full
checklist re-run on the hardened build (optimizations must not perturb shaping
fidelity); G-BUILD in Release configuration.

**Deliverable artifacts.** Performance report (per-budget, per-device, evidence-
linked); memory-ladder test logs; optimization ADRs; updated degradation
documentation.

**Workstreams.** WS-07 (hardening portion).

**Effort.** L.

**Risks retired.** "Beautiful but slow" ship risk; OOM-crash reputation risk on
older devices; the residual D-114 renderer-choice risk (Core Graphics
sufficiency, or a controlled Metal escalation with evidence).

**Founder pause.** **FD-02** final approval of the baseline aesthetic (blocks
visual-polish completion, not engineering hardening).

---

### P15 — Distribution

**Objective.** Everything between a green build and a submitted app: real
identifiers (FD-01), App Store Connect configuration, product setup with FD-06
Family Sharing decisions, metadata/screenshots (Arabic), privacy labels,
territory eligibility, archive/upload, and submission — automated wherever
technically possible (Xcode, CLI, Simulator, Chrome control) pausing only for
founder credentials/legal acceptance/purchases/provisioning/final visual approval
(Q56, Q84).

**Scope in.**
- FD-01 execution: real bundle id confirmed as `net.binjamshid.makhtoot`; placeholder
  sweep (former `com.example.makhtoot` → `net.binjamshid.makhtoot`) applied across bundle id, UTI, IAP ids, CloudKit
  container, entitlements; full regression build + G-STORE re-run after the
  sweep.
- App Store Connect: app record, IAPs (`Makhtoot Premium` group; monthly/annual/
  lifetime with FD-06 Family Sharing set per product — irreversible), pricing
  ($2.99/$29.99/$89.99 base with Apple localization), sandbox testers.
- APP_STORE_CHECKLIST.md executed line-by-line (see §3 below): metadata, Arabic
  screenshots per device class, privacy nutrition labels from the P13 data-flow
  note, export-compliance answer, territory eligibility checklist (Q46: all
  territories needing no extra legal documentation/local registration),
  review notes (incl. demo project, referral-flag disclosure posture,
  VERIFY-AT-SUBMISSION items resolved: current grace-period durations, current
  referral guideline text — recorded even though flag is OFF).
- Archive + upload via `xcodebuild archive`/`-exportArchive` + upload tooling;
  TestFlight pass; submission.
- Founder-credential pauses orchestrated as explicit checkpoints (Apple ID/ASC
  login, agreements/tax/banking acceptance, provisioning approval, final visual
  approval).

**Scope out.** Any feature change; referral activation (FD-05 stays OFF);
post-submission marketing.

**Entry criteria.** P14 exit (all gates green); FD-01, FD-06 decided; privacy
policy + terms documents supplied by founder (legal content is never invented).

**Exit criteria (gates).** The **Definition of Distribution-Ready** (§3) fully
satisfied; submission completed in App Store Connect; codebase-memory closes the
run with final verification evidence and the submission record.

**Deliverable artifacts.** Signed archive; ASC configuration; completed
APP_STORE_CHECKLIST.md with evidence links; submission confirmation; release
ADR.

**Workstreams.** WS-15.

**Effort.** M.

**Risks retired.** Placeholder-leak risk (sweep + regression); irreversible
ASC-setting risk (FD-06 decided consciously); review-rejection risk (checklist
addresses 3.1.2 paywall items, restore purchases, privacy labels, font-license
substantiation pack ready).

**Founder pause.** **FD-01** (identifiers/team/repo — hard block), **FD-06**
(Family Sharing — hard block before IAP creation); credential/legal/provisioning/
final-visual-approval checkpoints per Q56/Q84.

---

## 3. Definition of Distribution-Ready

Makhtoot is Distribution-Ready when every item below is true, with evidence
recorded in codebase memory and the corresponding APP_STORE_CHECKLIST.md line
checked. This section defines the bar; APP_STORE_CHECKLIST.md is the executable
line-item instrument.

**Gates (all four, on the release candidate build):**
1. G-BUILD: Release-configuration archive builds clean from a tagged commit.
2. G-PERF: full D-115 matrix green on all device classes; archived traces.
3. G-STORE: full sandbox suite green *after* the FD-01 identifier sweep (product
   ids change ⇒ suite re-run is mandatory).
4. G-ARABIC: full manual checklist green on the release candidate, including
   arrange/marks/ligatures/path/export sections and per-font passes.

**Identity & configuration:**
5. FD-01 applied everywhere; zero occurrences of the former placeholder
   `com.example.makhtoot` (or derived placeholders) in the shipped product,
   entitlements, or ASC config. Real bundle ID `net.binjamshid.makhtoot` confirmed.
6. FD-06 Family Sharing recorded per product and configured exactly as decided.
7. `MKFeatureFlags.referralProgram` verified OFF in the release build; referral
   code inert (D-124); review-risk memo on file in case of reviewer inquiry.

**Legal & licensing (never invented — evidence or absence):**
8. Every bundled font: captured license file + WS-09 verification record; OFL
   attribution text shipped and reachable at Settings → Support → Licensing.
9. Every bundled asset: license record on file (P8 manifest).
10. CMYK ICC profile: FD-03 resolved — either verified-redistributable profile
    with license evidence, or Apple Generic CMYK fallback shipped with the
    documented fidelity limitation.
11. Privacy policy + Terms/EULA: founder-supplied, linked in-app and in ASC
    metadata (3.1.2 requirement).
12. No Qur'anic preloaded content of any kind present in any bundle or asset
    (Q67–68 audit line).

**App Store Connect & compliance:**
13. IAPs live in sandbox with correct pricing/localization; paywall discloses
    title/length/price adjacent to CTA; restore purchases reachable; dismissible
    paywall; no dark patterns (market study §8 3.1.2 items).
14. App-side trial vs Apple intro-offer difference documented in review notes
    (D-123: no ASC introductory offer configured in v1).
15. Privacy nutrition labels match the P13 data-flow note (effectively: no data
    collection unless analytics opt-in, which is anonymous, non-tracking, no
    ATT).
16. Territory list per Q46 eligibility checklist executed at submission time.
17. VERIFY-AT-SUBMISSION items resolved and dated: current Apple grace-period
    durations reflected in UX copy; current App Review Guidelines re-checked for
    referral posture (even though OFF) and for font-catalog download policy
    (D-121).
18. Arabic metadata: name (مخطوط / Makhtoot), subtitle, description, keywords,
    screenshots (iPhone + iPad, RTL UI shown truthfully), what's-new text.
19. Export compliance (encryption) answered; app uses only exempt/standard
    encryption (HTTPS, Keychain, CloudKit).
20. TestFlight build installed and smoke-tested on physical iPhone + iPad by the
    founder; final visual approval recorded (Q84 checkpoint).

---

## 4. Run-2 Adversarial-Review Handoff

Run 2's mandate: attack this plan and the sibling deliverables before Run 3
builds. Ordered by expected yield, with the specific claims to falsify:

1. **Arabic shaping correctness during manual movement (P5).** Attack D-106's
   claim that a derivation snapshot preserves visual identity: fonts where GPOS
   mark anchoring differs from captured positions after transform; cursive
   overlap seams when a medial glyph is moved (joins are *visually* continuous
   strokes — does translation expose seams the plan under-specifies?); scale
   applied to a glyph inside a joined word. Falsify: "arranged render ==
   live render at derivation instant" across the full D-120 font list, not just
   Amiri/Noto.
2. **Base-mark dynamic attachment (P5–P6).** Follow-base under rotation and
   non-uniform scale: is the mark offset transformed in base-local space or
   canvas space? Multi-mark stacks (shadda+fatha) reordering; marks on ligature
   members after decomposition; detach → base moves → re-attach semantics.
   D-105's "recorded relative offset" is under-specified for rotated bases —
   press hard here.
3. **Ligature decomposition/recomposition (P6).** D-108's fidelity default:
   fonts without clean constituent glyphs for a ligature; nested/overlapping
   discretionary ligatures; decompose → transform constituent → recompose
   (recomposition restores "the stored original glyph" — what happens to the
   constituent's edits? Data-loss confirmation required?); `dlig` toggling after
   arrangement (should be impossible — verify the state machine forbids it).
4. **Bidi runs (P3, P7).** Level switching on mixed Arabic/Latin when the user
   letter-edits inside an LTR sub-run of an arranged RTL paragraph; neutral
   punctuation at run boundaries after per-glyph movement (visual order is
   frozen). Note: partial re-derivation of a sub-run is impossible by design
   (INV-1/R-6.11 — any content edit reverts the whole composition back to
   flow text), so the attack target here is re-scoped away from "does
   bidiLevel retention survive partial re-derivation" to the
   selection/path-text findings: letter-level range selection spanning more
   than one bidi run, and numerals (Arabic-Indic vs Latin) run assignment on
   path text.
5. **Editable-SVG promise vs font licenses (P10).** Q73 says "fully editable
   wherever feasible"; D-118 embeds `@font-face` "only when license allows."
   Attack the matrix: OFL Reserved Font Name implications for subsetted embeds;
   user-imported fonts (unknown license — must never embed; is the fallback
   documented per-feature?); premium catalog fonts post-expiry appearing in
   old exports' fonts. Verify the fallback table is exhaustive and the UI never
   promises editability it can't deliver.
6. **CMYK feasibility on iOS (P10).** Market study §7 rated this Medium-Low and
   FOUNDATION D-117 keeps it in v1 per Q75. Attack: `CGColorSpace(iccData:)`
   conversion-intent behavior actually honored by CG PDF context? OutputIntent
   embedding correctness? Verify the external-tooling verification protocol in
   TEST_MATRIX is strong enough to catch a silently-wrong conversion, and that
   the FD-03 fallback path (Apple Generic CMYK) is honestly characterized.
7. **Free-tier entitlement enforcement (P11).** Hunt gating leaks: premium font
   used pre-expiry renders via cached shaping post-expiry (D-119) — can the
   user *duplicate* the project and keep editing premium content? Export of a
   free project that *references* a locked font in an unused layer? 2 MP
   "effective" cap math vs aspect-ratio games? Trial state via device-clock
   manipulation beyond simple rollback (timezone hops, NTP-off)?
8. **iCloud entitlement changes (P12, P15).** The app gains CloudKit + KVS
   entitlements mid-program and swaps container ids at FD-01: attack the
   provisioning/regression story — does the plan re-run G-STORE *and* sync
   scenarios after the identifier sweep? (Plan says yes for G-STORE; Run 2
   should force a sync re-verification line into APP_STORE_CHECKLIST.)
9. **Memory-pressure autosave (P2, P14).** D-116 stage 3 does synchronous
   autosave on the critical event — attack: is a 5,000-node scene.json write
   completable inside the jetsam window? Should the journal (not full scene)
   be the critical-path artifact? Kill during the atomic rename; pressure
   during export tiling (two memory consumers).
10. **Offline mode (P12–P13).** Verify no feature silently degrades offline:
    font catalog browse with no network (cached manifest?); paywall render
    offline (StoreKit products unavailable — does the free tier remain fully
    usable, Q41?); consent toggled on with no network (queued, not lost?).
11. **Trial/lifetime/subscription precedence (P11).** D-113 order vs reality:
    lifetime purchased *during* active subscription (double-payment messaging?);
    subscription in grace while trial timestamps still valid; revoked/refunded
    transactions demoting entitlement mid-session with an arranged premium-font
    document open.
12. **App Review risk of the disabled referral code (P11, P15).** The referral
    module ships compiled-but-inert (D-124). Attack: does inert code containing
    "extend trial" strings risk reviewer static-analysis questions? Should
    review notes proactively disclose, or should the module be excluded from
    the release build entirely (compile-time flag vs runtime flag)? Run 2
    should recommend a definitive posture; current plan ships it compiled with
    runtime flag OFF + memo — challenge that. **Resolved:** D-225 adopts
    compile-time exclusion from Release (`#if MAKHTOOT_REFERRAL_ENABLED`,
    Debug/internal only) — **FOUNDER-CONFIRMED 2026-07-17**.

Additional standing instruction to Run 2: verify every D-### citation in PLAN.md
and DEPENDENCY_GRAPH.md against FOUNDATION.md verbatim, and flag any deliverable
statement that silently extends a locked decision.

---

## 5. Run-3 Execution Model

Run 3 implements the workstream packets.

**Packet execution loop (per WS-xx packet, per phase slice):**
1. **Brief-in.** Record the FOUNDATION decisions, PLAN phase, entry criteria,
   and applicable exit-gate checks for each packet (`AGENT_TASK_PACKETS/WS-xx-*.md`).
   Use codebase-memory MCP (`get_architecture`, `search_graph`) to attach the
   current repository context.
2. **Implementation.** Follow the packet and FOUNDATION §12. The rules cover no invented legal facts; placeholder ids
   untouched; module-dependency edges only as declared; Arabic strings with
   Latin gloss on first use; requirement ids cited in code-adjacent docs.
3. **Evidence-out.** Record the following using the codebase-memory MCP conventions
   (Q58): (a) **ADRs** (`manage_adr`) for every architecturally significant
   choice, numbered per-phase, referencing the D-###/FD-0x they refine — never
   contradicting FOUNDATION; (b) an **implementation log** entry per work session: scope touched, decisions
   taken, deviations proposed (never silently applied); (c) **verification
   evidence**: build transcripts, test output, Instruments traces, pixel-diff
   artifacts, checklist scans — linked to the phase-exit gate items they
   satisfy. Escalate any contradiction with FOUNDATION for gate review.
4. **Gate review.** Review phase exits independently of implementation. Re-run
   G-BUILD commands and sample G-ARABIC checklist items. Accept only items
   backed by evidence, then record the milestone in the implementation log and re-index
   (`index_repository`/`detect_changes`).

**Concurrency.** Schedule packets using the DEPENDENCY_GRAPH.md
parallelization map (e.g., after M4: WS-04 (P5) ∥ WS-09 (P9) ∥ WS-14 (P8); after
M5: WS-05 (P7) ∥ WS-04 (P6) continuation). Assign one writer per packet slice
and keep concurrent file ownership disjoint at module boundaries (D-101).
Route cross-packet interface changes through gate review as an ADR before
either side proceeds.

**Founder approval.** Work may proceed on code, tests, and refactors within
FOUNDATION decisions. Scheduled stub flips, performance optimization within
D-114/D-115, builds and simulator/device runs may proceed. In-app Arabic copy
may proceed with founder review flagged. TestFlight internal operations may
proceed once credentials exist. Pause for explicit founder input at these
checkpoints.

- **FD-01** — real bundle id/team/repo (P15 entry; also `git init`/naming is
  founder-performed per BRIEF Product identity).
- **FD-02** — baseline-aesthetic approval/edit (P14 visual polish).
- **FD-03** — CMYK ICC profile election + license verification outcome (P10 QA
  sign-off).
- **FD-04** — premium font hosting location or bundle-fallback election (P9).
- **FD-05** — referral activation (only if ever requested; default never).
- **FD-06** — Family Sharing per product (before ASC IAP creation, P15).
- **FD-07** — commercial foundry budget/process (post-v1 only).
- Plus the Q56/Q84 operational checkpoints: founder credentials (Apple ID, ASC),
  legal acceptances (agreements, privacy policy/terms supply), license
  purchases, provisioning approvals, and final visual approval before submission.
Nothing else pauses. Anything not on this list that *feels* founder-worthy is
recorded as a proposed decision in the implementation log and surfaced at the
next gate review — work continues on the documented default.

**Failure handling.** A packet that cannot meet its gate emits a blocking report
(evidence of the failure, options, FOUNDATION constraints involved). Use gate
review to narrow scope within FOUNDATION or invoke a documented fallback (e.g.,
D-121 bundle fallback, D-117 Generic-CMYK fallback, D-114 Metal seam). Prepare a
founder decision memo if a locked decision itself is untenable.

---

## 6. Traceability

| PLAN.md element | BRIEF.md bullet(s) | FOUNDATION id(s) |
|---|---|---|
| Gate vocabulary (G-BUILD/PERF/STORE/ARABIC) | Engineering — Gates (Q59) | D-115, §11 TEST_MATRIX ref |
| No calendar dates, S/M/L/XL sizing | Run 1 deliverables (plan character) | §11 phase list |
| P0 scaffold, tooling limits | Engineering (Q47, Q49) | D-100, D-101, D-102 |
| P1 design system, RTL-first, themeable | Product identity (themeable layer); Platform (Arabic-only RTL) | D-126, FD-02 |
| P1 accessibility non-scope | Platform and scope (Q53) | — |
| P2 scene graph/persistence/undo/autosave/recovery | Canvas & projects; Performance (autosave, no-loss recovery) | D-111, D-112 |
| P3 shaping capture, cluster map, bidi, forms, no shaper | Arabic text & glyph engine (typing, both levels, joining) | D-103..D-105, D-107, D-109 |
| P3 fixture fonts pre-verified | Fonts & licensing (market study §5 verified: Amiri, Noto) | D-120 |
| P4 canvas interactions, typing overlay, budgets | Canvas & projects; Performance | D-104, D-114, D-115, D-102 |
| P5 arrange derivation, revert, two levels, per-object styles | Arabic engine (Arrange Mode; never auto-reflow; per-object list) | D-106, D-111 |
| P6 marks, ligatures, join break + form selector | Arabic engine (tashkeel Q11 full; ligatures Q71; joining) | D-105, D-107, D-108 |
| P7 Bézier path text, arrange-on-path | Arabic engine (curved text, Q72) | D-110 |
| P8 assets in v1, imports, no templates, no Qur'anic content | Platform and scope (Q61–62, Q67–68); Canvas (v1 imports) | §2 MKAssets, D-119 |
| P9 four font mechanisms, categories, licensing screen, verification | Fonts & licensing (all bullets, Q64, Q66) | D-120..D-122, FD-04 |
| P10 export matrix, SVG editability, CMYK, presets, hi-res | Export (all bullets, Q73, Q75, Q76) | D-117..D-119, FD-03 |
| P11 pricing, trial Q37, free tier Q41, expiry Q27, referral OFF Q78, StoreKit scope | Monetization (all bullets) | D-113, D-119, D-123, D-124, D-224, D-225, D-228, D-229, FD-05, FD-06 |
| P12 CloudKit premium sync, not SIWA (Q77), offline-first | Accounts/data/privacy; Platform (offline) | D-112 (sync clause), §2 MKSync |
| P13 opt-in anonymous analytics (Q43, Q79), no ads, licensing screen | Accounts/data/privacy; Fonts (Q66) | D-125 |
| P14 budgets, memory ladder, soft degradation not caps | Performance (all bullets) | D-114..D-116, FD-02 |
| P15 automation + founder pauses (Q56, Q84), territories Q46 | Engineering (Distribution); Accounts (territories) | FD-01, FD-06, §0 identifiers |
| Definition of Distribution-Ready | Run 1 deliverables (APP_STORE_CHECKLIST.md); Known research gaps (VERIFY-AT-SUBMISSION) | §12 conventions, D-121, D-123 |
| Run-2 handoff attack list | Arabic engine bullets; Export Q73/Q75; Monetization; Performance; Known research gaps | D-105..D-109, D-113, D-116..D-119, D-123, D-124 |
| Run-3 model, MCP conventions, pause boundary | Engineering (Q58; Q56/Q84 pauses); Fonts (never invent licenses) | §10 FD table, §12 conventions |
| Never invent legal facts | Fonts & licensing; Known research gaps | §12 |
