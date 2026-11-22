package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.geometry.MkOrientedRect
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize

enum class MkSnapAxis {
    HORIZONTAL, VERTICAL
}

data class MkSnapCandidate(
    var axis: MkSnapAxis,
    var position: Double,
    var source: Source
) {
    sealed class Source {
        object CanvasEdge : Source()
        object CanvasCenter : Source()
        data class NodeEdge(val arg0: MkNodeId) : Source()
        data class NodeCenter(val arg0: MkNodeId) : Source()
        object EqualSpacing : Source()
    }
}

data class MkSnapGuide(
    var axis: MkSnapAxis,
    var position: Double,
    var extentStart: Double,
    var extentEnd: Double
)

data class MkSnapResult(
    var adjustment: CGVector? = null,
    var guides: List<MkSnapGuide> = emptyList()
) {
    companion object {
        val none: MkSnapResult = MkSnapResult()
    }
}

object MkSnapEngine {
    val baseRadiusPoints: Double = 6.0
    val hysteresisPoints: Double = 2.0
    fun radius(zoomScale: Double): Double { throw MkNotYetPorted("mk-canvas.MkSnapEngine.radius") }
    fun canvasCandidates(canvasSize: MkSize): List<MkSnapCandidate> { throw MkNotYetPorted("mk-canvas.MkSnapEngine.canvasCandidates") }
    fun nodeCandidates(nodeID: MkNodeId, obb: MkOrientedRect): List<MkSnapCandidate> { throw MkNotYetPorted("mk-canvas.MkSnapEngine.nodeCandidates") }
    fun equalSpacingCandidates(axis: MkSnapAxis, neighborIntervals: List<ClosedRange<Double>>, draggedSize: Double): List<MkSnapCandidate> { throw MkNotYetPorted("mk-canvas.MkSnapEngine.equalSpacingCandidates") }
    fun nearest(value: Double, candidates: List<MkSnapCandidate>, axis: MkSnapAxis, radius: Double): MkSnapCandidate? { throw MkNotYetPorted("mk-canvas.MkSnapEngine.nearest") }
    fun snap(draggedBounds: MkRect, candidates: List<MkSnapCandidate>, zoomScale: Double, viewportExtent: MkRect): MkSnapResult { throw MkNotYetPorted("mk-canvas.MkSnapEngine.snap") }
    fun snappedRotation(angle: Double): Double { throw MkNotYetPorted("mk-canvas.MkSnapEngine.snappedRotation") }
}

