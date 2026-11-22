package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkBaseDirection

/**
 * One bidi run ، mirrors ARCHITECTURE.md §8.2's `MKBidiRun`. Ports
 * `Sources/MKTextEngine/BidiMap.swift`.
 */
data class MkBidiRun(
    /** Logical range (`CTRunGetStringRange`). */
    var utf16Range: IntRange,
    /**
     * Derived level: `1` for an RTL run, `2` for an LTR run embedded in an
     * RTL paragraph, `0` for an LTR run in an LTR paragraph (§8.2 ، Core
     * Text exposes only the RTL bit per run, not the full UBA embedding
     * level; this is the documented, intentionally coarse derivation).
     */
    var level: Int,
    /** `CTRunGetStatus(.rightToLeft)`, captured verbatim. */
    var isRTL: Boolean,
    /**
     * Index into [MkBidiMap.runs] ، i.e. this run's position in CTLine
     * visual order (D-109: "Preserve CTLine run order").
     */
    var visualOrdinal: Int,
)

/**
 * D-109 captured bidi structure for one shaped line ، mirrors
 * ARCHITECTURE.md §8.2's `MKBidiMap`, plus the per-glyph global visual
 * index the packet's task 7 requires ("assign each glyph a global
 * visualIndex left→right across the line") ، this is the value WS-04
 * writes into `MKProvenance.visualIndex`.
 */
data class MkBidiMap(
    var baseDirection: MkBaseDirection,
    /** Visual order ، identical array order to `MkShapedLine.runs`. */
    var runs: List<MkBidiRun>,
    /**
     * Global left→right visual index per glyph across the whole line:
     * always a permutation of `0..<glyphCount` (fuzz invariant).
     */
    var glyphVisualIndex: Map<MkGlyphAddress, Int>,
)

/**
 * D-109 bidi run capture (WS-03 packet §5 task 7). Makhtoot performs no
 * bidi resolution of its own (ARCHITECTURE §8.1) ، this builder only
 * records what Core Text already decided per run (`CTLineGetGlyphRuns`
 * order = visual order, `CTRunGetStatus(.rightToLeft)` per run) and derives
 * `level` per the coarse two-level rule documented on [MkBidiRun.level].
 */
object MkBidiMapBuilder {
    fun build(runs: List<MkShapedRun>, baseDirection: MkBaseDirection): MkBidiMap =
        throw MkNotYetPorted("MkBidiMapBuilder.build")
}
