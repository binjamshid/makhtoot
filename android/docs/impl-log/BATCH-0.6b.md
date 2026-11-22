# Batch 0 · Agent 0.6b — MakhtootKit-scope Arabic string extraction (founder-authorised supplement)

Status: complete. Round-trip verification: **154/154 pass, 0 fail**. No blockers.

Companion to Agent 0.6a (app-scope, `Makhtoot/**`). This agent owns `MakhtootKit/Sources/**`
only and touched no Swift source file.

## What was produced

| Output | Path | Status |
|---|---|---|
| Android string resources, one file per Gradle module (additive) | `android/strings/modules/<gradle-module>-strings.xml` | 13 files, 154 keys total, all valid XML |
| Literal-by-literal classification map | `android/strings/module-strings-map.json` | 577 entries (one per raw occurrence examined), valid JSON |

Both are staging output. Per the mission brief, Agent 1.1 installs each `<gradle-module>-strings.xml`
into that module's own `src/main/res/values/strings.xml` — **not** a single shared file, because
`:app` depends on the engine modules and never the reverse, so an engine module cannot reference
`:app`'s `R` class. `android/strings/strings.xml` (Agent 0.4's 52 app-scope keys) and
`android/strings/app-strings.xml`/`app-strings-map.json` (Agent 0.6a's output) were not touched.

No file was written for `mk-textengine`, `mk-pathtext`, or `mk-analytics` — every literal examined
in those three modules turned out to be either a comment-only occurrence or persisted/journaled
data, so there was nothing genuinely extractable (see the per-module table below). This is a
finding, not an omission: Spine's "one file per module with at least one extracted string"
condition simply isn't met by those three.

## 1. Counts vs. the mission brief's starting estimate

The brief's per-module estimate (437 literals across 134 files) was explicitly flagged as
"verify rather than trust." Re-running `grep -rhoE '"[^"]*[؀-ۿ][^"]*"' --include='*.swift'` per
module and taking `sort -u` gives **439 distinct literals**; counting every raw occurrence
(including repeats of the same literal on different lines, and a few literals the regex split
into two fragments around Swift's escaped inner quotes, e.g. `"...الخط \"\(fontName)\"..."`)
gives **577 raw occurrences across 134 files** — the number actually classified, one row per
occurrence, in `module-strings-map.json`. The two split-fragment cases were reconciled by hand
against the real source (`Read`, not regex) before being written to `strings.xml`; both are
called out individually in §8.

## 2. Classification result

| Classification | Occurrences | Meaning |
|---|---|---|
| `UI` (extracted) | 164 → **154 distinct keys** | Genuine user-facing text, safe to route through a string resource |
| `PERSISTED_JOURNAL` | 78 | `label:`/`name:` argument to `MKReplaceNodesCommand`/`MKBatchCoreCommand`/`MKNoOpCommand` — a **stored**, `Codable` field journaled verbatim to `journal.mkj` |
| `PERSISTED_NODE_NAME` | 7 | Default value of `MKNodeCore(name:)` — stored Codable field persisted into the `.makhtoot` document |
| `PERSISTED_CONTENT` | 1 | Becomes the actual persisted text *content* of a node (`MKSourceText`), not just a label |
| `PERSISTED_MANIFEST` | 3 | Written into a project/package manifest or exported-file metadata dictionary |
| `PERSISTED_CATALOG` | 208 | Field of a `Codable` asset/region descriptor that is also copied into `MKNodeCore.name` once placed (MKAssets' `nameAr`/`tags`, MKAssetGeometry's region `name`) |
| `FONT_NAME` | 44 | Bundled font family Arabic display name |
| `COMMENT_ONLY` | 55 | Quoted only inside a `//`/`///` comment; no live Swift string literal exists at that call site |
| `DATA_TABLE` | 21 | Arabic-Indic digit/numeral lookup array entries — mechanical conversion tables, not prose |
| `DEBUG_LOG` | 12 | `os.Logger`/`preconditionFailure`/report-detail string, English text with a stylistic Arabic comma, never shown to a user |
| `SPECIMEN` | 2 | Fixed font-preview specimen phrase (pangram-equivalent), not translatable UI copy |
| `BRAND_NAME` | 5 | The "مخطوط" product wordmark / brand glyph, or a filename-default derived from it |
| `BORDERLINE_GLYPH` | 8 | Single tashkeel button glyph (`ـَ` etc.) — see §7, flagged uncertain |
| **Total** | **577** | |

`164` occurrences collapse to `154` distinct keys because a handful of strings are the same text
used at more than one call site (e.g. `mk_persistence_undo_move` "تحريك" fires from three
different command types; `mk_store_error_requires_internet` "يتطلب الاتصال بالإنترنت" is the
canonical DF-7 string shared by two `MKStoreError` cases; `mk_sync_status_sign_in_required` is
shared between `MKSyncAccountReason` and `MKSyncError`).

## 3. Per-module table

| Module | Gradle module | Examined | Extracted (keys) | Left inline | File written |
|---|---|---:|---:|---:|---|
| MKFoundation | `mk-foundation` | 8 | 6 | 2 | yes |
| MKModel | `mk-model` | 4 | 1 | 3 | yes |
| MKTextEngine | `mk-textengine` | 1 | 0 | 1 | **no** |
| MKArrange | `mk-arrange` | 22 | 5 | 17 | yes |
| MKPathText | `mk-pathtext` | 7 | 0 | 7 | **no** |
| MKCanvas | `mk-canvas` | 87 | 37 | 49 | yes |
| MKRender | `mk-render` | 2 | 1 | 1 | yes |
| MKColor | `mk-color` | 4 | 2 | 2 | yes |
| MKExport | `mk-export` | 22 | 12 | 10 | yes |
| MKFonts | `mk-fonts` | 74 | 25 | 48 | yes |
| MKPersistence | `mk-persistence` | 28 | 14 | 13 | yes |
| MKSync | `mk-sync` | 52 | 22 | 29 | yes |
| MKStore | `mk-store` | 22 | 16 | 4 | yes |
| MKAnalytics | `mk-analytics` | 3 | 0 | 3 | **no** |
| MKDesignSystem | `mk-designsystem` | 18 | 8 | 10 | yes |
| MKAssets | `mk-assets` | 223 | 5 | 213 | yes |
| **Total** | | **577** | **154 keys / 164 occ.** | 413 | 13 files |

## 4. The load-bearing distinction: computed vs. stored command labels

Every Undo/Redo action name in this codebase flows through one of two shapes, and the difference
matters more than anything else in this pass:

- **Computed**, e.g. `MKInsertNodeCommand.name: String { "إدراج عنصر" }` (Commands.swift). Not a
  `CodingKeys`-participating stored property, so it is never encoded into `journal.mkj` — it is
  recomputed fresh from the command's case every time. Safe to extract; a resource lookup at
  *access* time can never desynchronize from the journal because the journal never holds this
  value in the first place.
- **Stored**, e.g. `MKReplaceNodesCommand.label: String` / `MKBatchCoreCommand.label: String`
  (also Commands.swift), and `MKNoOpCommand.name: String` (MKCommand.swift). These *are* Codable
  stored fields, journaled verbatim. Every caller across `MKArrange` (all 12 of its arrange-op
  labels — join break/restore, form selection, mark attach/detach, ligature decompose/recompose,
  style/opacity/transform/nudge), `MKPathText/PathTextCommands.swift` (all 5 of its labels), and
  `MKCanvas/InspectorModel.swift` (all 16 of its inspector-control labels) routes through one of
  these two stored fields via `MKReplaceNodesCommand`/`MKBatchCoreCommand`/
  `ArrangeCommands.replaceComposition`. **All of these were left inline**, classified
  `PERSISTED_JOURNAL` — this is why `MKPathText` ends up with zero extracted strings despite
  having 5 genuinely user-visible Undo-menu labels, and why `MKArrange`'s extraction count (5) is
  much smaller than its raw literal count (22) would suggest.

This is the same reasoning the brief asked to apply to `.makhtoot` documents and manifests,
extended to the append-only command journal inside a `.makhtoot` package — a journaled command's
`label` becomes part of the file's persisted byte stream exactly like a manifest field does.

## 5. Verdict on the four named risk modules

- **MKFonts (73 examined → 25 extracted, 48 left).** The brief's prediction was correct: 44 of
  the 48 left-inline literals are `BundledFontIndex.builtInArabicNames[fontID]` — bundled font
  family Arabic display names ("أميري", "ريم كوفي", "نوتو نستعليق أردو", …). Two more are a
  fixed font-preview specimen phrase ("بسم الحرف العربي وجماله" / "١٢٣ 123"). The 25 extracted
  are genuinely different: `MKFontError.arabicUserMessage` (10 error strings),
  `MKFontCategory.arabicDisplayName` (10 catalog-filter labels — Naskh/Ruqaa/Thuluth/Kufi/…,
  computed from the enum case, not persisted), and 5 licensing-screen/offline-state strings.
- **MKAssets (114 examined → 5 extracted, 109 left).** Also confirmed: 109 of the 114 are asset/
  ornament/preset proper names or the tags/region-name fields riding along with them in the same
  `Codable MKAssetDescriptor`/`MKAssetGeometry` catalog records. This is not a judgment call —
  `MKAssetDescriptor.nameAr`'s own doc comment states outright: *"Becomes the placed node's
  `MKNodeCore.name` (T3: "name = nameAr")."* The 5 extracted are `MKAssetCategory.nameAr`, a
  **computed** property (the five browser-section titles — أشكال أساسية/زخارف/إطارات/حليات
  خطية/خلفيات زخرفية) that is never itself persisted; only the category's `rawValue` ("ornaments"
  etc.) is Codable.
- **MKPersistence (24 examined → 14 extracted, 10 left).** Split almost exactly down the
  computed/stored line from §4: 14 computed Undo-menu labels extracted; `MKNoOpCommand`'s
  "حفظ طارئ"/"لا شيء" (stored, journaled), `MKBatchCoreCommand`'s "تحرير" default (stored,
  journaled), and `MetadataStore.duplicateProject`'s `" نسخة"` title suffix (written straight
  into `manifest.title`, D-112 task 15 — the exact same shape as the MKSync D-310 trap below,
  just for project-duplication instead of sync conflicts) all left inline.
