# Verification record — IBM Plex Mono (`ibm-plex-mono`)

Produced by the WS-09 per-font VERIFICATION PROTOCOL (`Resources/VERIFICATION_PROTOCOL.md`), following the same steps as the existing `Tajawal`/`IbmPlexSansArabic` records. Bundled for the **حِبر (Hibr)** design-system theme's `mono` UI role (spec/metadata labels, e.g. "A4 · CMYK", the Latin "MAKHTOOT" sub-lockup) — a UI-chrome font, not part of the canvas text-on-path catalog.

## Step 1 — Authoritative upstream repository

- Repository: <https://github.com/IBM/plex>
- Located via: Google Fonts' own canonical distribution repository (`github.com/google/fonts`, `ofl/ibmplexmono/`), the same locate-point already used for every other bundled family in this catalog.
- Designer/foundry: IBM Corp. (Mike Abbink, Bold Monday)

## Step 2 — License file capture

`LICENSE-OFL.txt` in this directory is the byte-identical `OFL.txt` fetched directly from `https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/OFL.txt` at verification time (2026-07-23).

## Step 3 — Copyright + Reserved Font Names

- Copyright line (verbatim, first line of `LICENSE-OFL.txt`): `Copyright © 2017 IBM Corp. with Reserved Font Name "Plex"`
- Reserved Font Names found: `Plex`

## Step 4 — Redistribution clause

OFL 1.1 §2 permits bundling with commercial software, subject to §3 (no reuse of the Reserved Font Name "Plex" by a modified derivative). Makhtoot ships the font UNMODIFIED, so this is satisfied trivially — same reasoning already recorded for every other OFL family in this catalog.

## Step 5 — Binary identity

| File | PostScript name | Style/Weight | SHA-256 | GPOS cursive (type 3)? |
|---|---|---|---|---|
| IBMPlexMono-Regular.ttf | IBMPlexMono-Regular | normal/400 | 6a3412f058c7d8dfd9170c41e85ade48e5156ecb89356110ca57a0a27734af46 | no |
| IBMPlexMono-Medium.ttf | IBMPlexMono-Medium | normal/500 | a9b4c49bb299e05b5f6c481e7fb5e78943d2793249a0c8874ab574a2d1ea6755 | no |
| IBMPlexMono-Bold.ttf | IBMPlexMono-Bold | normal/700 | ac27abd6450a64dd94467580a02fe6235156d5b92f2926ebbc8e7489df64e0be | no |

Each file above was downloaded directly from `google/fonts`' `ofl/ibmplexmono/` directory (same fetch as the license file) and hashed immediately after download; the hash is recorded in `Resources/LicenseRecords/records.json` for the `FontLicenseAudit` (T20) to re-verify against the shipped binary at any time.

## Step 6 — MKLicenseRecord

Written to `Resources/LicenseRecords/records.json` (`fontID: "ibm-plex-mono"`).

## Step 7 — D-222 arrange-fidelity gate

**N/A for this family.** IBM Plex Mono is a Latin-only UI/chrome font (zero Arabic cmap coverage — confirmed via `fontTools.ttLib` `getBestCmap()`), never routed through `MKArrange`/text-on-path rendering, so the Arrange-Mode manual-visual gate does not apply. Recorded as `not_applicable` rather than `blocked`.

## Step 8 — GPOS cursive-attachment audit (D-222)

No GPOS lookup type 3 (cursive attachment) found on base glyphs, on any of the three faces above.

Audited via `fontTools.ttLib` (GPOS `LookupList`, walking `LookupType`, resolving `LookupType 9` extension wrappers to their real `ExtensionLookupType`) against every face listed above.

## Ship decision

Registered (process-wide, at launch) but **deliberately absent from `catalog-seed.json`**, the same mechanism already used for `Aref Ruqaa`/`Amiri` to keep a font out of `MKFontCatalog.browse()`'s default canvas-text picker (see `Resources/EXCLUDED_FONTS.md`) — IBM Plex Mono has zero Arabic glyph coverage and is a UI-chrome font (the Hibr theme's `mono` role), never meant for user canvas text. `redistributionConfirmed: true` in `records.json` still gates real per-process font registration, which is all `MKDesignSystem`'s `Font.custom(...)` call sites need.
