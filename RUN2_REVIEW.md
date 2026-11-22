# Makhtoot (مخطوط) — RUN2_REVIEW.md
## Run-2 adversarial review: mandate, verdicts, dispositions, handoff

Date: 2026-07-17

---

## 1. Mandate & method

Run 2's mandate is PLAN.md §4 ("Run-2 Adversarial-Review Handoff"): 12 ordered
attack targets, each naming the specific Run-1 claim to falsify, plus a standing
instruction to verify every D-### citation in PLAN.md and DEPENDENCY_GRAPH.md
against FOUNDATION.md verbatim and flag any deliverable statement that silently
extends a locked decision, plus RUN1_SELF_REVIEW.md §8's closing note that the
"decision recorded but not propagated" defect class found there should itself be
added to the Run-2 attack list — a propagation sweep across all prior decisions.

The 2026-07-17 review ran 14 parallel read-only checks against the shipped
package (12 numbered targets and two citation and propagation sweeps).
`RUN2_DISPOSITIONS.md` assigns each accepted finding a new DECISIONS_LOG record
(D-220–D-231) or a documentation fix (DF-1–DF-12) and records file ownership.
Seven disjoint edit groups (W1–W7) applied the changes, followed by a review of
the resulting package.

---

## 2. Verdicts by target

Verdict legend: **HOLDS** — the attacked claim survived; **GAP** — an
unspecified or untested area was found and closed; **BROKEN** — the attacked
claim was empirically or logically false as stated and has been corrected.

