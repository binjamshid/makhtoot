# Asset rights inventory

Source review updated 22 November 2026. Package entries below reflect source and build declarations. The repository’s [project license](../LICENSE) covers software publicly released under its terms by a rights holder with authority to license it. [Third-party notices](../THIRD_PARTY_NOTICES.md) document separately licensed dependencies. Keep material with unresolved redistribution rights out of a public snapshot or release until it is cleared or replaced.

## Fonts

| Material | Source and attribution evidence | Packaging |
| --- | --- | --- |
| 45 families, 87 TrueType faces | The [iOS font tree](../MakhtootKit/Sources/MKFonts/Resources/Fonts/) has one original `LICENSE-OFL.txt` per family. The [license records](../MakhtootKit/Sources/MKFonts/Resources/LicenseRecords/records.json) list copyright, upstream source revision, Reserved Font Names, and hashes. All 87 SHA-256 values matched the tracked font files. The [verification protocol](../MakhtootKit/Sources/MKFonts/Resources/VERIFICATION_PROTOCOL.md) describes how to record evidence for additions. | [iOS](../MakhtootKit/Package.swift) copies the font tree and license records as MKFonts resources. The [Android app asset tree](../android/app/src/main/assets/fonts/) contains the same 87 font files at matching family-relative paths and SHA-256 values. Each family includes its original OFL notice alongside the fonts. The [verifier](../Scripts/android/check-font-assets.py) checks exact paths and bytes in source and accepts an APK or AAB for release checks. |
| IBM Plex Sans Arabic | The font files and [OFL text](../MakhtootKit/Sources/MKFonts/Resources/Fonts/IbmPlexSansArabic/LICENSE-OFL.txt) use the directory `IbmPlexSansArabic`. The [license record](../MakhtootKit/Sources/MKFonts/Resources/LicenseRecords/records.json) uses `Fonts/IbmPlexSansArabic/LICENSE-OFL.txt`. | Both platforms use the same case-sensitive family path. |
| Downloadable catalog | The [catalog manifest](../MakhtootKit/Sources/MKFonts/Resources/PremiumCatalog/catalog-manifest-v1.json) and [sample manifest](../MakhtootKit/Sources/MKFonts/Resources/PremiumCatalog/manifest.sample.json) describe an Amiri Bold sample download. Before distributing a catalog payload, verify its exact file, hash, source, rights, and notices. | iOS copies the manifest directory. Android has a [test fixture copy of the catalog manifest](../android/fixtures/resources/catalog-manifest-v1.json). The manifests describe downloads separately from the bundled font files. |
| Device fonts and user-imported fonts | Each imported file carries its own terms. Check those terms before sharing a font or embedding it in a distributable asset. The [iOS license record type](../MakhtootKit/Sources/MKFonts/MKLicenseRecord.swift) records embedding evidence. | Device or user-provided fonts can affect exported artifacts. Check the output itself for embedded bytes or outlines when publishing examples. |
| Excluded and restricted candidates | [Historical catalog exclusions](../MakhtootKit/Sources/MKFonts/Resources/EXCLUDED_FONTS.md) record candidate decisions and shaping gates. [Prohibited font sources](../MakhtootKit/Sources/MKFonts/Resources/Fonts/_PROHIBITED.md) record the evidence required before reconsidering restricted families. | Use the font trees to establish which bytes are packaged and the [catalog seed](../MakhtootKit/Sources/MKFonts/Resources/catalog-seed.json) to check catalog entries. |

## Artwork, icons, and working materials

| Material | Source and attribution evidence | Packaging and review |
| --- | --- | --- |
| Ornament and shape library, version 1 | [57 asset entries](../MakhtootKit/Sources/MKAssets/Resources/assets-manifest.json) cover 16 ornaments, 15 shapes, 10 calligraphic elements, 8 frames, and 8 pattern backgrounds. The [57 provenance records](../MakhtootKit/Sources/MKAssets/Resources/provenance-records.json) identify each as original geometry and record its source description. The [sourcing rules](../MakhtootKit/Sources/MKAssets/Resources/ASSET_SOURCING_RULES.md) cover derived material, glyph outlines, and license evidence. | iOS declares MKAssets resources. Android has [matching manifest](../android/fixtures/resources/assets-manifest.json) and [provenance fixtures](../android/fixtures/resources/provenance-records.json), plus [Kotlin generator sources](../android/mk-assets/src/main/kotlin/net/binjamshid/makhtoot/mk/assets/generators/). Confirm the public reuse grant for the geometry and [contact sheets](impl-log/WS-14-contact-sheets/) with the owner. |
| Makhtoot app icon, alternate icons, and branding | The [primary app icon](../Makhtoot/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json) and [alternate PNGs](../Makhtoot/AltIcons/) remain in the Xcode project. Record their creator, source files, and redistribution terms. The root license grants no trademark rights. | The [Xcode project](../Makhtoot.xcodeproj/project.pbxproj) declares these resources. The [Android manifest](../android/app/src/main/AndroidManifest.xml) specifies no launcher icon. |
| Marketing and working files | Marketing captures, browser captures and logs, the logo reference, design explorations, an unidentified JPEG, private founder and research inputs, and machine-local tooling configuration are excluded from this source edition. | The implementation logs retain historical verification notes. Review the rights for any retained illustration or implementation evidence before republishing it elsewhere. |

