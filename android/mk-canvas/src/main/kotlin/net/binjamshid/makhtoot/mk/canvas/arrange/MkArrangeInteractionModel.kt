package net.binjamshid.makhtoot.mk.canvas.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.MkCanvasSession
import net.binjamshid.makhtoot.mk.canvas.MkSelectionGranularity
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.model.arranged.MkGlyphNode
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm

class MkArrangeInteractionModel(
    val session: MkCanvasSession,
    var engine: (MkArrangeEngineProviding)? = null
) {
    val isActive: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.isActive")
    val activeOwnerNodeID: MkNodeId?
        get() = throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.activeOwnerNodeID")
    val activeOwnerNode: MkArrangedTextNode?
        get() = throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.activeOwnerNode")
    suspend fun enterArrangeMode(nodeID: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.enterArrangeMode") }
    fun dismissError() { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.dismissError") }
    fun reportRefusal(refusal: ArrangeEntryRefusal) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.reportRefusal") }
    fun exitArrangeMode() { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.exitArrangeMode") }
    fun revertPreflight(): MkArrangeRevertPreflight? { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.revertPreflight") }
    fun revert() { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.revert") }
    fun revertAndEdit(): MkNodeId? { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.revertAndEdit") }
    fun duplicateThenRevertForEditing(): MkNodeId? { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.duplicateThenRevertForEditing") }
    fun setGranularity(newValue: MkSelectionGranularity) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.setGranularity") }
    fun tap(point: MkPoint, zoomScale: Double, now: Double? = null, additive: Boolean = false): MkNodeId? { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.tap") }
    fun letterLevelSubSelections(ids: Set<MkNodeId>, node: MkArrangedTextNode): List<Set<MkNodeId>> { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.letterLevelSubSelections") }
    fun beginMove() { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.beginMove") }
    fun updateMove(delta: MkSize) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.updateMove") }
    fun endMove() { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.endMove") }
    fun detachSelectedMark() { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.detachSelectedMark") }
    fun reattachMark(markID: MkNodeId, baseID: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.reattachMark") }
    fun logicalGlyphNeighbors(id: MkNodeId): Pair<MkGlyphNode?, MkGlyphNode?> { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.logicalGlyphNeighbors") }
    suspend fun breakJoinWithNext(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.breakJoinWithNext") }
    suspend fun breakJoinWithPrevious(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.breakJoinWithPrevious") }
    suspend fun restoreJoinWithNext(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.restoreJoinWithNext") }
    suspend fun restoreJoinWithPrevious(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.restoreJoinWithPrevious") }
    suspend fun loadFormSelector(nodeID: MkNodeId): MkArrangeFormSelectorModel? { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.loadFormSelector") }
    fun selectForm(form: MkJoiningForm, nodeID: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.selectForm") }
    fun canDecompose(groupID: MkNodeId): Boolean { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.canDecompose") }
    suspend fun decompose(groupID: MkNodeId, fidelity: Boolean): Boolean { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.decompose") }
    fun recomposePreflight(groupID: MkNodeId): MkArrangeRecomposePreflight? { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.recomposePreflight") }
    fun recompose(groupID: MkNodeId, force: Boolean = false) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.recompose") }
    fun setStyleForSelection(style: MkStyle, gestureID: java.util.UUID = java.util.UUID.randomUUID()) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.setStyleForSelection") }
    fun setOpacityForSelection(opacity: Double, gestureID: java.util.UUID = java.util.UUID.randomUUID()) { throw MkNotYetPorted("mk-canvas.MkArrangeInteractionModel.setOpacityForSelection") }
    enum class ArrangeEntryRefusal {
        NOTHING_SELECTED, MULTIPLE_SELECTED
    }
}

