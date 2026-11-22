package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkPlatformPath

/**
 * The editable (anchor + in/out handle) view over `mk-model`'s
 * [MkBezierPathData] flat cubic-segment encoding. Ports
 * `Sources/MKPathText/BezierPathModel.swift`.
 */

/** Phantom tag for [MkPathAnchorId]. */
sealed class MkPathAnchorTag

typealias MkPathAnchorId = MkId<MkPathAnchorTag>

/** One editable control point: its own position plus optional incoming/outgoing Bezier handles. */
data class MkPathAnchor(
    var id: MkPathAnchorId = MkPathAnchorId(),
    var point: MkPoint,
    var handleIn: MkPoint? = null,
    var handleOut: MkPoint? = null,
)

/** The editable Bezier path model: ordered anchors, open/closed. */
data class MkBezierPathModel(
    var anchors: List<MkPathAnchor>,
    var isClosed: Boolean = false,
) {
    /** Builds the editable model from the document representation. */
    constructor(data: MkBezierPathData) : this(anchors = emptyList(), isClosed = data.isClosed) {
        throw MkNotYetPorted("MkBezierPathModel.init(data)")
    }

    /** Flattens back to the document representation. */
    fun bezierPathData(): MkBezierPathData = throw MkNotYetPorted("MkBezierPathModel.bezierPathData")

    fun cgPath(): MkPlatformPath = throw MkNotYetPorted("MkBezierPathModel.cgPath")

    /** >=2 anchors open / >=3 closed (task 10's structural-validity invariant). */
    val isValid: Boolean
        get() = throw MkNotYetPorted("MkBezierPathModel.isValid")

    companion object {
        /** A single straight segment. */
        fun line(start: MkPoint, end: MkPoint): MkBezierPathModel = throw MkNotYetPorted("MkBezierPathModel.line")

        /** An open circular arc from [startAngle] to [endAngle] (radians). */
        fun arc(center: MkPoint, radius: Double, startAngle: Double, endAngle: Double): MkBezierPathModel =
            throw MkNotYetPorted("MkBezierPathModel.arc")

        /** A full circle (closed arc, `0...2*PI`). */
        fun circle(center: MkPoint, radius: Double): MkBezierPathModel = throw MkNotYetPorted("MkBezierPathModel.circle")

        /** A decorative sine-like wave across [rect]'s width. */
        fun wave(rect: MkRect, periods: Int, amplitude: Double): MkBezierPathModel =
            throw MkNotYetPorted("MkBezierPathModel.wave")
    }
}
