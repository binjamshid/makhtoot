package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.arranged.MkMarkClass

/**
 * One resolved mark → base attachment (ARCHITECTURE §5.1 step 2 / §6.3),
 * captured at the cluster-map layer (full `MKMarkNode` ، with transform,
 * style, stacking ، is an MKArrange/P5 concern; this is the raw geometric
 * fact D-105 asks the engine to capture: "relative offset (GPOS result
 * captured from shaped positions)"). Ports
 * `Sources/MKTextEngine/MarkAttachment.swift`.
 *
 * P3-completion note: [relativeOffset] matches `MKMarkNode.relativeOffset`'s
 * type exactly (for frictionless WS-04 handoff) and [markClass] is
 * MKModel's [MkMarkClass].
 */
data class MkMarkAttachment(
    /** Index into the owning line's `clusterMap.clusters` for the mark. */
    var markClusterIndex: Int,
    /**
     * The mark's own glyph, when it has a distinct one. `null` when Core
     * Text fused the mark into its base's glyph (a `.baseWithMarks` cluster
     * with only one glyph total ، observed for shadda in this engine's
     * fixture captures). D-105 still requires the mark be recorded ("no
     * mark is orphaned") even without a distinct offset.
     */
    var markGlyph: MkGlyphAddress?,
    /**
     * Index into `clusterMap.clusters` for the resolved base cluster.
     * `null` = a free mark (§6.3: no preceding base exists at all, e.g. a
     * standalone tashkeel typed after whitespace or at string start).
     */
    var baseClusterIndex: Int?,
    /** The base glyph the mark is positioned relative to. */
    var baseGlyph: MkGlyphAddress?,
    /**
     * `markPosition − basePosition`, both taken directly from
     * `MkShapedRun.positions` in the same shaped-line (line-local)
     * coordinate frame ، this **is** the GPOS `mark`/`mkmk` anchoring
     * result by construction (D-105), no anchor-table parsing performed.
     * `null` exactly when [markGlyph] is `null`.
     */
    var relativeOffset: MkSize?,
    var markClass: MkMarkClass?,
)

/**
 * Resolves every mark in a shaped line to its base, per §6.3: "the base is
 * the nearest preceding non-mark glyph"; walks backward across cluster
 * boundaries (and run boundaries ، clusters are already in logical order in
 * `clusterMap.clusters`) since Core Text frequently gives a mark its own
 * `.markOnly` cluster distinct from its base's cluster.
 */
object MkMarkAttacher {
    fun attachments(line: MkShapedLine): List<MkMarkAttachment> =
        throw MkNotYetPorted("MkMarkAttacher.attachments")
}