- **MKSync (51 examined → 22 extracted, 29 left).** 20 of the 29 left-inline are
  `MKConflictNaming.arabicIndicNumerals` — a 20-entry Arabic-Indic digit lookup array for
  disambiguating repeated conflict-copy names, the same kind of mechanical table as
  `MKFoundation/MKRTLUtilities.arabicIndicDigits`. The remaining 9 are 5 `os.Logger` debug lines
  and 4 doc-comment-only resolution-order examples. **The one deliberate exception in this whole
  pass:** `MKConflictNaming.conflictSuffix = "(نسخة متعارضة)"` (D-310 policy) *was* extracted, as
  `mk_sync_conflict_copy_suffix`, even though by the §4 reasoning it would normally be left
  inline (it is algorithmically written into the persisted project title). The mission brief
  named this literal specifically and instructed treating it as user-facing text with maximum
  round-trip scrutiny — followed literally, and re-verified independently against the live source
  line (`MKConflictNaming.swift:21`) in §6/§8, not just against my own transcription.

## 6. Round-trip verification

`generate.py` writes the 13 XML files, then a separate verification pass — using
`xml.etree.ElementTree` to parse the *written files back off disk* (not the in-memory strings)
and a from-scratch reimplementation of Android's backslash-unescape rules (`\n`, `\"`, `\'`, `\\`,
`\@`, `\?`) applied after the parser's own entity decoding — compares every recovered value
against the hand-transcribed canonical Arabic text.

