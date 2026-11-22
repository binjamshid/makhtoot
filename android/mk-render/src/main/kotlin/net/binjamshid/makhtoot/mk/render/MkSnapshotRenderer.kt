package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkScene

/**
 * Renders a scene (or a region/thumbnail of it) to a decoded bitmap — the
 * export/thumbnail entry point every raster path (`:mk-export`, contact
 * sheets, canvas snapshots) goes through. Ports
 * `Sources/MKRender/SnapshotRenderer.swift`.
 */
class MkSnapshotRenderer(
    private val fonts: MkFontProviding = MkSystemFontStubProvider(),
    private val assets: MkAssetProviding = MkEmptyAssetProvider(),
) {
    /** Renders [scene]'s [region] at [scale]/[quality] to a bitmap, or `null` on failure. */
    fun render(scene: MkScene, region: MkRect, scale: Double, quality: MkRenderQuality): MkPlatformImage? =
        throw MkNotYetPorted("MkSnapshotRenderer.render")

    /** Same as [render], additionally returning the substitution/perf report. */
    fun renderWithReport(scene: MkScene, region: MkRect, scale: Double, quality: MkRenderQuality): Pair<MkPlatformImage?, MkRenderReport> =
        throw MkNotYetPorted("MkSnapshotRenderer.renderWithReport")

    /** Renders the whole canvas (background + all nodes) at [scale]/[quality]. */
    fun renderFullCanvas(scene: MkScene, scale: Double, quality: MkRenderQuality): MkPlatformImage? =
        throw MkNotYetPorted("MkSnapshotRenderer.renderFullCanvas")

    /** Renders a thumbnail whose longer edge is [longEdge] points. */
    fun renderThumbnail(scene: MkScene, longEdge: Double = 512.0): MkPlatformImage? =
        throw MkNotYetPorted("MkSnapshotRenderer.renderThumbnail")

    companion object {
        /** Builds a [width]x[height] drawing surface flipped for the document's y-down convention, at [scale]. */
        fun makeFlippedBitmapContext(width: Int, height: Int, scale: Double): MkDrawingSurface? =
            throw MkNotYetPorted("MkSnapshotRenderer.makeFlippedBitmapContext")
    }
}
