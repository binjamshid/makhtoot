package net.binjamshid.makhtoot.mk.persistence.undo

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec
import net.binjamshid.makhtoot.mk.model.MkNode
import net.binjamshid.makhtoot.mk.model.MkNodeCore
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.MkStyle

data class MkInsertNodeCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var node: MkNode,
    var index: Int? = null,
    var parent: MkNodeId? = null
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkInsertNodeCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkInsertNodeCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkInsertNodeCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkInsertNodeCommand.inverse") }
}

data class MkInsertNodesCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodes: List<MkNode>,
    var parent: MkNodeId? = null
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkInsertNodesCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkInsertNodesCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkInsertNodesCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkInsertNodesCommand.inverse") }
}

data class MkRemoveNodeCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeID: MkNodeId
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkRemoveNodeCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkRemoveNodeCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkRemoveNodeCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkRemoveNodeCommand.inverse") }
}

data class MkReorderCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeID: MkNodeId,
    var toIndex: Int
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkReorderCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkReorderCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkReorderCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkReorderCommand.inverse") }
}

data class MkTransformCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeID: MkNodeId,
    var newTransform: MkTransform2D
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkTransformCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkTransformCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkTransformCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkTransformCommand.inverse") }
}

data class MkStyleCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeID: MkNodeId,
    var newStyle: MkStyle
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkStyleCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkStyleCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkStyleCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkStyleCommand.inverse") }
}

data class MkLockHideCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeID: MkNodeId,
    var isLocked: Boolean,
    var isHidden: Boolean
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkLockHideCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkLockHideCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkLockHideCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkLockHideCommand.inverse") }
}

data class MkRenameCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeID: MkNodeId,
    var newName: String
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkRenameCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkRenameCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkRenameCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkRenameCommand.inverse") }
}

data class MkCanvasSpecCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var newCanvas: MkCanvasSpec
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkCanvasSpecCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkCanvasSpecCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkCanvasSpecCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkCanvasSpecCommand.inverse") }
}

data class MkRestoreTopLevelNodesCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var previousNodes: List<MkNode>
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkRestoreTopLevelNodesCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkRestoreTopLevelNodesCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkRestoreTopLevelNodesCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkRestoreTopLevelNodesCommand.inverse") }
}

data class MkGroupCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeIDs: List<MkNodeId>,
    var groupName: String,
    var groupID: MkNodeId = MkNodeId()
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkGroupCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkGroupCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkGroupCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkGroupCommand.inverse") }
}

data class MkUngroupCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var groupID: MkNodeId
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkUngroupCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkUngroupCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkUngroupCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkUngroupCommand.inverse") }
}

data class MkBatchTransformCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var newTransforms: Map<MkNodeId, MkTransform2D>,
    var gestureID: java.util.UUID
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkBatchTransformCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkBatchTransformCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkBatchTransformCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkBatchTransformCommand.inverse") }
}

data class MkBatchCoreCommand(
    override val id: java.util.UUID,
    var newCores: Map<MkNodeId, MkNodeCore>,
    var gestureID: java.util.UUID,
    var label: String
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkBatchCoreCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkBatchCoreCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkBatchCoreCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkBatchCoreCommand.inverse") }
}

data class MkTextEditCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeID: MkNodeId,
    var newNode: MkNode,
    var burstKey: String
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkTextEditCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkTextEditCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkTextEditCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkTextEditCommand.inverse") }
}

data class MkReplaceNodesCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var newNodes: Map<MkNodeId, MkNode>,
    var label: String,
    var coalescingKeySuffix: String? = null
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkReplaceNodesCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkReplaceNodesCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkReplaceNodesCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkReplaceNodesCommand.inverse") }
}

data class MkReplaceNodeCommand(
    override val id: java.util.UUID = java.util.UUID.randomUUID(),
    var nodeID: MkNodeId,
    var newNode: MkNode
) : MkCommand {
    override val name: String
        get() = throw MkNotYetPorted("mk-persistence.MkReplaceNodeCommand.name")
    override val coalescingKey: String?
        get() = throw MkNotYetPorted("mk-persistence.MkReplaceNodeCommand.coalescingKey")
    override fun apply(scene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkReplaceNodeCommand.apply") }
    override fun inverse(scene: MkScene): MkCommand { throw MkNotYetPorted("mk-persistence.MkReplaceNodeCommand.inverse") }
}

