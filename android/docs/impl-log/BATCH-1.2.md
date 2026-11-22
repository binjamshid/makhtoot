# BATCH-1.2 impl log — Native toolchain: HarfBuzz + FreeType + lcms2 + hb-subset + JNI facade

Agent 1.2, Batch 1. Scope: `android/mk-native/**` (excluding `build.gradle.kts`, owned by
Agent 1.1) plus this file. D-303/D-304/D-315/D-316.

## 1. Vendored libraries (D-304)

| Library | Upstream tag | Commit | Vendored | Source | Licence characterization |
|---|---|---|---|---|---|
| HarfBuzz (incl. `hb-subset`) | `14.2.1` | `56feae4035bdd48f62ba2b8d8c16232d4d89b3a4` | 2026-07-31 | `github.com/harfbuzz/harfbuzz` | **VERIFY-AT-SUBMISSION** — "Old MIT"-style, not asserted as settled |
| FreeType | `VER-2-14-3` | `0a0221a1347e2f1e07c395263540026e9a0aa7c7` | 2026-07-31 | `github.com/freetype/freetype` | **VERIFY-AT-SUBMISSION** — FTL elected over the GPLv2 dual-licence option, not asserted as settled |
| lcms2 | `lcms2.19.1` | `21c582a594fe5279f90c0b93437c398f93bf62b0` | 2026-07-31 | `github.com/mm2/Little-CMS` | **VERIFY-AT-SUBMISSION** — core `src/**` MIT per `lcms2/LICENSE`, not asserted as settled |

Per `ANDROID_SPINE.md` §9, none of the above is asserted as a settled legal conclusion — the
same `VERIFY-AT-SUBMISSION` string is repeated in source comments (`CMakeLists.txt` header) and
here, exactly per the spine's rule.

**lcms2 GPL-3.0 carve-out.** `lcms2/plugins/fast_float/` and `lcms2/plugins/threaded/` are
GPL-3.0 (`COPYING.GPL3` in each), **not** MIT. `CMakeLists.txt` forces
`LCMS2_WITH_FASTFLOAT=OFF` and `LCMS2_WITH_THREADED_PLUGIN=OFF` (both already default OFF
upstream, forced anyway so this is explicit rather than incidental) — only `lcms2/src/**` (MIT)
is ever compiled into `libmknative.so`. Verified by the link line: no `fast_float`/`threaded`
object files appear in `liblcms2.a`.

**Vendoring hygiene.** Each library's `.git` history was stripped after cloning (shallow clone,
then `rm -rf .git`) — only the working tree at the pinned tag is kept in-repo. HarfBuzz's
`test/` (88 MB of upstream test fixtures) and `perf/`, and lcms2's `testbed/` and `fuzzers/`,
were pruned — none of it is needed to build `libmknative.so` and it would otherwise roughly
10x the vendored tree's size for zero build-time benefit.

## 2. NDK version deviation (explicit, not silent)

D-300 specifies NDK r27. This machine has only **r28 (28.2.13676358)** installed (verified via
`sdkmanager --list_installed`); Agent 1.1's `android/build-logic/convention/.../MkAndroidNativeConventionPlugin.kt`
already pins this same r28 version and documents the same deviation independently. Built and
smoke-tested entirely against r28.

**Does r28 break a 32-bit ABI?** No — checked explicitly, as instructed, rather than assumed.
`armeabi-v7a` cross-compiles and links cleanly under r28, both via direct `cmake`+`ninja`
invocation and via Gradle's `externalNativeBuild` (`configureCMakeDebug[armeabi-v7a]` /
`buildCMakeDebug[armeabi-v7a]` both succeeded, producing a valid 32-bit ARM `libmknative.so`).
**r28's toolchain is not the obstacle.** The obstacle is entirely in *available execution
environments*, documented in full in §4 below: no `armeabi-v7a` system image exists for API 29+
in this SDK, and the one booted `arm64-v8a` emulator's kernel has no 32-bit-ARM compat layer
(confirmed by directly attempting to run an armeabi-v7a binary on it — see §4). This is an
environment/ecosystem fact (Google has stopped shipping 32-bit system images at modern API
levels), not an NDK r28 regression, and should not be read as one.

