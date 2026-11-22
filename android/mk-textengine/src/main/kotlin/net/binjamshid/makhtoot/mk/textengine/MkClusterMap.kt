package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkClusterId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * One cluster: the unit D-105 defines as "codepoint index ↔ cluster ↔
 * glyph(s)". See [MkClusterMapBuilder] for the construction algorithm.
 * Ports `Sources/MKTextEngine/ClusterMap.swift`.
 *
 * P3-completion note: `id` is now the real `MkFoundation.MkClusterId`
 * (UUID phantom type ، the durable key `MKProvenance.clusterID` stores),
 * minted fresh per cluster at capture time. The maps in [MkClusterMap] key
 * on the cluster's array **ordinal** (index into `MkClusterMap.clusters`),
 * which is the cheap capture-local join key; `id` is what survives into
 * MKModel provenance when WS-04 derives an `ArrangedComposition`.
 */
data class MkCluster(
    /**
     * Durable id (MKFoundation `MkClusterId`, UUID-backed) ، the value WS-04
     * writes into `MKProvenance.clusterID`.
     */
    var id: MkClusterId = MkClusterId(),
    /** UTF-16 range in the shaped line's source text. */
    var utf16Range: IntRange,
    /** Scalars in [utf16Range], logical (source) order. */
    var codepoints: List<Int>,
    /**
     * Every glyph realizing this cluster, in the order they were found
     * while scanning the owning run (not guaranteed logical order for
     * multi-glyph clusters).
     */
    var glyphs: List<MkGlyphAddress>,
    var kind: Kind,
) {
    /**
     * Mirrors ARCHITECTURE.md §4.5's `MKCluster.Kind` exactly (the "1
     * codepoint → N glyphs" rare case is *not* a separate kind ،
     * ARCHITECTURE §4.5's correctness caveat treats it as a [Simple]
     * cluster whose `glyphs` array simply has more than one entry; "the
     * table never assumes 1:1 anywhere").
     */
    sealed class Kind {
        /** 1 non-mark codepoint → 1 or more glyphs, no combining marks. */
        object Simple : Kind()

        /**
         * >1 non-mark codepoint → exactly 1 glyph (ligature candidate, e.g.
         * lam-alif ، D-105).
         */
        object Ligature : Kind()

        /**
         * ≥1 non-mark codepoint plus ≥1 mark codepoint sharing this cluster
         * (marks may or may not have their own glyph within the cluster ،
         * font-dependent, see `MkMarkAttacher`).
         */
        data class BaseWithMarks(val baseCount: Int) : Kind()

        /**
         * All codepoints in the cluster are marks; no base letter shares it
         * (base resolution walks to the nearest preceding cluster ، §6.3
         * "free mark" case when no preceding base exists at all).
         */
        object MarkOnly : Kind()

        /**
         * All codepoints are ZWJ/ZWNJ/bidi-control formatting characters
         * (`MkMarkClassifier.isControlFormatter`). Dropped from renderable
         * children downstream; retained here so revert/Unicode-level
         * editing still sees them (§5.1 step 2).
         */
        object Control : Kind()
    }
}

/** D-105's bidirectional map: codepoint index ↔ cluster ↔ glyph(s). */
data class MkClusterMap(
    /**
     * Logical order (ascending `utf16Range.lowerBound`) ، this is what makes
     * cross-run bidi reordering transparent to consumers walking `clusters`
     * in array order (ARCHITECTURE §4.5 step 5).
     */
    var clusters: List<MkCluster>,
    /** Every glyph address that belongs to some cluster → index into [clusters]. */
    var glyphToCluster: Map<MkGlyphAddress, Int>,
    /** Every UTF-16 index covered by some cluster → index into [clusters]. */
    var utf16ToCluster: Map<Int, Int>,
)

/**
 * D-105 cluster-map construction (WS-03 packet §5 task 6). Algorithm,
 * matching ARCHITECTURE.md §4.5 exactly (see the Swift source's extensive
 * algorithm doc comment, preserved in
 * `MakhtootKit/Sources/MKTextEngine/ClusterMap.swift` for the full six-step
 * derivation): collect glyph (address, stringIndex) pairs per run, group by
 * distinct string index to find cluster boundaries within a run (sorted by
 * value, not glyph-array position, to restore logical order for RTL runs),
 * sort all raw clusters by `utf16Range.lowerBound` ascending across runs,
 * decode codepoints from the source text's UTF-16 view, then classify each
 * cluster's [MkCluster.Kind].
 */
object MkClusterMapBuilder {
    fun build(runs: List<MkShapedRun>, sourceUtf16: List<Int>): MkClusterMap =
        throw MkNotYetPorted("MkClusterMapBuilder.build")
}
