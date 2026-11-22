# Batch 0 · Agent 0.4 — Strings, theme tokens and asset extraction

Status: complete. All acceptance criteria in `ANDROID_TASK_PACKETS/BATCH-0.md` (lines 292–380)
met. No blockers.

## What was produced

| Output | Path | Status |
|---|---|---|
| Android string resources | `android/strings/strings.xml` | 52/52 keys, valid XML |
| Design-system token dump | `android/strings/theme-tokens.json` | 5/5 themes, valid JSON |
| Font/licence catalog manifest | `android/strings/font-manifest.json` | 45/45 families, 87/87 files, valid JSON |
| Verbatim resource copies | `android/fixtures/resources/*.json` (5 files) | byte-identical (`diff` clean) |

## 1. `android/strings/strings.xml`

Source: `Makhtoot/Resources/Localizable.xcstrings` (52 keys, single-catalog app — the Arabic
source text is itself the key, per D-100/D-475). `data['strings']` count = 52; emitted
`<string>` count = 52 (verified via `xml.etree.ElementTree`, count and uniqueness checked
programmatically). No `variations`/plural entries exist anywhere in the source file, so **zero**
`<plurals>` elements were emitted — this is a fact about the source catalog, not a gap.

**Escaping.** Checked every one of the 52 Arabic values for `& < > ' " @ ? %` and literal
newline/tab before choosing an escaping strategy — none of the 52 values contain any of those
characters, so in practice no value needed escaping. A general Android-`strings.xml` escaper
(escapes `&`, `<`, `>`, `'`, `"`, backslash, `\n`, `\t`, and a leading `@`/`?`) was still applied
to every value rather than special-cased, so a future regeneration from an updated
`Localizable.xcstrings` (which may add a value containing one of these characters) is handled
correctly by construction, not by luck.

**Resource-name sanitization (every key, no exceptions).** Every one of the 52 xcstrings keys is
Arabic text, and Android resource names must match `[a-zA-Z_][a-zA-Z0-9_]*` (ASCII only), so
**all 52 keys required sanitization** — none of the source keys were already valid Android
identifiers. Names were derived from each entry's `comment` field, preferring the "Latin gloss:
…" suffix where present (46 of 52 entries have one) and otherwise from the comment's plain-English
description (`إنشاء` → `create`, `حفظ` → `save`, the 6 entries with no explicit gloss). All 52
names were verified unique and identifier-valid by script before the file was written. Full
mapping (resource name → original Arabic key, which is also the string's own value in this
single-catalog app):

| Resource name | Arabic key / value |
|---|---|
| `custom_dimensions_label` | أبعاد مخصصة |
| `custom_dimensions_subtitle_premium` | أدخل العرض والارتفاع بدقة |
| `rename` | إعادة تسمية |
| `rename_project_title` | إعادة تسمية المشروع |
| `close` | إغلاق |
| `cancel` | إلغاء |
| `create` | إنشاء |
| `empty_state_start_first_design` | ابدأ أول تصميم لك |
| `start_designing_cta` | ابدأ التصميم |
| `folder_name_placeholder` | اسم المجلد |
| `project_name_placeholder` | اسم المشروع |
| `settings_title` | الإعدادات |
| `height_label` | الارتفاع |
| `subscription_row_title` | الاشتراك |
| `premium_plans_title` | الباقات المميزة |
| `search_projects_prompt` | البحث في المشاريع |
| `licensing_row_title` | التراخيص |
| `support_row_title` | الدعم |
| `width_label` | العرض |
| `folder_chip_all` | الكل |
| `editor_title` | المحرر |
| `projects_title` | المشاريع |
| `canvas_preset_a5_print_card` | بطاقة طباعة A5 |
| `move_to_folder_none_option` | بلا مجلد |
| `duplicate` | تكرار |
| `done` | تم |
| `debug_seed_500_projects` | توليد ٥٠٠ مشروع تجريبي |
| `canvas_preset_messaging_status` | حالة رسائل |
| `theme_name_baseline_ink_paper` | حبر ورق |
| `delete` | حذف |
| `delete_folder_confirm_title` | حذف المجلد؟ |
| `delete_project_confirm_title` | حذف المشروع؟ |
| `save` | حفظ |
| `canvas_preset_phone_wallpaper` | خلفية هاتف |
| `canvas_preset_story_9x16` | ستوري ٩:١٦ |
| `export_history_title` | سجل التصدير |
| `delete_folder_confirm_message` | سيُحذف المجلد، وستنتقل مشاريعه إلى (الكل) |
| `delete_project_confirm_message` | سيُحذف المشروع نهائيًا من هذا الجهاز |
| `view_plans_link` | عرض الباقات |
| `not_available_on_device_label` | غير متاح على هذا الجهاز |
| `open` | فتح |
| `no_results_title` | لا توجد نتائج |
| `export_history_empty_state` | لم يتم تصدير هذا المشروع بعد |
| `new_folder_title` | مجلد جديد |
| `new_folder_chip` | مجلد جديد + |
| `app_name` | مخطوط |
| `canvas_preset_square_1x1` | مربع ١:١ |
| `new_project_button` | مشروع جديد |
| `debug_design_gallery_title` | معرض عناصر التصميم |
| `canvas_preset_post_4x5` | منشور ٤:٥ |
| `premium_feature_label` | ميزة مميزة |
| `move_to_folder_action` | نقل إلى مجلد |

