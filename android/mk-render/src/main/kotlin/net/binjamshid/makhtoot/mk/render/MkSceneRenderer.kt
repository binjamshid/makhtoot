package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkScene

/**
 * Draws a whole scene (or a region of it) directly into a drawing surface —
 * the shared implementation `MkSnapshotRenderer`/`MkTileRenderer` build on.
 * Ports `Sources/MKRender/SceneRenderer.swift`.
 */
class MkSceneRenderer(
    private val fonts: MkFontProviding = MkSystemFontStubProvider(),
    private val assets: MkAssetProviding = MkEmptyAssetProvider(),
) {
    /** Renders [scene]'s [region] into [ctx] at [scale] and [quality], returning the substitution/perf report. */
    fun render(scene: MkScene, region: MkRect, ctx: MkDrawingSurface, scale: Double, quality: MkRenderQuality): MkRenderReport =
        throw MkNotYetPorted("MkSceneRenderer.render")
}
