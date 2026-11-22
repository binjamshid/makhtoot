package net.binjamshid.makhtoot.mk.model.arranged

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkNodeCore

/**
 * The arranged structure itself: an ordered set of Glyph/Mark/Ligature nodes
 * in visual order, plus the retained source backup and the arrangement's
 * origin frame. Ports `Sources/MKModel/Arranged/ArrangedComposition.swift`.
 */

/** One arranged child — the closed set D-111 requires (glyph/mark/ligature, NOT plain `MkNode`). */
@Serializable
sealed class MkArrangedChild {
    @Serializable
    data class Glyph(var node: MkGlyphNode) : MkArrangedChild()

    @Serializable
    data class Mark(var node: MkMarkNode) : MkArrangedChild()

    @Serializable
    data class Ligature(var node: MkLigatureGroup) : MkArrangedChild()

    val id: MkNodeId
        get() = throw MkNotYetPorted("MkArrangedChild.id")
}

/** The frozen, non-reflowing structure an Arrange Mode derivation produces (D-106, glossary: "Arranged Composition"). */
@Serializable
data class MkArrangedComposition(
    /** Children in visual (paint) order at derivation time. Z-order among them is index order. */
    var nodes: List<MkArrangedChild>,
    var sourceBackup: MkSourceTextBackup,
    /** The composition's bounding frame at derivation, in the owning node's local space. */
    var originFrame: MkRect,
) {
    /** Convenience find-by-id over `nodes` (linear — compositions are bounded by a single text object's glyph count). */
    fun child(id: MkNodeId): MkArrangedChild? = throw MkNotYetPorted("MkArrangedComposition.child")
}

/** What an Arranged Composition was derived from (D-106/D-110). */
@Serializable
sealed class MkArrangeOrigin {
    @Serializable
    object LiveText : MkArrangeOrigin()

    @Serializable
    data class PathText(var path: MkBezierPathData) : MkArrangeOrigin()
}

/** The `arranged` `MkNode` case's payload: node header + the arranged structure. */
@Serializable
data class MkArrangedTextNode(
    var core: MkNodeCore,
    var composition: MkArrangedComposition,
    var derivedFrom: MkArrangeOrigin,
)
