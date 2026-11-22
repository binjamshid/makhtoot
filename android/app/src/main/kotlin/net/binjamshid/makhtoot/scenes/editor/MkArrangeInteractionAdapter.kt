package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.arrange.MkArrangeDeriver
import net.binjamshid.makhtoot.mk.arrange.MkJoinController
import net.binjamshid.makhtoot.mk.arrange.MkLigatureDecomposer
import net.binjamshid.makhtoot.mk.arrange.MkMarkAttachmentController
import net.binjamshid.makhtoot.mk.arrange.MkRevertService
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeEngineProviding
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeFormSelectorModel
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeRecomposePreflight
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeRevertPreflight
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.MkStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangeOrigin
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedChild
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.model.arranged.MkGlyphNode
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand
import net.binjamshid.makhtoot.mk.textengine.MkShapingService

class MkArrangeInteractionAdapter(
    val deriver: MkArrangeDeriver,
    val revertService: MkRevertService = MkRevertService(),
    val joinController: MkJoinController,
    val ligatureDecomposer: MkLigatureDecomposer,
    val markController: MkMarkAttachmentController = MkMarkAttachmentController(),
    val shapingService: MkShapingService,
    val fonts: MkFontProviding = MkSystemFontStubProvider(),
    val capture: Any? = null,
    val composition: Any? = null,
    val origin: MkArrangeOrigin? = null,
    val real: Any? = null,
    val result: Any? = null,
    val command: Any? = null,
    var c: Any = component,
    var copy: Any = composition,
    var touched: Boolean = false
) : MkArrangeEngineProviding {
    val options: Any
        get() = throw MkNotYetPorted("app.MkArrangeInteractionAdapter.options")
    val edited: Any
        get() = throw MkNotYetPorted("app.MkArrangeInteractionAdapter.edited")
    val composition: Any
        get() = throw MkNotYetPorted("app.MkArrangeInteractionAdapter.composition")
    override suspend fun deriveArrangeCommand(sourceNodeID: MkNodeId, scene: MkScene): (MkCommand)? { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.deriveArrangeCommand") }
    override fun revertPreflight(node: MkArrangedTextNode): MkArrangeRevertPreflight { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.revertPreflight") }
    override fun revertCommand(arrangedNodeID: MkNodeId, node: MkArrangedTextNode): MkCommand { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.revertCommand") }
    override fun nodeIDs(range: Range<Int>, composition: MkArrangedComposition, includeMarks: Boolean): Set<MkNodeId> { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.nodeIDs") }
    override fun utf16Ranges(ids: Set<MkNodeId>, composition: MkArrangedComposition): List<Range<Int>> { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.utf16Ranges") }
    override fun clusterSiblings(id: MkNodeId, composition: MkArrangedComposition): Set<MkNodeId> { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.clusterSiblings") }
    override suspend fun breakJoinCommand(nodeAID: MkNodeId, nodeBID: MkNodeId, ownerNode: MkArrangedTextNode): MkCommand { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.breakJoinCommand") }
    override suspend fun restoreJoinCommand(nodeAID: MkNodeId, nodeBID: MkNodeId, ownerNode: MkArrangedTextNode): MkCommand { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.restoreJoinCommand") }
    override suspend fun formSelectorModel(nodeID: MkNodeId, ownerNode: MkArrangedTextNode): MkArrangeFormSelectorModel? { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.formSelectorModel") }
    override fun formSelectionCommand(form: MkJoiningForm, model: MkArrangeFormSelectorModel, ownerNode: MkArrangedTextNode): (MkCommand)? { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.formSelectionCommand") }
    override fun canDecompose(groupID: MkNodeId, ownerNode: MkArrangedTextNode): Boolean { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.canDecompose") }
    override suspend fun decomposeCommand(groupID: MkNodeId, ownerNode: MkArrangedTextNode, fidelity: Boolean): Pair<MkCommand, Boolean> { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.decomposeCommand") }
    override fun recomposePreflight(groupID: MkNodeId, ownerNode: MkArrangedTextNode): MkArrangeRecomposePreflight { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.recomposePreflight") }
    override fun recomposeCommand(groupID: MkNodeId, ownerNode: MkArrangedTextNode, force: Boolean): MkCommand { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.recomposeCommand") }
    override fun detachMarkCommand(markID: MkNodeId, ownerNode: MkArrangedTextNode): (MkCommand)? { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.detachMarkCommand") }
    override fun reattachMarkCommand(markID: MkNodeId, toBase: MkNodeId, ownerNode: MkArrangedTextNode): (MkCommand)? { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.reattachMarkCommand") }
    override fun nudgePositionCommand(delta: MkSize, ids: Set<MkNodeId>, ownerNode: MkArrangedTextNode, gestureID: java.util.UUID): MkCommand { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.nudgePositionCommand") }
    override fun setTransformCommand(transform: MkTransform2D, id: MkNodeId, ownerNode: MkArrangedTextNode, gestureID: java.util.UUID): MkCommand { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.setTransformCommand") }
    override fun setStyleCommand(style: MkStyle, ids: Set<MkNodeId>, ownerNode: MkArrangedTextNode, gestureID: java.util.UUID): MkCommand { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.setStyleCommand") }
    override fun setOpacityCommand(opacity: Double, ids: Set<MkNodeId>, ownerNode: MkArrangedTextNode, gestureID: java.util.UUID): MkCommand { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.setOpacityCommand") }
    companion object {
        fun mapMatching(ids: Set<MkNodeId>, composition: MkArrangedComposition, mapTop: (MkArrangedChild) -> MkArrangedChild, mapComponent: (MkGlyphNode) -> MkGlyphNode): MkArrangedComposition { throw MkNotYetPorted("app.MkArrangeInteractionAdapter.mapMatching") }
    }
}

enum class MkArrangeAdapterError {
    NOT_A_GLYPH
}

