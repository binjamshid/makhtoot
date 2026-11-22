package net.binjamshid.makhtoot.mk.canvas.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.MkCanvasSession
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkPathGlyphOffsetKey
import net.binjamshid.makhtoot.mk.model.MkPathSide
import net.binjamshid.makhtoot.mk.model.MkPathSpacingMode
import net.binjamshid.makhtoot.mk.model.MkPathTextNode

class MkPathTextInteractionModel(
    val session: MkCanvasSession,
    var engine: (MkPathTextEngineProviding)? = null
) {
    val isActive: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.isActive")
    val activeNodeID: MkNodeId?
        get() = throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.activeNodeID")
    val activeNode: MkPathTextNode?
        get() = throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.activeNode")
    val curvatureWarningActive: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.curvatureWarningActive")
    fun enterPathEditMode(nodeID: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.enterPathEditMode") }
    fun exitPathEditMode() { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.exitPathEditMode") }
    fun nearestHitTarget(point: MkPoint, tolerance: Double): MkPathHitTarget? { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.nearestHitTarget") }
    fun currentHitTargets(): List<MkPathHitTarget> { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.currentHitTargets") }
    fun tap(point: MkPoint, tolerance: Double): MkPathHandleId? { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.tap") }
    fun beginHandleDrag(handle: MkPathHandleId, mode: MkPathHandleMode = MkPathHandleMode.MIRRORED) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.beginHandleDrag") }
    fun updateHandleDrag(point: MkPoint) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.updateHandleDrag") }
    fun endHandleDrag() { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.endHandleDrag") }
    fun insertAnchor(point: MkPoint) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.insertAnchor") }
    fun deleteAnchor(anchorID: java.util.UUID) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.deleteAnchor") }
    fun toggleClosed() { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.toggleClosed") }
    fun beginGlyphOffsetDrag(point: MkPoint): MkPathGlyphOffsetKey? { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.beginGlyphOffsetDrag") }
    fun updateGlyphOffsetDrag(delta: MkSize) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.updateGlyphOffsetDrag") }
    fun endGlyphOffsetDrag() { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.endGlyphOffsetDrag") }
    fun beginOptionsGesture() { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.beginOptionsGesture") }
    fun endOptionsGesture() { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.endOptionsGesture") }
    fun setStartOffset(offset: Double, gestureID: java.util.UUID) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.setStartOffset") }
    fun setSide(side: MkPathSide) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.setSide") }
    fun toggleAboveBelow() { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.toggleAboveBelow") }
    fun setSpacingMode(mode: MkPathSpacingMode) { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.setSpacingMode") }
    fun reverseDirection() { throw MkNotYetPorted("mk-canvas.MkPathTextInteractionModel.reverseDirection") }
}

