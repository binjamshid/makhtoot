package net.binjamshid.makhtoot.mk.render.drawers

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkPathTextNode
import net.binjamshid.makhtoot.mk.render.MkDrawingSurface
import net.binjamshid.makhtoot.mk.render.MkPlatformPath
import net.binjamshid.makhtoot.mk.render.MkRenderQuality
import net.binjamshid.makhtoot.mk.render.MkRenderReportBuilder

// Ports `Sources/MKRender/Drawers/PathTextDrawer.swift`. Adopts
// `:mk-pathtext`'s `ArcLengthLUT`/`PathLayoutEngine` (D-110) for glyph
// placement along the node's path.
class MkPathTextDrawer(
    private val fonts: MkFontProviding = MkSystemFontStubProvider(),
) {
    fun draw(
        node: MkPathTextNode,
        into: MkDrawingSurface,
        quality: MkRenderQuality,
        report: MkRenderReportBuilder,
    ): Unit = throw MkNotYetPorted("MkPathTextDrawer.draw")
}

/**
 * Self-contained polyline arc-length sampler. `MkPathTextDrawer` itself no
 * longer uses this (it adopted `:mk-pathtext`'s real `ArcLengthLUT`/
 * `PathLayoutEngine`) — kept for `MkHitTester.pathProximity`'s own, separate
 * stand-in use. Swift namespace enum (no cases) → Kotlin `object`.
 */
object MkPolylineArcLength {
    data class Placement(
        val point: MkPoint,
        val tangentAngle: Double,
    )

    /**
     * Swift `struct Table` exposes only a computed property and two methods
     * publicly (its `points`/`cumulativeLengths` storage is `fileprivate`) —
     * ported with no public stored fields; only [MkPolylineArcLength.sample]
     * can produce one, so the constructor stays internal, mirroring
     * `mk-foundation`'s `MkPlatformFont` placeholder pattern.
     */
    class Table internal constructor() {
        val totalLength: Double
            get() = throw MkNotYetPorted("MkPolylineArcLength.Table.totalLength")

        /**
         * Nearest sampled point/tangent at arc length [length] along the
         * path, linearly interpolated between the two bracketing samples.
         */
        fun point(length: Double): Placement = throw MkNotYetPorted("MkPolylineArcLength.Table.point")

        /** Nearest arc length + perpendicular distance for a query point. */
        fun nearest(query: MkPoint): Pair<Double, Double> = throw MkNotYetPorted("MkPolylineArcLength.Table.nearest")
    }

    /**
     * Flattens [path] into a polyline (fixed subdivision per Bézier segment)
     * and builds a cumulative-length table over it.
     */
    fun sample(path: MkPlatformPath, segmentsPerCurve: Int = 32): Table =
        throw MkNotYetPorted("MkPolylineArcLength.sample")
}
