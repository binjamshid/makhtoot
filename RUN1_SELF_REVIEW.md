# Makhtoot (مخطوط) — RUN1_SELF_REVIEW.md

> Private source materials cited here are omitted from this source edition. The checked-in decisions and specifications describe the project.
## Mandatory pre-handoff self-review (Run 1 → Run 2)

Date: 2026-07-17

This document records the mandated self-review: verification that every locked
requirement appears in the PRD, architecture, plan, and relevant task packet, the
stress-test of the twelve mandated risk areas, and the reconciliation actions taken
after the deliverable authors reported tensions.

---

## 1. Package inventory (as shipped to Run 2)

| File | Bytes | Role |
|---|---|---|
| `_input/BRIEF.md` | 11,644 | Locked-requirements digest (founder answers override market study; 2 overrides recorded) |
| `FOUNDATION.md` | 23,377 | Decision backbone, module map, glossary, canonical outlines (amended twice in self-review — §5 below) |
| `PLAN.md` | 66,851 | Phases P0–P15, gates, milestones, Run-2 attack list, Run-3 execution model |
| `PRD.md` | 116,195 | 312 requirements, 13 flows, 27-row gating matrix, 60-item edge-case compendium |
| `ARCHITECTURE.md` | 182,862 | 25 sections, 18 invariants (INV-1..18), Swift sketches, scene JSON Schema, risk register |
| `FILE_MAP.md` | 109,125 | 385 files across app target + 16 package targets, plist/entitlement tables |
| `DEPENDENCY_GRAPH.md` | 27,587 | 2 Mermaid graphs, per-edge rationale, parallelization map, stub strategy S1–S5 |
| `TEST_MATRIX.md` | 105,616 | 193 tests; 61-item manual Arabic checklist; D-115 budgets encoded verbatim |
| `APP_STORE_CHECKLIST.md` | 66,792 | 105 items (81 [AGENT]/24 [FOUNDER]), Arabic metadata drafts, V-01..V-12 verify list |
| `DECISIONS_LOG.md` | 158,056 | 54 ADR records (27 foundation, 7 founder-pending, 20 derived incl. D-215–219 amendments) |
| `AGENT_TASK_PACKETS/WS-01..15` | 313,170 | 15 self-contained implementation packets, 11-section format (§11 Traceability added in execution pass), stub contracts |
| **Total** | **~1.18 MB** | |

Structural checks performed: all 15 packet filenames match FOUNDATION §11 exactly;
every deliverable ends with a Traceability section — true for all 24 deliverables as of
the execution pass (this was false for the 15 packets when this document was first
written; see §8); "Masoon" appears only inside prohibition statements (5 occurrences,
all "never Masoon" — corrected from an originally reported 3); bundle id appears only as
`com.example.makhtoot`, always PLACEHOLDER/FD-01-marked (50 occurrences package-wide —
the originally reported "77 marker occurrences" was unreproducible); cross-grep confirms
every stress-area term appears in every document that must carry it
(evidence table retained in review notes: Arrange/ZWJ/CMYK/OutputIntent/conflict-copy/
billing-retry/referral/memory APIs/fixtures لا·الله present in PRD, ARCHITECTURE, PLAN,
TEST_MATRIX, DECISIONS_LOG, and packets).

## 2. Locked-requirement coverage verification

Method: each deliverable carries an authored BRIEF→ID traceability table (PRD → R-ids,
ARCHITECTURE → sections+INV, PLAN → phases, TEST_MATRIX → T-ids, DECISIONS_LOG → D-ids,
FILE_MAP → files, APP_STORE_CHECKLIST → sections, each WS packet → tasks). Spot audit
of every BRIEF top-level bullet against those tables found no uncovered locked
requirement. Notable confirmations:

