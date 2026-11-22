# BATCH-1.1.md — Agent 1.1: Gradle scaffold, version catalog, CI and ratchet scripts

Batch 1 · Agent 1.1 (`ANDROID_TASK_PACKETS/BATCH-1.md` lines 22-226). Gate: G1.
Session interrupted once mid-run (process exit, not an error) and resumed from
verified on-disk state; this log reflects the final state, not the interrupted
one.

## Toolchain actually pinned (verified on this machine, not assumed)

| Item | Spec (D-300) | Pinned | Where |
|---|---|---|---|
| JDK | 17 | Temurin **17.0.19** at `/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home` | `android/gradle.properties` (`org.gradle.java.home`, explicit — the shell default is JDK 21) + `JavaLanguageVersion.of(17)` toolchain in `ConfigureKotlinAndroid.kt` |
| AGP | 8.7+ | **8.7.3** | `android/gradle/libs.versions.toml` (`agp`), hardcoded again in `build-logic/convention/build.gradle.kts` (see deviation note below) |
| Kotlin | 2.1 | **2.1.0** | `libs.versions.toml` (`kotlin`) |
| Gradle | (unspecified) | **8.11.1** (wrapper) | `android/gradle/wrapper/gradle-wrapper.properties` — chosen because the globally-installed Gradle 9.6.1 is ahead of what AGP 8.7.3 supports; 8.11.1 is the version documented as compatible with AGP 8.7.x |
| NDK | **r27** | **28.2.13676358** (installed; no r27 side-by-side) | `libs.versions.toml` (`ndk`) |
| CMake | (unspecified) | **3.22.1** (only version installed) | `libs.versions.toml` (`cmakeVersion`) |
| minSdk / compileSdk / targetSdk | 29 / 36 / 36 (FDA-07) | 29 / 36 / 36 | `ConfigureKotlinAndroid.kt` + per-module/app convention plugins |

**NDK deviation, stated plainly per the launch instructions:** D-300 specifies
NDK r27. This machine has only r28 (28.2.13676358) installed and no r27
side-by-side install. r28 is pinned explicitly in `libs.versions.toml` rather
than left to "whatever is default" — the convention plugin
(`MkAndroidNativeConventionPlugin.kt`) reads `libs.findVersion("ndk")`, so the
change back to r27, if the founder wants strict D-300 adherence, is a
one-line edit to `libs.versions.toml` after running
`sdkmanager --install "ndk;27.2.12479018"`, not a structural change.

AGP 8.7.3 also logs a (non-fatal) warning that it was only tested up to
compileSdk 35, not 36 — expected, since 36 is very new relative to 8.7.x;
left as a warning, not suppressed, so it stays visible rather than being
silently hidden.

## 18-module scaffold and dependency wiring

All 18 modules from `ANDROID_SPINE.md` §3.1 are included in
`android/settings.gradle.kts`. Every `build.gradle.kts` wires the module
dependency edges from spine §3.2 **exactly** (generated programmatically from
that table, then spot-checked): no `:mk-export`→`:mk-store` edge, no
`:mk-sync`→`:mk-store` edge — both modules reach entitlement state only via
`MKEntitlementProviding`/`MkEntitlementProviding` in `:mk-foundation`, a
dependency every module already has.

