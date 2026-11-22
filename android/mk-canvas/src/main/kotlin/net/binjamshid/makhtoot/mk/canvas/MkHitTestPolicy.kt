package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.geometry.MkOrientedRect
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

data class MkHitCandidate(
    var nodeID: MkNodeId,
    var worldOBB: MkOrientedRect,
    var zIndex: Int,
    var isLocked: Boolean = false,
    var isHidden: Boolean = false
)

sealed class MkCanvasHitScope {
    object TopLevel : MkCanvasHitScope()
    data class InsideGroup(val arg0: MkNodeId) : MkCanvasHitScope()
    data class InsideComposition(val arg0: MkNodeId) : MkCanvasHitScope()
}

object MkHitTestPolicy {
    val minimumTouchTargetPoints: Double = 44.0
    val minimumCanvasTolerance: Double = 2.0
    val viewSlopPoints: Double = 22.0
    fun touchTolerance(zoomScale: Double): Double { throw MkNotYetPorted("mk-canvas.MkHitTestPolicy.touchTolerance") }
    fun hits(point: MkPoint, candidates: List<MkHitCandidate>, tolerance: Double): List<MkNodeId> { throw MkNotYetPorted("mk-canvas.MkHitTestPolicy.hits") }
    fun topHit(point: MkPoint, candidates: List<MkHitCandidate>, tolerance: Double): MkNodeId? { throw MkNotYetPorted("mk-canvas.MkHitTestPolicy.topHit") }
    data class TapCycleState(
        var lastPoint: MkPoint? = null,
        var lastTimestamp: Double? = null,
        var lastIndex: Int = -1
    ) {
        fun select(hits: List<MkNodeId>, point: MkPoint, now: Double): MkNodeId? { throw MkNotYetPorted("mk-canvas.TapCycleState.select") }
        companion object {
            val cycleWindow: Double = 1.5
            val cycleDistance: Double = 8.0
        }
    }
}

