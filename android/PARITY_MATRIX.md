# android/PARITY_MATRIX.md — iOS→Android Requirement Parity Ledger

Android port work item 0.1, specified in `ANDROID_TASK_PACKETS/BATCH-0.md`. Source of truth for iOS
status is the shipped Swift source (`MakhtootKit/Sources/**`, `Makhtoot/AppShell/**`), not prose
docs, per `ANDROID_SPINE.md` §0. Android status column starts `⬜` for every row; Batches 2–8
update it in place; Batch 8.7 and 9.5 are the ones that must show every row ✅.

## Row-count note — the true id count is 318, not 319 (resolved)

`ANDROID_SPINE.md` §0 originally stated "PRD requirement ids (`R-<section>.<n>`) | 319", and
this packet's own Task 1 originally instructed running
`grep -oE 'R-[0-9]+\.[0-9]+' PRD.md | sort -u | wc -l` to confirm 319 before writing anything.
That exact command **does** print 319 — but it was counting the wrong 319 things, for two
errors that happened to cancel numerically:

1. **Undercounts by 1.** The pattern has no letter-suffix group, so `R-21.35a` — a real,
   independently `**R-21.35a (P0)**`-defined requirement ("Neutral-punctuation freeze at
   capture," INV-1/D-109) distinct from `R-21.35` ("Arrange during active text editing") —
   collapses into the same string as `R-21.35` and is invisible to the count.
2. **Overcounts by 2.** `R-14.20` and `R-21.72` were matched by the pattern but were **never
   defined anywhere in `PRD.md`** with a `**R-x.y (P#)**` bold definition — both were dangling
   prose cross-references (`R-2.8`'s text: "…see R-14.20"; `R-15.12`'s text: "…(R-21.72)").

**Status: resolved.** A correction agent, taking over this path per spine `§17`'s declared-
takeover rule, has since:

- Fixed the two dangling `PRD.md` cross-references to point at the real ids they were almost
  certainly typos for: `R-14.20` → `R-14.11` (`PRD.md:161`, Guideline 3.1.2 compliance — what
  `R-2.8`'s "see R-14.20" was pointing at) and `R-21.72` → `R-21.55` (`PRD.md:1180`, mid-export
  entitlement re-evaluation at render request — exactly what `R-15.12`'s sentence describes).
  Both replacements were confirmed by mutual cross-reference (`R-2.8`↔`R-14.11` and
  `R-15.12`↔`R-21.55` each cite the other) before being applied. `PRD.md`'s bold-definition
  count is unchanged at 318 after this fix, as expected — it corrects prose pointers, not
  requirement definitions.
- Corrected `ANDROID_SPINE.md` throughout (§0's metrics table and no-"coming soon" contract,
  §5.3's Agent 0.1 assignment line, §6's G0/G8 gate rows, and §16's traceability register) from
  319 to 318, with an explanatory note on the same derivation given above so a future reader
  cannot "re-correct" it back to 319.

Verified count of actual bold-defined requirement ids, letter-suffix aware:
`grep -oE '\*\*R-[0-9]+\.[0-9]+[a-z]? \(P' PRD.md | sed -E 's/^\*\*(R-[0-9]+\.[0-9]+[a-z]?) \(P/\1/' | sort -u | wc -l` → **318**.

**This matrix has 318 rows**: one per real, independently bold-defined requirement — `R-21.35`
and `R-21.35a` counted as the two distinct requirements they are; no row fabricated for the
(now-repaired) `R-14.20`/`R-21.72` typos. `ANDROID_SPINE.md` §0 now reads "318," so this matrix
and the spine are consistent; no gap remains to record in
`android/docs/impl-log/BATCH-0.1.md`.

## Header summary

- **Total rows: 318** (see note above). Verified: every real bold-defined `R-<section>.<n>` id
  in `PRD.md` appears exactly once below, no duplicates, no fabricated ids
  (`comm -23`/`comm -13` against the PRD-derived id list both return empty).
- **Count by iOS status:** `✅ shipped` 298 · `⚠️ shipped with known gap` 14 · `⚠️→✅` (fixed,
  with a note correcting this packet's cited commit) 6 · `❌ missing` 0. 298+14+6 = 318.
- **Count by target batch** (rolled up from `batch.agent` to `batch`): Batch 1 → 6 ·
  Batch 2 → 4 · Batch 3 → 34 · Batch 4 → 40 · Batch 5 → 46 · Batch 6 → 48 · Batch 7 → 55 ·
  Batch 8 → 82 (61 of which are §21's edge-case sweep, Agent 8.7) · Batch 9 → 3.
  6+4+34+40+46+48+55+82+3 = 318. No id assigned to Batch 0 (this batch produces the ledger,
  it does not itself port anything).
- Every row has a non-empty Android target module and non-empty target batch.agent cell
  (verified: `awk` scan over all 318 data rows for blank column 6/7 returns 0 rows).
- Android status column is `⬜` for every row at G0 and is updated in place by every batch from
  Batch 2 onward; Batch 8.7 and 9.5 are the ones that must show 318/318 ✅ (`ANDROID_SPINE.md`
  G8/§6 now reads "318" as well, per the row-count note above — no reconciliation needed).

## Legend

- File-path shorthand: `MK/<Target>/…` = `MakhtootKit/Sources/MK<Target>/…`; `App/…` =
  `Makhtoot/AppShell/…`. Full paths given on first use per module in each section.
- iOS status: `✅ shipped` · `⚠️ shipped with known gap` (cross-referenced to a named
  `AUDIT_2026-07-28.md` finding or founder handover note) · `❌ missing`.
- Android target module = the Gradle module from spine §3.1. Target batch.agent = the register
  id from spine §5, letter-suffixed where the owning agent is one of the seven split agents
  (spine §5.2). Agent scopes below are drawn from each agent's actual **Mission** in
  `ANDROID_TASK_PACKETS/BATCH-N.md` (read in full for this purpose), not inferred from file
  names alone.
- File-location granularity: assigned at feature-area/subsystem level (module or sub-directory),
  not independently re-verified per individual requirement id against exact line ranges — at
  318-row scale this is the documented judgment call this packet's own Task 2 anticipates
  ("note the judgment call in the impl log rather than leaving the cell empty" applies equally
  to file-location granularity as to target-agent assignment).

---

## §1 Overview & Personas (`PRD.md` §1) — 18 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-1.1 | Core promise: native-fidelity typing → explicit Arrange Mode derivation with lossless revert | `MK/Arrange/ArrangeDeriver.swift`, `MK/Model/Arranged/*.swift` | ✅ shipped | `:mk-arrange` | 4.1 | ⬜ |
| R-1.2 | v1 ships static image/design output only; animation/video is a v2 seam | `MK/Model/MKScene.swift`, `MK/Model/MKNode.swift` | ✅ shipped | `:mk-model` | 2.2 | ⬜ |
| R-1.3 | Entire UI ships Arabic-only, RTL-first, `ar` sole localization | `Makhtoot/App/MakhtootApp.swift`, `Makhtoot/Resources/Localizable.xcstrings` | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-1.4 | Fully useful offline; only 3 permitted network uses (fonts, sync, analytics) | `MK/Fonts/MKFontDownloader.swift`, `MK/Sync/**`, `MK/Analytics/Upload/**` | ✅ shipped | cross | 8.1 | ⬜ |
| R-1.5 | No preloaded Qur'anic content, no sacred-content detection; all text treated identically | n/a — absence of a feature | ✅ shipped (intentional non-build) | n/a | 8.7 | ⬜ |
| R-1.6 | Market-gap positioning claim (no competitor exposes per-glyph manipulation) | doc only (`PROJECT_DESCRIPTION.md`) | ✅ shipped (doc-only) | n/a | 9.1 | ⬜ |
| R-1.7 | Marketing/competitor claims must be re-validated before submission | doc only | ⚠️ shipped with known gap (VERIFY-AT-SUBMISSION per PRD's own marking — competitor claims not yet re-validated) | n/a | 9.1 | ⬜ |
| R-1.8 | Persona P-A "الخطّاط الهاوي" (hobbyist calligrapher) — iPad-first needs | `Makhtoot/AppShell/**` (adaptive layout) | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-1.9 | Persona P-B "صانع المحتوى" (content creator) — iPhone-first speed/presets | `Makhtoot/AppShell/**` | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-1.10 | Persona P-C "المصمّم المحترف" (professional designer) — print/SVG/CMYK needs | `Makhtoot/AppShell/**` | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-1.11 | Persona P-D "المعلّم/إمام المجتمع" (teacher/community organizer) — heavy-tashkeel, honest free tier | `Makhtoot/AppShell/**` | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-1.12 | Every P0 flow completable on iPhone SE-class and 13" iPad with identical feature set | `Makhtoot/AppShell/**` (adaptive layout, no device forking) | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-1.13 | First-launch-to-export-with-manual-arrangement in <10 min, offline, no docs | end-to-end product behavior | ⚠️ shipped with known gap (AUDIT FC-6: no automated UI-test evidence for ~8,000 LOC of SwiftUI at time of audit; Wave 0 added `MakhtootUITests` target since) | `:app` | 8.6 | ⬜ |
| R-1.14 | All §22/D-115 performance budgets pass on oldest supported hardware before submission | cross-cutting perf | ⚠️ shipped with known gap (`DegradationController.history` unbounded growth, P-8, still open per 2026-07-30 founder handover) | cross | 8.4 | ⬜ |
| R-1.15 | Free tier post-trial stays complete/honest forever: create/edit/autosave/organize/export ≤2MP forever | `MK/Export/ExportGate.swift`, `MK/Export/FreeTierBudget.swift` | ⚠️→✅ (FC-2 export-gate bypass fixed; this packet's own citation of commit `ec9887c` is wrong — the actual fix landed in commit `d885fe2` "Wave 1: fix bold/italic wiring + export gate bypass (FC-1/FC-2/P-4)"; see impl log) | `:mk-export` | 5.6 | ⬜ |
| R-1.16 | No accessibility scope in v1 — explicit founder non-goal, no VoiceOver/Dynamic Type work planned | absence of feature; confirmed by `AUDIT_2026-07-28.md` UX-1 (canvas invisible to VoiceOver) | ✅ shipped as intentional absence (UX-1 still open/Wave-5-founder-gated; note: Wave 3 did add some Dynamic Type + localized a11y labels for non-canvas chrome per commit `a3308f9`, a partial drift from the pure non-goal — see impl log) | `:app` | 8.5 | ⬜ |
| R-1.17 | No templates; reusable shapes/ornaments/frames/pattern backgrounds ARE in scope | `MK/Assets/**` | ✅ shipped | `:mk-assets` | 5.5a | ⬜ |
| R-1.18 | No accounts, no SIWA, no ads, no third-party SDKs, no server backend | architecture policy (D-101/D-113) | ✅ shipped | multiple (scaffold) | 1.1 | ⬜ |

---

## §2 Information Architecture & Navigation (`PRD.md` §2) — 12 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-2.1 | 5-scene top-level structure: Browser, Editor, Settings, Paywall, Onboarding (RTL-first) | `Makhtoot/AppShell/Navigation/RootShellView.swift`, `AppNavigationModel.swift`, `MKRoute.swift` | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-2.2 | Universal adaptive layout: one codebase, iPhone stack/sheets vs iPad split/sidebar, no feature forking | `Makhtoot/AppShell/**` | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-2.3 | Entire navigation chrome is RTL (back-right, sidebars from right, directional sliders R-to-L) | `Makhtoot/AppShell/Navigation/**` | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-2.4 | Scene/state restoration on relaunch via crash-recovery journal (viewport reset, mode preserved) | `MK/Persistence/CrashRecovery.swift`, `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` | ⚠️ shipped with known gap (AUDIT EU-3 "no state restoration — background kill loses the user's place" was open at audit time; Wave 3 commit `a3308f9` added scene restoration — verify current state) | `:mk-persistence` | 3.4 | ⬜ |
| R-2.5 | iPad Split View / Stage Manager support, same adaptive rules, no cross-instance drag-drop | `Makhtoot/AppShell/**` | ✅ shipped | `:app` | 7.1 | ⬜ |
| R-2.6 | No URL schemes/deep links/widgets/App Intents in v1 (P2-seam) | absence of feature (one `.onOpenURL` exists for `.makhtoot` file opening only, not general deep links) | ✅ shipped (intentional absence) | `:app` | 7.1 | ⬜ |
| R-2.7 | Destructive confirmations are Arabic action sheets, destructive verb first | `Makhtoot/AppShell/Scenes/Editor/*Sheet.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-2.8 | Paywall is never the first screen; Browser + editable canvas reachable before any paywall | `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift`, `Navigation/AppNavigationModel.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-2.9 | Onboarding: 3 cards (Type/Arrange/Export) + trial card, skippable, shown once | `Makhtoot/AppShell/Scenes/Onboarding/OnboardingView.swift` | ⚠️ shipped with known gap (AUDIT EU-8 "onboarding tells rather than shows" — open/Wave-5-founder-gated; EU-7 "cannot be replayed" was fixed Wave 3 per commit `a3308f9`) | `:app` | 7.8 | ⬜ |
| R-2.10 | Exactly 3 editor modes: Text Editing / Manipulation / Arrange, always visibly indicated | `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` | ✅ shipped | `:app` | 7.3a | ⬜ |
| R-2.11 | Mode-transition table (trigger → guarantee) for all 5 mode-switch paths | `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` | ✅ shipped | `:app` | 7.3a | ⬜ |
| R-2.12 | Undo/redo is global and crosses mode switches | `MK/Persistence/Undo/UndoStack.swift` | ✅ shipped | `:mk-persistence` | 3.5 | ⬜ |

---

## §3 Project Browser & Documents (`PRD.md` §3) — 12 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-3.1 | Project = one `.makhtoot` file package: manifest/scene/assets/backups/thumbnail, single canvas | `MK/Persistence/DocumentPackage.swift`, `MakhtootDocument.swift` | ✅ shipped | `:mk-persistence` | 3.4 | ⬜ |
| R-3.2 | Free and premium alike get local storage, autosave, duplicate, folders, search, export history | `MK/Persistence/DocumentPackage.swift` | ✅ shipped | `:mk-persistence` | 3.4 | ⬜ |
| R-3.3 | Autosave: debounced ≤2s, immediate on background/memory-pressure, atomic write-temp+rename, journal replay | `MK/Persistence/AutosaveController.swift`, `CommandJournal.swift`, `CrashRecovery.swift` | ✅ shipped (P-6/P-7/S-6/S-7 orphan-sweep and file-protection findings fixed Wave 1, commit `d885fe2`) | `:mk-persistence` | 3.4 | ⬜ |
| R-3.4 | Autosave is invisible — no save button; toast only on autosave failure | `MK/Persistence/AutosaveController.swift` | ✅ shipped | `:mk-persistence` | 3.4 | ⬜ |
| R-3.5 | Grid of project thumbnails, most-recently-edited first, list view toggle on iPad | `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift` | ✅ shipped | `:app` | 7.2 | ⬜ |
| R-3.6 | Folders: create/rename/delete/move, one level deep in v1 | `MK/Persistence/Metadata/MetadataStore.swift`, `MetadataModels.swift` | ✅ shipped | `:mk-persistence` | 3.6 | ⬜ |
| R-3.7 | Search: live filter on name + indexed searchable text, diacritic-insensitive | `MK/Persistence/Metadata/SearchNormalizer.swift`, `MetadataStore.swift` | ✅ shipped | `:mk-persistence` | 3.6 | ⬜ |
| R-3.8 | Duplicate: full deep copy, "نسخة" suffix, safe against concurrent autosave | `MK/Persistence/Metadata/MetadataStore.swift` | ✅ shipped | `:mk-persistence` | 3.6 | ⬜ |
| R-3.9 | Delete: confirmation, local-immediate, no trash/undo-delete in v1 | `MK/Persistence/Metadata/MetadataStore.swift` | ✅ shipped | `:mk-persistence` | 3.6 | ⬜ |
| R-3.10 | Export history: per-project list (date/format/dims/preset/tier), re-opens export sheet pre-configured | `MK/Persistence/Metadata/MetadataModels.swift`, `Makhtoot/AppShell/Scenes/Browser/ExportHistorySheet.swift` | ✅ shipped | `:mk-persistence` | 3.6 | ⬜ |
| R-3.11 | New-project sheet: preset chooser, custom W×H, background color, default auto-incrementing name | `Makhtoot/AppShell/Scenes/Browser/NewProjectSheet.swift` | ✅ shipped | `:app` | 7.2 | ⬜ |
| R-3.12 | Project metadata editable: name, folder, canvas size (resize re-anchors top-right) | `MK/Persistence/Metadata/MetadataStore.swift` | ✅ shipped | `:mk-persistence` | 3.6 | ⬜ |

---

## §4 Canvas Editor (`PRD.md` §4) — 22 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-4.1 | Canvas capabilities (locked): drag/resize/rotate/multi-select/guides/snap/layers/group/lock-hide/undo-redo/zoom/pan | `MK/Canvas/**` (session spine) | ✅ shipped | `:mk-canvas` | 5.1 | ⬜ |
| R-4.2 | No artificial caps on canvas size/glyph/object count for any tier | `MK/Canvas/**` | ✅ shipped | `:mk-canvas` | 5.1 | ⬜ |
| R-4.3 | Single render path: canvas host + layer-per-node, committed text always via MKTextEngine→MKRender | `MK/Render/LayerTreeBuilder.swift`, `SceneRenderer.swift` | ✅ shipped | `:mk-render` | 4.5 | ⬜ |
| R-4.4 | Zoom 2.5%–6400%, pinch + double-tap-fit, pan 1/2-finger, zoom chip with tap-to-reset | `MK/Canvas/**` (zoom/pan) | ✅ shipped | `:mk-canvas` | 5.1 | ⬜ |
| R-4.5 | Document space is pt-based; inspector shows position in pt at 0.1 precision | `MK/Canvas/**` | ✅ shipped | `:mk-canvas` | 5.1 | ⬜ |
| R-4.6 | Selection: tap topmost unlocked, tap-again cycles overlap, marquee, multi-select modifier | `MK/Render/HitTester.swift`, `MK/Canvas/**` (hit-test policy) | ✅ shipped | `:mk-canvas` | 5.3 | ⬜ |
| R-4.7 | Transform handles: 8 resize + rotation, proportional default, 0/±45/±90/180° snap + haptic | `MK/Canvas/Gestures/**` | ✅ shipped | `:mk-canvas` | 5.2a | ⬜ |
| R-4.8 | Alignment guides & snapping: edges/center/other-nodes/equal-spacing, 4pt threshold, accent guide lines | `MK/Canvas/Geometry/**` | ✅ shipped | `:mk-canvas` | 5.2b | ⬜ |
| R-4.9 | Grouping: group/ungroup any multi-selection, nesting, line-height as parent-group property | `MK/Canvas/**` (editing operations) | ✅ shipped | `:mk-canvas` | 5.3 | ⬜ |
| R-4.10 | Lock/hide per node/group from layers panel + context menu; locked skip taps, hidden skip render/export | `MK/Canvas/**` (layers model), `MK/Render/**` (hidden exclusion) | ✅ shipped | `:mk-canvas` | 5.3 | ⬜ |
| R-4.11 | Long-press context menu: cut/copy/paste/duplicate/delete/group/lock/hide/z-order | `MK/Canvas/**` (editing operations) | ⚠️ shipped with known gap (AUDIT EU-2 "long-press on the canvas is a dead gesture" — open/Wave-5-founder-gated) | `:mk-canvas` | 5.3 | ⬜ |
| R-4.12 | Nudge: 1pt/arrow-key-tap, 10pt with modifier; RTL "forward" chip points −x | `MK/Canvas/**` (hardware-keyboard command map) | ✅ shipped | `:mk-canvas` | 5.3 | ⬜ |
| R-4.13 | Per-node style surface: position/rotation/scale/opacity/fill/stroke/shadow; text adds kerning/tracking/baseline/line-height | `MK/Model/MKNodeStyle.swift`, `MKTextStyle.swift` | ✅ shipped | `:mk-model` | 2.2 | ⬜ |
| R-4.14 | Style copy/paste applies intersection of applicable fields to target node type | `MK/Canvas/**` (copy/paste editing ops) | ✅ shipped | `:mk-canvas` | 5.3 | ⬜ |
| R-4.15 | Color picker: swatches, P3-aware system picker, recent colors, opacity slider, eyedropper; sRGB stored | `MK/Color/MKColorSpec.swift`, `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-4.16 | Full undo/redo across every mutating operation (transforms/style/text/arrange/marks/joins/ligatures/path/layers/group/lock/canvas-size/background) | `MK/Persistence/Undo/UndoStack.swift`, `Commands.swift` | ✅ shipped | `:mk-persistence` | 3.5 | ⬜ |
| R-4.17 | Undo implementation: in-memory inverse-command stack, gesture coalescing, unbounded within memory budget | `MK/Persistence/Undo/UndoStack.swift` | ✅ shipped (undo-stack memory reclaim wired into degradation ladder, FC-3/P-5, Wave 2 commit `2fe2342`) | `:mk-persistence` | 3.5 | ⬜ |
| R-4.18 | Undo UI: two toolbar chips with long-press op-name, 3-finger swipe on iPad, shake-to-undo disabled | `Makhtoot/AppShell/Scenes/Editor/EditorStatusViews.swift` | ✅ shipped | `:app` | 7.3b | ⬜ |
| R-4.19 | Mode-crossing undo (arrange entry/exit, revert-to-text) is a P0 correctness surface | `MK/Persistence/Undo/UndoStack.swift`, `MK/Arrange/RevertService.swift` | ✅ shipped | `:mk-persistence` | 3.5 | ⬜ |
| R-4.20 | Background is a distinguished node: solid (all tiers), photo/pattern (premium-only) | `MK/Render/Drawers/BackgroundDrawer.swift` | ✅ shipped | `:mk-canvas` | 5.1 | ⬜ |
| R-4.21 | Background is always bottom layer, cannot reorder above content, lockable, exports as rendered | `MK/Render/Drawers/BackgroundDrawer.swift` | ✅ shipped | `:mk-canvas` | 5.1 | ⬜ |
| R-4.22 | Mode-crossing undo is P0 (cross-ref R-2.12/R-4.19) | see R-4.19 | ✅ shipped | `:mk-persistence` | 3.5 | ⬜ |

---

## §5 Typing & Live Text (`PRD.md` §5) — 11 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-5.1 | Double-tap creates Live Text + UITextView overlay; committed render always via MKTextEngine, metrically identical | `MK/Canvas/**` (IME overlay) | ✅ shipped | `:mk-canvas` | 5.4a | ⬜ |
| R-5.2 | Native-field typing: contextual shaping, mandatory ligatures, GPOS tashkeel, bidi, numerals, kashida, no custom shaper | `MK/TextEngine/MKShapingEngine.swift`, `ShapingService.swift` | ✅ shipped | `:mk-textengine` | 3.1a | ⬜ |
| R-5.3 | Mixed Arabic-English: paragraph base RTL default, UBA-correct embedded Latin runs, per-object direction override | `MK/TextEngine/BidiMap.swift` | ✅ shipped | `:mk-textengine` | 3.2 | ⬜ |
| R-5.4 | Tashkeel input via system keyboard + pasted annotation marks, rendered per font support | `MK/TextEngine/MarkClassifier.swift`, `MarkAttachment.swift` | ✅ shipped | `:mk-textengine` | 3.3 | ⬜ |
| R-5.5 | Multi-line: hard breaks, soft wrap at frame width, 4-way alignment incl. Core-Text justification | `MK/TextEngine/MKShapingEngine.swift` (`shapeParagraph`) | ✅ shipped | `:mk-textengine` | 3.1b | ⬜ |
| R-5.6 | Live Text style surface: font/size/fill/tracking/kerning/baseline/line-height/opacity/stroke/shadow, reflow-safe | `MK/TextEngine/FontFeatureControl.swift` | ✅ shipped | `:mk-textengine` | 3.1a | ⬜ |
| R-5.7 | Discretionary/contextual ligature toggle maps to Core Text `dlig`/`calt` features before arrangement | `MK/TextEngine/FontFeatureControl.swift` | ✅ shipped | `:mk-textengine` | 3.1a | ⬜ |
| R-5.8 | One style per Live Text object in v1 (mixed-style runs are a P2-seam) | `MK/Model/MKTextStyle.swift` | ✅ shipped | `:mk-model` | 2.2 | ⬜ |
| R-5.9 | Variable fonts expose registered axes as inspector sliders; instance recorded in provenance | `Makhtoot/AppShell/Scenes/Editor/FontSettingsSheet.swift:268-291`, `MK/Fonts/MKFontRegistrar.swift:74-81` | ⚠️→✅ (FC-1 bold/italic axis wiring fixed; this packet's own citation of commit `ec9887c` is wrong — the actual fix is commit `d885fe2` "Wave 1: fix bold/italic wiring…"; see impl log) | `:mk-textengine` | 3.1a | ⬜ |
| R-5.10 | Missing-glyph policy: system cascade in overlay, committed render badges fallback runs, no silent tofu/substitution | `MK/Render/Drawers/LiveTextDrawer.swift` | ✅ shipped | `:mk-render` | 4.5 | ⬜ |
| R-5.11 | Rotated Live Text editing normalizes overlay to axis-aligned during edit, restores rotation on commit (D-201) | `MK/Canvas/**` (IME overlay) | ✅ shipped | `:mk-canvas` | 5.4a | ⬜ |

---

## §6 Arrange Mode (`PRD.md` §6) — 14 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-6.1 | Arrange entered only by explicit "تنسيق الحروف" tap; entry is non-destructive, confirmation-free | `MK/Arrange/ArrangeDeriver.swift` | ✅ shipped | `:mk-arrange` | 4.1 | ⬜ |
| R-6.2 | Derivation produces Glyph/Mark/Ligature nodes + Source Text Backup (D-105/D-106) | `MK/Arrange/ArrangeDeriver.swift`, `MK/Model/Arranged/*.swift` | ✅ shipped | `:mk-arrange` | 4.1 | ⬜ |
| R-6.3 | Arranged Compositions never auto-reflow; only per-letter form realization and ligature decomposition re-shape | `MK/Arrange/ArrangeInvariants.swift` | ✅ shipped | `:mk-arrange` | 4.1 | ⬜ |
| R-6.4 | Dual-level model: glyph level and Unicode-letter level both first-class, lossless switching | `MK/Arrange/LevelMapping.swift` | ✅ shipped | `:mk-arrange` | 4.1 | ⬜ |
| R-6.5 | Every Glyph/Mark/Ligature node independently selectable/transformable with full style surface | `MK/Canvas/Arrange/**` (interaction model) | ✅ shipped | `:mk-canvas` | 5.4b | ⬜ |
| R-6.6 | Multi-select within a composition (marquee + additive tap); distribute/space about common bounds | `MK/Canvas/Arrange/**` | ✅ shipped | `:mk-canvas` | 5.4b | ⬜ |
| R-6.7 | Contextual arrange toolbar: level toggle, break/decompose, mark attach/detach, form selector, revert, close | `Makhtoot/AppShell/Scenes/Editor/ArrangeToolbarView.swift` | ✅ shipped | `:app` | 7.5 | ⬜ |
| R-6.8 | Provenance completeness: codepoints/glyph id/font ref/joining form/cluster id/bidi level per node | `MK/Arrange/ArrangeDeriver.swift` | ✅ shipped | `:mk-arrange` | 4.1 | ⬜ |
| R-6.9 | Hit-testing in Arrange uses outline bounds +6pt touch inflation; magnifier loupe for sub-12pt nodes | `MK/Canvas/Arrange/**` | ✅ shipped | `:mk-canvas` | 5.4b | ⬜ |
| R-6.10 | Composition remains one canvas object in manipulation mode; re-entering Arrange resumes intact | `MK/Canvas/Arrange/**` | ✅ shipped | `:mk-canvas` | 5.4b | ⬜ |
| R-6.11 | Double-tapping an Arranged Composition opens a choice sheet (revert&edit / duplicate&edit / cancel), never the text overlay directly | `MK/Arrange/RevertService.swift`, `Makhtoot/AppShell/Scenes/Editor/MergeDesignSheet.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-6.12 | Revert-to-text (FL-13): confirmation, discards arrangement, restores Live Text from Source Text Backup, re-shapes | `MK/Arrange/RevertService.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-6.13 | Non-blocking "منسّق" (arranged) badge with glyph-count subtitle in layers panel | `Makhtoot/AppShell/Scenes/Editor/LayersPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-6.14 | Letter-level selection spanning a bidi-run boundary splits into per-run sub-selections with independent bounds | `MK/Canvas/Arrange/**`, `MK/TextEngine/BidiMap.swift` | ✅ shipped | `:mk-canvas` | 5.4b | ⬜ |

---

## §7 Tashkeel & Marks (`PRD.md` §7) — 10 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-7.1 | Full mark coverage: standard tashkeel + superscript alef + honorific + Qur'anic-annotation ranges, as character handling only | `MK/TextEngine/MarkClassifier.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-7.2 | Mn/Me marks → Mark Nodes at derivation; font-fused marks stay part of base, listed non-detachable | `MK/Arrange/MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-7.3 | Default: Mark Node attached to base with shaped relative offset, follows base transform | `MK/Arrange/MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-7.4 | Individual mark manipulation without detaching; user delta stored atop follow-base attachment | `MK/Arrange/MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-7.5 | Explicit detach ("فصل الحركة") / re-attach ("إرفاق بالحرف") recomputing relative offset | `MK/Arrange/MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-7.6 | Multiple marks per base: each its own node, shaped z-order preserved, cycle-select on overlap | `MK/Arrange/MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-7.7 | "الحركات (n)" marks-list chip opens mini list by Arabic mark name for precise selection | `Makhtoot/AppShell/Scenes/Editor/ArrangeToolbarView.swift` | ✅ shipped | `:app` | 7.5 | ⬜ |
| R-7.8 | Shadda+kasra: font's shaped result preserved as-is, no normalization/reordering of stored codepoints ever | `MK/Arrange/MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-7.9 | Marks inherit fill at derivation then style independently; "توحيد لون الحركات" bulk-unify action | `MK/Arrange/MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-7.10 | Marks on decomposed ligatures/broken joins keep correct attachment to their constituent base | `MK/Arrange/LigatureDecomposer.swift`, `MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |

---

## §8 Ligatures & Joining (`PRD.md` §8) — 14 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-8.1 | Joining preserved by default everywhere; moving glyphs never changes letterforms | `MK/Arrange/ArrangeInvariants.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.2 | Breaking a join is explicit ("فك الارتباط"); glyph keeps current form/position, form selector becomes available | `MK/Arrange/JoinController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.3 | Form selector shows 4 contextual forms rendered live in the composition's font | `Makhtoot/AppShell/Scenes/Editor/FormSelectorPopoverView.swift` | ✅ shipped | `:app` | 7.5 | ⬜ |
| R-8.4 | Form realization via synthetic ZWJ context reshape + glyph harvest (D-107); never presentation-form codepoints | `MK/TextEngine/FormResolver.swift` | ✅ shipped | `:mk-textengine` | 3.3 | ⬜ |
| R-8.5 | Letters with fewer than 4 forms show only valid forms, rendered live and honest | `Makhtoot/AppShell/Scenes/Editor/FormSelectorPopoverView.swift` | ✅ shipped | `:app` | 7.5 | ⬜ |
| R-8.6 | Restore join returns to originally-captured form via provenance, not a re-shape of the composition | `MK/Arrange/JoinController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.7 | Breaking one letter's join never reshapes neighbors (documented freeze semantics + one-time hint) | `MK/Arrange/JoinController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.8 | Ligature classes: mandatory lam-alif family + font-defined discretionary/contextual (toggleable pre-arrangement) | `MK/TextEngine/LigatureDetector.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.9 | Ligature is both a combined selectable object AND decomposable into constituents on explicit action | `MK/Arrange/LigatureDecomposer.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.10 | Decomposition fidelity default: single-affine fit within [0.85,1.15] scale clamp, Δ≤0.5pt (D-108/D-221) | `MK/Arrange/LigatureDecomposer.swift`, `DecomposeOptions.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.11 | Fidelity opt-out: "استخدام الأشكال الافتراضية" re-lays constituents with default spacing/forms | `MK/Arrange/DecomposeOptions.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.12 | Recomposition restores stored original glyph+group; dirty-check confirms on ANY transform/style delta | `MK/Arrange/LigatureDecomposer.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.13 | Marks riding a ligature re-attach to the constituent owning their codepoint at decomposition | `MK/Arrange/LigatureDecomposer.swift`, `MarkAttachmentController.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |
| R-8.14 | Word-ligature fonts (e.g. الله) produce one Ligature Group; fallback to default forms if constituents unresolvable | `MK/Arrange/LigatureDecomposer.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |

---

## §9 Path Text (`PRD.md` §9) — 10 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-9.1 | Path Text creation via arc/circle/wave/freeform tool; freeform opens pen-style path editor | `MK/PathText/BezierPathModel.swift`, `Makhtoot/AppShell/Scenes/Editor/PathOptionsPopoverView.swift` | ✅ shipped | `:mk-pathtext` | 4.3 | ⬜ |
| R-9.2 | Arc-length LUT layout, visual-order RTL-aware pen advance, tangent rotation, mixed-bidi sub-run coherence (D-110) | `MK/PathText/ArcLengthLUT.swift`, `PathLayoutEngine.swift` | ⚠️ shipped with known gap (ArcLengthLUT is imprecise, ~0.9pt error on straight segments — 9× its own <0.1pt budget — because `bezierPathData()` emits degenerate control points and the adaptive sampler only measures spatial flatness; open per 2026-07-30 founder handover, directly relevant to Android's G4 render-tolerance work) | `:mk-pathtext` | 4.3 | ⬜ |
| R-9.3 | Live behavior: retype/font/size/tracking changes relayout; path itself editable in live mode | `MK/PathText/PathLayoutEngine.swift`, `PathEditModel.swift` | ✅ shipped | `:mk-pathtext` | 4.4 | ⬜ |
| R-9.4 | Path controls: start offset, side flip, tracking-on-path, reverse direction | `MK/PathText/PathLayoutOptions.swift` | ✅ shipped | `:mk-pathtext` | 4.3 | ⬜ |
| R-9.5 | Overflow: text longer than path clips with "+n" badge, no auto-shrink | `MK/PathText/PathLayoutEngine.swift` | ✅ shipped | `:mk-pathtext` | 4.3 | ⬜ |
| R-9.6 | Marks on path text follow base rotation (tangent) so tashkeel stays radially correct | `MK/PathText/PathGlyphPlacement.swift` | ✅ shipped | `:mk-pathtext` | 4.3 | ⬜ |
| R-9.7 | "تنسيق الحروف" on Path Text freezes to Arranged Composition exactly as §6, provenance includes source path | `MK/PathText/PathTextCommands.swift`, `MK/Arrange/ArrangeDeriver.swift` | ✅ shipped | `:mk-pathtext` | 4.3 | ⬜ |
| R-9.8 | After arrangement path is no longer editable, never re-flows; geometry retained in Source Text Backup | `MK/PathText/PathTextCommands.swift` | ✅ shipped | `:mk-pathtext` | 4.3 | ⬜ |
| R-9.9 | Frozen path optionally shown as non-interactive ghost guide for alignment; never renders in export | `Makhtoot/AppShell/Scenes/Editor/PathGhostGuideOverlay.swift` | ✅ shipped | `:app` | 7.5 | ⬜ |
| R-9.10 | Revert of arranged path composition restores live Path Text with original string, style, AND path | `MK/Arrange/RevertService.swift` | ✅ shipped | `:mk-arrange` | 4.2 | ⬜ |

---

## §10 Layers & Inspector (`PRD.md` §10) — 10 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-10.1 | Layers panel lists all top-level nodes + expandable hierarchies; thumbnail/name/eye/lock per row | `Makhtoot/AppShell/Scenes/Editor/LayersPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.2 | Reorder via drag = z-order; reordering inside an Arranged Composition changes intra-composition z-order | `Makhtoot/AppShell/Scenes/Editor/LayersPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.3 | Auto-generated Arabic row names, renamable inline; virtualized list for 5,000+ nodes | `Makhtoot/AppShell/Scenes/Editor/LayersPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.4 | Panel presentation: iPad persistent side panel (right edge), iPhone bottom sheet at half/full detents | `Makhtoot/AppShell/Scenes/Editor/LayersPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.5 | Multi-select in panel (edit mode) supports bulk hide/lock/delete/group | `Makhtoot/AppShell/Scenes/Editor/LayersPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.6 | Numeric inspector: X/Y/W/H/rotation + type-relevant style/transform fields | `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.7 | Fields accept Arabic-Indic OR European digits; display uses locale-appropriate digits, RTL field alignment | `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.8 | Mixed selection shows shared fields, differing values as "—"; steppers ±1/±10, scrubbing continuous | `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.9 | W/H fields: Live Text W wraps (H read-only); Arranged Composition W/H scale (aspect-locked default) | `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-10.10 | Every inspector edit is undoable and autosaved | `MK/Persistence/Undo/UndoStack.swift` | ✅ shipped | `:mk-persistence` | 3.5 | ⬜ |

---

## §11 Shapes/Ornaments/Assets & Imports (`PRD.md` §11) — 12 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-11.1 | Bundled placeable vector assets: shapes/ornaments/frames/calligraphic elements/pattern backgrounds, licensed | `MK/Assets/Generators/*.swift` | ✅ shipped | `:mk-assets` | 5.5a | ⬜ |
| R-11.2 | Not templates: one object per tap, no pre-composed layouts/placeholders/start-from-design gallery | `MK/Assets/Browser/MKAssetBrowserModel.swift` | ✅ shipped | `:mk-assets` | 5.5a | ⬜ |
| R-11.3 | Categorized RTL asset browser grid, Arabic-tag search, favorites; inserted as ordinary styleable nodes | `MK/Assets/Browser/*.swift` | ✅ shipped | `:mk-assets` | 5.5a | ⬜ |
| R-11.4 | Pattern backgrounds: vector tiles w/ scale+colorway, premium-only (D-215), browsable with lock badges free | `MK/Assets/Instantiation/MKPatternInstantiator.swift` | ✅ shipped | `:mk-assets` | 5.5b | ⬜ |
| R-11.5 | Asset packs as downloadable premium content: schema hook only (`packId`), no UI/downloads in v1 (P2-seam) | `MK/Assets/Model/MKAssetDescriptor.swift` | ✅ shipped | `:mk-assets` | 5.5a | ⬜ |
| R-11.6 | Import types: raster/SVG/PDF/fonts via Files/Photos/paste/iPad drag-drop-in | `Makhtoot/AppShell/Scenes/Editor/BackgroundImageSheet.swift`, `BackgroundImageSupport.swift` | ⚠️ shipped with known gap (AUDIT EU-6 "no drag and drop" — open/Wave-5-founder-gated; PRD explicitly requires iPad drag-and-drop-in as an import source) | `:app` | 7.6 | ⬜ |
| R-11.7 | Photo/raster import gated premium/trial-only (covers backgrounds and placed raster elements, D-217) | `MK/Store/MKEntitlementResolver.swift` (gate check) | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-11.8 | SVG import: internal SVG→CG interpreter for supported subset; unsupported constructs rasterize with notice | no dedicated agent named in spine — judgment call, closest owner is the general import-sheet agent | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-11.9 | PDF import: page 1 (multi-page picker) placed as vector-preserving node via CGPDF drawing | no dedicated agent named in spine — judgment call, closest owner is the general import-sheet agent | ✅ shipped | `:app` | 7.6 | ⬜ |
| R-11.10 | Imported assets copied content-addressed into `assets/`, deduplicated by hash, originals never referenced in place | `MK/Persistence/AssetStore.swift` | ✅ shipped | `:mk-persistence` | 3.6 | ⬜ |
| R-11.11 | Import validation: corrupt/oversized rejected with Arabic errors; 50MP downsample, 20MB SVG/PDF soft cap | `MK/Persistence/PackageImportValidator.swift` | ✅ shipped | `:mk-persistence` | 3.4 | ⬜ |
| R-11.12 | Image nodes: crop/corner-radius/opacity/stroke/shadow; no filters/adjustments in v1 (P2-seam) | `Makhtoot/AppShell/Scenes/Editor/InspectorPanelView.swift` | ✅ shipped | `:app` | 7.6 | ⬜ |

---

## §12 Fonts & Catalog (`PRD.md` §12) — 11 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-12.1 | Curated bundled OFL-verified starter fonts, free AND premium; KFGQPC prohibited | `MK/Fonts/BundledFontIndex.swift` | ✅ shipped | `:mk-fonts` | 3.7 | ⬜ |
| R-12.2 | Downloadable premium catalog, static JSON manifest on founder-hosted HTTPS, entitlement-gated download | `MK/Fonts/MKPremiumDelivery.swift`, `MKCatalogManifestFetchService.swift` | ⚠️ shipped with known gap (AUDIT FC-5: hosted premium-font delivery is entirely inert — `.bundledFallback` used in production; open/Wave-5-founder-gated; FDA-04 keeps Android on the same fallback posture) | `:mk-fonts` | 6.5 | ⬜ |
| R-12.3 | User font import via Files picker (premium): sfnt validation, content-addressed copy, per-process registration | `MK/Fonts/MKFontImporter.swift`, `MKFontValidator.swift` | ✅ shipped | `:mk-fonts` | 3.7 | ⬜ |
| R-12.4 | Catalog schema carries `licenseType`/`embeddingRights`/`foundry`/`commercialStatus` from day one (no commercial fonts ship v1) | `MK/Fonts/MKFontTypes.swift` | ✅ shipped | `:mk-fonts` | 6.5 | ⬜ |
| R-12.5 | Catalog browser: live previews, styles/weights, 10 category chips, tags, favorites, search | `Makhtoot/AppShell/Scenes/Editor/FontBrowserSheet.swift` | ✅ shipped | `:app` | 7.7 | ⬜ |
| R-12.6 | Character coverage computed from cmap; picker shows coverage badge for current text selection | `MK/Fonts/MKCoverageAnalyzer.swift` | ✅ shipped | `:mk-fonts` | 3.7 | ⬜ |
| R-12.7 | License/attribution/foundry/coverage/source links live at Settings→Support→Licensing, not primary catalog UI | `Makhtoot/AppShell/Scenes/Settings/LicensingView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-12.8 | Premium download UX: size shown, progress/cancel/resumable, cached, free re-download after reinstall | `MK/Fonts/MKFontDownloader.swift` | ✅ shipped (progress-stream continuation leak, EU-9, fixed Wave 2 commit `2fe2342`) | `:mk-fonts` | 6.5 | ⬜ |
| R-12.9 | Font lifecycle: deleted/uninstalled font while in use → fallback render + re-download/re-import offer, document never fails to open | `MK/Fonts/MKFontLockController.swift` | ✅ shipped | `:mk-fonts` | 6.5 | ⬜ |
| R-12.10 | Expiry locking (D-119): catalog/imported fonts lock on fall to free; last-cached-shaping display, re-shape blocked | `MK/Fonts/MKFontLockController.swift` | ✅ shipped | `:mk-fonts` | 6.5 | ⬜ |
| R-12.11 | Catalog manifest fetch/cache: 24h staleness TTL, cache-first browse, honest empty-state on zero-manifest-ever | `MK/Fonts/MKCatalogManifestFetchService.swift` | ✅ shipped (response-size-cap gap S-8 fixed Wave 2, commit `2fe2342`) | `:mk-fonts` | 6.5 | ⬜ |

---

## §13 Export (`PRD.md` §13) — 15 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-13.1 | Single render path: every export renders from immutable scene snapshot via MKRender, never screen capture | `MK/Export/ExportCoordinator.swift` | ✅ shipped | `:mk-export` | 5.6 | ⬜ |
| R-13.2 | Free tier: JPEG + rasterized PDF, both capped at 2MP effective, applied at render never by downscale | `MK/Export/FreeTierBudget.swift`, `ExportGate.swift` | ⚠️→✅ (FC-2 fixed; packet's cited commit `ec9887c` is wrong, actual fix is `d885fe2`; see impl log) | `:mk-export` | 5.6 | ⬜ |
| R-13.3 | Premium/trial: opaque PNG, transparent PNG, SVG, high-res print PDF, uncapped JPEG/PDF | `MK/Export/ExportGate.swift` | ⚠️→✅ (FC-2 fixed, commit `d885fe2` — see impl log) | `:mk-export` | 5.6 | ⬜ |
| R-13.4 | Premium hi-res: 4K+/300-DPI/unlimited scaling bounded only by memory protection, tiled strip rendering | `MK/Export/TiledRasterExporter.swift` | ✅ shipped | `:mk-export` | 5.6 | ⬜ |
| R-13.5 | Transparent PNG: alpha preserved, background node excluded when toggled (premium) | `MK/Export/RasterEncoders.swift` | ✅ shipped | `:mk-export` | 5.6 | ⬜ |
| R-13.6 | SVG preserves editable text/vector objects: Live Text→`<text>`, arranged glyphs→`<g><path>` with `data-mk-*` provenance | `MK/Export/SVGTextWriter.swift`, `SVGProvenance.swift` | ⚠️ shipped with known gap (AUDIT FC-4: no font subsetting — full font embedded per family, deliberate deferral; bold/italic face resolution unresolved at `SVGTextWriter.swift:201` at audit time, same root cause as FC-1; approval-gated Wave 5, status post-Wave-1 bold/italic fix not independently re-verified here) | `:mk-export` | 5.6 | ⬜ |
| R-13.7 | Outlining is a documented per-feature fallback only, never silent; export sheet lists exactly which objects outline and why | `MK/Export/TextOutlining.swift`, `MKOutlineSubstitutePainter.swift` | ⚠️ shipped with known gap (AUDIT FC-4 item 3: placeholder outline geometry in one `SVGSerializer.swift:380` branch, open at audit time) | `:mk-export` | 5.6 | ⬜ |
| R-13.8 | SVG writer is a custom serializer (no system API); validated against SVG 1.1 static subset, `direction="rtl"` | `MK/Export/SVGSerializer.swift` | ✅ shipped | `:mk-export` | 5.6 | ⬜ |
| R-13.9 | Print PDF: vector + live-text runs, 300-DPI raster floor, true CMYK with ICC-aware output | `MK/Export/PDFPrintCMYKExporter.swift`, `PDFVectorExporter.swift` | ✅ shipped | `:mk-export` | 5.7b | ⬜ |
| R-13.10 | Color pipeline: extended sRGB → CMYK via `CGColorSpace(iccData:)`, relative colorimetric, OutputIntent-embedded | `MK/Export/PDFOutputIntent.swift`, `MK/Color/CMYKConverter.swift` | ✅ shipped | `:mk-export` | 5.7b | ⬜ |
| R-13.11 | Export sheet CMYK controls: RGB/CMYK toggle, profile name shown, color-difference disclaimer | `Makhtoot/AppShell/Scenes/Editor/*ExportUI*` (export sheet) | ✅ shipped | `:mk-export` | 5.7b | ⬜ |
| R-13.12 | Presets at 2MP baseline (free) + premium custom dims; same list drives new-project canvas presets | `MK/Export/ExportPresets.swift` | ✅ shipped | `:mk-export` | 5.6 | ⬜ |
| R-13.13 | Every export writes an export-history record (tier/format/dims/color-space/fallbacks applied) | `MK/Persistence/Metadata/MetadataModels.swift` | ✅ shipped | `:mk-persistence` | 3.6 | ⬜ |
| R-13.14 | Arabic output sharpness is a release gate: manual verification of shaping/marks/decomposed ligatures at print res | manual QA process, no single file | ✅ shipped (process, re-executed for Android at parity gate) | `:mk-render`/`:mk-export` | 8.3 | ⬜ |
| R-13.15 | Destination: share sheet, Files save, Photos save (raster only); Arabic-safe default filenames | `MK/Export/MKFilenameSanitizer.swift` | ✅ shipped | `:mk-export` | 5.6 | ⬜ |

---

## §14 Free/Premium Gating & Paywall (`PRD.md` §14) — 18 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-14.1 | Exhaustive G1–G26 gating matrix across tiers (Free/Trial/Premium/Expired) | `MK/Store/MKEntitlementResolver.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-14.2 | No caps anywhere on canvas size/glyph/object count for ANY tier; perf protections never tier features | `MK/Store/MKEntitlementResolver.swift` (policy) | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-14.3 | Free tier is permanent and honest: G1–G7/G10/G12–G14/G24 never regress behind a paywall without founder decision | `MK/Store/MKEntitlementResolver.swift` (policy) | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-14.4 | Gating enforced at content-creation time AND export time (render request, D-119); never via watermark | `MK/Export/ExportGate.swift` | ⚠️→✅ (FC-2 fixed, commit `d885fe2`, not `ec9887c` as this packet cites — see impl log) | `:mk-export` | 5.6 | ⬜ |
| R-14.5 | "Premium content present" project flag set when project contains premium fonts/photo bg/premium assets (D-119) | `MK/Assets/Instantiation/MKPremiumContentLedger.swift` | ⚠️ shipped with known gap (AUDIT FC-7: export gate can't see premium *assets*, only fonts/backgrounds; open/Wave-5-founder-gated) | `:mk-assets` | 5.5b | ⬜ |
| R-14.6 | Free background = solid colors only (D-215); color picker itself never gated | `MK/Assets/Instantiation/MKPatternInstantiator.swift` | ✅ shipped | `:mk-assets` | 5.5a | ⬜ |
| R-14.7 | Unified 🔒 "مميّز" lock-badge chip on gated rows; tap always explains before showing paywall | `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-14.8 | Expired-tier locked-content UX: banner + replace-fonts/subscribe actions; replacement re-shapes Live Text | `MK/Fonts/MKFontLockController.swift` | ✅ shipped | `:mk-fonts` | 6.5 | ⬜ |
| R-14.9 | Expired export of premium-content projects blocked with replace-or-subscribe sheet enumerating exact items | `MK/Export/ExportGate.swift` | ✅ shipped | `:mk-export` | 5.6 | ⬜ |
| R-14.10 | Products: monthly/annual/lifetime at founder-intent price tiers, StoreKit localized price strings always | `MK/Store/MKProductCatalog.swift`, `MKStoreIDs.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-14.11 | Guideline 3.1.2 compliance: title/length/price adjacent to CTA, functional Privacy/Terms links, visible close, no urgency mechanics | `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-14.12 | CTA disclosure copy: exact Arabic price/trial/renewal/cancel-anytime strings from `Product.displayPrice` | `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-14.13 | "استعادة المشتريات" (Restore Purchases) mandatory, always-visible on paywall + Settings | `MK/Store/MKPurchaseController.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-14.14 | Paywall layout: benefits mirror gating matrix, live premium-font hero sample, plan selector defaults annual | `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-14.15 | Paywall entry points: lock badges, export sheet, catalog, import pickers, sync toggle, Settings, trial banner — all user-initiated | `Makhtoot/AppShell/Scenes/Paywall/PaywallView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-14.16 | Win-back/offer-code UI not in v1; StoreKit offer-code sheet reachable from Settings only if trivially enabled (P2-seam) | absence of feature | ✅ shipped (intentional absence) | `:app` | 7.8 | ⬜ |
| R-14.17 | `premiumContentPresent` walk iterates ALL nodes regardless of hidden/locked; `MKExportGate` enforces preset-membership at engine level | `MK/Export/ExportGate.swift:72-80` | ⚠️→✅ (FC-2/D-229 fixed, commit `d885fe2`, not `ec9887c` as this packet cites; FC-7 asset-visibility gap per R-14.5 still open — see impl log) | `:mk-export` | 5.6 | ⬜ |

---

## §15 Trial / Subscription / Lifetime States (`PRD.md` §15) — 13 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-15.1 | Entitlement states + precedence (D-113): lifetime>subscribed>grace>billingRetry>trial>free, single resolver | `MK/Store/MKEntitlementResolver.swift`, `MKEntitlementPrecedence.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-15.2 | On-device StoreKit 2 JWS verification; server-side validation is a documented v2 seam | `MK/Store/Verification.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-15.3 | Premium capability set identical for lifetime/subscribed/grace/billingRetry; only banner messaging differs | `MK/Store/MKEntitlementDetail.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-15.4 | Lifetime + subscription both present: lifetime wins display, cancel guidance shown, never auto-refund/hide | `MK/Store/MKEntitlementResolver.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-15.5 | 7-day trial starts at first app launch for everyone; fully premium during trial | `MK/Store/Trial/MKTrialManager.swift` | ✅ shipped | `:mk-store` | 6.2 | ⬜ |
| R-15.6 | Trial persisted in Keychain (survives reinstall) + iCloud KVS mirror; earliest timestamp wins across devices | `MK/Store/Trial/MKSecureStore.swift`, `MKUbiquitousStore.swift` | ✅ shipped | `:mk-store` | 6.2 | ⬜ |
| R-15.7 | Clock-rollback guard: monotonic checks, rollback never extends trial | `MK/Store/Trial/MKClockProviding.swift` | ✅ shipped | `:mk-store` | 6.2 | ⬜ |
| R-15.8 | No App Store Connect intro offer configured in v1, avoids double-trial divergence | `MK/Store/Trial/MKTrialManager.swift` | ✅ shipped | `:mk-store` | 6.2 | ⬜ |
| R-15.9 | Trial UI: status chip "باقي n أيام", day-1 onboarding explanation, expiry-day banner | `Makhtoot/AppShell/Scenes/Browser/ProjectBrowserView.swift` | ✅ shipped | `:mk-store` | 6.2 | ⬜ |
| R-15.10 | Required Arabic copy per entitlement state (10-row table); active-trial copy always wins over expired-was-premium (D-228) | `MK/Store/MKEntitlementDetail.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-15.11 | Grace/billingRetry banners deep-link to `showManageSubscriptions`; exact grace duration never hardcoded | `MK/Store/MKEntitlementDetail.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-15.12 | State transitions apply reactively (`Transaction.updates`); open export sheet re-validates at render request | `MK/Store/MKEntitlementResolver.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |
| R-15.13 | Post-purchase redundant-subscription prompt (D-228): lifetime purchase while active sub exists → cancel prompt | `MK/Store/MKPurchaseController.swift` | ✅ shipped | `:mk-store` | 6.1 | ⬜ |

---

## §16 Referral, flag OFF (`PRD.md` §16) — 5 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-16.1 | Referral ships architected-but-disabled behind `MKFeatureFlags.referralProgram = OFF`; D-225 compile-time exclusion from Release | `MK/Store/Referral/*.swift`, `MK/Foundation/MKFeatureFlags.swift` | ✅ shipped | `:mk-store` | 6.2 | ⬜ |
| R-16.2 | Dormant mechanic: referrer-only +7-day-trial reward per qualifying invite, invitee gets nothing, max 4 extensions | `MK/Store/Referral/MKReferralLedger.swift` | ✅ shipped | `:mk-store` | 6.2 | ⬜ |
| R-16.3 | Dormant attribution: local code gen, share/manual entry, honor-based (no server); qualifying event definition open per FD-05 | `MK/Store/Referral/MKReferralCodeGenerator.swift`, `MKReferralRedemption.swift` | ⚠️ shipped with known gap (AUDIT FC-8: referral qualifying action is a placeholder; open/Wave-5-founder-gated; module stays dormant behind the flag regardless, so low activation risk) | `:mk-store` | 6.2 | ⬜ |
| R-16.4 | Removal path: deleting `MKStore/Referral` folder + flag removes feature completely, no dangling schema | `MK/Store/Referral/**` | ✅ shipped | `:mk-store` | 6.2 | ⬜ |
| R-16.5 | Review-risk documentation memo (3.1.1 circumvention concern, no reward may ever gate core functionality) | doc (`APP_STORE_CHECKLIST.md` cross-ref) | ✅ shipped | `:mk-store` | 6.2 | ⬜ |

---

## §17 iCloud Sync, premium (`PRD.md` §17) — 9 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-17.1 | Premium CKSyncEngine sync in user's own iCloud, container `iCloud.net.binjamshid.makhtoot`, no account/SIWA | `MK/Sync/Engine/MKSyncEngineController.swift` | ✅ shipped | `:mk-sync` | 6.3a | ⬜ |
| R-17.2 | Record design: one record per project, manifest+scene as encrypted-asset payloads, assets as CKAssets | `MK/Sync/Serialization/MKProjectRecordCoder.swift` | ✅ shipped | `:mk-sync` | 6.3b | ⬜ |
| R-17.3 | Conflict policy: last-writer-wins per project, "(نسخة متعارضة)" conflict-copy fallback | `MK/Sync/Conflict/MKSyncDecisionEngine.swift`, `MKConflictNaming.swift` | ✅ shipped | `:mk-sync` | 6.3b | ⬜ |
| R-17.4 | Sync is opt-in Settings toggle, premium-gated, default OFF even for premium | `Makhtoot/AppShell/Scenes/Settings/SyncSettingsView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-17.5 | Per-project sync status glyph in browser; Settings sync pane shows account state, last sync, quota errors | `MK/Sync/Status/MKSyncStatus.swift` | ✅ shipped | `:mk-sync` | 6.3b | ⬜ |
| R-17.6 | Account states handled: no account, account switch (re-scope), sign-out (pause), restricted/managed | `MK/Sync/Account/MKSyncAccountState.swift` | ✅ shipped | `:mk-sync` | 6.3b | ⬜ |
| R-17.7 | Offline: full editing offline, changes queue, drains on reconnect, never blocks editing/export | `MK/Sync/ChangeTracking/MKSyncPendingQueue.swift` | ✅ shipped | `:mk-sync` | 6.3b | ⬜ |
| R-17.8 | Large projects: assets chunk as CKAssets; over-limit assets marked "محلي فقط" with documented notice | `MK/Sync/Engine/MKSyncEngineController.swift` | ✅ shipped | `:mk-sync` | 6.3a | ⬜ |
| R-17.9 | Sync pauses on fall to free (no upload/download); local projects never deleted/degraded; re-subscribe resumes | `MK/Sync/Conflict/MKSyncDecisionEngine.swift` (policy) | ✅ shipped | `:mk-sync` | 6.3b | ⬜ |

---

## §18 Analytics & Privacy (`PRD.md` §18) — 7 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-18.1 | Only analytics: anonymous opt-in font-usage, default OFF, versioned consent, immediate stop on opt-out | `MK/Analytics/Consent/MKConsentManager.swift`, `MKConsentRecord.swift` | ✅ shipped | `:mk-analytics` | 6.4 | ⬜ |
| R-18.2 | Data minimization: on-device fontID→count buckets; upload = anonymous ephemeral-UUID batches, week-granularity, bucketed | `MK/Analytics/Upload/MKFontUsageBatch.swift` | ✅ shipped | `:mk-analytics` | 6.4 | ⬜ |
| R-18.3 | Never collected/uploaded: user text, project content, identifiers, font files, imported assets, device fingerprints | `MK/Analytics/Counter/MKUsageCounterStore.swift` | ✅ shipped | `:mk-analytics` | 6.4 | ⬜ |
| R-18.4 | No ads, no third-party analytics/crash SDKs; App Privacy label reflects usage-data-optional | doc + `MK/Analytics/**` (absence of SDK) | ✅ shipped | `:mk-analytics` | 6.4 | ⬜ |
| R-18.5 | Kill switch: local flag disables analytics entirely (compile-time + runtime), independent of consent state | `MK/Analytics/MKAnalyticsError.swift`, `Consent/MKConsentStatus.swift` | ✅ shipped | `:mk-analytics` | 6.4 | ⬜ |
| R-18.6 | Privacy Policy + Terms links in Settings→الدعم and App Store metadata | `Makhtoot/AppShell/Scenes/Settings/SupportSettingsView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-18.7 | Territory posture: distribute where no extra legal docs/registration required; checklist in APP_STORE_CHECKLIST | doc | ✅ shipped | `:mk-analytics` | 6.4 | ⬜ |

---

## §19 Offline Behavior (`PRD.md` §19) — 4 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-19.1 | Fully offline permanently; only 3 network uses; architecturally only MKFonts/MKSync/MKAnalytics may network | `MK/Fonts/MKFontDownloader.swift`, `MK/Sync/**`, `MK/Analytics/Upload/**` | ✅ shipped | cross | 8.1 | ⬜ |
| R-19.2 | Per-feature offline matrix (12 rows: browser/canvas/fonts/export/purchase/entitlement/trial/sync/analytics/settings) | cross-cutting | ✅ shipped | cross | 8.1 | ⬜ |
| R-19.3 | Airplane-mode acceptance: FL-2…FL-10 and FL-13 pass end-to-end on a fresh install | manual/automated QA process | ✅ shipped | `:app` | 8.6 | ⬜ |
| R-19.4 | No feature shows a spinner waiting on network without cancel/queue path; interrupted downloads resume | `MK/Fonts/MKFontDownloader.swift` | ✅ shipped | `:mk-fonts` | 6.5 | ⬜ |

---

## §20 Settings & Licensing (`PRD.md` §20) — 6 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-20.1 | Settings IA (RTL): subscription/sync/editing/privacy/support(incl. licensing)/about | `Makhtoot/AppShell/Scenes/Settings/GeneralSettingsView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-20.2 | Settings→Support→Licensing is canonical home for per-font license/attribution/foundry/coverage/source | `Makhtoot/AppShell/Scenes/Settings/LicensingView.swift`, `LicenseFontDetailView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-20.3 | OFL compliance surface: copyright notice + full license text per font, reserved-font-name rules respected | `Makhtoot/AppShell/Scenes/Settings/LicenseFontDetailView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-20.4 | Contact = mailto link only, no in-app forms/chat | `Makhtoot/AppShell/Scenes/Settings/SupportSettingsView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-20.5 | About screen shows schemaVersion + diagnostics export (zip of logs, no user content) | `Makhtoot/AppShell/Scenes/Settings/GeneralSettingsView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |
| R-20.6 | Manage subscription opens system subscription-management sheet | `Makhtoot/AppShell/Scenes/Settings/GeneralSettingsView.swift` | ✅ shipped | `:app` | 7.8 | ⬜ |

---

## §21 Edge-Case Compendium (`PRD.md` §21) — 61 ids

Default owner for this section is Batch 8 · Agent 8.7, whose own mission statement is literally
"Edge-case compendium sweep (PRD §21)" and "Close out `android/PARITY_MATRIX.md`: every one of
the [318] `R-…` ids must be ✅" — i.e. 8.7 is the plan's own designated closer for this section,
not an inferred default. Two ids (R-21.64, R-21.65) are reassigned to 8.4 because they are the
D-116/D-223 memory-pressure ladder itself, which 8.4's mission explicitly owns ("Verify the
D-116/D-223 memory ladder against `onTrimMemory` levels including the critical journal-only
flush").

### 21.1 Text input & Unicode

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.1 | Empty Live Text deletes silently; Arranged Composition can never be empty; deleting last glyph deletes composition (undoable) | `MK/Arrange/ArrangeCommands.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.2 | Tashkeel-only input renders on dotted circles per Core Text default; arrangement treats dotted-circle+mark as a pair | `MK/TextEngine/MarkClassifier.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.3 | Unlimited marks per base become individual nodes preserving shaped stacking order; 10+ marks don't break hit-test/export | `MK/Arrange/MarkAttachmentController.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.4 | Shadda+kasra ordering preserved exactly as entered either order; no Unicode normalization anywhere in pipeline | `MK/TextEngine/ClusterMap.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.5 | Lam-alif inside words: medial/final-context ligatures are Ligature Groups exactly like isolated لا | `MK/Arrange/LigatureDecomposer.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.6 | ZWJ/ZWNJ pasted input preserved as real codepoints; control-character badge; engine's own ZWJ synthesis never leaks into user string | `MK/TextEngine/ClusterMap.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.7 | Marks across ligature decomposition re-attach per cluster map; never orphaned, never dropped | `MK/Arrange/LigatureDecomposer.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.8 | RTL/LTR paste preserves codepoints + directional controls exactly; explicit "إزالة أحرف التحكم" cleanup only | `MK/TextEngine/BidiMap.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.9 | Word-ligature fonts that can't decompose sensibly fall back to default forms with notice; never crash/emit .notdef | `MK/Arrange/LigatureDecomposer.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.10 | Emoji/non-Arabic: system cascade render; single non-outlinable Glyph Node; SVG/PDF embeds as image w/ notice (D-227 carve-out) | `MK/Export/TextOutlining.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.11 | Very long single-line text (10,000+ chars): incremental shaping, echo budget, cancellable arrangement HUD, panel virtualization | `MK/TextEngine/ShapingService.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.12 | Kashida/tatweel U+0640: real shapeable joining char, stretchable via scale-X, join-breaks like any glyph | `MK/Arrange/JoinController.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.13 | Paste of styled/rich text: plain-text codepoints only taken, style from target object, no RTF import | `Makhtoot/AppShell/Scenes/Editor/*` (paste handling) | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.14 | Unassigned codepoints/ZWJ emoji sequences render per system, cluster map follows Core Text, never crash | `MK/TextEngine/ClusterMap.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.15 | Mixed-numeral round-trip (٢١٣/123) keeps codepoints, reorders per UBA, per-digit glyph nodes in visual order | `MK/TextEngine/BidiMap.swift` | ✅ shipped | cross | 8.7 | ⬜ |

### 21.2 Fonts

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.20 | .notdef never draws silently; fallback badge + export disclosure; arrangement records actual fallback font | `MK/Render/Drawers/LiveTextDrawer.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.21 | Font deleted while used: missing-font badge + fallback render + re-download offer; document never fails to open | `MK/Fonts/MKFontLockController.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.22 | Imported font invalid: sfnt rejection w/ specific Arabic errors; registers-but-no-arab-tables warns, not blocked | `MK/Fonts/MKFontValidator.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.23 | Variable font axes recorded in provenance; frozen read-only on Arranged Composition with explanatory hint | `MK/TextEngine/FontFeatureControl.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.24 | Duplicate font family names (imported shadows bundled): keyed by file hash + PostScript name, disambiguated by source chip | `MK/Fonts/MKFontRegistry.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.25 | Expiry with imported fonts locks exactly like premium catalog fonts; files retained for instant restore on re-subscribe | `MK/Fonts/MKFontLockController.swift` | ✅ shipped | cross | 8.7 | ⬜ |

### 21.3 Arrange Mode & editing lifecycle

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.30 | Arrange-then-edit-source conflict per R-6.11; editing via external means is impossible (no external editors) | `MK/Arrange/RevertService.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.31 | Revert confirmation always required, lists adjustment count ≥1; zero-adjustment reverts skip the count line | `MK/Arrange/RevertService.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.32 | Undo across mode switches: global stack, redo re-derives byte-identically (snapshot stored not re-computed) | `MK/Persistence/Undo/UndoStack.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.33 | Deleting a base glyph with attached marks: marks follow into deletion as one command; detached marks survive independently | `MK/Arrange/ArrangeCommands.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.34 | Scaling composition to near-zero clamped at minimum visual size + haptic; inspector never allows 0/negative scale | `MK/Arrange/ArrangeInvariants.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.35 | Arrange during active text editing: arrange button disabled while overlay open, no half-committed derivations | `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.35a | Neutral-punctuation freeze at capture (INV-1/D-109): resolved once at derivation, immune to later neighbor moves | `MK/Arrange/ArrangeDeriver.swift` | ✅ shipped | cross | 8.7 | ⬜ |

### 21.4 Path text

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.36 | Path self-intersection allowed; arc-length layout continues regardless; tangent rotation stays continuous, no glyph flipping | `MK/PathText/PathLayoutEngine.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.37 | Zero-length/degenerate path: editor prevents committing <8pt; no NaN transforms, no crash | `MK/PathText/BezierPathModel.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.38 | Extremely tight curvature: glyphs place on tangent without collision resolution (documented v1 behavior) | `MK/PathText/PathGlyphPlacement.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.39 | Path edit after arrange is impossible by construction; ghost guide is non-interactive | `MK/PathText/PathTextCommands.swift` | ✅ shipped | cross | 8.7 | ⬜ |

### 21.5 Persistence, autosave, documents

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.40 | Duplicate-during-autosave: flush-then-copy snapshot, never a torn file (write-temp+rename atomicity) | `MK/Persistence/Metadata/MetadataStore.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.41 | Storage-full autosave failure: persistent non-dismissable banner, journal keeps un-flushed batch, export blocked | `MK/Persistence/AutosaveController.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.42 | Crash/kill mid-edit: relaunch replays journal, recovery ≤2s of work at risk, subtle "تمت الاستعادة" toast | `MK/Persistence/CrashRecovery.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.43 | Newer schemaVersion opens read-only with explanatory copy; never destructive rewrite | `MK/Model/Schema/MKSceneMigrator.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.44 | Export during memory pressure: D-116 ladder runs first, tiled export proceeds, clean abort + partial-file cleanup on critical stage | `MK/Render/MemoryPressureMonitor.swift`, `MK/Export/TiledRasterExporter.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.45 | Project rename to empty/whitespace rejected inline; names are not filenames (UUID-based packages) | `MK/Persistence/Metadata/MetadataStore.swift` | ✅ shipped | cross | 8.7 | ⬜ |

### 21.6 Sync & iCloud

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.46 | Sync conflicts: last-writer-wins + conflict-copy when both sides diverged; no merge attempts in v1 | `MK/Sync/Conflict/MKSyncDecisionEngine.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.47 | iCloud account switch: CK notification stops engine, re-scopes to new account; old-account projects remain local | `MK/Sync/Account/MKSyncAccountState.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.48 | iCloud sign-out mid-session: sync pauses gracefully, queued changes persist, zero data loss | `MK/Sync/Account/MKSyncAccountState.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.49 | Quota exceeded: per-project error state + Settings copy, backoff retries, editing/export unaffected | `MK/Sync/Errors/MKSyncError.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.50 | Same project edited on two devices offline: both sync on reconnect → conflict handling, tested with arranged compositions | `MK/Sync/Conflict/MKSyncDecisionEngine.swift` | ✅ shipped | cross | 8.7 | ⬜ |

### 21.7 Store, trial, entitlements

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.51 | Purchase interrupted (network/Ask-to-Buy/kill): `Transaction.updates` delivers result later; pending state shown; never double-charges | `MK/Store/MKPurchaseController.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.52 | Trial clock rollback: monotonic guard shows true remaining days; rolling forward expires normally, no un-expire | `MK/Store/Trial/MKClockProviding.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.53 | Restore on a new device re-syncs entitlements; app-side trial pulls earliest KVS timestamp across devices | `MK/Store/Trial/MKUbiquitousStore.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.54 | Lifetime + subscription both present (cross-ref R-15.4): lifetime wins, cancel guidance, nothing hidden | `MK/Store/MKEntitlementResolver.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.55 | Grace-period expiry mid-export: entitlement binds at render request, in-flight export completes and delivers, next export re-evaluates | `MK/Export/ExportGate.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.56 | Refund/revocation drops entitlement reactively (no accusatory copy); mid-export completion rule extends to revocation (D-228) | `MK/Store/MKEntitlementResolver.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.57 | Referral flag OFF: zero referral UI/strings/StoreKit surface anywhere; QA gate greps release UI; typed codes are just text | `MK/Store/Referral/**` (absence when OFF) | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.58 | StoreKit sandbox/product-load failure on paywall: cached product info if available, else retry state, never blank/fabricated | `MK/Store/MKProductCatalog.swift` | ✅ shipped | cross | 8.7 | ⬜ |

### 21.8 Canvas, layers, import

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.59 | Locked/hidden layer interactions: locked skips taps (panel-selectable), hidden excluded from render/hit-test/export | `MK/Render/HitTester.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.60 | Deleting a group with mixed locked/unlocked children: blocked with unlock-and-delete-or-cancel choice | `Makhtoot/AppShell/Scenes/Editor/LayersPanelView.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.61 | Imported SVG w/ unsupported constructs: partial rasterization notice; encrypted PDFs rejected with "ملف PDF محمي" | `MK/Export/**` (import-side interpreter, see R-11.8 judgment call) | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.62 | Pasting an image while free routes through the same import gate as picker import; clipboard untouched | `MK/Store/MKEntitlementResolver.swift` (gate) | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.63 | 5,000-node scenes: panel virtualization, marquee perf, D-115 heavy-open budget <3s are acceptance gates | `MK/Persistence/DocumentPackage.swift` (open budget) | ✅ shipped | cross | 8.7 | ⬜ |

### 21.9 Memory, system, lifecycle

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-21.64 | Memory-pressure staged response (D-116): 70%/85%/critical stages, relaunch restores exactly | `MK/Render/MemoryPressureMonitor.swift`, `MK/Render/DegradationController.swift` | ⚠️ shipped with known gap (`DegradationController.history` unbounded growth, P-8, still open per 2026-07-30 founder handover) | `:mk-render` | 8.4 | ⬜ |
| R-21.65 | Backgrounding during export: continues under background task assertion, clean abort on reclaim, no notification (none permitted v1) | `MK/Persistence/ExportTempDirectory.swift` | ✅ shipped | `:mk-render` | 8.4 | ⬜ |
| R-21.66 | Expiry mid-edit: current operation completes, gates re-evaluate lazily; arranged composition w/ premium font stays editable (outlines) | `MK/Store/MKEntitlementResolver.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.67 | App update mid-project: additive JSON migrations w/ pre-migration rescue snapshot; failed migration = read-only + intact backup | `MK/Model/Schema/MKSceneMigrator.swift` | ✅ shipped | cross | 8.7 | ⬜ |
| R-21.68 | Device rotation/Stage Manager resize mid-gesture: gesture cancels cleanly, viewport re-fits, selection preserved | `MK/Canvas/Gestures/**` | ✅ shipped | cross | 8.7 | ⬜ |

---

## §22 Non-Functional Requirements (`PRD.md` §22) — 18 ids

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-22.1 | Manipulation frame time ≤8.3ms ProMotion, ≤16.6ms A12-class floor | `MK/Render/RenderSignposts.swift` | ✅ shipped | cross | 8.4 | ⬜ |
| R-22.2 | Typing echo <50ms (keystroke → overlay glyph visible) | `MK/Canvas/**` (IME overlay) | ✅ shipped | cross | 8.4 | ⬜ |
| R-22.3 | Project open: typical (≤100 nodes) <1s; heavy (5,000 nodes) <3s | `MK/Persistence/DocumentPackage.swift` | ✅ shipped | cross | 8.4 | ⬜ |
| R-22.4 | Incremental autosave <100ms, off main thread | `MK/Persistence/AutosaveController.swift` | ✅ shipped | cross | 8.4 | ⬜ |
| R-22.5 | 4K PNG export <10s on A15-class hardware | `MK/Export/TiledRasterExporter.swift` | ✅ shipped | cross | 8.4 | ⬜ |
| R-22.6 | Peak editor memory <60% of `os_proc_available_memory` before degradation ladder begins | `MK/Render/MemoryPressureMonitor.swift` | ✅ shipped | cross | 8.4 | ⬜ |
| R-22.7 | Budgets are quantitative gates for all iOS 18 devices (build/profiling/StoreKit-sandbox/manual-Arabic-checklist) | doc + process | ✅ shipped | cross | 8.4 | ⬜ |
| R-22.8 | Zero-data-loss guarantee: crash/kill loses at most last un-journaled batch (≤2s) | `MK/Persistence/CommandJournal.swift`, `CrashRecovery.swift` | ✅ shipped | `:mk-persistence` | 3.4 | ⬜ |
| R-22.9 | Determinism: identical scene snapshot → identical export bytes; canvas preview and export pixel-identical | `MK/Render/SceneRenderer.swift` (single-render-path) | ✅ shipped | cross | 8.3 | ⬜ |
| R-22.10 | Degradation is always soft/reversible (preview fidelity, virtualization), never feature caps | `MK/Render/DegradationController.swift` | ✅ shipped | cross | 8.4 | ⬜ |
| R-22.11 | SwiftUI-first; UIKit/Core Text/TextKit2/CG permitted; Metal is extension-seam only; arrange sits atop Apple shaping, never a shaper | architecture policy (D-103/D-114) | ✅ shipped | multiple (scaffold) | 1.1 | ⬜ |
| R-22.12 | Toolchain: Xcode/xcodebuild/gh only, no XcodeGen/Tuist/Fastlane/external CI, no third-party runtime deps | build config | ✅ shipped | multiple (scaffold) | 1.1 | ⬜ |
| R-22.13 | Swift 6 strict concurrency: `@MainActor` UI/document, `Sendable` services, renderer consumes immutable snapshots | architecture policy (D-102) | ✅ shipped | multiple (scaffold) | 1.1 | ⬜ |
| R-22.14 | Persistence per D-112: file packages + JSON scene + SwiftData metadata index, the decisive recommendation | `MK/Persistence/DocumentPackage.swift` | ✅ shipped | `:mk-persistence` | 3.4 | ⬜ |
| R-22.15 | Codebase-memory conventions: durable ADRs, implementation logs, verification evidence per phase | doc process | ✅ shipped | multiple (scaffold) | 1.1 | ⬜ |
| R-22.16 | Distribution automation: App Store prep/submission automated where technically possible, pauses only for founder items | doc process | ✅ shipped | n/a | 9.4 | ⬜ |
| R-22.17 | Security: no dynamic code/remote-config execution, downloaded fonts sfnt-validated, all network TLS, no client secrets | `MK/Fonts/MKFontValidator.swift` | ✅ shipped | multiple (scaffold) | 1.1 | ⬜ |
| R-22.18 | Cold launch to interactive project browser <1s on A15-class devices (D-115 as amended by D-218) | `Makhtoot/App/MakhtootApp.swift` | ✅ shipped | cross | 8.4 | ⬜ |

---

## §23 Out of Scope / v2 Seams (`PRD.md` §23) — 7 ids

Every id here is explicitly NOT built in v1 on iOS; spine §14 carries the same exclusions
forward to Android v1 by the same logic (these are not new cuts, they mirror iOS's own v1
scope). "Android status" tracks that the seam is honored (not built), not that the seam
feature is built.

| R-id | Summary | iOS file(s) | iOS status | Android module | batch.agent | Android |
|---|---|---|---|---|---|---|
| R-23.1 | Animation/video/reels export: stable UUIDs + value-type snapshots ready for future keyframing; no timeline/encoder in v1 | `MK/Render/SnapshotRenderer.swift` (snapshot API seam) | ✅ shipped (seam only, as intended) | `:mk-render` | 4.5 | ⬜ |
| R-23.2 | Templates: document model can serialize a scene as a starting point (duplicate already does this); no template gallery | `MK/Model/Schema/SceneCodec.swift` | ✅ shipped (seam only, as intended) | `:mk-model` | 2.2 | ⬜ |
| R-23.3 | Multi-page projects: `manifest.json` reserves `pages` array (length 1 in v1); no multi-page UI | `MK/Persistence/DocumentPackage.swift` | ✅ shipped (seam only, as intended) | `:mk-persistence` | 3.4 | ⬜ |
| R-23.4 | App Store Server API entitlement validation: `MKStore` isolates verification behind a protocol; v1 is on-device JWS only | `MK/Store/Verification.swift` | ✅ shipped (seam only, as intended) | `:mk-store` | 6.1 | ⬜ |
| R-23.5 | Commercial foundry pipeline: catalog schema fields exist from v1; acquisition/licensing is FD-07, post-v1 | `MK/Fonts/MKFontTypes.swift` | ✅ shipped (seam only, as intended) | `:mk-fonts` | 6.5 | ⬜ |
| R-23.6 | Sacred-text assets (Qur'anic content, Uthmani fonts/text): nothing ships in v1; any future asset needs founder approval | absence of feature | ✅ shipped (intentional absence) | n/a | 8.7 | ⬜ |
| R-23.7 | Also explicitly out: accessibility scope, Metal, custom kashida justification, rich mixed-style runs, image filters, asset packs, nested folders, trash/undo-delete, deep links/widgets/App Intents, offer codes UI, collaborative editing, Family Sharing execution | absence of features (cross-cutting) | ✅ shipped (intentional absence) | `:app` | 8.5 | ⬜ |

