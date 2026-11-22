package net.binjamshid.makhtoot.mk.fonts

// Work item 1.4-repair2. Not one of the 21 Swift source files in the
// MKFonts port map — new supporting infrastructure, same category as
// `mk-render/src/main/kotlin/.../MkRenderPlatformTypes.kt`'s
// `MkDrawingSurface`/`MkPlatformImage` placeholders and the first repair
// pass's `mk-store`/`MkPlatformProductHandle`, `mk-assets`/
// `MkAssetPlatformTypes.kt` precedent.
//
// MKFonts' Swift source draws on three Foundation/CoreText types with no
// direct Kotlin equivalent:
//
// - `URLSession` (`MKCatalogManifestFetchService.session`,
//   `MKFontDownloader.session`) — D-304's carve-out names OkHttp as the
//   Android HTTP substitute, but `:mk-fonts/build.gradle.kts` does not yet
//   depend on it (only Agent 1.1 may add that edge — `ANDROID_SPINE.md`
//   §3.2/§4 ground rule (c)). Filed as a `CONTRACT_CHANGES.md` request
//   rather than silently added to the Gradle file.
// - `Bundle` (`MKFontsResources.bundle`, `MKBundledFontIndex.bundle`,
//   `MKLicensingDataSource.bundle`) — Android's real analogue (D-316) is
//   `android.content.res.AssetManager`, obtained from a `Context` this
//   module does not yet receive anywhere in its public API. Real wiring
//   is Batch 3's `:mk-fonts` implementation concern, not a missing Gradle
//   dependency (`AssetManager` ships with the Android SDK already), so no
//   `CONTRACT_CHANGES.md` entry is needed for this one.
// - `NSAttributedString` (`MKFontCatalog.previewAttributedString`) — no
//   Android type has been chosen yet (`:mk-fonts` has no dependency edge
//   onto `:mk-render`/`:mk-color`, spine §3.2, so it cannot reuse a
//   render-side attributed-text type even if one existed); stays a
//   `:mk-fonts`-local placeholder until that design decision is made.

/**
 * Placeholder for the Foundation `URLSession` `MKCatalogManifestFetchService`
 * and `MKFontDownloader` use to fetch premium font catalog manifests/files
 * on iOS. Android's real type (D-304) is expected to wrap
 * `okhttp3.OkHttpClient`, once `:mk-fonts/build.gradle.kts` depends on it
 * (pending `CONTRACT_CHANGES.md` request, Batch 1.4-repair2).
 */
class MkPlatformHttpSession internal constructor()

/**
 * Placeholder for the Foundation `Bundle` `MKFontsResources`/
 * `MKBundledFontIndex`/`MKLicensingDataSource` use to locate bundled font
 * and license-text resources on iOS. Android's real type (D-316) is
 * expected to wrap `android.content.res.AssetManager`, sourced from a
 * `Context` this module's real (Batch 3) implementation will need to
 * accept somewhere in its constructors.
 */
class MkPlatformAssetBundle internal constructor()

/**
 * Placeholder for the Foundation `NSAttributedString`
 * `MKFontCatalog.previewAttributedString` returns on iOS (a styled
 * preview render of the font's sample text). No Android equivalent has
 * been chosen yet — candidates include `android.text.Spannable` or a
 * `:mk-render`-owned attributed-text type, but `:mk-fonts` has no
 * dependency edge onto `:mk-render`/`:mk-color` (spine §3.2), so this
 * stays a module-local placeholder until Batch 3 resolves the design.
 */
class MkPlatformAttributedString internal constructor()
