# Makhtoot (مخطوط) — TEST_MATRIX.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.
## Run-1 Phase-by-Phase Verification Matrix (for Run-3 agents and the founder)

Conforms to `FOUNDATION.md` (D-100…D-126, §11 phases P0–P15) and `_input/BRIEF.md`
(locked quality gates, Q59). If anything here contradicts FOUNDATION.md, FOUNDATION.md
wins. Test IDs use the canonical `T-<area>-<n>` scheme (FOUNDATION §12). Verification
evidence for every executed gate test is recorded in the codebase-memory MCP as
per-phase verification records (BRIEF "Engineering", Q58).

---

## 1. How to use this matrix

### 1.1 Gate types (BRIEF Q59 — the only v1 gates)

| Gate type | Meaning | Who signs off |
|---|---|---|
| **BUILD** | `xcodebuild` build/test success, archive success, strict-concurrency clean | Run-3 agent (automated) |
| **PERF** | Quantitative D-115 budget measured on the device matrix (§2) with the prescribed instrument | Run-3 agent runs; founder countersigns P14 |
| **STOREKIT** | StoreKit 2 scenario passes in `.storekit`-file testing AND (where marked) sandbox | Run-3 agent; founder countersigns sandbox subset |
| **MANUAL-ARABIC** | Item on the Manual Arabic-Script Checklist (§7) visually verified by a human Arabic reader | Founder (or delegated Arabic-literate reviewer) |
| **FUNCTIONAL-supporting** | Supporting functional test. Not itself a release gate, but listed phase-exit FUNCTIONAL tests must pass before dependent gates are attempted | Run-3 agent |

Formal accessibility audits, UI-automation suites, and snapshot suites are **not** v1
gates (BRIEF, founder Q53/Q59). See §22 Gap Statement.

### 1.2 Automation levels

| Level | Meaning |
|---|---|
| `xcodebuild-testable` | Runs as an XCTest (unit/integration) in `MakhtootKit` or app target via `xcodebuild test` |
| `simulator-scriptable` | Needs a booted simulator/device and scripted driving (`xcrun simctl`, StoreKit Transaction Manager, network conditioner, `simctl status_bar`/push/memory tooling), possibly with a debug-only automation hook in the app |
| `manual-visual` | A human looks at the screen or the exported artifact. All MANUAL-ARABIC items are this level |

### 1.3 Test entry format

Every test is written as:

> **T-XXX-n · Title** — Phase Pk · Gate TYPE · Automation level
> **Purpose** … **Preconditions/Fixtures** … **Steps** … **Expected** …

### 1.4 Standard fixture projects (created once, stored under `TestFixtures/`)

| Fixture ID | Contents |
|---|---|
| `FIX-EMPTY` | New 1080×1080 project, default background, zero nodes |
| `FIX-TYPICAL` | 100 nodes: 20 Live Text objects (Arabic), 2 Arranged Compositions, 1 Path Text, 30 shapes/ornaments, 2 images, remainder groups — the D-115 "typical" open target |
| `FIX-HEAVY` | 5 000 nodes generated programmatically (mixed glyph nodes, shapes, marks) — the D-115 "heavy" open target |
| `FIX-ARABIC` | One project containing every fixture string from §7 as separate Live Text objects, Amiri 48 pt |
| `FIX-BIDI` | The §7.8 mixed-direction strings as Live Text objects |
| `FIX-PREMIUM` | Project using one premium-catalog font, one user-imported font, one photo background — used by expiry/gating tests |
| `FIX-PATH` | Three Path Text objects: circle, open cubic Bézier S-curve, closed freeform loop |
| `FIX-4K` | 4096×4096 project with 300 nodes incl. one Arranged Composition and one photo — export-budget target |
| `FIX-FONTS-BAD` | Corrupt .ttf (truncated tables), .woff2 file, bitmap-only sfnt, 0-byte file — import-rejection corpus |

### 1.5 Canonical os_signpost registry (required instrumentation, subsystem `net.binjamshid.makhtoot.perf`)

| Signpost name | Interval | Emitted by |
|---|---|---|
| `frame.manipulate` | begin/end per render pass during gesture manipulation | `MKCanvas`/`MKRender` |
| `typing.echo` | keystroke commit → engine-rendered glyph visible | `MKCanvas` text overlay + `MKRender` |
| `doc.open` | open request → first interactive frame | `MKPersistence` + app target |
| `autosave.incremental` | mutation-debounce fire → atomic rename complete | `MKPersistence` |
| `export.render` | export confirmed → file written (sub-intervals `export.tile` per strip) | `MKExport` |
| `arrange.derive` | Arrange Mode entry → Arranged Composition ready | `MKArrange` |
| `shape.line` | attributed-string build → glyph geometry extracted | `MKTextEngine` |
| `memory.stage` | event (payload: stage 1/2/3, % used) | `MKFoundation` monitor |

These names are load-bearing: PERF tests reference them; agents must not rename them
without updating this file.

---

## 2. Device matrix (PERF gates)

| ID | Device | Role | Display | Notes |
|---|---|---|---|---|
| `DEV-A12` | iPhone XS or XR (A12) | **Floor** device for ≤16.6 ms frame gate | 60 Hz | Oldest iOS 18-capable iPhone class |
| `DEV-A15` | iPhone 13 (or SE 3rd gen, A15) | Mid-tier reference; export budget device | 60 Hz | D-115 "4K PNG <10 s on A15" is measured HERE |
| `DEV-M` | iPad Pro 11" M1/M2/M4 | iPad adaptive-layout + big-canvas reference | 120 Hz ProMotion | Also the iPad ProMotion frame-gate device |
| `DEV-PRO` | iPhone 15/16 Pro (ProMotion) | ≤8.3 ms frame gate device | 120 Hz ProMotion | |
| `SIM` | iOS 18 Simulator (any Mac) | FUNCTIONAL / STOREKIT-file / sync scenarios | n/a | **Never** used for PERF verdicts |

Rules:
- Every PERF verdict states device ID, iOS build, app build hash, measurement tool, N runs (minimum 5, report median + worst).
- Frame-time gates: `frame.manipulate` interval distribution via Instruments (os_signpost + Hitches template); pass = P95 ≤ budget during a scripted 10-second manipulation session.
- MetricKit (`MXMetricPayload`: `applicationLaunchMetrics`, `animationMetrics.scrollHitchTimeRatio`, `memoryMetrics.peakMemoryUsage`) is collected in TestFlight builds as field corroboration, not as the primary gate instrument.

---

## 3. T-BLD — Build & toolchain gates (P0, re-run every phase)

**T-BLD-1 · Clean build, app target** — Phase P0 · Gate BUILD · xcodebuild-testable
**Purpose** The one non-negotiable gate: the project builds. **Preconditions** Clean checkout, Xcode 16.x, no derived data. **Steps** 1. `xcodebuild -scheme Makhtoot -destination 'generic/platform=iOS Simulator' clean build`. **Expected** Exit 0; zero errors; warnings triaged (new warnings vs. previous phase must be justified in the phase log).

**T-BLD-2 · MakhtootKit package tests** — Phase P0 · Gate BUILD · xcodebuild-testable
**Purpose** All engine-module unit tests pass headlessly. **Steps** 1. `xcodebuild test -scheme Makhtoot -destination 'platform=iOS Simulator,name=iPhone 16'` (runs `MakhtootKit` test bundles). **Expected** 100 % pass; no skipped gate-referenced tests.

**T-BLD-3 · Swift 6 strict concurrency clean** — Phase P0 · Gate BUILD · xcodebuild-testable
**Purpose** D-100 mandates Swift 6 language mode; concurrency violations are build errors, not warnings. **Steps** 1. Verify `SWIFT_VERSION = 6.0` and strict concurrency = complete in all targets (grep project + Package.swift). 2. Build. **Expected** No `@unchecked Sendable` without an ADR-referenced justification comment; build clean.

**T-BLD-4 · No third-party dependencies** — Phase P0 · Gate BUILD · xcodebuild-testable
**Purpose** D-101: v1 has zero third-party packages. **Steps** 1. Inspect `Package.swift` dependencies and project package references. **Expected** Only the local `MakhtootKit` package; empty external dependency list.

**T-BLD-5 · Arabic-only localization configuration** — Phase P0 · Gate BUILD · xcodebuild-testable
**Purpose** D-100: `ar` is the only localization and the development region. **Steps** 1. Read project settings (`knownRegions`, `developmentRegion`). 2. Launch app in simulator. **Expected** `ar` present, development region `ar`; UI renders RTL (verify `UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft` via debug hook).

**T-BLD-6 · Release archive builds** — Phase P15 · Gate BUILD · xcodebuild-testable
**Purpose** Distribution phase gate: archivable with release configuration. **Preconditions** FD-01 applied: real bundle ID `net.binjamshid.makhtoot` confirmed; BLOCKED-FD-01 resolved. **Steps** 1. `xcodebuild archive -scheme Makhtoot -configuration Release`. **Expected** Archive succeeds; bitcode/entitlement warnings zero; placeholder bundle id flagged if still present.

**T-BLD-7 · Module dependency direction check** — Phase P0 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** FOUNDATION §2 dependency table is enforced (e.g., `MKModel` must not import `MKRender`). **Steps** 1. Script greps `import MK*` statements per target and diffs against the §2 table. **Expected** No edge outside the table; violations fail the phase.

**T-BLD-8 · S1 entitlement-stub audit (DEBUG-gated, no stray references)** — Phase P0 · Gate BUILD · xcodebuild-testable
**Purpose** D-229(3): `AlwaysPremium*`/`AlwaysFree*` S1 entitlement-resolver stub types exist for engineering convenience but must never ship live or leak into non-test code; directly relevant at P11 Store & Gating. **Steps** 1. Verify the stub type declarations are wrapped `#if DEBUG` (grep + a Release-configuration compile check that a file referencing them fails to build in Release). 2. Run a source-audit script that greps the full source tree for `AlwaysPremium`/`AlwaysFree` references and asserts every hit is inside a test target OR the composition-root file that wires the debug-only override. **Expected** A Release build referencing a stub fails to compile (proves the `#if DEBUG` gate is real, not just a comment); the source audit finds zero non-test/non-composition-root references; the audit script re-runs as part of the P0 build-gate re-run at every phase exit.

---

## 4. T-MDL — Scene model & persistence (P2)

**T-MDL-1 · Scene graph Codable round trip** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-111/D-112: `scene.json` losslessly encodes every node case. **Fixtures** Programmatic scene containing every `MKNode` case (`group`, `liveText`, `pathText`, `arranged`, `shape`, `image`, `background`) with non-default transform/style/lock/hidden values, plus an Arranged child set (glyph/mark/ligature nodes with full provenance). **Steps** 1. Encode → decode → encode. **Expected** Value equality after round trip; byte-stable second encode (deterministic key order).

**T-MDL-2 · schemaVersion presence and migration hook** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** Migration path exists from day one. **Steps** 1. Decode a fixture `scene.json` with `schemaVersion: 1`. 2. Decode a synthetic `schemaVersion: 0` and `schemaVersion: 999` document. **Expected** v1 loads; v0 runs registered migration (or explicit "unsupported" error); v999 fails with a typed `futureSchema` error surfaced as an Arabic user-facing message, never a crash or silent data loss.

**T-MDL-3 · File-package structure** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-112 layout: `manifest.json`, `scene.json`, `assets/`, `backups/`, `thumbnail.png` inside `.makhtoot`. **Steps** 1. Create + save a project with one imported image. 2. Enumerate package contents. **Expected** Exactly the D-112 layout; imported asset content-addressed (filename = content hash); manifest ids match scene ids.

**T-MDL-4 · Atomic autosave (write-temp + rename)** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** A crash mid-write can never corrupt the previous good save. **Steps** 1. Save fixture project. 2. In a test harness, interpose the file coordinator to kill the process (or throw) after temp write but before rename; relaunch persistence layer and open. **Expected** Previous intact version loads; orphan temp files cleaned on next save.

**T-MDL-5 · Debounced autosave timing** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-112: autosave ≤2 s after last mutation; immediate on background/memory-pressure. **Steps** 1. Mutate scene; assert save fires within 2 s (test clock). 2. Simulate `didEnterBackground` and a stage-1 memory event; assert immediate save. **Expected** Both immediate paths flush synchronously-safe (no main-thread file IO — see T-PRF-8).

**T-MDL-6 · Crash-recovery journal replay** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-112/D-116: last un-flushed command batch is journaled and replayed. **Steps** 1. Apply 10 mutations; force-quit the persistence layer before debounce fires (journal present, scene.json stale). 2. Reopen. **Expected** All 10 mutations restored from journal; journal cleared after successful integration; a corrupted journal is skipped with the last good save loaded and a non-blocking Arabic notice.

**T-MDL-7 · Undo/redo command-stack integrity** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-112: inverse-operation stack over the value-type scene; gesture coalescing. **Steps** 1. Scripted sequence: add node → move (simulated 60-event drag) → recolor → group → delete → undo ×5 → redo ×5. **Expected** State after undo ×5 equals initial scene (value equality); redo ×5 equals final; the 60-event drag is ONE undo step; undo stack survives autosave (autosave never truncates it).

**T-MDL-8 · SwiftData metadata index contains no scene data** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-112: SwiftData holds metadata ONLY (project list, folders, names, search text, export history, font catalog state, analytics counters, trial/consent records) — never the scene graph. **Steps** 1. Create/save projects; inspect the SwiftData store entities. **Expected** No entity/attribute stores node trees, glyph data, or asset bytes; deleting the SwiftData store and relaunching re-indexes from `.makhtoot` packages without project loss.

**T-MDL-9 · Project browser operations** — Phase P2 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF canvas/projects bullet: duplicate, folders, search, export history for all users. **Steps** 1. Create 3 projects in 2 folders; duplicate one; rename; search by Arabic name "تجربة"; export one (any format) and open export history. **Expected** Duplicate is deep copy (new ids, shared nothing); Arabic search matches with and without tashkeel in the query; export history row records format/dimensions/date.

**T-MDL-10 · Document open under renamed/moved package** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** Robustness: ids live in manifest, not path. **Steps** 1. Save project; move/rename the `.makhtoot` package on disk; reopen via browser refresh. **Expected** Opens fine; metadata index heals the path; no duplicate entries.

**T-MDL-11 · Multi-file save-order crash window (scene→manifest→journal-truncate)** — Phase P2 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-223/D-112: the crash-window ordering across the three save artifacts — scene.json write → manifest.json write → journal truncate — must never leave a state where a stale journal is replayed against a newer scene and double-applies already-persisted mutations. **Steps** 1. Apply a mutation batch. 2. Interpose the file coordinator to kill the process at each of three windows: (a) after scene.json write, before manifest.json write; (b) after manifest.json write, before journal truncate; (c) mid journal-truncate. 3. Relaunch the persistence layer and open the project at each window. **Expected** At every window the reopened scene reflects a consistent state (no partial manifest, no dangling asset references); the journal records a `baseRev` at journal-open time, and on replay the persistence layer SKIPS (does not double-apply) any journal entries whose effect is already reflected in the loaded scene.json's revision — verified by asserting each mutation's final value appears exactly once after recovery in all three crash windows.

---

## 5. T-TXT — Text engine: shaping capture (P3)

**T-TXT-1 · Shaping capture parity with CTLine drawing** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-103: engine-extracted glyph ids/positions/advances must exactly match what Core Text would draw. **Fixtures** String «بسم الله الرحمن الرحيم», Amiri 48 pt. **Steps** 1. Shape via `CTTypesetter`→`CTLine`→runs; capture via `CTRunGetGlyphs/Positions/Advances/StringIndices`. 2. Render (a) `CTLineDraw` and (b) MKRender from captured geometry into two bitmaps. **Expected** Bitmap diff = 0 differing pixels (identical context state); glyph count, ids, and positions equal.

**T-TXT-2 · Cluster map bidirectionality** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-105: codepoint ↔ cluster ↔ glyph map is total and invertible. **Fixtures** «لا إله إلا الله» (ligatures), «مُحَمَّدٌ» (marks), «عام 2026» (bidi). **Steps** 1. Build cluster map. 2. For every codepoint index, map → cluster → glyph(s) → back. **Expected** Every codepoint maps to exactly one cluster; every glyph belongs to exactly one cluster; round trip returns the original index set; lam-alif cluster reports 2 codepoints/1 glyph; shadda+fatha cluster reports mark glyphs attached to base cluster.