| # | Target | Verdict | Headline finding |
|---|---|---|---|
| 1 | Shaping under movement | BROKEN | "Arranged render == live render" across the full D-120 font list is empirically false — fidelity tests ran on Amiri/Noto only (R2-1-1, blocker). Single-glyph-scale-inside-a-joined-word neighbor behavior was unspecified (R2-1-5). GPOS cursive attachment (type 3) was unmodeled by the mark-capture model (R2-1-3, VERIFY per font). D-108's claimed risk-register citation did not exist (R2-1-8). |
| 2 | Base-mark attachment | BROKEN | The composition-transform formula omitted `relativeOffset` entirely (R2-2-1). Detach → rotate → re-attach carried a double-rotation ambiguity (R2-2-3). All mark tests were manual-visual — unable to catch a wrong-space implementation (R2-2-8). |
| 3 | Ligatures | BROKEN | The P0 "looks unchanged" requirement was contradicted by the clamp's own escape hatch — no defined behavior when the natural fit falls outside [0.85, 1.15] (R2-3-2). The recompose dirty-check was transform-only and silently discarded style-only edits (R2-3-3). The self-review's claimed risk-register entry for ligature fidelity did not exist (R2-3-5). |
| 4 | Bidi | GAP/BROKEN | The attack's own premise was invalid — partial re-derivation of a sub-run is impossible by design (INV-1/R-6.11), and RUN1_SELF_REVIEW's claim that "PRD edge cases specify expected behavior" for that case was false (R2-4-1). The path-text engine's own naming contradicted itself — "visual-order pen" describing logical-reading-order traversal (R2-4-4). Cross-run letter-selection had no defined bounds/transform behavior (R2-4-7). |
| 5 | SVG/licenses | BROKEN | Two incompatible `MKLicenseRecord` definitions existed in the package (ARCHITECTURE vs WS-09) (R2-5-7). Two contradictory `data-mk` SVG provenance schemas existed (ARCHITECTURE vs WS-08) (R2-5-6). OFL Reserved-Font-Name exposure under subset-embedding (as opposed to whole-font embedding) was entirely unaddressed (R2-5-2). |
| 6 | CMYK | GAP | A second, unaudited raster conversion path falsified the "single conversion point" claim in D-117 (R2-6-2). Three documents disagreed on the verification protocol's actual rigor (R2-6-5). The existing fixture set could not discriminate a wrong rendering intent from a correct one (R2-6-6). Two previously unhedged platform assumptions (iOS CMYK bitmap-context support; OutputIntent key shape) are now explicit VERIFY-AT-IMPLEMENTATION items (R2-6-3/6-4). |
| 7 | Gating (free-tier / trial) | GAP | A sustained pre-launch clock rollback amounted to an unlimited trial; "monotonic guard" was a misnomer for what the mechanism actually does; the reserved `lastObservedBoottime` field was never wired (R2-7-4, High). The hidden-premium-layer export-block behavior was ambiguous (render-based vs presence-based) (R2-7-2). The claimed automated S1-stub audit did not exist (R2-7-6). A second-device post-sync entitlement-enforcement path was asserted by RUN1_SELF_REVIEW but unimplemented and untested (R2-7-5). |
| 8 | iCloud / FD-01 | GAP (as PLAN predicted) | No post-FD-01-sweep sync re-verification step existed anywhere in the checklist. APP_STORE_CHECKLIST 1.08 promoted only the analytics record type to production, not `Project`/`ProjectAsset` — a silent production sync-breakage risk (R2-8-2). Account switch-back (A→B→A) could mint spurious conflict copies with no reconciliation rule (R2-8-5). |
| 9 | Memory-pressure autosave | GAP→BROKEN | The critical-path save did a full-scene re-encode exactly when memory is scarcest, with no jetsam-safety bound anywhere in the design (R2-9-1/9-2/9-3). D-210's claimed "monitor can shrink strip height mid-export" mechanism appeared nowhere in the actual code sketch. T-MEM-6 cited an export-under-pressure policy that had never actually been written (R2-9-8). The journal artifact's path contradicted itself between ARCHITECTURE and WS-02 (R2-9-5). |
| 10 | Offline mode | mostly HOLDS | The catalog-manifest fetch/cache task did not exist at all in any workstream packet (R2-10-1, High). Three different offline-paywall strings were in circulation across PRD/WS-10/TEST_MATRIX (R2-10-2). An 8-week vs 2-week analytics-retention conflict existed between two documents (R2-10-3). The core offline architecture (network confined to three named features) survived direct attack cleanly. |
| 11 | Precedence (trial/lifetime/subscription) | core math HOLDS | No double-payment warning existed for a lifetime purchase made during an active subscription (R2-11-1). T-SK-13 carried a live, unresolved "document which [behavior]" TODO on mid-export revocation (R2-11-3). The self-review's "6×6 [entitlement-state] combinations tested" claim was backed by only 5 actually-realized combinations (R2-11-4). Subscribe-then-refund silently resurrected the trial with no recorded rationale (R2-11-5). A dangling R-21.70 citation was found. The core D-113 precedence ordering itself held under attack. |
| 12 | Referral (App Review risk) | BROKEN | The RUN1_SELF_REVIEW claim that referral strings were already excluded from the shipped string catalog was false (R2-12-1). Guideline 2.3.1 (dormant/hidden feature) had never actually been analyzed anywhere in the checklist (R2-12-4). A definitive posture was adopted per the target's own instruction: compile-time exclusion of the referral module from Release builds (D-225, FOUNDER-CONFIRM). |

**Sweep A — D-### citation audit.** 221 citations checked across PLAN.md and
DEPENDENCY_GRAPH.md against FOUNDATION.md verbatim. 0 phantom citations found.
3 defects found and fixed: D-101's citation dropped the word "ever" from the
decision it cited, one citation misattributed a decision to the wrong module
("spine" edge), and one citation pointed at D-115 where D-116 was the correct
target (no-loss recovery).

**Sweep B — propagation audit.** D-100…126, all FD-0x, and D-215…219 were
checked for propagation to every operative deliverable and found clean except
for one class of defect: ARCHITECTURE §2.1 had locally numbered two of its own
decisions "D-200" and "D-201," colliding with DECISIONS_LOG's own
already-assigned D-200 (localization) and D-201 (text-input overlay) — both
orphaned ARCHITECTURE decisions were recovered under fresh, non-colliding ids
(D-230, D-231). Three further propagation defects were found and fixed: D-211
(trial-persistence honesty limits) was never propagated into ARCHITECTURE §19.2;
D-201's rotation-during-editing clause was contradicted by WS-06 task 13's
"transform-matched (zoom/rotation)" wording (fixed to honor D-201: rotation
normalizes during editing); D-207's analytics kill-switch mechanism was inverted
in four documents claiming "no remote config" (fixed to honor D-207: the
CloudKit public-DB record read is a remote, serverless kill switch in addition
to the local consent toggle).

