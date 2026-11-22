package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.arrange.MkPathGlyphPlacement
import net.binjamshid.makhtoot.mk.arrange.MkPathPlacementProviding
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.textengine.MkGlyphAddress
import net.binjamshid.makhtoot.mk.textengine.MkShapedLine

/**
 * The real [MkPathPlacementProviding] conformer for `mk-arrange`'s
 * arrange-on-path seam. Ports
 * `Sources/MKPathText/PathPlacementProvider.swift`.
 *
 * **Dependency-edge note (documented, same precedent already logged for
 * WS-03/06/07's own targets):** `ANDROID_SPINE.md` §3.2 does not list a
 * `:mk-pathtext -> :mk-arrange` edge in the module dependency table as
 * currently drawn from `Package.swift`; conforming to `mk-arrange`'s
 * `MkPathPlacementProviding` interface from this module requires depending
 * on the module that declares it (Kotlin has no other way to conform to an
 * interface owned by another module), and `mk-arrange` never depends on
 * `mk-pathtext` (its own dependency edges are foundation/model/textengine/
 * persistence), so the edge `mk-pathtext -> mk-arrange` is acyclic. This is
 * an `android/docs/CONTRACT_CHANGES.md`-worthy dependency-edge addition for
 * Agent 1.1/the gate to apply — flagged here, not silently assumed.
 */
class MkPathTextPlacementProvider(
    private val layout: MkPathLayoutResult,
    private val lineIndex: Int = 0,
) : MkPathPlacementProviding {
    /** The seam `MkArrangeDeriver` calls once per base glyph while building `MkGlyphNode`s. */
    override fun placement(address: MkGlyphAddress, lineIndex: Int): MkPathGlyphPlacement? =
        throw MkNotYetPorted("MkPathTextPlacementProvider.placement")

    companion object {
        /** Builds a provider ready for `MkArrangeDeriver.derive(..., placement:)`, performing the documented Y-flip. */
        fun forArrangeOnPath(
            line: MkShapedLine,
            lineIndex: Int = 0,
            path: MkBezierPathData,
            options: MkPathLayoutOptions,
            userOffsets: Map<MkPathClusterProvenanceKey, MkPathGlyphUserOffset> = emptyMap(),
        ): Pair<MkPathTextPlacementProvider, MkPathLayoutResult> =
            throw MkNotYetPorted("MkPathTextPlacementProvider.forArrangeOnPath")
    }
}
