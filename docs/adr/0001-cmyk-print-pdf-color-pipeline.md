# ADR-0001 — CMYK print-PDF color pipeline: ICC conversion at export, Apple Generic CMYK fallback

- Status: Accepted (**retroactive** — back-recorded 2026-07-20 from an already-made
  decision; see note at the end)
- Date: 2026-07-17 (original decision date, D-117); amended 2026-07-17 (D-226)
- Supersedes: none
- DECISIONS_LOG.md refs: D-117, D-118, D-226, FD-03

## Context

The market study assessed print/PDF-X CMYK support as Medium-Low feasibility and
recommended deferring true CMYK to v1.1/v2, shipping RGB with a disclaimer instead.
Founder Q75 overrode that recommendation and locked True CMYK for v1: premium print
export must be vector/300-DPI with ICC-profile-aware CMYK output. The engineering
question this ADR covers is not *whether* (founder-locked) but *how to contain the
scope* so the requirement ships without pulling in a full desktop-class color-managed
suite (soft-proofing, gamut warnings, spot colors, per-object color spaces) — and what
happens if the one genuinely open piece, the bundled ICC profile itself, doesn't land.

## Decision

One working space everywhere (extended-sRGB/P3 on screen); exactly one conversion
point at export — vector paths/text and the whole raster image convert to CMYK
through an ICC profile loaded via `CGColorSpace(iccData:)`, relative colorimetric
intent, with the profile embedded as a PDF OutputIntent. No CMYK values are authored,
stored, or displayed anywhere else in the app. Scope is explicitly bounded: no
in-app soft-proofing, no PDF/X-1a certification claim (output is described as "CMYK
PDF with embedded OutputIntent," never marketed as PDF/X unless independently
verified), no spot colors, no per-object color spaces, no CMYK pickers.

## Pre-registered no-go trigger

**The bundled ICC profile itself (FD-03) is the gated piece.** Candidate press
profiles (eciRGB/ISO-Coated-v2-class) have a documented, unresolved redistribution-
licensing question (BRIEF research gap). The no-go trigger, as recorded at decision
time: if FD-03 does not resolve with a licensed, redistributable profile, the app
ships v1 on the fallback below **permanently for v1** — not as a temporary stand-in
while licensing is chased indefinitely. No PDF/X-adjacent marketing claim is made in
either case.

## Reserved fallback budget

Already built, not a future task: Apple's built-in Generic CMYK
(`CGColorSpace(name: .genericCMYK)`) is the documented, always-available fallback,
explicitly disclosed in the export UI as lower print fidelity ("قد تختلف الألوان
المطبوعة عن ألوان الشاشة" — printed colors may differ from screen colors). The
fallback budget is therefore ~zero incremental engineering: it is the same
conversion code path with a different profile source, already implemented and
disclosed rather than deferred to whenever FD-03 lands.

## Numeric re-evaluation gate

Per D-226 (the execution-tightening amendment): two `VERIFY-AT-IMPLEMENTATION`
spikes block WS-08 task 12 — (a) iOS bitmap-context CMYK support
(`CGContext(data:space:CMYK)`), (b) the exact `CGPDFContext` OutputIntent
auxiliary-key shape. Both must resolve, plus the intent-discriminator fixture
(#00FF00 relative-colorimetric vs. perceptual divergence test) must pass, before
WS-08 task 12 is considered closed. FD-03 itself is re-evaluated at the Print-PDF
export QA phase (P10): if unresolved by P10 exit, the ADR's own no-go trigger fires
and v1 ships on Apple Generic CMYK, full stop for that release — not an open-ended
"keep waiting on licensing" state.

## Consequences

Positive: the founder-locked requirement ships with a single, auditable conversion
point, and the profile question is fully isolated from the rest of the pipeline —
nothing else blocks on FD-03. Negative: on-screen colors will not match press output
exactly and v1 has no in-app way to preview that; out-of-gamut sRGB colors clip under
relative-colorimetric conversion with no warning UI; physical print verification is
external-tool-gated (littleCMS `transicc` / Argyll `xicclu`), not an in-app feature,
so every export-path change carries a manual verification cost.

## Validation trigger

WS-08 task 12's two `VERIFY-AT-IMPLEMENTATION` spikes resolved; intent-discriminator
fixture green; FD-03 resolved (licensed profile bundled) **or** the no-go trigger
fires and Apple Generic CMYK ships as the permanent v1 profile; physical print proof
reviewed by founder before any print-accuracy marketing claim.

---

**Retroactive-record note:** this ADR did not originate the decision above — D-117
and its D-226 amendment in `DECISIONS_LOG.md` did, on 2026-07-17, before this `docs/adr/`
directory existed. This file is a faithful back-record, written during the
2026-07-20 portfolio house-standard pass, structured into the gated-ADR shape
(no-go trigger / fallback budget / re-evaluation gate) that the original D-117/D-226
prose already contains in substance but not in this dedicated format. No fact here
was invented; every claim traces to the cited D-117/D-226/FD-03 text.
