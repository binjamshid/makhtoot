import Foundation
import MKModel

/// One bidi run ، mirrors ARCHITECTURE.md §8.2's `MKBidiRun`.
public struct MKBidiRun: Hashable, Sendable {
    /// Logical range (`CTRunGetStringRange`).
    public var utf16Range: Range<Int>
    /// Derived level: `1` for an RTL run, `2` for an LTR run embedded in an
    /// RTL paragraph, `0` for an LTR run in an LTR paragraph (§8.2 ، Core
    /// Text exposes only the RTL bit per run, not the full UBA embedding
    /// level; this is the documented, intentionally coarse derivation).
    public var level: UInt8
    /// `CTRunGetStatus(.rightToLeft)`, captured verbatim.
    public var isRTL: Bool
    /// Index into `MKBidiMap.runs` ، i.e. this run's position in CTLine
    /// visual order (D-109: "Preserve CTLine run order").
    public var visualOrdinal: Int

    public init(utf16Range: Range<Int>, level: UInt8, isRTL: Bool, visualOrdinal: Int) {
        self.utf16Range = utf16Range
        self.level = level
        self.isRTL = isRTL
        self.visualOrdinal = visualOrdinal
    }
}

/// D-109 captured bidi structure for one shaped line ، mirrors
/// ARCHITECTURE.md §8.2's `MKBidiMap`, plus the per-glyph global visual
/// index the packet's task 7 requires ("assign each glyph a global
/// visualIndex left→right across the line") ، this is the value WS-04
/// writes into `MKProvenance.visualIndex`.
public struct MKBidiMap: Hashable, Sendable {
    public var baseDirection: MKBaseDirection
    /// Visual order ، identical array order to `MKShapedLine.runs`
    /// (CTLine run order, D-109).
    public var runs: [MKBidiRun]
    /// Global left→right visual index per glyph across the whole line:
    /// runs are already in visual order and glyphs within a run are in
    /// visual order (see `MKShapedRun`'s order note), so the global index
    /// is a plain enumeration over (run, glyph) in array order. Always a
    /// permutation of `0..<glyphCount` (fuzz invariant).
    public var glyphVisualIndex: [MKGlyphAddress: Int]

    public init(baseDirection: MKBaseDirection, runs: [MKBidiRun], glyphVisualIndex: [MKGlyphAddress: Int]) {
        self.baseDirection = baseDirection
        self.runs = runs
        self.glyphVisualIndex = glyphVisualIndex
    }
}

/// D-109 bidi run capture (WS-03 packet §5 task 7). Makhtoot performs no
/// bidi resolution of its own (ARCHITECTURE §8.1) ، this builder only
/// records what Core Text already decided per run (`CTLineGetGlyphRuns`
/// order = visual order, `CTRunGetStatus(.rightToLeft)` per run) and
/// derives `level` per the coarse two-level rule documented on
/// `MKBidiRun.level`.
public enum MKBidiMapBuilder {
    public static func build(runs: [MKShapedRun], baseDirection: MKBaseDirection) -> MKBidiMap {
        let paragraphIsRTL = (baseDirection == .rightToLeft || baseDirection == .rightToLeftOverride)
        var bidiRuns: [MKBidiRun] = []
        bidiRuns.reserveCapacity(runs.count)
        var glyphVisualIndex: [MKGlyphAddress: Int] = [:]
        var nextVisualIndex = 0

        for (visualOrdinal, run) in runs.enumerated() {
            let level: UInt8
            if run.isRTL {
                level = 1
            } else {
                level = paragraphIsRTL ? 2 : 0
            }
            bidiRuns.append(MKBidiRun(
                utf16Range: run.stringRange,
                level: level,
                isRTL: run.isRTL,
                visualOrdinal: visualOrdinal))
            for glyphIndex in run.glyphs.indices {
                glyphVisualIndex[MKGlyphAddress(run: visualOrdinal, glyph: glyphIndex)] = nextVisualIndex
                nextVisualIndex += 1
            }
        }
        return MKBidiMap(baseDirection: baseDirection, runs: bidiRuns, glyphVisualIndex: glyphVisualIndex)
    }
}
