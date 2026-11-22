# Android Port — Batch 0 Task Packets

Batch 0 · Theme: **Extraction from iOS** (parity matrix, golden fixtures, API surface,
strings/tokens/assets, decision-doc amendment) · Gate: **G0**

Source of truth for behaviour is the shipped Swift code (repo `main`): 38,080 LOC / 269 files
across the 16 `MakhtootKit` library targets, 16,227 LOC / 60 files in the `Makhtoot` app target
(a separate 678 LOC / 7 files in `MakhtootUITests` — the two are not the same figure and must be
kept apart, per spine §0), 26,771 LOC of tests, 1,101 passing tests, zero skips. This batch is
the only one besides Batch 9 permitted to touch
anything outside `android/` — it runs entirely against the Swift codebase and produces the
artefacts every later batch depends on. Read `CLAUDE.md`, `FOUNDATION.md` and
`ANDROID_SPINE.md` in full before starting any agent below; every `D-3xx` id, module name and
file path here is frozen by the spine.

Dispatch all five agents in one message — they run concurrently. None of them depends on
another Batch 0 agent's *output* (0.1–0.4 all read the same Swift tree independently; 0.5 reads
only doc files), so there is no ordering constraint inside the batch, only the file-ownership
matrix at the end.

---

### Batch 0 · Agent 0.1 — Parity matrix (319 R-ids × iOS status)

**Depends on:** none — first batch · **Parallel-safe with:** every other Batch 0 agent

**Mission.** Extract all 319 `R-<section>.<n>` requirement ids from `PRD.md` (count
independently — see Tasks) and produce `android/PARITY_MATRIX.md`, the single checked-in
ratchet that every later batch (through Batch 8.7 and 9.5) updates and that G8 requires to show
319/319 ✅. Every requirement gets an Android target module and target batch.agent so no later
agent has to re-derive scope from prose. **Completeness is this agent's core deliverable, not a
nice-to-have**: an earlier register left 102 of the 319 ids cited by no packet at all, and this
agent is what closes that gap — every single id must land a non-empty target batch.agent, none
may be silently skipped. The register is now **66 agents** with letter-suffixed splits
(`3.1a`/`3.1b`, `5.2a`/`5.2b`, `5.4a`/`5.4b`, `5.5a`/`5.5b`, `5.7a`/`5.7b`, `6.3a`/`6.3b`,
`7.3a`/`7.3b` — spine §5.2), so every target batch.agent value assigned here must use those ids,
never the unsplit parent number alone.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `PRD.md` | Source of the 319 `R-<section>.<n>` ids and their requirement text |
| `AUDIT_2026-07-28.md` §5 "Feature Completeness & Functionality" | FC-1 (bold/italic wiring) and FC-2 (export gate bypass) — both now fixed on iOS in Wave 1, work item 1.1 (commit `ec9887c` in `EXECUTION_PLAN_2026-07-28.md`) — record the *current*, fixed iOS status, and call out explicitly that Android must ship the fix, not the original bug |
| `ANDROID_SPINE.md` §3 | Frozen module map — the Android target module and Kotlin package for every R-id |
| `ANDROID_SPINE.md` §5 | Frozen batch/agent register — the target batch.agent for every R-id |
| `FOUNDATION.md` §2, §11 | iOS module map and canonical document outlines, for locating each requirement's implementing file(s) |
| `FILE_MAP.md` | Where iOS code for a given feature area lives, to speed up the file-location column |
| `MakhtootKit/Sources/**`, `Makhtoot/AppShell/**` | Ground truth for "iOS implementing file(s)" and "iOS status" — the executable spec, not the prose docs, per spine §0 |

**Owns (creates or edits — no other agent may touch these).**
- `android/PARITY_MATRIX.md` (new)
- `android/docs/impl-log/BATCH-0.1.md` (new)

**Never touch.** Any Swift source file (read-only). Any other `android/**` path — those belong to
0.2/0.3/0.4. The four decision documents (`DECISIONS_LOG.md`, `FOUNDATION.md`, `CLAUDE.md`,
`PROJECT_DESCRIPTION.md`) — those are 0.5's alone.

**Port map.** Not applicable — this agent produces a cross-reference matrix from existing prose
and source, it does not port Swift to Kotlin.
| Input | Output |
|---|---|
| `PRD.md` (319 `R-<section>.<n>` ids) | One matrix row per id |
| `AUDIT_2026-07-28.md` §5 (FC-1, FC-2) | Cross-reference footnote on affected rows |

**Tasks.**
1. `grep -oE 'R-[0-9]+\.[0-9]+' PRD.md | sort -u | wc -l` — confirm the count is exactly 319
   before writing anything; if it is not, note the actual count in the impl log and use the
   real count (the spine's "319" is the expected value, not a license to fabricate rows to hit
   it).
