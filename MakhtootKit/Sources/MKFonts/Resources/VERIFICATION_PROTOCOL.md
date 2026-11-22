# WS-09 font VERIFICATION PROTOCOL

Every font under `Resources/Fonts/<Family>/` MUST have completed all 8 steps
below before it may exist in that directory. `MKFontRegistry`'s loader
enforces this at runtime (T3 AC): "no record → no registration", and a
family folder existing without all three of {font files, `LICENSE-OFL.txt`,
`VERIFICATION.md`} is a build-time contract violation checked by
`FontLicenseAudit` (T20).

This file is the **checklist definition**. Individual fonts' completed
protocol runs are recorded at `Resources/Fonts/<Family>/VERIFICATION.md`
(machine-generated evidence, one per family) and the aggregate machine-
readable outcome lives in `Resources/LicenseRecords/records.json`
(`verification` object per record) plus `Resources/EXCLUDED_FONTS.md` for
anything not unconditionally shipped.

## The 8 steps

1. **Locate the authoritative upstream repository.** Acceptable sources: the
   Google Fonts GitHub org (`github.com/google/fonts`, which documents its
   own upstream provenance per-family via `upstream_info.md` and
   `METADATA.pb`'s `source { repository_url, commit }` block), the font
   foundry's own repo directly (`notofonts/arabic`, `aliftype/*`, SIL
   International's GitHub org for Scheherazade New/Lateef/Harmattan, or any
   other repo `google/fonts` itself names as the source of record). Generic
   font-aggregator/mirror download sites (font catalog sites unrelated to the
   foundry or to Google Fonts) are **never** authoritative, no matter how
   convenient — auto-fail if that is the only source found.
2. **Capture the exact `OFL.txt`/`LICENSE` file** from that repository (or
   from `google/fonts`' own byte-identical mirror of it, itself traceable to
   the pinned upstream commit) and store it verbatim at
   `Resources/Fonts/<fontID>/LICENSE-OFL.txt`. No edits, no reformatting.
3. **Record the copyright line and all Reserved Font Names** parsed
   literally from the captured license header — never inferred, never
   assumed absent without a text scan.
4. **Confirm the redistribution clause.** OFL 1.1 §2 permits bundling,
   embedding, and redistribution with commercial software provided the
   copyright notice and license text accompany the font; §3 forbids reusing
   a Reserved Font Name on a *modified* derivative (Makhtoot never modifies
   the shipped font, so this is satisfied by construction as long as the
   binary is unmodified — see step 5).
5. **Confirm binary identity.** The font file bundled in
   `Resources/Fonts/<fontID>/` must be byte-identical to (or an unmodified
   copy of) the upstream release artifact. Record the upstream release tag
   or commit and the SHA-256 of every bundled file.
6. **Write the `MKLicenseRecord`** (canonical shape, D-227 — see
   `Sources/MKFonts/LicenseRecord.swift`) into
   `Resources/LicenseRecords/records.json`, and append the verification
   evidence (steps 1-5 findings) to `Resources/Fonts/<fontID>/VERIFICATION.md`.
7. **D-222 fidelity gate.** A license-clean font must ALSO pass the
   WS-04 (`MKArrange`) arrange-fidelity test block run specifically against
   *this* font: `T-AR-31/32/33` plus the decompose/recompose round-trip
   `T-AR-36..38` — not merely the reduced cross-font sweep `T-AR-58`. These
   are `MANUAL-ARABIC` / `manual-visual` tests (TEST_MATRIX.md) exercised
   against the Arrange Mode UI. **If Arrange Mode does not exist yet in the
   repo** (as of this protocol run — `MKArrange` is a placeholder target),
   this step cannot be executed and must be recorded as `blocked_pending_ws04`,
   never silently marked as passing. A font whose step 7 result is anything
   other than an actual recorded PASS is treated identically to a step-7
   failure for the purposes of the packet's shipping AC, and any exception
   to that (e.g. shipping anyway for a specific demo/smoke-test purpose) must
   be explicitly logged, not silently assumed.
8. **GPOS cursive-attachment audit.** Inspect the font's `GPOS` table for
   `LookupType 3` (cursive attachment, including when wrapped by a
   `LookupType 9` extension lookup) applied to base glyphs; record
   present/absent in the verification record. If ANY shipped font uses GPOS
   type 3, `MKModel`'s D-105 mark-capture layer needs a cursive-pair
   structure before that font can ship — this is a `VERIFY`-per-font
   blocking condition (never assume support exists; always check and
   record). A font flagged "present" here without confirmed D-105 support is
   excluded from the default browsable catalog exactly like a step 7
   failure — logged in `EXCLUDED_FONTS.md` with the specific finding, not
   folded into a generic "license failure" bucket.

Failure at steps 1-6 ⇒ font is EXCLUDED outright, logged in
`EXCLUDED_FONTS.md`. KFGQPC/Uthmanic-family anything is an automatic step-1
fail (see `Resources/Fonts/_PROHIBITED.md`) — the rest of the protocol is
never run for those.

## Tooling used for steps 5 and 8 (for reproducibility)

- SHA-256: computed immediately after download, in the same process that
  wrote the file to disk (no separate re-download step that could diverge).
- GPOS audit: `fontTools.ttLib.TTFont`, walking `table_GPOS.LookupList.Lookup`,
  reading `LookupType` per lookup (resolving type-9 extension lookups to
  their real `ExtensionLookupType`), flagging any occurrence of type 3.
- sfnt sanity: same `fontTools` pass checks for `cmap`/`name`/`head` presence
  and `glyf`/`CFF ` (outline table) presence, matching the acceptance
  criteria `FontValidator` (T14) applies to user-imported fonts, so bundled
  and imported fonts are held to the same structural bar.
