package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkScene

/**
 * Splits a large export/canvas region into memory-bounded tiles and renders
 * each independently — the mechanism that lets export size be bounded by
 * disk, not RAM (D-118). Ports `Sources/MKRender/TileRenderer.swift`.
 */
object MkTileRenderer {
    /** Byte budget per tile. */
    const val maxTileBytes: Int = 64 * 1024 * 1024

    /** The tile rects covering [bounds] at [scale], each within [maxBytes]. */
    fun tileRects(bounds: MkRect, scale: Double, maxBytes: Int = maxTileBytes): List<MkRect> =
        throw MkNotYetPorted("MkTileRenderer.tileRects")

    /** Renders one tile of [scene] at [rect]/[scale]/[quality] using [renderer]. */
    fun renderTile(scene: MkScene, rect: MkRect, scale: Double, quality: MkRenderQuality, renderer: MkSnapshotRenderer): MkPlatformImage? =
        throw MkNotYetPorted("MkTileRenderer.renderTile")
}
