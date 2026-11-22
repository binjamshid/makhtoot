# Third-party notices

Third-party files retain their own terms and copyright notices under [section 1 of the project license](LICENSE). Preserve the original notices with any redistribution that includes the corresponding material. See the [asset rights inventory](docs/asset-rights.md) for the checked-in fonts, artwork, samples, and color profiles.

This inventory describes the source tree and build declarations inspected on 22 November 2026 at `1b01500`. Release package contents and the notices delivered with them still need verification.

## Android native code

The Android app declares a dependency on `:mk-native`. Its [CMake configuration](android/mk-native/CMakeLists.txt) pins the three vendored libraries and links HarfBuzz, HarfBuzz Subset, FreeType, and Little CMS core into the `mknative` JNI target. The [iOS package manifest](MakhtootKit/Package.swift) declares an empty external Swift package dependency list.

| Component and upstream pin | Source terms and attribution | Android build declaration |
| --- | --- | --- |
| HarfBuzz 14.2.1, `56feae4035bdd48f62ba2b8d8c16232d4d89b3a4` | [HarfBuzz COPYING](android/mk-native/third_party/harfbuzz/COPYING) identifies Old MIT terms and credits the upstream contributors. Preserve that file, source header notices, and applicable separate terms, including [the Microsoft USE files' MIT notice](android/mk-native/third_party/harfbuzz/src/ms-use/COPYING). | Links `harfbuzz` and `harfbuzz-subset`. The app configuration disables HarfBuzz utilities and optional raster, vector, and GPU targets. |
| FreeType 2.14.3, `0a0221a1347e2f1e07c395263540026e9a0aa7c7` | The [FreeType license index](android/mk-native/third_party/freetype/LICENSE.TXT) offers the [FreeType License](android/mk-native/third_party/freetype/docs/FTL.TXT) or [GPLv2 or later](android/mk-native/third_party/freetype/docs/GPLv2.TXT). Makhtoot’s CMake file records the FreeType License choice. See the index for the additional file-specific notices. | Links `freetype`. The configuration disables external zlib, bzip2, PNG, HarfBuzz, and Brotli. FreeType’s bundled zlib 1.3 code has [its own notice](android/mk-native/third_party/freetype/src/gzip/zlib.h) and [record of local modifications](android/mk-native/third_party/freetype/src/gzip/README.freetype). |
| Little CMS 2.19.1 core, `21c582a594fe5279f90c0b93437c398f93bf62b0` | [MIT license and copyright notice](android/mk-native/third_party/lcms2/LICENSE) for the core by Marti Maria Saguer. | Links the static core. CMake disables shared core, tools, tests, and both optional plug-ins. |
| Little CMS `fast_float` and `threaded`, same vendor pin | Both plug-ins are tracked in the repository. Their source headers specify GPL-3.0-or-later and their directories contain [fast_float COPYING.GPL3](android/mk-native/third_party/lcms2/plugins/fast_float/COPYING.GPL3) and [threaded COPYING.GPL3](android/mk-native/third_party/lcms2/plugins/threaded/COPYING.GPL3). See [the upstream plug-in note](android/mk-native/third_party/lcms2/plugins/README.1ST). | Makhtoot forces `LCMS2_WITH_FASTFLOAT` and `LCMS2_WITH_THREADED_PLUGIN` off. The [upstream plug-in build logic](android/mk-native/third_party/lcms2/cmake/Lcms2Plugins.cmake) creates the targets only when their respective flags are on. |

Makhtoot’s Android native text and glyph code uses the FreeType Project. Portions of that software are copyright © 1996–2026 The FreeType Project ([freetype.org](https://freetype.org/)). All rights reserved. See the [FreeType License](android/mk-native/third_party/freetype/docs/FTL.TXT).

Review non-runtime files when preparing a source distribution. The vendor trees also contain documentation, examples, tooling, demo fonts, artwork, and test profiles. The [asset rights inventory](docs/asset-rights.md#vendored-non-code-files) lists material that needs file-specific review. Keep the Little CMS plug-ins’ source notices if their directories are included.

## Android build tooling and resolved dependencies

- The checked-in [Gradle Wrapper JAR](android/gradle/wrapper/gradle-wrapper.jar) has an Apache-2.0 declaration in `META-INF/MANIFEST.MF` and the license text in `META-INF/LICENSE`. The [wrapper configuration](android/gradle/wrapper/gradle-wrapper.properties) pins the Gradle distribution to 8.11.1. The JAR is used by the build tooling.
- The [Gradle version catalog](android/gradle/libs.versions.toml) lists direct dependency versions and entries available for later use. The [app module](android/app/build.gradle.kts), the library module build files, and [convention plugins](android/build-logic/convention/) determine which entries are used. Review resolved runtime and transitive artifacts for each release variant and preserve their applicable license texts, notices, and terms.

## Fonts

Makhtoot tracks 45 font families under the SIL Open Font License 1.1. The [per-family records](MakhtootKit/Sources/MKFonts/Resources/LicenseRecords/records.json) identify upstream revisions, copyright holders, Reserved Font Names, original notice paths, and file hashes. The [original notices](MakhtootKit/Sources/MKFonts/Resources/Fonts/) are in each family directory as `LICENSE-OFL.txt`.

The iOS package copies the fonts and family notices together. The main Android app assets carry all 45 original notices alongside the matching font files. The expected archive locations are `assets/fonts/<family>/LICENSE-OFL.txt` in an APK and `base/assets/fonts/<family>/LICENSE-OFL.txt` in an AAB. Run `python3 Scripts/android/check-font-assets.py <apk-or-aab>` to compare exact paths and bytes against the canonical resources. [Android app assets](android/app/src/main/assets/fonts/) · [Verification script](Scripts/android/check-font-assets.py)

See the font inventory for downloadable and imported fonts. [Font inventory](docs/asset-rights.md#fonts)
