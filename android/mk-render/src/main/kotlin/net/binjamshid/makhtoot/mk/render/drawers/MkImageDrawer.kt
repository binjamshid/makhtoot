package net.binjamshid.makhtoot.mk.render.drawers

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkImageNode
import net.binjamshid.makhtoot.mk.render.MkAssetProviding
import net.binjamshid.makhtoot.mk.render.MkDrawingSurface
import net.binjamshid.makhtoot.mk.render.MkPlatformImage
import net.binjamshid.makhtoot.mk.render.MkRenderQuality
import net.binjamshid.makhtoot.mk.render.MkRenderReportBuilder

// Ports `Sources/MKRender/Drawers/ImageDrawer.swift`. `MkImageNode`: raster
// and vector-PDF asset placement via `MkAssetProviding`. `.vectorSVG` is a
// recorded substitution until `:mk-assets` ships a vector program resolver.
class MkImageDrawer {
    fun draw(
        node: MkImageNode,
        assets: MkAssetProviding,
        into: MkDrawingSurface,
        quality: MkRenderQuality,
        report: MkRenderReportBuilder,
    ): Unit = throw MkNotYetPorted("MkImageDrawer.draw")
}

/**
 * Bitmap orientation correction for this module's one drawing coordinate
 * system: `MkSceneRenderer` paints into a y-DOWN, top-left-origin user
 * space, but a native image-draw call always lays an image's first pixel
 * row along the rect's maximum-y edge (native y-UP convention) — under a
 * y-down CTM those two conventions cancel the wrong way and every bitmap
 * lands vertically mirrored without this correction. Swift namespace enum
 * (no cases) → Kotlin `object`.
 */
object MkImageOrientation {
    /** Draws [image] filling [rect] the right way up under a y-down CTM. */
    fun drawUprightInYDownContext(image: MkPlatformImage, rect: MkRect, into: MkDrawingSurface): Unit =
        throw MkNotYetPorted("MkImageOrientation.drawUprightInYDownContext")
}

/**
 * Cover-fit math (fills `bounds` entirely, may overflow one axis) — the one
 * aspect mode `MkGeometryMath` (`:mk-foundation`) doesn't already provide.
 * `MkBackgroundDrawer` uses this for edge-to-edge image backgrounds. Swift
 * namespace enum (no cases) → Kotlin `object`.
 */
object MkImageAspect {
    fun cover(size: MkSize, bounds: MkSize): MkSize = throw MkNotYetPorted("MkImageAspect.cover")
}
