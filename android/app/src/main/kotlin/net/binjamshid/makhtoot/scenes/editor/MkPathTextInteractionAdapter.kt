package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.arrange.MkPathGlyphPlacement
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathGlyphHit
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathHandleId
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathHandleMode
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathHitTarget
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathTextEngineProviding
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkPathGlyphOffset
import net.binjamshid.makhtoot.mk.model.MkPathGlyphOffsetKey
import net.binjamshid.makhtoot.mk.model.MkPathLayoutOptions
import net.binjamshid.makhtoot.mk.model.MkPathTextNode
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.MkTextStyle
import net.binjamshid.makhtoot.mk.pathtext.MkBezierPathModel
import net.binjamshid.makhtoot.mk.pathtext.MkPathLayoutResult
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand
import net.binjamshid.makhtoot.mk.textengine.MkShapingEngine

class MkPathTextInteractionAdapter(
    val shapingEngine: MkShapingEngine,
    val fonts: MkFontProviding = MkSystemFontStubProvider(),
    var anchorIDCache: Map<MkNodeId, List<java.util.UUID>> = emptyMap(),
    var layoutResultCache: Map<MkNodeId, Pair<LayoutCacheKey, MkPathLayoutResult?>> = emptyMap(),
    val path: Any? = null,
    val moved: Any? = null,
    val realHandle: Any? = null,
    val lut: Any? = null,
    val length: Any? = null,
    val onCurvePoint: Any? = null,
    val distance: Any? = null,
    val existingIDs: Any? = null,
    var inserted: Any? = null,
    val tolerance: Any? = null,
    var best: Pair<MkPathGlyphPlacement, Double>? = null,
    val laidOutPosition: Any? = null,
    val key: Any? = null,
    val currentOffset: Any? = null,
    val position: Any? = null,
    val realKey: Any? = null,
    val realOffset: Any? = null,
    var model: Any? = null,
    val ids: List<java.util.UUID>,
    val result: Any? = null,
    val request: Any? = null,
    val line: Any? = null,
    val options: Any? = null,
    val userOffsets: Any? = null
) : MkPathTextEngineProviding {
    val freshCache: Any
        get() = throw MkNotYetPorted("app.MkPathTextInteractionAdapter.freshCache")
    override fun hitTargets(node: MkPathTextNode): List<MkPathHitTarget> { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.hitTargets") }
    override fun nearestHitTarget(point: MkPoint, node: MkPathTextNode, tolerance: Double): MkPathHitTarget? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.nearestHitTarget") }
    override fun curvatureWarning(node: MkPathTextNode): Boolean { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.curvatureWarning") }
    override fun moveAnchorCommand(anchorID: java.util.UUID, newPoint: MkPoint, moveHandles: Boolean, nodeID: MkNodeId, scene: MkScene, coalescingKey: String): (MkCommand)? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.moveAnchorCommand") }
    override fun moveHandleCommand(handleID: MkPathHandleId, newPoint: MkPoint, mode: MkPathHandleMode, nodeID: MkNodeId, scene: MkScene, coalescingKey: String): (MkCommand)? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.moveHandleCommand") }
    override fun insertAnchorCommand(point: MkPoint, nodeID: MkNodeId, scene: MkScene): Pair<MkCommand, java.util.UUID>? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.insertAnchorCommand") }
    override fun deleteAnchorCommand(anchorID: java.util.UUID, nodeID: MkNodeId, scene: MkScene): (MkCommand)? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.deleteAnchorCommand") }
    override fun toggleClosedCommand(nodeID: MkNodeId, scene: MkScene): (MkCommand)? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.toggleClosedCommand") }
    override fun glyphHitTest(point: MkPoint, node: MkPathTextNode): MkPathGlyphHit? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.glyphHitTest") }
    override fun setGlyphOffsetCommand(offset: MkPathGlyphOffset, key: MkPathGlyphOffsetKey, nodeID: MkNodeId, scene: MkScene, gestureID: java.util.UUID): (MkCommand)? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.setGlyphOffsetCommand") }
    fun stableModel(node: MkPathTextNode, nodeID: MkNodeId): MkBezierPathModel { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.stableModel") }
    fun layoutResult(node: MkPathTextNode): MkPathLayoutResult? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.layoutResult") }
    companion object {
        fun computeLayoutResult(shapingEngine: MkShapingEngine, node: MkPathTextNode): MkPathLayoutResult? { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.computeLayoutResult") }
        fun mirror(target: MkPathHitTarget): MkPathHitTarget { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.mirror") }
        fun mirror(id: MkPathHandleId): MkPathHandleId { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.mirror") }
        fun mirror(kind: MkPathHandleId.Kind): MkPathHandleId.Kind { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.mirror") }
        fun mirror(kind: MkPathHandleId.Kind): MkPathHandleId.Kind { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.mirror") }
        fun mirror(mode: MkPathHandleMode): MkPathHandleMode { throw MkNotYetPorted("app.MkPathTextInteractionAdapter.mirror") }
        val insertAnchorTolerance: Double = 24.0
    }
    data class LayoutCacheKey(
        val text: String,
        val style: MkTextStyle,
        val path: MkBezierPathData,
        val layout: MkPathLayoutOptions,
        val glyphOffsets: Map<MkPathGlyphOffsetKey, MkPathGlyphOffset>
    )
}