---

## 3. Dispositions

**New decision records (D-220–D-231).**

- **D-220** — Mark-attachment geometry made normative (amends D-105/D-106): `relativeOffset` is base-local; normative world transform and re-attach formula fixed; `MKMarkNode.stackIndex` replaces the `visualIndex` overload.
- **D-221** — Ligature fidelity clamp semantics + recompose dirty-check (amends D-108): WS-04's affine fit (scale clamped [0.85,1.15]) is normative; out-of-clamp REFUSES fidelity mode and falls back to default forms; recompose dirty-check now compares transform AND style.
- **D-222** — Per-font Arabic fidelity gate (amends D-120): every bundled font must pass the full arrange-fidelity block (T-AR-31/32/33 + T-AR-36…38), not just the reduced T-AR-58 sweep; adds a GPOS cursive-attachment (type 3) audit step and a dlig decompose fixture.
- **D-223** — Critical-path autosave is journal-only (amends D-116; adjusts D-210): stage-3 autosave is a synchronous journal-only flush (`journal.mkj`, package root); full-scene `flushNow()` runs only at stages 1–2; D-210's "shrink strip mid-export" claim is struck in favor of static-sizing-plus-pause.
- **D-224** — Trial clock guard hardened (amends D-123; extends D-211): wires the reserved `lastObservedBoottime` field into an uptime-vs-wall-clock cross-check; renames "monotonic guard" to "wall-clock high-water mark + uptime cross-check"; residual reboot+rollback recorded honestly, not eliminated.
- **D-225** — Referral dormancy: compile-time exclusion from Release (amends D-124 mechanism; FD-05 unchanged) — **FOUNDER-CONFIRM**: `#if MAKHTOOT_REFERRAL_ENABLED`, Debug/internal only; CI greps the built Release product for referral vocabulary.
- **D-226** — CMYK conversion audit tightened (amends D-117 execution): explicit `.relativeColorimetric` rendering intent on the raster path; "single conversion point" corrected to "two documented, intent-matched conversion sites"; external-tool ground truth specified for the ±1% tolerance; two VERIFY-AT-IMPLEMENTATION spikes block WS-08 task 12.
- **D-227** — Export/licensing record + SVG schema reconciliation (amends D-118/D-122): canonical `MKLicenseRecord` = WS-09 T2's shape; canonical SVG provenance schema = WS-08's; OFL subset-embedding RFN question recorded VERIFY-AT-SUBMISSION; emoji-in-arranged-group and locked-font-during-export cases defined.
- **D-228** — Entitlement UX closures (amends D-113/D-123): redundant-subscription cancellation prompt (new P0); mid-export revocation lets the in-flight export complete; trial not consumed by purchase, with copy precedence recorded; grace-over-trial rationale recorded; `pendingApproval` clarified as UI-only state.
- **D-229** — Gating enforcement closures (amends D-119): `premiumContentPresent` walk becomes presence-based (all nodes, ignoring isHidden/isLocked); `MKExportGate` free-tier preset check moves to engine level; stub types gain `#if DEBUG` + source-audit enforcement; `MKSyncService` gains an entitlement gate mirroring `MKExportGate`.
- **D-230** — MKStoreAPI protocol-seam placement (recovers orphaned ARCHITECTURE §2.1 decision, formerly mislabeled "D-200").
- **D-231** — Composition-root assembly `MakhtootAppServices` (recovers orphaned ARCHITECTURE §2.1 decision, formerly mislabeled "D-201").

