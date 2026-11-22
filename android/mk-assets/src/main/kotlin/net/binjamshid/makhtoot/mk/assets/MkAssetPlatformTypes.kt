package net.binjamshid.makhtoot.mk.assets
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkPlatformFont

// Batch 1.4-repair (supersedes Agent 1.4 on this module). Not one of the 24
// Swift source files in the MKAssets port map — new supporting
// infrastructure, same category as `mk-render`'s own
// `MkRenderPlatformTypes.kt` (`ANDROID_SPINE.md` §9's deviation-logging
// convention). `:mk-assets` has no dependency edge onto `:mk-render` or
// `:mk-color` (spine §3.2: `:mk-assets` depends only on `:mk-foundation`,
// `:mk-model`), so it cannot reuse those modules' placeholder types even
// though the underlying iOS types are the same CoreGraphics handles —
// hence a second, module-local set of placeholders with matching names/
// docs rather than a borrowed cross-module reference.
//
// MKAssets' Swift source draws through three CoreGraphics native handles
// with no JVM equivalent: `CGPath` (a native vector path), `CGImage` (a
// decoded raster bitmap), and `CGColor` (a native color handle). Each gets
// a small placeholder class here, following the exact pattern
// `mk-render/src/main/kotlin/.../MkRenderPlatformTypes.kt` and
// `mk-foundation/.../stubs/MkFontProviding.kt`'s `MkPlatformFont` already
// establish: an `internal constructor()` so nothing outside this module can
// fabricate a fake instance. Real wiring arrives once a later batch's
// `:mk-assets` implementation plumbs in `android.graphics.Path`/`Bitmap`/
// `Color` directly (these are Android framework types, not third-party
// dependencies, so no `build.gradle.kts` change is needed for the real
// implementation — only for this contract-stub placeholder is a local type
// used instead of the framework type, to keep the Batch 1 stub free of any
// premature `android.graphics` API surface commitment).

/**
 * Placeholder for the native vector path `CGPath` represents on iOS.
 * Android's real type is expected to wrap `android.graphics.Path`.
 */
class MkPlatformPath internal constructor()

/**
 * Placeholder for the decoded raster bitmap `CGImage` represents on iOS.
 * Android's real type is expected to wrap `android.graphics.Bitmap`.
 */
class MkPlatformImage internal constructor()

/**
 * Placeholder for the native color handle `CGColor` represents on iOS.
 * Android's real type is expected to wrap `android.graphics.Color`/`@ColorInt`.
 */
class MkPlatformColor internal constructor()
