# Makhtoot Android Port — BATCH-8.md

## Batch 8 · Wiring, Parity, Hardening (7 agents)

**Depends on:** G7 (app runs end-to-end on emulator + a physical device; every screen
reachable; zero `Placeholder` composables). **Gate:** G8 — `bash Scripts/android/gate.sh 8`.

By G7 every feature exists somewhere in the tree. Batch 8 is what turns "all the code
exists" into "all the features actually work, end to end, on real hardware, with nothing
silently mis-shaping Arabic." G8 is the single hard measurable gate of the whole port:
**stub count = 0**, `Scripts/android/check-no-stubs.sh` clean, all 319 `R-…` ids ✅ in
`android/PARITY_MATRIX.md`, D-115 performance budgets met on named hardware, and a clean
TalkBack sweep. Every agent below is audit-and-fix, not new-feature work — if an agent
finds a genuinely missing implementation (not just an unwired one), it is escalated by
name in that agent's report, never silently built out of scope or silently skipped.

Per spine §4 ground rule 9, no Batch 8 agent touches anything outside `android/` or
`Scripts/android/` (the two path prefixes spine's own gate definitions already write
into). No Batch 8 agent touches iOS/`MakhtootKit`/`Makhtoot` sources — every comparison
against the iOS engine is read-only, against already-exported `android/fixtures/**`
goldens (D-324) or direct Swift-source reading for oracle behavior, never a live edit.

The plan's register is **66 agents** across 10 batches (spine §5): 0:5 · 1:4 · 2:5 · 3:8 ·
4:6 · 5:11 · 6:6 · 7:9 · **8:7** · 9:5, with seven letter-suffixed splits elsewhere in the
plan (3.1a/b, 5.2a/b, 5.4a/b, 5.5a/b, 5.7a/b, 6.3a/b, 7.3a/b) — none of Batch 8's own 7
agents are split. Where this batch reads or cites a component from an earlier work item with a letter suffix, it cites the specific letter (e.g. the
in-house PDF writer is 5.7a core
writer/5.7b subsetting-CMYK-ICC; the sync engine is 6.3a transport/6.3b policy; the IME
text-editing overlay is 5.4a; the shaping bridge is 3.1a and line breaking is 3.1b) rather
than the pre-split parent number.

### At-a-glance

| Agent | Title | Primary deliverable |
|---|---|---|
| 8.1 | Composition-root wiring audit and stub burn-down | `android/docs/WIRING_AUDIT.md`, stub count → 0 |
| 8.2 | Shaping parity run vs golden fixtures + `SHAPING_DELTAS.md` | `android/SHAPING_DELTAS.md`, per-family pass table |
| 8.3 | Render and export parity (pixel and byte goldens) | Pixel/byte/structural parity report |
| 8.4 | Performance: Android D-115 budgets, frame timing, memory ladder | `android/docs/PERF_REPORT.md` |
| 8.5 | Accessibility, font scale, RTL sweep | `android/docs/A11Y_REPORT.md` |
| 8.6 | Instrumented UI tests (port the 7 iOS UI tests and extend) | `androidTest` suite, 14 tests |
| 8.7 | Edge-case compendium sweep (PRD §21) | `android/PARITY_MATRIX.md` closed for all 319 `R-…` ids |

### Android-specific test IDs introduced in this batch

One numbered block, `T-AND-8<agent><seq>`, so the range is collision-free against every
other batch's own `T-AND-<n>` block.

| ID | Owner | What it proves |
|---|---|---|
| T-AND-8101 | 8.1 | `Scripts/android/stub-count.sh` reports 0 and matches `WIRING_AUDIT.md`'s published count |
| T-AND-8102 | 8.1 | Composition-root live-render assertion (Android analogue of `CompositionRootWiringTests.swift`): toggling Bold on a committed text node changes rendered pixels — proves the real font provider reached the renderer, not a default-constructed stub |
| T-AND-8201 | 8.2 | Full 45-family golden corpus run: joining forms, ligatures, marks — pass rate and mismatch count |
| T-AND-8202 | 8.2 | D-222 arrange-fidelity block (derive → decompose/recompose → revert round-trip) per family, gating ship/hold |
| T-AND-8203 | 8.2 | Unregistered-delta gate check: every HarfBuzz↔Core Text mismatch not in `SHAPING_DELTAS.md` fails the run |
| T-AND-8301 | 8.3 | PNG/JPEG pixel-compare vs `android/fixtures/render/**` goldens, stated tolerance |
| T-AND-8302 | 8.3 | SVG byte-compare vs goldens |
| T-AND-8303 | 8.3 | PDF structural validation: object tree, embedded subset, `OutputIntent`, CMYK operators |
| T-AND-8304 | 8.3 (cites), founder (performs) | PDF external-viewer verification (Adobe Acrobat + one AOSP-lineage PDF viewer) — a founder G5 gate task per spine §6, not an agent-run test; 8.3 cites the founder's sign-off in `RENDER_EXPORT_PARITY.md` rather than performing the check itself |
| T-AND-8305 | 8.3 | Single-render-path invariant (INV-2/INV-6 Android analogue): canvas preview snapshot bytes and export bytes at the same scale match |
| T-AND-8401 | 8.4 | Manipulation frame time, `DEV-AND-PRO` (120 Hz), ≤8.3 ms P95 |
| T-AND-8402 | 8.4 | Manipulation frame time, `DEV-AND-MID` (2020-class floor), ≤16.6 ms P95 |
| T-AND-8403 | 8.4 | Typing echo <50 ms |
| T-AND-8404 | 8.4 | Open typical project (≤100 nodes) <1 s |
| T-AND-8405 | 8.4 | Open heavy project (5,000 nodes) <3 s |
| T-AND-8406 | 8.4 | Incremental autosave <100 ms, off the main thread |
| T-AND-8407 | 8.4 | 4K PNG export <10 s |
| T-AND-8408 | 8.4 | Cold launch to interactive browser <1 s |
| T-AND-8409 | 8.4 | Memory ladder stages 1/2/3 mapped to `onTrimMemory` levels, ordering proven (save-before-evict) |
| T-AND-8410 | 8.4 | Critical journal-only flush + relaunch recovery (no full re-encode under `TRIM_MEMORY_COMPLETE`) |
| T-AND-8501 | 8.5 | TalkBack sweep, every screen reachable and correctly labeled |
| T-AND-8502 | 8.5 | 48dp touch-target floor audit (D-319) |
| T-AND-8503 | 8.5 | `fontScale` 200% layout audit |
| T-AND-8504 | 8.5 | Reduce-motion (`TRANSITION_ANIMATION_SCALE` = 0) honored |
| T-AND-8505 | 8.5 | Contrast audit against the 5 `MkTheme` themes |
| T-AND-8506 | 8.5 | Canvas TalkBack exposure, scoped per the iOS UX-1 decision status (see 8.5 Tasks) |
| T-AND-8507 | 8.5 | `MkFloatingBar`'s flat-alpha-surface degradation (`Modifier.blur` no-op below API 31) visually checked on an API 30 emulator (FDA-07/D-305/Risk R9) |
| T-AND-8601…8607 | 8.6 | The 7 ported iOS UI tests (see 8.6 port map) |
| T-AND-8608 | 8.6 | Configuration change mid-edit (rotation) |
| T-AND-8609 | 8.6 | Process death mid-edit (system-initiated kill + restore) |
| T-AND-8610 | 8.6 | Split-screen (multi-window) |
| T-AND-8611 | 8.6 | Foldable fold/unfold mid-session |
| T-AND-8612 | 8.6 | Back-gesture handling (predictive back, no data loss mid-edit) |
| T-AND-8613 | 8.6 | IME rotation (switching Arabic keyboard layouts mid-composition) |
| T-AND-8614 | 8.6 | Low-memory kill during autosave |
| T-AND-8701 | 8.7 | Zip `.makhtoot` import: crafted path-traversal entry names rejected (D-309 security, Android side of R-21.61 family) |
| T-AND-8702 | 8.7 | SAF font import: duplicate/corrupt corpus (Android path of R-21.22/R-21.24) |
| T-AND-8703 | 8.7 | Drive `appDataFolder` quota-exceeded handling (Android path of R-21.49) |
| T-AND-8704 | 8.7 | Auto Backup disabled: trial reinstall does not restore the blocked days (Android path of R-21.52, D-312 weaker-than-Keychain risk) |
| T-AND-8705 | 8.7 | `onTrimMemory` critical mid-export: in-flight strip completes, next strip pauses (Android path of R-21.44/T-MEM-6) |

