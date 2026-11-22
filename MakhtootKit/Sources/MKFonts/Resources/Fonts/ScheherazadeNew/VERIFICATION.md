# Verification record — Scheherazade New (`scheherazade-new`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/silnrsi/font-scheherazade>
- Pinned commit: `60e64560db425905f52149398403298747f5f684`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/scheherazadenew/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/silnrsi/font-scheherazade> (HTTP 200)
  at verification time.
- Designer/foundry: SIL International

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/scheherazadenew/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright (c) 1994-2026, SIL Global (https://www.sil.org/),`
- Reserved Font Names found: ['Scheherazade']

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
| ScheherazadeNew-Bold.ttf | ScheherazadeNew-Bold | normal/700 | 91363517a63dbc7448b5814226d33d845b26b32a461cd159ea0b3f23c7effd2d | no |
| ScheherazadeNew-Medium.ttf | ScheherazadeNew-Medium | normal/500 | 060b801307ec55d996d635578fffba0d95169f63e1d0f6061402185eaf4fa6af | no |
| ScheherazadeNew-Regular.ttf | ScheherazadeNew-Regular | normal/400 | 794bac8dc9e83d1d620bc471ea694f5f31d0965ce8006490a79dfc51a2d283b3 | no |
| ScheherazadeNew-SemiBold.ttf | ScheherazadeNew-SemiBold | normal/600 | 155056d27ea5a34ab739170abeff8d45b44a494e39be329f0a4d1e6cbd173390 | no |

Each file above was downloaded directly from google/fonts' `ofl/scheherazadenew/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "scheherazade-new"`).

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