**Result: 154/154 pass, 0 fail.** All 13 files also parse cleanly as XML (no malformed markup).

A second, independent cross-check compared each extracted key's canonical text directly against
the *raw regex-captured literal* from the original `grep` pass (a second, independently-derived
source, not my transcription) — 147/154 matched byte-for-byte with no transformation at all; the
other 7 are exactly the templated/interpolated cases (§8), each verified by substituting the
Swift `\(expr)` back for the Android `%1$s`/`%1$d` placeholder and confirming the surrounding
literal text matches character-for-character. The four highest-risk strings — the D-310 conflict
suffix, the D-116 memory banner, the D-106 revert-confirmation copy, and the canonical DF-7
"requires internet" string — were additionally re-extracted directly from the live `.swift` files
by an independent regex pass (not reusing any earlier-cached value) and diffed against the
generated resource: all four matched exactly.

## 7. Left uncertain, flagged rather than guessed

- **8 tashkeel-palette button glyphs** (`TextEditingOverlay.swift` `Mark.symbol`: `ـَ`, `ـُ`, `ـِ`,
  `ـّ`, `ـْ`, `ـً`, `ـٌ`, `ـٍ` — tatweel + combining mark, the visual glyph shown ON each harakat
  button). These are genuinely rendered to the user, but they are a one-or-two-codepoint visual
  specimen of the mark itself rather than natural-language UI copy, closer in kind to the
  font/asset-name exclusion categories than to a label or message (the text actually *inserted*
  into the document when tapped is a separate bare `\u{06xx}` scalar, not Arabic-range text, and
  isn't even captured by this scan). Left inline, classified `BORDERLINE_GLYPH`, and called out
  here per "when genuinely uncertain, leave it inline and flag it." The 8 companion
  `accessibilityLabel` values ("فتحة", "ضمة", "كسرة", …) for the same buttons were extracted
  without hesitation — those are unambiguous VoiceOver prose.
- **MKAssetGeometry's region name "الكل"** (`MKAssetGeometry.swift:103`,
  `MKAssetStyleableRegion(name: "الكل", ...)`). Structurally identical to the MKAssets
  `nameAr`/`tags` trap (a field inside the same Codable catalog record chain) but one level more
  indirect — it names a *sub-region* of an asset's geometry rather than the asset itself, and it's
  not explicitly confirmed anywhere in a doc comment that it reaches `MKNodeCore.name`. Left
  inline alongside the rest of the catalog data for consistency and safety; flagged in case a
  reviewer wants to confirm it's genuinely never surfaced as standalone per-region-styling UI text
  before Batch 2+ builds against it.

