package net.binjamshid.makhtoot.mk.render.drawers

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkShapeNode
import net.binjamshid.makhtoot.mk.render.MkDrawingSurface
import net.binjamshid.makhtoot.mk.render.MkRenderQuality
import net.binjamshid.makhtoot.mk.render.MkRenderReportBuilder

// Ports `Sources/MKRender/Drawers/ShapeDrawer.swift`. Draws
// `MkShapeNode.geometry` — fill/stroke for every case except `.asset` (needs
// `:mk-assets`' vector program, not yet built, not a `:mk-render`
// dependency).
class MkShapeDrawer {
    fun draw(
        node: MkShapeNode,
        into: MkDrawingSurface,
        quality: MkRenderQuality,
        report: MkRenderReportBuilder,
    ): Unit = throw MkNotYetPorted("MkShapeDrawer.draw")
}
