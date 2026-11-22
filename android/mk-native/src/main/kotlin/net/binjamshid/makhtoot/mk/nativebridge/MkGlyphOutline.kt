package net.binjamshid.makhtoot.mk.nativebridge

/**
 * A decomposed glyph outline (D-303's FreeType half), already copied out of
 * the native path handle by [MkGlyphOutliner.outline] — holds no native
 * handle, needs no [java.io.Closeable] lifetime.
 *
 * [verbs] (see [MkOutlineVerb]) and [points] are parallel streams: walk
 * [verbs] in order, consuming `verb.pointCount` (x,y) pairs from [points]
 * for each one. `null` means the glyph has no vector outline at all — e.g.
 * a bitmap-only COLR/CBDT glyph outside the v1 bundled catalog; this is not
 * a shaping-delta case (`android/SHAPING_DELTAS.md`, D-325), it is an
 * outline-extraction result for a glyph id HarfBuzz already produced.
 */
public data class MkGlyphOutline(
    val verbs: IntArray,
    val points: FloatArray,
    val advance: Float,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is MkGlyphOutline) return false
        return verbs.contentEquals(other.verbs) &&
            points.contentEquals(other.points) &&
            advance == other.advance
    }

    override fun hashCode(): Int {
        var result = verbs.contentHashCode()
        result = 31 * result + points.contentHashCode()
        result = 31 * result + advance.hashCode()
        return result
    }
}
