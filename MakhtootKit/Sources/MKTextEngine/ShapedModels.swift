import CoreGraphics
import MKFoundation
import MKModel

// P3-completion pass: the early spike's `MKTE*` capture types now carry
// their final ARCHITECTURE §4.2 names (`MKShapedRun`/`MKShapedLine`/…).
// These remain MKTextEngine-owned value types (they are the engine's
// *output* contract consumed by WS-04/05/07/08), not MKModel types ، the
// scene graph stores MKModel's `ArrangedComposition`, which WS-04 derives
// FROM these.

/// Addresses one glyph as `(run index, glyph index within that run)` inside
/// a single `MKShapedLine`. Used as the join key between
/// `MKShapedRun.glyphs`/`positions`/`advances` and the cluster/bidi/mark
/// maps (D-105).
public struct MKGlyphAddress: Hashable, Sendable {
    public var run: Int
    public var glyph: Int

    public init(run: Int, glyph: Int) {
        self.run = run
        self.glyph = glyph
    }
}

/// Resolved Core Text attributes captured back off a run (packet task 3's
/// `attributes` field; T-TXT-10's kerning/tracking/baseline survival
/// check). Colour/shadow/stroke are node-style concerns (`MKStyle`), not
/// shaping attributes, and are deliberately absent here.
public struct MKResolvedRunAttributes: Hashable, Sendable {
    public var tracking: CGFloat
    public var baselineShift: CGFloat
    public var standardLigaturesEnabled: Bool

    public init(tracking: CGFloat = 0, baselineShift: CGFloat = 0, standardLigaturesEnabled: Bool = true) {
        self.tracking = tracking
        self.baselineShift = baselineShift
        self.standardLigaturesEnabled = standardLigaturesEnabled
    }
}

/// One Core Text glyph run, captured verbatim (D-103): every array below is
/// copied directly from `CTRunGetGlyphs`/`CTRunGetPositions`/
/// `CTRunGetAdvances`/`CTRunGetStringIndices` with no reordering, rounding,
/// or reinterpretation. All arrays share `glyphs.count` entries and are
/// index-parallel.
///
/// **Order note:** this is the run's own *glyph* order as Core Text
/// returns it (already visually left-to-right within the run for both LTR
/// and RTL runs ، RTL only affects *which* codepoint a given position
/// corresponds to, not the array's visual left-to-right walk order).
/// Cross-run *logical* order must never be assumed from array/run index ،
/// see `MKClusterMap`/`MKBidiMap`.
public struct MKShapedRun: Hashable, Sendable {
    public var glyphs: [UInt16]              // CGGlyph
    public var positions: [CGPoint]          // CTRunGetPositions ، line-origin-relative, Core Text y-up (CoordinateSpace.swift)
    public var advances: [CGSize]            // CTRunGetAdvances
    public var stringIndices: [Int]          // CTRunGetStringIndices ، UTF-16 index of the first codepoint of each glyph's cluster
    public var stringRange: Range<Int>       // CTRunGetStringRange ، UTF-16, into the shaped line's source text
    public var isRTL: Bool                   // CTRunGetStatus(.rightToLeft)
    public var isNonMonotonic: Bool          // CTRunGetStatus(.nonMonotonic) ، reordered-mark clusters (task 4 accept criterion)
    public var font: MKFontHandle            // resolved from CTRunGetAttributes[.font] (postScriptName + pointSize)
    public var attributes: MKResolvedRunAttributes
    /// WS-16 (D-222 step 8 / `docs/impl-log/WS-16-cursive.md`, ADR WS16-A2):
    /// index-parallel to `glyphs` ، `true` when the glyph ID at that index
    /// is a member of the font's GPOS 'curs' (LookupType 3, cursive
    /// attachment) coverage table. This is a provenance ANNOTATION only ،
    /// `positions[i]` is already the real, Core-Text-computed, cursive-
    /// adjusted placement (D-105: "the shaped positions already encode the
    /// answer"), unaffected by this flag. The flag exists so a downstream
    /// consumer that RESHAPES a single glyph via the D-107 synthetic-ZWJ-
    /// context technique (join break/restore, ligature decompose ، outside
    /// this module) can tell whether the glyph it is about to replace was
    /// part of a contextual cursive-connected sequence a synthetic ZWJ
    /// context cannot reproduce, and treat that case as an accepted-by-
    /// design fidelity limitation (matching D-222's own precedent for
    /// single-glyph scale inside a joined word) rather than silently claim
    /// an exact round-trip. Computed via `MKCursiveCoverageCache`
    /// (Coverage-table-only read ، never anchor values, never a recomputed
    /// position).
    public var cursiveAttached: [Bool]

    public init(
        glyphs: [UInt16],
        positions: [CGPoint],
        advances: [CGSize],
        stringIndices: [Int],
        stringRange: Range<Int>,
        isRTL: Bool,
        isNonMonotonic: Bool,
        font: MKFontHandle,
        attributes: MKResolvedRunAttributes,
        cursiveAttached: [Bool]? = nil
    ) {
        self.glyphs = glyphs
        self.positions = positions
        self.advances = advances
        self.stringIndices = stringIndices
        self.stringRange = stringRange
        self.isRTL = isRTL
        self.isNonMonotonic = isNonMonotonic
        self.font = font
        self.attributes = attributes
        self.cursiveAttached = cursiveAttached ?? Array(repeating: false, count: glyphs.count)
    }
}

