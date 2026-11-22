package net.binjamshid.makhtoot.mk.canvas.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.MkPathData
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.MkStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

data class MkArrangeFormOption(
    var form: MkJoiningForm,
    var isValid: Boolean,
    var achieved: Boolean,
    var previewOutline: MkPathData? = null,
    var previewAdvance: MkSize,
    var glyphID: UInt16
)

data class MkArrangeFormSelectorModel(
    var nodeID: MkNodeId,
    var scalar: Long,
    var currentForm: MkJoiningForm,
    var options: List<MkArrangeFormOption>
)

data class MkArrangeRevertPreflight(
    var editedNodeCount: Int,
    var willDiscard: Boolean = true
) {
    companion object {
        val confirmationTitle: String = "العودة إلى النص؟"
        val confirmationBody: String = "سيؤدي هذا إلى حذف جميع التعديلات اليدوية على الحروف والحركات. النص الأصلي سيُستعاد كما كان."
        val confirmAction: String = "العودة"
        val cancelAction: String = "إلغاء"
    }
}

data class MkArrangeRecomposePreflight(
    var editedComponentCount: Int
) {
    val requiresConfirmation: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkArrangeRecomposePreflight.requiresConfirmation")
    companion object {
        val confirmationBody: String = "ستفقد تعديلات مكوّنات الوصلة"
    }
}

object MkArrangeSourceEditConflict {
    val title: String = "تعديل النص يتطلب العودة إلى النص ، ستفقد التنسيق اليدوي"
    val revertAndEdit: String = "العودة والتعديل"
    val duplicateThenEdit: String = "نسخ ثم تعديل"
    val cancel: String = "إلغاء"
}

interface MkArrangeEngineProviding : Any {
    suspend fun deriveArrangeCommand(sourceNodeID: MkNodeId, scene: MkScene): (MkCommand)?
    fun revertPreflight(node: MkArrangedTextNode): MkArrangeRevertPreflight
    fun revertCommand(arrangedNodeID: MkNodeId, node: MkArrangedTextNode): MkCommand
    fun nodeIDs(range: Range<Int>, composition: MkArrangedComposition, includeMarks: Boolean): Set<MkNodeId>
    fun utf16Ranges(ids: Set<MkNodeId>, composition: MkArrangedComposition): List<Range<Int>>
    fun clusterSiblings(id: MkNodeId, composition: MkArrangedComposition): Set<MkNodeId>
    suspend fun breakJoinCommand(nodeAID: MkNodeId, nodeBID: MkNodeId, ownerNode: MkArrangedTextNode): MkCommand
    suspend fun restoreJoinCommand(nodeAID: MkNodeId, nodeBID: MkNodeId, ownerNode: MkArrangedTextNode): MkCommand
    suspend fun formSelectorModel(nodeID: MkNodeId, ownerNode: MkArrangedTextNode): MkArrangeFormSelectorModel?
    fun formSelectionCommand(form: MkJoiningForm, model: MkArrangeFormSelectorModel, ownerNode: MkArrangedTextNode): (MkCommand)?
    fun canDecompose(groupID: MkNodeId, ownerNode: MkArrangedTextNode): Boolean
    suspend fun decomposeCommand(groupID: MkNodeId, ownerNode: MkArrangedTextNode, fidelity: Boolean): Pair<MkCommand, Boolean>
    fun recomposePreflight(groupID: MkNodeId, ownerNode: MkArrangedTextNode): MkArrangeRecomposePreflight
    fun recomposeCommand(groupID: MkNodeId, ownerNode: MkArrangedTextNode, force: Boolean): MkCommand
    fun detachMarkCommand(markID: MkNodeId, ownerNode: MkArrangedTextNode): (MkCommand)?
    fun reattachMarkCommand(markID: MkNodeId, toBase: MkNodeId, ownerNode: MkArrangedTextNode): (MkCommand)?
    fun nudgePositionCommand(delta: MkSize, ids: Set<MkNodeId>, ownerNode: MkArrangedTextNode, gestureID: java.util.UUID): MkCommand
    fun setTransformCommand(transform: MkTransform2D, id: MkNodeId, ownerNode: MkArrangedTextNode, gestureID: java.util.UUID): MkCommand
    fun setStyleCommand(style: MkStyle, ids: Set<MkNodeId>, ownerNode: MkArrangedTextNode, gestureID: java.util.UUID): MkCommand
    fun setOpacityCommand(opacity: Double, ids: Set<MkNodeId>, ownerNode: MkArrangedTextNode, gestureID: java.util.UUID): MkCommand
}