2. For each id, record: id, one-line requirement summary (paraphrased, not copied verbatim —
   copyright discipline applies to internal docs too), iOS implementing file(s) (real paths),
   iOS status (`✅ shipped` / `⚠️ shipped with known gap` / `❌ missing`), Android target module
   (from spine §3's Gradle module column), target batch.agent (from spine §5's register, using
   the post-split letter-suffixed id — e.g. `5.7a` or `5.7b`, never a bare `5.7` — wherever the
   requirement's owning agent is one of the seven split agents), Android status (always starts
   `⬜`). Do not leave any id's target batch.agent blank — if a requirement does not map cleanly
   to one agent's stated scope, assign the closest owning agent and note the judgment call in the
   impl log rather than leaving the cell empty.
3. Cross-reference `AUDIT_2026-07-28.md` §5: the R-ids implemented by
   `Makhtoot/AppShell/Scenes/Editor/EditorViewModel.swift`'s bold/italic and export-sharing
   paths must be marked `⚠️→✅ (FC-1/FC-2 fixed Wave 1, ec9887c)` with a one-line note that
   Android's Batch 5.6/5.7 and Batch 8 must ship the corrected behaviour, never the pre-fix
   bug — Android has no "bug-compatible" excuse since it is written after the fix landed.
4. Group the matrix by PRD section for readability (a section-header row per `§` is fine); keep
   one row per id inside each group.
5. Add a short header block above the table: total count, count by iOS status, count by target
   batch, and the instruction "Android status column is updated in place by every batch from 2
   onward; Batch 8.7 and 9.5 are the ones that must show 319/319 ✅."

**Acceptance.**
- `grep -oE 'R-[0-9]+\.[0-9]+' android/PARITY_MATRIX.md | sort -u | wc -l` equals the verified
  PRD count (319 unless step 1 found otherwise).
- **Completeness, checked by count, not by spot-check**: every one of the 319 ids has a
  non-empty Android target module and a non-empty target batch.agent cell — run
  `grep -c '⬜\|✅\|⚠️' android/PARITY_MATRIX.md`-style row-completeness check (or equivalent) and
  confirm the row count equals 319 with zero blank target-module/target-batch.agent cells. This
  is the specific defect being closed: an earlier register left 102 of the 319 ids cited by no
  packet at all, and 0 (not "close to 0") is the acceptance bar here.
- Every target batch.agent value that names one of the seven split agents uses its letter suffix
  (`3.1a`/`3.1b`, `5.2a`/`5.2b`, `5.4a`/`5.4b`, `5.5a`/`5.5b`, `5.7a`/`5.7b`, `6.3a`/`6.3b`,
  `7.3a`/`7.3b`), never the bare parent number.
