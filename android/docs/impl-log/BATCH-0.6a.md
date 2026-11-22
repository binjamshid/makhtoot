# Batch 0 · Agent 0.6a — App-scope Arabic string extraction (founder-authorised supplement)

Status: complete. Round-trip verification: **363/363 pass, 0 fail**. No blockers.

## What was produced

| Output | Path | Status |
|---|---|---|
| Android string resources (new, additive) | `android/strings/app-strings.xml` | 363 keys, valid XML |
| Literal-by-literal classification map | `android/strings/app-strings-map.json` | 702 entries, valid JSON |

Both files are staging output; per the mission brief, Agent 1.1 merges them into
`android/app/src/main/res/values/strings.xml` alongside Agent 0.4's 52 keys (`android/strings/
strings.xml`, outside this work item). No Swift source file was modified.

## 1. Reconciling the starting count with what's actually in the tree

The mission brief's starting point — `grep -rhoE '"[^"]*[؀-ۿ][^"]*"' Makhtoot | sort -u` — gives
**548 distinct literals across 52 files**, exactly reproduced here. That count includes text that
is not an actual compiled Swift string literal at all: the grep pattern matches any quoted Arabic
text, including inside `//`/`///`/`/* */` comments. Refining it:

| Refinement | Distinct literals | Files |
|---|---|---|
| Naive grep (starting point, matches brief exactly) | 548 | 52 |
| − text that appears only inside a comment (no matching real code literal at all) | −4 files drop out entirely (`MakhtootApp.swift`, `AppNavigationModel.swift`, `MKRoute.swift`, `PathGhostGuideOverlay.swift` have Arabic only in doc comments cross-referencing a real literal elsewhere) | 483 real code literals | 38 |
| − the 5 files `ANDROID_SPINE.md` §3.1 excludes from the Android port entirely | (already excluded from the 483; tracked separately, see §5 below) | 38 |

**483 distinct real Swift string literals across 38 files** is the actual extraction scope. Every
one of the 702 raw quoted-Arabic-text occurrences (548 distinct → 702 counting repeats) was
individually classified; nothing was dropped silently. `app-strings-map.json` has exactly 702
entries — one per occurrence, including the comment-only and excluded-file ones — precisely
because "for every literal you examined, extracted or not" was read literally.

## 2. Classification result

| Classification | Occurrences | Distinct literals / keys | Meaning |
|---|---|---|---|
| `extract` | 406 | 363 new keys | Genuine user-facing UI text → written to `app-strings.xml` |
| `duplicate_of_existing_strings_xml` | 87 | 50 literals → 50 existing keys | Byte-identical to a value already in Agent 0.4's `strings.xml`; referenced by that key, not re-added |
| `leave_inline` | 74 | 71 literals | Left as a Swift literal; reason recorded per entry (breakdown below) |
| `excluded_file_not_in_android_port` | 78 | 72 literals | Inside one of the 5 files `ANDROID_SPINE.md` §3.1 excludes from the port entirely |
| `not_a_literal_comment_only` | 57 | — | Grep matched quoted text inside a comment, not a real string literal |
| **Total** | **702** | | |

### `leave_inline` breakdown (74 occurrences, 71 distinct literals)