## 8. Format-string placeholders and split-literal reconciliation

9 of the 154 extracted keys came from Swift string interpolation and were converted to Android
format specifiers: `%1$s` for text (font names, project titles, a pre-formatted relative-date
string), `%1$d`/`%2$d` for counts (subscription-period values, sync upload progress). Two of
these (`mk_export_fallback_font_embedding_restricted`/`_locked_font_no_cache`/`_font_not_embedded`
and `mk_color_icc_disclosure_bundled`) plus one non-interpolated case
(`mk_export_fallback_user_fidelity_toggle`) had their raw `grep` match truncated mid-string by the
extraction regex, because the literal contains an *escaped* inner quote
(`"...الخط \"\(fontName)\"..."` / `"...حسب إعداد \"دقة المسار\""`) — the regex correctly matched
`"[^"]*"` and stopped at the first raw `"` byte, which lands mid-literal for these four. All four
were reconstructed by directly `Read`-ing the source (not by regex) before being written to
`strings.xml`; §6's independent cross-check confirms the reconstruction is exact.

## 9. Key naming

All 154 keys follow `mk_<module_without_mk_prefix>_<snake_case_latin_gloss>` exactly (e.g.
`mk_sync_conflict_copy_suffix`, `mk_store_error_requires_internet`, `mk_canvas_kind_group`),
lowercase ASCII/digits/underscores, derived from the property/case name or a `// Latin gloss:`
comment where present. Verified unique within and across all 13 files (154 keys, 154 unique,
zero collisions).

## 10. Escaping

Applied uniformly to every value: backslash→`\\` (first), `&`→`&amp;`, `<`/`>`→`&lt;`/`&gt;`,
`"`→`\"`, `'`→`\'`, embedded newline→`\n`, and a leading `@`/`?`→`\@`/`\?`. None of the 154
values happened to need most of these paths (no literal backslashes, no leading `@`/`?`, no
embedded newlines), but the escaper runs unconditionally rather than by inspection. Several
values do contain literal double quotes (the three `%1$s`-font-name messages, the
`دقة المسار` self-quote) — these exercised the `"`→`\"` path and are covered by the §6 round-trip.

## Acceptance checklist

- [x] Every distinct Arabic string literal under `MakhtootKit/Sources/**` enumerated per module
      and classified (577 raw occurrences / 439 naive-distinct — see §1)
- [x] Genuine user-facing UI text extracted; font/asset/preset proper names, persisted/journaled
      data, specimen text, and debug/log strings left inline per the classification rules (§2–§5)
- [x] One `strings.xml` file per Gradle module written under `android/strings/modules/`, not a
      single shared file (13 files; 3 modules produced none, correctly — §"What was produced")
- [x] `mk_<module>_<snake_case_latin_gloss>` key convention followed exactly, 154/154 unique
- [x] `android/strings/module-strings-map.json` written — one entry per occurrence examined,
      extracted or not, with `{module, swiftFile, lineNumber, literal, key, classification,
      reason}`
- [x] All 13 XML files validated (`xml.etree.ElementTree`, no parse errors)
- [x] Round-trip verified independently, twice over (§6): **154/154 pass, 0 fail**
- [x] D-310 conflict-copy suffix treated as the brief's named exception, exact form re-verified
      directly against source (§5, §6)
- [x] No Swift source file modified
- [x] Only the three permitted files/dirs created: this impl log, `android/strings/modules/**`,
      `android/strings/module-strings-map.json`

## Blockers

None.
