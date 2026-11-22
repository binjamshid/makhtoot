package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode

/** The result of a hit-test: which node (and, for an arranged node, which child) was hit. */
data class MkHitResult(
    var nodeId: MkNodeId,
    var childId: MkNodeId? = null,
    var distance: Double = 0.0,
)

/**
 * Point-in-scene hit-testing, precise per node kind (shape path containment,
 * text glyph bounds, arranged-child bounds). Ports
 * `Sources/MKRender/HitTester.swift`.
 */
class MkHitTester(private val fonts: MkFontProviding = MkSystemFontStubProvider()) {
    companion object {
        /** Extra tap-target slop for glyph hit targets. */
        const val glyphTapSlopPoints: Double = 4.0

        /** Extra tap-target slop for mark hit targets. */
        const val markTapSlopPoints: Double = 6.0
    }

    /** The topmost node hit at [point] in [scene], or `null`. */
    fun node(point: MkPoint, scene: MkScene): MkHitResult? = throw MkNotYetPorted("MkHitTester.node")

    /** Every node hit at [point] in [scene], topmost first. */
    fun allHits(point: MkPoint, scene: MkScene): List<MkHitResult> = throw MkNotYetPorted("MkHitTester.allHits")

    /** The local bounds and resolved world transform of [nodeId] in [scene], or `null` if not found. */
    fun worldGeometry(nodeId: MkNodeId, scene: MkScene): Pair<MkRect, MkAffineTransform>? =
        throw MkNotYetPorted("MkHitTester.worldGeometry")

    /** Precise (per-kind) containment test for [worldPoint] against [nodeId]'s actual painted geometry. */
    fun containsPrecise(nodeId: MkNodeId, worldPoint: MkPoint, scene: MkScene): Boolean =
        throw MkNotYetPorted("MkHitTester.containsPrecise")

    /** Hit-tests an arranged composition's own children (glyph/mark/ligature) within [node]. */
    fun arrangedChild(
        point: MkPoint,
        node: MkArrangedTextNode,
        compositionWorldTransform: MkAffineTransform,
        tolerance: Double = 0.0,
    ): MkHitResult? = throw MkNotYetPorted("MkHitTester.arrangedChild")

    /** Nearest arc-length/distance pair for [point] against a path-text node's [path], within [tolerance]. */
    fun pathProximity(point: MkPoint, path: MkBezierPathData, tolerance: Double = 8.0): Pair<Double, Double>? =
        throw MkNotYetPorted("MkHitTester.pathProximity")
}
