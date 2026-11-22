# Batch 0 · Agent 0.5 — Decision-document amendment (D-300…D-325)

**Status:** complete. **Date:** 2026-07-30. **Scope:** documentation only — no Swift source,
no `android/` code, touched.

## What was ported

Not a code port — a decision-register transcription per `ANDROID_TASK_PACKETS/BATCH-0.md`
(lines 381–473) and `ANDROID_SPINE.md` §1/§2 (frozen, verbatim-in-content source).

1. **`DECISIONS_LOG.md`** — appended a new "Part II — Android platform decisions
   (D-300…D-325)" section after the existing Part I close (`D-1xx`–`D-231`, "Amended index",
   and the "*End of DECISIONS_LOG.md — 54 records...*" tally line). All 26 records
   (`D-300`–`D-325`) written in the file's existing per-record template (Status/Date/Owner/
   Context/Decision/Alternatives considered/Consequences/Migration impact/Confidence/
   Dependencies/Validation trigger — the 2026-07-20 house-standard shape, since these are new
   entries written from that date forward). Append-only via `cat >>`: verified byte-identical
   preservation of every line before the append point. A new "Amended index (Android
   additions)" summary table and closing tally line were added at the very end.
2. **`FOUNDATION.md`** — edited only within the agent's owned scope (§1, §2, §10, new §13):
   - §1: one-line amendment pointers added directly after the D-100 and D-101 bullets
     ("Amended for Android by D-300... D-100 remains authoritative for iOS" /
     "Amended for Android only by D-304's third-party carve-out... D-101 ... unamended and
     fully in force for iOS"). D-100/D-101's own bullet text is otherwise untouched.
   - New §2.1 "Android module map" — the 18-module table from `ANDROID_SPINE.md` §3.1,
     inserted as a clearly separated subsection immediately after the existing iOS module
     table (§2). The iOS table is untouched.
   - New §10.1 "Android founder decisions (FDA-01…FDA-08)" — appended after the existing
     FD-01…FD-07 table, same column shape (ID / Decision / Blocking).
   - New §13 "Android platform (D-300…D-325, added 2026-07-30)" — one paragraph per decision
     cluster (platform/layout, shaping/rendering, persistence/interchange/sync, store/trial/
     fonts/colour/export, design-system/localisation/accessibility/analytics/referral/
     distribution, verification), at the same density as §1–§9, cross-referencing every
     `D-3xx` id at least once and pointing to `DECISIONS_LOG.md` for full rationale rather
     than duplicating it. §3–§9, §11, §12 were not touched.
3. **`CLAUDE.md`** — edited only the two named bullets/sections:
   - "Platform and scope": replaced "**iPhone and iPad only.** No Android port, and none is
     planned for v1." with a bullet stating "iPhone and iPad, and Android" as supported
     platforms, the 2026-07-30 authorization date, and pointers to `D-300`–`D-325` /
     `FOUNDATION.md` §13 / `ANDROID_SPINE.md`. The "Arabic-only at launch" bullet is
     byte-identical to before. The "No backend" bullet was left untouched (out of the
     packet's named scope; Drive sync and Play Billing are both no-backend-compliant per
     D-310/D-311, so nothing in that bullet is contradicted).
   - "Never": added two new prohibitions rather than removing anything — a Class-B shaping
     delta can never be registered in `android/SHAPING_DELTAS.md` regardless of who proposes
     it (D-325), and a release AAB must never ship with the referral module/source
     set/strings present (D-321, mirrors D-225). The existing five bullets are unchanged in
     wording; "Localize into other scripts in v1" was deliberately left untouched per the
     packet (Arabic-only-UI is unchanged by this port — Android is a new platform for the
     same Arabic-only product, not a new localization).
   - "Architecture", "Quality bar", "Decision log", "Identity", "Mandatory read order"
     sections are byte-identical to before.
4. **`PROJECT_DESCRIPTION.md`** — added one status note inside the existing Overview
   paragraph, replacing the single sentence "There is no Android port and none is planned for
   v1." (now false) with a short, clearly-marked note: authorization date, pointer to
   `ANDROID_SPINE.md` and the `D-3xx` register, and an explicit "not yet started as of this
   note" status so the note does not overclaim progress. No other positioning content in the
   document was touched (Product vision, Target user, Product principles, MVP feature
   priorities, Current feature surface, Monetization direction, Technical direction, Launch
   direction, Summary — all still describe the iOS app only, correctly, since none of them
   claimed "no Android port" and none needed correction).

## Verification performed

- **Post-stall re-verification.** The coordinator flagged that an infrastructure stall may
  have interrupted the original run mid-write; before continuing, both already-written files
  were independently re-checked rather than trusted: `DECISIONS_LOG.md`'s 26 `## D-3xx`
  headers were re-grepped for sequence/gaps/duplicates (clean), and `FOUNDATION.md`'s tail
  was re-read to confirm §13 ends cleanly at its "Verification." paragraph, not mid-table.
  This surfaced one real gap: §13's body referenced D-300–D-303 and D-305–D-325 but not
  D-304 (the D-101 carve-out was only pointed to from §1, not from §13 itself), which failed
  the acceptance criterion "`FOUNDATION.md` §13 ... cross-references every `D-3xx` id at
  least once." Fixed by adding one sentence on the D-304 carve-out to §13's "Platform and
  layout" paragraph; re-verified all 26 ids (`D-300`–`D-325`) now present in §13 by script.
- `grep -c '^## D-3' DECISIONS_LOG.md` → **26** (matches acceptance criterion).
- `grep -n '^## D-3[0-9][0-9]' DECISIONS_LOG.md` → D-300 through D-325 in strict sequence,
  no gaps, no duplicate ids (spot-checked with `sort | uniq -c`).
- Pre-existing `DECISIONS_LOG.md` content (`D-1xx`–`D-231`, "Amended index", closing tally)
  preserved byte-identically — the addition was a pure `cat >>` append, never an in-place
  edit, so nothing before the append point could have changed.
- `grep -n 'No Android port' CLAUDE.md` → no matches (acceptance criterion met).
- `FOUNDATION.md` §13 confirmed present and complete through its closing "Verification."
  paragraph (not truncated) — re-checked after an infrastructure stall interrupted the
  original run, per the coordinator's follow-up instruction.
- `grep -n -i 'android' PROJECT_DESCRIPTION.md` → only the one added note cluster; no
  remaining stale "no Android port" claim anywhere else in the document.

## Confirmation of pre-run state (per packet task 1 verification instruction)

`DECISIONS_LOG.md` ran to `D-231` before this agent's edit (`grep -n '^## D-231'` located the
record; 59 total `## D-1xx`/`## D-2xx` headers pre-edit), confirming the spine's claim that
`D-300` is collision-free. `android/docs/impl-log/` existed and was empty before this write,
confirming no other Batch 0 agent had claimed this path.

