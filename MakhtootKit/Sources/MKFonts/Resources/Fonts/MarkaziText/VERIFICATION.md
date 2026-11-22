# Verification record — Markazi Text (`markazi-text`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/BornaIz/markazitext>
- Pinned commit: `51bb67cce0bb3609f8318077ab0f74b93d365007`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/markazitext/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/BornaIz/markazitext> (HTTP 200)
  at verification time.
- Designer/foundry: Borna Izadpanah, Florian Runge, Fiona Ross

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/markazitext/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright 2017 The Markazi Text Project Authors (https://github.com/BornaIz/markazitext)`
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
| MarkaziText[wght].ttf | MarkaziText-Regular | normal/400 | 424b7331681160ff2a4b209bfc356ea9564d429a7daea43ee4dc28de8ff4f9fe | no |

Each file above was downloaded directly from google/fonts' `ofl/markazitext/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "markazi-text"`).

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
