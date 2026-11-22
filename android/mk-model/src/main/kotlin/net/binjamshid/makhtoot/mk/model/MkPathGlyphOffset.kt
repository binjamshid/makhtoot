package net.binjamshid.makhtoot.mk.model

import kotlinx.serialization.Serializable
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

/**
 * Persisted counterpart of `mk-pathtext`'s `PathClusterProvenanceKey` /
 * `PathGlyphUserOffset` (which are deliberately not `Codable`/`@Serializable`
 * runtime-only types — `mk-model` cannot depend on `mk-pathtext`, the
 * dependency edge runs the other way). Ports
 * `Sources/MKModel/MKPathGlyphOffset.swift`.
 */

/** "The Nth cluster with these exact codepoints" — a stable persistence key across a reshape. */
@Serializable
data class MkPathGlyphOffsetKey(
    var codepoints: List<Long>,
    var occurrenceOrdinal: Int,
)

/** A user-applied per-glyph nudge (position + rotation) on top of a path-text glyph's engine-computed placement. */
@Serializable
data class MkPathGlyphOffset(
    var offset: MkPoint = MkPoint.zero,
    var rotation: Double = 0.0,
) {
    companion object {
        val zero = MkPathGlyphOffset()
    }
}