## Deviations from the spine/packet

None load-bearing. Minor scope judgment calls, both within the packet's stated authority
("if anything appears to conflict... write it as-is and note the conflict... under a
`> **Writer note:**` blockquote"):

> **Writer note:** The packet's Owns list for `FOUNDATION.md` names only §1, §2, §10, plus a
> new §13. `ANDROID_SPINE.md`'s hard rules explicitly call out that D-303 replaces D-103 as
> the Android shaping source of truth — but D-103 lives in `FOUNDATION.md` §3, outside this
> agent's owned scope. Rather than editing §3 (out of scope) or leaving the D-303/D-103
> relationship undocumented in `FOUNDATION.md`, the asymmetry is stated fully in new §13's
> "Shaping and rendering" paragraph ("replaces Core Text **on Android only** — D-103 stays
> the shaping source of truth for iOS, unedited"). §3/D-103 itself was not touched. This is a
> scope-boundary judgment call, not a contradiction between the spine and a locked D-1xx.

> **Writer note:** `PROJECT_DESCRIPTION.md`'s packet-specified target was "add one short
> status note" without naming an exact insertion point. The single existing sentence "There
> is no Android port and none is planned for v1." (Overview section) was factually
> superseded by this run and was replaced in place with the status note, rather than adding
> the note elsewhere and leaving the false sentence standing. This mirrors how `CLAUDE.md`'s
> parallel false statement was handled and was judged necessary for `PROJECT_DESCRIPTION.md`
> to stop contradicting `FOUNDATION.md`/`DECISIONS_LOG.md`, consistent with `CLAUDE.md`'s own
> "never treat a document that contradicts `FOUNDATION.md` as correct" rule.

No place was found where the spine's `D-3xx` text conflicted with an existing locked `D-1xx`
in a way that could not be resolved by amendment (D-300→D-100, D-304→D-101, D-303→D-103 all
resolved cleanly as Android-only amendments/carve-outs/replacements, exactly as the spine
specifies, with the original iOS-authoritative records left byte-identical).

## Blockers

None. This agent's scope is complete and does not block on any founder input, credential, or
external dependency (per `ANDROID_SPINE.md` §7, Batch 0 requires none).

## Stub count delta

N/A — this agent ports no code and touches no stub. `Scripts/android/stub-count.sh` does not
exist yet (created in Batch 1) and this agent's output does not affect it.
