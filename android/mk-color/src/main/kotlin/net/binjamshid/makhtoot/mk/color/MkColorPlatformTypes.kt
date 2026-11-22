package net.binjamshid.makhtoot.mk.color

/**
 * Placeholders for the CoreGraphics opaque platform types `MKColor`'s public
 * API surfaces (`CGColor`, `CGImage`, `CGColorSpace`, `Bundle`), none of
 * which have a direct Kotlin/JVM equivalent at this engine layer. Not
 * themselves rows in the `MKColor` port map (`ANDROID_SPINE.md` §9 —
 * necessary supporting infrastructure, documented, not silent), following
 * the same pattern already established in `mk-foundation`'s
 * `stubs/MkFontProviding.kt` (`MkPlatformFont`).
 *
 * Android's real implementation (Batch 2) is expected to back these with
 * `android.graphics.Color`/`Bitmap`/`ColorSpace` and lcms2-via-NDK handles
 * (D-315) respectively — real wiring lands with the Batch 2 `:mk-color`
 * implementation at the same file paths.
 */
class MkPlatformColor internal constructor()

/** Placeholder for `CGImage`. See [MkPlatformColor]. */
class MkPlatformImage internal constructor()

/** Placeholder for `CGColorSpace` (an ICC-profile-backed colour space handle). See [MkPlatformColor]. */
class MkColorSpaceHandle internal constructor()

/** Placeholder for `Bundle` (resource-bundle lookup for the bundled ICC profile). See [MkPlatformColor]. */
class MkResourceBundle internal constructor()
