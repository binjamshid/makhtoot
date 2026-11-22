package net.binjamshid.makhtoot.mk.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkClusterId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.textengine.MkGlyphAddress

/**
 * Runtime-only (deliberately not `@Serializable` — matches the Swift
 * source's "Codable-free runtime type" design) per-glyph placement output
 * of [MkPathLayoutEngine]'s `layout` functions. Ports
 * `Sources/MKPathText/PathGlyphPlacement.swift`'s `PathGlyphPlacement`
 * struct.
 *
 * **Naming-rule collision, documented (`ANDROID_SPINE.md` §3.3/§9), not
 * silent:** Swift's `PathGlyphPlacement` (this module, no `MK` prefix) and
 * `mk-arrange`'s `MKPathGlyphPlacement` (`Sources/MKArrange/PathPlacementProviding.swift`,
 * already carries the `MK` prefix) are two distinct, differently-spelled
 * Swift types — but the naming rule's mechanical `Mk`-prefix transform
 * would map BOTH to the identical simple name `MkPathGlyphPlacement`,
 * which collides the moment `MkPathPlacementProvider.kt` (this same
 * module) needs to reference both together. Resolved by an alternate
 * spelling for THIS type, `MkPathGlyphPlacementResult` (mk-arrange's stays
 * the plain mechanical `MkPathGlyphPlacement`) — this type is the fuller
 * engine output record (cluster/arc-length/user-offset/mark fields), so
 * the more descriptive name landed here.
 */

/** Stable identity for "the Nth cluster with these exact codepoints" — survives a full reshape. */
data class MkPathClusterProvenanceKey(
    var codepoints: List<Long>,
    var occurrenceOrdinal: Int,
)

/** A user-applied per-glyph nudge, keyed by [MkPathClusterProvenanceKey]. */
data class MkPathGlyphUserOffset(
    var offset: MkPoint = MkPoint.zero,
    var rotation: Double = 0.0,
) {
    companion object {
        val zero = MkPathGlyphUserOffset()
    }
}

/** One glyph's final placement on the path. */
data class MkPathGlyphPlacementResult(
    /** `(run, glyph)` address into the shaped line this placement was computed from. */
    var address: MkGlyphAddress,
    var clusterId: MkClusterId,
    var provenanceKey: MkPathClusterProvenanceKey,
    /** Arc length (points from path start) of this glyph's anchor. */
    var arcLength: Double,
    /** Final composition-local position. */
    var position: MkPoint,
    /** Final rotation, radians, CCW-positive. */
    var rotation: Double,
    var userOffset: MkPoint = MkPoint.zero,
    var userRotation: Double = 0.0,
    var isMark: Boolean = false,
    /** The base glyph's cluster id, for marks that resolved to a base. */
    var baseClusterId: MkClusterId? = null,
)

/** Overflow is always recorded, never silently dropped. */
data class MkPathOverflowInfo(
    var isOverflowing: Boolean = false,
    /** UTF-16 range (into the shaped line's source text) of clusters that overflowed the path. */
    var overflowUtf16Range: IntRange? = null,
    /** `true` when the overflowing glyphs were placed via straight extension along the exit tangent. */
    var continuedStraight: Boolean = false,
) {
    companion object {
        val none = MkPathOverflowInfo()
    }
}

/** [MkPathLayoutEngine]'s full output. */
data class MkPathLayoutResult(
    /** In path-traversal (global logical reading) order. */
    var placements: List<MkPathGlyphPlacementResult>,
    var overflow: MkPathOverflowInfo,
    var pathLength: Double,
    /** Set when any adjacent base-glyph pair's rotation differs by more than the curvature-warning threshold. */
    var curvatureWarning: Boolean,
    /** Highlight-ribbon support: arc length where the pen started, before any glyph was placed. */
    var penStartArcLength: Double = 0.0,
    /** Arc length where the pen finished, after the last glyph's span. */
    var penEndArcLength: Double = 0.0,
)
