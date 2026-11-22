# Verification record — Tajawal (`tajawal`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`).

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/googlefonts/tajawal>
- Pinned commit: `2085b8942f234e7afb83dc03c77713d0d5471cc9`
- Located via: Google Fonts' own canonical distribution repository
  (`github.com/google/fonts`, `ofl/tajawal/`), which documents its
  own upstream traceability per-family in `upstream_info.md` /
  `METADATA.pb`'s `source { repository_url, commit }` block — this is NOT an
  aggregator/mirror site (protocol step 1 explicitly permits "Google Fonts
  GitHub org" as an authoritative locate-point). The upstream commit above was
  independently confirmed to resolve at <https://github.com/googlefonts/tajawal> (HTTP 200)
  at verification time.
- Designer/foundry: Boutros Fonts, Mourad Boutros, Soulaf Khalifeh

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched
directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal/OFL.txt`
at verification time (which google/fonts itself mirrors byte-for-byte from the
upstream repository's release artifact — see `upstream_info.md` in the
evidence pack for the pinned-commit → release-archive chain where present).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`):
  `Copyright 2018 Boutros International. (http://www.boutrosfonts.com)`
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
| Tajawal-Black.ttf | Tajawal-Black | normal/900 | da582a579d3200869535dc994d2349608a8582042f8776b3679b157015db287c | no |
| Tajawal-Bold.ttf | Tajawal-Bold | normal/700 | 0342ab6b74b6bd1b4b5bf7beda45a9734a2b3147a31e8a3a45b6a3417a52d9d7 | no |
| Tajawal-ExtraBold.ttf | Tajawal-ExtraBold | normal/800 | 3d1298b747c22579f9e1bdeb0d4165064cb17f7e66145e2f43f9deb12ad7a2cf | no |
| Tajawal-ExtraLight.ttf | Tajawal-ExtraLight | normal/200 | a12ffbfaaec30ab8142edc60fa4727b104a90eb54c6a200a76988a1ec2ec11dc | no |
| Tajawal-Light.ttf | Tajawal-Light | normal/300 | ab26ed3e0c5af2c71b469b5780decff8088d290ab91aa29b07321580136e813a | no |
| Tajawal-Medium.ttf | Tajawal-Medium | normal/500 | 1ff8bd943a261c9dd7906bdb1993cab87b6d925a7fb5f848cdb51ed301531090 | no |
| Tajawal-Regular.ttf | Tajawal-Regular | normal/400 | 6882892da3e03527d5db2bbab3b48bde6ef2e878a43f522d1a4eebda90010a19 | no |

Each file above was downloaded directly from google/fonts' `ofl/tajawal/`
directory (same fetch as the license file) and hashed immediately after
download; the hash is recorded in `Resources/LicenseRecords/records.json` for
the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any
time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "tajawal"`).

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
