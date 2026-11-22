package net.binjamshid.makhtoot.mk.nativebridge

/**
 * Verbatim `hb_shape` output (D-303), already copied out of the native
 * shape-result handle by [MkShaper.shape] — this class holds no native
 * handle itself and needs no [java.io.Closeable] lifetime of its own.
 *
 * Mirrors the shape of `MakhtootKit/Sources/MKTextEngine/ShapedModels.swift`'s
 * per-run capture (glyphs/positions/advances/cluster indices) closely
 * enough that `:mk-textengine`'s Batch 3 port can build `MkShapedRun` from
 * this directly. No shaping *policy* (ligature/mark/joining-form
 * classification) lives here — that stays Kotlin's job downstream, exactly
 * as D-303 requires.
 *
 * @param glyphIds glyph ids in visual (shaped) order.
 * @param clusters `hb_glyph_info_t.cluster` per glyph — the source-string
 *   cluster this glyph belongs to (`HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS`,
 *   D-107/D-105's cluster-map dependency).
 * @param xAdvances per-glyph x-advance in pixels.
 * @param yAdvances per-glyph y-advance in pixels (0 for purely horizontal text).
 * @param xOffsets per-glyph GPOS x-offset in pixels (mark attachment, D-108).
 * @param yOffsets per-glyph GPOS y-offset in pixels (mark attachment, D-108).
 * @param isRtl the resolved run direction HarfBuzz actually shaped with.
 */
public data class MkShapedGlyphs(
    val glyphIds: IntArray,
    val clusters: IntArray,
    val xAdvances: FloatArray,
    val yAdvances: FloatArray,
    val xOffsets: FloatArray,
    val yOffsets: FloatArray,
    val isRtl: Boolean,
) {
    val glyphCount: Int get() = glyphIds.size

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is MkShapedGlyphs) return false
        return glyphIds.contentEquals(other.glyphIds) &&
            clusters.contentEquals(other.clusters) &&
            xAdvances.contentEquals(other.xAdvances) &&
            yAdvances.contentEquals(other.yAdvances) &&
            xOffsets.contentEquals(other.xOffsets) &&
            yOffsets.contentEquals(other.yOffsets) &&
            isRtl == other.isRtl
    }

    override fun hashCode(): Int {
        var result = glyphIds.contentHashCode()
        result = 31 * result + clusters.contentHashCode()
        result = 31 * result + xAdvances.contentHashCode()
        result = 31 * result + yAdvances.contentHashCode()
        result = 31 * result + xOffsets.contentHashCode()
        result = 31 * result + yOffsets.contentHashCode()
        result = 31 * result + isRtl.hashCode()
        return result
    }
}