- Arabic-only RTL UI, iOS 18, universal adaptive layouts: PRD §1–2, WS-13, FILE_MAP ar.lproj-only.
- No templates / no accessibility scope / no Qur'anic content or special handling: PRD §23 exclusions + edge cases; DECISIONS_LOG D-209 records the market-study divergence.
- All four font mechanisms: PRD §12, ARCHITECTURE §17, WS-09 (incl. per-font verification protocol; KFGQPC prohibited via FILE_MAP `_PROHIBITED.md`).
- Export matrix incl. free 2 MP JPEG/PDF, premium PNG/SVG/print-CMYK-PDF, presets, custom dims: PRD §13, ARCHITECTURE §16, WS-08, TEST_MATRIX §export fidelity.
- StoreKit completeness (status/restore/precedence/grace/retry/messaging/testing + verification decision): PRD §15, ARCHITECTURE §18–19, WS-10, TEST_MATRIX §12 (20 scenarios) + T-DST-3 (§15) = 21 STOREKIT-gate total, D-113/D-123.
- Referral architecture flag-OFF with risk memo + removal: ARCHITECTURE §19, WS-10, APP_STORE_CHECKLIST §7, D-124/D-212, PRD §16.
- Memory/no-artificial-caps/degradation/no-loss recovery: D-115/D-116/D-218, ARCHITECTURE §12, WS-07, TEST_MATRIX §memory.
- Offline completeness + only-3-network-uses: PRD §19, INV network-confinement, TEST_MATRIX offline audit tests.
- Analytics opt-in anonymous aggregated font usage only: D-125, WS-12, APP_STORE_CHECKLIST §5 privacy labels.

## 3. Twelve-area stress-test

For each mandated area: the design position, where it lives, and the residual risk Run 2
should attack.

1. **Arabic contextual shaping during manual movement** — Movement never reshapes:
   Arrange derivation freezes glyph identities (INV no-implicit-reshape); shaping only
   re-runs on explicit revert-to-text or form selection. Residual risk: cluster→glyph
   mapping ambiguity in fonts with complex GSUB chains; Run 2 should attack the D-105
   mapping algorithm against Amiri's discretionary ligature set (TEST_MATRIX T-AR
   preservation block exists; fixtures may need widening).
2. **Dynamic base-mark attachment** — Marks record base-relative offsets at derivation;
   follow-base is a transform parent relationship, detach is explicit (D-106, PRD §7).
   Residual: multi-mark stacks (shadda+vowel) vertical-ordering fidelity after base
   rotation — covered by T-AR stack tests; geometry math in ARCHITECTURE §6 needs Run-2
   scrutiny for rotated bases.
3. **Ligature decomposition/recomposition** — D-108 fidelity-offset design; recompose
   restores stored original glyph exactly (round-trip test exists). Residual: fidelity
   placement for 3+-letter discretionary ligatures is heuristic; flagged in the
   ARCHITECTURE risk register.
4. **Bidirectional runs** — Core Text bidi is preserved via per-run capture +
   `bidiLevel`/visual-index retention (D-109); arranged nodes never re-order. Residual:
   partial re-derivation after editing only the Latin sub-run of a mixed line —
   PLAN's Run-2 attack list item; PRD edge cases specify expected behavior.
5. **Editable-SVG promise vs font licenses** — Live Text exports as `<text>` with
   `@font-face` embedding only for OFL-verified fonts; every outline fallback is
   per-feature documented (D-118, INV no-silent-flattening); user-imported and
   non-embeddable fonts always outline with provenance attributes. Position: the
   promise "editable wherever feasible" is honestly scoped in PRD §13. Residual: none
   architectural; per-font embedding-clause capture is part of WS-09 verification.
6. **CMYK feasibility on iOS** — Founder-locked (Q75) against market-study deferral
   advice; recorded divergence (D-117). Scope contained: single conversion point,
   ICC-profile PDF OutputIntent, no soft-proofing, no PDF/X claims, external-tool
   verification in TEST_MATRIX, FD-03 profile licensing gate with Apple Generic CMYK
   fallback. Residual: fidelity expectations — Run 2 should pressure the verification
   protocol's pass thresholds.
7. **Free-tier entitlement enforcement** — Central `MKEntitlementResolver`, gating at
   both capability and content level ("premium content present" flag), export-time
   re-check; always-premium stub is flipped and removed at P11 (stub S1) with a
   TEST_MATRIX audit that no stub ships. Residual: enforcement bypass via document
   editing on a second free device after sync — covered in PRD edge cases; verify in
   Run 2.
8. **iCloud entitlement changes** — Sync is premium-gated at the engine entry;
   expiry stops push/pull but never deletes local data; account switch resets sync
   state without data loss (WS-11 tasks + T-sync tests).
9. **Memory-pressure autosave** — Ladder D-116 with save-before-degrade invariant
   (INV-17), synchronous journal flush on critical, relaunch recovery test (kill
   mid-edit) in TEST_MATRIX. Threshold ambiguity found and fixed (D-218).