| Reason code | Count | What it covers |
|---|---|---|
| `debug_only` | 46 | `#if DEBUG`-gated developer tooling: `EditorScene`'s "DEBUG:" QA-menu command labels (18), `EditorViewModel`'s E2E-ARRANGE/E2E-PATH `MKLog`/`debugSetActiveOverlayText` harness (25), `SettingsPlaceholderView`'s 500-project perf-seed tool (2), plus one more (`EditorScene` line 631 `debugSetActiveOverlayText`) |
| `placeholder_demo_screen_content` | 8 | `RootView.swift` swatch/panel labels — the WS-01 placeholder root scene, reachable in a shipped build only via a `#if DEBUG` Settings link; superseded demo content, not production UI |
| `screenshot_fixture_test_data` | 6 | `ProjectBrowserView`'s `-mkScreenshotSeedProjects` App-Store-screenshot fixture project names, `#if DEBUG`-gated and explicitly commented "Intended to be reverted after the screenshot pass" |
| `internal_command_label_uncertain_ui_surface` | 3 | `MKBatchCoreCommand`/`ArrangeCommands` `label:` params (`defaultTextColorLabel`, `MKArrangeInteractionAdapter`'s two labels) — no `setActionName`/UndoManager wiring found anywhere in the repo, so no confirmed UI surface displays them |
| `persisted_default_node_name` | 3 | Default `MKNodeCore(name:)` values ("نص" ×2, "سطر") — persisted into `scene.json` as the node's `name` field |
| `test_sample_specimen_text` | 2 | `RootView`'s explicitly-named "WS-01 packet §6 Arabic-correctness fixture" strings (tashkeel/ligature/mixed-numeral specimens) |
| `swiftui_preview_fixture_data` | 1 | `ExportHistorySheet`'s `#Preview` macro argument |
| `specimen_fallback_text` | 1 | `FontBrowserSheet`'s default font-preview sample text |
| `placeholder_glyph_symbol` | 1 | `FormSelectorPopoverView`'s `Text("؟")` fallback-outline glyph |
| `accessibility_glue_only` | 1 | `PaywallView`'s compound accessibility label — punctuation glue over already-covered strings, no fixed content of its own |
| `programmatic_list_separator_char` | 1 | `LicenseFontDetailView`'s `.joined(separator: "، ")` |
| `persisted_value_project_name_suffix` | 1 | `ProjectLibraryProviding`'s duplicate-project " نسخة" suffix, concatenated into the persisted project name |

Every one of these is a judgment call the mission brief asked to make explicit; the reason for
each individual occurrence (not just the category) is in `app-strings-map.json`.

## 3. Uncertain calls, flagged explicitly

- **`internal_command_label_uncertain_ui_surface` (3 occurrences).** Genuinely uncertain whether
  these ever reach a user (they would, if wired to `UndoManager.setActionName`, but no such wiring
  exists in the repo today). Left inline per "when genuinely uncertain, leave it inline and flag
  it" rather than guessing either way.
- **`placeholder_demo_screen_content` (8 occurrences, `RootView.swift`).** `RootView.swift` itself
  is *not* one of the 5 files `ANDROID_SPINE.md` §3.1 names as excluded from the port, so its
  strings were not mechanically skipped — this is a content judgment, not a file-scope one. Its
  content is described in its own doc comment as a scene "WS-13 replaces... with the real
  project-browser shell," reachable in a shipped build only through a `#if DEBUG` Settings link.
  The DEBUG-only *nav label* that routes to it ("شاشة WS-01 الأصلية") was still extracted, mirroring
  Agent 0.4's own precedent of extracting `debug_design_gallery_title` for an equally
  DEBUG-only-reachable link — but the destination screen's own swatch/panel content was left
  inline. If the founder disagrees with drawing that line between "nav label" and "screen content,"
  this is the one call in this pass worth a second look.
- **Sync copy mentions iCloud, not Drive.** `SyncSettingsView.swift` and one `PaywallView.swift`
  comparison-table row hardcode "المزامنة عبر iCloud" / "مزامنة iCloud" — accurate for iOS, but
  Android syncs via Google Drive `appDataFolder` (D-310), not iCloud. These were extracted
  byte-identically per this agent's mandate (verbatim extraction, no rewording), as
  `mk_app_sync_via_icloud_section_header` and `mk_app_compare_row_sync_feature_name`. **Whichever
  Batch 7 UI agent wires Android's sync settings/paywall screens will need founder-approved
  Drive-specific copy for these two keys** — left open because the scope was to extract existing Arabic text.

## 4. Key naming

All 363 new keys follow `mk_app_<snake_case_latin_gloss>` exactly, lowercase ASCII/digits/
underscores only, derived from meaning (mined from the source's own `// Latin gloss: …` comments
and `comment:` parameters where present, otherwise from the Swift property/case name, otherwise
hand-assigned from context — never a transliteration of the Arabic). Verified programmatically:
363 keys, 363 unique, zero collisions, zero regex mismatches against `^[a-z][a-z0-9_]*$`.

Two same-named collisions surfaced during generation (auto-derived slugs for *different* literals
landing on the same short gloss, e.g. two different "contact"/"upgrade"/"free"/"language" strings)
and were given distinct hand-picked names instead of a `_2` suffix — see the "collision fixes"
block in the generation script's manual-override table; none reached the final output.

## 5. Duplicate detection against `android/strings/strings.xml`

50 distinct app-scope literals are byte-identical to a value already in Agent 0.4's 52-key
catalog (87 occurrences total, since several — e.g. `"إغلاق"`, `"إلغاء"`, `"حذف"`, `"تم"` — recur
many times across the app). None were re-added; each occurrence in `app-strings-map.json` carries
`"key": "<existing strings.xml key>"` so downstream agents resolve to the same resource either
way. Two literals worth calling out because they are near-misses, not exact ones, and were
correctly *not* merged: `theme_name_baseline_ink_paper` ("حبر ورق") vs. `RootView.swift`'s "حِبر ،
حِبر وقرطاس" (different literal, extracted separately as `mk_app_baseline_theme_full_name`); and
`GeneralSettingsView`'s AppIconOption `displayName` "حِبر (افتراضي)" (different again, extracted as
`mk_app_app_icon_hibr_default`).

