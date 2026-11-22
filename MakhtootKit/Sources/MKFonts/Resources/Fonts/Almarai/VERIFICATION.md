# Verification record — Almarai (`almarai`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/JuergenWillrodt/Almarai>
- Pinned commit: `7307ede5d42bcb5b9f905736a7c6eb04347afa3b`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/almarai/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/JuergenWillrodt/Almarai> (HTTP 200)
  at verification time.
- Designer/foundry: Boutros Fonts, Mourad Boutros

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/almarai/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright 2019 The Almarai Project Authors (https://github.com/JuergenWillrodt/Almarai)`
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
| Almarai-Bold.ttf | Almarai-Bold | normal/700 | 06401391b5b39fbcf2bc0c6a6e03faf992435e7b011183a1861737e913af8613 | no |
| Almarai-ExtraBold.ttf | Almarai-ExtraBold | normal/800 | 9f8f72f1cb06db787a5b32e314a109267e53c505c9f9ab0dad5aa8ff8b219a07 | no |
| Almarai-Light.ttf | Almarai-Light | normal/300 | a57bca270340202a28899f7488ee76ed9b93115b89d7a81db92d68e29993da5a | no |
| Almarai-Regular.ttf | Almarai-Regular | normal/400 | 5b5cad33c8e5922083728d271cdcda91f96ba291f1307eccc4f4ef732dc19622 | no |

Each file above was downloaded directly from google/fonts' `ofl/almarai/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "almarai"`).

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