> **Writer note:** `theme_name_baseline_ink_paper` ("حبر ورق" / "Ink & Paper") is a distinct
> string from the Hibr theme's own picker display name ("حِبر", `MKThemeID.displayName` in
> `MKTheme.swift`) — the two are not the same string and were not merged, since the xcstrings
> catalog treats them as separate keys with separate call sites (this string's comment says
> "Baseline theme name", not "theme picker row").
>
> Each `<string>` element carries its original iOS `comment` as an XML comment immediately above
> it (double-hyphen sequences neutralized to `- -` to stay XML-comment-legal), so a later agent
> can trace every resource name back to its iOS call-site context without re-opening
> `Localizable.xcstrings`.

## 2. `android/strings/theme-tokens.json`

Source: `MKTheme.swift`, `MKTypeRamp.swift`, `MKSpacing.swift`, `MKMotion.swift`,
`Themes/{Hibr,Kufi,Naqsh,Raml,Tayf}Theme.swift`, `Themes/MKThemeColorHelpers.swift`. Top level is
`_meta` plus exactly 5 theme objects (`hibr`, `kufi`, `naqsh`, `raml`, `tayf`), each non-empty and
each carrying its own `colors`, `fonts`, `typeRamp`, `spacing`, `radii`, `elevation`, `motion`
sub-objects (mirrors the `MKTheme` protocol shape 1:1, per the packet's instruction — `spacing`
and `motion` are duplicated identically into every theme object, rather than centralized once,
specifically so a later agent can consume one theme object standalone).

**Color resolution.** Every `Color(hex:)` literal was transcribed as `#RRGGBB`. Every
`Color(light:dark:)` pair became `{"light": "#…", "dark": "#…"}`. Where a Swift property is a
**computed passthrough** to another semantic role on the same theme (e.g. `KufiTheme.secondary`
returns `primary`; `RamlTheme.inkFaint` returns `inkMuted`), the JSON value is `{"ref": "<role>"}`
rather than a duplicated literal, so a consumer can tell "these are the same color by
construction" from "these happen to match." 17 such references exist across the 5 themes (listed
per-theme in `_meta` is not duplicated here; verified programmatically: hibr 1, kufi 6, naqsh 4,
raml 3, tayf 3).

