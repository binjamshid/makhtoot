package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.geometry.MkCanvasGeometrySource
import net.binjamshid.makhtoot.mk.canvas.geometry.MkCanvasRenderBridge
import net.binjamshid.makhtoot.mk.canvas.geometry.MkOrientedRect
import net.binjamshid.makhtoot.mk.canvas.gestures.MkMarqueeMode
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.persistence.MkMakhtootDocument
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

class MkCanvasSession(
    val document: MkMakhtootDocument,
    var mode: MkCanvasMode? = null,
    var geometrySource: MkCanvasGeometrySource? = null,
    var renderBridge: MkCanvasRenderBridge? = null,
    var snappingEnabled: Boolean = true,
    var showsGrid: Boolean = false
) {
    val scene: MkScene
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasSession.scene")
    val canUndo: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasSession.canUndo")
    val canRedo: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasSession.canRedo")
    val selectionBounds: MkRect?
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasSession.selectionBounds")
    val singleSelectionOBB: MkOrientedRect?
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasSession.singleSelectionOBB")
    fun perform(command: MkCommand) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.perform") }
    fun beginGesture() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.beginGesture") }
    fun endGesture() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.endGesture") }
    fun undo() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.undo") }
    fun redo() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.redo") }
    fun enterBrowseMode() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.enterBrowseMode") }
    fun beginEditingText(nodeID: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.beginEditingText") }
    fun setSelection(ids: Set<MkNodeId>) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.setSelection") }
    fun setSelectionFromLayersPanel(ids: Set<MkNodeId>) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.setSelectionFromLayersPanel") }
    fun setArrangeChildSelection(ids: Set<MkNodeId>, granularity: MkSelectionGranularity, compositionScope: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.setArrangeChildSelection") }
    fun clearSelection() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.clearSelection") }
    fun toggleSelection(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.toggleSelection") }
    fun hitCandidates(scope: MkCanvasHitScope? = null): List<MkHitCandidate> { throw MkNotYetPorted("mk-canvas.MkCanvasSession.hitCandidates") }
    fun tap(point: MkPoint, zoomScale: Double, now: Double? = null, additive: Boolean = false): MkNodeId? { throw MkNotYetPorted("mk-canvas.MkCanvasSession.tap") }
    fun marqueeSelect(rect: MkRect, mode: MkMarqueeMode, additive: Boolean = false) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.marqueeSelect") }
    fun group(name: String = "مجموعة"): MkNod { throw MkNotYetPorted("mk-canvas.MkCanvasSession.group") }
    fun ungroup() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.ungroup") }
    fun setLocked(locked: Boolean, id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.setLocked") }
    fun setHidden(hidden: Boolean, id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.setHidden") }
    fun rename(id: MkNodeId, newName: String) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.rename") }
    fun delete(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.delete") }
    fun deleteSelection() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.deleteSelection") }
    fun reorder(id: MkNodeId, toIndex: Int) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.reorder") }
}

