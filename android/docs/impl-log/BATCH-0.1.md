# Batch 0 · Agent 0.1 — Impl log

## What was produced

`android/PARITY_MATRIX.md` — one row per requirement, columns: id, one-line paraphrased
summary, iOS implementing file(s), iOS status, Android target module, target batch.agent,
Android status (`⬜` for all 318 rows at G0).

## Row count: 318, not 319 — a spine-fact correction

This packet's own Task 1 instructs running `grep -oE 'R-[0-9]+\.[0-9]+' PRD.md | sort -u | wc -l`
to confirm 319 before writing anything, "if it is not, note the actual count … and use the real
count." That exact command **does** print 319, but it counts the wrong 319 things, via two
errors that cancel numerically:

1. **Undercounts real ids by 1.** The pattern has no letter-suffix group, so `R-21.35a` — an
   independently `**R-21.35a (P0)**`-defined requirement ("Neutral-punctuation freeze at
   capture," INV-1/D-109), textually and substantively distinct from `R-21.35` ("Arrange during
   active text editing") — collapses into the same string as `R-21.35` and is invisible to the
   count.
2. **Overcounts by 2.** `R-14.20` and `R-21.72` match the pattern but are **never defined
   anywhere in `PRD.md`** with a `**R-x.y (P#)**` bold definition. Verified:
   `grep -n '\*\*R-14\.20\|\*\*R-21\.72' PRD.md` returns nothing. Both are dangling prose
   cross-references — `R-2.8`'s text ends "…see R-14.20"; `R-15.12`'s text ends "…(R-21.72)".
   The nearest real requirements covering the same ground already have their own rows:
   `R-14.11` (Guideline 3.1.2 compliance — almost certainly what R-2.8 meant to cite) and
   `R-21.55` (mid-export entitlement re-evaluation at render request — exactly what R-15.12's
   sentence describes).

The letter-suffix-aware, definition-site-only count is
`grep -oE '\*\*R-[0-9]+\.[0-9]+[a-z]? \(P' PRD.md | sed -E 's/^\*\*(R-[0-9]+\.[0-9]+[a-z]?) \(P/\1/' | sort -u | wc -l`
→ **318**. 318 − 1 (R-21.35a hidden) + 2 (phantom ids) = 319 (naive count) — the two errors
happen to net to exactly the spine's stated value, which is why this is easy to miss on a first
pass; I only caught it because the run was interrupted mid-task and the coordinator's resume
message explicitly asked me to re-derive the count rather than trust either number.

**Resolution applied:** `android/PARITY_MATRIX.md` has 318 rows — one per real, independently
bold-defined requirement. R-21.35 and R-21.35a are both present as separate rows (they are two
different requirements). No row is fabricated for R-14.20 or R-21.72 (they are not
requirements). Verified zero-diff both directions: `comm -23`/`comm -13` between the PRD-derived
318-id list and the matrix's row-id list both return empty, and there are no duplicate ids in
the matrix (`sort | uniq -d` empty).

**This is a spine-fact discrepancy, not a packet-following error.** `ANDROID_SPINE.md` §0's
table states "PRD requirement ids (`R-<section>.<n>`) | 319" and §6's G0/G8 language says
"318/318" — sorry, says "319/319". Per spine §4 ground rule 5 / this packet's ownership scope, I
am not authorized to edit `ANDROID_SPINE.md` (owned by Agent 0.5's decision-doc scope, not
0.1's), so the correction is recorded here and prominently at the top of
`android/PARITY_MATRIX.md` instead. Every later reference to "319 R-ids" in any packet or gate
script should be read as 318 until the spine itself is corrected in a future pass. I flag this
explicitly for the coordinator/founder rather than silently patching the spine or silently
adjusting my own count to match a wrong expectation, per this packet's own instruction not to
fabricate rows to hit a target number.

## Previously-unassigned ids

Per spine §5.3, "102 [ids] were previously cited by no packet at all" before this agent's pass.
This matrix is the first artifact to assign every PRD requirement id an owning batch.agent, so
by construction all 318 rows now have one — I did not attempt to separately identify which 102
of the (spine's stated) 319 were the previously-uncovered subset, since no prior parity matrix
existed on disk to diff against (this is Batch 0, the first batch; `android/` did not contain
`PARITY_MATRIX.md` before work item 0.1). The "102 previously unassigned" figure is the
spine's own claim about the state of the plan before work item 0.1, not something this
agent needed to reproduce or verify independently — the deliverable this agent owns is that the
gap is now fully closed (0 blank cells), which is verified below.

## Methodology for target batch.agent assignment

Rather than infer agent scope from Swift/Kotlin file names alone, I read the actual **Mission**
paragraph of all 66 agents across `ANDROID_TASK_PACKETS/BATCH-1.md` through `BATCH-9.md` (the
packet files were already available in this run) before
assigning any row, per the coordinator's explicit instruction to ground assignments in agents
that "actually have the relevant module in scope, not a plausible-looking guess." This caught
several corrections to an initial file-name-based heuristic, e.g.:

- `3.5` is `mk-persistence` **undo** (not metadata) and `3.6` is `mk-persistence` **Room
  metadata index** (not undo) — the reverse of a plausible-sounding first guess from module
  file ordering.
- `5.3` (`mk-canvas` selection/hit-test/layers/inspector/**keys**) owns the canvas-side
  selection/lock-hide/nudge/copy-paste/grouping *mechanics* (R-4.6, R-4.9–R-4.12, R-4.14),
  distinct from `7.6` which ports the actual `LayersPanelView.kt`/`InspectorPanelView.kt`
  Compose *screens* (R-10.1–R-10.9) — both are real, non-overlapping agents; a naive "layers →
  one agent" guess would have merged them incorrectly.
- `6.3a` (Drive transport/auth/chunking) vs `6.3b` (conflict policy, record coder, **status
  publisher**, **account-state handling**, **pending queue**) — R-17.5/17.6/17.7 look like
  "sync status/account/offline" at a glance but their Kotlin owner is explicitly 6.3b per its
  own mission text ("per-project status publisher," "account-state handling," "offline pending
  queue"), not 6.3a.
- `5.6` (`mk-export` raster/SVG/**gate**/free-tier budget) explicitly "carries forward AUDIT
  finding FC-2 as a hard, explicit requirement" — this is the correct Android owner for every
  PRD row touching `MKExportGate`/`MKFreeTierBudget` (R-13.2/13.3, R-14.4/14.9/14.17), not
  `6.1` (store/entitlement) as an initial guess would place them, since spine §3.2 explicitly
  records there is **no** `:mk-export → :mk-store` dependency edge.
- `5.5b` owns `MkPremiumContentLedger` by name in its mission — R-14.5 (`premiumContentPresent`
  flag) belongs there, not at `6.1`.
- `7.7` ("Font browser, font settings, asset browser sheets") is the correct owner for PRD
  §12.2's catalog-browsing UX rows (R-12.5, R-12.7 cross-ref), distinct from `6.5`'s
  manifest/download/lock engine.

Where no agent's mission names a clean owner (SVG/PDF import parsing, R-11.8/R-11.9/R-21.61 —
no agent packet mentions an SVG-import interpreter by name anywhere in Batches 1–9), I assigned
the closest plausible owner (`7.6`, the general import-sheet agent) and recorded the judgment
call in the row itself rather than leaving the cell blank, per this packet's Task 2 instruction.

## Row-completeness verification (this agent's core deliverable per its Mission)

- `grep -c '^| R-' android/PARITY_MATRIX.md` (excluding the 31 table-header rows: 22
  section-level + 9 §21 subsection-level) = 318 data rows.
- 318 unique ids, zero duplicates (`sort | uniq -d` empty).
- Zero rows with a blank Android-target-module or blank target-batch.agent cell (`awk` scan
  over column 6/7 of every data row).
- Every one of the seven letter-suffixed split agents used in this matrix appears **only** with
  its letter suffix (`3.1a`/`3.1b`, `5.2a`/`5.2b`, `5.4a`/`5.4b`, `5.5a`/`5.5b`, `6.3a`/`6.3b`,
  `7.3a`/`7.3b` — `5.7a` was not needed by any row, `5.7b` was); grepped for bare `3.1`, `5.2`,
  `5.4`, `5.5`, `5.7`, `6.3`, `7.3` in the batch.agent column — zero hits.
- Final tallies (in the matrix header): iOS status 298 `✅ shipped` / 14 `⚠️ shipped with known
  gap` / 6 `⚠️→✅` (fixed-with-corrected-citation) / 0 `❌ missing`, summing to 318. Target-batch
  rollup: 1→6, 2→4, 3→34, 4→40, 5→46, 6→48, 7→55, 8→82 (61 of which are the §21 edge-case sweep
  assigned to Agent 8.7, whose own mission is literally "Edge-case compendium sweep (PRD §21)"),
  9→3, summing to 318.

## PRD requirements I could not cleanly map to one agent

None left unassigned (0 blank cells, verified above). Requirements where the "closest owning
agent" call was genuinely ambiguous, with the judgment recorded in the row itself rather than
silently:

- R-11.8, R-11.9, R-21.61 (SVG/PDF import parsing) — no agent packet names an SVG-import
  interpreter anywhere in Batches 1–9; assigned to 7.6 as the closest general import-surface
  owner.
- R-1.4, R-19.1, R-19.2, most of §21 (61 ids) — assigned to Batch 8 · Agent 8.7 as the
  explicitly-named cross-cutting closer/edge-case-sweep agent rather than split across each
  requirement's originating engine module, since 8.7's own mission is to close out this exact
  ledger for PRD §21 specifically.
- R-9.9 (path ghost guide) and R-8.3/R-8.5 (form selector) assigned to `7.5` (the arrange/path
  toolbar UI agent) rather than the underlying engine agents (4.2/4.3), because 7.5's mission
  names these exact Compose files (`ghost guide overlay`, would-be `MkFormSelectorPopover`) by
  title.

## FC-1/FC-2 cross-reference (Task 3) — and a correction to this packet's own citation

Per Task 3, I verified FC-1 (bold/italic wiring) and FC-2 (export-gate bypass) against the
shipped Swift source rather than trusting the audit doc's claim, per spine §0's "source of truth
is shipped code" rule:

- `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift` line 224 now takes
  `fontProvider: any MKFontProviding` in its initializer and threads it through the render/export
  call sites the audit named as broken (`renderThumbnailPNG`, etc.) — FC-1 confirmed fixed.
- `EditorViewModel.swift` lines 908/952 (`exportForSharing`/`exportPNGForSharing`) now take an
  `entitlement: any MKEntitlementProviding` parameter and construct `MKExportCoordinator` with
  it — FC-2 confirmed fixed.

**This packet's own text says both were fixed "per `EXECUTION_PLAN_2026-07-28.md` Wave 1 ·
Agent 1.1 (commit `ec9887c`)." That commit hash is wrong.** `git log` shows `ec9887c` is an
**earlier, unrelated** commit — "Close all open MASTER-PLAN items; ship build 20260728.1" —
that predates the `AUDIT_2026-07-28.md`-driven Wave 0–4 sequence entirely (it touches
`SVGTextWriter.swift`/`SVGSerializer.swift`/`MKFontRegistrar.swift` for a *different*,
already-closed plan, and does not touch `EditorViewModel.swift` at all — verified via
`git log --oneline -- Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`). The actual Wave 1
commit is **`d885fe2`** — "Wave 1: fix bold/italic wiring + export gate bypass (FC-1/FC-2/P-4),
persistence hardening (P-6/P-7/S-2/S-6/S-7), entitlement cache TTL (S-1), sync/import leaks
(S-3/S-4), haptics + export temp cleanup (UX-4/S-5)" — which matches both the packet's own
description of what Wave 1 fixed and the actual diff. Every row in `PARITY_MATRIX.md` that cites
the FC-1/FC-2 fix cites `d885fe2` and notes that this packet's `ec9887c` citation is wrong,
rather than silently repeating the packet's error or silently correcting it without a trace.

Rows carrying the FC-1 note: R-5.9. Rows carrying the FC-2 note: R-1.15, R-13.2, R-13.3, R-14.4,
R-14.17.

## iOS status beyond FC-1/FC-2 — scope boundary, stated explicitly

Task 2 asks for an accurate iOS status per row generally, not only for FC-1/FC-2. I annotated
`⚠️ shipped with known gap` on rows where I had already gathered concrete evidence while doing
the required reading (`AUDIT_2026-07-28.md` full read of §5 Feature Completeness, plus targeted
reads of §1 Performance's opening findings and the Wave 0–4 commit messages, plus the founder's
own 2026-07-30 program-state memory noting P-8/ArcLengthLUT as still-open items). This produced
14 `⚠️ shipped with known gap` rows: R-1.7, R-1.13, R-1.14, R-2.4, R-2.9, R-4.11, R-9.2, R-11.6,
R-12.2, R-13.6, R-13.7, R-14.5, R-16.3, R-21.64. (R-1.16 is a related but separate case: it is
marked `✅ shipped as intentional absence` rather than `⚠️`, because the underlying PRD
requirement is "build no accessibility scope" — the AUDIT UX-1 finding that VoiceOver is indeed
absent confirms the non-goal was honored, not that something is broken; that row's own note
flags the nuance without counting it as a gap.) **This is not
an exhaustive re-audit of all ~90 `AUDIT_2026-07-28.md` findings against all 318 requirements**
— that scope was not requested by this packet and is not attempted here. Every `⚠️` row names
its source finding (audit id or founder-memory note) so a later batch can verify further rather
than trust this matrix's characterization blindly.

## Deviations from a literal reading of the packet

- File-location granularity: assigned at module/subsystem level (e.g. "`MK/Arrange/**`
  (editing operations)"), not independently re-verified per-row against exact line ranges — see
  the Legend in `PARITY_MATRIX.md` for the explicit statement of this judgment call, made once
  at the top rather than repeated 318 times.
- Built the matrix incrementally (header + one PRD section per edit, 26 separate edits total)
  rather than as a single large write, per the coordinator's explicit instruction after an
  infrastructure failure truncated an earlier attempt at a single-shot write.

## Blockers

None. `android/`, `android/docs/`, `android/fixtures/`, `android/strings/`, and
`android/API_SURFACE.md` were already on disk when work item 0.1 began.
This work item had no dependency on those paths and left them untouched.

## Files touched

- `android/PARITY_MATRIX.md` (new, 318 data rows across 23 PRD sections)
- `android/docs/impl-log/BATCH-0.1.md` (this file)

No file outside this agent's exclusive ownership was created or modified. `git status` confirms
no Swift source file was touched.
