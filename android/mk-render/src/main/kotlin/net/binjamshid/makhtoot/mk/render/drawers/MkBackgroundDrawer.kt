package net.binjamshid.makhtoot.mk.render.drawers

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkBackgroundNode
import net.binjamshid.makhtoot.mk.render.MkAssetProviding
import net.binjamshid.makhtoot.mk.render.MkDrawingSurface
import net.binjamshid.makhtoot.mk.render.MkRenderQuality
import net.binjamshid.makhtoot.mk.render.MkRenderReportBuilder

// Ports `Sources/MKRender/Drawers/BackgroundDrawer.swift`. `MkBackgroundNode`:
// "transform ignored; always canvas-filling" — this drawer fills exactly
// `canvasBounds`, never the node's own transform. Both solid and image
// content are implemented.
class MkBackgroundDrawer {
    fun draw(
        node: MkBackgroundNode,
        canvasBounds: MkRect,
        assets: MkAssetProviding,
        into: MkDrawingSurface,
        quality: MkRenderQuality,
        report: MkRenderReportBuilder,
    ): Unit = throw MkNotYetPorted("MkBackgroundDrawer.draw")
}
