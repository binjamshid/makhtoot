package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.geometry.MkCanvasGeometrySource
import net.binjamshid.makhtoot.mk.canvas.geometry.MkCanvasRenderBridge
import net.binjamshid.makhtoot.mk.canvas.geometry.MkOrientedRect
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkPathData
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.render.MkHitTester
import net.binjamshid.makhtoot.mk.render.MkLayerTreeController

class MkCanvasRenderAdapter(
    val layerTree: MkLayerTreeController,
    val hitTester: MkHitTester,
    override val localBounds: Any? = null,
    val geometry: Any? = null,
    val localPoint: Any? = null,
    val childID: Any? = null,
    val ownerTransform: Any? = null,
    val index: Any? = null,
    val childAffine: Any? = null,
    val pointSize: Any? = null,
    val outline: MkPathData? = null,
    val localRect: MkRect,
    val half: Any? = null,
    val compositionRect: Any? = null
) : MkCanvasGeometrySource, MkCanvasRenderBridge {
    val hostLayer: Any
        get() = throw MkNotYetPorted("app.MkCanvasRenderAdapter.hostLayer")
    fun sync(scene: MkScene) { throw MkNotYetPorted("app.MkCanvasRenderAdapter.sync") }
    fun setVisibleRect(visibleRect: MkRect, zoomScale: Double) { throw MkNotYetPorted("app.MkCanvasRenderAdapter.setVisibleRect") }
    fun consumeRasterizationCount(): Int { throw MkNotYetPorted("app.MkCanvasRenderAdapter.consumeRasterizationCount") }
    override fun applyTransientTransform(nodeID: MkNodeId, transform: MkAffineTransform) { throw MkNotYetPorted("app.MkCanvasRenderAdapter.applyTransientTransform") }
    override fun commitTransients() { throw MkNotYetPorted("app.MkCanvasRenderAdapter.commitTransients") }
    override fun worldOBB(nodeID: MkNodeId, scene: MkScene): MkOrientedRect? { throw MkNotYetPorted("app.MkCanvasRenderAdapter.worldOBB") }
    override fun localBounds(nodeID: MkNodeId, scene: MkScene): MkRect? { throw MkNotYetPorted("app.MkCanvasRenderAdapter.localBounds") }
    override fun containsPrecise(nodeID: MkNodeId, worldPoint: MkPoint, scene: MkScene): Boolean { throw MkNotYetPorted("app.MkCanvasRenderAdapter.containsPrecise") }
    override fun arrangedChildHit(worldPoint: MkPoint, ownerNodeID: MkNodeId, scene: MkScene, tolerance: Double): Pair<MkNodeId, Double>? { throw MkNotYetPorted("app.MkCanvasRenderAdapter.arrangedChildHit") }
    override fun arrangedChildWorldOBB(childID: MkNodeId, ownerNodeID: MkNodeId, scene: MkScene): MkOrientedRect? { throw MkNotYetPorted("app.MkCanvasRenderAdapter.arrangedChildWorldOBB") }
    companion object {
        val compositionAffine: Any? = null
    }
}

