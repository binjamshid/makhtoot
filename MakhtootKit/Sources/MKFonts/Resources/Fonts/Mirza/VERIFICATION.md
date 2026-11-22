# Verification record — Mirza (`mirza`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/Tarobish/Mirza>
- Pinned commit: `fa7b59c92953e7f437d079a8c118a7952c507f09`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/mirza/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/Tarobish/Mirza> (HTTP 200)
  at verification time.
- Designer/foundry: KB Studio

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/mirza/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright 2015 The Mirza Project Authors (https://github.com/Tarobish/Mirza)`
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
| Mirza-Bold.ttf | Mirza-Bold | normal/700 | 306b412a39d9f93ca840c13ca62300eb5c7712e2afa94bd7ef2272b51131be6d | no |
| Mirza-Medium.ttf | Mirza-Medium | normal/500 | 423532407cc832ef84cc8f08a3359f26b50e721c8aa0e00221e4215cc83440b3 | no |
| Mirza-Regular.ttf | Mirza-Regular | normal/400 | 5b1ac6cb285ca3492e313a53d5252b9784bf7607f2835a2d44cb3cbad0168539 | no |
| Mirza-SemiBold.ttf | Mirza-SemiBold | normal/600 | 4225215d0df4ad389c4ac29d48fddc531703776591ade64c23f6f995669d4078 | no |

Each file above was downloaded directly from google/fonts' `ofl/mirza/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "mirza"`).

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
