package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkScene

/**
 * Flat-colored-rect stub so `mk-canvas` can build/run against a real layer
 * tree before [MkLayerTreeController] lands real rendered bitmaps. No
 * drawing at all — every layer is a plain solid-color layer sized to the
 * node's [MkNodeLocalBounds]. Ports `Sources/MKRender/StubRenderTree.swift`.
 */
class MkStubRenderTree : MkRenderTreeProviding {
    override val hostLayer: MkPlatformLayer = MkPlatformLayer()

    override fun sync(scene: MkScene): Unit = throw MkNotYetPorted("MkStubRenderTree.sync")

    override fun applyTransientTransform(nodeId: MkNodeId, transform: MkAffineTransform): Unit =
        throw MkNotYetPorted("MkStubRenderTree.applyTransientTransform")

    override fun commitTransients() {
        // Intentional no-op — matches the Swift original's empty body exactly.
    }

    override fun setVisibleRect(visibleRect: MkRect, zoomScale: Double) {
        // Intentional no-op — matches the Swift original's empty body exactly.
    }

    override fun consumeRasterizationCount(): Int = throw MkNotYetPorted("MkStubRenderTree.consumeRasterizationCount")
}
