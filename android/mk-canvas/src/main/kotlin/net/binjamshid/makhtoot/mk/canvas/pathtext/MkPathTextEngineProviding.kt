package net.binjamshid.makhtoot.mk.canvas.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.model.MkPathGlyphOffset
import net.binjamshid.makhtoot.mk.model.MkPathGlyphOffsetKey
import net.binjamshid.makhtoot.mk.model.MkPathTextNode
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

data class MkPathHandleId(
    var anchorID: java.util.UUID,
    var kind: Kind
) {
    object Kind {
    }
}

data class MkPathHitTarget(
    var id: MkPathHandleId,
    var position: MkPoint
)

enum class MkPathHandleMode {
    MIRRORED, FREE
}

data class MkPathGlyphHit(
    var key: MkPathGlyphOffsetKey,
    var position: MkPoint,
    var currentOffset: MkPathGlyphOffset
)

interface MkPathTextEngineProviding : Any {
    fun hitTargets(node: MkPathTextNode): List<MkPathHitTarget>
    fun nearestHitTarget(point: MkPoint, node: MkPathTextNode, tolerance: Double): MkPathHitTarget?
    fun curvatureWarning(node: MkPathTextNode): Boolean
    fun moveAnchorCommand(anchorID: java.util.UUID, newPoint: MkPoint, moveHandles: Boolean, nodeID: MkNodeId, scene: MkScene, coalescingKey: String): (MkCommand)?
    fun moveHandleCommand(handleID: MkPathHandleId, newPoint: MkPoint, mode: MkPathHandleMode, nodeID: MkNodeId, scene: MkScene, coalescingKey: String): (MkCommand)?
    fun insertAnchorCommand(point: MkPoint, nodeID: MkNodeId, scene: MkScene): Pair<MkCommand, java.util.UUID>?
    fun deleteAnchorCommand(anchorID: java.util.UUID, nodeID: MkNodeId, scene: MkScene): (MkCommand)?
    fun toggleClosedCommand(nodeID: MkNodeId, scene: MkScene): (MkCommand)?
    fun glyphHitTest(point: MkPoint, node: MkPathTextNode): MkPathGlyphHit?
    fun setGlyphOffsetCommand(offset: MkPathGlyphOffset, key: MkPathGlyphOffsetKey, nodeID: MkNodeId, scene: MkScene, gestureID: java.util.UUID): (MkCommand)?
}

