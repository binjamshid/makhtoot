package net.binjamshid.makhtoot.mk.render

// Work item 1.3 ("Contract stubs A"). Not one of the 23 Swift source
// files in the MKRender port map — new supporting infrastructure, same
// category as `mk-foundation`'s `MkPlatformFont`/`MkLogger` placeholders
// (`ANDROID_SPINE.md` §9's deviation-logging convention: "a dropped
// iOS-only capability with no Android analogue" / a native type with no
// direct JVM equivalent is always recorded, never invented silently).
//
// MKRender's Swift source draws through five CoreGraphics/CoreAnimation
// native handles with no JVM equivalent: `CGContext` (the mutable drawing
// destination), `CALayer` (the layer-tree node D-305/`RenderNode` will
// eventually back), `CGImage` (a decoded raster bitmap), `CGPDFPage` (a
// parsed PDF page reference), and `CGPath` (a native vector path). Each
// gets a small placeholder class here, following the exact pattern
// `mk-foundation/src/main/kotlin/.../stubs/MkFontProviding.kt`'s
// `MkPlatformFont` already establishes: an `internal constructor()` so
// nothing outside this module can fabricate a fake instance, real
// wiring arrives with Batch 4/5's `:mk-canvas`/`:mk-render` implementation
// once `android.graphics.Canvas`/`RenderNode`/`Bitmap`/`Path` are plumbed in.

/**
 * Placeholder for the mutable drawing destination `CGContext` represents on
 * iOS. Android's real type (D-305, arriving with Batch 4/5's `:mk-render`
 * implementation) is expected to wrap `android.graphics.Canvas`.
 */
class MkDrawingSurface internal constructor()

/**
 * Placeholder for the layer-tree node `CALayer` represents on iOS. Android's
 * real type (D-305 — `RenderNode`, API 29+ only, no fallback per FDA-07) is
 * expected to wrap `android.graphics.RenderNode`.
 */
class MkPlatformLayer internal constructor()

/**
 * Placeholder for the decoded raster bitmap `CGImage` represents on iOS.
 * Android's real type is expected to wrap `android.graphics.Bitmap`
 * (D-313's raster-export pipeline already targets `Bitmap` strips).
 */
class MkPlatformImage internal constructor()

/**
 * Placeholder for the parsed PDF page reference `CGPDFPage` represents on
 * iOS. Android has no system PDF-page-reference equivalent MKRender can
 * borrow (D-314: `:mk-export` ships an in-house PDF writer, `PdfDocument`
 * is rejected) — this stays a `:mk-render`-local placeholder until a real
 * page-reference type is needed for asset resolution.
 */
class MkPlatformPdfPage internal constructor()

/**
 * Placeholder for the native vector path `CGPath` represents on iOS.
 * Android's real type is expected to wrap `android.graphics.Path`.
 */
class MkPlatformPath internal constructor()

/**
 * Placeholder for the native color handle `CGColor` represents on iOS.
 * Android's real type is expected to wrap `android.graphics.Color`/`@ColorInt`.
 */
class MkPlatformColor internal constructor()

/**
 * Ports `CGInterpolationQuality` (a finite Apple system enum, not an opaque
 * native handle) — a real Kotlin enum rather than a placeholder class, since
 * every case is known and stable. `RenderOptions.swift`'s
 * `MKRenderQuality.imageInterpolationQuality` is the one call site.
 */
enum class MkImageInterpolationQuality {
    None,
    Low,
    Medium,
    High,
}