`:mk-native` has no module dependencies (it is the graph's leaf); it is
depended on by exactly `:mk-textengine`, `:mk-render`, `:mk-export`,
`:mk-fonts`, `:mk-color`, matching spine §3.2's "every module that shapes,
outlines, or colour-transforms" rule. `:app` depends on all 17 others.

Convention plugins (`android/build-logic/convention/src/main/kotlin/`):
- `mk.android.library` — the 14 plain engine modules.
- `mk.android.library.compose` — `mk-designsystem` and `mk-canvas` only (the
  two modules that touch Compose surfaces directly per D-306/D-317).
- `mk.android.application` — `:app` (Compose, `resourceConfigurations += "ar"`
  for D-318, debug-only `referral` source set + `BuildConfig.REFERRAL_ENABLED`
  for D-321, signing-config placeholder for Agent 9.2's Batch 9 takeover).
- `mk.android.native` — `:mk-native` only (CMake/NDK wiring: path to
  `CMakeLists.txt`, four ABIs — arm64-v8a, armeabi-v7a, x86_64, x86 — per
  Agent 1.2's task).

`namespace` is set explicitly per module's own `build.gradle.kts` (not
derived mechanically in the convention plugin) because `mk-native`'s package
root (`...mk.nativebridge`) is not a regular transform of the module name —
documented inline in `MkAndroidLibraryConventionPlugin.kt`.

## Gradle/version-catalog gotcha discovered and fixed (record for future agents)

Declaring a version catalog named `"libs"` explicitly in
`android/settings.gradle.kts` (`versionCatalogs { create("libs") {
from(files("gradle/libs.versions.toml")) } }`) **collided** with Gradle's own
automatic convention-based registration of `gradle/libs.versions.toml` as a
catalog named `"libs"` — Gradle 8.11 rejects this with "In version catalog
libs, you can only call the 'from' method a single time." Fix: removed the
explicit `versionCatalogs` block entirely; the file is picked up by
convention. `android/build-logic/settings.gradle.kts` cannot declare its own
`"libs"` catalog pointing at the same TOML either, for the same reason, once
wired in via `pluginManagement { includeBuild("build-logic") }` — its AGP/
Kotlin plugin versions are therefore hardcoded (`agpVersion`/`kotlinVersion`
constants in `build-logic/convention/build.gradle.kts`), with an explicit
comment that they must be kept in sync by hand with `libs.versions.toml`.

**Second gotcha, hit twice (once in my own code, once found in Agent 1.2's
`MkFontBlob.kt` during the full build):** Kotlin block comments (`/* */`)
**nest** — a glob-style doc-comment fragment like `` `src/main/cpp/**`/`src/main/kotlin/**` `` `**` contains a literal `/*` substring
(`cpp/**` → the `/` before `**` plus the first `*` reads as an opener), which
opens a second nested comment the lexer then never sees closed, producing
"Unclosed comment" at end-of-file with no line number pointing at the real
cause. Fixed my own convention-plugin KDoc by rewriting it as `//` line
comments. **Not fixed** in `mk-native/src/main/kotlin/.../MkFontBlob.kt:66`
(Agent 1.2's file, outside this agent's ownership) — flagged in "Blockers"
below since it is the actual reason `:mk-native:compileDebugKotlin` fails
right now, not a native/JNI problem.

## Glue artifacts (spine §11) — all present

- `android/docs/CONTRACT_CHANGES.md` — append-only format documented, zero
  real entries, `gate.sh`'s pending-check verified against it (passes).
- `android/app/src/main/res/values/strings.xml` — installed by concatenating
  `android/strings/strings.xml` (52 keys) and `android/strings/app-strings.xml`
  (363 keys) **verbatim**, after
  programmatically verifying **zero key overlap** between the two files.
  415 keys total, valid XML (verified via `xml.dom.minidom`).
- `android/app/src/main/assets/fonts/**` — all **87** `.ttf` files across
  **45** families copied from `MakhtootKit/Sources/MKFonts/Resources/Fonts/`,
  each verified byte-for-byte against `android/strings/font-manifest.json`'s
  recorded sha256 before/after copy (0 mismatches). Zero prohibited fonts
  present (the Fonts directory itself contains no KFGQPC/Uthmanic family at
  all — confirmed by directory listing, not just by the manifest's own
  claim). `LICENSE-OFL.txt`/`VERIFICATION.md`/stray editor-cache files inside
  each source family directory are correctly excluded — only `.ttf` files are
  copied.
- `android/app/src/main/res/xml/backup_rules.xml` **and**
  `data_extraction_rules.xml` — both present, both restricted to exactly one
  path: `datastore/mk_trial_state.preferences_pb` (the D-312 trial DataStore
  blob's file name, fixed here for Batch 6 · Agent 6.2 to match exactly).
  **Naming deviation, recorded per spine §9's "document every deviation"
  rule:** the packet's literal path `dataExtractionRules.xml` (camelCase) is
  not a legal Android resource file name — aapt2 requires
  `[a-z0-9_.]+` for file-based resources under `res/`. Used the valid,
  conventional `data_extraction_rules.xml` instead (and referenced it as
  `@xml/data_extraction_rules` from the manifest); the camelCase form would
  not have built.
- `Scripts/android/no-stubs-allowlist.txt` — contains exactly the two named
  legitimate permanent matches (`MkNotYetPorted.kt`, `MkSettingsPlaceholderView.kt`)
  with one-line reasons each, at the frozen paths from spine §11.

## String-resource install (spine §11 founder amendment)

| Source | Keys | Installed to |
|---|---|---|
| `android/strings/strings.xml` (0.4) | 52 | `android/app/src/main/res/values/strings.xml` |
| `android/strings/app-strings.xml` (0.6a) | 363 | same file, appended (0 key collisions, verified programmatically) |
| `android/strings/modules/<module>-strings.xml` (13 files) | 154 | each named module's own `src/main/res/values/strings.xml` |
| **Total** | **569** | verified: `grep -c '<string ' -r` across all 14 installed files sums to exactly 569 |

The 13 modules (`mk-arrange`, `mk-assets`, `mk-canvas`, `mk-color`,
`mk-designsystem`, `mk-export`, `mk-fonts`, `mk-foundation`, `mk-model`,
`mk-persistence`, `mk-render`, `mk-store`, `mk-sync`) all validate as
well-formed XML.

**Deliberate, documented exception to the frozen ownership matrix:**
`ANDROID_TASK_PACKETS/BATCH-1.md`'s appendix assigns every module's `src/**`
to Agent 1.3 or 1.4 exclusively, with no carve-out for `res/`. The founder's
post-freeze string-externalization instruction explicitly assigns the
13 module-level `strings.xml` installs to Agent 1.1. Both are true at once
because the two agents' actual file paths never collide: 1.3/1.4 write
`src/main/kotlin/**`, only `src/main/res/values/strings.xml` changed
in those same 13 module directories — zero overlapping paths, verified before
writing (no Kotlin file existed at any of those paths at write time). Recorded
here per spine §9's instruction to log a deviation rather than make it
silently.

## Scripts (`Scripts/android/*.sh`)

`gate.sh`, `stub-count.sh`, `check-no-stubs.sh`, `check-localization.sh`,
`check-design-tokens.sh`, `referral-release-grep.sh` — all six written,
`chmod +x`'d, `bash -n` syntax-checked clean, and actually run (not just
written) against the real repo state:

- `stub-count.sh`: printed **1081** at last run (rising as Batches — actually
  as Agents 1.2/1.3/1.4 continue landing contract stubs concurrently within
  this same batch; the number is expected to be large at G1 and 0 only at G8,
  per spine ground rule 4).
- `check-no-stubs.sh` (advisory mode, no `--gate` arg / gate < 8): reports
  `Placeholder` hits inside legitimate KDoc prose (e.g. "Placeholder for the
  structured-logging handle...") in files that are not the two allowlisted
  ones — expected false-positive noise from a deliberately blunt, mechanical
  ratchet (mirrors the iOS script's own bluntness); non-blocking before G8.
- `check-localization.sh` / `check-design-tokens.sh`: both report 0
  violations (BASELINE=0) against the current tree.
- `referral-release-grep.sh` (no argument): prints the documented
  "not runnable pre-archive" skip, exit 0 — correct pre-Batch-9 behaviour.
- `gate.sh 0`: **PASSES** — contract-changes step clean; PARITY_MATRIX.md
  covers exactly 318 R-ids (not 319, verified against the same
  `\*\*R-[0-9]+\.[0-9]+[a-z]?` extraction rule spine §0 specifies for
  PRD.md, cross-diffed id-for-id against PARITY_MATRIX.md's plain-table
  `R-` column — identical sets); D-300..D-325 all present in
  DECISIONS_LOG.md; API_SURFACE.md lists all 16 targets;
  DETERMINISM_EXCLUSIONS.json parses and is consumed (not hard-coded) for
  the export/*.jpg, export/*.pdf exclusion — the byte-identical
  regeneration diff itself needs Agent 0.2's Swift golden-export tool, which
  is outside `android/`/`Scripts/android/`, so `gate.sh` documents that
  sub-step rather than fake-passing it.
- `gate.sh 1`: implemented (runs `./gradlew help` then `./gradlew
  assembleDebug`, publishes stub count, runs `check-no-stubs.sh --gate 1` in
  advisory mode) but **not run to a clean PASS** this session, because
  `assembleDebug` genuinely fails right now for reasons entirely outside this
  agent's scope (see Blockers). This is the expected, documented G1 state
  while 1.2/1.3/1.4 are still landing files, per this agent's own acceptance
  criteria ("1.3/1.4's stubs land concurrently... report honestly what does
  not yet build").
- `gate.sh 2` through `gate.sh 9`: implemented per spine §6's table (module
  test invocations, SHAPING_DELTAS.md Class-B check, RENDER_TOLERANCE.md
  presence check, stub-count==0 check, PARITY_MATRIX.md unchecked-row check,
  referral-release-grep invocation) but not exercised — their prerequisites
  don't exist yet (correct; those are later batches' job).

## Literal build-command output (never claimed green without running it)

**`cd android && ./gradlew help`** — after fixing the version-catalog
collision and the nested-comment/API-shape issues below:
```
BUILD SUCCESSFUL in 47s
5 actionable tasks: 3 executed, 2 up-to-date
```

**`./gradlew projects`** — lists all 18 modules plus the `:build-logic`
included build, exactly as expected:
```
BUILD SUCCESSFUL in 13s
```

**`./gradlew :mk-foundation:assembleDebug`** — reaches real Kotlin
compilation (manifest processed, R class generated, resources merged,
assets packaged, AAR metadata written) and fails **only** on:
```
Unresolved reference 'MkNotYetPorted'.
Unresolved reference 'MkProjectId'.
```
Both symbols are Agent 1.3's own `mk-foundation` files to create
(`MkNotYetPorted.kt` is explicitly named in 1.3's Owns list) and did not
exist anywhere in the tree at the time of this run. This is not a scaffold
defect — every prior task (manifest merge, resource merge, namespace, R
class, dependency resolution) succeeded.

**`./gradlew assembleDebug` (full, `--continue`)** — 342 actionable tasks,
217 executed, 55 from cache, 70 up-to-date, **4 failed**:
- `:mk-foundation:compileDebugKotlin` — missing `MkNotYetPorted`/`MkProjectId`
  (Agent 1.3's files, not yet landed at run time).
- `:mk-native:compileDebugKotlin` — `MkFontBlob.kt:66:1 Syntax error:
  Unclosed comment` (Agent 1.2's file — the same nested-`/*`-in-KDoc bug class
  already fixed in the convention plugins and still present in
  Agent 1.2's file since it is outside this agent's ownership).
- `:mk-native:configureCMakeDebug[x86]`, `:mk-native:buildCMakeDebug[x86_64]`
  — native (ninja) build failure inside the vendored HarfBuzz build
  (`error opening 'harfbuzz-build/CMakeFiles/harfbuzz.dir/src/harfbuzz.cc.o.d'`),
  Agent 1.2's `third_party`/`CMakeLists.txt` territory, not this agent's.

Everything upstream of those four tasks — Gradle configuration for all 18
modules, dependency resolution across the whole catalog, resource merging
(415+154=569 strings, 87 fonts), manifest processing for `:app`
(reached `processDebugResources`) — succeeded. `assembleDebug` genuinely
cannot go fully green until 1.2's two remaining issues and 1.3's two missing
symbols land; this agent's own scope (every file in its Owns list) is
complete and correctly wired.

## CI workflow

`.github/workflows/android-ci.yml` written last (it was the one item missed
during the mid-session interruption — caught during the resume verification
pass). Mirrors `ci.yml`'s header discipline: only jobs actually run locally
and confirmed green are included (`stub-count.sh`, `check-no-stubs.sh`
advisory, `check-localization.sh`, `check-design-tokens.sh`,
`referral-release-grep.sh` no-arg skip, `gate.sh 0`, `./gradlew help`,
`./gradlew projects`). Full `assembleDebug` and `gate.sh 1` are explicitly
and honestly left out with a comment explaining why (the same four
sibling-owned blockers below) — added once they are actually green, not
before.

## Blockers outside this work item

1. `android/mk-foundation/src/main/kotlin/.../MkNotYetPorted.kt` does not
   exist yet (Agent 1.3's file). Every module depending on `:mk-foundation`
   (i.e. every module) cannot compile until it lands.
2. `MkProjectId` type referenced by `MkDocumentStoring.kt` is undefined
   (Agent 1.3's territory).
3. `android/mk-native/src/main/kotlin/.../MkFontBlob.kt:66` has an unclosed
   Kotlin block comment (same bug class documented above under "Gradle/
   version-catalog gotcha") — Agent 1.2's file.
4. `:mk-native`'s vendored HarfBuzz CMake build fails on the x86/x86_64 ABI
   configurations with a ninja dependency-file path error — Agent 1.2's
   `CMakeLists.txt`/`third_party/harfbuzz` territory.

The four items are outside this scope under the packet's explicit
instruction not to write Kotlin/C++ source or touch another agent's `src/`.

## Acceptance checklist (from the packet)

- [x] `cd android && ./gradlew help` succeeds, lists all 18 modules.
- [x] `./gradlew :mk-foundation:build` / a couple other modules do not fail
      for *configuration* reasons — confirmed; the only failures are missing
      symbols/native-build issues in sibling agents' `src/` content.
- [x] `bash Scripts/android/stub-count.sh` runs without error (prints a
      count — 1081 as of the last run, correctly non-zero since 1.3/1.4 are
      actively landing stubs).
- [x] Manifest / `locales_config.xml` / `backup_rules.xml` /
      `data_extraction_rules.xml` all validate as XML and contain the
      required RTL/locale/backup settings.
- [x] `strings.xml` installed, entry count matches (415 = 52+363, verified
      disjoint).
- [x] `assets/fonts/**` contains exactly 87 `.ttf` files across 45 families,
      zero prohibited fonts.
- [x] `CONTRACT_CHANGES.md` exists, documented format, zero real entries.
- [x] `no-stubs-allowlist.txt` exists, lists exactly the two named matches.
- [x] Requirements covered: infrastructure only, no `R-id` closes here (per
      packet).

## Addendum 2026-07-31 — two CONTRACT_CHANGES.md entries applied

Both filed by the "Batch 1.4-repair" agent, both real external-library
dependency additions (not invented module edges), applied per spine §4
ground rule 5 / §11 (this agent is the sole applier of Gradle changes filed
through the contract-changes channel).

1. **`:mk-store`** — added `implementation(libs.play.billing.ktx)`
   (`com.android.billingclient:billing-ktx`, already catalog-present as
   `play-billing-ktx` since this agent's original version-catalog pass;
   simply not wired into any module until now). The repair log explains that
   `MKProductCatalog.swift`'s `product(for:) -> Product?`
   needs Play Billing's `ProductDetails` on the classpath to type against
   (D-311); the module-local `MkPlatformProductHandle` placeholder in the
   contract stub is untouched — Batch 6 · Agent 6.1 still owns the real
   implementation. No module-graph edge added; spine §3.2's dependency table
   for `:mk-store` (`:mk-foundation` only) is unchanged.

2. **`:mk-persistence`** — added `alias(libs.plugins.ksp)` to the plugins
   block plus `implementation(libs.androidx.room.runtime)`,
   `implementation(libs.androidx.room.ktx)`, `ksp(libs.androidx.room.compiler)`.
   Rationale in the repair log: `MKMetadataStore.swift`'s
   `makeContainer(url:) -> ModelContainer` / `MKMetadataSchema.models`
   reference SwiftData types with no Kotlin equivalent; D-308 specifies Room
   replaces SwiftData for **metadata only, never the scene graph** — that
   boundary is enforced at the source level by whichever Batch 3 agent
   writes the real `MkMetadataStore`/`MkMetadataModels`, not by this
   dependency wiring; this change only makes Room's real types resolvable.
   Module-local placeholders (`MkMetadataContainer`,
   `List<kotlin.reflect.KClass<*>>`) untouched. No module-graph edge added;
   spine §3.2's dependency table for `:mk-persistence`
   (`:mk-model`, `:mk-foundation`) is unchanged.

Both `CONTRACT_CHANGES.md` rows flipped from `pending` to `applied`.

**Compile verification, literal results:**
- `./gradlew :mk-store:compileDebugKotlin :mk-persistence:compileDebugKotlin`
  (online, first run after wiring — Play Billing had never been resolved by
  any module before, so a pure `--offline` first attempt correctly failed
  with "No cached version... available for offline mode", not a wiring bug):
  `BUILD SUCCESSFUL in 51s` (`33 actionable tasks: 3 executed, 30 up-to-date`),
  including `:mk-persistence:kspDebugKotlin` running cleanly.
- `./gradlew clean :mk-store:compileDebugKotlin :mk-persistence:compileDebugKotlin --offline`
  (clean build, fully offline, dependency now cached): **`BUILD SUCCESSFUL in
  47s`** (`54 actionable tasks: 23 executed, 27 from cache, 4 up-to-date`) —
  genuine green from a clean state, not a stale/up-to-date false positive.

**Gate pending-check confirmation:** ran the exact grep pattern
`gate.sh`'s contract-changes step uses
(`grep -E '\|\s*pending\s*\|?\s*$' android/docs/CONTRACT_CHANGES.md`)
directly against the file — zero matches (exit 1), confirming the
pending-entry gate check clears. A full `bash Scripts/android/gate.sh 1` run
was started to double-check end-to-end but was stopped before completing its
(multi-minute) full `assembleDebug` step, since that step is known to still
fail for unrelated, concurrently-being-repaired reasons (mk-fonts/mk-sync/
mk-analytics repair agent's in-flight work, `MkFontBlob.kt`'s unclosed
comment, the vendored-HarfBuzz CMake/ninja failure — all previously
documented above and none of them this agent's to fix); the pending-check
step itself, which runs first and prints before any of that, is what was
confirmed clean both directly and via the start of that run.

**No Kotlin source touched** — only the two `build.gradle.kts` files and
`CONTRACT_CHANGES.md`, per the ownership note in this task.