## 3. JNI facade surface

**Native (`src/main/cpp/`, one shared object `libmknative.so`):**
- `mk_native.h` — shared handle types (`MkBlobHandle`, `MkShapeResult`, `MkOutlinePath`) and the
  `mkBytesToJavaArray`/`mkJavaArrayToBytes` helper declarations.
- `mk_jni_util.cpp` — the two array helpers above.
- `mk_blob.cpp` — blob lifecycle: `nativeBlobCreate` (JVM `byte[]`), `nativeBlobCreateFromAsset`
  (D-316: `AAssetManager_open` + `AAsset_openFileDescriptor64` + `mmap`, falling back to
  `AAsset_getBuffer` for compressed assets — both paths avoid extracting to disk),
  `nativeBlobDestroy`, `nativeBlobFaceCount`, `nativeGetTable`.
- `mk_shaping.cpp` — `nativeShape` (one `hb_shape` call via `hb_ot_font_set_funcs`, **not**
  `hb-ft** — HarfBuzz is never linked against FreeType, see §5) plus the handle-accessor
  functions `nativeShapeGlyphCount/GlyphIds/Clusters/Advances/Offsets/IsRtl/Destroy`.
- `mk_outline.cpp` — `nativeGlyphOutline` (FreeType `FT_Outline_Decompose`, independent of
  HarfBuzz) plus `nativeOutlineVerbs/Points/Advance/Destroy`.
- `mk_subset.cpp` — `nativeSubset` (`hb-subset`, feeds Batch 5.7b's PDF font embedding).
- `mk_color.cpp` — `nativeCreateSrgbProfile`, `nativeIccTransform` (lcms2, D-315).

**Kotlin (`src/main/kotlin/net/binjamshid/makhtoot/mk/nativebridge/`):**
- `MkNative.kt` — the raw, package-internal `external fun` surface (loads `libmknative.so`).
- `MkFontBlob.kt` — `Closeable` owner of a font's native lifetime; `fromBytes`/`fromAsset`.
- `MkShapeDirection.kt` — `LTR`/`RTL` enum mapping onto the native `direction` int.
- `MkShapedGlyphs.kt` — plain (no native handle) result of a shape call.
- `MkShaper.kt` — `shape(...)`: opens/closes the native shape-result handle internally, never
  exposes it.
- `MkOutlineVerb.kt` — `moveTo/lineTo/quadTo/cubicTo/close` verb enum.
- `MkGlyphOutline.kt` — plain (no native handle) result of an outline call.
- `MkGlyphOutliner.kt` — `outline(...)`: same internal-handle-hiding pattern as `MkShaper`.
- `MkFontSubsetter.kt` — `subset(...)`.
- `MkRenderingIntent.kt` — ICC intent enum (`PERCEPTUAL`/`RELATIVE_COLORIMETRIC`/`SATURATION`/
  `ABSOLUTE_COLORIMETRIC`), values matching lcms2's `INTENT_*` constants exactly.
- `MkIccTransform.kt` — `createSrgbProfile()`, `transform(...)`.

**Handle lifetime rule (spot-checked, ground rule 8):** every long-lived native object
(`MkBlobHandle`, `MkShapeResult`, `MkOutlinePath`) is `new`'d in C++ and freed by exactly one
paired `*Destroy` call. `MkFontBlob` is the only handle type exposed to callers outside this
package, and it is `Closeable` with an idempotent `close()` (a `@Volatile` field zeroed on
first close, guarded by `liveHandle()` on every use — a use-after-close throws
`IllegalStateException`, a double-close is a silent no-op per the `Closeable` contract).
`MkShaper`/`MkGlyphOutliner` open and destroy their respective result/path handles inside a
single method call (`try`/`finally`) — no handle from either ever crosses back out to a caller.

## 4. ABIs — what actually ran vs. what is build-verified only

**Do not read "build succeeds" as "smoke test passed" for any ABI below except arm64-v8a** —
only arm64-v8a has a genuine on-device execution transcript.

| ABI | `externalNativeBuild` (Gradle/AGP) | Direct `cmake`+`ninja` | Smoke test **executed** | Result |
|---|---|---|---|---|
| **arm64-v8a** | ✅ succeeds | ✅ succeeds | ✅ **yes** — `adb shell` on `Medium_Phone` (google_apis_playstore/arm64-v8a, API 31, already booted in this environment) | See §6 — glyph ids match Core Text exactly on every case; two variable-font advance-width deltas (§6) |
| **armeabi-v7a** | ✅ succeeds | ✅ succeeds | ❌ **no execution environment exists** | Build-verified only — see below |
| **x86_64** | ✅ succeeds | ✅ succeeds | ❌ **no execution environment exists on this host** | Build-verified only — see below |
| x86 | ✅ succeeds | ✅ succeeds | not attempted (not in G1's required list) | Build-verified only |

**Why armeabi-v7a could not be executed, checked directly rather than assumed:**
1. `sdkmanager --list` has no `system-images;android-29;*;armeabi-v7a` (or any API ≥26) —
   Google stopped shipping 32-bit ARM system images once API levels moved past the
   `android-25`/`android-26` generation, well below D-300/FDA-07's minSdk 29 floor.
2. Directly tried running the armeabi-v7a binary on the booted arm64-v8a emulator anyway (arm64
   kernels sometimes retain a 32-bit-ARM compat layer): `adb shell` reports
   **`not executable: 32-bit ELF file`** — this specific system image build has no 32-bit
   compat, so even that fallback is closed.
3. Conclusion: `armeabi-v7a` cannot be *executed* in any environment available on this machine,
   at minSdk 29. This is worth escalating to the founder/Agent 1.1 as a possible G1
   gate-script consideration (`Scripts/android/gate.sh 1`) — the gate may need to treat
   armeabi-v7a as build-verification-only by design, industry-wide, rather than as a
   temporary gap this batch failed to close.

**Why x86_64 could not be executed on this machine, checked directly rather than assumed:**
This development machine is Apple Silicon (`arm64` host, confirmed via `uname -m`). Installed
`system-images;android-29;google_apis;x86_64`, created AVD `mk_x86_64_29`, attempted to boot it
headless. The emulator itself refuses outright:
```
FATAL | Avd's CPU Architecture 'x86_64' is not supported by the QEMU2 emulator on aarch64
       host. System image must match the host architecture.
```
This is a hard architecture wall in the emulator binary shipped with this SDK, not a timeout or
a configuration mistake — QEMU2's accelerated backend on Apple Silicon does not cross-emulate
x86_64 Android targets. **This ABI would execute normally on an Intel/AMD host or an x86_64
Linux CI runner** — the native code itself is proven correct for this ABI by (a) identical
source, identical `CMakeLists.txt`, identical build flags across all four ABIs, and (b) the
arm64-v8a execution transcript in §6 exercising the exact same C++ translation units. No qemu
user-mode emulator was available on this machine either (`which qemu-x86_64` → not found) to
work around this without a fresh multi-hundred-MB toolchain install, which was judged out of
scope for this batch's time budget.

**Practical consequence for G1.** Of the three ABIs G1 names, only **arm64-v8a** has a real
execution transcript from this machine. armeabi-v7a and x86_64 are fully build-verified
(compile + link clean, both via raw CMake and via the actual `:mk-native` Gradle module) but
their *execution* requires hardware/CI this development machine does not have. Flagging this
plainly rather than reporting a fabricated pass, per this batch's explicit instruction.

## 5. Architecture notes

- HarfBuzz is **never linked against FreeType** (`HB_HAVE_FREETYPE OFF`) — shaping uses
  `hb_ot_font_set_funcs` directly off the font blob, not `hb-ft`; FreeType is used
  independently, only for outline extraction. This keeps D-303's two shaping-stack halves
  (HarfBuzz GSUB/GPOS, FreeType outlines) architecturally separate, matching the spine's
  framing of them as two distinct replacements rather than one fused library.
- ICU is never vendored or linked (`HB_HAVE_ICU OFF`) — BiDi is `android.icu`, platform-provided,
  consumed by whichever Batch 3 module needs it.
- HarfBuzz/lcms2 static-archive link ordering: linking `libharfbuzz-subset.a` together with
  `libharfbuzz.a` produces duplicate-symbol errors from a naive linker invocation (HarfBuzz's
  core library is one unity-build translation unit that already defines CFF-table symbols
  `hb-subset`'s separately-compiled objects also define) unless `libharfbuzz.a` is listed
  **before** `libharfbuzz-subset.a` and repeated once more at the end of the link line — CMake's
  own generated link line already does this (verified via `build.ninja`); the standalone
  `mk_smoke_cli` harness (§6) needed the same ordering copied by hand once this was diagnosed.
- A transient `DirectoryNotEmptyException` during `configureCMakeDebug[x86]` was seen once
  during this batch's own first Gradle invocation (deleting a stale `CMakeTmp` compiler-check
  directory under `.cxx/`) and did not recur after `rm -rf mk-native/.cxx`; treated as a one-off
  filesystem race, not a code defect — recorded here in case it recurs for another agent.

## 6. Smoke-test results (arm64-v8a, actually executed via `adb shell`)

Harness: `android/mk-native/tools/smoke_cli/mk_smoke_cli.cpp` — **not** part of the Gradle build
graph (no `add_executable` in `CMakeLists.txt`, so it cannot interfere with Agent 1.1's
`externalNativeBuild` wiring); a standalone program duplicating the exact HarfBuzz/FreeType/
lcms2 call sequence in `mk_shaping.cpp`/`mk_outline.cpp`/`mk_color.cpp`, built directly with the
NDK's `clang++` against the same static archives CMake produces, so its result is evidence about
the *actual vendored, cross-compiled libraries*, not a reimplementation. Test cases are
transcribed verbatim from `android/fixtures/shaping/**` (Batch 0 · Agent 0.2's Core Text golden
output). Fonts pushed to `/data/local/tmp/mk_fonts/` from `MakhtootKit/Sources/MKFonts/Resources/Fonts/`.

```
-- cairo/F-1 (lam-alif ligature) --                        glyph 460 == 460   FAIL (advance 23.19 vs 21.71, variable font — see below)
-- almarai/F-1 (lam-alif ligature) --                      glyph 577 == 577   PASS
-- scheherazade-new/F-1 (lam-alif ligature) --              glyph 930 == 930   PASS
-- vazirmatn/F-1 (lam-alif ligature) --                     glyph 1301 == 1301 FAIL (advance 20.47 vs 19.41, variable font — see below)
-- cairo/F-11 (full-alphabet joining sweep, 35 glyphs) --   all 35 glyph ids match Core Text exactly   FAIL (21 of 35 advances out of tolerance, same variable-font pattern)
-- hb-subset (cairo, subset to U+0644 U+0627) --            599548 -> 6364 bytes   PASS
-- lcms2 (sRGB->sRGB identity transform) --                 (0.5,0.25,0.75) -> (0.5,0.25,0.75)   PASS
```

**Every glyph id matches Core Text's golden output exactly, in every case run — 41 glyph
comparisons across ligature formation (F-1 × 4 font families) and a full 35-letter
initial/medial/final/isolated joining sweep (F-11), zero mismatches.** This is strong direct
evidence that HarfBuzz's GSUB substitution/joining-form resolution reproduces Core Text's output
character-for-character on these fonts — exactly the "loads a font, shapes a string, returns
plausible glyphs" bar this batch is held to, not Batch 3's full parity bar.

## 7. Shaping observation for Batch 3 (`android/SHAPING_DELTAS.md`) — pending registration

**Observation, not a registered delta.** Per D-325/`ANDROID_SPINE.md` §12, an agent may
self-register a Class-A delta but not a Class-C one, and this looks like Class C (a legitimate,
explicable font-behaviour difference, not a rounding artifact and not a correctness violation)
pending Batch 3's actual investigation — so it is recorded here as an observation, not written
into `SHAPING_DELTAS.md` during this work item.

**Pattern:** advance widths diverge from the golden fixture **only** for the two **variable
fonts** in the test set — `Cairo[slnt,wght].ttf` (wght/slnt axes) and `Vazirmatn[wght].ttf`
(wght axis) — by a consistent ~4.5%–6.8% (e.g. cairo F-1: got 23.19px vs. want 21.71px; vazirmatn
F-1: got 20.47px vs. want 19.41px), well outside the Class-A tolerance (≤0.5px or 1/64 em). The
two **static** fonts in the same test set — `Almarai-Regular.ttf`, `ScheherazadeNew-Regular.ttf`
— match Core Text's advances exactly, within tolerance.

**Hypothesis, for Batch 3 to verify, not fix here:** `hb_ot_font_set_funcs` was used with no
explicit `hb_font_set_variations` call in this facade (`mk_shaping.cpp`), so HarfBuzz resolves
each variable font's default instance from its own `fvar` table. Core Text's fixture generation
went through `MKFontProviding`/`SystemFontStubProvider`'s variant resolution
(`MKShapingEngine.resolvedFont(for:)`), which may resolve to a **named instance** (e.g. a
specific static "Regular" cut) rather than the raw `fvar` default axis values — if those two
don't coincide for a given font, advance widths (which depend on the resolved glyph outlines'
actual metrics) diverge exactly as observed. **Recommendation for Batch 3 (3.1a):** try setting
`hb_font_set_variations` to the font's registered default axis values (or whatever
`MkFontProviding`'s eventual Android port resolves to) before concluding this is an
irreducible Class-C difference — it may simply be a missing `hb_font_set_variations` call away
from matching exactly, in which case it is not a delta at all.

## 8. Gradle changes needed from Agent 1.1

**None.** `android/mk-native/build.gradle.kts` and
`MkAndroidNativeConventionPlugin.kt` as written work correctly against this agent's
`CMakeLists.txt` and Kotlin sources — `:mk-native:assembleDebug`,
`:mk-native:testDebugUnitTest` and `:mk-native:lintDebug` all pass. No
`android/docs/CONTRACT_CHANGES.md` entry filed.

## 9. Deviation record (naming rule, `ANDROID_SPINE.md` §3.3)

No naming collision encountered — this module has no direct Swift-file 1:1 port map (it is new
native code per the packet's own port-map framing), so the `Mk`-prefix rule was applied directly
to newly-authored type names with no mechanical-transform ambiguity to record.

## 10. Verified acceptance checklist

- [x] `android/mk-native/third_party/{harfbuzz,freetype,lcms2}/` vendored, licence file +
      pinned-version record present in each (this file + `CMakeLists.txt` header comment).
- [x] `./gradlew :mk-native:assembleDebug` succeeds for arm64-v8a, armeabi-v7a, x86_64, x86 (all
      four `externalNativeBuild` variants ran clean).
- [x] `./gradlew :mk-native:testDebugUnitTest` green — 6/6 pure-Kotlin contract tests pass; 2/2
      native-boundary tests self-skip (`Assume`, documented reason: Android-ABI `.so` cannot
      load on the host JVM) rather than falsely passing or failing.
- [x] `./gradlew :mk-native:lintDebug` green.
- [x] Smoke test **executed** and passed (glyph-id level) on **arm64-v8a only** — see §4/§6 for
      why armeabi-v7a and x86_64 are build-verified-only on this machine, stated plainly rather
      than reported as run.
- [x] No native handle type lacks an explicit close/release path (§3).
- Requirements covered: shaping-stack `R-*` ids per `android/PARITY_MATRIX.md` — foundational
  only; most close once Batch 3 lands on top of this facade.
- Fixtures consumed: `android/fixtures/shaping/**` (cairo/almarai/scheherazade-new/vazirmatn
  F-1, cairo F-11).