## Sample projects and test artifacts

The [tutorial example and illustration](../examples/README.md) identify the input text, font source and modifications. The project directory contains two JSON files, and the accompanying image is a rendered PNG.

- The [four source project fixtures](../MakhtootKit/Tests/Fixtures/) contain scene JSON and manifests for 100 shapes, 5,000 shapes, a live Arabic text example, and an arranged lam–alef example. [MKGoldenExport](../MakhtootKit/Sources/MKGoldenExport/) reads the projects and generates [Android parity artifacts](../android/fixtures/), including shaping data, thumbnails, SVG, and raster exports. These are test materials. Before reusing one in public documentation, record permission for the input and review the exported artifact’s font, profile, and any image content.
- Seven historical PDF references were excluded from the source edition. Some contained embedded system font subsets (SF Arabic, Geeza Pro or Helvetica); all seven contained an Apple or HP color profile. The [generator](../MakhtootKit/Sources/MKGoldenExport/ExportGoldens.swift) can produce PDF references locally in its ignored build directory. The [build guide](BUILD.md#export-fixture-checks) describes the opt-in command and structural tests.

## Color profiles

| Material | Source and attribution evidence | Packaging and review |
| --- | --- | --- |
| iOS CMYK fallback | The [ICC resource directory](../MakhtootKit/Sources/MKColor/Resources/ICC/README.md) contains instructions for a future press profile. [ICCProfileStore](../MakhtootKit/Sources/MKColor/ICCProfileStore.swift) resolves the platform’s Generic CMYK fallback. | The Xcode/SwiftPM source has no checked-in press ICC profile. Exported PDFs can embed a profile obtained from the platform. Clear any future press profile and include its notice before adding it to app resources. |
| Android ICC support | [The JNI color code](../android/mk-native/src/main/cpp/mk_color.cpp) creates an sRGB profile through Little CMS and accepts profile bytes for transforms. [MkIccProfileStore](../android/mk-color/src/main/kotlin/net/binjamshid/makhtoot/mk/color/MkIccProfileStore.kt) still has a stub for app-level profile selection. | No standalone ICC file is tracked in Android app or library resources. The five Little CMS files below are vendor test inputs. |
| Locally generated PDF profiles | PDF export may embed profiles from the host system. | Inspect new PDF outputs and record redistribution rights before sharing. The seven historical PDF fixtures are excluded from this source tree. |

## Vendored non-code files

| Material | Evidence | Source distribution review |
| --- | --- | --- |
| Little CMS test ICC profiles | The five upstream test profiles (`test0.icc`, `test1.icc`, `test2.icc`, `test3.icc`, and `test5.icc`) are excluded. | The [Android CMake configuration](../android/mk-native/CMakeLists.txt) disables the vendor tests and plug-ins. |
| HarfBuzz demo fonts | The upstream WASM sample Roboto Regular 2.137 and the GPU demo Parastoo Regular font are excluded, including both encoded copies in the demo header and web page. | The [Android CMake configuration](../android/mk-native/CMakeLists.txt) disables the HarfBuzz GPU and utility targets. |
| Vendor logos, artwork, documentation, and examples | [HarfBuzz’s README](../android/mk-native/third_party/harfbuzz/README.md) identifies its logo’s font and credits the xkcd image source. Its local copy of the xkcd-derived image is excluded. The five Little CMS PDF manuals and its ICC-bearing logo are excluded. | The [native dependency notices](../THIRD_PARTY_NOTICES.md#android-native-code) identify the pinned upstream libraries. Review the terms of any retained documentation assets or artwork before reusing them. |

## Release verification

- Review the intended source snapshot and any visible history. Record exclusions or replacements and attach the evidence for each unresolved asset that remains.
- Inspect the assembled iOS application and Android APK or AAB for each release variant. Compare bundled fonts, notices, artwork, profiles, and native components with this inventory. Confirm the Little CMS plug-in exclusion using the native build outputs and the packaged libraries for every ABI.
- Check that the final distribution delivers the applicable notices for its native code, fonts, and resolved Android dependencies. Update this inventory when the source, dependency pins, or package contents change.
