package net.binjamshid.makhtoot.mk.render.drawers

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkLiveTextNode
import net.binjamshid.makhtoot.mk.render.MkDrawingSurface
import net.binjamshid.makhtoot.mk.render.MkRenderQuality
import net.binjamshid.makhtoot.mk.render.MkRenderReportBuilder

// Ports `Sources/MKRender/Drawers/LiveTextDrawer.swift`. Draws
// `MkLiveTextNode` through the shaping capture (D-104: "committed rendering
// of Live Text objects is always the mk-textengine→mk-render path so canvas
// and export are pixel-identical"). Coordinate convention: shaping happens
// in a y-up, line-relative space; this drawer's document/canvas space is
// y-down, top-left origin — it re-flips locally before drawing so glyphs
// render upright.
class MkLiveTextDrawer(
    private val fonts: MkFontProviding = MkSystemFontStubProvider(),
) {
    fun draw(
        node: MkLiveTextNode,
        into: MkDrawingSurface,
        quality: MkRenderQuality,
        report: MkRenderReportBuilder,
    ): Unit = throw MkNotYetPorted("MkLiveTextDrawer.draw")
}