**Doc-fix families (no new D-record; DF-1–DF-12 in RUN2_DISPOSITIONS.md).**
Citation and index fixes (Sweep A's three defects; DEPENDENCY_GRAPH spine
citations corrected; D-107 module-ownership wording reconciled). Checklist
additions: 11.06b (post-FD-01-sweep sync re-verification against a real
container and real product ids, gating 11.06), 1.08 (extended to promote
`Project`/`ProjectAsset` record types to production, not only analytics), 7.02b
(Guideline 2.3.1 dormant/hidden-feature analysis per D-225), V-13 (FD-03 CMYK
licensing outcome cross-referenced against the 10.04 print-claims copy).
Offline reconciliations (DF-7): a new WS-09 `MKCatalogManifestFetchService` task
plus a zero-manifest-ever empty state; one canonical offline-paywall string;
the 8-week retention window reconciled. Bidi terminology fix (DF-6a): "visual-
order pen" renamed to "logical reading order pen" at its three remaining sites
(Task 3, below) plus the ARCHITECTURE §9.4 title/pseudocode and T-PTH-2. New
letter-range cross-bidi-run selection rule (DF-6b) and neutral-punctuation-
frozen edge case (DF-6c). Test additions across the package (DF-8): numeric
mark-position fixtures at 30/90/180/270° with non-uniform scale (D-220), ligature
rotate-then-decompose and neighbor-overlap and style-only-recompose fixtures
(D-221), sustained-rollback and full 3-axis StoreKit-state fixtures (D-224/D-228),
hidden-premium-layer export-block and duplicate-as-expired-user gating tests
(D-229), `T-ARR-NOREFLOW-1` asserting `MKError.arrangedNodeCannotReshape`. Net
effect: **TEST_MATRIX now totals 214 tests (§20), up from 193**, including the
new T-ARR numeric family (T-ARR-1…3, T-ARR-LIG-STYLE, T-ARR-NOREFLOW-1).

---

## 4. RUN1_SELF_REVIEW claims falsified by Run 2

Recorded here per the standing instruction not to silently rewrite
RUN1_SELF_REVIEW.md. Each of the following claims, as originally stated in that
document, did not hold under Run-2 attack:

- **§3 item 3** — "flagged in the ARCHITECTURE risk register": no such
  ligature-fidelity risk-register entry existed (R2-3-5; closed by DF-12's new
  RSK-14 entry).