---

### Batch 8 · Agent 8.1 — Composition-root wiring audit and stub burn-down

**Depends on:** G7 · **Parallel-safe with:** every other Batch 8 agent

**Mission.** Sweep every module for remaining `MkNotYetPorted` throws and drive the count
to zero. Audit the `:app` composition root exactly the way `AUDIT_2026-07-28.md` audited
the iOS one: for every injected dependency, prove the real implementation is constructed
AND is the same instance every consumer actually receives — this is precisely the shape
of bug that shipped iOS FC-1 (bold/italic inert app-wide because `EditorViewModel` held
seven `SystemFontStubProvider()` literals instead of the container's real
`MKRegistryFontProvider`) and FC-2 (PNG/JPEG export bypassing the entitlement gate because
the export path built its own default-arg `MKExportCoordinator` instead of the wired one).
When this agent is done, `Scripts/android/stub-count.sh` reports 0 and
`Scripts/android/check-no-stubs.sh` exits clean.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `CLAUDE.md`, `FOUNDATION.md` §1–2 | module map, D-1xx conventions |
| `AUDIT_2026-07-28.md` FC-1 (~L41, L857), FC-2 (~L47, L923) | the exact wiring-bug shape and audit method to replicate |
| `Makhtoot/AppShell/AppContainer.swift` (298 LOC) | oracle composition root — what "every dependency wired to its real conformer" looks like when correct |
| `EXECUTION_PLAN_2026-07-28.md` Wave 1 · Agent 1.1 | the fix pattern (stored property instead of literal stub; explicit `fonts:`/`renderer:` args instead of trusting a coordinator's own defaults) |
| `Scripts/stub-source-audit.sh` (125 LOC) | Swift sibling this agent ports |
| `android/API_SURFACE.md`, `android/PARITY_MATRIX.md` (G0) | full symbol list and requirement coverage to cross-check against |
| `Scripts/android/stub-count.sh`, `Scripts/android/check-no-stubs.sh` (Batch 1 · Agent 1.1 ratchet scripts) | the counters this agent must drive to zero |

**Owns (creates or edits — no other agent may touch these).**
- `Scripts/android/stub-source-audit.sh` (new)
- `android/docs/WIRING_AUDIT.md` (new)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/composition/AppContainer.kt` — wiring fixes only (swap a stub construction for the real conformer at a construction or call site); never new feature code
- Any other `:app` or module call site where a `MkNotYetPorted`-backed stub is referenced in place of an already-implemented real conformer from an earlier batch — wiring fixes only, scoped identically
- `android/docs/impl-log/BATCH-8.1.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**` (iOS — this is not an iOS agent);
`android/SHAPING_DELTAS.md`, `android/docs/PERF_REPORT.md`, `android/docs/A11Y_REPORT.md`,
`android/PARITY_MATRIX.md` (owned by 8.2/8.4/8.5/8.7); any `androidTest` source (owned by
8.6); any construction fix that would require implementing a genuinely missing feature —
escalate instead.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `Makhtoot/AppShell/AppContainer.swift` | 298 | `appshell/composition/AppContainer.kt` (already ported at Batch 7.1) | Oracle for "real conformer, one instance, every consumer" — audited here, not re-ported |
| `Scripts/stub-source-audit.sh` | 125 | `Scripts/android/stub-source-audit.sh` | Generalizes the `AlwaysPremium*`/`AlwaysFree*` declaration-gate + no-live-reference pattern from two named Swift stub families to any Kotlin type backed by `MkNotYetPorted` or a documented debug-only fake, matching D-301's 18-module map |

**Tasks.**
1. Run `Scripts/android/stub-count.sh` for the starting count; classify every remaining
   `MkNotYetPorted` as (a) a wiring bug — the real implementation exists somewhere in the
   tree but a construction or call site still passes/constructs the stub, or (b) a genuine
   gap — no real implementation exists yet.
2. For every injected dependency in `AppContainer.kt` (font provider, entitlement
   provider, asset provider, persistence/project-library, renderer, sync engine [Agent 6.3a
   Drive transport / 6.3b policy port], store/billing resolver, analytics uploader — the
   full set `AppContainer.swift` itself enumerates), write one `WIRING_AUDIT.md` row:
   construction site, every consumption call site (grep-verified, not eyeballed), PASS/FAIL.
   Specifically hunt for the FC-1/FC-2 shape: a coordinator or view model with its OWN
   default parameter that silently re-defaults to a stub even when the caller passes the
   real one elsewhere — the FC-1 bug itself lived in iOS `EditorViewModel`, so its direct
   Android analogue, Agent 7.3a's `MkEditorViewModel.kt`, is a required stop on this audit,
   not merely `AppContainer.kt` itself.
3. Port `Scripts/stub-source-audit.sh` to `Scripts/android/stub-source-audit.sh`: grep for
   stub/fake DI conformers declared under the Batch 1 debug-only naming convention, assert
   each is gated out of the release source set and has no live (non-test) reference outside
   its own declaration file.
4. Fix every category-(a) wiring bug directly (scoped construction/call-site edits only).
5. Escalate every category-(b) gap as a named, numbered item at the end of
   `WIRING_AUDIT.md` — G8 cannot pass with any open item here.
6. Re-run `Scripts/android/stub-count.sh` until it reports 0; run
   `Scripts/android/check-no-stubs.sh` and confirm a clean exit.

**Acceptance.**
- `./gradlew :app:testDebugUnitTest :app:lintDebug` green
- Requirements covered: `R-22.11`, `R-22.17` (real implementations only, no dynamic code)
- Tests: `T-AND-8101`, `T-AND-8102`
- `Scripts/android/stub-count.sh` reports 0 and `Scripts/android/check-no-stubs.sh` exits clean —
  this is the entire acceptance bar for the stub count. There is no alternative reading under
  which a nonzero count with every remainder named and escalated in `WIRING_AUDIT.md` also
  passes: spine §4 ground rule 4 deletes that clause outright, with no exception and no
  escalation path. Escalating a category-(b) gap in `WIRING_AUDIT.md` (Task 5) documents the
  finding; it does not substitute for driving the count to 0.

**Impl log.** `android/docs/impl-log/BATCH-8.1.md`

---

### Batch 8 · Agent 8.2 — Shaping parity run vs golden fixtures + `SHAPING_DELTAS.md`

**Depends on:** G7 · **Parallel-safe with:** every other Batch 8 agent

**Mission.** Run the full Batch-0 golden corpus — 45 bundled families × the canonical
Arabic fixtures × joining forms × ligatures × marks — against the Kotlin/HarfBuzz engine.
Every mismatch is either fixed or classified and registered in `android/SHAPING_DELTAS.md`
with font, input, expected, actual, reason and **class (A/B/C, spine §12)** per D-325; an
unregistered delta fails the gate, and a Class-B delta fails the gate even if registered —
classification is not self-service (spine §12): this agent may register a Class-A delta
directly, but a Class-B delta (any dropped/added/reordered mark, changed glyph id, broken
or differently-composed ligature, changed joining form, or tashkeel loss) can never be
registered away, and a Class-C delta requires founder sign-off per row, not this agent's own
say-so. Apply the D-222 per-font fidelity rule: a family ships only after it passes the
arrange-fidelity block, not just the reduced sweep. Also re-run the evidence assertions in
`MakhtootKit/Tests/WS16CursiveTests/` (owned by work item 3.3) for the five held fonts as
part of this parity pass — that suite is the cursive-attachment fidelity evidence the Arrange
invariant depends on. Deliver a per-family pass table.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `android/fixtures/**` (Batch 0.2 export) | the byte-identical golden corpus — the acceptance oracle (D-324) |
| `PRD.md` §7 (Tashkeel & Marks), §8 (Ligatures & Joining) | behavioral spec being verified |
| `DECISIONS_LOG.md` D-222 (~L899), D-325 | the per-font fidelity gate and the shaping-delta register mechanism this agent enforces, verbatim |
| `ANDROID_SPINE.md` §12 | the A/B/C delta classification and the triple-based G3 denominator this agent's pass table and `SHAPING_DELTAS.md` entries must use |
| `TEST_MATRIX.md` §7 (T-AR-1…63), esp. §7.9/§7.13 (T-ARR family) | the Arrange Mode preservation checks the fidelity block reuses |
| `FOUNDATION.md` §3 (D-103/D-105/D-107/D-108) | the invariants (ZWJ harvesting, ligature-cluster detection, GPOS mark offsets) HarfBuzz output must still satisfy |
| `mk-textengine/**` (Agent 3.1a HarfBuzz shaping bridge, Agent 3.1b line breaking/paragraph layout, Agent 3.2), `mk-arrange/**` sources (Batch 4) | the engine under test |
| `MakhtootKit/Tests/WS16CursiveTests/` (4 files, 450 LOC — from work item 3.3) | the cursive-attachment fidelity evidence suite for the five held fonts; this agent re-runs its assertions, it does not re-port them |

**Owns (creates or edits — no other agent may touch these).**
- `android/SHAPING_DELTAS.md` (new)
- `android/docs/SHAPING_PARITY_REPORT.md` (new — per-family pass table, by class per spine §12)
- `mk-textengine/src/test/kotlin/**/ShapingParityTest.kt`, `mk-arrange/src/test/kotlin/**/ArrangeFidelityBlockTest.kt` (new test files)
- Bug fixes inside `mk-textengine/src/main/kotlin/**`, `mk-arrange/src/main/kotlin/**` where the mismatch is a genuine Kotlin engine bug (not a legitimate HarfBuzz↔Core Text delta)
- `android/docs/impl-log/BATCH-8.2.md`
- Re-runs (does not own or edit) `MakhtootKit/Tests/WS16CursiveTests/` — a read/execute-only dependency owned by work item 3.3; a failure here is reported in `SHAPING_PARITY_REPORT.md`, never silently patched into that suite

**Never touch.** `MakhtootKit/**`, `Makhtoot/**`; `android/docs/WIRING_AUDIT.md`,
`android/docs/PERF_REPORT.md`, `android/docs/A11Y_REPORT.md`, `android/PARITY_MATRIX.md`;
any `mk-render`/`mk-export`/`mk-canvas` source (owned by 8.3/8.6).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `android/fixtures/**` (exported from `MakhtootKit/Tests/MKTextEngineTests/**` at Batch 0.2) | — | `mk-textengine/src/test/kotlin/**/ShapingParityTest.kt` | Golden corpus is the oracle, not the Swift test files themselves |
| `TEST_MATRIX.md` §7 (T-AR-1…63) | — | `T-AND-8201`…`8203` + reused `T-AR-*` ids | Automated golden-compare replaces manual visual judgment wherever the artifact is a glyph-id/cluster/GPOS-offset dump; genuinely visual calls (e.g. ink-trap rendering under Nastaliq) stay manual per D-324 |

**Tasks.**
1. Load `android/fixtures/**` and run every fixture through `mk-textengine` (HarfBuzz
   shaping) → `mk-arrange` (derivation) on the Kotlin/JNI stack; capture cluster maps,
   glyph ids, and GPOS `x_offset`/`y_offset`/`x_advance` per D-303.
2. Compare against the Core Text-derived goldens. For every mismatch: root-cause first
   (genuine HarfBuzz↔Core Text version/table-interpretation skew vs. an actual Kotlin
   engine bug). Fix real bugs; classify everything else per spine §12 and register in
   `android/SHAPING_DELTAS.md` (font, input, expected, actual, reason, class). **Class A**
   (sub-pixel positional ≤0.5 px or ≤1/64 em whichever is larger, line-break opportunity
   choice, advance rounding ≤1 unit at 1000 UPM) this agent registers directly. **Class B**
   (dropped/added/reordered mark, changed glyph id, broken/differently-composed ligature,
   changed joining form, tashkeel loss) is never registered — it is an immediate, unfixable-
   by-registration gate failure; if root-causing shows it is genuinely a Class-B shaper
   divergence and not a Kotlin bug, escalate it by name rather than writing it into the
   register. **Class C** (a legitimate font-behavior difference that is neither A nor B) is
   logged with a `pending founder sign-off` status; it does not count as resolved until
   signed off.
3. Apply D-222 per family: once a family's reduced sweep (`T-AR-58`-equivalent) passes,
   also run the arrange-fidelity block — derive → decompose/recompose (incl. lam-alif and
   الله) → revert round-trip (`T-AR-31/32/33/36…38`-equivalent) — before marking that
   family ✅. A family failing the block ships only with its delta registered, classified,
   and — if Class C — signed off, exactly as D-222 requires on iOS; a Class-B failure never
   ships regardless of the block result.
4. Watch specifically for R-8.13 (mark re-attachment across ligature decomposition),
   R-8.14 (word-ligature-font fallback), R-7.6 (stacked mark order), R-21.4/21.5/21.6/21.7/
   21.9/21.12 (shadda+kasra ordering, lam-alif joining, ZWJ preservation, marks-across-
   decomposition, word-ligature fallback, kashida) as the highest-risk fixture classes for
   a two-shaper-stack divergence (Risk R1/R2 in the spine's risk register) — these are
   exactly the invariants a Class-B delta would violate.
5. Re-run `MakhtootKit/Tests/WS16CursiveTests/`'s evidence assertions (4 files, 450 LOC,
   from work item 3.3) for the five held fonts against the Kotlin/HarfBuzz stack; any
   assertion failure is root-caused and classified exactly as step 2, and reported in
   `SHAPING_PARITY_REPORT.md` under its own row — this agent does not edit the test suite
   itself.
6. Produce the per-family pass table: 45 rows of family, reduced-sweep result,
   fidelity-block result, delta count **by class (A/B/C)**, ship/hold.

**Acceptance.**
- `./gradlew :mk-textengine:testDebugUnitTest :mk-arrange:testDebugUnitTest :mk-textengine:lintDebug :mk-arrange:lintDebug` green
- Requirements covered: `R-7.6`, `R-7.8`, `R-8.2`, `R-8.13`, `R-8.14`, `R-21.2`–`R-21.7`, `R-21.9`, `R-21.12`
- Tests: `T-AND-8201`, `T-AND-8202`, `T-AND-8203`; `T-AR-1`…`T-AR-63` (automated-equivalent where the artifact is a data dump, manual sign-off retained where genuinely visual); `WS16CursiveTests` re-run clean for the five held fonts
- Fixtures consumed: `android/fixtures/shaping/**` (all 45 families)
- Parity restated with spine §12's unit: measured per (font family × corpus string × glyph)
  triple. Passes iff **zero Class-B deltas**, **Class-A deltas ≤1% of triples**, and **every
  Class-C row is signed off** — not the unenforceable "≥99% of golden fixtures match"
  framing an earlier draft used, which named no unit

**Impl log.** `android/docs/impl-log/BATCH-8.2.md`

---

### Batch 8 · Agent 8.3 — Render and export parity (pixel and byte goldens)

**Depends on:** G7 · **Parallel-safe with:** every other Batch 8 agent

**Mission.** Pixel-compare rendered scenes against Batch-0 PNG goldens against the
per-channel/differing-pixel tolerance **defined and justified in
`android/docs/RENDER_TOLERANCE.md`** (created in Batch 4, `§6` G4/`§12`) — this agent
validates against that document's numbers, it does not restate or re-derive its own.
Byte-compare SVG output. Validate PDF structurally (object tree, embedded font subset,
`OutputIntent`, CMYK operators) rather than byte-for-byte. **Opening the exported PDF in
Adobe Acrobat and a second (AOSP-lineage) viewer is a founder gate task at G5, not an agent
task** (spine §6 G5, mirroring the same correction to the PDF external-viewer check there) —
this agent's own job on PDF is structural validation only; it cites the founder's G5 sign-off
rather than performing or re-performing the external-viewer check itself. Confirm the
single-render-path invariant (INV-2/INV-6): canvas preview and export come from the same
renderer.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `android/fixtures/render/**`, `android/fixtures/export/**` (Batch 0.2) | PNG/SVG/PDF goldens |
| `PRD.md` §13 (Export) | R-13.1…R-13.15 format matrix, SVG/PDF/CMYK requirements |
| `ARCHITECTURE.md` §16.3 (INV-2/INV-6, ~L2509) | the single-render-path invariant this agent proves on Android |
| `FOUNDATION.md` §5–6 (D-114, D-117, D-118) | renderer/color/export pipeline this port must match in behavior |
| spine §2 D-305, D-313, D-314, D-315 | the Android substitutions (Skia `RenderNode`, in-house PDF writer — Agent 5.7a core writer/5.7b subsetting-CMYK-ICC, lcms2) this agent is validating |
| `android/docs/RENDER_TOLERANCE.md` (Batch 4) | the concrete per-channel tolerance and max-differing-pixel-fraction this agent's pixel-compare cites, not restates (starting numbers ≤6/channel, ≤1.0% differing pixels, per spine §12 — validate/tighten only in that file, never here) |
| `TEST_MATRIX.md` §11 (T-EXP-1…16), §7.12 (export fidelity manual checklist) | the format-by-format acceptance criteria |
| `mk-render/**`, `mk-export/**` sources (Batch 4/5) | the renderer and export writer under test |

**Owns (creates or edits — no other agent may touch these).**
- `android/docs/RENDER_EXPORT_PARITY.md` (new — tolerance statement, per-format results)
- `mk-render/src/test/kotlin/**/RenderGoldenTest.kt`, `mk-export/src/test/kotlin/**/ExportGoldenTest.kt` (new)
- Bug fixes inside `mk-render/src/main/kotlin/**`, `mk-export/src/main/kotlin/**` where a mismatch is a genuine renderer/writer bug (not a legitimate Skia/Core Graphics antialiasing difference)
- `android/docs/impl-log/BATCH-8.3.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**`; `android/SHAPING_DELTAS.md`,
`android/docs/WIRING_AUDIT.md`, `android/docs/PERF_REPORT.md`, `android/docs/A11Y_REPORT.md`,
`android/PARITY_MATRIX.md`; `mk-textengine`/`mk-arrange` sources (owned by 8.2); `mk-canvas`
sources (owned by 8.6).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MakhtootKit/Sources/MKRender/SnapshotRenderer.swift` (97 LOC) | 97 | `mk-render/src/main/kotlin/**/SnapshotRenderer.kt` (ported at Batch 4.5/4.6) | Oracle for "canvas preview and export share one renderer" — INV-2/INV-6 audit target |
| `android/fixtures/render/**`, `android/fixtures/export/**` | — | `RenderGoldenTest.kt`, `ExportGoldenTest.kt` | PNG/SVG/PDF goldens exported once at Batch 0.2, regenerated byte-identically per G0 |

**Tasks.**
1. Pixel-compare: render every `android/fixtures/render/**` scene through the Skia
   `RenderNode`/`Picture` path (D-305) at the goldens' scale; diff against the PNG goldens
   using `android/docs/RENDER_TOLERANCE.md`'s per-channel tolerance and max-differing-pixel
   fraction — cite the document's numbers in `RENDER_EXPORT_PARITY.md`, do not assert or
   re-derive a different number here; antialiasing/hinting differences between Skia and
   Core Graphics are expected and acceptable within that stated band, a shape, position,
   color, or text-run difference outside it is not and must be fixed.
2. Byte-compare: diff every `android/fixtures/export/**/*.svg` against the Kotlin SVG
   serializer's output — this format has no legitimate rasterizer-driven divergence, so
   any diff is a bug.
3. Structurally validate every exported PDF: object tree, embedded font subset (`hb-subset`
   output per D-314), `OutputIntent` (D-315/FDA-03 lcms2 CMYK profile), and CMYK operators
   present and well-formed — never byte-for-byte (timestamps/object ordering legitimately
   differ). This agent's PDF acceptance bar stops at structural validation; opening the
   export in Adobe Acrobat and an AOSP-lineage viewer is the founder's own G5 gate check
   (spine §6), not something this headless agent performs or re-performs — cite that G5
   sign-off in `RENDER_EXPORT_PARITY.md` rather than logging a viewer verification this
   agent did not actually do.
4. Confirm the single-render-path invariant: assert (by construction, then by a runtime
   test) that both the canvas preview path and every export format funnel through the same
   `SnapshotRenderer`/render-node code with only format-specific context construction and
   encoding around it — no per-format drawing code, matching ARCHITECTURE.md §16.3.

**Acceptance.**
- `./gradlew :mk-render:testDebugUnitTest :mk-export:testDebugUnitTest :mk-render:lintDebug :mk-export:lintDebug` green
- Requirements covered: `R-13.1`, `R-13.6`–`R-13.10`, `R-13.14`, `R-21.44`, `R-21.61`
- Tests: `T-AND-8301`…`T-AND-8305`; `T-EXP-1`…`T-EXP-16`, `T-AR-51`…`T-AR-57`
- Fixtures consumed: `android/fixtures/render/**`, `android/fixtures/export/**`
- Pixel comparison passes against `android/docs/RENDER_TOLERANCE.md`'s tolerance (cited, not
  restated); zero unexplained SVG byte diffs; every exported PDF passes structural
  validation. `T-AND-8304` (external-viewer verification) is cited as the founder's G5
  sign-off, not this agent's own test run

**Impl log.** `android/docs/impl-log/BATCH-8.3.md`

---

### Batch 8 · Agent 8.4 — Performance: Android D-115 budgets, frame timing, memory ladder

**Depends on:** G7 · **Parallel-safe with:** every other Batch 8 agent

**Mission.** Translate D-115's budgets to Android and verify on real hardware:
manipulation frame time ≤8.3 ms on a 120 Hz device and ≤16.6 ms on a mid-range 2020-class
device (the A12-class equivalent), typing echo <50 ms, open a 100-node project <1 s and
the 5,000-node fixture <3 s, incremental autosave <100 ms off the main thread, 4K PNG
export <10 s, cold launch to interactive browser <1 s. Verify the D-116/D-223 memory
ladder against `onTrimMemory` levels including the critical journal-only flush and relaunch
recovery.

**Named test devices** (spine-required, engineering pick — not a policy fact, no
`VERIFY-AT-SUBMISSION` needed):
- **`DEV-AND-PRO`** — Google Pixel 8 Pro (Tensor G3, 120 Hz LTPO OLED, 2023). High-refresh
  reference; Android's own Macrobenchmark/Perfetto tooling is validated first on Pixel
  hardware, mirroring `DEV-M`'s ProMotion role in TEST_MATRIX §2.
- **`DEV-AND-MID`** — Samsung Galaxy A51 (Exynos 9611, 60 Hz, 2020). The mid-range
  2020-class floor device — the direct era-match to `DEV-A12` (iPhone XS/A12, also a
  2018-class device still in the iOS 18/oldest-supported bracket); ships Android 10,
  which is exactly minSdk 29 (FDA-07) — this device is the floor the port must hit budget
  on, not a device above the floor.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `FOUNDATION.md` §5 (D-115 budgets, D-116 memory ladder, ~L159–180) | the exact numbers this agent verifies |
| `PRD.md` §22.1 (R-22.1…R-22.7, R-22.18) | the same budgets as testable requirements |
| `TEST_MATRIX.md` §2 (device matrix), §15 (T-PRF-1…14), §16 (T-MEM-1…6) | iOS budget/test structure this agent's Android sibling mirrors line-for-line |
| `DECISIONS_LOG.md` D-223 (~L911) | critical-path autosave is journal-only — the exact ordering invariant to verify under `onTrimMemory` |
| `android/fixtures/FIX-TYPICAL`, `FIX-HEAVY`, `FIX-4K` (Batch 0.2 analogues) | the standard perf fixtures |
| `mk-canvas/**`, `mk-render/**`, `mk-persistence/**` sources | the systems under measurement |

**Owns (creates or edits — no other agent may touch these).**
- `android/docs/PERF_REPORT.md` (new)
- `mk-canvas/src/androidTest/kotlin/**/FrameTimingBenchmark.kt`, `mk-persistence/src/androidTest/kotlin/**/AutosaveBenchmark.kt`, `mk-export/src/androidTest/kotlin/**/ExportBenchmark.kt`, `:app/src/androidTest/kotlin/**/LaunchBenchmark.kt` (new Macrobenchmark modules)
- `mk-foundation/src/main/kotlin/**/MkMemoryPressureMonitor.kt` — `onTrimMemory` level mapping fixes only, if the D-116 ladder ordering (save-before-evict) is found unwired
- `android/docs/impl-log/BATCH-8.4.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**`; `android/SHAPING_DELTAS.md`,
`android/docs/WIRING_AUDIT.md`, `android/docs/A11Y_REPORT.md`, `android/PARITY_MATRIX.md`;
`mk-canvas`/`mk-render` production sources beyond the named memory-ladder fix (owned by
8.3/8.6 for their own concerns).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `TEST_MATRIX.md` §15 (T-PRF-1…14) | — | `T-AND-8401`…`8408` (Macrobenchmark + JankStats) | `os_signpost`/`XCTOSSignpostMetric` → Perfetto trace sections with the same interval names (`frame.manipulate`, `typing.echo`, `doc.open`, `autosave.incremental`, `export.render`) so cross-platform perf comparisons stay legible |
| `TEST_MATRIX.md` §16 (T-MEM-1…6) | — | `T-AND-8409`, `T-AND-8410` | `DispatchSource` memory-pressure stages → `ComponentCallbacks2.onTrimMemory` levels (`TRIM_MEMORY_RUNNING_LOW`≈stage 1, `TRIM_MEMORY_RUNNING_CRITICAL`/`UI_HIDDEN`≈stage 2, `TRIM_MEMORY_COMPLETE`≈stage 3/critical) |

**Tasks.**
1. Instrument the four required Perfetto trace sections (`frame.manipulate`,
   `typing.echo`, `doc.open`, `autosave.incremental`, `export.render`) mirroring
   TEST_MATRIX §1.5's `os_signpost` registry by name.
2. Macrobenchmark: manipulation frame time on `DEV-AND-PRO` (120 Hz, ≤8.3 ms P95) and
   `DEV-AND-MID` (60 Hz floor, ≤16.6 ms P95) using `FIX-TYPICAL`; typing echo <50 ms on
   both devices; open `FIX-TYPICAL` <1 s and `FIX-HEAVY` <3 s; incremental autosave <100 ms
   with zero main-thread I/O frames (JankStats cross-check); 4K PNG export of `FIX-4K` <10 s;
   cold launch to interactive browser <1 s (baseline-profile-assisted, per 9.2).
3. Map D-116's three stages onto `onTrimMemory` levels; instrument the ordering assertion
   D-223 requires — full autosave completes BEFORE offscreen-cache eviction at stage 1/2,
   and at the critical stage (`TRIM_MEMORY_COMPLETE`) exactly one journal-only append flush
   occurs with NO scene re-encode and no allocation above a documented ceiling.
4. Kill-and-relaunch test: force a process death at the critical stage; relaunch; confirm
   recovery restores to the last journaled batch, matching `T-MEM-4`'s ≤2 s-at-risk bound.
5. Write `android/docs/PERF_REPORT.md`: one section per D-115 budget, device, measured
   value (median + P95, ≥5 runs), pass/fail against the stated number.

**Acceptance.**
- `./gradlew :mk-canvas:connectedDebugAndroidTest :mk-persistence:connectedDebugAndroidTest :mk-export:connectedDebugAndroidTest :app:connectedDebugAndroidTest` green on both named devices
- Requirements covered: `R-22.1`–`R-22.7`, `R-22.18`, `R-21.64`, `R-21.65`
- Tests: `T-AND-8401`…`T-AND-8410`
- All nine D-115 hard-gate numbers (mirroring T-PRF-1/2/3/5/6/7/9/10/13's D-218 set) met on `DEV-AND-PRO` and `DEV-AND-MID`; D-223 save-before-evict ordering proven with timestamp evidence, not assumed

**Impl log.** `android/docs/impl-log/BATCH-8.4.md`

---

### Batch 8 · Agent 8.5 — Accessibility, font scale, RTL sweep

**Depends on:** G7 · **Parallel-safe with:** every other Batch 8 agent

**Mission.** TalkBack sweep of every screen, 48dp touch-target floor (D-319), font-scale to
200%, reduce-motion, contrast. Port whatever the iOS Wave 3 design/accessibility sweep
produced and follow whatever the iOS UX-1 canvas-VoiceOver decision landed on for the
canvas's own accessibility approach. Also perform the API 30 emulator visual check G8
requires (spine §6, FDA-07, R9): `Modifier.blur` is a no-op below API 31, so
`MkFloatingBar`'s translucent surface degrades to a flat alpha surface on API 29–30 — both
named perf devices (`DEV-AND-PRO`/`DEV-AND-MID`) are API 31+, so without this dedicated check
that degraded path would never actually be looked at by anyone.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `EXECUTION_PLAN_2026-07-28.md` Wave 3 · Agent 3.2 (~L638) | the iOS Dynamic Type / a11y-label / zoom-value / tour-frame sweep this agent ports |
| `EXECUTION_PLAN_2026-07-28.md` Wave 5 · Decision UX-1 (~L802) | the canvas-VoiceOver decision: recommended YES, scoped to top-level nodes only (arrange-mode glyph children deferred) — confirm current status before porting (as of this plan's writing it is approval-gated in the founder's queue, not yet executed on iOS; if still unexecuted at Batch 8 runtime, port the SAME scoped recommendation to TalkBack rather than inventing a different scope, and record the iOS status honestly in `A11Y_REPORT.md` rather than assuming it shipped) |
| `FOUNDATION.md` D-319 (Android accessibility, spine §2) | 48dp floor, `fontScale`, reduce-motion source |
| `PRD.md` §22 (R-22.x) general quality bar | RTL-first, dynamic type, VoiceOver/TalkBack, touch targets (CLAUDE.md quality bar) |
| `mk-designsystem/**` (Batch 2.4/2.5), `mk-canvas/**` (Batch 5) sources | the components under audit |
| `ANDROID_SPINE.md` FDA-07, D-305, Risk R9, `§6` G8 | the exact `MkFloatingBar`/`Modifier.blur`/API 30 limitation this agent must visually check and document; an emulator running exactly API 30 is required — both named perf devices run API 31+ and cannot exercise this path |
| `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkFloatingBar.kt` (Batch 2.4) | the component under check — its translucent-surface modifier flagged for this exact visual QA pass at Batch 1's port map |

**Owns (creates or edits — no other agent may touch these).**
- `android/docs/A11Y_REPORT.md` (new)
- Accessibility-label/content-description, touch-target, and `fontScale`-clamp fixes inside `mk-designsystem/src/main/kotlin/**` and `:app/src/main/kotlin/**/appshell/scenes/**` Compose screens — presentation-layer only, mirroring iOS Wave 3 · 3.2's scope restriction
- `mk-canvas/src/main/kotlin/**/MkCanvasViewController.kt` — TalkBack `AccessibilityNodeProvider`
  wiring on the `MkCanvasView : View` class it contains (per spine §3.3, the class was never
  split into its own `MkCanvasView.kt` file — Agent 5.1 put it inside
  `MkCanvasViewController.kt`, and no agent creates a separate `MkCanvasView.kt`; cite the real
  path), scoped exactly per the UX-1 decision (top-level nodes only)
- `mk-canvas/src/test/kotlin/**/MkCanvasAccessibilityTest.kt` (new, mirrors the pre-staged `MKCanvasAccessibilityTests.swift` from the UX-1 work packet)
- `android/docs/impl-log/BATCH-8.5.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**` (read the UX-1 decision, do not implement
or alter it there — that remains iOS's own approval-gated work); `android/SHAPING_DELTAS.md`,
`android/docs/WIRING_AUDIT.md`, `android/docs/PERF_REPORT.md`, `android/PARITY_MATRIX.md`;
non-presentation `mk-canvas` gesture/render logic (owned by 8.3/earlier batches).

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `MakhtootKit/Sources/MKDesignSystem/MKTypeRamp.swift` | — | `mk-designsystem/src/main/kotlin/**/MkTypeRamp.kt` | `.custom(size:, relativeTo:)` Dynamic Type → Compose `fontScale`-aware `TextUnit` scaling with an accessibility-size clamp, same intent as Wave 3 · 3.2 step 1 |
| `Makhtoot/AppShell/Scenes/Editor/ZoomControlsView.swift` | — | `:app` `ZoomControlsView.kt` | `.accessibilityValue(percentageText)` → `contentDescription` carrying the same Arabic-Indic percentage, Wave 3 · 3.2 step 3 |
| `MakhtootKit/Sources/MKCanvas/MKCanvasViewController.swift` (417 LOC) + UX-1 work packet (~L815) | 417 | `mk-canvas/src/main/kotlin/**/MkCanvasViewController.kt` (the `MkCanvasView : View` class it contains — Agent 5.1's port target, not a separate file) | UX-1's `accessibilityElements`-per-top-level-node design → `AccessibilityNodeProvider` exposing one virtual node per top-level `LayersModel` entry, custom move/resize/delete actions, recomputed on scene mutation/selection change; arrange-mode glyph children explicitly out of scope, matching the iOS recommendation |

**Tasks.**
1. TalkBack sweep every reachable screen (browser, editor shell, all sheets/popovers from
   Batch 7); confirm every interactive element has a correct Arabic `contentDescription`
   sourced from the string catalog (D-318), not a hardcoded literal — the direct Android
   analogue of Wave 3 · 3.2's `LocalizedStringResource` sweep.
2. Audit every tappable control against the 48dp floor (D-319); fix undersized targets.
3. Set every screen's `fontScale` to 200% (largest Android accessibility bracket) and
   confirm layout holds — clamp tool-rail/inspector text where iOS clamped at
   `.accessibility3` (Wave 3 · 3.2 step 1).
4. Confirm reduce-motion (`Settings.Global.TRANSITION_ANIMATION_SCALE` = 0) suppresses
   the same animations the iOS reduce-motion path suppresses.
5. Contrast-audit all 5 `MkTheme` themes (Hibr/Kufi/Naqsh/Raml/Tayf) against WCAG AA for
   text-on-background pairs.
6. Canvas accessibility: read the current status of the iOS UX-1 decision before writing
   any code. If it has shipped by the time this agent runs, port its actual shape exactly.
   If it is still approval-gated/unexecuted, implement the scoped TalkBack equivalent
   (one virtual accessibility node per top-level scene node; move/resize/delete custom
   actions; arrange-mode glyph children deferred) and record in `A11Y_REPORT.md` that
   Android is, in this one respect, ahead of the iOS baseline it was supposed to mirror —
   named honestly, not hidden.
7. **API 30 emulator check (`T-AND-8507`, FDA-07/D-305/Risk R9).** Launch an emulator
   pinned to exactly API 30 (neither named perf device covers this — both are API 31+) and
   visually inspect every screen where `MkFloatingBar`'s translucent-surface modifier is in
   use (the two dense popovers plus the low-content zoom-controls bar, per its Batch 1/2.4
   port map). Confirm the degraded flat-alpha-surface fallback (no blur, since
   `Modifier.blur` is a no-op below API 31) still reads as an intentional, legible surface —
   not as a rendering bug — and record the result with a screenshot in `A11Y_REPORT.md`.
   This is a documented limitation to verify degrades gracefully, not a defect to fix.

**Acceptance.**
- `./gradlew :mk-designsystem:testDebugUnitTest :mk-canvas:testDebugUnitTest :mk-designsystem:lintDebug :mk-canvas:lintDebug` green
- Requirements covered: `R-22.x` quality-bar items (RTL-first, dynamic type, VoiceOver/TalkBack, 44pt→48dp targets per CLAUDE.md); D-319
- Tests: `T-AND-8501`…`T-AND-8507`
- TalkBack sweep clean (G8's own gate line); zero sub-48dp targets; 200% `fontScale` layout holds on every screen; `MkFloatingBar`'s flat-alpha-surface fallback visually checked and documented (with screenshot) on an API 30 emulator (G8's own gate line, spine §6)

**Impl log.** `android/docs/impl-log/BATCH-8.5.md`

---

### Batch 8 · Agent 8.6 — Instrumented UI tests (port the 7 iOS UI tests and extend)

**Depends on:** G7 · **Parallel-safe with:** every other Batch 8 agent

**Mission.** Port the 7 `MakhtootUITests/*.swift` tests to Compose UI / Espresso, driving
the real production paths exactly as the iOS originals do — no debug-only bypass hooks
except where the iOS test itself uses one. Extend with Android-specific cases:
configuration change and process death mid-edit, split-screen and foldable fold/unfold,
back-gesture handling, IME rotation, and low-memory kill during autosave.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootUITests/ArrangeModeEnterExitUITests.swift` (106 LOC) | Arrange Mode chrome swap (wand → `ArrangeToolbarView` → إغلاق close) |
| `MakhtootUITests/CompositionRootWiringTests.swift` (123 LOC) | the pixel-diff regression net for FC-1-shaped wiring bugs — the same class of bug 8.1 audits statically, this proves it dynamically |
| `MakhtootUITests/InsertTextCommitUITests.swift` (115 LOC) | insert → commit → becomes live selection, via `TextInsertSheet` |
| `MakhtootUITests/MakhtootFileOpenInPlaceUITests.swift` (122 LOC) | `.makhtoot` open-in-place via the system share/open surface — Android drives this via SAF `ACTION_OPEN_DOCUMENT`/zip import per D-309, not a Files.app equivalent |
| `MakhtootUITests/OnboardingFirstProjectUITests.swift` (92 LOC) | first-launch onboarding → created project → editor opens |
| `MakhtootUITests/PremiumExportPaywallGateUITests.swift` (85 LOC) | export paywall gate (SVG specifically, stable since before FC-2) |
| `MakhtootUITests/SettingsGeneralCrashRepro.swift` (35 LOC) | browser → settings gear → عام (General) — regression repro for a real 2026-07-29 crash |

**Owns (creates or edits — no other agent may touch these).**
- `:app/src/androidTest/kotlin/**/ArrangeModeEnterExitUiTest.kt`
- `:app/src/androidTest/kotlin/**/CompositionRootWiringUiTest.kt`
- `:app/src/androidTest/kotlin/**/InsertTextCommitUiTest.kt`
- `:app/src/androidTest/kotlin/**/MakhtootFileOpenInPlaceUiTest.kt`
- `:app/src/androidTest/kotlin/**/OnboardingFirstProjectUiTest.kt`
- `:app/src/androidTest/kotlin/**/PremiumExportPaywallGateUiTest.kt`
- `:app/src/androidTest/kotlin/**/SettingsGeneralCrashReproUiTest.kt`
- `:app/src/androidTest/kotlin/**/ConfigChangeProcessDeathUiTest.kt` (new — T-AND-8608/8609)
- `:app/src/androidTest/kotlin/**/MultiWindowFoldableUiTest.kt` (new — T-AND-8610/8611)
- `:app/src/androidTest/kotlin/**/BackGestureUiTest.kt` (new — T-AND-8612)
- `:app/src/androidTest/kotlin/**/ImeRotationUiTest.kt` (new — T-AND-8613)
- `:app/src/androidTest/kotlin/**/LowMemoryAutosaveKillUiTest.kt` (new — T-AND-8614)
- `android/docs/impl-log/BATCH-8.6.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**`, `MakhtootUITests/**`; any file outside
`:app/src/androidTest/**` and this agent's own impl log — bug fixes surfaced by a failing
test are reported (with the failing test left RED and documented, mirroring how
`CompositionRootWiringTests.swift` was allowed to stay RED across a wave boundary in the
iOS plan) rather than silently patched in another agent's owned module.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `ArrangeModeEnterExitUITests.swift` | 106 | `ArrangeModeEnterExitUiTest.kt` | `XCUIApplication` → `ComposeTestRule` + `UiDevice`; tap "وضع الترتيب" wand, confirm the Arrange toolbar replaces the standard tool rail, tap "إغلاق" to exit |
| `CompositionRootWiringTests.swift` | 123 | `CompositionRootWiringUiTest.kt` | Same indirect-assertion shape: toggle Bold on committed text, screenshot-diff before/after (no direct process-internal `AppContainer` access from an instrumented test any more than XCUITest has one) |
| `InsertTextCommitUITests.swift` | 115 | `InsertTextCommitUiTest.kt` | Drive the real `TextInsertSheet`/`MkTextInsertSheet`, confirm commit via the Font settings sheet's selection-bound Traits section |
| `MakhtootFileOpenInPlaceUITests.swift` | 122 | `MakhtootFileOpenInPlaceUiTest.kt` | No Files.app/`simctl get_app_container` equivalent needed — SAF lets an instrumented test seed a document directly via `ACTION_OPEN_DOCUMENT` intent stubbing (`Intents.intending`); also covers D-309 zip import specifically, which the iOS original could not (zip import didn't exist yet on iOS) |
| `OnboardingFirstProjectUITests.swift` | 92 | `OnboardingFirstProjectUiTest.kt` | `-MKHasCompletedOnboarding` `UserDefaults` argument-domain override → `SharedPreferences`/`DataStore` test-only seed via `ActivityScenarioRule` launch args; tap "التالي" (Next) until "ابدأ التصميم" is reachable regardless of trial-page presence, same page-count-agnostic design |
| `PremiumExportPaywallGateUITests.swift` | 85 | `PremiumExportPaywallGateUiTest.kt` | SVG export gate check via `container.entitlementProvider` analogue; same free-tier-only precondition caveat |
| `SettingsGeneralCrashRepro.swift` | 35 | `SettingsGeneralCrashReproUiTest.kt` | Direct regression repro: browser → settings gear → عام (General) does not crash |

**Tasks.**
1. Port all 7 tests verbatim in intent: same production entry points, same Arabic string
   assertions, same fresh-project bootstrap pattern per test.
2. Add `T-AND-8608` configuration-change (rotation) mid-edit: in-flight text-edit overlay
   session and undo stack survive a rotation without a partial command (mirrors R-21.68's
   iOS "device rotation / Stage Manager resize" requirement, ported to Android's own
   config-change lifecycle).
3. Add `T-AND-8609` process-death mid-edit: `ActivityScenario` simulates a system-initiated
   process kill (not just a config change) mid-autosave-debounce window; relaunch restores
   via the same journal-replay path 8.4 verifies at the perf level.
4. Add `T-AND-8610`/`T-AND-8611` split-screen and foldable fold/unfold: multi-window resize
   and a fold/unfold transition mid-gesture cancel cleanly, viewport re-fits, selection
   preserved (Android-native extension of R-21.68).
5. Add `T-AND-8612` predictive back-gesture: back from the editor with unsaved-but-
   journaled work never loses data and never double-navigates.
6. Add `T-AND-8613` IME rotation: switching Arabic keyboard layouts mid-composition does
   not corrupt the in-progress text-edit overlay session — the transparent `EditText` +
   custom `InputConnection` overlay from work item 5.4a (D-307).
7. Add `T-AND-8614` low-memory kill during autosave: combine 8.4's `onTrimMemory` critical
   path with an actual process kill during the debounce window; relaunch recovers.

**Acceptance.**
- `./gradlew :app:connectedDebugAndroidTest` green (all 14 tests) on `DEV-AND-PRO` and `DEV-AND-MID`
- Requirements covered: `R-6.11`, `R-21.35`, `R-21.42`, `R-21.68`; D-306, D-307, D-309
- Tests: `T-AND-8601`…`T-AND-8614`
- Every ported test drives the real production path, not a debug bypass beyond what the iOS original itself used
- Any bug a new test surfaces is reported, not silently patched outside this agent's owned test files

**Impl log.** `android/docs/impl-log/BATCH-8.6.md`

---

### Batch 8 · Agent 8.7 — Edge-case compendium sweep (PRD §21)

**Depends on:** G7 (and, practically, the outputs of 8.1–8.6 for many
individual items) · **Parallel-safe with:** every other Batch 8 agent (may re-run its own
matrix pass after the others land — this agent's own file writes don't collide with theirs)

**Mission.** Work `PRD.md` §21 case by case on Android and record the result for each.
Close out `android/PARITY_MATRIX.md`: every one of the 319 `R-…` ids must be ✅ with the
Android file that implements it and the test that proves it. Any id that cannot be closed
is escalated with a named reason — but the plan's contract is that there are none.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `PRD.md` §21.1–21.9 (R-21.1…R-21.68) | the full edge-case compendium being swept, grouped: text/Unicode (21.1), fonts (21.2), Arrange Mode lifecycle (21.3), path text (21.4), persistence/autosave (21.5), sync (21.6), store/trial (21.7), canvas/layers/import (21.8), memory/system/lifecycle (21.9) |
| `android/PARITY_MATRIX.md` (Batch 0.1, updated incrementally through Batches 1–8) | the 319-row ledger this agent closes out |
| Every other Batch 8 agent's deliverable (`WIRING_AUDIT.md`, `SHAPING_DELTAS.md`, render/export/perf/a11y reports, the `androidTest` suite) | most §21 items are already covered by tests in other work items — 8.7's job is to CITE that proof in the matrix, not duplicate it |
| `FOUNDATION.md` D-309, D-310, D-311, D-312, D-320, D-321 (spine §2) | Android-specific mechanisms several §21 items now route through (zip interop, Drive sync, Play Billing, trial, analytics, referral) |
| `ANDROID_SPINE.md` §5.3, §9, §16 | the rule that Agents 8.7 and 9.5 register every new `T-AND-*` id back into `TEST_MATRIX.md`, and the `T-AND-<n>`-for-Android-only-tests convention this agent's own registration entries must follow |

**Owns (creates or edits — no other agent may touch these).**
- `android/PARITY_MATRIX.md` — final close-out pass (row-by-row ✅/escalation, cross-referencing every other agent's proof)
- `TEST_MATRIX.md` — append-only: one new row per `T-AND-8<n>` id introduced across this batch (Task 5), in the existing table format; no existing row edited
- `:app/src/androidTest/kotlin/**/EdgeCase/ZipImportPathTraversalTest.kt` (new — T-AND-8701)
- `mk-fonts/src/androidTest/kotlin/**/EdgeCase/SafFontImportCorpusTest.kt` (new — T-AND-8702)
- `mk-sync/src/androidTest/kotlin/**/EdgeCase/DriveQuotaExceededTest.kt` (new — T-AND-8703)
- `mk-store/src/androidTest/kotlin/**/EdgeCase/AutoBackupOffTrialReinstallTest.kt` (new — T-AND-8704)
- `mk-export/src/androidTest/kotlin/**/EdgeCase/TrimMemoryDuringExportTest.kt` (new — T-AND-8705)
- `android/docs/impl-log/BATCH-8.7.md`

**Never touch.** `MakhtootKit/**`, `Makhtoot/**`; `android/SHAPING_DELTAS.md`,
`android/docs/WIRING_AUDIT.md`, `android/docs/PERF_REPORT.md`, `android/docs/A11Y_REPORT.md`
(read and cite, do not rewrite); any other agent's `androidTest` files outside the 5 new
edge-case files listed above.

**Port map.**
| Swift source | LOC | Kotlin target | Notes / platform substitution |
|---|---|---|---|
| `PRD.md` §21 (whole section, R-21.1…R-21.68) | — | `android/PARITY_MATRIX.md` close-out + 5 new edge-case tests | Most of §21 is proven Android-side by 8.1–8.6's own tests already; only the 5 genuinely Android-only mechanisms (zip interop D-309, Drive quota D-310, Auto Backup trial weakness D-312, `onTrimMemory` export pause D-116 Android mapping, SAF font import) need dedicated new tests here |

**Tasks.**
1. Walk `PRD.md` §21 top to bottom. For each `R-21.n`, find the Android file + test that
   proves it (usually already delivered by 0–8.6); write the matrix row. Where the iOS
   mechanism has an Android-only substitution (iCloud→Drive, Keychain-backed trial→
   Keystore-wrapped DataStore + Auto Backup, Files.app Open-In→SAF, App Store review→Play
   review), verify the Android mechanism actually satisfies the SAME user-facing guarantee,
   not just an analogous-sounding one.
2. Build the 5 genuinely new Android-only edge-case tests (T-AND-8701…8705) for the
   mechanisms with no 1:1 iOS analogue: crafted-zip path-traversal rejection (D-309, reusing
   `PackageImportValidator`'s allowlist+caps logic ported at Batch 3.4/9.3), SAF font-import
   corpus (duplicate PostScript name, corrupt sfnt, woff2 rejection — R-21.22/R-21.24 on
   Android's own import surface), Drive `appDataFolder` quota-exceeded (R-21.49 Android
   path), Auto Backup disabled trial-reinstall (D-312's documented weaker-than-Keychain
   survival — must show the true remaining/expired state, never a re-granted trial),
   `onTrimMemory` critical mid-export pause/resume (R-21.44/T-MEM-6 Android path via
   D-116's static-strip-budget-plus-pause policy).
3. Close `android/PARITY_MATRIX.md`: every row among the 319 `R-…` ids gets ✅ + Android
   file + proving test, OR a named escalation with a concrete reason and owner. G8 requires
   zero open escalations.
4. Cross-check `android/PARITY_MATRIX.md`'s row count against `PRD.md`'s actual `R-…` id
   count (319) — no id silently dropped, none double-counted, none invented.
5. **Register every new `T-AND-8<n>` id introduced across this batch back into
   `TEST_MATRIX.md`** (spine §5.3/§16) — walk this batch's own "Android-specific test IDs"
   table top to bottom and add one row per id in `TEST_MATRIX.md`'s existing format,
   append-only. Verified by direct count against this batch's own id table: **46** distinct
   `T-AND-8<n>` ids (`T-AND-8101`…`T-AND-8102`, `T-AND-8201`…`T-AND-8203`,
   `T-AND-8301`…`T-AND-8305`, `T-AND-8401`…`T-AND-8410`, `T-AND-8501`…`T-AND-8507`
   [`T-AND-8507` added by this correction pass, spine §6 G8/FDA-07], `T-AND-8601`…
   `T-AND-8614`, `T-AND-8701`…`T-AND-8705`) — no id skipped, none invented.
   Do not cite `T-FC-2` anywhere in the matrix or the register: it is not a `TEST_MATRIX.md`
   id (the file's own prefixes are `T-ANL/AR/ARR/AST/BLD/CVS/DST/EXP/FNT/MDL/MEM/OFF/PRF/
   PTH/SK/SYN/TXT/XXX`); where the FC-1/FC-2 wiring-bug shape is relevant (as in 8.1's own
   mission), cite it as the `AUDIT_2026-07-28.md` finding id `FC-2`, never as a test id.

**Acceptance.**
- `./gradlew :app:connectedDebugAndroidTest :mk-fonts:connectedDebugAndroidTest :mk-sync:connectedDebugAndroidTest :mk-store:connectedDebugAndroidTest :mk-export:connectedDebugAndroidTest` green
- Requirements covered: all of `PRD.md` §21 (`R-21.1`…`R-21.68`) plus, by citation, every other `R-…` id closed by an earlier batch
- Tests: `T-AND-8701`…`T-AND-8705`, plus every cited `T-…`/`T-AND-…` id from 8.1–8.6
- `android/PARITY_MATRIX.md` shows all 319 `R-…` ids ✅ with zero open escalations — the plan's own contract for this file
- All 46 of this batch's `T-AND-8<n>` ids appear as rows in `TEST_MATRIX.md`; zero `T-FC-2` citations anywhere

**Impl log.** `android/docs/impl-log/BATCH-8.7.md`

---

## Appendix — file-ownership matrix (collision proof)

One row per owned path prefix, one column per owning agent. Every path prefix below is
touched by exactly one Batch 8 agent.

| Path prefix | Owning agent |
|---|---|
| `Scripts/android/stub-source-audit.sh` | 8.1 |
| `android/docs/WIRING_AUDIT.md` | 8.1 |
| `android/app/src/main/kotlin/net/binjamshid/makhtoot/appshell/composition/AppContainer.kt` | 8.1 |
| `android/docs/impl-log/BATCH-8.1.md` | 8.1 |
| `android/SHAPING_DELTAS.md` | 8.2 |
| `android/docs/SHAPING_PARITY_REPORT.md` | 8.2 |
| `mk-textengine/src/test/kotlin/**/ShapingParityTest.kt` | 8.2 |
| `mk-arrange/src/test/kotlin/**/ArrangeFidelityBlockTest.kt` | 8.2 |
| `mk-textengine/src/main/kotlin/**` (bug fixes only) | 8.2 |
| `mk-arrange/src/main/kotlin/**` (bug fixes only) | 8.2 |
| `android/docs/impl-log/BATCH-8.2.md` | 8.2 |
| `android/docs/RENDER_EXPORT_PARITY.md` | 8.3 |
| `mk-render/src/test/kotlin/**/RenderGoldenTest.kt` | 8.3 |
| `mk-export/src/test/kotlin/**/ExportGoldenTest.kt` | 8.3 |
| `mk-render/src/main/kotlin/**` (bug fixes only) | 8.3 |
| `mk-export/src/main/kotlin/**` (bug fixes only) | 8.3 |
| `android/docs/impl-log/BATCH-8.3.md` | 8.3 |
| `android/docs/PERF_REPORT.md` | 8.4 |
| `mk-canvas/src/androidTest/kotlin/**/FrameTimingBenchmark.kt` | 8.4 |
| `mk-persistence/src/androidTest/kotlin/**/AutosaveBenchmark.kt` | 8.4 |
| `mk-export/src/androidTest/kotlin/**/ExportBenchmark.kt` | 8.4 |
| `:app/src/androidTest/kotlin/**/LaunchBenchmark.kt` | 8.4 |
| `mk-foundation/src/main/kotlin/**/MkMemoryPressureMonitor.kt` (ladder-ordering fix only) | 8.4 |
| `android/docs/impl-log/BATCH-8.4.md` | 8.4 |
| `android/docs/A11Y_REPORT.md` | 8.5 |
| `mk-designsystem/src/main/kotlin/**` (a11y/touch-target/fontScale fixes only) | 8.5 |
| `:app/src/main/kotlin/**/appshell/scenes/**` (a11y fixes only) | 8.5 |
| `mk-canvas/src/main/kotlin/**/MkCanvasViewController.kt` (TalkBack wiring on its `MkCanvasView : View` class only) | 8.5 |
| `mk-canvas/src/test/kotlin/**/MkCanvasAccessibilityTest.kt` | 8.5 |
| `android/docs/impl-log/BATCH-8.5.md` | 8.5 |
| `:app/src/androidTest/kotlin/**/ArrangeModeEnterExitUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/CompositionRootWiringUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/InsertTextCommitUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/MakhtootFileOpenInPlaceUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/OnboardingFirstProjectUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/PremiumExportPaywallGateUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/SettingsGeneralCrashReproUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/ConfigChangeProcessDeathUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/MultiWindowFoldableUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/BackGestureUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/ImeRotationUiTest.kt` | 8.6 |
| `:app/src/androidTest/kotlin/**/LowMemoryAutosaveKillUiTest.kt` | 8.6 |
| `android/docs/impl-log/BATCH-8.6.md` | 8.6 |
| `android/PARITY_MATRIX.md` (final close-out pass) | 8.7 |
| `:app/src/androidTest/kotlin/**/EdgeCase/ZipImportPathTraversalTest.kt` | 8.7 |
| `mk-fonts/src/androidTest/kotlin/**/EdgeCase/SafFontImportCorpusTest.kt` | 8.7 |
| `mk-sync/src/androidTest/kotlin/**/EdgeCase/DriveQuotaExceededTest.kt` | 8.7 |
| `mk-store/src/androidTest/kotlin/**/EdgeCase/AutoBackupOffTrialReinstallTest.kt` | 8.7 |
| `mk-export/src/androidTest/kotlin/**/EdgeCase/TrimMemoryDuringExportTest.kt` | 8.7 |
| `android/docs/impl-log/BATCH-8.7.md` | 8.7 |
| `TEST_MATRIX.md` (append-only: new `T-AND-8<n>` rows) | 8.7 |

No file has two writers in this batch. Every agent's bug-fix authority into shared
production source (8.2 into `mk-textengine`/`mk-arrange`, 8.3 into `mk-render`/`mk-export`,
8.4 into `mk-foundation`'s memory monitor, 8.5 into `mk-designsystem`/`:app` presentation
layer/`mk-canvas`'s accessibility wiring) is scoped narrowly enough by subject matter that
no two agents' fixes land in the same file; where two agents' concerns border the same
module (e.g. 8.3 and 8.6 both touch `mk-canvas`-adjacent surfaces), 8.3 stays out of
`mk-canvas` entirely and 8.5's `mk-canvas` edit is limited to the single named
`MkCanvasViewController.kt` file — and, within it, only the `MkCanvasView : View` class's
TalkBack/`AccessibilityNodeProvider` wiring, never its gesture/render internals (spine §3.3:
there is no separate `MkCanvasView.kt` file anywhere in this port — Agent 5.1 put the class
inside `MkCanvasViewController.kt`, and every citation in this batch has been corrected to
the real path).