**`primaryPressed` (computed, not a literal).** No theme has an explicit `primaryPressed` hex
constant in Swift — every one calls `Color.darkened(hex:, by: 0.12)` (default `amount`), defined
in `MKThemeColorHelpers.swift` as `each RGB channel × (1 − amount)`, i.e. × 0.88, values not
otherwise rounded in the Swift source (SwiftUI's `Color(red:green:blue:)` takes `Double`).
Recomputed here in Python at full precision and rounded to the nearest integer per channel to
produce a `#RRGGBB` literal (necessary since JSON has no native float-RGB `Color` type); e.g.
Hibr light `0x8A3324` → `#792D20`. All 10 values (5 themes × light/dark) were computed by script,
not transcribed by hand — see `/tmp` scratch script referenced below if a re-derivation is ever
needed (not checked into the repo; the formula is documented here and in the JSON `_meta.note` so
it's reproducible without the scratch file).

**Two verbatim-but-surprising Swift values, ported as-is, not "corrected":**
- `RamlTheme.inkMuted` resolves to `inkMutedLight` in **both** the light and dark branches
  (`Color(light: Self.inkMutedLight, dark: Self.inkMutedLight)`) — `RamlTheme.swift` has no
  `inkMutedDark` constant at all. Ported verbatim as `{"light": "#9A9082", "dark": "#9A9082"}`,
  flagged inline in the generation script and here rather than silently "fixed."
- `KufiTheme.canvasBackdrop` resolves dark mode to `surfaceLight` (`0xF2F2EF`), not
  `surfaceDark` — ported verbatim as `{"light": "#0A0A0A", "dark": "#F2F2EF"}`.
- `HibrTheme`'s dark-mode primary/secondary swap (gold becomes `primary`, oxblood becomes
  `secondary` in dark mode — the theme's own doc comment calls this out as intentional, not a
  bug) is ported unchanged.

**`typeRamp`.** All 10 `MKTypeRole` cases (`display`, `largeTitle`, `title`, `title2`,
`headline`, `body`, `callout`, `footnote`, `caption`, `mono`) present per theme, with
`pointSize`/`lineHeightMultiplier`/`weight` from `MKTypeRamp.swift` `style(for:)` (identical
across all 5 themes — only the resolved font `face` differs, via each theme's `fonts.display` /
`fonts.ui` / `fonts.mono`).

**`spacing`**: `{xs:4, sm:8, md:12, lg:16, xl:24, xxl:32, xxxl:48}` for all 5 themes (every theme's
`spacing` property resolves to `MKSpacing.default`). **`motion`**:
`{fastDuration:0.15, standardDuration:0.25, modalDuration:0.35, curve:"easeInOut",
reducesMotion:false}` for all 5 themes (every theme's `motion` property resolves to
`MKMotionTokens.default`).

**`radii`/`elevation`** are the two genuinely per-theme-distinct scales (besides `colors`/`fonts`)
— transcribed directly from each theme's `radius`/`elevation` computed properties. Kufi is the
one theme with `style: "circular"` (every other theme is `"continuous"`) and all-zero radii,
per its own doc comment ("stark grid", hard-edged rectangles).

## 3. `android/strings/font-manifest.json`

Source: `MakhtootKit/Sources/MKFonts/Resources/Fonts/**` (45 family directories on disk, verified
by direct `find`/listing, matching the spine's expected 45/87 exactly), cross-referenced against
`Fonts/_PROHIBITED.md`, `Resources/EXCLUDED_FONTS.md`, and
`Resources/LicenseRecords/records.json`.

**Family/file count (task 5).** Verified by direct filesystem listing: **45** family directories,
**87** font files total (`.ttf`), matching the spine's stated expected result exactly — no
discrepancy, nothing to flag loudly per the packet's "fail loudly if the tree disagrees" clause.
Cross-checked programmatically that every one of `records.json`'s 45 `familyName` entries maps
1:1 to an on-disk directory (case/spacing-insensitive match — `records.json` uses spaced display
names, e.g. `"Amiri Quran"`, on-disk directories are PascalCase-no-space, e.g. `AmiriQuran/`), that
every one of the 87 `faces[].filename` entries exists on disk under that family's directory, and
that there are zero on-disk font files not referenced by `records.json` and zero referenced files
missing from disk. `licenseType` across all 45 records is uniformly `"OFL-1.1"`.

**Prohibition/exclusion cross-check (task 3).** `Fonts/_PROHIBITED.md` names exactly one
prohibited family — KFGQPC Uthmanic Script HAFS (and the wider KFGQPC Uthmanic family,
proprietary non-commercial EULA, D-120). **No family with that name, or any name containing
"KFGQPC" or "Uthman", exists anywhere in `Fonts/` on disk** — it was never bundled in the first
place, so there was nothing to exclude from the manifest. `Resources/EXCLUDED_FONTS.md` is a
historical D-120-candidate record (20 candidates total): 5 were held back pending WS-16's Arrange
Mode cursive-fidelity work and have since been **released** into the catalog (Amiri, Amiri Quran,
Aref Ruqaa, Qahiri, Rakkas — all 5 are present in `Fonts/` and in `records.json`, and are included
in the manifest normally), and the remaining 15 are recorded as "fully clean, no exclusion." **Net
result: zero families excluded from `font-manifest.json`** — every family currently bundled on iOS
passed licensing and ships. This is stated as a finding, not assumed: the manifest generation
script raises a hard error (not a silent skip) if any `records.json` family fails to resolve to an
on-disk directory, and none did.

**Licence characterization.** Every family's `licenseType` (`OFL-1.1`), `copyrightNotice`,
`sourceRepoURL`/`sourceCommit`, `redistributionConfirmed`, `verificationDate`/`verifiedBy`, and
`embeddingRights` are carried over verbatim from `records.json` — these are **already-completed,
signed-off iOS-side verification records** (per-family `VERIFICATION.md` + `records.json`'s own
`verification` block), not a new/unverified claim being asserted for the first time. This is
**not** a case for the spine §9 `VERIFY-AT-SUBMISSION` convention — that convention is reserved
for newly-vendored native libraries with no prior verification pass (harfbuzz/freetype/lcms2,
D-304, a different agent's scope), not for a font catalog whose licensing was already verified and
shipped on iOS. `licenseCharacterization` is recorded as `"verified"` accordingly, per family.

**Android asset paths.** Every face's `androidAssetPath` follows
`android/app/src/main/assets/fonts/<on-disk-directory-name>/<filename>` per the packet's port map
and D-316 — e.g. `android/app/src/main/assets/fonts/AmiriQuran/AmiriQuran-Regular.ttf`. No files
were copied there (the path did not exist yet). Under spine §11, that copy step is
owned by Agent 1.1 (`android/app/src/main/assets/fonts/**` is a named "glue artifact"), and this
manifest is exactly the mapping Agent 1.1 needs to perform that copy faithfully.

## 4. `android/fixtures/resources/**` (verbatim copies)

5 files copied byte-for-byte (`diff` against the Swift-side originals is clean for all 5, verified
after copy — see command output in this session, not reproduced here since it is definitionally
empty):

| Source | Copy |
|---|---|
| `MakhtootKit/Sources/MKAssets/Resources/assets-manifest.json` (484,627 bytes) | `android/fixtures/resources/assets-manifest.json` |
| `MakhtootKit/Sources/MKAssets/Resources/provenance-records.json` (34,729 bytes) | `android/fixtures/resources/provenance-records.json` |
| `MakhtootKit/Sources/MKExport/Resources/presets.json` (2,568 bytes) | `android/fixtures/resources/presets.json` |
| `MakhtootKit/Sources/MKFonts/Resources/catalog-seed.json` (14,208 bytes) | `android/fixtures/resources/catalog-seed.json` |
| `MakhtootKit/Sources/MKFonts/Resources/PremiumCatalog/catalog-manifest-v1.json` (1,395 bytes) | `android/fixtures/resources/catalog-manifest-v1.json` |

No reformatting was applied — these are inputs Batch 5.5/5.6/6.5 consume as-is per the packet, not
derived data.

## Deviations from the port map

None. Every source file named in the packet's "Reads" table was located at the path given and
read in full (or, for the 5 verbatim-copy JSON files, copied byte-for-byte rather than
re-serialized, to guarantee byte-identity). No file needed a naming-collision workaround (§3.3
does not apply to this agent — it ports data, not Swift symbols).

## Acceptance checklist (packet, verbatim)

- [x] `android/strings/strings.xml` is valid XML (parsed with `xml.etree.ElementTree`, no errors)
      and contains one entry per `Localizable.xcstrings` key (52 = 52).
- [x] `android/strings/theme-tokens.json` has exactly 5 top-level theme objects (`hibr`, `kufi`,
      `naqsh`, `raml`, `tayf`), each non-empty (16 colors + fonts + 10 typeRamp roles + spacing +
      radii + elevation + motion per theme).
- [x] `android/strings/font-manifest.json` lists every non-prohibited bundled family (45/45); zero
      entries reference a family named in `_PROHIBITED.md` (none exist on disk to reference).
- [x] The 5 files under `android/fixtures/resources/` are present and byte-identical to their
      Swift originals (`diff` clean, verified this session).
- [x] Requirements covered: enables `R-*` localization/theming/font-catalog traceability once
      `android/PARITY_MATRIX.md` lands (Agent 0.1, concurrent, not a dependency of this agent).

## Blockers

None.