public struct MKLineMetrics: Hashable, Sendable {
    public var ascent: CGFloat
    public var descent: CGFloat
    public var leading: CGFloat
    public var width: CGFloat

    public init(ascent: CGFloat, descent: CGFloat, leading: CGFloat, width: CGFloat) {
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.width = width
    }
}

/// One shaped line: CTLine run order preserved (D-109), plus the derived
/// cluster and bidi maps for that line.
public struct MKShapedLine: Hashable, Sendable {
    public var runs: [MKShapedRun]              // CTLine visual run order, preserved verbatim
    public var typographicBounds: MKLineMetrics
    public var clusterMap: MKClusterMap         // D-105
    public var bidiMap: MKBidiMap               // D-109
    public var lineIndexInParagraph: Int
    public var sourceRange: Range<Int>          // UTF-16 range of the paragraph's source text this line covers
    public var sourceText: String               // full paragraph source text (kept so callers/tests don't need the original request)

    public init(
        runs: [MKShapedRun],
        typographicBounds: MKLineMetrics,
        clusterMap: MKClusterMap,
        bidiMap: MKBidiMap,
        lineIndexInParagraph: Int,
        sourceRange: Range<Int>,
        sourceText: String
    ) {
        self.runs = runs
        self.typographicBounds = typographicBounds
        self.clusterMap = clusterMap
        self.bidiMap = bidiMap
        self.lineIndexInParagraph = lineIndexInParagraph
        self.sourceRange = sourceRange
        self.sourceText = sourceText
    }

    /// Total glyph count across all runs (cache cost accounting, fuzz
    /// invariants).
    public var glyphCount: Int {
        runs.reduce(0) { $0 + $1.glyphs.count }
    }
}

public struct MKShapedParagraph: Hashable, Sendable {
    public var lines: [MKShapedLine]
    public var sourceText: String

    public init(lines: [MKShapedLine], sourceText: String) {
        self.lines = lines
        self.sourceText = sourceText
    }

    public var glyphCount: Int {
        lines.reduce(0) { $0 + $1.glyphCount }
    }

    /// MASTER-PLAN Phase-2 RTL-alignment fix: the node's own box width, as
    /// every consumer of this paragraph already independently (and
    /// identically) computed it before this fix ،
    /// `MKNodeLocalBounds.localBounds(of:)`'s `.liveText` case ، the widest
    /// line's own measured typographic width, NOT `MKTextFrameSpec`'s
    /// `.widthConstrained` wrap width (a text box can be wider than its
    /// longest rendered line). Centralized here so `LiveTextDrawer` and
    /// `SVGTextWriter` (MKExport) agree with `MKNodeLocalBounds` and with
    /// each other on exactly the same number.
    public var boxWidth: CGFloat {
        lines.map(\.typographicBounds.width).max() ?? 0
    }

    /// The node box's HEIGHT, as a companion to `boxWidth` and defined the
    /// same way: whatever actually gets painted, so bounds and drawn
    /// content cannot drift apart.
    ///
    /// Bug fix (2026-07-29, user report: "text can overflow in a text
    /// field box and get cutoff"). Every caller previously computed this
    /// as `lineHeight × lineCount` independently, which is the box a
    /// *layout* engine reserves ، not the box the glyphs occupy.
    /// `LiveTextDrawer` puts line 0's BASELINE at `lines[0]
    /// .typographicBounds.ascent` and steps by `lineHeight` thereafter, so
    /// the painted extent runs to `ascent₀ + (n−1)·lineHeight +
    /// descent_last`. Whenever a face's `ascent + descent` exceeds
    /// `lineHeightMultiple × pointSize` ، routine for Arabic faces, whose
    /// descenders and below-baseline tashkeel push the em box well past
    /// the 1.2× default ، the old number was SHORTER than the ink, and
    /// `MKLayerTreeController` sizes each node's `CALayer` to exactly these
    /// bounds, so the bottom of the text was clipped away.
    ///
    /// `max` with the reserved height keeps multi-line spacing intact for
    /// faces where the reserved box is the larger of the two.
    public func boxHeight(lineHeight: CGFloat) -> CGFloat {
        guard let first = lines.first, let last = lines.last else { return 0 }
        let painted = first.typographicBounds.ascent
            + CGFloat(lines.count - 1) * lineHeight
            + last.typographicBounds.descent
        return max(lineHeight * CGFloat(lines.count), painted)
    }

    /// Per-line local-space x origin inside this paragraph's `[0, boxWidth]`
    /// box (D-109 direction-aware multi-line alignment; MASTER-PLAN Phase-2
    /// bug fix). A line narrower than `boxWidth` is offset so it hugs the
    /// box's edge its own paragraph direction reads FROM, leaving the
    /// ragged edge on the other side:
    /// - `.rightToLeft`/`.rightToLeftOverride` (D-109 default): flush
    ///   RIGHT ، offset by `boxWidth - lineWidth`, ragged left.
    /// - `.leftToRight`: flush LEFT ، offset `0` (prior/unchanged
    ///   behavior), ragged right.
    public func lineOriginX(lineWidth: CGFloat, baseDirection: MKBaseDirection) -> CGFloat {
        switch baseDirection {
        case .rightToLeft, .rightToLeftOverride:
            return boxWidth - lineWidth
        case .leftToRight:
            return 0
        }
    }
}
