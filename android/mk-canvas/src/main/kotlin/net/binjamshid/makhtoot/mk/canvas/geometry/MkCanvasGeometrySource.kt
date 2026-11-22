package net.binjamshid.makhtoot.mk.canvas.geometry

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkScene

interface MkCanvasGeometrySource : Any {
    fun worldOBB(nodeID: MkNodeId, scene: MkScene): MkOrientedRect?
    fun localBounds(nodeID: MkNodeId, scene: MkScene): MkRect? { throw MkNotYetPorted("mk-canvas.MkCanvasGeometrySource.localBounds") }
    fun containsPrecise(nodeID: MkNodeId, worldPoint: MkPoint, scene: MkScene): Boolean { throw MkNotYetPorted("mk-canvas.MkCanvasGeometrySource.containsPrecise") }
    fun arrangedChildWorldOBB(childID: MkNodeId, ownerNodeID: MkNodeId, scene: MkScene): MkOrientedRect? { throw MkNotYetPorted("mk-canvas.MkCanvasGeometrySource.arrangedChildWorldOBB") }
    fun arrangedChildHit(worldPoint: MkPoint, ownerNodeID: MkNodeId, scene: MkScene, tolerance: Double): Pair<MkNodeId, Double>? { throw MkNotYetPorted("mk-canvas.MkCanvasGeometrySource.arrangedChildHit") }
}

interface MkCanvasRenderBridge : Any {
    fun applyTransientTransform(nodeID: MkNodeId, transform: MkAffineTransform)
    fun commitTransients()
}

