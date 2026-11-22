package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontHandle
import net.binjamshid.makhtoot.mk.model.MkBaseDirection

/**
 * Ports `Sources/MKTextEngine/ShapedModels.swift` — the frozen shaping
 * output types every other engine module (and `mk-arrange`'s deriver)
 * consumes.
 */

/** Addresses one glyph: which run, and which glyph within that run. */
data class MkGlyphAddress(
    var run: Int,
    var glyph: Int,
)

/** Per-run resolved style attributes (tracking/baseline-shift/ligature toggle) captured at shape time. */
data class MkResolvedRunAttributes(
    var tracking: Double = 0.0,
    var baselineShift: Double = 0.0,
    var standardLigaturesEnabled: Boolean = true,
)

/** One shaped run: glyphs, positions, advances, and their source-string correspondence. */
data class MkShapedRun(
    var glyphs: List<Int>,
    var positions: List<MkPoint>,
    var advances: List<MkSize>,
    var stringIndices: List<Int>,
    var stringRange: IntRange,
    var isRTL: Boolean,
    var isNonMonotonic: Boolean,
    var font: MkFontHandle,
    var attributes: MkResolvedRunAttributes,
    /** WS-16/D-222: per-glyph GPOS cursive-attachment provenance flag, index-parallel to [glyphs]. */
    var cursiveAttached: List<Boolean>,
)

/** Typographic metrics for one shaped line. */
data class MkLineMetrics(
    var ascent: Double,
    var descent: Double,
    var leading: Double,
    var width: Double,
)

/** One fully shaped line: runs plus the D-105/D-109 cluster and bidi maps captured alongside it. */
data class MkShapedLine(
    var runs: List<MkShapedRun>,
    var typographicBounds: MkLineMetrics,
    var clusterMap: MkClusterMap,
    var bidiMap: MkBidiMap,
    var lineIndexInParagraph: Int,
    var sourceRange: IntRange,
    var sourceText: String,
) {
    /** Total glyph count across every run in this line. */
    val glyphCount: Int
        get() = throw MkNotYetPorted("MkShapedLine.glyphCount")
}

/** A fully shaped paragraph: every line, plus the box-relative line-origin math the deriver/drawer share. */
data class MkShapedParagraph(
    var lines: List<MkShapedLine>,
    var sourceText: String,
) {
    /** Total glyph count across every line. */
    val glyphCount: Int
        get() = throw MkNotYetPorted("MkShapedParagraph.glyphCount")

    /** The paragraph's overall box width (max of every line's typographic width). */
    val boxWidth: Double
        get() = throw MkNotYetPorted("MkShapedParagraph.boxWidth")

    /** The paragraph's overall box height for the given [lineHeight]. */
    fun boxHeight(lineHeight: Double): Double = throw MkNotYetPorted("MkShapedParagraph.boxHeight")

    /** The box-relative X origin for a line of [lineWidth] under [baseDirection] (D-109 RTL-alignment). */
    fun lineOriginX(lineWidth: Double, baseDirection: MkBaseDirection): Double =
        throw MkNotYetPorted("MkShapedParagraph.lineOriginX")
}
