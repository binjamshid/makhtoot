# Android Port — Batch 1 Task Packets

Batch 1 · Theme: **Scaffold, native toolchain, contract stubs** · Gate: **G1**

Batch 1 turns Batch 0's extraction artefacts (`android/PARITY_MATRIX.md`,
`android/API_SURFACE.md`, `android/fixtures/**`, `android/strings/**`, D-300…D-325) into a
Gradle project that builds and links against a native shaping stack, with every public symbol
of all 16 `MakhtootKit` targets present as a Kotlin contract stub. This is the batch where the
**18-module** shape of `android/` becomes real and where `Scripts/android/stub-count.sh` starts
reporting a real (large) number that every later batch drives toward zero.

Read `ANDROID_SPINE.md` in full — every module name, package, decision id and file path below
is frozen by it — plus `CLAUDE.md`, `FOUNDATION.md`, and `EXECUTION_PLAN_2026-07-28.md` for
house style before starting any agent. `android/API_SURFACE.md` (Batch 0 · 0.3) is the mechanical
source 1.3 and 1.4 port from; `android/fixtures/**` (Batch 0 · 0.2) is what 1.2's native smoke
tests compare against.

Dispatch all four agents in one message — they run concurrently, gated on G0.

---

### Batch 1 · Agent 1.1 — Gradle scaffold, version catalog, CI and ratchet scripts

**Depends on:** G0 · **Parallel-safe with:** every other Batch 1 agent

**Mission.** Stand up the `android/` Gradle project shell — `settings.gradle.kts` with all 18
modules, the version catalog, convention plugins, the `:app` manifest and locale/backup config,
and the Android siblings of the repo's existing `Scripts/*.sh` ratchets plus the CI workflow —
so 1.2/1.3/1.4 have a project to add source into. This agent owns every module's Gradle
*configuration* file; it does not write a line of Kotlin or C++ source.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `ANDROID_SPINE.md` §3 | Frozen 18-module list, Gradle module names, Kotlin package roots |
| `ANDROID_SPINE.md` §2 D-300, D-301, D-317, D-318, D-321; §1 FDA-07 | minSdk **29** (Android 10, FDA-07 — not 26; the API 26–28 `Picture` + bitmap-cache render fallback is deleted from the plan entirely) / compileSdk·targetSdk 36 / Kotlin 2.1 / AGP 8.7+ / JDK 17 / NDK r27; `android/` Gradle layout; RTL-first + locale pinning; referral debug-only source set |
| `Scripts/check-conflict-files.sh`, `check-localization.sh`, `check-design-tokens.sh`, `check-storekit-ids.sh`, `referral-release-grep.sh`, `stub-source-audit.sh` | House pattern for a documented, single-purpose, exit-code-driven shell ratchet — mirror structure and exit-code discipline, not iOS-specific content |
| `.github/workflows/ci.yml` | House CI header rule: **never add a job you have not run locally and confirmed green** — the same discipline applies to `android-ci.yml` |
| `android/API_SURFACE.md`, `android/PARITY_MATRIX.md` (Batch 0) | Confirms all 16 targets/319 R-ids exist before wiring `stub-count.sh`'s expectations |
| `ANDROID_SPINE.md` §3.2 | The regenerated, corrected 18-module dependency-edge table (from `MakhtootKit/Package.swift`) — an earlier table was wrong for 7 of 17 modules and invented two edges that do not exist (`:mk-export`→`:mk-store`, `:mk-sync`→`:mk-store`); this agent's `build.gradle.kts` files must match §3.2 exactly, not any other document |
| `ANDROID_SPINE.md` §11 | The five glue-artifact specs this agent now owns (`CONTRACT_CHANGES.md` format, `strings.xml` install step, font-asset copy, `dataExtractionRules.xml`/`backup_rules.xml` split, `no-stubs-allowlist.txt`) |
| `android/strings/strings.xml`, `android/strings/font-manifest.json` (Batch 0 · 0.4, staging outputs) | The source this agent installs into `res/values/strings.xml` and copies into `assets/fonts/**` |
| `MakhtootKit/Sources/MKFonts/Resources/Fonts/_PROHIBITED.md`, `EXCLUDED_FONTS.md` | The exclusion lists the font-asset copy step must honour exactly as the iOS bundling step does |

**Owns (creates or edits — no other agent may touch these).**
- `android/settings.gradle.kts` (new)
- `android/gradle/libs.versions.toml` (new)
- `android/gradle.properties` (new)
- `android/build-logic/**` (new — one convention plugin for library modules, one for Compose
  modules, one for the `:app` module)
- `android/build.gradle.kts` (new, root)
- `android/*/build.gradle.kts` — the **Gradle configuration file only** for all 18 modules:
  `mk-foundation`, `mk-model`, `mk-textengine`, `mk-arrange`, `mk-pathtext`, `mk-canvas`,
  `mk-render`, `mk-color`, `mk-export`, `mk-fonts`, `mk-persistence`, `mk-sync`, `mk-store`,
  `mk-analytics`, `mk-designsystem`, `mk-assets`, `mk-native`, `app` — applying the convention
  plugins; **not** any file under any module's `src/`, which belongs to 1.2/1.3/1.4. Per spine
  §17, `android/app/build.gradle.kts` specifically is a declared cross-batch conflict: Agent 1.1
  owns and edits it exclusively through Batch 8 (this is the stated exception window); Agent 9.2
  takes it over in Batch 9 for signing-config/AAB/R8 additions only — that Batch 9 takeover is
  not a violation of this agent's exclusivity, it is the declared resolution.
- `android/app/src/main/AndroidManifest.xml` (new)
- `android/app/src/main/res/xml/locales_config.xml` (new, pinned to `ar` per D-318). Per spine
  §17, this path is a declared cross-batch conflict: Agent 1.1 creates it here in Batch 1; Agent
  7.1 may take it over in Batch 7 only if app-shell locale-picker wiring requires edits, and must
  declare that takeover in its own packet's Owns list — this agent's ownership is not exclusive
  past Batch 1 for this one path.
- `android/app/src/main/res/xml/backup_rules.xml` (new — governs `fullBackupContent` on Android
  11 and below only, restricted to exactly the D-312 trial blob)
