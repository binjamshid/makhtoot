# Verification record — Lateef (`lateef`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/silnrsi/font-lateef>
- Pinned commit: `d682ea7cc0305b592058255167c83d059aa640fa`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/lateef/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/silnrsi/font-lateef> (HTTP 200)
  at verification time.
- Designer/foundry: SIL International

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/lateef/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright (c) 1994-2025, SIL Global (https://www.sil.org/), with`
- Reserved Font Names found: ['Lateef']

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
| Lateef-Bold.ttf | Lateef-Bold | normal/700 | eee405eeb4e81491b0b659fb40dc016765292022d74406c616f72501e160afe2 | no |
| Lateef-ExtraBold.ttf | Lateef-ExtraBold | normal/800 | ee6406b63af32993054b1f7e2d6ff0fd7c91c409b0d4818bb1d686f709f0cdff | no |
| Lateef-ExtraLight.ttf | Lateef-ExtraLight | normal/200 | d22920471ea9305e50b18674a285975cd9856059dd1dccb088becb101090c328 | no |
| Lateef-Light.ttf | Lateef-Light | normal/300 | f5c18f8c66cc30a61cc009f86b31aeecc4d81804fe4ef847cef4d2288a1e6723 | no |
| Lateef-Medium.ttf | Lateef-Medium | normal/500 | b08e71723c6bdcc7855a1384ced2cc459f0fbbc65dfa0dfa0a94b9983d484ef1 | no |
| Lateef-Regular.ttf | Lateef-Regular | normal/400 | fcbd9e0227a4d7238880defa5fd74c012d69351150709e559a8577446145c2fc | no |
| Lateef-SemiBold.ttf | Lateef-SemiBold | normal/600 | ac0ba34269c19062340d942c5ad4ecc41ab8b9d21df92973372a7e1d7a421ff2 | no |

Each file above was downloaded directly from google/fonts' `ofl/lateef/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "lateef"`).

## Step 7 — D-222 arrange-fidelity gate (T-AR-31/32/33 + T-AR-36..38)

**BLOCKED — not executed this run.** These are MANUAL-ARABIC manual-visual
tests that exercise Arrange Mode (`MKArrange`, owned by WS-04). In this repo
snapshot `Sources/MKArrange/MKArrangePlaceholder.swift` is the only file in
that target — there is no Arrange Mode UI to run T-AR-31/32/33/36-38 against.
This is logged as a cross-workstream blocking dependency (see
`docs/impl-log/WS-09.md`), not asserted as passing.

## Step 8 — GPOS cursive-attachment audit (D-222)

No GPOS lookup type 3 (cursive attachment) found on base glyphs.

Audited via `fontTools.ttLib` (GPOS `LookupList`, walking `LookupType`,
resolving `LookupType 9` extension wrappers to their real `ExtensionLookupType`)
against every face listed above — see the per-face table.

## Ship decision

In default catalog (`catalog-seed.json`). Step 7 (arrange-fidelity) remains BLOCKED pending WS-04 — re-verify when Arrange Mode ships.
