package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.model.MkBezierSegment

/**
 * Adaptive per-cubic-segment subdivision (D-110's core numeric machinery)
 * building a cumulative arc-length table; queries do a binary search over
 * the table, then evaluate the exact analytic cubic at the interpolated
 * parameter. Ports `Sources/MKPathText/ArcLengthLUT.swift`.
 *
 * The Swift initializer performs the real adaptive-subdivision algorithm to
 * populate `totalLength` and the internal sample table. `totalLength` is
 * modeled as a computed (throw-stubbed) property here rather than a stored
 * one assigned at construction time, so merely constructing this type (as
 * `mk-render`/`mk-arrange` call sites need to be able to do in this batch)
 * does not itself throw — only actually reading the not-yet-computed value
 * does, matching every other Batch 1 stub's throw-on-use contract.
 */
class MkArcLengthLUT(private val segments: List<MkBezierSegment>) {
    val segmentCount: Int
        get() = segments.size

    val totalLength: Double
        get() = throw MkNotYetPorted("MkArcLengthLUT.totalLength")

    constructor(path: MkBezierPathModel) : this(path.bezierPathData().segments)

    /** The point at arc length [length] (clamped to `[0, totalLength]`). */
    fun point(length: Double): MkPoint = throw MkNotYetPorted("MkArcLengthLUT.point")

    /** The unit tangent vector at arc length [length]. */
    fun tangent(length: Double): MkVector = throw MkNotYetPorted("MkArcLengthLUT.tangent")

    /** `(point, tangent, normal)` at arc length [length]. `normal` is the LEFT normal of `tangent`. */
    fun frame(length: Double): MkPathFrame = throw MkNotYetPorted("MkArcLengthLUT.frame")

    /** The `(segmentIndex, localT)` pair a given arc length maps to. */
    fun segmentAndLocalT(length: Double): Pair<Int, Double> = throw MkNotYetPorted("MkArcLengthLUT.segmentAndLocalT")

    /** Nearest arc length to [query]. */
    fun nearestLength(query: MkPoint): Double = throw MkNotYetPorted("MkArcLengthLUT.nearestLength")
}

/** Placeholder for `CGVector` (a 2-D direction/magnitude pair), used by arc-length tangent queries. */
data class MkVector(val dx: Double, val dy: Double)

/** The `(point, tangent, normal)` triple [MkArcLengthLUT.frame] returns. */
data class MkPathFrame(val point: MkPoint, val tangent: MkVector, val normal: MkVector)
