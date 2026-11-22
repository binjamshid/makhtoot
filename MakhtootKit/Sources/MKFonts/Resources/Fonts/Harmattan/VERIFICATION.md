# Verification record — Harmattan (`harmattan`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/silnrsi/font-harmattan>
- Pinned commit: `b8d089bdb2cf97351cff63beaa9d68a6273dcc42`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/harmattan/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/silnrsi/font-harmattan> (HTTP 200)
  at verification time.
- Designer/foundry: SIL International

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/harmattan/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright (c) 2007-2008, The C&MA Guinea Fulbe Team;`
- Reserved Font Names found: ['Fouta', 'Harmattan']

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
| Harmattan-Bold.ttf | Harmattan-Bold | normal/700 | eb9de49ecb72d34e14c768bea6f9a7831f6bd2c15b062fcc2bb17b0ac967bc67 | no |
| Harmattan-Medium.ttf | Harmattan-Medium | normal/500 | e83a209c87145152dcc4df18ffdd50aad8407fb563135392e168c896e932d2d5 | no |
| Harmattan-Regular.ttf | Harmattan-Regular | normal/400 | 5fbaafc51ad21663729b168afaff5f28d3e3087f1fc736ada32d7cd99674c0e0 | no |
| Harmattan-SemiBold.ttf | Harmattan-SemiBold | normal/600 | 83479450450a50da78412f2f48b274883095a23a01d6bf36db54e769cb09b11d | no |

Each file above was downloaded directly from google/fonts' `ofl/harmattan/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "harmattan"`).

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