- **§3 item 2** — "covered by T-AR stack tests": mark geometry under base
  rotation/scale had no numeric test coverage, only manual-visual (R2-2-8;
  closed by D-220's numeric TEST_MATRIX fixtures).
- **§3 item 4** — "PRD edge cases specify expected behavior" for partial
  re-derivation of a mixed-direction line: false — partial re-derivation is
  impossible by design (INV-1/R-6.11), so no such behavior was ever specifiable
  (R2-4-1; the attack target itself was re-scoped in PLAN §4 item 4).
- **§3 item 9** — "synchronous journal flush on critical": understated the
  actual design, which performed a full-scene re-encode plus journal write at
  stage-3, not a journal-only flush; now genuinely journal-only per D-223.
- **§3 item 12** — "WS-10 keeps user-facing referral strings out of the shipped
  string catalog while the flag is off": false — referral strings were present
  in the shared `Localizable.xcstrings` catalog (R2-12-1; closed by D-225's
  compile-time exclusion and catalog move).
- **§3 item 7** — "TEST_MATRIX audit that no stub ships": no such automated
  audit existed (R2-7-6; closed by D-229's `#if DEBUG` + source-audit test).
- **§3 item 7** — "covered in PRD edge cases; verify [second-device sync
  enforcement]": the case was asserted as covered but was in fact
  unimplemented and untested (R2-7-5; closed by D-229's sync entitlement gate).

---

## 5. Founder decisions arising from Run 2

The only action items for the founder produced by this review:

1. **D-225 — referral compile-time exclusion.** CONFIRM: this changes the
   *mechanism* of the founder-locked D-124 (from a runtime feature flag to a
   compile-time `#if` exclusion from Release builds). FD-05's guideline-recheck
   gate before any future activation is unchanged. **CONFIRMED 2026-07-17.**
2. **D-201 — rotation UX.** Honored as originally recorded: rotated Live Text
   objects normalize to axis-aligned during editing and restore after. If
   in-place rotated editing is actually preferred, a superseding decision
   record is needed. **REAFFIRMED as recorded, 2026-07-17.**
3. **D-207 — remote CloudKit kill switch.** Honored as originally recorded: the
   analytics kill switch is a remote, serverless CloudKit public-DB record read
   in addition to the local consent toggle. If a local-only kill switch is
   preferred, a superseding decision record is needed. **REAFFIRMED as
   recorded, 2026-07-17.**
4. **D-222 — per-font fidelity gate.** Acknowledge: every newly bundled or
   newly verified font now requires the full manual Arabic fidelity-block
   verification workload (T-AR-31/32/33 + T-AR-36…38), not the previously
   reduced T-AR-58 sweep — a real, recurring cost increase per font.
   **ACKNOWLEDGED 2026-07-17.**
5. **Pre-existing FD-01…FD-07** remain unchanged and still open, except
   **FD-03 — RESOLVED 2026-07-19 (founder):** Apple Generic CMYK elected for v1
   (licensed profile deferred to v1.1 via the `ICCProfileStore` seam).

---

## 6. Run-3 handoff

Implementation agents must treat the following as blocking or load-bearing:

- **VERIFY-AT-IMPLEMENTATION spikes** (must resolve before the dependent task
  proceeds): CMYK `CGContext(data:space:CMYK)` bitmap-context support on iOS;
  the exact CGPDFContext OutputIntent auxiliary-key shape (dict vs array); the
  CKSyncEngine minimum-OS requirement (ARCHITECTURE §20.1); `MKMemoryLadder`'s
  Sendable/actor-isolation shape under Swift 6 strict concurrency.
- **D-220's formula is the single source of truth for mark math.** Any mark
  placement, detach, or re-attach code must implement
  `composition.affine ∘ base.affine ∘ translate(relativeOffset) ∘ mark.affine`
  exactly, with re-attach recomputing `relativeOffset` in base-local space —
  no alternate derivation.
- **WS-04's affine fit is canonical for ligature constituent placement**
  (uniform scale clamped [0.85,1.15], first/last edge-aligned, interior offsets
  from the fit) — ARCHITECTURE §7.5 prose is subordinate to it, not an
  alternate description.
- **Honest residuals that remain by design** (not defects, not to be
  "fixed" away in Run 3): translate/scale seam artifacts at cursive joins under
  manual movement; trial reset via reboot-then-clock-rollback (mitigated only
  within a single boot session by D-224); trial re-entry within the ≤7-day
  window after a subscribe-then-refund cycle (D-228, intended behavior).

---

## Traceability (BRIEF → this review's sections)

| BRIEF concern | Section of this review |
|---|---|
| Arabic contextual shaping during manual movement | §2 target 1, §3 D-222, §6 |
| Dynamic base-mark attachment | §2 target 2, §3 D-220, §6 |
| Ligature decomposition/recomposition | §2 target 3, §3 D-221, §4, §6 |
| Bidirectional runs / path text | §2 target 4, §3 DF-6a/b/c |
| Editable-SVG promise vs font licenses | §2 target 5, §3 D-227 |
| CMYK feasibility on iOS | §2 target 6, §3 D-226, §5 item 4→CMYK note in §6 |
| Free-tier entitlement enforcement | §2 target 7, §3 D-229, §4 |
| iCloud entitlement changes | §2 target 8, §3 doc-fix family (11.06b/1.08) |
| Memory-pressure autosave | §2 target 9, §3 D-223, §4 |
| Offline mode | §2 target 10, §3 DF-7 |
| Trial/lifetime/subscription precedence | §2 target 11, §3 D-224/D-228 |
| App Review risk of disabled referral code | §2 target 12, §3 D-225, §4, §5 item 1 |
| D-### citation integrity (standing instruction) | §2 Sweep A |
| Decision-propagation completeness (RUN1_SELF_REVIEW §8 closing note) | §2 Sweep B |
| Founder-facing open questions | §5 |
| Run-3 build readiness | §6 |
