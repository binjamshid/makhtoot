package net.binjamshid.makhtoot.mk.model.arranged

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.MkClusterId
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.MkFontRef
import net.binjamshid.makhtoot.mk.model.MkPathData
import net.binjamshid.makhtoot.mk.model.MkStyle

/**
 * One arranged base glyph (glossary: Glyph Node) — the both-levels
 * contract's shaped-glyph half (D-106). Ports
 * `Sources/MKModel/Arranged/GlyphNode.swift`.
 */

/** Stable pointer to one glyph within one font (D-106: "glyph id, font ref"). */
@Serializable
data class MkGlyphRef(
    var glyphID: Int,
    var font: MkFontRef,
    /** Hex string of the font's `sfnt` `head.checkSumAdjustment`. */
    var fontChecksum: String,
    /** Variable-font axis values, if the font instance is non-default. */
    var variationCoordinates: Map<String, Double>? = null,
)

/** Shaped position/advance/path-tangent captured at Arrange derivation time (D-106). */
@Serializable
data class MkGlyphLayout(
    /** Composition-space position at derivation. */
    var position: MkPoint,
    var advance: MkSize,
    /** Local path tangent angle (radians) — set only for path-derived glyphs (D-110). */
    var pathTangentAngle: Double? = null,
)

/**
 * Exact link back to Unicode — the "both levels supported" contract
 * (D-106/BRIEF). Shared by [MkGlyphNode]/[MkMarkNode]/[MkLigatureGroup].
 */
@Serializable
data class MkProvenance(
    /** Key into the owning composition's cluster grouping. */
    var clusterID: MkClusterId,
    /** Unicode scalar values this node realizes, in logical (typed) order. */
    var codepoints: List<Long>,
    /** UTF-16 range of `codepoints` within the source backup's string. */
    var utf16Start: Int,
    var utf16Length: Int,
    /** Unicode Bidi Algorithm embedding level (0...125, D-109). */
    var bidiLevel: Int,
    /** Index in the arranged composition's visual (paint) order. */
    var visualIndex: Int,
    /** Index in logical (typed/reading) order. */
    var logicalIndex: Int,
    /** WS-16 (D-222 step 8): `true` when this node's glyph is a GPOS cursive-attachment coverage member. Additive field, defaults to `false`. */
    var cursiveAttached: Boolean = false,
)

/** One base glyph, independently selectable/transformable (glossary: Glyph Node). D-106. */
@Serializable
data class MkGlyphNode(
    var id: MkNodeId = MkNodeId(),
    var glyph: MkGlyphRef,
    /** Cached outline, persisted (not just cached) — arranged nodes stay render-complete even if the source font locks. */
    var outline: MkPathData? = null,
    var layout: MkGlyphLayout,
    /** User-applied deltas on top of `layout.position` (independent per-glyph move/rotate/scale). */
    var transform: MkTransform2D = MkTransform2D.identity,
    var style: MkStyle = MkStyle.default,
    var provenance: MkProvenance,
    var joining: MkJoiningState = MkJoiningState.isolatedDefault,
    var isHidden: Boolean = false,
    var isLocked: Boolean = false,
)
