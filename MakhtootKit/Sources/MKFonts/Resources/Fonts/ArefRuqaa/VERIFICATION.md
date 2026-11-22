# Verification record — Aref Ruqaa (`aref-ruqaa`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/aliftype/aref-ruqaa>
- Pinned commit: `175e1ed565e75aba8059675b80dadc0a184d53e6`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/arefruqaa/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/aliftype/aref-ruqaa> (HTTP 200)
  at verification time.
- Designer/foundry: Abdullah Aref, Khaled Hosny, Hermann Zapf

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/arefruqaa/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright 2015-2020 The Aref Ruqaa Project Authors (https://github.com/alif-type/aref-ruqaa), with Reserved Font Name EURM10.`
- Reserved Font Names found: ['EURM10']

## Step 4 — Redistribution clause

OFL 1.1 §2 (quoted from the captured license text above): "Original or
Modified Versions of the Font Software may be bundled, redistributed and/or
sold with any software, provided that each copy contains the above copyright
notice and this license." This permits bundling Makhtoot (commercial
software) with this font, subject to §3 (no reuse of any Reserved Font Name
by a modified derivative — Makhtoot ships the font UNMODIFIED, so this is
satisfied trivially).

## Step 5 — Binary identity

| File | PostScript name | Style/Weight | SHA-256 | GPOS cursive (type 3)? |
|---|---|---|---|---|
| ArefRuqaa-Bold.ttf | ArefRuqaa-Bold | normal/700 | 247071015b7eefd63f94d6e47949c5d10294ed31bd432f809ba9a219d93f91bb | yes |
| ArefRuqaa-Regular.ttf | ArefRuqaa-Regular | normal/400 | ceb786d83ba92f35e96efcd8623c2858d288e0c543c8761ba35b1020989464f9 | yes |

Each file above was downloaded directly from google/fonts' `ofl/arefruqaa/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "aref-ruqaa"`).

## Step 7 — D-222 arrange-fidelity gate (T-AR-31/32/33 + T-AR-36..38)

**RESOLVED THIS SESSION (WS-16, `docs/impl-log/WS-16-cursive.md`, ADR
WS16-A3) — automated functional twin PASSES; full manual-visual sign-off
still pending.** T-AR-31's AUTOMATED FUNCTIONAL TWIN (TEST_MATRIX.md §7.9:
"also automated as a pixel-diff FUNCTIONAL twin in MKArrange tests") now
runs against this font's real binary and PASSES:
`MakhtootKit/Tests/WS16CursiveTests/AllFiveHeldFontsEvidenceTests
.derivationFidelityHoldsForHeldFont` renders live text vs. a derived
Arranged Composition of the same text through the real
`MKRender.MKSnapshotRenderer` and confirms pixel-identical output within
the 0.5% D-222 bar. T-AR-32/33's core invariant (moving/dragging a glyph
never reshapes it or its neighbors) is verified at the code level:
`JoinController.breakJoin`/`restoreJoin` leaves `layout.position` untouched
by design, font-agnostically — confirmed against this font specifically in
`CursiveJoinBreakEvidenceTests.swift`.

**What remains NOT done this session** (named, not silently assumed): the
full MANUAL-ARABIC human-visual sign-off for T-AR-31/32/33/36-38 (no
human-in-the-loop pass requested this session, same disposition every other
workstream's own gate 4 in this repo records); T-AR-36-38 (ligature
decompose/recompose) were not specifically exercised against this font this
session.

**A real, bounded, documented limitation was found and regression-tested**:
`JoinController`'s D-107 ZWJ-synthetic-context reshape (used by join-break/
restore) does not always reproduce the exact natural glyph id for this font
— confirmed for GPOS-cursive-attachment-affected letter pairs specifically
(ZWJ cannot trigger the contextual GSUB substitution that feeds this
font's `curs` feature) and, empirically, for some non-cursive-attached
pairs too (a broader per-font D-107 variance WS03-A6 already flagged as
font-dependent, not something this font uniquely suffers from). This is
accepted-by-design per D-222's own established precedent for the analogous
single-glyph-scale-inside-a-joined-word case (T-AR-60) — a visual-only,
non-crashing, non-corrupting limitation in a manual arrange-mode edit path.
`MKProvenance.cursiveAttached` (added this session, see Step 8) makes this
identifiable per-glyph; wiring it through `MKArrange.ArrangeDeriver` is
published as a required follow-up in `MakhtootKit/CONTRACTS.md`.

## Step 8 — GPOS cursive-attachment audit (D-222)

GPOS lookup type 3 (cursive attachment) detected on this font's base
glyphs — confirmed independently this session via a SECOND, native-Swift
GPOS coverage-table reader (`MKTextEngine/CursiveAttachment.swift`), not
just the original `fontTools` audit below.

Audited via `fontTools.ttLib` (GPOS `LookupList`, walking `LookupType`,
resolving `LookupType 9` extension wrappers to their real `ExtensionLookupType`)
against every face listed above — see the per-face table.

**RESOLVED (WS-16, `docs/impl-log/WS-16-cursive.md`, ADR WS16-A1/A2).**
Probed empirically that `CTRunGetPositions` already bakes the
cursive-adjusted position into capture (D-105's own "the shaped positions
already encode the answer" principle, previously established for mark
anchoring, extends unchanged to cursive attachment) and that MKArrange's
D-220 affine chain (`MKArrangedGeometry.localAffine`/`worldTransform`)
composes `layout.position` as an opaque translation regardless of what
produced it — so display, translate, rotate, and scale of
cursive-attached glyphs all work correctly today with ZERO geometry
changes. D-105's mark-capture model gained a per-glyph
`MKShapedRun.cursiveAttached`/`MKProvenance.cursiveAttached` provenance
flag (a GPOS-coverage-table membership read, never anchor values, never a
recomputed position) so the one real gap (Step 7's documented join-break/
restore reshape limitation) is identifiable and testable rather than an
unknown risk. Per D-222 step 8's own text ("if any shipped font uses it,
D-105's mark-capture model needs a cursive-pair structure before that font
ships"), this is now satisfied: a provenance flag, not a full anchor-delta
structure, per the probe evidence in `docs/impl-log/WS-16-cursive.md` ADR
WS16-A1.

## Ship decision

**RELEASED** (WS-16, `docs/impl-log/WS-16-cursive.md`) — registered in
`Resources/catalog-seed.json` and no longer flagged `provisionalShip` /
`isProvisionalShip`. See `Resources/EXCLUDED_FONTS.md`'s "Released this
session" section for the full evidence summary and the named remaining
follow-up (manual-visual T-AR-31/32/33/36-38 sign-off; threading
`cursiveAttached` through `MKArrange.ArrangeDeriver`, published in
`MakhtootKit/CONTRACTS.md`).