- `android/app/src/main/res/xml/dataExtractionRules.xml` (new — governs backup on Android 12+ at
  targetSdk 36; required alongside `backup_rules.xml`, not instead of it, restricted to the same
  D-312 trial blob; specifying only one of the two files means the whole project tree gets backed
  up on whichever API range that file doesn't cover)
- `android/docs/CONTRACT_CHANGES.md` (new — append-only entry format: `date | requesting agent |
  target module | requested change | rationale | status (pending/applied/rejected)`;
  `Scripts/android/gate.sh N` fails if any entry has status `pending`; every gate run gets an
  explicit "apply pending contract changes" step immediately before its own checks re-run)
- `android/app/src/main/res/values/strings.xml` (new — installed from Batch 0 · Agent 0.4's
  staging output `android/strings/strings.xml`, which this agent reads but does not own; before
  this assignment `res/values` appeared zero times in the whole plan, so no `R.string.*` symbol
  would ever have existed for Compose to reference)
- `android/app/src/main/assets/fonts/**` (new — copy of the 87 `.ttf` files across the 45
  bundled families from `MakhtootKit/Sources/MKFonts/Resources/Fonts/`, honouring
  `_PROHIBITED.md` and `EXCLUDED_FONTS.md` exactly as the iOS bundling step does; before this
  assignment all six references to this path across the plan were reads with no writer)
- `Scripts/android/no-stubs-allowlist.txt` (new — the two legitimate, permanent
  `check-no-stubs.sh` matches: `MkNotYetPorted.kt`, which extends `NotImplementedError` by
  construction, and `MkSettingsPlaceholderView.kt`, the pre-existing iOS placeholder screen;
  without this allowlist G8's blocking check can never pass)
- `Scripts/android/gate.sh` (new)
- `Scripts/android/stub-count.sh` (new)
- `Scripts/android/check-no-stubs.sh` (new)
- `Scripts/android/check-localization.sh` (new — Android sibling; the existing
  `Scripts/check-localization.sh` at repo root is iOS-only and untouched)
- `Scripts/android/check-design-tokens.sh` (new — Android sibling)
- `Scripts/android/referral-release-grep.sh` (new — Android sibling; greps a built release AAB)
- `.github/workflows/android-ci.yml` (new)
- `android/docs/impl-log/BATCH-1.1.md` (new)

**Never touch.** Any file under any module's `src/main/**` or `src/test/**` (1.2/1.3/1.4's).
`Scripts/*.sh` at the repo root and `.github/workflows/ci.yml` (iOS-only, unmodified). Any
`android/fixtures/**`, `android/strings/**`, `android/API_SURFACE.md`,
`android/PARITY_MATRIX.md` (Batch 0's, read-only here).

**Port map.** Not a Swift→Kotlin port — this agent stands up build tooling, not application
code. Its closest iOS analogue is the project-scaffold work `Package.swift` + `Makhtoot.xcodeproj`
did in WS-01, adapted to Gradle.
| iOS analogue | Android equivalent | Notes |
|---|---|---|
| `MakhtootKit/Package.swift` (target list + dependency edges) | `android/settings.gradle.kts` (18 `include(...)`) | Dependency edges mirror `FOUNDATION.md` §2 / spine §3, plus every text/glyph module depends on `:mk-native` |
| `Makhtoot.xcodeproj/project.pbxproj` (`Makhtoot` target, `supportsRTL` etc.) | `android/app/src/main/AndroidManifest.xml` + `locales_config.xml` | `supportsRtl="true"`, `resConfigs("ar")`, per-app locale pinned to `ar` (D-318) |
| `Scripts/check-localization.sh` etc. (5 iOS ratchets) | `Scripts/android/*.sh` (6 Android ratchets, incl. `referral-release-grep.sh`) | Same shape (documented, single-purpose, exit-code gated), new content |
| `.github/workflows/ci.yml` | `.github/workflows/android-ci.yml` | Same "never ship a job you haven't run green locally" discipline |

**Tasks.**
1. Write `android/settings.gradle.kts` including all 18 modules from spine §3, with
   `pluginManagement`/`dependencyResolutionManagement` pointed at the version catalog.
2. Write `android/gradle/libs.versions.toml`: Kotlin 2.1, AGP 8.7+, Compose BOM, AndroidX
   (Compose, Room, DataStore, WorkManager, Security-Crypto), Google Play Billing, Google Drive
   v3 REST client, Credential Manager, kotlinx-serialization, OkHttp — per D-304's JVM-side
   list. No analytics SDK dependency, ever (D-304). Also add the entries later batches need and
   that were previously missing from the catalog — since `build.gradle.kts` files are frozen as
   this agent's exclusive scope from Batch 2 onward (`§3.2`), an omission here is unrecoverable
   without a `CONTRACT_CHANGES.md` round-trip: `androidx.exifinterface`, `androidx.tracing`, the
   Paparazzi Gradle plugin + Robolectric, the `android-junit5` plugin, Navigation-Compose, Coil,
   `androidx.benchmark`/macrobenchmark plugin, Espresso + `compose-ui-test-junit4` +
   `androidx.test.runner`, the `androidx.baselineprofile` plugin, `androidx.appcompat`.
3. Write `android/build-logic/` convention plugins: one applying common Kotlin/lint/test config
   to a plain library module, one additionally applying Compose to a UI module, one for the
   `:app` module (application plugin, manifest merging, signing-config placeholder for Batch 9).
4. Write each of the 18 modules' `build.gradle.kts` from the corrected dependency-edge table in
   spine §3.2 (regenerated directly from `MakhtootKit/Package.swift`; a superseded table was
   wrong for 7 of 17 modules and invented a `:mk-export`→`:mk-store` edge and a
   `:mk-sync`→`:mk-store` edge that do not exist — entitlement access from both those modules is
   via `MKEntitlementProviding` in `:mk-foundation`, a dependency every module already has, not a
   direct edge to `:mk-store`). Wire `:mk-native` as a dependency of exactly
   `:mk-textengine`, `:mk-render`, `:mk-export`, `:mk-fonts`, `:mk-color` per §3.2. Do not add a
   `src/` file to any module — that would collide with 1.2/1.3/1.4. **This agent is the sole
   owner of all `build.gradle.kts` files through Batch 8** (the one Batch 9 exception for
   `android/app/build.gradle.kts` is declared above); if a later agent needs a module edge not in
   §3.2, that agent files an `android/docs/CONTRACT_CHANGES.md` entry and the batch gate applies
   it by editing the Gradle file — the requesting agent never edits it directly.
5. Set Gradle JVM/JDK 17 in `android/gradle.properties`; set compileSdk/targetSdk 36, **minSdk 29**
   (FDA-07 — Android 10, not 26) in the convention plugins, not per-module. Consequence: there is
   no API 26–28 code path to scaffold anywhere in this batch — do not add a `Picture` +
   bitmap-cache fallback to the render convention plugin or any module's `build.gradle.kts`;
   `RenderNode` (API 29+) is the only path (D-305). Document `Modifier.blur`'s no-op behaviour
   below API 31 as a known limitation in the impl log (visually verified later, at Batch 8.5).
6. Write `:app`'s manifest: `android:supportsRtl="true"`, `android:allowBackup="true"` with
   **both** `android:fullBackupContent="@xml/backup_rules"` (Android 11 and below) **and**
   `android:dataExtractionRules="@xml/data_extraction_rules"` (Android 12+, which targetSdk 36
   requires separately — specifying only one of the two means the whole project tree is backed up
   on whichever API range the missing file doesn't cover), both restricted to exactly the D-312
   trial blob (name the DataStore file/key the trial agent — Batch 6.2 — will use, and note in
   the impl log that 6.2 must match this name exactly since this agent runs first).
   `locales_config.xml` pinned to `ar` per D-318.
7. Create `android/docs/CONTRACT_CHANGES.md` with the append-only entry format above and a
   one-line usage note at the top of the file; leave it with zero entries (the first real entry
   is filed by whichever later agent first needs a cross-module change).
8. Install Batch 0 · Agent 0.4's staging `android/strings/strings.xml` into
   `android/app/src/main/res/values/strings.xml` (verbatim copy — 0.4 already did the
   `.xcstrings`→Android XML conversion; this agent's job is only the install step that makes
   `R.string.*` symbols exist for Compose to reference).
9. Copy the 87 `.ttf` files across the 45 bundled families from
   `MakhtootKit/Sources/MKFonts/Resources/Fonts/**` into
   `android/app/src/main/assets/fonts/<family>/<file>`, cross-checking every family against
   `_PROHIBITED.md` and `EXCLUDED_FONTS.md` — any prohibited font (KFGQPC/Uthmani, D-120) is
   excluded from the copy entirely, not merely flagged, exactly as Agent 0.4's manifest already
   excludes it. Verify the copied count against `android/strings/font-manifest.json` (0.4's
   staging output) and fail loudly on any mismatch rather than silently copying a stale set.
10. Write `Scripts/android/no-stubs-allowlist.txt` listing the two permanent, legitimate
    `check-no-stubs.sh` matches (`MkNotYetPorted.kt`, `MkSettingsPlaceholderView.kt`) with a
    one-line reason each; wire `check-no-stubs.sh` (task 11 below) to check every match against
    this allowlist before failing.
11. Write the six `Scripts/android/*.sh` ratchets, reading the referenced iOS scripts first and
   mirroring their structure (shebang header comment explaining *why*, single grep/awk-driven
   check, explicit exit code, BASELINE-style ratchet where applicable):
   - `gate.sh` — takes a batch number argument (`bash Scripts/android/gate.sh 1`); first applies
     any pending `android/docs/CONTRACT_CHANGES.md` entries (an explicit "apply pending contract
     changes" step, run before the gate's own checks) and fails the run if any entry is still
     `pending` after that step, then runs that gate's checks per spine §6 (for G1: `assembleDebug`
     on all 18 modules, `:mk-native` smoke test on the three listed ABIs, publish stub count).
   - `stub-count.sh` — greps `throw MkNotYetPorted(` across `android/*/src/main/kotlin/**`,
     prints the count. (Returns a large positive number after this batch — that is correct; it
     must reach 0 only at G8.)
   - `check-no-stubs.sh` — greps for `TODO(`, `NotImplementedError`, `notYetPorted`, `قريبًا`,
     `coming soon`, `Placeholder`; checks every hit against `Scripts/android/no-stubs-allowlist.txt`
     (task 10) before failing, since `MkNotYetPorted.kt`/`MkSettingsPlaceholderView.kt` will always
     match otherwise; advisory (non-blocking exit code) from G1, blocking from G8 per spine ground
     rule 3 — implement the severity switch as a flag or gate-number argument.
   - `check-localization.sh` — Android sibling of the iOS ratchet: flags a Latin-lettered,
     non-Arabic-script string literal inside a shipping Composable.
   - `check-design-tokens.sh` — Android sibling: flags a raw `Color(...)`/hex literal bypassing
     `MkTheme`'s `CompositionLocal`.
   - `referral-release-grep.sh` — greps a built release AAB (once one exists, Batch 9) for
     referral strings/classes; exits cleanly with a documented "no AAB yet" skip before Batch 9,
     matching the iOS script's own "not runnable pre-archive" pattern noted in `ci.yml`.
12. Write `.github/workflows/android-ci.yml` mirroring `ci.yml`'s header discipline (a top
    comment stating what was and was not run locally, and why); only include jobs actually run
    locally and confirmed green during this agent's own work (e.g. `assembleDebug`,
    `stub-count.sh`, `check-no-stubs.sh` in advisory mode) — do not include jobs (like the full
    `gate.sh 8` invocation) that cannot possibly be green this early.

**Acceptance.**
- `cd android && ./gradlew help` succeeds and lists all 18 modules.
- `./gradlew :mk-foundation:build` (and equivalently for a couple of other modules) does not
  fail for *configuration* reasons (it may still fail to compile until 1.3/1.4 land source —
  note in the impl log exactly what error state is expected/acceptable at this point).
- `bash Scripts/android/stub-count.sh` runs without error (prints 0 or an error-free "no
  sources yet" state, since no Kotlin source exists until 1.3/1.4 land — document this ordering
  dependency explicitly).
- `android/app/src/main/AndroidManifest.xml`, `locales_config.xml`, `backup_rules.xml` and
  `dataExtractionRules.xml` all validate as XML and contain the RTL/locale/backup settings above.
- `android/app/src/main/res/values/strings.xml` is installed and its entry count matches
  `android/strings/strings.xml` (0.4's staging output).
- `android/app/src/main/assets/fonts/**` contains exactly the 87 `.ttf` files across 45 families
  listed in `android/strings/font-manifest.json`, zero prohibited fonts present.
- `android/docs/CONTRACT_CHANGES.md` exists with the documented format and zero entries.
- `Scripts/android/no-stubs-allowlist.txt` exists and lists exactly the two named legitimate
  matches.
- Requirements covered: infrastructure only — no `R-id` closes here (see
  `android/PARITY_MATRIX.md`).

**Impl log.** `android/docs/impl-log/BATCH-1.1.md`

---

### Batch 1 · Agent 1.2 — Native toolchain: HarfBuzz + FreeType + lcms2 + hb-subset + JNI facade

**Depends on:** G0 · **Parallel-safe with:** every other Batch 1 agent

**Mission.** Stand up `android/mk-native/`: vendored HarfBuzz/FreeType/lcms2 under
`third_party/`, a single JNI facade exposing shaping/outlines/font-table access/subsetting/ICC
transform, Kotlin `external fun` declarations plus a safe wrapper layer with explicit native
lifetime management, and a smoke test comparing shaping output against Batch 0's golden
fixtures. This is the D-303/D-304/D-315 foundation every text-shaping and colour module depends
on.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `ANDROID_SPINE.md` §2 D-303, D-304, D-315, D-316 | Shaping stack (HarfBuzz/FreeType/ICU BiDi), vendoring location and licence obligations, lcms2 colour path, `AssetManager` fd → `hb_blob` font-loading path |
| `android/fixtures/shaping/**`, `joining/**`, `ligature/**`, `marks/**` (Batch 0 · 0.2) | The golden outputs the smoke test compares against |
| `MakhtootKit/Sources/MKTextEngine/MKShapingEngine.swift` | The Core Text call sequence and output shape (glyph ids, positions, advances, cluster map, bidi levels) that HarfBuzz's `hb_shape` must reproduce |
| `MakhtootKit/Sources/MKColor/CMYKConverter.swift`, `ICCProfileStore.swift` | The `CGColorSpace(iccData:)` sRGB↔CMYK path lcms2 must replace |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-native/CMakeLists.txt` (new)
- `android/mk-native/third_party/**` (new — vendored harfbuzz incl. `hb-subset`, freetype,
  lcms2 source trees plus their licence files, captured in-tree per D-304)
- `android/mk-native/src/main/cpp/**` (new — `mk_native.cpp` + headers, the single JNI facade)
- `android/mk-native/src/main/kotlin/net/binjamshid/makhtoot/mk/nativebridge/**` (new —
  `external fun` declarations and the safe Kotlin wrapper layer: face/font/buffer/blob lifetime
  management)
- `android/mk-native/src/test/kotlin/net/binjamshid/makhtoot/mk/nativebridge/**` (new — ABI
  shaping smoke tests against Batch 0's goldens)
- `android/docs/impl-log/BATCH-1.2.md` (new)

**Never touch.** `android/mk-native/build.gradle.kts` (1.1's — this agent only adds `src/` and
`third_party/` content; if the CMake/NDK wiring needs a `build.gradle.kts` change, record it in
`android/docs/CONTRACT_CHANGES.md` per spine ground rule 5, do not edit the file directly). Any
other module's `src/`. `android/fixtures/**` (read-only).

**Port map.** New native code with no Swift source — Core Text/CGColorSpace are the *behaviour*
being replaced, not code being ported line-for-line.
| iOS API being replaced | Android native replacement | Licence | Notes |
|---|---|---|---|
| Core Text `CTFont`/`CTLine` shaping | HarfBuzz `hb_shape` (GSUB/GPOS) | MIT-ish — `VERIFY-AT-SUBMISSION` | Exact upstream version pinned in `CMakeLists.txt`; `hb_glyph_info_t.cluster` with `HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS` maps to D-107's ZWJ harvesting, `hb_glyph_position_t.x_offset/y_offset/x_advance` to D-105/D-108/GPOS mark offsets |
| Core Text glyph outlines | FreeType | FTL (elect FTL over the GPLv2 dual-licence option) — `VERIFY-AT-SUBMISSION` | Capture the FTL licence text in `third_party/freetype/` |
| `NSString`/`CFStringTokenizer` bidi | ICU BiDi | Platform-provided (`android.icu`, API 24+) | NDK `libicu` linkage only where the JVM API is insufficient — do not vendor ICU |
| `CGColorSpace(iccData:)` sRGB→CMYK | lcms2 | MIT — `VERIFY-AT-SUBMISSION` | Relative colorimetric intent; default synthetic generic CMYK profile per FDA-03, never Apple Generic CMYK (not redistributable in an APK) |
| `hb-subset` (font subsetting for PDF embedding) | Vendored alongside HarfBuzz | Same as HarfBuzz | Feeds Batch 5.7's in-house PDF writer (D-314) |
| `CTFontManagerRegisterFontURLs` | *(none needed)* | — | `AssetManager` fd → `hb_blob` (D-316) needs no OS-level font registration analogue |

**Tasks.**
1. Vendor HarfBuzz (incl. `hb-subset`), FreeType and lcms2 source under
   `android/mk-native/third_party/<lib>/`, each pinned to an explicit upstream release tag
   recorded in `CMakeLists.txt` as a comment and in the impl log as a table (library, version,
   source URL, date vendored).
2. Capture each library's licence file verbatim in its `third_party/<lib>/` directory. Mark the
   licence *characterization* used for App Store/Play-policy purposes (MIT-ish for HarfBuzz,
   FTL for FreeType, MIT for lcms2) as `VERIFY-AT-SUBMISSION` in both the impl log and a
   source-comment — per spine §9, do not assert a licence claim as settled fact this early.
3. Write `CMakeLists.txt` building all three libraries plus `mk_native.cpp` for ABIs
   arm64-v8a, armeabi-v7a, x86_64, x86.
4. Write `mk_native.cpp` + headers: one JNI facade exposing (a) shaping (`hb_shape` over a
   supplied font blob + Arabic text + script/language/direction), (b) glyph outline extraction
   (FreeType), (c) font-table access, (d) subsetting (`hb-subset`), (e) ICC transform (lcms2).
   Keep the facade a thin bridge — no shaping *policy* lives in C++; policy (form resolution,
   ligature detection, mark classification) stays in Kotlin per D-303's "never write a shaper"
   rule, mirroring MKTextEngine's own separation.
5. Write the Kotlin `external fun` declarations plus a safe wrapper layer with explicit
   lifetime management for every native handle (HarfBuzz face/font/buffer/blob) — no handle may
   leak; every wrapper type is `Closeable`/uses a `try`-with-resources-equivalent pattern, and
   the impl log documents the ownership rule for each handle type.
6. Implement the `AssetManager` fd → `hb_blob` path per D-316: open a bundled font from
   `android/app/src/main/assets/fonts/**` via `AAssetManager_open` + fd, wrap as `hb_blob_t`
   without extracting to disk.
7. Write smoke tests that shape a representative subset of Batch 0's canonical Arabic corpus on
   every ABI (or via the emulator/host architecture available in CI — document which ABIs are
   actually exercised in CI vs. only build-verified) and compare glyph ids/positions/advances
   against `android/fixtures/shaping/**`. Any legitimate delta goes into
   `android/SHAPING_DELTAS.md` per D-325 — this agent may create that file if it does not yet
   exist (first writer wins; note in impl log if a later agent's delta entries land in the same
   file — that's expected and not a collision, per spine's data-file convention).

**Acceptance.**
- `android/mk-native/third_party/{harfbuzz,freetype,lcms2}/` each contain vendored source +
  licence file + pinned-version record.
- `./gradlew :mk-native:externalNativeBuildDebug` (or equivalent CMake build task) succeeds for
  all four ABIs.
- `./gradlew :mk-native:testDebugUnitTest` green: smoke test shapes the sample corpus and
  matches `android/fixtures/shaping/**` within the tolerance documented in the test.
- No native handle type lacks an explicit close/release path (spot-checked in the impl log).
- Requirements covered: shaping-stack `R-*` ids per `android/PARITY_MATRIX.md` (foundational —
  most close only once Batch 3 lands on top of this).
- Fixtures consumed: `android/fixtures/shaping/**`, `joining/**`, `ligature/**`, `marks/**`.

**Impl log.** `android/docs/impl-log/BATCH-1.2.md`

---

### Batch 1 · Agent 1.3 — Contract stubs A (foundation, model, textengine, arrange, pathtext, render, color)

**Depends on:** G0 · **Parallel-safe with:** every other Batch 1 agent

**Mission.** Generate, from `android/API_SURFACE.md`, a Kotlin file for every Swift file in
`MKFoundation`, `MKModel`, `MKTextEngine`, `MKArrange`, `MKPathText`, `MKRender` and `MKColor` —
94 files, 13,698 LOC of Swift behind them — with every public symbol present at the right
signature. Data classes and enums get real, working definitions (Batches 2–4 pattern-match on
them structurally); every function/property body is `throw MkNotYetPorted("<module>.<symbol>")`.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `android/API_SURFACE.md` (Batch 0 · 0.3) | The mechanical source of every symbol + signature to stub |
| `ANDROID_SPINE.md` §3 "Naming rule" | `MK`→`Mk` file renaming, subdirectory mirroring, `D-###`/`INV-###`/`R-###` doc-comment preservation |
| `MakhtootKit/Sources/{MKFoundation,MKModel,MKTextEngine,MKArrange,MKPathText,MKRender,MKColor}/**` | Ground truth for each file's real shape (structs/enums/protocols) when `API_SURFACE.md` needs disambiguation |
| `android/mk-native/src/main/kotlin/net/binjamshid/makhtoot/mk/nativebridge/**` (Batch 1 · 1.2, same-batch — read the interface shape, not the implementation, since 1.2 runs concurrently) | `MKTextEngine`'s stub bodies still throw `MkNotYetPorted`, but their signatures must already accept/return the native-bridge types Batch 3 will actually call, per contract-first (spine ground rule 5) |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/**` (new, incl.
  `MkNotYetPorted.kt` — the shared stub-exception type every other module's stub bodies throw)
- `android/mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/**` (new)
- `android/mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/**` (new)
- `android/mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/**` (new)
- `android/mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/**` (new)
- `android/mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/**` (new)
- `android/mk-color/src/main/kotlin/net/binjamshid/makhtoot/mk/color/**` (new)
- `android/{mk-foundation,mk-model,mk-textengine,mk-arrange,mk-pathtext,mk-render,mk-color}/src/test/kotlin/**` (new — minimal "stub throws `MkNotYetPorted`" compile/smoke tests, one per module, not one per symbol)
- `android/docs/impl-log/BATCH-1.3.md` (new)

**Never touch.** Any `build.gradle.kts` (1.1's). `android/mk-native/**` (1.2's). Any of the nine
modules owned by 1.4 (`mk-canvas`, `mk-export`, `mk-fonts`, `mk-persistence`, `mk-sync`,
`mk-store`, `mk-analytics`, `mk-designsystem`, `mk-assets`) or `:app`.

**Port map.**

#### `MKFoundation` -> `:mk-foundation` (15 files, 1,234 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKFoundation/Entitlement/MKEntitlementProviding.swift` | 48 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/entitlement/MkEntitlementProviding.kt` |
| `Sources/MKFoundation/Entitlement/MKEntitlementState.swift` | 64 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/entitlement/MkEntitlementState.kt` |
| `Sources/MKFoundation/Entitlement/StubEntitlementResolver.swift` | 17 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/entitlement/MkStubEntitlementResolver.kt` |
| `Sources/MKFoundation/Geometry/MKGeometry.swift` | 37 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/geometry/MkGeometry.kt` |
| `Sources/MKFoundation/Geometry/MKTransform2D.swift` | 114 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/geometry/MkTransform2D.kt` |
| `Sources/MKFoundation/ImageDownscale.swift` | 150 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/MkImageDownscale.kt` |
| `Sources/MKFoundation/MKError.swift` | 112 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/MkError.kt` |
| `Sources/MKFoundation/MKFeatureFlags.swift` | 54 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/MkFeatureFlags.kt` |
| `Sources/MKFoundation/MKFontUsageRecordingProtocol.swift` | 39 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/MkFontUsageRecordingProtocol.kt` |
| `Sources/MKFoundation/MKID.swift` | 45 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/MkId.kt` |
| `Sources/MKFoundation/MKLog.swift` | 67 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/MkLog.kt` |
| `Sources/MKFoundation/MKMemoryGovernor.swift` | 152 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/MkMemoryGovernor.kt` |
| `Sources/MKFoundation/RTL/MKRTLUtilities.swift` | 154 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/rtl/MkRtlUtilities.kt` |
| `Sources/MKFoundation/Stubs/MKDocumentStoring.swift` | 42 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/stubs/MkDocumentStoring.kt` |
| `Sources/MKFoundation/Stubs/MKFontProviding.swift` | 139 | `mk-foundation/src/main/kotlin/net/binjamshid/makhtoot/mk/foundation/stubs/MkFontProviding.kt` |

#### `MKModel` -> `:mk-model` (15 files, 2,176 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKModel/Arranged/ArrangedComposition.swift` | 124 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/arranged/MkArrangedComposition.kt` |
| `Sources/MKModel/Arranged/GlyphNode.swift` | 196 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/arranged/MkGlyphNode.kt` |
| `Sources/MKModel/Arranged/JoiningForm.swift` | 33 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/arranged/MkJoiningForm.kt` |
| `Sources/MKModel/Arranged/LigatureGroup.swift` | 107 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/arranged/MkLigatureGroup.kt` |
| `Sources/MKModel/Arranged/MarkNode.swift` | 81 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/arranged/MkMarkNode.kt` |
| `Sources/MKModel/Arranged/SourceTextBackup.swift` | 83 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/arranged/MkSourceTextBackup.kt` |
| `Sources/MKModel/MKBezierPathData.swift` | 166 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/MkBezierPathData.kt` |
| `Sources/MKModel/MKFontRef.swift` | 41 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/MkFontRef.kt` |
| `Sources/MKModel/MKNode.swift` | 605 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/MkNode.kt` |
| `Sources/MKModel/MKNodeStyle.swift` | 113 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/MkNodeStyle.kt` |
| `Sources/MKModel/MKPathGlyphOffset.swift` | 54 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/MkPathGlyphOffset.kt` |
| `Sources/MKModel/MKScene.swift` | 246 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/MkScene.kt` |
| `Sources/MKModel/MKTextStyle.swift` | 126 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/MkTextStyle.kt` |
| `Sources/MKModel/Schema/MKSceneMigrator.swift` | 80 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/schema/MkSceneMigrator.kt` |
| `Sources/MKModel/Schema/SceneCodec.swift` | 121 | `mk-model/src/main/kotlin/net/binjamshid/makhtoot/mk/model/schema/MkSceneCodec.kt` |

#### `MKTextEngine` -> `:mk-textengine` (17 files, 2,195 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKTextEngine/AttributedBuilder.swift` | 107 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkAttributedBuilder.kt` |
| `Sources/MKTextEngine/BidiMap.swift` | 84 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkBidiMap.kt` |
| `Sources/MKTextEngine/ClusterMap.swift` | 187 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkClusterMap.kt` |
| `Sources/MKTextEngine/CoordinateSpace.swift` | 39 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkCoordinateSpace.kt` |
| `Sources/MKTextEngine/CursiveAttachment.swift` | 254 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkCursiveAttachment.kt` |
| `Sources/MKTextEngine/FontFeatureControl.swift` | 71 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkFontFeatureControl.kt` |
| `Sources/MKTextEngine/FormResolver.swift` | 183 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkFormResolver.kt` |
| `Sources/MKTextEngine/GlyphPathProvider.swift` | 91 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkGlyphPathProvider.kt` |
| `Sources/MKTextEngine/JoiningAnalyzer.swift` | 81 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkJoiningAnalyzer.kt` |
| `Sources/MKTextEngine/JoiningTypeTable.swift` | 106 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkJoiningTypeTable.kt` |
| `Sources/MKTextEngine/LigatureDetector.swift` | 110 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkLigatureDetector.kt` |
| `Sources/MKTextEngine/MKShapingEngine.swift` | 239 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkShapingEngine.kt` |
| `Sources/MKTextEngine/MarkAttachment.swift` | 129 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkMarkAttachment.kt` |
| `Sources/MKTextEngine/MarkClassifier.swift` | 104 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkMarkClassifier.kt` |
| `Sources/MKTextEngine/ShapedModels.swift` | 229 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkShapedModels.kt` |
| `Sources/MKTextEngine/ShapingRequest.swift` | 40 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkShapingRequest.kt` |
| `Sources/MKTextEngine/ShapingService.swift` | 141 | `mk-textengine/src/main/kotlin/net/binjamshid/makhtoot/mk/textengine/MkShapingService.kt` |

#### `MKArrange` -> `:mk-arrange` (11 files, 2,078 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKArrange/ArrangeCommands.swift` | 249 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeCommands.kt` |
| `Sources/MKArrange/ArrangeDeriver.swift` | 572 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeDeriver.kt` |
| `Sources/MKArrange/ArrangeInvariants.swift` | 119 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkArrangeInvariants.kt` |
| `Sources/MKArrange/DecomposeOptions.swift` | 21 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkDecomposeOptions.kt` |
| `Sources/MKArrange/FormSelectorModel.swift` | 121 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkFormSelectorModel.kt` |
| `Sources/MKArrange/JoinController.swift` | 149 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkJoinController.kt` |
| `Sources/MKArrange/LevelMapping.swift` | 143 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkLevelMapping.kt` |
| `Sources/MKArrange/LigatureDecomposer.swift` | 361 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkLigatureDecomposer.kt` |
| `Sources/MKArrange/MarkAttachmentController.swift` | 191 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkMarkAttachmentController.kt` |
| `Sources/MKArrange/PathPlacementProviding.swift` | 60 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkPathPlacementProviding.kt` |
| `Sources/MKArrange/RevertService.swift` | 92 | `mk-arrange/src/main/kotlin/net/binjamshid/makhtoot/mk/arrange/MkRevertService.kt` |

#### `MKPathText` -> `:mk-pathtext` (9 files, 1,945 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKPathText/ArcLengthLUT.swift` | 218 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkArcLengthLUT.kt` |
| `Sources/MKPathText/BezierPathModel.swift` | 247 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkBezierPathModel.kt` |
| `Sources/MKPathText/PathEditModel.swift` | 207 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathEditModel.kt` |
| `Sources/MKPathText/PathGlyphPlacement.swift` | 160 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathGlyphPlacement.kt` |
| `Sources/MKPathText/PathHighlightRibbon.swift` | 240 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathHighlightRibbon.kt` |
| `Sources/MKPathText/PathLayoutEngine.swift` | 462 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathLayoutEngine.kt` |
| `Sources/MKPathText/PathLayoutOptions.swift` | 138 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathLayoutOptions.kt` |
| `Sources/MKPathText/PathPlacementProvider.swift` | 104 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathPlacementProvider.kt` |
| `Sources/MKPathText/PathTextCommands.swift` | 169 | `mk-pathtext/src/main/kotlin/net/binjamshid/makhtoot/mk/pathtext/MkPathTextCommands.kt` |

#### `MKRender` -> `:mk-render` (23 files, 3,603 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKRender/AssetProviding.swift` | 54 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkAssetProviding.kt` |
| `Sources/MKRender/BitmapCache.swift` | 139 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkBitmapCache.kt` |
| `Sources/MKRender/ContentHash.swift` | 152 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkContentHash.kt` |
| `Sources/MKRender/DegradationController.swift` | 248 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkDegradationController.kt` |
| `Sources/MKRender/Drawers/ArrangedDrawer.swift` | 95 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkArrangedDrawer.kt` |
| `Sources/MKRender/Drawers/BackgroundDrawer.swift` | 56 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkBackgroundDrawer.kt` |
| `Sources/MKRender/Drawers/ImageDrawer.swift` | 114 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkImageDrawer.kt` |
| `Sources/MKRender/Drawers/LiveTextDrawer.swift` | 278 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkLiveTextDrawer.kt` |
| `Sources/MKRender/Drawers/PathTextDrawer.swift` | 369 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkPathTextDrawer.kt` |
| `Sources/MKRender/Drawers/ShapeDrawer.swift` | 80 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkShapeDrawer.kt` |
| `Sources/MKRender/Drawers/StylePainting.swift` | 168 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/drawers/MkStylePainting.kt` |
| `Sources/MKRender/Geometry/ArrangedGeometry.swift` | 163 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/geometry/MkArrangedGeometry.kt` |
| `Sources/MKRender/Geometry/NodeLocalBounds.swift` | 71 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/geometry/MkNodeLocalBounds.kt` |
| `Sources/MKRender/HitTester.swift` | 337 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkHitTester.kt` |
| `Sources/MKRender/LayerTreeBuilder.swift` | 481 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkLayerTreeBuilder.kt` |
| `Sources/MKRender/MemoryPressureMonitor.swift` | 148 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkMemoryPressureMonitor.kt` |
| `Sources/MKRender/RenderOptions.swift` | 93 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkRenderOptions.kt` |
| `Sources/MKRender/RenderSignposts.swift` | 138 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkRenderSignposts.kt` |
| `Sources/MKRender/RenderTreeProviding.swift` | 49 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkRenderTreeProviding.kt` |
| `Sources/MKRender/SceneRenderer.swift` | 125 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkSceneRenderer.kt` |
| `Sources/MKRender/SnapshotRenderer.swift` | 97 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkSnapshotRenderer.kt` |
| `Sources/MKRender/StubRenderTree.swift` | 90 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkStubRenderTree.kt` |
| `Sources/MKRender/TileRenderer.swift` | 58 | `mk-render/src/main/kotlin/net/binjamshid/makhtoot/mk/render/MkTileRenderer.kt` |

#### `MKColor` -> `:mk-color` (4 files, 467 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKColor/CMYKConverter.swift` | 108 | `mk-color/src/main/kotlin/net/binjamshid/makhtoot/mk/color/MkCmykConverter.kt` |
| `Sources/MKColor/ICCProfileStore.swift` | 154 | `mk-color/src/main/kotlin/net/binjamshid/makhtoot/mk/color/MkIccProfileStore.kt` |
| `Sources/MKColor/MKColorSpec+HSB.swift` | 102 | `mk-color/src/main/kotlin/net/binjamshid/makhtoot/mk/color/MkColorSpec+HSB.kt` (see naming note below) |
| `Sources/MKColor/MKColorSpec.swift` | 103 | `mk-color/src/main/kotlin/net/binjamshid/makhtoot/mk/color/MkColorSpec.kt` |

> Note on `MKColorSpec+HSB.swift`: the naming rule's literal output (`MkColorSpec+HSB.kt`) is
> not a valid Kotlin/Gradle-safe filename on every toolchain. This agent must resolve the `+` by
> either merging the extension's members into `MkColorSpec.kt` (documented deviation, noted in
> the impl log per spine's own deviation-logging convention) or naming the file
> `MkColorSpecHsb.kt` — either is acceptable, but the choice must be recorded, not silent.

**Tasks.**
1. For every row in the port map above, create the Kotlin file at the listed target path.
   Directory structure mirrors the Swift subdirectory (`Arranged/` → `arranged/`, `Schema/` →
   `schema/`, `RTL/` → `rtl/`, `Stubs/` → `stubs/`, `Geometry/` → `geometry/`, `Entitlement/` →
   `entitlement/`, `PathText/` → `pathtext/`, `Drawers/` → `drawers/`, `Geometry/` → `geometry/`).
2. Create `MkNotYetPorted` in `mk-foundation` first (every other stub body across both this
   agent's and 1.4's modules throws it): `class MkNotYetPorted(symbol: String) :
   NotImplementedError("Not yet ported: $symbol")` or equivalent — the exact shape only needs to
   carry the dotted `<module>.<symbol>` identity string so `check-no-stubs.sh` (1.1) can grep
   for it unambiguously.
3. For each Swift `struct`/`enum`/`protocol` with stored properties (data-shape types —
   `MKNode`, `MKScene`, `ShapedModels`, `ArrangedComposition`, `GlyphNode`, `MKColorSpec`, etc.),
   write the **real** Kotlin `data class`/`sealed class`/`enum class`/`interface` definition —
   same fields, same nesting, `Codable` conformance mapped to `kotlinx.serialization`
   `@Serializable` where the Swift type is `Codable`. These are not stubbed; Batch 2–4 agents
   pattern-match on them structurally starting next batch.
4. For each function/computed-property/method on a class or in a protocol extension, write the
   real signature with a body of exactly `throw MkNotYetPorted("<Target>.<Symbol>")` (or, for a
   non-`Unit`-returning function where Kotlin needs a reachable-code-analysis-safe stub,
   `TODO()`-style is **not** used — always `MkNotYetPorted`, per spine ground rule 3's grep list
   explicitly banning `NotImplementedError`/`TODO(` as *terminal* stub markers; `MkNotYetPorted`
   itself wrapping `NotImplementedError` internally is fine since the ratchet greps for the
   wrapper name, not the base class — confirm this against `check-no-stubs.sh`'s actual grep
   list from 1.1 and adjust if the two agents' conventions diverge, recording the resolution in
   `android/docs/CONTRACT_CHANGES.md`).
5. Preserve every `D-###`/`INV-###`/`R-###` reference from the Swift doc comments in the
   corresponding Kotlin file's KDoc, per spine §3's naming-rule traceability requirement.
6. Write one minimal test per module (7 total) asserting a representative stubbed function
   throws `MkNotYetPorted` and a representative data class round-trips through
   `kotlinx.serialization` — this is what makes `testDebugUnitTest` meaningfully green rather
   than vacuously green.

**Acceptance.**
- `./gradlew :mk-foundation:testDebugUnitTest :mk-model:testDebugUnitTest :mk-textengine:testDebugUnitTest :mk-arrange:testDebugUnitTest :mk-pathtext:testDebugUnitTest :mk-render:testDebugUnitTest :mk-color:testDebugUnitTest` green.
- `./gradlew :mk-foundation:lintDebug` (and the other six) green.
- Every symbol listed for these 7 targets in `android/API_SURFACE.md` has a corresponding
  Kotlin declaration (spot-checked by count per module in the impl log).
- `bash Scripts/android/stub-count.sh` reports a non-zero count including this agent's modules
  (expected and correct at this batch).
- Requirements covered: none close yet (stubs are not implementations) — see
  `android/PARITY_MATRIX.md`, Android status stays `⬜` for every id in these 7 modules until
  Batches 2–4.
- Stub count for these 7 modules is published, not zero (zero is Batch 3/4/G8's job).

**Impl log.** `android/docs/impl-log/BATCH-1.3.md`

---

### Batch 1 · Agent 1.4 — Contract stubs B (canvas, export, fonts, persistence, sync, store, analytics, designsystem, assets, app)

**Depends on:** G0 · **Parallel-safe with:** every other Batch 1 agent

**Mission.** The same contract-stub treatment as 1.3, for the remaining nine `MakhtootKit`
targets (175 files, 24,382 LOC) plus the `Makhtoot` app target's screen-level entry points —
**55 files / 15,280 LOC in port scope** (60 files / 16,227 LOC exist on disk under
`Makhtoot/AppShell/**` + `Makhtoot/App/**` + `Makhtoot/Stubs/**`, but five of them — the four iOS
developer harnesses plus `EditorPlaceholderView.swift`, 947 LOC total — are excluded from the
port entirely per spine §3.1/§14 and must not appear anywhere in this agent's output or in the
stub count) — every public symbol present with the right signature, data classes/enums real,
every function body `throw MkNotYetPorted("<module>.<symbol>")`.

**Reads (spec, do not edit).**
| Path | Why |
|---|---|
| `android/API_SURFACE.md` (Batch 0 · 0.3) | The mechanical source of every symbol + signature to stub |
| `ANDROID_SPINE.md` §3 "Naming rule" | Same 1:1 naming/directory-mirroring rule as 1.3 |
| `MakhtootKit/Sources/{MKCanvas,MKExport,MKFonts,MKPersistence,MKSync,MKStore,MKAnalytics,MKDesignSystem,MKAssets}/**` | Ground truth for disambiguation against `API_SURFACE.md` |
| `Makhtoot/AppShell/**`, `Makhtoot/App/**`, `Makhtoot/Stubs/**` | The app target's own screens, navigation, composition root and protocol-seam stubs to mirror |
| `android/mk-foundation/src/main/kotlin/.../MkNotYetPorted.kt` (Batch 1 · 1.3, same-batch — read the type's shape, not an implementation detail) | Every stub body in this agent's modules throws the same shared exception type 1.3 defines — contract-first means this agent reads that one symbol's shape without waiting for 1.3's full batch to finish |

**Owns (creates or edits — no other agent may touch these).**
- `android/mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/**` (new)
- `android/mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/**` (new)
- `android/mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/**` (new)
- `android/mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/**` (new)
- `android/mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/**` (new)
- `android/mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/**` (new)
- `android/mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/**` (new)
- `android/mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/**` (new)
- `android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/**` (new)
- `android/app/src/main/kotlin/net/binjamshid/makhtoot/**` (new — screen-level entry points only,
  per the port map below; Compose screen *bodies* beyond a stubbed entry point are Batch 7's job)
- `android/{mk-canvas,mk-export,mk-fonts,mk-persistence,mk-sync,mk-store,mk-analytics,mk-designsystem,mk-assets,app}/src/test/kotlin/**` (new — one minimal stub-throws test per module, 10 total)
- `android/docs/impl-log/BATCH-1.4.md` (new)

**Never touch.** Any `build.gradle.kts` (1.1's). `android/mk-native/**` (1.2's). Any of the seven
modules owned by 1.3 (`mk-foundation`, `mk-model`, `mk-textengine`, `mk-arrange`, `mk-pathtext`,
`mk-render`, `mk-color`). The five excluded iOS files — `App/DesignSystemGallery.swift`,
`App/Debug/PathTextHarnessView.swift`, `App/Debug/PerfHUDView.swift`,
`App/Debug/ShapingHarnessView.swift`, `AppShell/Scenes/Editor/EditorPlaceholderView.swift` — are
never ported under any name or path; do not create a Kotlin file for any of them, in `src/main/`
or `src/debug/`.

**Port map — library modules.**

#### `MKCanvas` -> `:mk-canvas` (29 files, 6,580 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKCanvas/Arrange/MKArrangeEngineProviding.swift` | 191 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/arrange/MkArrangeEngineProviding.kt` |
| `Sources/MKCanvas/Arrange/MKArrangeInteractionModel.swift` | 603 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/arrange/MkArrangeInteractionModel.kt` |
| `Sources/MKCanvas/CanvasContentAPI.swift` | 74 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasContentAPI.kt` |
| `Sources/MKCanvas/CanvasMode.swift` | 29 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasMode.kt` |
| `Sources/MKCanvas/CanvasSession.swift` | 256 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasSession.kt` |
| `Sources/MKCanvas/CheckerboardPattern.swift` | 44 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCheckerboardPattern.kt` |
| `Sources/MKCanvas/EditingOperations.swift` | 331 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkEditingOperations.kt` |
| `Sources/MKCanvas/Geometry/MKAnchoredResize.swift` | 208 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkAnchoredResize.kt` |
| `Sources/MKCanvas/Geometry/MKCanvasGeometrySource.swift` | 138 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkCanvasGeometrySource.kt` |
| `Sources/MKCanvas/Geometry/MKGroupTransform.swift` | 38 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkGroupTransform.kt` |
| `Sources/MKCanvas/Geometry/MKOrientedRect.swift` | 147 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/geometry/MkOrientedRect.kt` |
| `Sources/MKCanvas/Gestures/GestureCoordinator.swift` | 473 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkGestureCoordinator.kt` |
| `Sources/MKCanvas/Gestures/HandleGestures.swift` | 242 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkHandleGestures.kt` |
| `Sources/MKCanvas/Gestures/MarqueeController.swift` | 51 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkMarqueeController.kt` |
| `Sources/MKCanvas/Gestures/MoveGesture.swift` | 119 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/gestures/MkMoveGesture.kt` |
| `Sources/MKCanvas/GridLines.swift` | 32 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkGridLines.kt` |
| `Sources/MKCanvas/GuideRenderer.swift` | 107 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkGuideRenderer.kt` |
| `Sources/MKCanvas/HitTestPolicy.swift` | 145 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkHitTestPolicy.kt` |
| `Sources/MKCanvas/InspectorModel.swift` | 662 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkInspectorModel.kt` |
| `Sources/MKCanvas/KeyCommands.swift` | 132 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkKeyCommands.kt` |
| `Sources/MKCanvas/LayersModel.swift` | 314 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkLayersModel.kt` |
| `Sources/MKCanvas/MKCanvasViewController.swift` | 417 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkCanvasViewController.kt` |
| `Sources/MKCanvas/PathText/MKPathTextEngineProviding.swift` | 242 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathTextEngineProviding.kt` |
| `Sources/MKCanvas/PathText/MKPathTextInteractionModel.swift` | 372 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathTextInteractionModel.kt` |
| `Sources/MKCanvas/PathText/PathEditChromeLayer.swift` | 197 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/pathtext/MkPathEditChromeLayer.kt` |
| `Sources/MKCanvas/SelectionChromeLayer.swift` | 195 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSelectionChromeLayer.kt` |
| `Sources/MKCanvas/SelectionState.swift` | 83 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSelectionState.kt` |
| `Sources/MKCanvas/SnapEngine.swift` | 206 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkSnapEngine.kt` |
| `Sources/MKCanvas/TextEditingOverlay.swift` | 532 | `mk-canvas/src/main/kotlin/net/binjamshid/makhtoot/mk/canvas/MkTextEditingOverlay.kt` |

#### `MKExport` -> `:mk-export` (22 files, 3,342 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKExport/ExportCoordinator.swift` | 397 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportCoordinator.kt` |
| `Sources/MKExport/ExportGate.swift` | 180 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportGate.kt` |
| `Sources/MKExport/ExportPresets.swift` | 124 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportPresets.kt` |
| `Sources/MKExport/ExportRequest.swift` | 183 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportRequest.kt` |
| `Sources/MKExport/ExportResult.swift` | 57 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportResult.kt` |
| `Sources/MKExport/FallbackNote.swift` | 164 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFallbackNote.kt` |
| `Sources/MKExport/FontLicenseProviding.swift` | 80 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFontLicenseProviding.kt` |
| `Sources/MKExport/FreeTierBudget.swift` | 31 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFreeTierBudget.kt` |
| `Sources/MKExport/MKEmbeddingRestrictionWalker.swift` | 104 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkEmbeddingRestrictionWalker.kt` |
| `Sources/MKExport/MKExportFontDataProviding.swift` | 32 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkExportFontDataProviding.kt` |
| `Sources/MKExport/MKFilenameSanitizer.swift` | 36 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkFilenameSanitizer.kt` |
| `Sources/MKExport/MKOutlineSubstitutePainter.swift` | 148 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkOutlineSubstitutePainter.kt` |
| `Sources/MKExport/PDFOutputIntent.swift` | 92 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfOutputIntent.kt` |
| `Sources/MKExport/PDFPrintCMYKExporter.swift` | 119 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfPrintCmykExporter.kt` |
| `Sources/MKExport/PDFRasterExporter.swift` | 36 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfRasterExporter.kt` |
| `Sources/MKExport/PDFVectorExporter.swift` | 81 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkPdfVectorExporter.kt` |
| `Sources/MKExport/RasterEncoders.swift` | 56 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkRasterEncoders.kt` |
| `Sources/MKExport/SVGProvenance.swift` | 134 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgProvenance.kt` |
| `Sources/MKExport/SVGSerializer.swift` | 400 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgSerializer.kt` |
| `Sources/MKExport/SVGTextWriter.swift` | 238 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkSvgTextWriter.kt` |
| `Sources/MKExport/TextOutlining.swift` | 372 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkTextOutlining.kt` |
| `Sources/MKExport/TiledRasterExporter.swift` | 278 | `mk-export/src/main/kotlin/net/binjamshid/makhtoot/mk/export/MkTiledRasterExporter.kt` |

#### `MKFonts` -> `:mk-fonts` (21 files, 2,480 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKFonts/BundledFontIndex.swift` | 250 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkBundledFontIndex.kt` |
| `Sources/MKFonts/CatalogManifest.swift` | 101 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkCatalogManifest.kt` |
| `Sources/MKFonts/MKCatalogManifestFetchService.swift` | 132 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkCatalogManifestFetchService.kt` |
| `Sources/MKFonts/MKCoverageAnalyzer.swift` | 86 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkCoverageAnalyzer.kt` |
| `Sources/MKFonts/MKFontCatalog.swift` | 100 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontCatalog.kt` |
| `Sources/MKFonts/MKFontCatalogStore.swift` | 153 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontCatalogStore.kt` |
| `Sources/MKFonts/MKFontDownloader.swift` | 148 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontDownloader.kt` |
| `Sources/MKFonts/MKFontError.swift` | 83 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontError.kt` |
| `Sources/MKFonts/MKFontImporter.swift` | 87 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontImporter.kt` |
| `Sources/MKFonts/MKFontLockController.swift` | 55 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontLockController.kt` |
| `Sources/MKFonts/MKFontRegistrar.swift` | 146 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontRegistrar.kt` |
| `Sources/MKFonts/MKFontRegistry.swift` | 349 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontRegistry.kt` |
| `Sources/MKFonts/MKFontSearchIndex.swift` | 89 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontSearchIndex.kt` |
| `Sources/MKFonts/MKFontStorageManager.swift` | 51 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontStorageManager.kt` |
| `Sources/MKFonts/MKFontTypes.swift` | 156 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontTypes.kt` |
| `Sources/MKFonts/MKFontValidator.swift` | 197 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontValidator.kt` |
| `Sources/MKFonts/MKFontsCTFontSendable.swift` | 14 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontsCtFontSendable.kt` |
| `Sources/MKFonts/MKFontsResources.swift` | 9 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkFontsResources.kt` |
| `Sources/MKFonts/MKLicenseRecord.swift` | 148 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkLicenseRecord.kt` |
| `Sources/MKFonts/MKLicensingDataSource.swift` | 99 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkLicensingDataSource.kt` |
| `Sources/MKFonts/MKPremiumDelivery.swift` | 27 | `mk-fonts/src/main/kotlin/net/binjamshid/makhtoot/mk/fonts/MkPremiumDelivery.kt` |

#### `MKPersistence` -> `:mk-persistence` (19 files, 3,283 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKPersistence/AssetStore.swift` | 166 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkAssetStore.kt` |
| `Sources/MKPersistence/AutosaveController.swift` | 192 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkAutosaveController.kt` |
| `Sources/MKPersistence/CommandJournal.swift` | 144 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkCommandJournal.kt` |
| `Sources/MKPersistence/CrashRecovery.swift` | 92 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkCrashRecovery.kt` |
| `Sources/MKPersistence/DocumentPackage.swift` | 146 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkDocumentPackage.kt` |
| `Sources/MKPersistence/ExportTempDirectory.swift` | 72 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkExportTempDirectory.kt` |
| `Sources/MKPersistence/Internal/PersistenceSupport.swift` | 268 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/internal/MkPersistenceSupport.kt` |
| `Sources/MKPersistence/MKProjectChange.swift` | 25 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkProjectChange.kt` |
| `Sources/MKPersistence/MakhtootDocument.swift` | 292 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkMakhtootDocument.kt` |
| `Sources/MKPersistence/Metadata/LaunchReconciler.swift` | 63 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkLaunchReconciler.kt` |
| `Sources/MKPersistence/Metadata/MetadataModels.swift` | 270 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkMetadataModels.kt` |
| `Sources/MKPersistence/Metadata/MetadataStore.swift` | 308 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkMetadataStore.kt` |
| `Sources/MKPersistence/Metadata/MetadataSummaries.swift` | 116 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkMetadataSummaries.kt` |
| `Sources/MKPersistence/Metadata/SearchNormalizer.swift` | 78 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/metadata/MkSearchNormalizer.kt` |
| `Sources/MKPersistence/PackageImportValidator.swift` | 120 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/MkPackageImportValidator.kt` |
| `Sources/MKPersistence/Undo/Commands.swift` | 604 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/MkCommands.kt` |
| `Sources/MKPersistence/Undo/MKCommand.swift` | 60 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/MkCommand.kt` |
| `Sources/MKPersistence/Undo/MKCommandCoder.swift` | 73 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/MkCommandCoder.kt` |
| `Sources/MKPersistence/Undo/UndoStack.swift` | 194 | `mk-persistence/src/main/kotlin/net/binjamshid/makhtoot/mk/persistence/undo/MkUndoStack.kt` |

#### `MKSync` -> `:mk-sync` (10 files, 1,945 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKSync/Account/MKSyncAccountState.swift` | 74 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/account/MkSyncAccountState.kt` |
| `Sources/MKSync/ChangeTracking/MKSyncPendingQueue.swift` | 120 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/changetracking/MkSyncPendingQueue.kt` |
| `Sources/MKSync/Conflict/MKConflictNaming.swift` | 51 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/conflict/MkConflictNaming.kt` |
| `Sources/MKSync/Conflict/MKSyncDecisionEngine.swift` | 139 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/conflict/MkSyncDecisionEngine.kt` |
| `Sources/MKSync/Engine/MKSyncEngineController.swift` | 841 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/engine/MkSyncEngineController.kt` |
| `Sources/MKSync/Errors/MKSyncError.swift` | 138 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/errors/MkSyncError.kt` |
| `Sources/MKSync/Schema/MKSyncSchema.swift` | 104 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/schema/MkSyncSchema.kt` |
| `Sources/MKSync/Serialization/MKProjectRecordCoder.swift` | 253 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/serialization/MkProjectRecordCoder.kt` |
| `Sources/MKSync/Status/MKSyncStatus.swift` | 146 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/status/MkSyncStatus.kt` |
| `Sources/MKSync/Tunables/MKSyncTunables.swift` | 79 | `mk-sync/src/main/kotlin/net/binjamshid/makhtoot/mk/sync/tunables/MkSyncTunables.kt` |

#### `MKStore` -> `:mk-store` (18 files, 1,668 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKStore/MKEntitlementDetail.swift` | 69 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementDetail.kt` |
| `Sources/MKStore/MKEntitlementPrecedence.swift` | 74 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementPrecedence.kt` |
| `Sources/MKStore/MKEntitlementResolver.swift` | 290 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkEntitlementResolver.kt` |
| `Sources/MKStore/MKProductCatalog.swift` | 135 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkProductCatalog.kt` |
| `Sources/MKStore/MKPurchaseController.swift` | 133 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkPurchaseController.kt` |
| `Sources/MKStore/MKStoreError.swift` | 60 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkStoreError.kt` |
| `Sources/MKStore/MKStoreIDs.swift` | 37 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkStoreIds.kt` |
| `Sources/MKStore/Paywall/MKPaywallStateMachine.swift` | 102 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/paywall/MkPaywallStateMachine.kt` |
| `Sources/MKStore/Referral/MKReferralCodeGenerator.swift` | 42 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralCodeGenerator.kt` |
| `Sources/MKStore/Referral/MKReferralLedger.swift` | 100 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralLedger.kt` |
| `Sources/MKStore/Referral/MKReferralRedemption.swift` | 52 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/referral/MkReferralRedemption.kt` |
| `Sources/MKStore/Testing/MKSandboxScenarioStub.swift` | 67 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/testing/MkSandboxScenarioStub.kt` |
| `Sources/MKStore/Trial/MKClockProviding.swift` | 63 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkClockProviding.kt` |
| `Sources/MKStore/Trial/MKSecureStore.swift` | 117 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkSecureStore.kt` |
| `Sources/MKStore/Trial/MKTrialManager.swift` | 182 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkTrialManager.kt` |
| `Sources/MKStore/Trial/MKTrialRecord.swift` | 64 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkTrialRecord.kt` |
| `Sources/MKStore/Trial/MKUbiquitousStore.swift` | 65 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/trial/MkUbiquitousStore.kt` |
| `Sources/MKStore/Verification.swift` | 16 | `mk-store/src/main/kotlin/net/binjamshid/makhtoot/mk/store/MkVerification.kt` |

#### `MKAnalytics` -> `:mk-analytics` (13 files, 1,004 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKAnalytics/Consent/MKConsentManager.swift` | 107 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentManager.kt` |
| `Sources/MKAnalytics/Consent/MKConsentRecord.swift` | 62 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentRecord.kt` |
| `Sources/MKAnalytics/Consent/MKConsentStatus.swift` | 59 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/consent/MkConsentStatus.kt` |
| `Sources/MKAnalytics/Counter/MKFontUsageBucket.swift` | 33 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/counter/MkFontUsageBucket.kt` |
| `Sources/MKAnalytics/Counter/MKUsageCounterStore.swift` | 191 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/counter/MkUsageCounterStore.kt` |
| `Sources/MKAnalytics/MKAnalyticsError.swift` | 15 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkAnalyticsError.kt` |
| `Sources/MKAnalytics/MKAnalyticsLog.swift` | 9 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkAnalyticsLog.kt` |
| `Sources/MKAnalytics/MKLegalLinks.swift` | 22 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/MkLegalLinks.kt` |
| `Sources/MKAnalytics/Service/MKAnalyticsService.swift` | 125 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/service/MkAnalyticsService.kt` |
| `Sources/MKAnalytics/Service/MKDisclosureContent.swift` | 42 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/service/MkDisclosureContent.kt` |
| `Sources/MKAnalytics/Upload/MKAnalyticsUploader.swift` | 183 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkAnalyticsUploader.kt` |
| `Sources/MKAnalytics/Upload/MKCloudKitPublicDatabase.swift` | 66 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkCloudKitPublicDatabase.kt` |
| `Sources/MKAnalytics/Upload/MKFontUsageBatch.swift` | 90 | `mk-analytics/src/main/kotlin/net/binjamshid/makhtoot/mk/analytics/upload/MkFontUsageBatch.kt` |

#### `MKDesignSystem` -> `:mk-designsystem` (19 files, 1,405 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKDesignSystem/Components/MKBanner.swift` | 58 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkBanner.kt` |
| `Sources/MKDesignSystem/Components/MKBrandMark.swift` | 81 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkBrandMark.kt` |
| `Sources/MKDesignSystem/Components/MKChip.swift` | 38 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkChip.kt` |
| `Sources/MKDesignSystem/Components/MKFloatingBar.swift` | 70 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkFloatingBar.kt` |
| `Sources/MKDesignSystem/Components/MKInspectorField.swift` | 78 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkInspectorField.kt` |
| `Sources/MKDesignSystem/Components/MKPanel.swift` | 37 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkPanel.kt` |
| `Sources/MKDesignSystem/Components/MKSectionHeader.swift` | 32 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkSectionHeader.kt` |
| `Sources/MKDesignSystem/Components/MKSlider.swift` | 32 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkSlider.kt` |
| `Sources/MKDesignSystem/Components/MKToolbarButton.swift` | 101 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/components/MkToolbarButton.kt` |
| `Sources/MKDesignSystem/MKMotion.swift` | 73 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkMotion.kt` |
| `Sources/MKDesignSystem/MKSpacing.swift` | 36 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkSpacing.kt` |
| `Sources/MKDesignSystem/MKTheme.swift` | 198 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkTheme.kt` |
| `Sources/MKDesignSystem/MKTypeRamp.swift` | 120 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/MkTypeRamp.kt` |
| `Sources/MKDesignSystem/Themes/HibrTheme.swift` | 108 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkHibrTheme.kt` |
| `Sources/MKDesignSystem/Themes/KufiTheme.swift` | 74 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkKufiTheme.kt` |
| `Sources/MKDesignSystem/Themes/MKThemeColorHelpers.swift` | 43 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkThemeColorHelpers.kt` |
| `Sources/MKDesignSystem/Themes/NaqshTheme.swift` | 76 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkNaqshTheme.kt` |
| `Sources/MKDesignSystem/Themes/RamlTheme.swift` | 71 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkRamlTheme.kt` |
| `Sources/MKDesignSystem/Themes/TayfTheme.swift` | 79 | `mk-designsystem/src/main/kotlin/net/binjamshid/makhtoot/mk/designsystem/themes/MkTayfTheme.kt` |

#### `MKAssets` -> `:mk-assets` (24 files, 2,675 LOC)

| Swift source | LOC | Kotlin target |
|---|---|---|
| `Sources/MKAssets/Browser/MKAssetBrowserModel.swift` | 156 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetBrowserModel.kt` |
| `Sources/MKAssets/Browser/MKAssetFavoritesStoring.swift` | 58 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetFavoritesStoring.kt` |
| `Sources/MKAssets/Browser/MKAssetSearchNormalizer.swift` | 48 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkAssetSearchNormalizer.kt` |
| `Sources/MKAssets/Browser/MKUserDefaultsAssetMetadataStore.swift` | 102 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/browser/MkUserDefaultsAssetMetadataStore.kt` |
| `Sources/MKAssets/Generators/MKBasicShapeGenerator.swift` | 131 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkBasicShapeGenerator.kt` |
| `Sources/MKAssets/Generators/MKCalligraphicGenerator.swift` | 146 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkCalligraphicGenerator.kt` |
| `Sources/MKAssets/Generators/MKFrameGenerator.swift` | 158 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkFrameGenerator.kt` |
| `Sources/MKAssets/Generators/MKOrnamentGenerator.swift` | 259 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkOrnamentGenerator.kt` |
| `Sources/MKAssets/Generators/MKPatternTileGenerator.swift` | 109 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/MkPatternTileGenerator.kt` |
| `Sources/MKAssets/Instantiation/MKAssetInstantiator.swift` | 112 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkAssetInstantiator.kt` |
| `Sources/MKAssets/Instantiation/MKPatternInstantiator.swift` | 90 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkPatternInstantiator.kt` |
| `Sources/MKAssets/Instantiation/MKPremiumContentLedger.swift` | 63 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/instantiation/MkPremiumContentLedger.kt` |
| `Sources/MKAssets/Library/MKAssetLibrary.swift` | 57 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/library/MkAssetLibrary.kt` |
| `Sources/MKAssets/Library/MKAssetManifestCodec.swift` | 88 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/library/MkAssetManifestCodec.kt` |
| `Sources/MKAssets/Model/MKAssetCategory.swift` | 38 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetCategory.kt` |
| `Sources/MKAssets/Model/MKAssetDescriptor.swift` | 130 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetDescriptor.kt` |
| `Sources/MKAssets/Model/MKAssetGeometry.swift` | 180 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetGeometry.kt` |
| `Sources/MKAssets/Model/MKAssetPathBuilder.swift` | 263 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetPathBuilder.kt` |
| `Sources/MKAssets/Model/MKAssetProvenance.swift` | 84 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkAssetProvenance.kt` |
| `Sources/MKAssets/Model/MKPatternFill.swift` | 49 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/model/MkPatternFill.kt` |
| `Sources/MKAssets/Provenance/MKAssetProvenanceLibrary.swift` | 60 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/provenance/MkAssetProvenanceLibrary.kt` |
| `Sources/MKAssets/Provenance/MKAssetProvenanceStore.swift` | 44 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/provenance/MkAssetProvenanceStore.kt` |
| `Sources/MKAssets/Rendering/MKAssetContactSheetGenerator.swift` | 92 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/rendering/MkAssetContactSheetGenerator.kt` |
| `Sources/MKAssets/Rendering/MKAssetThumbnailRenderer.swift` | 158 | `mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/rendering/MkAssetThumbnailRenderer.kt` |

**Port map — `:app` screen-level entry points (48 files, 14,645 LOC, from `Makhtoot/AppShell/**`;
`EditorPlaceholderView.swift` (82 LOC) is excluded from this list per spine §3.1/§14 — dead,
unrouted iOS code, not ported, must not appear in this agent's stub scope or inflate the stub
count).**

| Swift source | LOC | Kotlin target |
|---|---|---|
| `AppShell/AppContainer.swift` | 298 | `app/src/main/kotlin/net/binjamshid/makhtoot/MkAppContainer.kt` — **frozen path per spine §17**: this agent creates the Batch 1 contract stub at exactly `android/app/src/main/kotlin/net/binjamshid/makhtoot/MkAppContainer.kt`; Agent 7.1 supersedes it in Batch 7 with the real composition-root implementation at this same path, declaring the takeover in its own packet; Agent 8.1 reads and wires against it but does not own or edit it |
| `AppShell/Navigation/AppNavigationModel.swift` | 159 | `app/src/main/kotlin/net/binjamshid/makhtoot/navigation/MkAppNavigationModel.kt` |
| `AppShell/Navigation/MKRoute.swift` | 77 | `app/src/main/kotlin/net/binjamshid/makhtoot/navigation/MkRoute.kt` |
| `AppShell/Navigation/RootShellView.swift` | 420 | `app/src/main/kotlin/net/binjamshid/makhtoot/navigation/MkRootShellView.kt` |
| `AppShell/Persistence/MKPersistenceProjectLibrary.swift` | 435 | `app/src/main/kotlin/net/binjamshid/makhtoot/persistence/MkPersistenceProjectLibrary.kt` |
| `AppShell/Scenes/Browser/ExportHistorySheet.swift` | 101 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkExportHistorySheet.kt` |
| `AppShell/Scenes/Browser/MKSearchBarFontUpdater.swift` | 56 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkSearchBarFontUpdater.kt` |
| `AppShell/Scenes/Browser/NewProjectSheet.swift` | 335 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkNewProjectSheet.kt` |
| `AppShell/Scenes/Browser/ProjectBrowserView.swift` | 1,029 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkProjectBrowserView.kt` |
| `AppShell/Scenes/Browser/ProjectBrowserViewModel.swift` | 155 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/browser/MkProjectBrowserViewModel.kt` |
| `AppShell/Scenes/Editor/ArrangeToolbarView.swift` | 189 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkArrangeToolbarView.kt` |
| `AppShell/Scenes/Editor/BackgroundImageSheet.swift` | 263 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkBackgroundImageSheet.kt` |
| `AppShell/Scenes/Editor/BackgroundImageSupport.swift` | 145 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkBackgroundImageSupport.kt` |
| `AppShell/Scenes/Editor/CanvasHostView.swift` | 44 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkCanvasHostView.kt` |
| `AppShell/Scenes/Editor/EditorScene.swift` | 1,067 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorScene.kt` |
| `AppShell/Scenes/Editor/EditorStatusViews.swift` | 67 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorStatusViews.kt` |
| `AppShell/Scenes/Editor/EditorTourModel.swift` | 58 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorTourModel.kt` |
| `AppShell/Scenes/Editor/EditorTourOverlay.swift` | 109 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorTourOverlay.kt` |
| `AppShell/Scenes/Editor/EditorViewModel.swift` | 2,725 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkEditorViewModel.kt` |
| `AppShell/Scenes/Editor/FontBrowserSheet.swift` | 157 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkFontBrowserSheet.kt` |
| `AppShell/Scenes/Editor/FontSettingsSheet.swift` | 1,168 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkFontSettingsSheet.kt` |
| `AppShell/Scenes/Editor/FormSelectorPopoverView.swift` | 191 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkFormSelectorPopoverView.kt` |
| `AppShell/Scenes/Editor/InspectorPanelView.swift` | 461 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkInspectorPanelView.kt` |
| `AppShell/Scenes/Editor/LayersPanelView.swift` | 122 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkLayersPanelView.kt` |
| `AppShell/Scenes/Editor/MKArrangeInteractionAdapter.swift` | 235 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkArrangeInteractionAdapter.kt` |
| `AppShell/Scenes/Editor/MKAssetBrowserSheet.swift` | 288 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkAssetBrowserSheet.kt` |
| `AppShell/Scenes/Editor/MKCanvasRenderAdapter.swift` | 188 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkCanvasRenderAdapter.kt` |
| `AppShell/Scenes/Editor/MKPathTextInteractionAdapter.swift` | 347 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkPathTextInteractionAdapter.kt` |
| `AppShell/Scenes/Editor/MergeDesignSheet.swift` | 98 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkMergeDesignSheet.kt` |
| `AppShell/Scenes/Editor/PathEditToolbarView.swift` | 111 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkPathEditToolbarView.kt` |
| `AppShell/Scenes/Editor/PathGhostGuideOverlay.swift` | 78 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkPathGhostGuideOverlay.kt` |
| `AppShell/Scenes/Editor/PathOptionsPopoverView.swift` | 147 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkPathOptionsPopoverView.kt` |
| `AppShell/Scenes/Editor/TextInsertSheet.swift` | 425 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkTextInsertSheet.kt` |
| `AppShell/Scenes/Editor/TokenStripView.swift` | 68 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkTokenStripView.kt` |
| `AppShell/Scenes/Editor/ToolRailView.swift` | 458 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkToolRailView.kt` |
| `AppShell/Scenes/Editor/ZoomControlsView.swift` | 113 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/editor/MkZoomControlsView.kt` |
| `AppShell/Scenes/Onboarding/OnboardingView.swift` | 182 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/onboarding/MkOnboardingView.kt` |
| `AppShell/Scenes/Paywall/PaywallView.swift` | 444 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/paywall/MkPaywallView.kt` |
| `AppShell/Scenes/Settings/FontManagementView.swift` | 265 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkFontManagementView.kt` |
| `AppShell/Scenes/Settings/GeneralSettingsView.swift` | 296 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkGeneralSettingsView.kt` |
| `AppShell/Scenes/Settings/LicenseFontDetailView.swift` | 173 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkLicenseFontDetailView.kt` |
| `AppShell/Scenes/Settings/LicensingView.swift` | 121 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkLicensingView.kt` |
| `AppShell/Scenes/Settings/PrivacyConsentView.swift` | 168 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkPrivacyConsentView.kt` |
| `AppShell/Scenes/Settings/SettingsPlaceholderView.swift` | 286 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkSettingsPlaceholderView.kt` |
| `AppShell/Scenes/Settings/SupportSettingsView.swift` | 86 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkSupportSettingsView.kt` |
| `AppShell/Scenes/Settings/SyncSettingsView.swift` | 147 | `app/src/main/kotlin/net/binjamshid/makhtoot/scenes/settings/MkSyncSettingsView.kt` |
| `AppShell/Support/MKAppSignpost.swift` | 47 | `app/src/main/kotlin/net/binjamshid/makhtoot/support/MkAppSignpost.kt` |
| `AppShell/Support/MKArabicRelativeDate.swift` | 43 | `app/src/main/kotlin/net/binjamshid/makhtoot/support/MkArabicRelativeDate.kt` |

> `SettingsPlaceholderView.swift` is the iOS side's own placeholder screen (pre-existing, not
> something this port introduces) — port its Kotlin equivalent with the same name;
> `Scripts/android/check-no-stubs.sh`'s `Placeholder` grep targets net-new coming-soon UI, not a
> 1:1 port of an already-named iOS type. Note this distinction in the impl log so G1/G8 do not
> misread this file as a violation. **`EditorPlaceholderView.swift` is different and must not be
> confused with `SettingsPlaceholderView.swift`**: per spine §3.1/§14 it is dead, unrouted iOS
> code with no PRD requirement behind it, excluded from the port entirely (see the five-file
> exclusion note in the additional-entry-points table below) — it is not ported under any name.

**Port map — `:app` additional entry points (composition root, debug harnesses, protocol seams).**
Excludes the four iOS developer harnesses — `App/DesignSystemGallery.swift` (161 LOC),
`App/Debug/PathTextHarnessView.swift` (389 LOC), `App/Debug/PerfHUDView.swift` (83 LOC),
`App/Debug/ShapingHarnessView.swift` (232 LOC) — per spine §3.1/§14. Together with
`EditorPlaceholderView.swift` above, that is **947 LOC across 5 files excluded from this agent's
entire stub scope**: internal iOS developer tooling and dead code, backing no `R-*` requirement,
never ported to Kotlin under any name (not even to a `debug`-only source set), and must never be
referenced by `Scripts/android/stub-count.sh` or `check-no-stubs.sh`.
| Swift source | LOC | Kotlin target | Notes |
|---|---|---|---|
| `Makhtoot/App/MakhtootApp.swift` | 83 | `app/src/main/kotlin/net/binjamshid/makhtoot/MkMakhtootApp.kt` | App entry point / composition-root construction (D-231 `MakhtootAppServices` equivalent) |
| `Makhtoot/App/RootView.swift` | 110 | `app/src/main/kotlin/net/binjamshid/makhtoot/MkRootView.kt` | Top-level Compose root, hosts `RootShellView`'s Kotlin equivalent |
| `Makhtoot/App/UIChromeFontBootstrap.swift` | 47 | `app/src/main/kotlin/net/binjamshid/makhtoot/MkUiChromeFontBootstrap.kt` | 9 bundled UI-chrome fonts (D-317) — no SF-Arabic dependency to replace, straightforward asset-font registration |
| `Makhtoot/Stubs/ProjectLibraryProviding.swift` | 312 | `app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkProjectLibraryProviding.kt` | Protocol/interface — real definition (interfaces are not stub bodies), implementations arrive in Batch 3.6/3.4 |
| `Makhtoot/Stubs/AlwaysPremiumEntitlementStub.swift` | 25 | `app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkAlwaysPremiumEntitlementStub.kt` | Test/dev-only entitlement stub — must stay non-Release-reachable, mirroring D-229(3)'s `#if DEBUG` discipline via a `debug`-variant source set, not a runtime flag |
| `Makhtoot/Stubs/SyncStatusProviding.swift` | 45 | `app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkSyncStatusProviding.kt` | Protocol/interface — real definition |
| `Makhtoot/Stubs/NoOpAnalyticsRecorder.swift` | 13 | `app/src/main/kotlin/net/binjamshid/makhtoot/stubs/MkNoOpAnalyticsRecorder.kt` | Real definition — this is FDA-04's permanent no-op uploader shape, not a temporary stub |

**Tasks.**
1. For every row across the three port maps above, create the Kotlin file at the listed target
   path, mirroring Swift subdirectory structure into lowercase package segments exactly as 1.3
   does (`Arrange/` → `arrange/`, `PathText/` → `pathtext/`, `Trial/` → `trial/`, `Referral/` →
   `referral/`, `Themes/` → `themes/`, `Generators/` → `generators/`, `Instantiation/` →
   `instantiation/`, `Provenance/` → `provenance/`, `Rendering/` → `rendering/`, `Browser/` →
   `browser/`, `Model/` → `model/` (note: `mk-assets/.../model/` is a different package path
   than `:mk-model` — do not conflate the two), `Undo/` → `undo/`, `Metadata/` → `metadata/`,
   `Internal/` → `internal/` — Kotlin's `internal` visibility modifier is a keyword, so this
   directory segment must be a plain lowercase package name, not a language-reserved word
   collision; verify it compiles and note in the impl log if renamed to avoid ambiguity).
2. Data classes/enums (`MKAssetDescriptor`, `MKEntitlementDetail`, `MKSyncStatus`,
   `MKConsentRecord`, `MKThemeColorHelpers`-backed theme token shapes, `CanvasMode`,
   `SelectionState`, etc.) get real Kotlin definitions; every function/method body is
   `throw MkNotYetPorted("<module>.<symbol>")`, exactly as 1.3.
3. `Makhtoot/Stubs/ProjectLibraryProviding.swift` and `SyncStatusProviding.swift` are Swift
   `protocol`s — port them as Kotlin `interface`s with real method signatures (interfaces have
   no bodies to stub); their eventual implementations arrive with Batch 3.6
   (`MkPersistenceProjectLibrary`) and Batch 6.3 (sync status), not this agent.
4. `AlwaysPremiumEntitlementStub` must land in a `debug`-only Gradle source set on `:app`
   (`src/debug/kotlin/...`, not `src/main/kotlin/...`) so it is absent from a release build by
   construction — same mechanism spine D-321 mandates for the referral module, applied here to
   the pre-existing dev/debug entitlement stub (spine §17: `src/debug/` is correct, never
   `src/main/`). Adjust its port-map target path from `src/main/kotlin/` to `src/debug/kotlin/`
   accordingly when writing the file (the table shows the logical target; the debug-variant root
   is the actual physical path — record this substitution explicitly in the impl log so 1.1/G1
   do not expect this file under `src/main/kotlin/`). **This is the only file this agent places
   in `src/debug/`.** `DesignSystemGallery.swift` and the three `Makhtoot/App/Debug/*` harness
   views are not a `debug`-source-set case at all — they are excluded from the port entirely
   (task list above, five-file exclusion note) and must not be written to any source set, debug
   or main.
5. For the `:app` screen-level entry points (the 48-file `AppShell` port map), write each
   Composable's function signature as a real, callable stub (e.g.
   `@Composable fun EditorScene(viewModel: EditorViewModel) { throw MkNotYetPorted(...) }` is not
   valid Compose — a `@Composable` stub body should render a minimal placeholder that itself is
   **not** a `Placeholder`-named type banned by `check-no-stubs.sh`; instead render nothing
   (`Unit`) or a bare `Box(Modifier)` and route the *logic* symbols (ViewModel methods, adapter
   functions) through `MkNotYetPorted`. Note this distinction explicitly in the impl log: UI
   entry points get an inert placeholder body, everything else gets `MkNotYetPorted`, and
   neither is a "coming soon" in the product sense since no screen is reachable via navigation
   yet (Batch 7 wires navigation).
6. Write one minimal test per module (10 total, including `:app`) confirming a representative
   stubbed symbol throws and a representative data class round-trips.

**Acceptance.**
- `./gradlew :mk-canvas:testDebugUnitTest :mk-export:testDebugUnitTest :mk-fonts:testDebugUnitTest :mk-persistence:testDebugUnitTest :mk-sync:testDebugUnitTest :mk-store:testDebugUnitTest :mk-analytics:testDebugUnitTest :mk-designsystem:testDebugUnitTest :mk-assets:testDebugUnitTest :app:testDebugUnitTest` green.
- `./gradlew :mk-canvas:lintDebug` (and the other nine, incl. `:app`) green.
- Every symbol listed for these nine library targets plus `:app`'s screen-level entry points in
  `android/API_SURFACE.md` (library targets) / this packet's app port map (`:app`) has a
  corresponding Kotlin declaration.
- `AlwaysPremiumEntitlementStub.kt` — the only debug-only file this agent produces — lives under
  `:app`'s `src/debug/kotlin/`, confirmed absent from `src/main/kotlin/`.
- The five excluded files (`DesignSystemGallery`, the three `Debug/*` harness views,
  `EditorPlaceholderView`) appear nowhere in this agent's output, under any source set:
  `find android/app/src/main/kotlin android/app/src/debug/kotlin -iname '*Harness*' -o -iname
  'DesignSystemGallery*' -o -iname 'EditorPlaceholderView*'` returns nothing.
- `bash Scripts/android/stub-count.sh` reports a non-zero count including this agent's modules.
- Requirements covered: none close yet — see `android/PARITY_MATRIX.md`.

**Impl log.** `android/docs/impl-log/BATCH-1.4.md`

---

## Appendix — file-ownership matrix (collision proof)

| Path (prefix) | 1.1 | 1.2 | 1.3 | 1.4 |
|---|---|---|---|---|
| `android/settings.gradle.kts`, `android/gradle/**`, `android/build-logic/**`, `android/build.gradle.kts`, `android/gradle.properties` | ✅ | | | |
| `android/*/build.gradle.kts` (all 18 modules) | ✅ | | | |
| `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/**` | ✅ | | | |
| `Scripts/android/*.sh` | ✅ | | | |
| `.github/workflows/android-ci.yml` | ✅ | | | |
| `android/mk-native/CMakeLists.txt`, `android/mk-native/third_party/**` | | ✅ | | |
| `android/mk-native/src/main/cpp/**` | | ✅ | | |
| `android/mk-native/src/main/kotlin/**` | | ✅ | | |
| `android/mk-native/src/test/kotlin/**` | | ✅ | | |
| `android/mk-foundation/src/**` | | | ✅ | |
| `android/mk-model/src/**` | | | ✅ | |
| `android/mk-textengine/src/**` | | | ✅ | |
| `android/mk-arrange/src/**` | | | ✅ | |
| `android/mk-pathtext/src/**` | | | ✅ | |
| `android/mk-render/src/**` | | | ✅ | |
| `android/mk-color/src/**` | | | ✅ | |
| `android/mk-canvas/src/**` | | | | ✅ |
| `android/mk-export/src/**` | | | | ✅ |
| `android/mk-fonts/src/**` | | | | ✅ |
| `android/mk-persistence/src/**` | | | | ✅ |
| `android/mk-sync/src/**` | | | | ✅ |
| `android/mk-store/src/**` | | | | ✅ |
| `android/mk-analytics/src/**` | | | | ✅ |
| `android/mk-designsystem/src/**` | | | | ✅ |
| `android/mk-assets/src/**` | | | | ✅ |
| `android/app/src/main/kotlin/**`, `android/app/src/debug/kotlin/**`, `android/app/src/test/kotlin/**` | | | | ✅ |
| `android/docs/impl-log/BATCH-1.1.md` | ✅ | | | |
| `android/docs/impl-log/BATCH-1.2.md` | | ✅ | | |
| `android/docs/impl-log/BATCH-1.3.md` | | | ✅ | |
| `android/docs/impl-log/BATCH-1.4.md` | | | | ✅ |

No file has two owners. 1.1 owns Gradle *configuration* (`build.gradle.kts`, `settings.gradle.kts`,
scripts, CI, manifest) for every module including the 16 that 1.3/1.4 populate — configuration
and `src/` are always disjoint paths within the same module directory, so 1.1 never collides
with 1.3/1.4 even though all three "touch" the same module. **1.3 and 1.4 own disjoint module
sets**: 1.3 has `mk-foundation`, `mk-model`, `mk-textengine`, `mk-arrange`, `mk-pathtext`,
`mk-render`, `mk-color` (7 modules); 1.4 has `mk-canvas`, `mk-export`, `mk-fonts`,
`mk-persistence`, `mk-sync`, `mk-store`, `mk-analytics`, `mk-designsystem`, `mk-assets`, `app`
(10 modules) — 17 total, matching all 16 `MakhtootKit`-derived library modules plus `:app`
exactly once each; `:mk-native` is 1.2's alone. Zero overlap.
