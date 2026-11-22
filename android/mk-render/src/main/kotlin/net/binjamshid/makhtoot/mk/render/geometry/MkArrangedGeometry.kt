package net.binjamshid.makhtoot.mk.render.geometry

import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.model.arranged.MkComposedLigature
import net.binjamshid.makhtoot.mk.model.arranged.MkGlyphNode
import net.binjamshid.makhtoot.mk.model.arranged.MkMarkNode

// Ports `Sources/MKRender/Geometry/ArrangedGeometry.swift`. D-220's
// normative affine chain, implemented once here so `MkArrangedDrawer`
// (rendering) and `MkHitTester` (hit-testing) share exactly one geometry
// truth. Swift namespace enum (no cases) → Kotlin `object`.
object MkArrangedGeometry {
    /**
     * One resolved arranged-composition element, flattening decomposed
     * ligature components into the same id space as top-level children.
     * Swift enum WITH associated values → Kotlin `sealed class`.
     */
    sealed class Element {
        data class Glyph(val node: MkGlyphNode) : Element()
        data class ComposedLigature(
            val id: MkNodeId,
            val groupTransform: MkTransform2D,
            val ligature: MkComposedLigature,
        ) : Element()
        data class Mark(val node: MkMarkNode) : Element()
    }

    /**
     * Built once per composition render/hit-test pass and reused across
     * per-child lookups rather than re-scanning `composition.nodes` (and
     * decomposed components) on every lookup. Swift `struct Index`'s
     * `init(composition:)` performs real construction work (a loop building
     * an id→element table + paint-order array) — not "simple construction,
     * no logic" — so unlike this module's other trivial-storage
     * constructors, it becomes a throwing constructor per the stub
     * mechanism (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3, stub
     * mechanism rule 2).
     */
    class Index(composition: MkArrangedComposition) {
        /** Paint order: top-level composition order, decomposed-ligature components spliced in. */
        var paintOrder: List<MkNodeId> = emptyList()
            private set

        init {
            throw MkNotYetPorted("MkArrangedGeometry.Index.init")
        }

        fun element(id: MkNodeId): Element? = throw MkNotYetPorted("MkArrangedGeometry.Index.element")
    }

    /**
     * The element's own LOCAL (composition-space, not yet composed with
     * `compositionAffine`) affine.
     */
    fun localAffine(element: Element): MkAffineTransform? = throw MkNotYetPorted("MkArrangedGeometry.localAffine")

    /**
     * `composition.affine ∘ child.affine` for a glyph/ligature child. Named
     * `worldTransformOfChild` (not the overloaded Swift `worldTransform(ofChild:)`)
     * because Kotlin overload resolution is erasure-based, not label-based:
     * this, [worldTransformOfMark], and the convenience [worldTransform] below
     * all share the exact same (MkNodeId, Index, MkAffineTransform) parameter
     * types, so Swift's three same-named, differently-labeled overloads
     * collide as "conflicting overloads" in Kotlin unless distinctly named.
     */
    fun worldTransformOfChild(childId: MkNodeId, index: Index, compositionAffine: MkAffineTransform): MkAffineTransform? =
        throw MkNotYetPorted("MkArrangedGeometry.worldTransform(ofChild:)")

    /**
     * The normative mark chain: `composition.affine ∘ base.affine ∘
     * translate(relativeOffset) ∘ mark.affine`.
     */
    fun worldTransformOfMark(markId: MkNodeId, index: Index, compositionAffine: MkAffineTransform): MkAffineTransform? =
        throw MkNotYetPorted("MkArrangedGeometry.worldTransform(ofMark:)")

    /**
     * Convenience: world transform for ANY arranged-child id (glyph,
     * composed ligature, decomposed-ligature component, or mark),
     * dispatching to the right formula.
     */
    fun worldTransform(id: MkNodeId, index: Index, compositionAffine: MkAffineTransform): MkAffineTransform? =
        throw MkNotYetPorted("MkArrangedGeometry.worldTransform(of:)")
}