10. **Offline mode** — Whole product offline; network confined to MKFonts/MKSync/
    MKAnalytics by invariant; airplane-mode full-editor tests exist.
11. **Trial/lifetime/subscription precedence** — Single precedence chain (D-113)
    restated identically in PRD §15, ARCHITECTURE §18, WS-10, TEST_MATRIX StoreKit
    scenarios; trial persistence honesty limits recorded (D-211) rather than
    overclaimed.
12. **App Review risk of disabled referral code** — Ships compiled but inert
    (flag OFF, D-124); risk memo + precedent citations in APP_STORE_CHECKLIST §7;
    reactivation hard-gated on FD-05 + guideline recheck; removal procedure documented.
    Residual: reviewer discovery of dormant referral strings — WS-10 keeps user-facing
    referral strings out of the shipped string catalog while the flag is off.

## 4. Tensions reported by authors → dispositions

| # | Tension | Disposition |
|---|---|---|
| 1 | $3/$30/$90 are not exact Apple tiers | **D-216** — nearest tiers $2.99/$29.99/$89.99; exact-price availability VERIFY-AT-SUBMISSION |
| 2 | Free placed raster images unspecified (PRD TN-1) | **D-217** — all raster/SVG/PDF import premium per founder Q32 "images" gate; founder-editable |
| 3 | Pattern-background gating unstated | **D-215** — premium, per Q34 solid-colors-only free tier |
| 4 | D-115 "<60 %" vs D-116 70 % trigger | **D-218** + FOUNDATION D-115 amended: 60 % = design target, 70 % = first ladder trigger; cold-launch <1 s gate added |
| 5 | Deprecated `CTFontManagerRegisterFontsForURL` spelling | **D-219** — implement with `CTFontManagerRegisterFontURLs(.process)` |
| 6 | D-112 "search text" could leak scene content into SwiftData | FOUNDATION D-112 amended: titles + layer names only, never scene text |
| 7 | MKTextEngine → MKFonts vs P3-before-P9 ordering | Accepted resolution: `MKFontProviding` fixture slice (DEPENDENCY_GRAPH stub S2); Run 2 to confirm |
| 8 | D-121 HTTPS-font-download compliance stated too firmly | Carried as VERIFY-AT-SUBMISSION everywhere (V-list); bundle-fallback is the mitigation |
| 9 | D-124 honor-code attribution can't verify "qualifying paid action" | Folded into FD-05: any activation requires attribution rework; referral stays OFF in v1 |
| 10 | Market-study §8/§14 recommends intro-offer trial + server-side validation | Decided positions D-123/D-113 override; divergence documented for reviewers (checklist §3) and as extension seam |

Dispositions D-215–D-219 were recorded in DECISIONS_LOG when this document was first
written but not propagated to the operative deliverables (PRD/PLAN/ARCHITECTURE/
FILE_MAP/DEPENDENCY_GRAPH/APP_STORE_CHECKLIST/packets); propagation was completed in
the execution pass — see §8.

No unresolved contradictions remain between FOUNDATION and any deliverable.

## 5. FOUNDATION amendments made during self-review