- Every FC-1/FC-2-affected row carries the fixed-not-buggy cross-reference.
- Requirements covered: all (this agent's output *is* the requirement coverage index).
- No Swift file was modified (`git status` shows no changes outside `android/`).

**Impl log.** `android/docs/impl-log/BATCH-0.1.md`

---

### Batch 0 · Agent 0.2 — Golden-fixture exporter (Swift)

**Depends on:** none — first batch · **Parallel-safe with:** every other Batch 0 agent

**Mission.** Add a Swift executable target `MKGoldenExport` to `MakhtootKit/Package.swift` that
runs the shipped engines against canonical inputs and dumps deterministic JSON + PNG goldens to
`android/fixtures/`. This is the acceptance oracle for every later engine-porting batch (D-324)
— Batches 3–5 and Batch 8.2/8.3 diff their Kotlin output against these files, not against
prose.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Tests/Fixtures/fixture-arabic-basic.makhtoot` | Canonical small scene |
| `MakhtootKit/Tests/Fixtures/fixture-arranged-la.makhtoot` | Canonical Arrange Mode scene (لا ligature) |
| `MakhtootKit/Tests/Fixtures/fixture-100-nodes.makhtoot` | Mid-size scene |
| `MakhtootKit/Tests/Fixtures/fixture-5000-nodes.makhtoot` | Large scene (perf-adjacent, also a codec/migrator case) |
| `PRD.md` "Canonical Arabic test fixtures" (line ~31) | The canonical Arabic text corpus to shape across all 45 families |
| `MakhtootKit/Tests/MKTextEngineTests/**` | Existing shaping/joining/ligature/mark test cases and assertions to mirror as golden inputs |
| `MakhtootKit/Tests/MKArrangeTests/**` | Existing derive/decompose/recompose/revert test cases |
| `MakhtootKit/Tests/MKPathTextTests/**` | Existing arc-length/placement test cases and Bézier path fixtures |
| `MakhtootKit/Tests/MKModelTests/**`, `MakhtootKit/Tests/MKPersistenceTests/**` | Scene codec round-trip and `MKSceneMigrator` migration-chain cases |
| `MakhtootKit/Tests/MKRenderTests/**`, `MakhtootKit/Tests/MKExportTests/**` | Render/export golden inputs, existing pixel-comparison harness patterns |
| `MakhtootKit/Sources/MKFonts/Resources/Fonts/**` (45 families) | The bundled font catalog the shaping/joining/ligature goldens must cover exhaustively |
| `EXECUTION_PLAN_2026-07-28.md` ground rule 3 | The `swift test --no-parallel` Core Text/XCTest parallel-testing wedge — this exporter must document the same constraint |

**Owns (creates or edits — no other agent may touch these).**
- `MakhtootKit/Package.swift` (add the `MKGoldenExport` executable target and its target
  dependencies only — do not touch any other target declaration)
- `MakhtootKit/Sources/MKGoldenExport/**` (new)
- `android/fixtures/**` — **all subdirectories except `android/fixtures/resources/`**, which
  0.4 owns. This agent's output tree: `android/fixtures/shaping/`, `android/fixtures/joining/`,
  `android/fixtures/ligature/`, `android/fixtures/marks/`, `android/fixtures/arrange/`,
  `android/fixtures/pathtext/`, `android/fixtures/scenecodec/`, `android/fixtures/render/`,
  `android/fixtures/export/`
- `android/docs/impl-log/BATCH-0.2.md` (new)

**Never touch.** Any file under `MakhtootKit/Sources/` outside the new `MKGoldenExport` target
(read-only access to the real engines via the package's existing library products). Any
`MakhtootKit/Tests/**` file (read-only — reuse the fixtures, do not modify the tests).
`android/fixtures/resources/**` (0.4's).

**Port map.** Not a Swift→Kotlin port — this agent invokes the existing Swift engines and
serializes their output as fixtures for later Kotlin ports to match.
| Golden category | Reads (Swift engine) | Output |
|---|---|---|
| (a) Shaping — glyph ids, positions, advances, cluster→codepoint map, bidi levels, RTL run flags | `MKTextEngine/MKShapingEngine.swift` (239 LOC), `ShapedModels.swift` (229), `ClusterMap.swift` (187), `BidiMap.swift` (84) | `android/fixtures/shaping/<family>/<corpus-id>.json` — canonical corpus × all 45 families |
| (b) ZWJ joining-form harvest per letter per family | `MKTextEngine/JoiningAnalyzer.swift` (81), `JoiningTypeTable.swift` (106), `FormResolver.swift` (183) | `android/fixtures/joining/<family>.json` |
| (c) Ligature detect/decompose/recompose | `MKTextEngine/LigatureDetector.swift` (110), `MKArrange/LigatureDecomposer.swift` (361) | `android/fixtures/ligature/<family>/<case-id>.json` |
| (d) Mark attachment offsets incl. Qur'anic annotation range U+06D6–06ED | `MKTextEngine/MarkAttachment.swift` (129), `MarkClassifier.swift` (104), `CursiveAttachment.swift` (254) | `android/fixtures/marks/<family>/<case-id>.json` |
| (e) Arrange derivation snapshots | `MKArrange/ArrangeDeriver.swift` (572), `ArrangeInvariants.swift` (119) | `android/fixtures/arrange/<fixture-name>.json` — one per `Tests/Fixtures/*.makhtoot` scene |
| (f) Path-text placement for a set of Bézier paths | `MKPathText/PathLayoutEngine.swift` (462), `ArcLengthLUT.swift` (218), `PathGlyphPlacement.swift` (160) | `android/fixtures/pathtext/<path-id>.json` |
| (g) Scene-codec round trips + every `MKSceneMigrator` case | `MKModel/Schema/SceneCodec.swift` (121), `Schema/MKSceneMigrator.swift` (80) | `android/fixtures/scenecodec/<case-id>.json` |
| (h) Render PNG goldens | `MKRender/SceneRenderer.swift` (125), `SnapshotRenderer.swift` (97) | `android/fixtures/render/<fixture-name>.png` |
| (i) Export byte-goldens for PNG/JPEG/SVG/PDF where deterministic | `MKExport/ExportCoordinator.swift` (397), `SVGSerializer.swift` (400), `PDFVectorExporter.swift` (81) | `android/fixtures/export/<fixture-name>.<ext>` |

**Tasks.**
1. Add `.executableTarget(name: "MKGoldenExport", dependencies: ["MKFoundation", "MKModel",
   "MKTextEngine", "MKArrange", "MKPathText", "MKRender", "MKColor", "MKExport", "MKFonts",
   "MKPersistence"])` to `Package.swift`, alongside (not replacing) the existing target list.
2. Build the canonical Arabic corpus from `PRD.md`'s "Canonical Arabic test fixtures" section;
   drive it through `MKShapingEngine` for all 45 bundled families, dumping glyph ids, positions,
   advances, cluster→codepoint maps, bidi levels and RTL run flags as sorted-key, no-timestamp
   JSON.
3. Harvest ZWJ joining forms per letter per family (letter × {isolated, initial, medial, final}
   × family), reusing `JoiningAnalyzer`/`FormResolver`'s existing logic — do not reimplement
   joining-type lookup, call the shipped code.
4. Dump ligature detect/decompose/recompose results and mark-attachment offsets (incl. the
   U+06D6–06ED Qur'anic range) the same way.
5. Load each of the 4 `Tests/Fixtures/*.makhtoot` scenes, run `ArrangeDeriver`, and dump the
   derivation snapshot (pre-arrange scene → arranged composition) for each.
6. Construct a small set of representative Bézier paths (straight, curved, closed) and dump
   path-text placement results for a sample of glyph runs along each.
7. Round-trip each fixture scene through `SceneCodec` and, separately, run every migration case
   `MKSceneMigrator` currently handles, dumping input/output pairs.
8. Render each fixture scene to a PNG golden via `SceneRenderer`/`SnapshotRenderer`.
9. Export each fixture scene through `ExportCoordinator` for PNG/JPEG/SVG and vector PDF, saving
   byte-goldens only for the deterministic formats (note in the impl log which format(s), if
   any, are excluded and why — e.g. JPEG's encoder may not be byte-deterministic run-to-run).
10. Run the exporter twice in a row and diff `android/fixtures/` — it must be byte-identical
    both runs (no timestamps, no non-deterministic map ordering, sorted JSON keys). This is
    G0's explicit check.
11. Document the `swift test --no-parallel` wedge (Core Text/XCTest parallel-testing hang) in
    the executable's own top-of-file comment and in the impl log, since anyone re-running this
    target inside a test-like harness will hit the same issue.

**Acceptance.**
- `swift run MKGoldenExport` (from `MakhtootKit/`) succeeds and populates all nine
  `android/fixtures/` subdirectories listed in the port map.
- Running it a second time produces a byte-identical tree (`git status` shows no diff after a
  second run, or a diff tool confirms identical bytes).
- `cd MakhtootKit && swift build --no-parallel` still succeeds with the new target added.
- Requirements covered: `R-*` shaping/arrange/pathtext/persistence/render/export sections (see
  `android/PARITY_MATRIX.md` once 0.1 lands — this agent does not itself update that file).
- Fixtures consumed: none (this agent produces fixtures, it does not consume Android-side ones).

**Impl log.** `android/docs/impl-log/BATCH-0.2.md`

---

### Batch 0 · Agent 0.3 — Public API surface dump

**Depends on:** none — first batch · **Parallel-safe with:** every other Batch 0 agent

**Mission.** Write `Scripts/android/dump-api-surface.sh` and run it to produce
`android/API_SURFACE.md`: every `public`/`open` symbol across all 16 `MakhtootKit` targets, with
full signature, grouped by target and source file. Batch 1 · Agents 1.3 and 1.4 generate every
Kotlin contract stub directly from this file — it must be complete and mechanically parseable,
not a prose summary.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `MakhtootKit/Sources/**/*.swift` (all 16 targets, 38,080 LOC) | The symbols to enumerate |
| `MakhtootKit/Package.swift` | Target list and dependency edges, to group the output correctly |
| `ANDROID_SPINE.md` §3 | Target → Gradle module / Kotlin package mapping, so the dump can be organized the same way Batch 1 will consume it |

**Owns (creates or edits — no other agent may touch these).**
- `Scripts/android/dump-api-surface.sh` (new)
- `android/API_SURFACE.md` (new, generated output — checked in, not gitignored, since G0 checks
  its content directly)
- `android/docs/impl-log/BATCH-0.3.md` (new)

**Never touch.** Any file under `MakhtootKit/Sources/` (read-only). `Scripts/*.sh` at the repo
root (those are the iOS ratchets; this is a new script under `Scripts/android/`, not an edit to
an existing one). Any other `android/**` path.

**Port map.** Not a Swift→Kotlin port — this agent enumerates the Swift public surface that
Batch 1's 1.3/1.4 will each port from.
| Swift target | LOC | Files | Notes |
|---|---|---|---|
| `MKFoundation` | 1,234 | 15 | Leaf — entitlement protocol, geometry, error types, feature flags |
| `MKModel` | 2,176 | 15 | Scene graph, arranged-composition types, codec, migrator |
| `MKTextEngine` | 2,195 | 17 | Shaping core — heaviest cross-reference to `:mk-native` (D-303) |
| `MKArrange` | 2,078 | 11 | Arrange Mode derivation/decompose/recompose |
| `MKPathText` | 1,945 | 9 | Path-text layout |
| `MKCanvas` | 6,580 | 29 | Largest target — gestures, session, inspector, layers |
| `MKRender` | 3,603 | 23 | Drawers, layer tree, caches, degradation ladder |
| `MKColor` | 467 | 4 | CMYK/ICC — cross-reference to `:mk-native` lcms2 binding |
| `MKExport` | 3,342 | 22 | Raster/SVG/PDF exporters, gate, presets |
| `MKFonts` | 2,480 | 21 | Registry, validator, coverage, catalog, downloader |
| `MKPersistence` | 3,283 | 19 | Document package, journal, crash recovery, undo stack |
| `MKSync` | 1,945 | 10 | CloudKit engine → maps to Drive engine on Android |
| `MKStore` | 1,668 | 18 | StoreKit 2 → maps to Play Billing on Android |
| `MKAnalytics` | 1,004 | 13 | Consent, counters, uploader |
| `MKDesignSystem` | 1,405 | 19 | Tokens, 5 themes, Compose-bound components |
| `MKAssets` | 2,675 | 24 | Generators, library, provenance, thumbnails |
| **Total** | **38,080** | **269** | verified 2026-07-30 by direct `find`/`wc` against `main` (spine §0) — not 267; `MKRender` is 23 files and `MKAssets` is 24, both previously under-counted by one. This total is the mechanical input to Batch 1's contract-stub file count (1.3 + 1.4 module scope); an undercount here means missing stub files in that batch. |

**Tasks.**
1. Write `Scripts/android/dump-api-surface.sh` as a `swift-syntax`-free, `grep`/`awk`-based
   extractor (mirror the style of the existing `Scripts/*.sh` ratchets — see
   `Scripts/check-localization.sh` for the house pattern of a documented, single-purpose,
   exit-code-driven shell script) that finds every line matching `public ` or `open ` at
   declaration position (`func`, `var`, `let`, `struct`, `class`, `enum`, `protocol`,
   `typealias`, `init`) inside `MakhtootKit/Sources/**/*.swift`, and prints the full signature
   (multi-line signatures joined onto one logical entry).
2. Group output by target (in the order shown in the port-map table above), then by source
   file, then by declaration order within the file.
3. For each symbol, include: target, source file, line number, kind (func/var/struct/etc.),
   full signature.
4. Cross-reference `ANDROID_SPINE.md` §3 to prefix each target's section with its Gradle module
   and Kotlin package (e.g. `MKArrange → :mk-arrange → net.binjamshid.makhtoot.mk.arrange`) so
   1.3/1.4 do not have to re-look-up the mapping per symbol.
5. Run the script and commit its output to `android/API_SURFACE.md`.
6. Spot-check completeness: `grep -c '^public\|^    public\|open ' MakhtootKit/Sources/**/*.swift`
   (approximate) against the count of entries the script produced, and note any known
   false-negative pattern (e.g. multi-line generic constraints) in the impl log rather than
   silently under-counting.

**Acceptance.**
- `bash Scripts/android/dump-api-surface.sh` runs clean (exit 0) and its output matches
  `android/API_SURFACE.md` byte-for-byte (i.e. the checked-in file is not hand-edited afterward).
- All 16 targets appear as sections, each non-empty.
- Every entry has target, file, line, kind, and a real signature — zero `<symbol>` placeholders.
- Requirements covered: enables `R-*` port-map traceability for every Batch 1–7 agent (indirect;
  this agent does not close any R-id itself).

**Impl log.** `android/docs/impl-log/BATCH-0.3.md`

---

### Batch 0 · Agent 0.4 — Strings, theme tokens and asset extraction

**Depends on:** none — first batch · **Parallel-safe with:** every other Batch 0 agent

**Mission.** Convert every Arabic UI string, design-system token and licensed/catalog asset from
the iOS side into the flat files Batch 2 (`mk-designsystem`), Batch 6.5 (`mk-fonts` catalog) and
`:app` string resources will consume, so no later agent has to re-derive them from Swift source.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `Makhtoot/Resources/Localizable.xcstrings` | Every Arabic UI string (keys are the Arabic source text — single-catalog app, D-100/D-475) |
| `MakhtootKit/Sources/MKDesignSystem/MKTheme.swift`, `MKTypeRamp.swift`, `MKSpacing.swift`, `MKMotion.swift` | Cross-theme token shapes (color roles, type ramp, spacing scale, motion durations) |
| `MakhtootKit/Sources/MKDesignSystem/Themes/HibrTheme.swift`, `KufiTheme.swift`, `NaqshTheme.swift`, `RamlTheme.swift`, `TayfTheme.swift` | The 5 concrete theme token sets (حبر، كوفي، نقش، رمل، طيف) |
| `MakhtootKit/Sources/MKFonts/Resources/Fonts/**` (45 families, 87 font files) | Bundled-font catalog to map to Android asset paths |
| `MakhtootKit/Sources/MKFonts/Resources/Fonts/_PROHIBITED.md` | KFGQPC/Uthmani exclusion list — D-120, binding on Android too |
| `MakhtootKit/Sources/MKFonts/Resources/EXCLUDED_FONTS.md` | Additional exclusion record, cross-reference against `_PROHIBITED.md` |
| `MakhtootKit/Sources/MKFonts/Resources/LicenseRecords/records.json` | Per-family licence records (OFL, etc.) |
| `MakhtootKit/Sources/MKFonts/Resources/catalog-seed.json`, `PremiumCatalog/catalog-manifest-v1.json` | Bundled + premium catalog manifests |
| `MakhtootKit/Sources/MKAssets/Resources/assets-manifest.json`, `provenance-records.json` | Asset library manifest and provenance records |
| `MakhtootKit/Sources/MKExport/Resources/presets.json` | Export preset definitions |

**Owns (creates or edits — no other agent may touch these).**
- `android/strings/strings.xml` (new)
- `android/strings/theme-tokens.json` (new)
- `android/strings/font-manifest.json` (new)
- `android/fixtures/resources/**` (new — copies of `assets-manifest.json`,
  `provenance-records.json`, `presets.json`, `catalog-seed.json`, `catalog-manifest-v1.json`;
  this is the **only** subpath under `android/fixtures/` this agent owns — everything else
  under `android/fixtures/` belongs to 0.2)
- `android/docs/impl-log/BATCH-0.4.md` (new)

**Never touch.** Any Swift source file (read-only). `android/fixtures/**` outside the
`resources/` subdirectory (0.2's). `android/API_SURFACE.md`, `android/PARITY_MATRIX.md`.

**Port map.** Not a Swift→Kotlin port — this agent converts data files, not code.
| Source | Output | Notes |
|---|---|---|
| `Makhtoot/Resources/Localizable.xcstrings` | `android/strings/strings.xml` | Keys preserved, Arabic values verbatim, plurals → `<plurals>` |
| `MKTheme.swift` + `MKTypeRamp.swift` + `MKSpacing.swift` + `MKMotion.swift` + 5 `Themes/*.swift` | `android/strings/theme-tokens.json` | Colors, type ramp, spacing, radii, motion — one object per theme (حبر/كوفي/نقش/رمل/طيف) plus the shared shape definitions |
| `MKFonts/Resources/Fonts/**` (45 families / 87 files) + `LicenseRecords/records.json` | `android/strings/font-manifest.json` | Family → Android asset path (`android/app/src/main/assets/fonts/<family>/<file>`) + licence record per D-316 |
| `MKAssets/Resources/assets-manifest.json` | `android/fixtures/resources/assets-manifest.json` | Verbatim copy |
| `MKAssets/Resources/provenance-records.json` | `android/fixtures/resources/provenance-records.json` | Verbatim copy |
| `MKExport/Resources/presets.json` | `android/fixtures/resources/presets.json` | Verbatim copy |
| `MKFonts/Resources/catalog-seed.json` | `android/fixtures/resources/catalog-seed.json` | Verbatim copy |
| `MKFonts/Resources/PremiumCatalog/catalog-manifest-v1.json` | `android/fixtures/resources/catalog-manifest-v1.json` | Verbatim copy |

**Tasks.**
1. Parse `Localizable.xcstrings` (JSON) and emit `android/strings/strings.xml` with one
   `<string name="…">` per key (Arabic value verbatim, no re-translation, no re-wording) and
   `<plurals>` for any key with plural variants. Preserve the original key as the Android
   resource name (sanitized to a valid Android resource identifier only where the xcstrings key
   itself is not already valid — note every sanitization in the impl log so nothing silently
   diverges).
2. Extract every token from `MKTheme.swift`'s shared shape plus each of the 5 concrete theme
   files into `android/strings/theme-tokens.json`: one top-level object per theme
   (`hibr`/`kufi`/`naqsh`/`raml`/`tayf`) each with `colors`, `typeRamp`, `spacing`, `radii`,
   `motion` sub-objects mirroring the Swift property names 1:1 so Batch 2.4 can map them
   directly onto Compose `CompositionLocal`s without re-deriving values.
3. Build `android/strings/font-manifest.json`: for each of the 45 families, list its font
   file(s), Android asset path under `android/app/src/main/assets/fonts/<family>/`, and its
   licence record pulled from `records.json`. Cross-check every family against
   `_PROHIBITED.md` and `EXCLUDED_FONTS.md` — any font listed as prohibited (KFGQPC/Uthmani
   fonts, D-120) must be **excluded from the manifest entirely**, not merely flagged, and the
   exclusion must be noted in the impl log with the reason quoted from `_PROHIBITED.md`.
4. Copy the five manifest/provenance/preset JSON files verbatim into
   `android/fixtures/resources/`, byte-identical to their Swift-side originals (these are inputs
   Batch 5.5/5.6/6.5 consume as-is, not derived data — no reformatting).
5. Note in the impl log the exact font-file and family count found on disk. The verified,
   expected result is 87 font files across 45 families (family-only directories — marker
   files such as `_PROHIBITED.md` and `EXCLUDED_FONTS.md` are not families and must not be
   counted). If the tree disagrees with this at execution time, fail loudly — stop and flag
   the discrepancy in the impl log rather than silently adjusting the manifest to match.

**Acceptance.**
- `android/strings/strings.xml` is valid XML and contains one entry per `Localizable.xcstrings`
  key (count matches).
- `android/strings/theme-tokens.json` has exactly 5 top-level theme objects, each non-empty.
- `android/strings/font-manifest.json` lists every non-prohibited bundled family; zero entries
  reference a family named in `_PROHIBITED.md`.
- The 5 files under `android/fixtures/resources/` are present and byte-identical to their Swift
  originals (`diff` clean).
- Requirements covered: `R-*` localization, theming and font-catalog sections (see
  `android/PARITY_MATRIX.md` once 0.1 lands).

**Impl log.** `android/docs/impl-log/BATCH-0.4.md`

---

### Batch 0 · Agent 0.5 — Decision-document amendment (D-300…D-325)

**Depends on:** none — first batch · **Parallel-safe with:** every other Batch 0 agent

**Mission.** Write the frozen `D-300`–`D-325` Android decision register (`ANDROID_SPINE.md` §2)
into `DECISIONS_LOG.md` in that file's existing style; amend `FOUNDATION.md` and `CLAUDE.md` so
they stop asserting "no Android port"; add a short `PROJECT_DESCRIPTION.md` note. This is the
**only** agent in Batches 0–8 permitted to edit anything outside `android/`, and it must not
touch a single line of Swift source — it edits prose decision documents only.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `ANDROID_SPINE.md` §1, §2 | The exact FDA-01…08 and D-300…D-325 text to transcribe (verbatim content, not paraphrase — these are frozen) |
| `DECISIONS_LOG.md` | Existing style/format for a decision record (Status/Date/Owner/Context/Decision/Alternatives considered/Consequences/Confidence/Dependencies/Validation trigger) and current max id (`D-231`, confirmed — D-300 is collision-free) |
| `FOUNDATION.md` §1 (D-100), §2 (module map), §10 (Founder Decisions) | Insertion points for the Android amendment pointer, Android module map, and FDA-01…08 |
| `CLAUDE.md` "Platform and scope" and "Never" sections | The exact "iPhone and iPad only. No Android port" and "Localize into other scripts in v1" language to amend |
| `PROJECT_DESCRIPTION.md` | Where a short Android-port status note belongs alongside existing product/positioning content |

**Owns (creates or edits — no other agent may touch these).**
- `DECISIONS_LOG.md` (append `D-300`–`D-325`, in that order, after the current `D-231` /
  "Amended index" tail)
- `FOUNDATION.md` (edit §1, §2, §10; add new §13 "Android platform")
- `CLAUDE.md` (edit "Platform and scope" and "Never" sections only)
- `PROJECT_DESCRIPTION.md` (add one Android-port status note)
- `android/docs/impl-log/BATCH-0.5.md` (new)

**Never touch.** Any file under `MakhtootKit/` or `Makhtoot/` (no Swift source, no resources).
Any path under `android/` — every other Batch 0 agent's output lives there and this agent's job
is exclusively the four decision documents plus its own impl log.

**Port map.** Not applicable — no code is ported. The "port" here is decision-register content
from the frozen spine into the repo's canonical documents.
| Spine section | Target document | Target section |
|---|---|---|
| §1 FDA-01…08 | `FOUNDATION.md` | §10 "Founder Decisions" — appended after FD-07 |
| §2 D-300…D-325 | `DECISIONS_LOG.md` | New entries after D-231, following existing record format |
| §2 D-300…D-325 (summary) | `FOUNDATION.md` | New §13 "Android platform" |
| §3 module map | `FOUNDATION.md` | §2 "Module map" — Android column/subsection added, iOS content unchanged |
| — | `CLAUDE.md` | "Platform and scope" (remove "No Android port, and none is planned for v1"; point at D-3xx register) and "Never" (remove/qualify "Localize into other scripts in v1" only insofar as it conflicts with the Android decision — Arabic-only-UI stays true on both platforms, only the *no-second-platform* claim changes) |
| — | `PROJECT_DESCRIPTION.md` | Short status note: Android port authorized 2026-07-30, tracked via `ANDROID_SPINE.md` / `DECISIONS_LOG.md` D-3xx |

**Tasks.**
1. Transcribe `ANDROID_SPINE.md` §2's `D-300`–`D-325` into `DECISIONS_LOG.md` verbatim in
   content, reformatted into that file's existing per-record shape (Status: accepted; Date:
   2026-07-30; Owner: Android-port authorization run; Context: founder request 2026-07-30
   overrides D-100/CLAUDE.md; Decision: the spine's decision text; Alternatives considered: pull
   from the spine's own rationale, e.g. D-323's KMP/Flutter/RN rejection; Consequences;
   Confidence; Dependencies; Validation trigger — the corresponding gate check from spine §6).
   Do not renumber, merge, split, or drop any of the 26 records.
2. In `FOUNDATION.md` §1, add a short amendment pointer next to D-100: "Amended for Android by
   D-300 (`DECISIONS_LOG.md`) — D-100 remains authoritative for iOS." Do not delete or reword
   D-100 itself.
3. In `FOUNDATION.md` §2, add the Android module map (spine §3's 18-module table) as a clearly
   separated subsection — the existing iOS module map stays untouched.
4. Add a new `FOUNDATION.md` §13 "Android platform" summarizing D-300–D-325 at the same density
   as the existing §1–§9 sections (one paragraph or short list per decision cluster: platform,
   layout, shaping, rendering, persistence/sync, store, fonts/design system,
   localization/accessibility, analytics/referral/distribution) with pointers into
   `DECISIONS_LOG.md` for the full record — do not duplicate the full decision text here.
5. Append FDA-01…FDA-08 to `FOUNDATION.md` §10's Founder Decisions table, same column shape as
   the existing FD-01…FD-07 rows.
6. In `CLAUDE.md`, edit only the two named bullets: replace "iPhone and iPad only. No Android
   port, and none is planned for v1." with language that keeps "iPhone and iPad, and Android"
   as supported platforms and points at the D-3xx register for the Android decision set; do not
   touch the Arabic-only-at-launch bullet (that stays true on Android too, per D-300). In
   "Never," remove or qualify only the platform-count claim, not the "Localize into other
   scripts in v1" line (Arabic-only-UI is unchanged by this port — Android is a new *platform*
   for the same Arabic-only product, not a new *localization*).
7. Add one short note to `PROJECT_DESCRIPTION.md` recording the Android port's authorization
   date and pointing at `ANDROID_SPINE.md` and the D-3xx register — do not rewrite the
   document's existing positioning content.
8. If anything in the spine's D-3xx text appears to conflict with an existing locked `D-1xx`
   beyond what D-300–D-325 already explicitly amends, do not resolve it unilaterally — write it
   as-is (per spine's own top-level instruction) and note the conflict in this agent's impl log
   under a `> **Writer note:**` blockquote, the same convention the spine itself uses.

**Acceptance.**
- `grep -c '^## D-3' DECISIONS_LOG.md` equals 26.
- `DECISIONS_LOG.md`'s existing `D-1xx`–`D-231` records are byte-identical to before this
  agent's edit (append-only).
- `FOUNDATION.md` §13 exists and cross-references every `D-3xx` id at least once.
- `CLAUDE.md` no longer asserts "No Android port" anywhere in the file
  (`grep -n 'No Android port' CLAUDE.md` returns nothing).
- `CLAUDE.md`'s Arabic-only-UI bullet and the module/architecture sections describing
  `MakhtootKit` are otherwise unchanged.
- Requirements covered: none directly (this agent unblocks every later batch's authority to
  write Android code at all).

**Impl log.** `android/docs/impl-log/BATCH-0.5.md`

---

## Appendix — file-ownership matrix (collision proof)

| Path (prefix) | 0.1 | 0.2 | 0.3 | 0.4 | 0.5 |
|---|---|---|---|---|---|
| `android/PARITY_MATRIX.md` | ✅ | | | | |
| `MakhtootKit/Package.swift` | | ✅ (new target only) | | | |
| `MakhtootKit/Sources/MKGoldenExport/**` | | ✅ | | | |
| `android/fixtures/shaping/**` `joining/**` `ligature/**` `marks/**` `arrange/**` `pathtext/**` `scenecodec/**` `render/**` `export/**` | | ✅ | | | |
| `android/fixtures/resources/**` | | | | ✅ | |
| `Scripts/android/dump-api-surface.sh` | | | ✅ | | |
| `android/API_SURFACE.md` | | | ✅ | | |
| `android/strings/strings.xml` | | | | ✅ | |
| `android/strings/theme-tokens.json` | | | | ✅ | |
| `android/strings/font-manifest.json` | | | | ✅ | |
| `DECISIONS_LOG.md` | | | | | ✅ |
| `FOUNDATION.md` | | | | | ✅ |
| `CLAUDE.md` | | | | | ✅ |
| `PROJECT_DESCRIPTION.md` | | | | | ✅ |
| `android/docs/impl-log/BATCH-0.1.md` | ✅ | | | | |
| `android/docs/impl-log/BATCH-0.2.md` | | ✅ | | | |
| `android/docs/impl-log/BATCH-0.3.md` | | | ✅ | | |
| `android/docs/impl-log/BATCH-0.4.md` | | | | ✅ | |
| `android/docs/impl-log/BATCH-0.5.md` | | | | | ✅ |

No file has two owners. `android/fixtures/**` is split at the subdirectory level between 0.2
(all engine-golden categories) and 0.4 (`resources/` only) — the two never write the same path.
0.5 is the sole writer of anything outside `android/` in this batch, confirming spine §4 ground
rule 9's exception.