## 6. Round-trip verification

Independent verification (`verify.py`, deliberately re-implementing Android's escape/unescape
rules from scratch rather than re-using the generator's own functions, then reading the *written*
`app-strings.xml` file back off disk): for every one of the 363 extracted keys, the XML value was
unescaped and, for the 20 templated entries, both sides' `\(expr)` / `%N$s`/`%N$d` placeholders
were canonicalized to a common `@N@` marker before comparison — this isolates "did the constant
Arabic text survive" from "the Swift interpolation expression obviously can't appear in the
Android value."

**Result: 363/363 pass, 0 fail.** Also checked: XML parses cleanly via
`xml.etree.ElementTree` (363 `<string>` elements, matching the key count exactly); no stray
unescaped `&` outside a recognized entity in any value; `app-strings-map.json`'s 363 distinct
`extract` keys and `app-strings.xml`'s 363 keys are set-identical in both directions.

## 7. Escaping

Applied to every value, not special-cased: `&`→`&amp;`, `<`/`>`→`&lt;`/`&gt;`, `"`→`&quot;`,
`'`→`\'`, embedded `\n`→literal `\n` escape, backslash→`\\` (done first), and a leading `@`/`?`
prefixed with `\`. None of the 363 values happened to contain an apostrophe or start with `@`/`?`
(checked programmatically), so most of these paths weren't exercised by this dataset, but the
escaper was applied uniformly rather than by inspection, same reasoning Agent 0.4 documented for
`strings.xml`.

## 8. Format-string placeholders

20 of the 363 extracted keys came from Swift string interpolation (`\(expr)`) and were converted
to Android format specifiers: `%1$s` for text-valued expressions (names, elapsed-time
descriptions, pre-formatted Arabic-Indic digit strings from `MKRTLUtilities.toArabicIndicDigits`),
`%1$d` for raw numeric expressions (`width`, `height`, `percent`, `coverage.ranges.count`). Example:
`"قبل \(digits(minutes)) دقيقة"` → `<string name="mk_app_relative_date_minutes_ago_format">قبل
%1$s دقيقة</string>`. The original Swift expression text (e.g. `digits(minutes)`) is preserved in
`app-strings-map.json`'s `literal` field for traceability; it cannot and does not appear in the
Android resource, by definition.

## Acceptance checklist

- [x] Every distinct Arabic string literal in `Makhtoot/**/*.swift` enumerated and classified
      (702 raw occurrences / 548 naive-distinct, refined to 483 real code literals — see §1)
- [x] `android/strings/app-strings.xml` created, additive, does not duplicate any `strings.xml` key
- [x] `android/strings/strings.xml` untouched
- [x] `android/strings/app-strings-map.json` created — one entry per occurrence examined, extracted
      or not, with classification and reason
- [x] Key convention `mk_app_<snake_case_latin_gloss>` followed exactly, 363/363 unique
- [x] XML validated (`xml.etree.ElementTree`, 363 elements, no parse errors)
- [x] Round-trip verified independently: **363/363 pass, 0 fail**
- [x] No Swift source file modified
- [x] Only the three permitted files created: this impl log, `app-strings.xml`,
      `app-strings-map.json`

## Blockers

None.
