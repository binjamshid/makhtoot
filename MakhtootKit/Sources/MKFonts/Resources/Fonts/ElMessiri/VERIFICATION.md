# Verification record — El Messiri (`el-messiri`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/Gue3bara/El-Messiri>
- Pinned commit: `553b98d8e374318694b50862849af666268fd278`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/elmessiri/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/Gue3bara/El-Messiri> (HTTP 200)
  at verification time.
- Designer/foundry: Mohamed Gaber, Jovanny Lemonad

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/elmessiri/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright 2015 The El Messiri Project Authors (https://github.com/Gue3bara/El-Messiri)`
- Reserved Font Names found: (none found in license header)

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
| ElMessiri[wght].ttf | ElMessiri-Regular | normal/400 | 5d58d5259d2accccba39cffe12e1226e88b6afc5150e3605eb2a9c2fe06ccab0 | no |

Each file above was downloaded directly from google/fonts' `ofl/elmessiri/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "el-messiri"`).

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
