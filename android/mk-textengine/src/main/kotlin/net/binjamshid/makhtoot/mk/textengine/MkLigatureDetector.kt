package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkClusterId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkLigatureSetting

/** Classification of a detected ligature (WS-03 packet §5 task 9). */
enum class MkLigatureKind {
    /**
     * The lam-alif family (lam + any alef variant) ، `rlig`, non-negotiable
     * in Arabic, present regardless of feature settings.
     */
    Required,

    /** Present only because discretionary ligatures were enabled (`.discretionaryOn`). */
    Discretionary,

    /** Any other multi-codepoint fusion the font produced under default features. */
    Contextual,
}

/**
 * One detected ligature: a cluster the font realized as a single glyph from
 * multiple non-mark codepoints (D-105's "ligature candidate", promoted to a
 * detection record with kind + provenance so WS-04 can build
 * `MKLigatureGroup`s with the feature-state provenance D-108 requires).
 * Ports `Sources/MKTextEngine/LigatureDetector.swift`.
 */
data class MkDetectedLigature(
    /** Ordinal into the owning line's `clusterMap.clusters`. */
    var clusterOrdinal: Int,
    /** The cluster's durable id (→ `MKProvenance.clusterID`). */
    var clusterID: MkClusterId,
    /** The single glyph realizing the ligature. */
    var glyph: MkGlyphAddress,
    /**
     * All constituent scalars, logical order (marks included if the
     * cluster carried any ، `MKLigatureGroup.provenance.codepoints` wants
     * the full constituent list per D-106).
     */
    var constituentScalars: List<Int>,
    var kind: MkLigatureKind,
    /**
     * The ligature setting active when this shape was captured ، WS-04
     * records this as provenance.
     */
    var activeSetting: MkLigatureSetting,
)

/**
 * WS-03 packet §5 task 9: promotes `.ligature`-kind clusters (and
 * base-with-marks clusters that fused into one glyph) to detection records
 * with a required/discretionary/contextual classification.
 *
 * Kind heuristic (packet task 9 verbatim): lam+alef pairs = required;
 * others = discretionary-if-dlig-else-contextual.
 */
object MkLigatureDetector {
    fun detect(line: MkShapedLine, activeSetting: MkLigatureSetting): List<MkDetectedLigature> =
        throw MkNotYetPorted("MkLigatureDetector.detect")
}