1. D-115: added cold-launch <1 s budget; clarified 60 % target vs 70 % ladder trigger.
2. D-112: narrowed SwiftData "search text" to titles + layer names.
Both are reflected in DECISIONS_LOG amendments (D-218, and a note under tension #6).

## 6. Genuine Founder Decisions (the only open blockers)

FD-01 bundle id/team/repo · FD-02 baseline aesthetic approval ("حبر ورق") · FD-03 CMYK
ICC profile licensing · FD-04 premium-font hosting vs bundle fallback · FD-05 referral
activation (default: never in v1) · FD-06 Family Sharing (irreversible; checklist
recommends OFF at launch) · FD-07 commercial foundry budget (v1.1+). Everything else is
decided with recorded rationale.

## 7. Handoff statement to Run 2

The package is internally consistent, traceable, and execution-ready. Attack-priority
list is in PLAN.md (Run-2 handoff section, 12 ordered targets). The areas Run 1 itself
trusts least: (a) D-105 cluster mapping against complex-GSUB fonts, (b) fidelity
placement for multi-letter ligature decomposition, (c) CMYK verification thresholds,
(d) trial-persistence limits vs founder expectations, (e) the unverified-by-citation
compliance claims consolidated in APP_STORE_CHECKLIST's V-01..V-12, (f) propagation
completeness of late reconciliation decisions — one class-instance found and fixed in
§8; sweep for others.

---

## 8. Execution addendum (2026-07-17, post-review verification pass)

The execution pass re-verified every claim in this document against the shipped
package. Corrections appear above. The propagation gaps found and fixed are
recorded here.

**Count corrections**
- Byte counts across §1 inventory table updated to current file sizes (FOUNDATION
  23,377 · PLAN 66,851 · PRD 116,195 · ARCHITECTURE 182,862 · FILE_MAP 109,125 ·
  DEPENDENCY_GRAPH 27,587 · TEST_MATRIX 105,616 · APP_STORE_CHECKLIST 66,792 ·
  DECISIONS_LOG 158,056 · AGENT_TASK_PACKETS 313,170 · total ~1.18 MB).
- "Masoon" occurrence count corrected 3 → 5 (all inside prohibition statements).
- Bundle-id marker claim corrected: `com.example.makhtoot` appears 50 times, always
  PLACEHOLDER/FD-01-marked — the original "77 marker occurrences" figure was
  unreproducible.
- "Every deliverable ends with a Traceability section" corrected from an aspirational
  claim to a verified one — false for the 15 packets at original review time, true now
  that §11 was added to each (see below).
- PRD gating matrix corrected 26 → 27 rows (G10a pattern-backgrounds row added per
  D-215).
- PRD edge-case compendium corrected "~50-item" → 60 items (R-21.1–R-21.68, with
  reserved gaps).
- PRD requirement count corrected 311+ → 312 (R-22.18 added; see D-218 below).
- TEST_MATRIX StoreKit scenario count corrected: §12 holds 20 scenarios, not 21; the
  21st is T-DST-3 in §15. Combined STOREKIT-gate total is still 21.

**D-219 propagated** — deprecated `CTFontManagerRegisterFontsForURL` replaced with
`CTFontManagerRegisterFontURLs` in FOUNDATION, PRD, PLAN, ARCHITECTURE, FILE_MAP (×2),
DEPENDENCY_GRAPH, APP_STORE_CHECKLIST, WS-09 (×3). Historical records (DECISIONS_LOG
D-122, market study) intentionally left unchanged.

**D-216 propagated** — operative prices now $2.99/$29.99/$89.99 in PRD (R-14.10,
R-14.12 example copy), PLAN (×2), ARCHITECTURE product table, TEST_MATRIX §12 preamble,
FILE_MAP PaywallViewModel row, WS-10 mission/locked-decisions. BRIEF-verbatim
traceability columns and "never hardcode $3" prohibitions intentionally retained.

**D-215 reconciled — genuine contradiction found and fixed.** PRD had granted pattern
backgrounds to the free tier (old G10, R-4.20, R-11.4, R-14.6), contradicting D-215.
Fixed via a G10/G10a split with premium gating on G10a. WS-14's stale "D-2xx draft"
pointers now cite D-215 directly.

**D-217** — PRD TN-1/TN-2 tension notes updated from "not resolved" to resolved
(D-217 / folded into FD-05).

**D-218 encoded** — TEST_MATRIX T-PRF-13 promoted from supporting to Gate PERF
(<1 s A15-class, ≤2 s DEV-A12 supporting); §20 PERF gate count 8 → 9; new PRD R-22.18
cold-launch NFR added.

**T-MEM-2** heading tag corrected FUNCTIONAL-supporting → MANUAL-ARABIC (it was already
counted there by §20 and the P14 exit table — only the heading tag was wrong).

**15 packet Traceability sections (§11) added** — 8–15 rows each, mapping BRIEF bullets
to task IDs. Packet format is now 11-section, not 10.

**Closing note for Run 2:** the defect class found here — decisions recorded in
DECISIONS_LOG but not propagated to the operative documents — should be added to the
Run-2 attack list. Verify no remaining decision is cited only in DECISIONS_LOG.

## 9. Run-2 outcome pointer

Run 2 executed 2026-07-17. Several §3 claims above did not survive adversarial
attack and are falsified in detail — see `RUN2_REVIEW.md` §4. Dispositions are
recorded as DECISIONS_LOG D-220–D-231. Run 2 amended the package in place. The original
self-assessment remains recorded above.