**T-TXT-3 · Bidi run map preservation** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-109: run order, `kCTRunStatusRightToLeft`, and bidiLevel are captured. **Fixtures** «الإصدار iOS 18 متاح» **Steps** 1. Capture runs; record status flag, string range, visual order. **Expected** Arabic runs flagged RTL, Latin run LTR; visual order matches CTLine run order; concatenating runs by string range reproduces the source string exactly.

**T-TXT-4 · Mark classification (Mn/Me incl. Qur'anic range)** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-105: combining marks U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED become Mark Nodes with recorded relative offsets. **Fixtures** «قَالَۚ», «شُوَاظٌۭ», «رَبِّۣ» (constructed; contains 06DA, 06ED, 06E3). **Steps** 1. Shape; classify glyphs. **Expected** Every codepoint in the listed ranges yields a Mark Node bound to the correct base Glyph Node; relative offset equals shaped GPOS position minus base position; no mark is orphaned; spacing Qur'anic signs (e.g. ۞ U+06DE, ۩ U+06E9) are classified as base glyphs, not marks.

**T-TXT-5 · ZWJ synthetic-context form resolution** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-107: harvesting isolated/initial/medial/final forms via U+200D contexts, never presentation-form codepoints. **Fixtures** Each of ب ح ع س ص ط ك ل م ن ه ي. **Steps** 1. For each letter shape four synthetic contexts: bare (isolated), letter+ZWJ (initial), ZWJ+letter+ZWJ (medial), ZWJ+letter (final). 2. Compare harvested glyph ids to the ids the same letter receives inside natural carrier words (§7.1 table). **Expected** All four forms resolve to distinct glyph ids (where the font distinguishes them) and match the natural-context ids; assert no codepoint in U+FB50–FEFF is ever produced or consumed by the engine.

**T-TXT-6 · Non-joining letters yield only two forms** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** ا د ذ ر ز و join only to the preceding letter. **Steps** 1. Run the T-TXT-5 procedure for ا د ذ ر ز و. **Expected** Initial==isolated and medial==final glyph ids; engine's `JoiningForm` model exposes only {isolated, final} for these letters and the form selector metadata says so (feeds T-AR-33).

**T-TXT-7 · Font feature control (ligature toggles)** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-108: discretionary ligatures toggled via `kLigaturesType`/`dlig`/`calt` before arrangement. **Fixtures** A string Amiri renders with a discretionary ligature when `dlig` on (e.g. «محمد» with Amiri's dlig set, verified per bundled font at implementation time — record chosen string in the test). **Steps** 1. Shape with feature off and on; compare glyph counts. **Expected** Feature-on yields the combined glyph; feature-off yields constituents; toggling is per-object and persists through save/load.

**T-TXT-8 · Typing overlay ↔ engine parity** — Phase P3 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-104: on commit, the engine-rendered object visually replaces the UITextView overlay with no jump. **Steps** 1. In simulator, type «تصميم عربي أصيل» in a Live Text object at 36 pt; end editing; screenshot overlay-last-frame and engine-first-frame; diff. **Expected** Max per-pixel delta below anti-aliasing tolerance (define ≤1 % differing pixels at 2× scale); baseline and advances identical; caret/selection artifacts absent from committed render.

**T-TXT-9 · Numeral systems shape correctly** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** Arabic-Indic ١٢٣ and Latin 123 digits both supported (BRIEF). **Fixtures** «١٢٣٤٥», «12345», «سنة ٢٠٢٦/2026». **Steps** 1. Shape and inspect run directions and glyph order. **Expected** Digit runs are LTR-progressing within the RTL paragraph (standard UBA behavior); cluster map intact; no digit substitution occurs unless a style requests it.

**T-TXT-10 · Kerning/tracking/baseline attributes survive capture** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** BRIEF per-object typography controls feed through D-103 attributed-string build. **Steps** 1. Shape «الخط العربي» with tracking +40, kern pairs enabled, baseline shift +4. 2. Compare advances vs. default shaping. **Expected** Advances reflect tracking; baseline offset present in captured positions; disabling returns to byte-identical default geometry.

**T-TXT-11 · Empty/degenerate input safety** — Phase P3 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** Edge cases never crash the engine. **Fixtures** Empty string; lone combining mark «َ»; lone tatweel «ـ»; ZWJ-only; 10 000-character paragraph; emoji «🖋️» inside Arabic. **Steps** 1. Shape each. **Expected** No crash; lone mark renders on dotted-circle base (U+25CC behavior per font) or documented fallback; emoji handled as its own run; 10 k paragraph shapes without pathological time (see T-PRF-4).

---

## 6. T-CVS — Canvas core interaction (P4)

**T-CVS-1 · Drag/resize/rotate with handles** — Phase P4 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF canvas bullet. **Steps** 1. On FIX-TYPICAL, select a shape; drag 200 pt; resize via corner handle to 2×; rotate 45°. 2. Read back node transform via debug inspector hook. **Expected** Transform matches gesture deltas (position ±1 pt, scale ±0.01, rotation ±0.5°); transform stored decomposed (D-111), not as a raw matrix.

**T-CVS-2 · Multi-select and group transforms** — Phase P4 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** Marquee + tap-add selection; group move/rotate preserves relative layout. **Steps** 1. Marquee-select 5 nodes; drag 100 pt; rotate group 30°; group them (make `group` node); ungroup. **Expected** Relative positions preserved through group rotate; group/ungroup round trip restores identical world transforms; undo once reverses the whole group action.

**T-CVS-3 · Alignment guides and snapping** — Phase P4 · Gate FUNCTIONAL-supporting · manual-visual
**Purpose** Guides appear at canvas center/edges/sibling edges; snap engages within threshold. **Steps** 1. Drag a node slowly across canvas centerline and along another node's edge. **Expected** Guide lines render at the documented snap distance; release inside threshold lands exactly on guide (inspector X/Y shows integral snap value); snapping can be disabled by the documented modifier/setting.

**T-CVS-4 · Layers panel reflects scene** — Phase P4 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF layers bullet: text objects, arranged glyphs, tashkeel marks, images, shapes with visibility/lock/reorder. **Steps** 1. Open FIX-ARABIC; open layers panel; toggle visibility, lock, and drag-reorder a layer. **Expected** Hidden node disappears from canvas but persists in file; locked node ignores canvas hit-testing but stays selectable from panel; reorder changes z-order in render and in saved `scene.json`; Arranged Composition expands to show glyph/mark children in the panel tree.

**T-CVS-5 · Numeric inspector round trip** — Phase P4 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF: editable X/Y/W/H/rotation + style fields. **Steps** 1. Select node; type X=100, Y=٢٠٠ (Arabic-Indic digits), W=300, rotation=45 into inspector. **Expected** Canvas updates live; Arabic-Indic digit entry accepted and normalized; illegal input (negative W, letters) rejected with field-level Arabic error, not a crash; values persist through save/reload.

**T-CVS-6 · Zoom/pan fidelity** — Phase P4 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-114 UIScrollView zoom keeps text crisp. **Steps** 1. Zoom to 25 %, 100 %, 400 %, 1600 % on FIX-ARABIC; screenshot a Live Text object at each. **Expected** At ≥100 % zoom glyph edges re-rasterize sharp (no scaled-bitmap blur after zoom settles); pan has no tearing; zoom limits enforced and documented.

**T-CVS-7 · Lock/hide semantics under selection** — Phase P4 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** Locked/hidden nodes are excluded from marquee selection, group ops, and alignment targets but included in export. **Steps** 1. Lock node A, hide node B; marquee over both; export region. **Expected** Marquee selects neither; export includes A (locked = still visible) and excludes B (hidden).

**T-CVS-8 · Undo across canvas gestures** — Phase P4 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** Gesture coalescing at the UI level (extends T-MDL-7 to real gestures). **Steps** 1. Perform drag, pinch-resize, rotate on one node; press undo 3×. **Expected** Exactly three undo steps restore the original transform; redo replays identically.

**T-CVS-9 · iPhone/iPad adaptive layout smoke** — Phase P4 · Gate FUNCTIONAL-supporting · manual-visual
**Purpose** BRIEF: genuinely adaptive layouts, one codebase. **Steps** 1. Open editor on iPhone 16 sim, iPhone SE sim, iPad Pro 13" sim (portrait+landscape, Split View ½ and ⅓). **Expected** Panels reflow (sidebar on iPad, sheets/drawers on iPhone); no clipped RTL controls; canvas remains usable in iPad ⅓ Split View (minimum: view + pan/zoom).

**T-CVS-10 · In-canvas text editing lifecycle** — Phase P4 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-104 overlay appears on edit, disappears on commit; system Arabic keyboard behaviors work. **Steps** 1. Double-tap Live Text → overlay appears; type with Arabic keyboard incl. tashkeel via long-press; move caret; select word by double-tap; commit by tapping outside. **Expected** IME/marked-text, selection handles, and magnifier behave natively; committed object matches typed content; escape/undo during editing cancels cleanly.

**T-CVS-11 · Cross-boundary letter-range selection splits into per-run sub-selections** — Phase P4 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** New PRD rule (next-free R-6.x per DF-6(b); ARCHITECTURE §8.3 mirrors): a letter-level range selection spanning more than one bidi run splits into per-run sub-selections for bounds/transform purposes — each run's selected children compute and transform about their OWN sub-bounds, never one bounding box spanning the whole range. **Fixtures** «الإصدار iOS 18 متاح» (T-TXT-3 fixture: Arabic run / Latin run / Arabic run with an embedded digit run). **Steps** 1. Coherent sub-run selection: select a letter range entirely WITHIN one bidi run (e.g. within «الإصدار»); read back selection bounds/transform-pivot. 2. Cross-boundary selection: select a letter range starting inside the Arabic run and ending inside the Latin run (e.g. from partway through «الإصدار» through partway through «iOS»). **Expected** Case 1 (coherent, single-run): exactly ONE bounds/pivot is produced — no splitting occurs (regression guard against over-eager splitting). Case 2 (cross-boundary): the engine reports TWO sub-selections, one per run, each with its own sub-bounds; a transform requiring a pivot (e.g. a style change) is applied to each run's selected children about that run's own sub-bounds, not a single bounding box spanning both runs; the logical character range recovered by concatenating the two sub-selections reconstructs exactly the originally selected text, with no characters lost or duplicated at the run boundary.

---

## 7. T-AR — MANUAL ARABIC-SCRIPT CHECKLIST (the centerpiece gate)

This is the release-blocking human checklist (BRIEF Q59). Every item is Gate
**MANUAL-ARABIC**, Automation **manual-visual** unless stated otherwise. A human
Arabic reader executes each item and records pass/fail + screenshot in the phase
verification record.

### 7.0 Protocol

- **Fonts**: run the full checklist in **Amiri** and **Noto Naskh Arabic** (the two
  license-verified anchors, market study §5). Run the reduced sweep T-AR-58 in every
  other bundled font that passes WS-09 verification. Per D-222: at the moment a font
  passes WS-09 license verification, it ALSO gains the arrange-fidelity gate block —
  T-AR-31/32/33 + the decompose/recompose round trip T-AR-36…38 — in addition to (not
  instead of) the reduced sweep T-AR-58; a font that fails any of these is either fixed,
  coverage-flagged, or pulled before it ships, same as a T-AR-58 failure.
- **Sizes**: 24 pt and 96 pt for shaping items; export items at their format's native
  resolution.
- **Where**: iPhone simulator is acceptable for shaping items during P3–P7 development;
  the P14/P15 sign-off run MUST be on physical `DEV-A15` and `DEV-M`.
- **Typing**: all fixtures are typed by the user with the iOS Arabic keyboard (tashkeel
  via long-press on letters; Qur'anic annotation marks via paste from this document —
  the app ships NO Qur'anic content, so fixtures here are user-entered text, consistent
  with BRIEF Q67–68).
- **Reference rendering**: when in doubt, compare against the same string in Apple
  Notes/Pages with the same font — the app's Live Text rendering must match system
  shaping (D-103), because Core Text is the shared source of truth.
- **Recording**: each item gets pass/fail, device, font, screenshot (and exported file
  for §7.12), stored as phase verification evidence (codebase-memory MCP).

### 7.1 Contextual forms — joining-group letters (Phase P3 exit; re-run at P5)

Shared **Purpose**: each letter renders the correct isolated / initial / medial / final
contextual form, matching system rendering. Shared **Steps**: 1. Type the four fixture
strings below as separate Live Text objects. 2. Compare each highlighted letter's form
against the same word typed in Apple Notes with the same font. 3. Check dots and
i'jam placement are not clipped or displaced. Shared **Expected**: forms identical to
system rendering; joins continuous with no gaps or overlapping strokes at connection
points; no presentation-form ("broken/disconnected letters") rendering anywhere.

| ID | Letter | Isolated | Initial | Medial | Final | Extra pass criteria |
|---|---|---|---|---|---|---|
| T-AR-1 | ب | «ب» | «بيت» | «حبل» | «قلب» | single dot below stays below in all forms |
| T-AR-2 | ح | «ح» | «حمل» | «بحر» | «صبح» | medial ح bowl descends correctly; no dot |
| T-AR-3 | ع | «ع» | «عمل» | «لعب» | «ربع» | medial ع closed-loop form ≠ initial open form |
| T-AR-4 | س | «س» | «سلم» | «مسك» | «شمس» | three teeth visible in all joined forms |
| T-AR-5 | ص | «ص» | «صبر» | «قصد» | «قفص» | loop + tooth preserved; final tail correct |
| T-AR-6 | ط | «ط» | «طلب» | «مطر» | «قسط» | ascender upright in all forms |
| T-AR-7 | ك | «ك» | «كتب» | «مكتب» | «ملك» | final/isolated ك keeps hamza-like miniature (font-style dependent); medial swash correct |
| T-AR-8 | ل | «ل» | «لبن» | «علم» | «جبل» | no spurious lam-alif when not followed by alif |
| T-AR-9 | م | «م» | «مدن» | «جمل» | «قلم» | final م tail descends |
| T-AR-10 | ن | «ن» | «نهر» | «منع» | «لبن» | dot above in all forms; final bowl correct |
| T-AR-11 | ه | «ه» | «هدف» | «نهر» | «وجه» | medial ه two-loop form (font-appropriate); final knot correct |
| T-AR-12 | ي | «ي» | «يمن» | «بيت» | «عربي» | two dots below; final ي tail; not confused with ى |

### 7.2 Non-joining letters (Phase P3 exit)

**T-AR-13 · Right-joining-only letters break the join forward** — P3 · MANUAL-ARABIC · manual-visual
**Purpose** ا د ذ ر ز و connect only to the preceding letter; the following letter must start a new joining sequence. **Fixtures** (typed as separate objects):

| Letter | Word-start (isolated form) | After a joiner (final/joined form) | Followed by another letter (join must break) |
|---|---|---|---|
| ا | «اسم» | «باب» | «باب» (second ب takes isolated-like form after ا) |
| د | «درس» | «بدر» | «ولد» then «ولده» (ه initial-after-د check via «بدل») |
| ذ | «ذهب» | «بذل» | «منذر» (ر after ذ unjoined) |
| ر | «رسم» | «برق» | «مريم» (ي initial form after ر) |
| ز | «زرع» | «رمز» | «مزيد» (ي initial after ز) |
| و | «وقت» | «نور» | «دلو» and «نوران» |

**Steps** 1. Type each word; inspect the boxed letter and its successor. **Expected** The six letters never grow a left-side connection; the successor letter renders initial/isolated form, never medial/final; visual gap matches system rendering.

### 7.3 Lam-alif لا (Phase P3 exit; decomposition at P6)

**T-AR-14 · Lam-alif isolated form** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «لا» alone; «ولا» (preceded by non-joiner و → isolated-form lam-alif). **Steps** Type both; compare against Notes. **Expected** Single lam-alif ligature glyph (not ل + ا side by side); isolated form (symmetric legs) used in both.

**T-AR-15 · Lam-alif joined (final) form, word-medial occurrence** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «بلا» (ب joins → joined-form لا); «سلام»، «أولاد»، «خلال»، «بلاد» (lam-alif inside words). **Expected** Joined form (left leg rises from the connection) wherever preceded by a joiner; inside words the letters after alif restart joining correctly (م in «سلام» initial-form).

**T-AR-16 · Lam + hamza/madda alif variants** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «الآن» (ل + آ), «الملأ» (ل + أ), «للإيمان» (ل + إ), «سلاًا»? — excluded, invalid; use «سَلَاسِل» for vocalized lam-alif. **Expected** Ligature also forms for أ إ آ variants with the hamza/madda mark correctly positioned on the ligature; cluster map (T-TXT-2) reports 2 codepoints/1 glyph for each.

**T-AR-17 · Lam-alif never falsely triggered** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «لب»، «لم»، «ليل». **Expected** No ligature; plain initial ل.

### 7.4 The الله ligature (Phase P3 exit)

**T-AR-18 · Allah ligature composition** — P3 · MANUAL-ARABIC · manual-visual
**Purpose** The culturally critical الله ligature (with shadda + dagger-alif appearance per font) renders as the font designed it. **Fixtures** «الله»، «بالله»، «لله»، «عبدالله»، «اللهم». **Steps** 1. Type each; compare with Notes in same font. 2. Also type «الللهو» (three lams — must NOT take the ligature) and «اللهُمَّ» with explicit damma. **Expected** Ligature identical to system rendering in the five fixtures; no false positive on «الللهو»; explicit user tashkeel positions correctly on/around the ligature. In Arrange Mode this becomes ONE Ligature Group (verified functionally in T-AR-36 path).

### 7.5 Tashkeel attachment (Phase P3 exit; detachment behaviors at P6)

**T-AR-19 · The eight core marks on a base** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** typed on ب: «بَ» فتحة، «بِ» كسرة، «بُ» ضمة، «بْ» سكون، «بّ» شدّة، «بً» تنوين فتح، «بٍ» تنوين كسر، «بٌ» تنوين ضم. **Steps** Type each pair as its own object at 96 pt. **Expected** Above-marks (فتحة ضمة سكون شدة فتحتان ضمتان) sit above the base; كسرة/كسرتان below; horizontal centering matches system rendering; no mark drawn on dotted circle; no overlap with the base's dots.

**T-AR-20 · Shadda + vowel stacking order** — P3 · MANUAL-ARABIC · manual-visual
**Purpose** Shadda combines with a vowel into the canonical stack: fatha/damma ABOVE shadda; kasra conventionally moves up under the shadda (font-dependent — must match the font's own behavior in system rendering, not an app-invented position). **Fixtures** «مُحَمَّدٌ»، «رَبِّ»، «إِنَّ»، «حُبٌّ» (shadda+dammatan)، «الشَّدَّة»، «مِلَّة» (shadda+kasra). **Expected** Stack order identical to Notes/Pages in the same font; both marks form Mark Nodes attached to the same base with correct z-order preserved into Arrange Mode.

**T-AR-21 · Fully vocalized line incl. dagger alif** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ» (contains U+0670 dagger alif), «إِنَّ ٱللَّهَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ» (wasla ٱ + superscript alef ىٰ). **Expected** Every mark attached and positioned as system rendering; wasla renders; dagger alif positioned over its base; line spacing does not clip high stacks at default line height (and increasing line height in the inspector clears any collision).

**T-AR-22 · Tanwin at word end with alif** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «كتابًا»، «شكرًا»، «عفوًا» (fathatan-on-alif convention), «ماءً» (on hamza seat). **Expected** Fathatan placement follows the font's convention (on the letter before alif or on alif — must match system rendering, checked per font); no double-width gap.

**T-AR-23 · Mark positioning on ascenders/descenders** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «طَهَّرَ»، «ظِلٌّ»، «جِئْتُ»، «غُصْنٌ»، «خَيْرٌ». **Expected** Marks clear tall letters (ط ظ) and descender bowls (ج ع غ خ) without collision, matching the font's GPOS behavior in system rendering.

### 7.6 Qur'anic annotation marks U+06D6–06ED, typed by user (Phase P3 exit)

Reminder: the app ships **no Qur'anic content** (BRIEF Q67–68). These fixtures are
arbitrary user-typed strings that exercise the codepoint range because founder Q11
requires full support for the marks themselves. Font for this subsection: Amiri
(fullest coverage of the annotation range among the anchors); record any bundled font
whose coverage report (T-FNT-8) excludes the range and skip visually per-font.

**T-AR-24 · Small high waqf marks (U+06D6–06DC) ride their base** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «قَالَۚ» (06DA jeem), «كَلَّاۖ» (06D6 sad-lam-alif), «عَلِيمٌۗ» (06D7 qaf-lam-alif), «نَذِيرٞۘ»? — simplified: «مُبِينٍۙ» (06D9 lam-alif), «تَعْمَلُونَۛ» (06DB three dots), «يَشَاءُۜ» (06DC seen). **Steps** Paste each; zoom 400 %. **Expected** Each small mark renders above the END of its word near the final letter (attachment per font GPOS), never as a tofu box, never reordered into the middle of the word; deleting the mark with backspace removes only the mark.

**T-AR-25 · Small letters and stops (U+06DF–06E8, 06EA–06ED)** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «ءَامَنُوا۟» (06DF small rounded zero on wasl-alif), «أَنا۠» (06E0), «عَلَيْهِمۡ» (06E1 small high dotless head), «مِنۢ بَعْدِ» (06E2 small high meem), «شُوَاظۣٞ»? — simplified «رَبِّۣ» (06E3 small low seen), «الٓمٓ»-style madda via «نۤ» (06E4), «يَحۧيَىٰ»-style small yeh «ۧ» on «فِيهِۧ», «مَجۨرَاهَا»-style small noon «ۨ» on «لَنۨ», stops «قَرِيبٌ۪»، «بَعِيدٌ۫»، «شَهِيدٌ۬»، «عَلِيمٌۭ» (06EA–06ED). **Expected** All render as marks on their bases with sensible high/low placement matching system rendering; none break the base word's joining; cluster map keeps them as Mark Nodes (cross-check T-TXT-4).

**T-AR-26 · Spacing Qur'anic signs are standalone glyphs** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «۞ فصل ۝٥ سجدة ۩» (06DE rub el hizb, 06DD end-of-ayah with following digit, 06E9 sajdah). **Expected** Render as spacing glyphs in the text flow (not attached marks); RTL ordering correct around them; in Arrange Mode each becomes a normal Glyph Node.

### 7.7 Kashida / tatweel (Phase P3 exit; arrange interaction at P5)

**T-AR-27 · Tatweel elongation** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «الحمـــد» (three tatweels ك), «كتـــاب»، «محـــمد»، vocalized «كَـــتَبَ» (mark stays on its letter, not on the tatweel run), and misuse case «مرـحبا» (tatweel after non-joiner ر). **Steps** Type each (tatweel = ـ U+0640 on the Arabic keyboard). **Expected** Tatweel extends the baseline connection smoothly with no seams at any zoom; marks remain anchored to their letters; the misuse case renders the tatweel as an unconnected stroke exactly as system rendering does (no crash, no invented join); in Arrange Mode each tatweel is a selectable Glyph Node.

### 7.8 Mixed bidi: Arabic + English + numerals + punctuation (Phase P3 exit)

**T-AR-28 · Latin words inside Arabic** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «صمّم بتطبيق Makhtoot اليوم»، «الإصدار iOS 18 متاح الآن»، «اكتب بخط SF Arabic أو Amiri». **Expected** Reading order correct (Arabic RTL, Latin islands LTR, whole line reads naturally); caret traversal through the boundary follows iOS-native behavior in the edit overlay; no mirrored/flipped Latin glyphs.

**T-AR-29 · Numerals both systems** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «١٢٣ مقابل 123»، «السعر ٣ دولارات شهريًا أو 30 USD سنويًا»، «عام 2026 الموافق ١٤٤٧هـ»، «هاتف: 96891234567+». **Expected** Digit runs progress LTR inside the RTL line; the phone-number plus sign lands visually leading per UBA (match Notes rendering exactly — this is a classic trap; app must not "fix" UBA); Arabic-Indic and Latin digits never substituted for one another.

**T-AR-30 · Punctuation and bracket mirroring** — P3 · MANUAL-ARABIC · manual-visual
**Fixtures** «هل جرّبت (النسخة التجريبية)؟»، «قال: "Hello" ثم أكمل»، «القائمة: [أ، ب، ج]»، «نسبة ٥٠٪ تقريبًا»، «انتهى؟!». **Expected** Arabic question mark ؟ and comma ، used; parens/brackets open toward the text they wrap (mirrored correctly in RTL); the percent/quote placement matches system rendering; nothing double-mirrored on export (re-checked in §7.12 items).

### 7.9 Arrange Mode preservation (Phase P5–P6 exit — the differentiator checks)

**T-AR-31 · Glyph identity unchanged on Arrange entry** — P5 · MANUAL-ARABIC · manual-visual
**Purpose** D-106: entering Arrange Mode is a snapshot, not a re-render. **Fixtures** «بسم الله الرحمن الرحيم» vocalized variant from T-AR-21, plus FIX-BIDI strings. **Steps** 1. Screenshot the Live Text object. 2. Enter Arrange Mode; screenshot. 3. Overlay/diff (also automated as a pixel-diff FUNCTIONAL twin in MKArrange tests). **Expected** Zero visual change at entry: identical forms, ligatures, mark positions, spacing. Selection chrome is the only difference.

**T-AR-32 · No reshape on move** — P5 · MANUAL-ARABIC · manual-visual
**Fixtures** «بحر» arranged. **Steps** 1. Select the medial ح Glyph Node; drag it 150 pt away. **Expected** ح keeps its MEDIAL form while floating free (the neighbors also keep their forms and do NOT re-join or heal the gap); no reflow of remaining glyphs; undo returns it exactly.

**T-AR-33 · Join preserved on drag (default)** — P5 · MANUAL-ARABIC · manual-visual
**Purpose** BRIEF: joining preserved by default; breaking is explicit. **Fixtures** «سلم» arranged. **Steps** 1. Drag the whole word; then drag س slightly (a few points) with default settings. **Expected** Letterforms never switch to isolated forms because of any drag distance/direction; the visual connection may stretch open spatially but glyph identity is untouched; no automatic "smart" rejoin occurs.

**T-AR-34 · Explicit break → four-form selector correctness** — P6 · MANUAL-ARABIC · manual-visual
**Purpose** D-107 ZWJ-derived forms surface in the UI. **Fixtures** «معهد» arranged. **Steps** 1. Select medial ع; invoke explicit "break join" (فك الاتصال). 2. Open the contextual-form selector; apply each of isolated ع, initial عـ, medial ـعـ, final ـع in turn, comparing each against the reference forms in the §7.1 row. **Expected** Selector previews and applied results are the font's true contextual forms (harvested per D-107, never presentation-form codepoints); switching forms repeatedly is lossless; undo restores the pre-break state.

**T-AR-35 · Form selector on non-joiners offers exactly two forms** — P6 · MANUAL-ARABIC · manual-visual
**Fixtures** «نور» arranged, select و. **Expected** Selector shows only isolated and final forms for و (per T-TXT-6); applying each renders correctly.

**T-AR-36 · Ligature decompose keeps the ligature look** — P6 · MANUAL-ARABIC · manual-visual
**Purpose** D-108 default: visual fidelity. **Fixtures** «سلام» arranged (joined lam-alif); «الله» arranged. **Steps** 1. Select the lam-alif Ligature Group; decompose. 2. Screenshot before/after. **Expected** After decomposition the composition LOOKS unchanged (constituents placed with computed offsets matching original ligature bounds); but ل and ا are now separately selectable/movable; same check for الله components.

**T-AR-37 · Decompose opt-out to default forms** — P6 · MANUAL-ARABIC · manual-visual
**Steps** 1. Repeat T-AR-36 but choose the documented opt-out (الأشكال الافتراضية). **Expected** Constituents render in default contextual forms with default spacing (visibly different from the ligature); the choice is per-decomposition and undoable.

**T-AR-38 · Recompose restores exactly** — P6 · MANUAL-ARABIC · manual-visual
**Steps** 1. Decompose lam-alif (fidelity mode); move both parts; invoke recompose (إعادة الدمج). **Expected** The stored original ligature glyph returns at its original relative geometry (pixel-identical to pre-decomposition screenshot); recompose is refused with a clear Arabic message if a constituent was deleted.

**T-AR-60 · Single-glyph scale inside a joined word (neighbor overlap accepted-by-design)** — P5 · MANUAL-ARABIC · manual-visual
**Purpose** D-222: scaling one Glyph Node inside an otherwise-joined word does NOT modify its neighbors; the resulting stroke overlap or gap is accepted-by-design and documented exactly like the translate case (T-AR-32/33 pattern). **Fixtures** «سلم» arranged (as in T-AR-33). **Steps** 1. Select the medial ل Glyph Node; scale it 1.6× in place. **Expected** ل keeps its medial form and grows; neighboring س and م are NOT resized, repositioned, or reshaped to compensate; the resulting stroke overlap/gap at the join is visually present and is the documented, accepted behavior (not a bug); undo returns the word exactly to its pre-scale state.

**T-AR-61 · Discretionary ligature (dlig) decompose fixture** — P6 · MANUAL-ARABIC · manual-visual
**Purpose** D-222: extends the ligature decompose/recompose fixture set beyond lam-alif/الله to a discretionary (`dlig`) ligature, since dlig ligatures are opted-in per-object (T-TXT-7) and must decompose/recompose with the same fidelity guarantees as the always-on ligatures. **Fixtures** The T-TXT-7 string with `dlig` enabled (record the exact bundled-font string chosen at implementation, per T-TXT-7's note). **Steps** 1. With `dlig` on, arrange the object; select the discretionary Ligature Group; decompose (fidelity mode). 2. Screenshot before/after. 3. Recompose (إعادة الدمج). **Expected** Same contract as T-AR-36/38: decomposed constituents are placed to visually match the original dlig ligature's bounds and are independently selectable; recompose restores the exact original ligature glyph at its original relative geometry; if the natural component fit falls outside the D-221 clamp ([0.85, 1.15] uniform scale), fidelity mode is refused and the object falls back to default-forms decomposition with the standard notice (D-221(2)) — record which path this fixture exercises.

**T-AR-62 · Rotate ligature group 45° then decompose — marks track components** — P6 · MANUAL-ARABIC · manual-visual
**Purpose** DF-8/DF-12: a ligature carrying attached marks (e.g. vocalized الله or a shadda-bearing lam-alif context) must decompose correctly even when the whole Ligature Group has been rotated first — marks must track their post-decompose constituent, not the pre-rotation position. **Fixtures** «اللَّه» arranged (vocalized الله, shadda on the second ل). **Steps** 1. Select the الله Ligature Group; rotate the whole group 45°. 2. Decompose (fidelity mode). 3. Inspect the shadda's position relative to its now-separated base component. **Expected** After decomposition, the composition still LOOKS correct at the 45° orientation (constituents placed with computed offsets matching the rotated ligature bounds, per D-220/D-221); the shadda Mark Node tracks its owning base Glyph Node's new post-decompose transform (rotated position + orientation), not the ligature's pre-decompose combined transform; no mark is left orphaned or misplaced.

**T-AR-63 · Decompose neighbor-overlap fixture** — P6 · MANUAL-ARABIC · manual-visual
**Purpose** DF-12 (§7.4 nested/overlapping-ligature scope statement): Arrange Mode uses a flat model by design — after decomposing a ligature, resulting neighbor-overlap with an ADJACENT (non-ligature) glyph is accepted-by-design, not a bug, and is documented exactly like T-AR-32/33's move/drag overlap. **Fixtures** «بلا» arranged (ب immediately before the لا ligature — see T-AR-15). **Steps** 1. Decompose the لا Ligature Group (fidelity mode) so ل and ا become separate Glyph Nodes placed at their original combined-ligature bounds. 2. Inspect the boundary between the decomposed ل and the preceding ب. **Expected** The decomposed ل may visually overlap or gap against the neighboring ب exactly as the pre-decompose ligature did (no automatic rejoin/reflow attempt); this is accepted-by-design per the flat Arrange-mode model; both glyphs remain independently selectable and movable.

**T-AR-39 · Mark follows base** — P5 · MANUAL-ARABIC · manual-visual
**Fixtures** «مُحَمَّدٌ» arranged. **Steps** 1. Select the base م carrying shadda+fatha; move, rotate 30°, scale 1.5×. **Expected** Attached Mark Nodes follow every transform, preserving relative offset (rotating base rotates marks around the base per documented behavior); marks stay selectable individually.

**T-AR-40 · Detach stops following** — P5 · MANUAL-ARABIC · manual-visual
**Steps** 1. Select the shadda; detach (فصل الحركة); move the base م. **Expected** Detached shadda stays put while the base moves; it renders independently (own opacity/fill controls work).

**T-AR-41 · Reattach resumes following** — P5 · MANUAL-ARABIC · manual-visual
**Steps** 1. Select detached shadda; reattach to م (إعادة الإرفاق), either at current offset or snap-back per documented UI. **Expected** Reattached mark follows the base again; save/reload preserves attachment state and offset; undo history covers detach/reattach.

**T-AR-42 · Independent mark styling** — P5 · MANUAL-ARABIC · manual-visual
**Steps** 1. On «بَرَكَة» arranged, recolor the فتحة marks red, scale one 2×, set opacity 50 % on another. **Expected** Only the targeted Mark Nodes change; base glyphs untouched; styles persist and export correctly (spot-check in §7.12).

**T-AR-43 · Dual-level editing loses nothing** — P5 · MANUAL-ARABIC · manual-visual
**Purpose** BRIEF: shaped-glyph AND Unicode-letter manipulation, switching loses nothing. **Fixtures** «كتاب» arranged. **Steps** 1. In glyph view, nudge ت up 20 pt. 2. Switch to the letter (codepoint) view; verify the letter sequence ك ت ا ب shown intact; select letter ت there. 3. Switch back. **Expected** Codepoint sequence always intact (provenance per D-111); selection maps consistently between views; the glyph nudge survives the round trip.

**T-AR-44 · Revert-to-text round trip** — P5 · MANUAL-ARABIC · manual-visual
**Purpose** D-106 Source Text Backup. **Fixtures** «تصميم بلا حدود» with tashkeel added, arranged, then heavily edited (moved glyphs, detached mark, decomposed lam-alif). **Steps** 1. Invoke revert (الرجوع إلى النص); read the confirmation dialog; confirm. 2. Compare the restored Live Text object with a screenshot taken before arranging. **Expected** Confirmation explicitly warns arrangement will be discarded (سيتم تجاهل التنسيق اليدوي); restored object is pixel-identical to the pre-arrange Live Text including styles; typing into it reflows normally; redo/undo across the revert behaves as documented.

**T-AR-45 · Revert is the only reflow path** — P5 · MANUAL-ARABIC · manual-visual
**Steps** 1. In an Arranged Composition try every edit surface (inspector, keyboard shortcuts, double-tap). **Expected** No path exists that silently reflows/reshapes an Arranged Composition; text editing affordances on it lead only to the explicit revert flow. (BRIEF: arranged compositions never auto-reflow.)

### 7.10 Path text (Phase P7 exit)

**T-AR-46 · RTL glyph order along path** — P7 · MANUAL-ARABIC · manual-visual
**Fixtures** «الخط العربي جميل» on FIX-PATH circle and S-curve. **Steps** 1. Apply the string to each path. **Expected** Text reads correctly RTL along the path direction (first letter ا of «الخط» at the path start, subsequent letters advancing along arc length); joining and ligatures preserved along the curve; on the circle, text follows the documented convention (top outside, readable) matching the design spec.

**T-AR-47 · Tangent rotation** — P7 · MANUAL-ARABIC · manual-visual
**Steps** 1. Inspect glyphs at the tightest curvature of the S-curve at 400 % zoom. **Expected** Each glyph's baseline aligns to the local tangent (D-110); marks rotate with their bases; no glyph flips upside down on an inflection; extreme curvature degrades gracefully (overlap allowed, no crash, no NaN placement).

**T-AR-48 · Editable/reflowable until arranged** — P7 · MANUAL-ARABIC · manual-visual
**Steps** 1. Retype the path text to «مخطوط»; 2. Drag a path control point to change curvature; 3. Then arrange the path text; 4. Try editing the path again. **Expected** (1) and (2) relayout live along the new path; after arranging, glyphs freeze with per-glyph adjustability (nudge one glyph off-path works) and the path control points are no longer editable (D-110 live-mode only); revert-to-text restores live path editing.

**T-AR-49 · Tashkeel on path text** — P7 · MANUAL-ARABIC · manual-visual
**Fixtures** «قُلْ هُوَ ٱللَّهُ أَحَدٌ»-length vocalized user string, e.g. «حِبْرٌ وَوَرَقٌ وَقَلَمٌ», on the circle path. **Expected** Marks stay attached to their bases with path-local orientation; no mark detaches or lands on a neighboring glyph at moderate curvature.

**T-AR-50 · Arrange-on-path keeps adjustments** — P7 · MANUAL-ARABIC · manual-visual
**Steps** 1. Arrange the S-curve text; rotate one glyph +20° and recolor another; save, close, reopen. **Expected** Adjustments persist exactly; export (PNG) matches canvas.

### 7.11 Cross-font sweep and RTL chrome

**T-AR-58 · Reduced sweep per bundled font** — P9 · MANUAL-ARABIC · manual-visual
**Purpose** Every shipped font renders the core set correctly (or its coverage limits are documented in the catalog per T-FNT-8). **Fixtures** Reduced set: T-AR-1 row (ب), T-AR-14/15 (lam-alif), T-AR-18 («الله»), T-AR-20 («مُحَمَّدٌ»), T-AR-29 numerals line. **Steps** For each font in the shipped catalog, type the reduced set. **Expected** Correct shaping everywhere; any font failing a fixture is either fixed (font metadata/features), coverage-flagged in the catalog UI, or pulled — never shipped silently broken.

**T-AR-59 · RTL app chrome smoke** — P1 · MANUAL-ARABIC · manual-visual
**Purpose** Arabic-only UI reads natively (D-100/D-126). **Steps** 1. Walk browser → editor → inspector → settings on iPhone and iPad. **Expected** All panels right-anchored appropriately, directional icons mirrored (back arrows point right), sliders/steppers RTL-correct, Arabic strings everywhere (no English leakage except brand names), numerals per design spec.

### 7.12 Export fidelity per format (Phase P10 exit; sign-off at P15)

**T-AR-51 · Free JPEG at 2 MP** — P10 · MANUAL-ARABIC · manual-visual
**Fixtures** FIX-ARABIC exported as free-tier JPEG (preset ≤2 MP). **Steps** 1. Export; open on a Mac at 100 %. **Expected** Shaping identical to canvas (bit-for-bit same render path per D-118); tashkeel and Qur'anic marks legible at 2 MP; JPEG artifacts do not destroy thin marks at default quality; effective pixel count ≤2 MP verified.

**T-AR-52 · Free rasterized PDF** — P10 · MANUAL-ARABIC · manual-visual
**Steps** 1. Export free PDF; open in Preview and Adobe Acrobat. **Expected** Renders identically to the JPEG (rasterized, ≤2 MP effective); no live text objects present (free tier is raster per D-118); page size matches preset.

**T-AR-53 · PNG alpha edges** — P10 · MANUAL-ARABIC · manual-visual
**Fixtures** «مخطوط» large display text + a recolored detached فتحة on transparent background. **Steps** 1. Export premium transparent PNG; composite over pure black and pure yellow in Preview. **Expected** Glyph edges anti-alias cleanly against both backgrounds (no white/dark fringe = premultiplication handled); fully transparent pixels have zero color bleed; opaque PNG variant has the exact canvas background color.

**T-AR-54 · SVG opens editable in Illustrator, Figma, Inkscape** — P10 · MANUAL-ARABIC · manual-visual
**Purpose** D-118/Q73: editability preserved where promised. **Fixtures** A project with (a) an untouched Live Text object in Amiri (OFL → live `<text>` allowed), (b) an Arranged Composition with moved glyphs, (c) a shape + imported SVG ornament. **Steps** 1. Export SVG; open in current Illustrator, Figma (import), Inkscape 1.x. **Expected** (a) imports as text where the host app supports it — content string intact «…», RTL attributes present; (b) imports as grouped vector paths that LOOK identical to canvas, with `data-mk-*` provenance attributes (source text, codepoints, font name) inspectable in the XML; (c) shapes editable as paths. Every outlining decision matches the documented per-feature fallback table — nothing silently flattened. Record per-host quirks in the phase log.

**T-AR-55 · SVG outline-fallback documentation check** — P10 · MANUAL-ARABIC · manual-visual
**Steps** 1. Export the FIX-PREMIUM project (non-embeddable font) to SVG; inspect XML. **Expected** Text in the non-embeddable font is outlined AND the export UI/summary disclosed this before export (per D-118 "never silently flatten"); OFL-font text remains `<text>` with `@font-face` embed.

**T-AR-56 · Print PDF: vector + CMYK spot check** — P10 · MANUAL-ARABIC · manual-visual
**Purpose** Q75 true-CMYK gate. **Fixtures** FIX-4K with a swatch rectangle set to a known sRGB red (e.g. #C22326) and Live Text in Amiri. **Steps** 1. Export premium print PDF (CMYK, FD-03 profile or documented Apple Generic CMYK fallback). 2. Open in Adobe Acrobat: Output Preview → verify color space per object; use the object inspector to read the swatch's CMYK values. 3. Verify OutputIntent/ICC profile embedded (Preflight). 4. Zoom text to 6400 %. **Expected** Page objects are CMYK (no stray RGB unless documented, e.g. embedded photos per pipeline docs); swatch CMYK values match the pipeline's documented conversion for that profile within tolerance recorded in MKColor tests; text is vector (infinite zoom, no pixelation) with subset-embedded OFL font or documented outlines; OutputIntent present and names the shipped profile.

**T-AR-57 · Sharpness at print size, 300-DPI raster floor** — P10 · MANUAL-ARABIC · manual-visual
**Fixtures** FIX-4K including one photo background (premium). **Steps** 1. Export print PDF at an A3 preset. 2. In Acrobat, verify the embedded photo's effective resolution ≥300 DPI (Preflight → image resolution report). 3. Print A3 (or view at 100 % on a 220+ ppi display at equivalent physical scale) and read the smallest tashkeel. **Expected** Raster assets meet the 300-DPI floor or export warned about upscaled sources; Arabic strokes and marks are crisp at print size; hairline strokes don't drop out.

### 7.13 Arrange Mode functional/numeric twins (T-ARR family)

New per Run-2 D-220/D-221/DF-8. These are xcodebuild-testable FUNCTIONAL-supporting twins
of Arrange Mode behaviors that are precisely checkable programmatically (geometry math,
state-machine dirty-checks, typed errors) rather than requiring a human eye — distinct
from the MANUAL-ARABIC T-AR family above. Phase P5/P6 per the behavior under test.

**T-ARR-1 · Mark world-position formula at base rotations 30°/90°/180°/270° (numeric)** — Phase P5 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-220 makes the mark-attachment geometry normative: `composition.affine ∘ base.affine ∘ translate(relativeOffset) ∘ mark.affine`, with the mark's own rotation/scale pivoting about its relativeOffset-anchored origin (translate precedes mark.affine). This test asserts the engine's computed world position matches the formula analytically, not just "looks right." **Fixtures** A synthetic base Glyph Node at a known world transform with one attached Mark Node at a known `relativeOffset`, composition affine = identity for isolation. **Steps** 1. For each base rotation in {30°, 90°, 180°, 270°} (uniform scale 1.0), compute the expected mark world position by hand-evaluating the D-220 formula. 2. Read the engine's actual mark world position via the debug/test seam. **Expected** Actual position matches the analytically-computed expected position within tolerance ≤0.05 pt and ≤0.05° orientation at every rotation; the mark's own local rotation/scale (if any) visibly pivots about the relativeOffset-anchored origin, not the base's origin or the world origin.

**T-ARR-2 · Mark world-position formula under non-uniform base scale (numeric)** — Phase P5 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-220: non-uniform base scale skews the relativeOffset component-wise (falls out of the affine chain) — this must be verified numerically, since a skewed offset is easy to get wrong with a naive uniform-scale assumption. **Steps** 1. Set the base's scale to non-uniform values (e.g. scaleX=1.4, scaleY=0.7) at 0° rotation. 2. Compute the expected mark world position by hand-evaluating the D-220 formula with the non-uniform scale applied component-wise to `relativeOffset`. 3. Read the engine's actual mark world position. **Expected** Actual matches expected within tolerance ≤0.05 pt; repeat with a combined non-uniform-scale + 45°-rotation base transform and confirm the formula (not a simplified uniform-scale shortcut) still holds within the same tolerance.

**T-ARR-3 · Detach → rotate base 90° → re-attach → rotate base again (no double-rotation)** — Phase P5 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-220: re-attach recomputes `relativeOffset = base.affine⁻¹(mark.worldPos) − base.affine⁻¹(base.worldPos)` in BASE-LOCAL space, never as a raw world delta. This test catches the classic bug where re-attach captures a world-space offset and a subsequent base rotation then applies rotation twice. **Steps** 1. Detach a mark from its base (mark stays at its current world position, per T-AR-40). 2. Rotate the base 90°. 3. Re-attach the mark to the base at its current world position (T-AR-41 "current offset" path). 4. Read the newly-computed `relativeOffset`; verify it is expressed in base-local space per the D-220 formula. 5. Rotate the base ANOTHER 90° (180° total from start). 6. Read the mark's world position. **Expected** After step 3, `relativeOffset` equals `base.affine⁻¹(mark.worldPos) − base.affine⁻¹(base.worldPos)` computed at the base's POST-rotation transform (base-local, not the pre-rotation world delta). After step 5, the mark's world position matches the D-220 formula evaluated fresh at the base's new (180°-total) transform — i.e. the mark rotates exactly once more with the base, not twice (no accumulated double-rotation from the detach/re-attach round trip).

**T-ARR-LIG-STYLE · Style-only edit before recompose fires confirmation** — Phase P6 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-221(3): the recompose dirty-check compares FULL node state (transform AND style: fill/stroke/opacity/shadow) against the post-decomposition baseline — fixing the prior silent style-edit-loss bug where only transform was checked. **Steps** 1. Decompose a ligature (fidelity mode, e.g. lam-alif per T-AR-36). 2. Without moving/rotating/scaling any constituent, change ONLY a style property on one constituent (e.g. fill color). 3. Invoke recompose. **Expected** The recompose confirmation dialog fires (dirty-check detects the delta) exactly as it would for a transform change — the prior bug where a style-only edit was silently discarded on recompose does NOT reproduce; declining the confirmation preserves the style edit and the decomposed state; accepting recomposes and the style edit is lost as documented (with the confirmation having made that consequence explicit).

**T-ARR-NOREFLOW-1 · Feature-mutation on arranged node throws MKError.arrangedNodeCannotReshape** — Phase P6 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** DF-8/PLAN P6 exit: T-AR-45 establishes that no UI path silently reflows an Arranged Composition; this is the programmatic backstop proving the engine itself refuses a reshape-requiring mutation rather than merely lacking a UI affordance for it. **Steps** 1. On a frozen Glyph Node inside an Arranged Composition, call the engine API to mutate a property that would require re-shaping (e.g. toggle the `dlig`/ligature feature flag, or change the node's source codepoint) directly, bypassing the UI. **Expected** The call throws the typed error `MKError.arrangedNodeCannotReshape` (never a silent no-op, never a crash, never a partial mutation); the node's geometry and content are byte-identical before and after the throw; the same assertion holds for every reshape-requiring mutation path enumerated in the engine's API surface (enumerate and assert each in the test).

---

## 8. T-PTH — Path text functional (P7)

**T-PTH-1 · Arc-length LUT accuracy** — Phase P7 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-110 parameterization is numerically sound. **Steps** 1. Build LUT for a unit circle and a degenerate near-zero-length segment path. 2. Sample arc length at 1 000 points; compare against analytic circle values. **Expected** Position error <0.1 pt at 1000-pt scale; degenerate segments do not produce NaN/infinite tangents (fallback tangent defined).

**T-PTH-2 · Logical-reading-order pen advance along path** — Phase P7 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** Logical reading order pen advance (D-110; ARCHITECTURE §9.4 terminology corrected per DF-6a — "visual-order pen advance" was a misnomer and is dropped). **Fixtures** «سلام Hello ٤٥» on an open path; new multi-switch fixture «Hello سلام World ٤٥» (two direction switches within one line); new no-space digit-adjacency fixture «الرقم٤٥» (Arabic-Indic digits immediately adjacent to an Arabic letter, no separating space). **Steps** 1. Lay out each fixture on an open path; dump per-glyph arc offsets in path-traversal order. **Expected** Arc offsets strictly increase along the path following LOGICAL READING ORDER (each bidi run advances in its own internal order — the RTL Arabic run right-to-left through its glyphs, LTR Latin/digit runs left-to-right through theirs — chained run-by-run in the paragraph's logical sequence per the captured bidi map, T-TXT-3); total consumed arc length = sum of advances + tracking for every fixture; the multi-switch fixture's two direction changes produce no arc-length drift, gap, or overlap at either boundary; the no-space digit-adjacency fixture attaches the digit run's first glyph directly to the preceding Arabic glyph's arc offset with no phantom gap and no double-counted advance.

**T-PTH-3 · Overflow behavior** — Phase P7 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Type text longer than the path's arc length. **Expected** Documented overflow policy applies (clip or scale — per PRD §9); no crash; UI indicates overflow; shortening text restores full layout.

**T-PTH-4 · Live path edit relayout** — Phase P7 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Drag a control point of a live Path Text's Bézier; measure relayout continuity. **Expected** Glyphs re-place every frame (or at documented throttle) without flicker; text content/styles unchanged; undo restores the prior path geometry.

**T-PTH-5 · Closed-path wrap semantics** — Phase P7 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Lay «نص دائري مستمر» exceeding a closed loop's circumference minus start offset. **Expected** Documented behavior (no infinite wrap-around overlap unless specified); start-offset parameter shifts text around the loop deterministically.

**T-PTH-6 · Arrange-on-path provenance** — Phase P7 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Arrange a path text; inspect nodes. **Expected** Each Glyph Node stores source codepoints + path-derived base transform + user delta separately (so revert works); Source Text Backup includes the path and live-text state; revert restores a live Path Text on the identical path.

---

## 9. T-AST — Assets, shapes, imports (P8)

**T-AST-1 · Bundled asset browser placement** — Phase P8 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF: shapes/ornaments/frames/calligraphic elements/pattern backgrounds are placeable v1 assets. **Steps** 1. Place one of each category from `MKAssets`; transform each; save/reload. **Expected** All place as vector nodes, transform correctly, persist; each bundled asset has license-clear provenance metadata (spot-check the registry).

**T-AST-2 · Raster image import** — Phase P8 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Import a 12 MP HEIC and a PNG-with-alpha via Photos/Files. 2. Place, scale, export. **Expected** Content-addressed copy in `assets/` (T-MDL-3); orientation EXIF honored; alpha preserved; free tier: photo import gated premium (solid colors only for backgrounds — verify the gate blocks with paywall prompt, Q34).

**T-AST-3 · SVG import fidelity** — Phase P8 · Gate FUNCTIONAL-supporting · manual-visual
**Fixtures** SVG with paths, groups, gradients, and one unsupported feature (e.g. filter). **Steps** 1. Import; compare render vs. browser rendering. **Expected** Supported subset renders faithfully; unsupported features degrade per documented policy with a non-blocking Arabic notice — never a silent blank.

**T-AST-4 · PDF import as placeable asset** — Phase P8 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Import a single-page vector PDF; place and scale 4×. **Expected** Stays sharp (vector-backed rendering or high-res re-raster per zoom); multi-page PDFs follow the documented first-page/page-picker policy.

**T-AST-5 · Malformed import corpus** — Phase P8 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Fixtures** Zero-byte file, corrupt SVG (truncated XML), 200 MP image. **Steps** 1. Import each. **Expected** Typed errors with specific Arabic messages; oversized raster triggers the documented downsample-or-refuse path tied to memory budgets; no crash.

---

## 10. T-FNT — Fonts subsystem (P9)

**T-FNT-1 · Bundled font registration at launch** — Phase P9 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-122 per-process registration. **Steps** 1. Launch; query `CTFontManager` for each bundled font's PostScript name. **Expected** Every WS-09-verified bundled font resolves; failure of one font logs and skips without blocking launch; no system-wide registration.

**T-FNT-2 · Catalog browsing/search/favorites** — Phase P9 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Browse categories (Naskh, Ruq'ah, Thuluth, Diwani, Kufi, Maghrebi, modern display, Qur'anic-style, handwriting, bilingual); search «أميري»; favorite two fonts; relaunch. **Expected** Previews render live Arabic sample text; search matches Arabic + Latin names; favorites persist in SwiftData metadata.

**T-FNT-3 · Premium catalog download + entitlement check** — Phase P9 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-121 download after entitlement confirmation. **Steps** 1. As trial/premium user, download a catalog font (local test server hosting the static JSON manifest + font). 2. As free user, attempt the same. 3. Interrupt a premium download mid-transfer (kill the connection at ~50 % of expected byte count); resume. **Expected** Premium path: verified download (checksum from manifest), registered, usable immediately; free path: blocked with paywall prompt; interrupted download resumes from its BYTE OFFSET (verify via a range-request/bytes-already-written assertion, not merely "eventually succeeds") — a restart-from-zero on resume is a test failure (DF-8); checksum still verifies after the resumed download completes.

**T-FNT-4 · User font import happy path (premium)** — Phase P9 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Premium user imports a valid .ttf, .otf, .ttc, and a variable font via Files picker. **Expected** sfnt validation passes; content-addressed copy; registered; catalog entries flagged `userImported`; variable font instances exposed per documented policy; free user is blocked (Q64).

**T-FNT-5 · Import rejection corpus** — Phase P9 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Fixtures** FIX-FONTS-BAD. **Steps** 1. Import each file. **Expected** Each rejected with a SPECIFIC Arabic error (e.g. woff2: «صيغة الويب woff2 غير مدعومة — استخدم ttf أو otf»); nothing partially registered; no orphan files in container.

**T-FNT-6 · Duplicate and conflicting imports** — Phase P9 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Import the same font twice; import a different font with an identical PostScript name to a bundled font. **Expected** Duplicate detected via content hash (no second copy); name collision resolved per documented policy (imported font distinguishable in catalog, bundled font never shadowed silently).

**T-FNT-7 · License metadata at Settings → Support → Licensing** — Phase P9 · Gate FUNCTIONAL-supporting · manual-visual
**Purpose** Q66 placement. **Steps** 1. Open Settings → Support → Licensing (الدعم → التراخيص). **Expected** Every bundled/premium font lists license (OFL 1.1), attribution, foundry, commercial status, character coverage, source link; entries match the captured license files in the repo; no license text invented.

**T-FNT-8 · Character coverage reporting** — Phase P9 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. For each shipped font compute coverage of: Arabic block, tashkeel U+064B–065F, U+0670, Qur'anic annotations U+06D6–06ED. **Expected** Coverage table generated and surfaced in catalog metadata; fonts lacking the annotation range are marked so T-AR-24/25 skip them knowingly; typing an uncovered codepoint triggers the documented fallback policy (fallback font or visible notice), never invisible glyphs.

**T-FNT-9 · Expiry font locking** — Phase P11 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF Q27/D-119. **Steps** 1. On FIX-PREMIUM with expired entitlement (see T-SK-10): open the project. 2. Attempt to edit text set in a premium font and in a user-imported font. **Expected** Objects still display (last cached shaping) with a lock badge (قفل); re-shaping/edit in the locked font is blocked with replace-or-subscribe options; switching the object to a free font unlocks editing; nothing is deleted.

**T-FNT-10 · Font used across app relaunch and project share** — Phase P9 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Use an imported font in a project; relaunch (re-registration); simulate opening the same project on a device without that font (delete it from the container). **Expected** Relaunch renders correctly; missing-font open shows the documented missing-font flow (placeholder render + Arabic warning listing the font name), scene data intact.

---

## 11. T-EXP — Export pipeline (P10)

**T-EXP-1 · Single render path parity** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-118: export renders the same scene snapshot as canvas — never screen capture. **Steps** 1. Render FIX-ARABIC to (a) canvas-resolution bitmap via MKRender preview path and (b) PNG export at identical dimensions. **Expected** Pixel-identical output (tolerance 0); test fails if export ever consults UIKit view hierarchy.

**T-EXP-2 · Free-tier 2 MP cap enforcement** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. As free user export a 4096×4096 project to JPEG and PDF. **Expected** Output ≤2 MP effective (e.g. ~1414×1414 for square), aspect preserved; UI communicates the cap with upgrade path; no PNG/SVG/print-PDF options visible/enabled for free tier.

**T-EXP-3 · Premium format matrix** — Phase P10 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. As premium, export FIX-TYPICAL to opaque PNG, transparent PNG, SVG, print PDF, JPEG. **Expected** All succeed; dimensions honored exactly (custom W×H field); export history rows written with format/dims/date; files valid per format sniffers (libpng, XML parse, PDF header).

**T-EXP-4 · Preset list correctness** — Phase P10 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF presets bullet. **Steps** 1. Enumerate presets (social square/portrait, story, static-reel, messaging-status, wallpaper, print A-series) at 2 MP baseline; premium custom exact dimensions. **Expected** Each preset's aspect + free-tier pixel count ≤2 MP; premium custom accepts arbitrary dims subject only to memory guard (T-MEM-5); Arabic labels correct.

**T-EXP-5 · Tiled huge-raster export** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-116/D-118: output bounded by disk, not RAM. **Steps** 1. Export a 12000×12000 PNG on `SIM` with a 500 MB memory ceiling harness; verify strip rendering via `export.tile` signposts. **Expected** Peak memory stays under harness ceiling; strips stitch seamlessly (checksum vs. single-pass render of a small region); cancel mid-export cleans temp files.

**T-EXP-6 · Transparent PNG alpha correctness (automated twin of T-AR-53)** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Export glyph on transparent bg; assert corner pixels alpha=0 with RGB=0 (non-premultiplied leak check); edge pixels partial alpha. **Expected** As stated; opaque variant fully opaque alpha=255 everywhere.

**T-EXP-7 · SVG serializer structural contract** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-118 SVG rules are machine-checkable. **Steps** 1. Export the T-AR-54 fixture; parse XML. **Expected** Live Text (OFL font) → `<text>` with correct `direction`/`unicode-bidi` and @font-face when allowed; Arranged nodes → `<g><path>` with `data-mk-source-text`, `data-mk-codepoints`, `data-mk-font` attributes; document validates against SVG 1.1/2 well-formedness; viewBox matches canvas.

**T-EXP-8 · PDF text embedding per license switch** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Export print PDF containing OFL-font live text and a (test-flagged) non-embeddable-font text. **Expected** OFL text = live text with subset font embed (verify font object in PDF); non-embeddable = outlined paths + export-summary disclosure; per-license switch table read from font metadata, not hardcoded.

**T-EXP-9 · CMYK conversion numeric contract** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** Automated twin of T-AR-56 (D-117/D-226). **Ground truth** Per D-226(2), expected CMYK values are NOT hand-derived: they are computed once with an external ICC-aware tool (littleCMS `transicc` or Argyll `xicclu` — exact tool recorded at implementation) using the same profile and relative colorimetric intent as the shipped pipeline, then checked into the fixture corpus as the reference values this test compares against. **Steps** 1. Convert reference sRGB swatches (pure K-black, rich red #C22326, white) through the shipped ICC path via MKColor. 2. Compare to the checked-in external-tool-derived expected CMYK values for the FD-03 profile (or Apple Generic CMYK fallback), tolerance ±1 %. **Expected** Values match; relative colorimetric intent used; profile bytes embedded in PDF OutputIntent (parse check).

**T-EXP-10 · Premium-content gating at export** — Phase P11 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-119. **Steps** 1. As free user open FIX-PREMIUM (contains premium font + photo background); attempt export. **Expected** Export blocked with replace-or-subscribe flow (استبدال أو اشتراك); after replacing premium font with free font AND removing photo background, free JPEG export proceeds; "premium content present" project flag updates live.

**T-EXP-11 · Export determinism across runs** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Export the same scene snapshot twice to PNG. **Expected** Byte-identical output (stable render order, no timestamps in pixels) — guards against race conditions in the concurrent renderer (D-102).

**T-EXP-12 · Export during low storage** — Phase P10 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Fill simulator disk to near-capacity; export 4K PNG. **Expected** Clean typed failure with Arabic message («لا توجد مساحة تخزين كافية»), temp files removed, app stable, project untouched.

**T-EXP-13 · Out-of-gamut discriminator (#00FF00) intent divergence** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-226(3): a fully saturated out-of-gamut primary must produce CMYK results that visibly differ under different rendering intents — proof the pipeline is doing real gamut mapping, not silently clamping/ignoring intent. **Steps** 1. Convert sRGB #00FF00 (fully saturated green, out of gamut for the shipped CMYK profile) through the MKColor export path under `.relativeColorimetric`. 2. Convert the same swatch under `.perceptual`. **Expected** The two resulting CMYK values differ by more than the ±1 % tolerance used in T-EXP-9 (asserts intent-dependent gamut mapping is actually occurring); the `.relativeColorimetric` result matches the T-EXP-9 external-tool ground truth within tolerance.

**T-EXP-14 · Rendering-intent divergence unit test** — Phase P10 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-226(5): a direct unit-level check, below the export pipeline, that MKColor's intent parameter actually changes output for a boundary (near-gamut-edge) color — distinct from T-EXP-13's full-pipeline discriminator fixture. **Steps** 1. Call the `MKColor` conversion function directly with a boundary sRGB color (e.g. #00FF00) passing `.perceptual`. 2. Call it again with `.relativeColorimetric`. **Expected** The two CMYK tuples differ by more than rounding tolerance, proving the intent parameter is wired through to the underlying ColorSync/ICC call rather than ignored; this is a fast unit test with no PDF/export machinery involved.

**T-EXP-15 · Duplicate-as-expired-user inherits premium-content gating** — Phase P11 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-229(5): duplicating a premium-content project must inherit the `premiumContentPresent` flag and its resulting locks — the duplicate is not a loophole around gating. **Steps** 1. As premium user, build a project using a premium font and a photo background (FIX-PREMIUM style); duplicate it (T-MDL-9 duplicate op). 2. Let entitlement expire (T-SK-10) or switch to a free-tier test account. 3. Open the DUPLICATE. **Expected** The duplicate's `premiumContentPresent` flag is `true` exactly like the original; export is blocked with the same replace-or-subscribe flow as T-EXP-10; font/photo locks (T-FNT-9) apply identically to the duplicate.

**T-EXP-16 · Hidden premium layer still blocks export (presence-based walk)** — Phase P11 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-229(1): the `premiumContentPresent` walk iterates ALL nodes in the snapshot regardless of `isHidden`/`isLocked` — presence-based, not render-based. **Steps** 1. Build a project whose ONLY premium content (a premium-font Live Text object) is set `isHidden = true`. 2. As a free/expired user, compute `premiumContentPresent` and attempt export. **Expected** `premiumContentPresent` is `true` despite the node being hidden and excluded from the visible render; export is blocked via the same replace-or-subscribe flow as T-EXP-10 — a hidden premium layer is not a way to sneak premium content into a free-tier export.

---

## 12. T-SK — StoreKit 2, trial, entitlements (P11)

All tests run first against the checked-in `Makhtoot.storekit` configuration file
(products: `net.binjamshid.makhtoot.premium.monthly` $2.99, `.premium.annual` $29.99 in
subscription group "Makhtoot Premium"; `.premium.lifetime` $89.99 non-consumable (D-216) —
placeholder ids per FOUNDATION §0). Tests marked **[SANDBOX]** are re-run against App
Store sandbox with a sandbox Apple account before P15 exit. Time-based scenarios use
the StoreKit config's subscription-renewal-rate acceleration and Xcode Transaction
Manager.

**T-SK-1 · Products load and display localized prices** — P11 · STOREKIT · xcodebuild-testable
**Steps** 1. `Product.products(for:)` with the three ids. **Expected** All three load; paywall shows title, duration, and localized price string from StoreKit (never hardcoded "$3"); Arabic paywall copy includes price+term adjacent to CTA (App Review 3.1.2 hygiene, cross-ref APP_STORE_CHECKLIST).

**T-SK-2 · Purchase monthly** — P11 · STOREKIT [SANDBOX] · simulator-scriptable
**Steps** 1. From `free`/`trial` state purchase monthly; approve. **Expected** `Transaction` verified (JWS `VerificationResult.verified`), entitlement state → `subscribed`, premium features unlock immediately (fonts, PNG/SVG export, photo bg, sync toggle) without relaunch; finish() called; UI banner confirms.

**T-SK-3 · Purchase annual** — P11 · STOREKIT [SANDBOX] · simulator-scriptable
**Steps** As T-SK-2 with annual. **Expected** Same; subscription group shows annual as active plan.

**T-SK-4 · Purchase lifetime** — P11 · STOREKIT [SANDBOX] · simulator-scriptable
**Steps** 1. Purchase the non-consumable. **Expected** State → `lifetime`; paywall permanently replaced by a "premium forever" state (بريميوم مدى الحياة); no renewal UI anywhere; repurchase attempt surfaces "already purchased" restore path.

**T-SK-5 · Upgrade/crossgrade monthly ⇄ annual** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. With monthly active, purchase annual (same group → StoreKit plan change). 2. Reverse: annual → monthly (downgrade at period end). **Expected** Upgrade applies per StoreKit group ranking (immediate or at renewal per configuration); entitlement never lapses during change; UI states the effective date; no double-charge state confusion.

**T-SK-6 · Lifetime purchased while subscribed (precedence)** — P11 · STOREKIT · simulator-scriptable
**Purpose** D-113 precedence lifetime > subscribed. **Steps** 1. With annual active, buy lifetime. 2. Let the subscription lapse/cancel in Transaction Manager. **Expected** State remains `lifetime` throughout; UI guides the user to cancel the now-redundant subscription (link to manage subscriptions); expiry of the sub never downgrades any feature.

**T-SK-7 · Restore purchases on second device** — P11 · STOREKIT [SANDBOX] · simulator-scriptable
**Steps** 1. Purchase lifetime on simulator A (sandbox account). 2. On clean simulator B signed into the same account, tap مستعادة المشتريات (Restore). **Expected** `AppStore.sync()`/current-entitlements path restores `lifetime` with no re-payment; restore UI is reachable from paywall AND settings (3.1.2(c)); failure path (no purchases) shows a clear Arabic message.

**T-SK-8 · Interrupted purchase** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. Enable "Interrupted Purchases" in the StoreKit configuration; attempt monthly purchase; then resolve the interruption in Transaction Manager. **Expected** App handles `.pending` gracefully (paywall state "بانتظار التأكيد", no premium yet); when the transaction later arrives via `Transaction.updates`, premium unlocks without user action; no duplicate entitlement records.

**T-SK-9 · Ask-to-Buy / deferred** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. Simulate Ask to Buy approval flow in the config. **Expected** Same contract as T-SK-8 pending path; decline leaves state unchanged with polite Arabic notice.

**T-SK-10 · Expiry** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. With accelerated renewal rate, cancel auto-renew; let the period elapse. **Expected** State → `free` exactly at expiration (observed via `Product.SubscriptionInfo.Status` stream); premium fonts lock (T-FNT-9), photo backgrounds lock, export matrix reverts to free (T-EXP-10); projects remain fully viewable/editable otherwise (Q27/Q41); expiration messaging shown once, not nagging.

**T-SK-11 · Grace period simulation** — P11 · STOREKIT · simulator-scriptable
**Purpose** D-113: grace retains premium + banner. **Steps** 1. Enable Billing Grace Period in the .storekit file; trigger a failed renewal (Billing Issue in Transaction Manager). **Expected** State → `inGracePeriod`; ALL premium features keep working; persistent but non-blocking banner «مشكلة في الفوترة — حدّث وسيلة الدفع» deep-links to Apple subscription management; exact grace duration is NOT hardcoded in copy (VERIFY-AT-SUBMISSION per BRIEF research gaps).

**T-SK-12 · Billing retry** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. Continue past grace into billing-retry state. **Expected** State → `inBillingRetry` (still premium per D-113 precedence, with banner); when retry succeeds (resolve in Transaction Manager) state returns to `subscribed` and banner clears; when retry ultimately fails, clean transition to `free` + T-SK-10 behaviors.

**T-SK-13 · Revocation / refund** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. Refund an active transaction in Transaction Manager (revocationDate set). **Expected** `Transaction.updates` delivers the revoked transaction; entitlement recomputed immediately → `free` (or lower active tier); locked-content behaviors engage; no crash if revocation arrives mid-export: per D-228(2) an export already rendering COMPLETES (the gate is not re-evaluated mid-render); the NEXT export attempt re-evaluates entitlement and is gated/blocked per the now-lower tier.

**T-SK-14 · Trial state machine at first launch** — P11 · STOREKIT · xcodebuild-testable
**Purpose** D-123 app-side 7-day trial from FIRST launch, monthly+annual scope. **Steps** 1. Fresh install (clean Keychain/KVS harness); launch. **Expected** Trial record created (start timestamp) in Keychain with `kSecAttrAccessibleAfterFirstUnlock` + mirrored to iCloud KVS; state `trial(daysLeft: 7)`; full premium features during trial; countdown surfaces in settings/paywall; day 8 → `expired`→`free` behaviors.

**T-SK-15 · Trial persistence across delete + reinstall** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. Start trial; advance mock clock 3 days; delete app; reinstall; launch. **Expected** Keychain-surviving record found; trial resumes at 4 days left — NOT reset to 7; if Keychain was wiped but iCloud KVS has the record, KVS restores it.

**T-SK-16 · iCloud KVS reconciliation across devices (incl. delayed retroactive shrink)** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. Device A starts trial at T0. 2. Device B (same iCloud) first-launches 2 days later, briefly creating a local T0+2 record; KVS syncs. 3. Delayed-merge case (DF-8): Device B runs a session showing daysLeft computed from its own local T0+2 record because the KVS sync is artificially delayed/offline; mid-session, the delayed KVS update finally arrives carrying A's earlier T0. **Expected** Earliest timestamp wins on both devices (D-123); no device ever shows more days than A's schedule; conflict resolution logged. Delayed-merge case: when the late KVS update arrives mid-session, B's displayed daysLeft RETROACTIVELY SHRINKS to match the earlier T0 (the more generous local value is never silently kept); the shrink applies without requiring an app relaunch; if the recomputed state is already `expired`, premium features lock immediately mid-session per T-SK-10 rather than waiting for the next launch.

**T-SK-17 · Wall-clock high-water mark + uptime cross-check guard** — P11 · STOREKIT · xcodebuild-testable
**Purpose** D-224 amends D-123/D-211 terminology: "monotonic guard" is corrected to "wall-clock high-water mark + uptime cross-check". The reserved `lastObservedBoottime` field is wired: on every observation, elapsed `ProcessInfo.systemUptime` since first launch is compared against elapsed wall-clock time; if uptime-elapsed exceeds wall-clock-elapsed beyond tolerance, uptime-elapsed is authoritative for trial aging. **Steps** 1. Start trial; advance 6 days; roll the device clock back 30 days (app stays running / same boot session throughout); relaunch. 2. Sustained pre-launch rollback (DF-8/D-224 extension): with the app NOT running, roll the clock back within the SAME boot session (no reboot in between), then launch for the first time since the rollback. **Expected** Case 1: the wall-clock high-water mark refuses to extend the trial — trial still shows ≤1 day left (never recomputed upward); rolling the clock forward again does not double-penalize; tamper events logged locally only. Case 2 (sustained pre-launch rollback): because `ProcessInfo.systemUptime` keeps advancing continuously within the boot session even while the app isn't running, the uptime cross-check at first post-rollback launch still catches the discrepancy (uptime-elapsed exceeds wall-clock-elapsed) and the guard holds — trial aging is not extended. **Documented residual (expected-fail, honest note per D-211/D-224)**: a device REBOOT between the clock rollback and relaunch resets `systemUptime` to zero, defeating the uptime cross-check for that session; this is a known, accepted residual, not a test failure — record it as an explicit non-blocking observation rather than asserting pass/fail on it.

**T-SK-18 · Entitlement resolver precedence table (full 3-axis matrix)** — P11 · STOREKIT · xcodebuild-testable
**Purpose** D-113 total ordering, extended by D-228 to the full realizable combination space across three axes: (1) lifetime {present, absent}; (2) subscription state {subscribed, grace, billingRetry, expired, none}; (3) trial state {active with daysLeft>0, expired, never-started}. **Steps** 1. Unit-drive `MKEntitlementResolver` with every REALIZABLE combination of the three axes (document which combinations are excluded as impossible, e.g. states requiring a purchase record with no purchase having occurred), including explicitly: {lifetime+expired sub}, {grace+trial active}, {billingRetry+trial active}, {billingRetry+free/no trial}, {trial active with daysLeft>0 + expired sub} (D-228(3) re-entry case: subscription lapsed/refunded within the still-open 7-day trial window), {trial only}, {nothing}. **Expected** Resolved state follows lifetime > subscribed > grace > billingRetry > trial > free in every combination; the grace-over-trial ordering holds even when an active trial with days remaining is also present (D-228(4): billing problems surface immediately rather than being masked by the trial cushion, since grace is time-boxed and fixing payment preserves continuity); the trial+expired-sub-with-days-left case confirms trial re-entry is intended behavior — the active trial chip takes copy precedence over "expired (was premium)" per D-228(3), and the residual this creates (bounded, ≤7 days) is the one already recorded against D-211; resolver is the SINGLE source consumed by fonts/export/sync gates (verify via dependency check — no other module reads Transaction APIs directly).

**T-SK-19 · Offline entitlement behavior** — P11 · STOREKIT · simulator-scriptable
**Steps** 1. Go premium; enable airplane mode; relaunch; use premium features; attempt a new purchase. **Expected** Cached entitlements keep premium fully working offline (StoreKit local transaction store); new purchase fails gracefully with Arabic offline message; no spurious downgrade to free while offline.

**T-SK-20 · Referral module inert (flag OFF)** — P11 · STOREKIT · xcodebuild-testable
**Purpose** D-124: compiled but dead. **Steps** 1. Build with default flags; scan UI for referral surfaces; call the referral API guard in tests. **Expected** No UI path reachable; API returns disabled; `MKFeatureFlags.referralProgram == false` by default; flipping the local flag in a debug build exposes the flow (smoke only — feature remains non-shipping per FD-05).

**T-SK-21 · Post-lifetime-purchase redundant-subscription sheet** — P11 · STOREKIT · simulator-scriptable
**Purpose** D-228(1): on a successful lifetime purchase while an active/grace/billingRetry subscription exists, an immediate ONE-TIME sheet (not just a Settings string) prompts subscription cancellation with a working manage-subscriptions deep link. **Steps** 1. With an annual subscription `subscribed`, purchase lifetime; observe immediately after purchase completion. 2. Repeat starting from `inGracePeriod`. 3. Repeat starting from `inBillingRetry`. 4. Dismiss the sheet each time, then relaunch and separately revisit Settings. **Expected** In all three starting states the sheet appears exactly once immediately after the lifetime purchase completes, contains a working manage-subscriptions link, and does NOT reappear on relaunch or on revisiting Settings (one-time, not nagging — distinct from T-SK-6's persistent Settings-level link); state remains `lifetime` throughout (cross-ref T-SK-6 precedence).

---

## 13. T-SYN — CloudKit sync (P12)

Environment: two simulators (or device+simulator) signed into the same test iCloud
account, CloudKit dev environment, premium entitlement active via .storekit file.

**T-SYN-1 · Initial upload and second-device materialization** — P12 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Device A (premium): create project «مشروع المزامنة», save. 2. Wait for CKSyncEngine push; launch device B, enable sync. **Expected** Project appears on B with identical scene (checksum manifest+scene payloads), assets transferred as CKAssets; thumbnails regenerate; sync status UI reflects progress.

**T-SYN-2 · Concurrent edit → conflict copy** — P12 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-112 last-writer-wins + conflict copy. **Steps** 1. Both devices offline; edit the SAME project differently on each; bring both online. **Expected** Later writer's version wins under the original name; the losing version is preserved as a new project suffixed «(نسخة متعارضة)»; NO silent data loss; both open cleanly.

**T-SYN-3 · Non-conflicting multi-project sync** — P12 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. A edits project 1; B edits project 2; both online. **Expected** Both changes propagate; no conflict copies generated.

**T-SYN-4 · Account sign-out and switch** — P12 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. With sync active, sign out of iCloud in simulator Settings; use app; sign into a DIFFERENT account. **Expected** Sign-out: sync pauses with clear Arabic status («المزامنة متوقفة — سجّل الدخول إلى iCloud»); local projects untouched; account switch follows the documented policy (local data kept local; no cross-account leakage of the previous account's server data).

**T-SYN-5 · Quota exceeded / server errors** — P12 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Inject `CKError.quotaExceeded`, `.networkFailure`, `.serverRejectedRequest`, `.zoneBusy` into the sync engine via a mock transport. **Expected** Each maps to the documented retry/backoff or user-facing Arabic message (quota: «مساحة iCloud ممتلئة»); engine never wedges (subsequent success resumes); no partial-record corruption.

**T-SYN-6 · Entitlement lapse mid-sync (incl. expiry during active 80 MB upload)** — P12 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Premium expires (T-SK-10) while changes are queued (small edits, not yet uploading). 2. DF-8 extension: premium expires WHILE the T-SYN-7 80 MB asset upload is actively in-flight (mid-CKAsset-chunk-transfer). **Expected** Case 1: sync stops per gating policy with clear status; local edits keep saving locally; re-subscribing resumes and reconciles the queue. Case 2: the in-flight 80 MB upload is not left corrupted or duplicated — either the current chunk transfer completes and sync then halts, or the transfer aborts cleanly with no partial CKAsset left server-side (document which the engine actually does); re-subscribing resumes the upload from where it left off without re-transferring already-confirmed chunks; the local project stays fully intact throughout.

**T-SYN-7 · Large-asset project sync** — P12 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Sync a project with 80 MB of image assets. **Expected** CKAsset chunked transfer completes; progress UI accurate; airplane-mode interruption mid-transfer resumes without duplicating assets.

**T-SYN-8 · Sync never touches free users** — P12 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. As free user, monitor network + CK containers during full app use. **Expected** Zero CloudKit private-DB traffic; sync toggle hidden/disabled with premium upsell; (cross-ref T-OFF/T-ANL network audits).

**T-SYN-9 · Account switch-back A→B→A (no spurious conflict copies)** — P12 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** DF-8: extends T-SYN-4's account-switch coverage to a switch-BACK scenario, which is where naive conflict detection tends to misfire. **Steps** 1. Signed into account A, sync project «تبديل الحساب»; sign out. 2. Sign into account B (a different iCloud test account) without touching the same-named project. 3. Sign back into account A. **Expected** Account A's local/synced state for the project reconciles against A's CloudKit zone by CONTENT HASH — since nothing actually changed while on B, no conflict copy is created; the project reappears exactly as it was, with no duplicate «(نسخة متعارضة)» project and no re-upload of unchanged assets (verify via network capture that the content-hash match short-circuits the transfer).

**T-SYN-10 · Sync engine-entry entitlement gate (stale-free device cannot enable sync)** — P12 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-229(4): `MKSyncService` gains an entitlement gate at engine-start, mirroring `MKExportGate` — engine start requires a non-free resolved entitlement state; a device with a stale locally-cached `free` state cannot start syncing/pulling until entitlement resolves. **Fixtures** A fresh-install device signed into the SAME iCloud account as an existing premium device, but whose local entitlement resolver has not yet resolved past `free` (e.g. StoreKit local transaction store not yet queried, or a stale cached free result). **Steps** 1. On the fresh-install device, attempt to enable sync / trigger a CKSyncEngine pull before the entitlement resolver has resolved to a non-free state. 2. Allow entitlement resolution to complete (e.g. `AppStore.sync()` / current-entitlements path resolves to `subscribed`/`lifetime`). 3. Retry enabling sync. **Expected** Step 1: the sync engine refuses to start (no CloudKit private-DB traffic initiated) while the resolved state is `free`, mirroring `MKExportGate`'s behavior; UI shows the same offline/gated status class as other premium-gated features. Step 3: once entitlement resolves to a paid state, the engine starts normally and materializes the account's synced projects (T-SYN-1 path).

---

## 14. T-ANL — Analytics consent & privacy (P13)

**T-ANL-1 · Opt-in default OFF** — P13 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-125/Q79. **Steps** 1. Fresh install; read consent state; inspect Settings toggle. **Expected** Consent = off; toggle off; consent record absent until the user acts; enabling writes a VERSIONED consent record (version, date) to SwiftData metadata.

**T-ANL-2 · Nothing uploads without consent** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. With consent off, use fonts heavily for a session; run a network capture (mitm proxy or CK telemetry hook) for the whole session incl. background flush windows. **Expected** ZERO analytics network traffic (no CloudKit public-DB writes); on-device counters may accumulate locally per documented design, but nothing leaves the device.

**T-ANL-3 · Payload contains no identifiers** — P13 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-125 payload contract. **Steps** 1. With consent on, trigger a batch build; intercept the CKRecord before upload in a test seam. **Expected** Fields are exactly: random ephemeral batch UUID (not stable across batches), fontID → bucketed usage counts, week-granularity period. NO user record link, no device ids, no vendor ids, no timestamps finer than week, no text, no project data, no font files. Schema snapshot test fails on any added field.

**T-ANL-4 · Consent withdrawal** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Enable consent, generate data, then disable. **Expected** Uploads stop immediately; pending unsent batches discarded per documented policy; local counters handling (kept or cleared) matches the PRD §18 statement; re-enabling starts a fresh consent record version.

**T-ANL-5 · Kill switch (local flag + CloudKit remote record)** — P13 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Purpose** D-207: the kill switch has two layers — the local `MKFeatureFlags` build-time flag AND a CloudKit public-DB `analyticsEnabled` record read at upload time (a remote, serverless stop mechanism), independent of the user's local consent toggle. **Steps** 1. Flip the local kill switch flag (`MKFeatureFlags`); attempt an upload. 2. With the local flag on and consent on, set the CloudKit public-DB `analyticsEnabled` record to `false`; attempt an upload. 3. Go offline with no cached record value (first-ever check); attempt an upload. 4. Go offline with a cached last-known `false` value; attempt an upload. **Expected** Case 1: entire MKAnalytics pipeline inert regardless of consent; UI toggle hidden or disabled. Case 2: upload is blocked purely by the remote record even though the local flag and consent both permit it (proves the remote stop actually gates the network call, not just the UI). Case 3: offline with no cached value defaults to enabled (last-known-value, default-enabled per D-207) — upload proceeds if consent is on. Case 4: offline with a cached `false` last-known value — upload stays blocked using the cached value.

**T-ANL-6 · Aggregation correctness** — P13 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Simulate 1 000 font-use events across 5 fonts; build batch. **Expected** Counts bucketed per D-125 bucket table (exact buckets defined in ARCHITECTURE §21); raw event log never persisted beyond aggregation window.

---

## 15. T-PRF — Performance budgets (D-115, measured; P14 gate)

Every test below encodes a D-115 number verbatim. Method column contracts: Instruments
templates run from Xcode 16 on release-configuration builds; XCTest `measure` blocks
use `XCTOSSignpostMetric` bound to the §1.5 signpost names plus `XCTClockMetric`/
`XCTMemoryMetric`; MetricKit corroborates in TestFlight. Minimum 5 runs; report
median + worst; gate on the stated statistic.

**T-PRF-1 · Manipulation frame time — ProMotion ≤8.3 ms** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** `frame.manipulate` P95 ≤ **8.3 ms** on `DEV-PRO` and `DEV-M` at 120 Hz. **Fixtures** FIX-TYPICAL and FIX-HEAVY. **Steps** 1. Scripted 10 s session: continuous drag of a 20-node multi-selection, pinch-zoom, rotate of an Arranged Composition. 2. Instruments: os_signpost + Animation Hitches templates; record `frame.manipulate` interval distribution and hitch time ratio. **Expected** P95 ≤8.3 ms on FIX-TYPICAL (gate); FIX-HEAVY result recorded — if over budget, degradation ladder must be engaging (verify `memory.stage`/fidelity events) rather than raw jank; hitch time ratio <5 ms/s.

**T-PRF-2 · Manipulation frame time — A12 floor ≤16.6 ms** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** `frame.manipulate` P95 ≤ **16.6 ms** on `DEV-A12` at 60 Hz. **Steps** Same script as T-PRF-1 on the A12 device. **Expected** P95 ≤16.6 ms on FIX-TYPICAL; zero frames >33 ms during the scripted session (no visible double-frame hitches); Time Profiler capture attached to evidence for any near-miss.

**T-PRF-3 · Typing echo <50 ms** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** keystroke → visible glyph **<50 ms** (`typing.echo` interval), all matrix devices. **Steps** 1. Debug hook injects 50 keystrokes of «الخط العربي بخط أميري» at 8 char/s into an in-canvas editing session (D-104 overlay live); signpost measures commit-to-glyph-visible per keystroke. 2. Repeat inside a 500-node project. **Expected** Median and P95 <50 ms on every matrix device including `DEV-A12`; tashkeel long-press insertion also within budget.

**T-PRF-4 · Shaping capture latency (supporting)** — P14 · Gate PERF · xcodebuild-testable
**Budget** `shape.line` for a 200-character fully vocalized line ≤10 ms on `DEV-A15` (engineering sub-budget so T-PRF-3 holds). **Steps** 1. XCTest `measure(metrics: [XCTClockMetric, XCTOSSignpostMetric(...)])` around MKTextEngine shaping of the T-AR-21 string ×8 concatenated. **Expected** Median ≤10 ms; 10 000-char paragraph (T-TXT-11) shapes <250 ms (no pathological scaling).

**T-PRF-5 · Open typical project <1 s** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** `doc.open` for FIX-TYPICAL (≤100 nodes) < **1 s** to first interactive frame, all matrix devices (gate on `DEV-A12` worst case). **Steps** 1. Cold-launch app; open FIX-TYPICAL 5×; Instruments os_signpost + App Launch template. **Expected** Median <1 s on every device; "interactive" = gestures accepted and first full-fidelity render done (signpost end condition documented in code).

**T-PRF-6 · Open heavy project <3 s** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** `doc.open` for FIX-HEAVY (5 000 nodes) < **3 s**. **Steps** As T-PRF-5 with FIX-HEAVY. **Expected** Median <3 s on `DEV-A15` and `DEV-M`; `DEV-A12` recorded (target <3 s; if exceeded, progressive-render behavior must show canvas skeleton + spinner per D-116 spirit and the result is escalated at P14 review — the budget itself remains the gate on A15/M).

**T-PRF-7 · Incremental autosave <100 ms off main thread** — P14 · Gate PERF · xcodebuild-testable
**Budget** `autosave.incremental` < **100 ms**, and **0 ms** of it blocking the main thread. **Steps** 1. XCTest: mutate 10 nodes in FIX-TYPICAL; trigger debounced autosave; measure signpost interval ×20. 2. Main-thread audit: Time Profiler main-thread file-IO samples during autosave storm (mutate every 300 ms for 30 s). **Expected** Median <100 ms on `DEV-A15`; no `MKPersistence` write path frames on the main thread; UI frame time unaffected during storm (cross-check `frame.manipulate`).

**T-PRF-8 · Autosave storm integrity under load** — P14 · Gate FUNCTIONAL-supporting · xcodebuild-testable
**Steps** 1. Continuous mutations for 60 s with autosave debounce firing; kill process at random point; reopen. **Expected** Journal replay recovers to within the last ≤2 s of mutations (D-112); no corruption ever.

**T-PRF-9 · 4K PNG export <10 s on A15** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** `export.render` for FIX-4K → 4096×4096 opaque PNG < **10 s** on `DEV-A15`. **Steps** 1. Export 5×; signpost timing; also record on `DEV-M` (expected faster) and `DEV-A12` (recorded, not gated). **Expected** Median <10 s on A15; per-tile times roughly uniform (no quadratic tail); result file passes T-EXP-6 checks.

**T-PRF-10 · Peak editor memory <60 % before degradation** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** editor peak memory < **60 % of `os_proc_available_memory()`** before ladder stage 1 engages (D-115/D-116). **Steps** 1. On `DEV-A12` (worst RAM class): open FIX-HEAVY, zoom cycle, arrange a 500-glyph text, place 10 images. 2. Instruments Allocations + VM Tracker; app logs `os_proc_available_memory` snapshots + `memory.stage` events. **Expected** While no `memory.stage` event has fired, footprint stays <60 % of available; stage-1 fires no later than the 70 % threshold (T-MEM-1); no jetsam termination during the scenario.

**T-PRF-11 · Zoom re-raster latency (supporting)** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** After pinch-zoom settles at 400 % on FIX-TYPICAL, full-fidelity re-raster completes ≤150 ms on `DEV-A15` (engineering budget backing D-114 crispness without jank). **Steps** Signpost around the re-raster pass; 10 zoom cycles. **Expected** Median ≤150 ms; during re-raster, interaction stays ≥60 Hz using the stale-scale bitmap.

**T-PRF-12 · Arrange derivation latency (supporting)** — P14 · Gate PERF · xcodebuild-testable
**Budget** `arrange.derive` for a 500-glyph vocalized text ≤500 ms on `DEV-A15` (mode switch must feel instant-ish; number is the engineering target backing PRD §6 UX). **Steps** XCTest measure around MKArrange derivation. **Expected** Median ≤500 ms; linear scaling verified at 50/500/2000 glyphs.

**T-PRF-13 · Cold launch to browser <1 s on A15** — P14 · Gate PERF · simulator-scriptable (device-run)
**Budget** cold launch → interactive project browser < **1 s** median on `DEV-A15`-class devices (Gate PERF, per D-115 as amended by D-218); ≤2 s on `DEV-A12` retained as the worst-device supporting budget. **Steps** App Launch template, 5 cold launches on `DEV-A15` and `DEV-A12`. **Expected** Median <1 s on `DEV-A15`; median ≤2 s on `DEV-A12`; font registration (T-FNT-1) off the critical path or within budget.

**T-PRF-14 · Sustained session leak check** — P14 · Gate FUNCTIONAL-supporting · simulator-scriptable (device-run)
**Steps** 1. 30-minute scripted mixed session (edit, arrange, export, browse) on `DEV-A15`; Instruments Leaks + Allocations generations. **Expected** No unbounded growth across generations (steady-state after caches warm); zero leaks from MK* modules; memory returns near baseline after closing the project.

---

## 16. T-MEM — Memory pressure & recovery (P14, ladder D-116)

**T-MEM-1 · Stage 1 (70 %): caches dropped + autosave** — P14 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Harness inflates memory to cross 70 % of `os_proc_available_memory` while editing FIX-HEAVY (or `simctl spawn ... memory_pressure` where applicable; on-device use the debug ballast allocator). **Expected** `memory.stage` stage-1 event; instrumentation proves ORDERING: the immediate autosave (T-MDL-5 path) COMPLETES before offscreen bitmap cache eviction begins (signpost/timestamp evidence — not merely "both eventually happen"); Allocations shows the cache drop occurring after the autosave-complete timestamp; zero user-visible change on screen.

**T-MEM-2 · Stage 2 (85 %): degrade + banner** — P14 · Gate MANUAL-ARABIC · manual-visual
**Steps** 1. Continue ballast to 85 %. **Expected** Instrumentation proves the autosave implied by the banner text (تم الحفظ تلقائيًا) actually COMPLETES before fidelity degradation begins (signpost timestamps comparing `autosave.incremental` completion vs. degrade-start — not just that the banner text says so); preview fidelity then degrades (half-res layer bitmaps, simplified shadows) smoothly; the exact banner «الذاكرة شبه ممتلئة — تم الحفظ تلقائيًا» appears (string must match D-116 verbatim); editing remains functional; releasing ballast restores full fidelity.

**T-MEM-3 · Stage 3 (critical): synchronous journal-only flush** — P14 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-223: on stage-3/critical, `MKPersistence` performs a synchronous JOURNAL flush ONLY — append-only, no full-scene re-encode, no new large allocations; full-scene `flushNow()` is reserved for stages 1–2 and the normal debounced path. **Steps** 1. Drive a critical memory-pressure event (DispatchSource critical) while editing FIX-HEAVY. 2. Instrument `MKPersistence` calls during the critical window. **Expected** Exactly one journal append-flush occurs and completes before any termination; NO `scene.json` re-encode occurs and no allocation above a documented small ceiling is observed during the window (Allocations trace attached as evidence); instrumentation proves write-completion ordering — the journal flush completes before eviction/termination can proceed.

**T-MEM-4 · Kill mid-edit, relaunch, no loss** — P14 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF "no-loss recovery after termination". **Steps** 1. Perform 5 rapid edits incl. an in-progress drag; `kill -9` the process within the 2 s debounce window; relaunch; open project. **Expected** All committed edits restored via journal (the in-flight uncommitted drag may revert to its last committed state per D-112 — document observed behavior); recovery is silent or one concise Arabic notice; repeat 10× with zero corruption.

**T-MEM-5 · Huge-export memory guard** — P14 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** Q76: no artificial caps, warn near limits. **Steps** 1. Premium custom export at absurd dimensions (e.g. 30000×30000) on `DEV-A12`. **Expected** App warns about memory limits BEFORE starting (Q76 language), offers proceed/cancel; proceeding uses tiled strips (T-EXP-5) and either completes or fails cleanly with autosave intact — never a silent OOM kill without prior autosave.

**T-MEM-6 · Pressure during export (incl. stage-3-during-export)** — P14 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** D-223's export-under-pressure policy, now written: strip sizing is static (64 MB budget, never shrunk mid-export — supersedes the struck D-210 "monitor can shrink strip height mid-export" claim). **Steps** 1. Trigger stage-2 pressure while a 4K export runs; observe behavior. 2. Trigger stage-3 (critical) pressure while a 4K export runs, mid-strip. **Expected** Stage-2: export continues uninterrupted at the static 64 MB strip budget (no strip-height shrink); editor autosaves per the T-MEM-1/T-MEM-2 completes-before-eviction/degrade ordering. Stage-3: the in-flight strip COMPLETES (never aborted mid-strip); the export then PAUSES before starting the next strip until pressure drops back below stage-2, with a user-facing cancel option offered during the pause; the editor autosave still completes (journal-only per T-MEM-3); no corrupt half-written export file is ever left on disk in either case; resuming after pressure drops continues from the paused strip without re-rendering already-completed strips.

---

## 17. T-OFF — Offline behavior (P13/P14)

**T-OFF-1 · Full editor offline** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF: fully useful offline. **Steps** 1. Airplane mode (device) / network-disabled sim. 2. Full session: create project, type all §7.1 fixtures, arrange, path text, place assets, import photo from on-device library (premium), save, duplicate, search. **Expected** Every non-network feature works identically to online; no spinners, no errors, no feature hidden.

**T-OFF-2 · Export offline** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Still offline: export JPEG (free profile) and PNG/SVG/print PDF (premium profile). **Expected** All succeed; share sheet works for local destinations; export history records normally.

**T-OFF-3 · The only 3 network features degrade gracefully** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** BRIEF: network allowed ONLY for premium font downloads, premium iCloud sync, opt-in analytics upload. **Steps** 1. Offline, attempt: premium catalog font download; toggle/trigger sync; analytics batch flush (consent on). **Expected** Each shows a calm Arabic offline state («لا يوجد اتصال — سيتم التنزيل عند توفر الاتصال» class messaging), queues or retries when connectivity returns (verify auto-resume on reconnect); nothing else in the app ever touches the network (full-session network capture shows zero other traffic — this is also the privacy audit twin of T-ANL-2).

**T-OFF-4 · Reconnect reconciliation** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Queue a font download + sync changes offline; restore connectivity. **Expected** Both complete without user action; no duplicate downloads; sync applies cleanly (no spurious conflict copies from the offline gap alone).

**T-OFF-5 · First launch offline** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Steps** 1. Fresh install; first launch in airplane mode. **Expected** Onboarding, trial start (T-SK-14 local record), project creation, bundled fonts — all functional; StoreKit product load failure on paywall degrades to a retry state without blocking the free app.

**T-OFF-6 · Premium-user offline paywall/manage screen** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** DF-8: offline behavior of the paywall/manage-subscription screen itself for an ALREADY-premium user — distinct from T-SK-19's feature-availability check. **Steps** 1. As a premium/trial user, go offline (airplane mode). 2. Open Settings → paywall/manage-subscription screen. **Expected** Screen renders using cached entitlement state with no blocking spinner waiting on StoreKit network; current tier (premium/trial/lifetime) shown correctly with an offline-appropriate Arabic notice if live StoreKit status can't be refreshed; the manage-subscription deep link is present (understood to require connectivity when tapped); no crash and no false "not subscribed" flash.

**T-OFF-7 · Catalog manifest offline cases: stale cache vs. never cached** — P13 · Gate FUNCTIONAL-supporting · simulator-scriptable
**Purpose** DF-7/DF-8: `MKCatalogManifestFetchService` (fetch-on-foreground, 24h staleness TTL, disk cache) must distinguish two offline states with different UX. **Steps** 1. Stale-cache case: prime the disk cache with a manifest fetched more than 24h ago (simulate TTL expiry); go offline; foreground the catalog screen. 2. Never-cached case: fresh install, no manifest ever successfully fetched; go offline; open the catalog screen. **Expected** Stale-cache case: the catalog renders using the STALE cached manifest (better than nothing) with a subtle "may be outdated" indicator and no blocking error; a foreground reconnect triggers a background re-fetch per the 24h TTL policy. Never-cached case: the documented zero-manifest-ever empty state appears with the exact Arabic copy «لا يمكن تحميل قائمة الخطوط دون اتصال» and a retry affordance (per DF-7's PRD requirement); retry succeeds once connectivity returns without requiring an app restart.

---

## 18. T-DST — Distribution readiness (P15)

**T-DST-1 · Archive + validate** — P15 · Gate BUILD · xcodebuild-testable
**Steps** 1. T-BLD-6 archive; `xcrun altool`/notary-equivalent App Store validation via Xcode organizer or `xcodebuild -exportArchive` with app-store method. **Expected** Validation passes (entitlements: CloudKit container, Keychain sharing if used, Fonts capability per D-122 needs); FD-01 applied: real bundle ID `net.binjamshid.makhtoot` is in place.

**T-DST-2 · Privacy manifest & nutrition-label consistency** — P15 · Gate FUNCTIONAL-supporting · manual-visual
**Steps** 1. Compare `PrivacyInfo.xcprivacy` + App Store Connect privacy answers against D-125 reality (opt-in aggregated font usage only). **Expected** Declarations match tested behavior (T-ANL-2/3); no required-reason API undeclared; cross-ref APP_STORE_CHECKLIST items.

**T-DST-3 · Full sandbox StoreKit pass** — P15 · Gate STOREKIT · simulator-scriptable
**Steps** 1. Re-run the [SANDBOX]-marked subset (T-SK-2/3/4/7) on a physical device with a sandbox account. **Expected** All pass against real sandbox; receipts/transactions verified; founder countersigns.

**T-DST-4 · Final Arabic sign-off run** — P15 · Gate MANUAL-ARABIC · manual-visual
**Steps** 1. Execute the ENTIRE §7 checklist on `DEV-A15` + `DEV-M` on the release-candidate build, both anchor fonts. **Expected** 100 % pass or founder-accepted documented exceptions; evidence archived.

---

## 19. Per-phase gate tables (exit criteria; aligned to FOUNDATION §11 / PLAN.md)

A phase exits when ALL listed tests pass (or are explicitly waived by the founder in
the phase log). Earlier-phase BUILD gates (T-BLD-1…5, T-BLD-7, T-BLD-8) re-run
automatically at every phase exit.

| Phase | Must pass to exit | Gate types in play |
|---|---|---|
| **P0 Scaffold** | T-BLD-1, T-BLD-2, T-BLD-3, T-BLD-4, T-BLD-5, T-BLD-7, T-BLD-8 | BUILD |
| **P1 Design System & Shell** | T-BLD-* rerun; T-AR-59 (RTL chrome smoke) | BUILD, MANUAL-ARABIC |
| **P2 Model & Persistence** | T-MDL-1 … T-MDL-11 | BUILD, FUNCTIONAL |
| **P3 Text Engine** | T-TXT-1 … T-TXT-11; MANUAL-ARABIC §7.1–7.8 (T-AR-1…30) on simulator | BUILD, FUNCTIONAL, MANUAL-ARABIC |
| **P4 Canvas Core** | T-CVS-1 … T-CVS-11 | BUILD, FUNCTIONAL |
| **P5 Arrange Mode** | T-AR-31, T-AR-32, T-AR-33, T-AR-39…45, T-AR-60 (mark follow/detach/reattach, dual-level, revert, single-glyph scale); T-ARR-1…3 (numeric mark-position + detach/rotate/reattach twins) | BUILD, FUNCTIONAL, MANUAL-ARABIC |
| **P6 Marks/Ligatures/Forms** | T-AR-34…38, T-AR-61…63 (break/forms/ligature decompose-recompose incl. dlig, rotate-then-decompose, neighbor-overlap); T-TXT-5/6/7 rerun; T-ARR-LIG-STYLE, T-ARR-NOREFLOW-1 | BUILD, FUNCTIONAL, MANUAL-ARABIC |
| **P7 Path Text** | T-PTH-1 … T-PTH-6; T-AR-46 … T-AR-50 | BUILD, FUNCTIONAL, MANUAL-ARABIC |
| **P8 Assets & Imports** | T-AST-1 … T-AST-5 | BUILD, FUNCTIONAL |
| **P9 Fonts** | T-FNT-1 … T-FNT-8, T-FNT-10; T-AR-58 (cross-font sweep) + per D-222 the fidelity block (T-AR-31/32/33/36…38) at every newly license-verified font | BUILD, FUNCTIONAL, MANUAL-ARABIC |
| **P10 Export** | T-EXP-1 … T-EXP-9, T-EXP-11 … T-EXP-14; T-AR-51 … T-AR-57 | BUILD, FUNCTIONAL, MANUAL-ARABIC |
| **P11 Store & Gating** | T-SK-1 … T-SK-21 (.storekit file); T-FNT-9; T-EXP-10, T-EXP-15, T-EXP-16 | BUILD, STOREKIT, FUNCTIONAL |
| **P12 Sync** | T-SYN-1 … T-SYN-10 | BUILD, FUNCTIONAL |
| **P13 Analytics/Settings** | T-ANL-1 … T-ANL-6; T-OFF-1 … T-OFF-7 | BUILD, FUNCTIONAL |
| **P14 Performance Hardening** | T-PRF-1 … T-PRF-14 (PERF gates on device matrix); T-MEM-1 … T-MEM-6 | BUILD, PERF, FUNCTIONAL, MANUAL-ARABIC (T-MEM-2 banner) |
| **P15 Distribution** | T-BLD-6, T-DST-1 … T-DST-4 (incl. full §7 rerun + sandbox StoreKit) | BUILD, STOREKIT, MANUAL-ARABIC, FUNCTIONAL |

Founder countersignatures required at: P14 (PERF evidence), P15 (T-DST-3 sandbox,
T-DST-4 final Arabic sign-off).

---

## 20. Test counts by gate type

Run-2 note: T-BLD-7's own entry is Gate FUNCTIONAL-supporting (it always was — its header
reads "Gate FUNCTIONAL-supporting"), even though it is numbered inside the T-BLD family
and re-runs at every phase exit like the BUILD gates. The pre-Run-2 table double-counted
it under BUILD while omitting it from FUNCTIONAL-supporting; both rows below are corrected
to match each test's actual per-entry Gate label. Total across all gate types: 214.

| Gate type | Count | IDs |
|---|---|---|
| BUILD | 8 | T-BLD-1…6, T-BLD-8, T-DST-1 |
| PERF | 12 | T-PRF-1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13 → of these, D-115 hard gates: T-PRF-1/2/3/5/6/7/9/10/13 (9, per D-218); engineering-target PERF: T-PRF-4/11/12 |
| STOREKIT | 22 | T-SK-1…21, T-DST-3 |
| MANUAL-ARABIC | 65 | T-AR-1…63 (incl. 12 letter rows + 13-item non-joiner test), T-MEM-2 (banner text), T-DST-4 |
| FUNCTIONAL-supporting | 107 | T-BLD-7, T-MDL-1…11, T-TXT-1…11, T-CVS-1…11, T-PTH-1…6, T-AST-1…5, T-FNT-1…10, T-EXP-1…16, T-SYN-1…10, T-ANL-1…6, T-PRF-8/14, T-MEM-1/3…6, T-OFF-1…7, T-DST-2, T-ARR-1…3, T-ARR-LIG-STYLE, T-ARR-NOREFLOW-1 |

---

## 21. Traceability (BRIEF.md bullets → test IDs)

| BRIEF requirement (section · bullet) | Covered by |
|---|---|
| Platform: universal iPhone+iPad adaptive, iOS 18 | T-BLD-1, T-CVS-9 |
| Arabic-only RTL UI | T-BLD-5, T-AR-59 |
| Fully useful offline; only 3 network features | T-OFF-1…7, T-ANL-2, T-SYN-8, T-SK-19 |
| Native typing: shaping, contextual forms, ligatures, tashkeel, bidi, numerals, punctuation | T-TXT-1…11, T-AR-1…30 |
| Arrange Mode derivation + Source Text Backup + revert | T-AR-31, T-AR-44, T-AR-45, T-PTH-6, T-MDL-1 |
| Arranged compositions never auto-reflow; per-glyph transforms | T-AR-32, T-AR-45, T-AR-39…42, T-ARR-NOREFLOW-1 |
| Both levels (glyph + Unicode letter), switching loses nothing | T-AR-43, T-TXT-2 |
| Joining preserved by default; explicit break + 4-form selector | T-AR-33, T-AR-34, T-AR-35, T-TXT-5, T-TXT-6 |
| Tashkeel + full Qur'anic marks attach/follow/detach/move | T-AR-19…26, T-AR-39…42, T-TXT-4, T-ARR-1…3 |
| Ligatures combined + decomposable, fidelity default, opt-out, recompose | T-AR-36, T-AR-37, T-AR-38, T-AR-61…63, T-TXT-7, T-AR-14…18, T-ARR-LIG-STYLE |
| Per-object kerning/tracking/baseline/line-height/etc. | T-TXT-10, T-CVS-5 |
| Bézier path text, editable until arranged | T-PTH-1…6, T-AR-46…50 |
| No preloaded Qur'anic content; user-typed marks only | §7.0 protocol, §7.6 preamble (fixtures are user-typed) |
| Canvas: drag/resize/rotate/multi-select/guides/snap/layers/group/lock/hide/undo/zoom/pan | T-CVS-1…8, T-MDL-7 |
| Layers panel incl. arranged glyphs + marks | T-CVS-4 |
| Numeric inspector | T-CVS-5 |
| Autosave, duplicate, folders, search, export history | T-MDL-4…6, T-MDL-9, T-EXP-3 |
| Premium iCloud sync (CloudKit, not SIWA) | T-SYN-1…10 |
| Imports: raster, SVG, PDF, custom fonts (premium) | T-AST-2…5, T-FNT-4…6 |
| Four font mechanisms; formats; rejection with clear errors | T-FNT-1…6, T-FNT-10 |
| Catalog previews/styles/tags/favorites/search/categories | T-FNT-2 |
| Licensing at Settings → Support → Licensing | T-FNT-7 |
| Expiry: fonts lock, export falls back | T-FNT-9, T-SK-10, T-EXP-10 |
| Export free JPEG/PDF 2 MP; premium PNG/SVG/print PDF | T-EXP-1…4, T-AR-51…53 |
| Premium SVG editability + documented outline fallbacks | T-AR-54, T-AR-55, T-EXP-7 |
| Print PDF vector + true CMYK + ICC pipeline | T-AR-56, T-AR-57, T-EXP-8, T-EXP-9, T-EXP-13, T-EXP-14 |
| Presets + premium custom dimensions | T-EXP-4 |
| Free gating: resolution/formats/fonts/photo backgrounds | T-EXP-2, T-EXP-10, T-EXP-15, T-EXP-16, T-AST-2 |
| Sharp Arabic output at print resolution across formats | T-AR-51…57 |
| No artificial caps; memory monitoring, warnings, autosave, recovery | T-MEM-1…6, T-PRF-10 |
| Soft degradation ladder | T-MEM-1…3, T-PRF-1 |
| Quantitative budgets all iOS 18 devices | T-PRF-1…14 + §2 device matrix |
| $3/$30/$90 products, localized pricing | T-SK-1…6 (mapped per D-216) |
| 7-day app-side trial from first launch, reinstall-proof | T-SK-14…17 |
| Post-trial free tier retains editing + free export | T-SK-10, T-EXP-2 |
| Referral architected, flag OFF | T-SK-20 |
| Full StoreKit 2: status/restore/precedence/grace/retry/messaging/sandbox | T-SK-1…19, T-SK-21, T-DST-3 |
| No mandatory account; CloudKit direct | T-SYN-4, T-OFF-5 |
| Anonymous opt-in font analytics only; nothing else uploaded | T-ANL-1…6 |
| Gates (Q59): build, perf profiling, StoreKit sandbox, manual Arabic checklist | §1.1, §19 tables, T-DST-1/3/4 |
| Codebase-memory verification evidence per phase | §1.1, §7.0 recording protocol |
| Persistence choice validated (scale/undo/autosave/sync) | T-MDL-1…11, T-PRF-5…8, T-SYN-1…3 |

---

## 22. Gap statement — deliberately untested in v1 (and why)

1. **Formal accessibility suite (VoiceOver, Dynamic Type, contrast audits)** — founder
   Q53 explicitly excludes accessibility as a v1 requirement; BRIEF allocates no scope.
   Only incidental coverage exists (RTL layout correctness in T-AR-59). Revisit in v1.x.
2. **Snapshot-test suites** — BRIEF Q59 excludes mandatory snapshot suites. Where this
   matrix needs pixel comparison (T-TXT-1, T-AR-31, T-EXP-1/11) it uses targeted
   in-test bitmap diffs, not a maintained snapshot corpus — a deliberate scope choice
   to avoid snapshot-churn maintenance during rapid v1 iteration.
3. **UI-automation (XCUITest) regression suite** — excluded per Q59. simulator-scriptable
   tests use debug automation hooks + simctl, which is cheaper and less brittle; a real
   XCUITest suite is a v1.x hardening candidate.
4. **Animation/motion** — v1 is static compositions only (BRIEF platform scope);
   nothing animated exists to test beyond scroll/zoom interaction covered by PERF gates.
5. **On-screen CMYK soft-proofing** — D-117 documents v1 has none; verification is
   external-tool-based (T-AR-56). A soft-proof feature and its tests are v1.1+.
6. **Referral program end-to-end** — flag is OFF (D-124/FD-05); only inertness is
   tested (T-SK-20). Full flow testing happens only if FD-05 ever activates it, after
   guideline recheck.
7. **App Store Server API cross-validation** — D-113 decides on-device verification for
   v1 (no backend); server-side receipt validation tests are an extension-seam item.
8. **Commercial foundry font licenses** — v1 catalog is OFL-only (FD-07); no tests for
   commercial-license embedding switches beyond the per-license mechanism itself
   (T-EXP-8's test-flagged path).
9. **Exact Apple grace-period durations** — deliberately not asserted numerically
   (BRIEF research gap; T-SK-11 forbids hardcoding the duration in copy).
   VERIFY-AT-SUBMISSION.
10. **Localization beyond `ar`** — single-locale app by decision (D-100); no pseudo-loc
    or multi-locale layout tests.

End of TEST_MATRIX.md.
