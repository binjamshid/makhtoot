package net.binjamshid.makhtoot.mk.render.drawers

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.render.MkDrawingSurface
import net.binjamshid.makhtoot.mk.render.MkRenderQuality
import net.binjamshid.makhtoot.mk.render.MkRenderReportBuilder

// Ports `Sources/MKRender/Drawers/ArrangedDrawer.swift`. Draws
// `MkArrangedTextNode`: per child in composition paint order (glyphs/
// ligatures interleaved with marks in the composition's own visual order),
// concatenates the world affine per the D-220 normative chain
// (`MkArrangedGeometry`), then fills/strokes the stored outline path —
// never consults the font at render time (INV-13).
class MkArrangedDrawer {
    fun draw(
        node: MkArrangedTextNode,
        into: MkDrawingSurface,
        quality: MkRenderQuality,
        report: MkRenderReportBuilder,
    ): Unit = throw MkNotYetPorted("MkArrangedDrawer.draw")
}
