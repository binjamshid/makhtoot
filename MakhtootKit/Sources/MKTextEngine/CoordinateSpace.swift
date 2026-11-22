import CoreGraphics

/// Coordinate-system documentation and conversion helpers for the shaping
/// capture in this module (WS-03 packet §5 task 3: "documented coordinate
/// convention").
///
/// **Line-local space.** Every position captured into `MKTEShapedRun.positions`
/// is exactly what `CTRunGetPositions` reported, relative to the **line
/// origin** (not the paragraph origin, not any view). Core Text's space is
/// **y-up** ، increasing `y` moves *up* the page, matching Core
/// Graphics/PDF convention, NOT UIKit's y-down view space. This module
/// never flips or rewrites a captured position; the raw Core Text value is
/// the source of truth (ARCHITECTURE.md §4.4: "Fractional positions are
/// kept as `CGFloat` exactly as returned; rounding happens only at
/// rasterization").
///
/// **Paragraph stacking.** `MKShapingEngine.shapeParagraph(_:)` advances
/// each subsequent line downward on the page in Core Text's own y-up
/// terms: line N+1's baseline sits `(ascent + descent + leading) ×
/// lineHeightMultiple` *below* line N's, i.e. at a smaller y if the whole
/// paragraph is later composed into one shared space. This module does not
/// itself perform that composition (each `MKTEShapedLine` stays in its own
/// line-local origin) ، stacking into one paragraph-local frame is a
/// rendering-time concern (MKRender, P4) once real scene composition
/// exists.
///
/// **UIKit conversion.** Consumers drawing into a y-down UIKit/CALayer
/// context must flip. `flippedForUIKit(_:frameHeight:)` is the one pure
/// helper this module ships for that; it is intentionally minimal ، full
/// screen composition against scene transforms belongs to MKRender (P4),
/// not this early-spike engine.
public enum MKCoordinateSpace {
    /// Flips a Core Text (y-up, line-relative) point into a y-down frame of
    /// the given `frameHeight` (e.g. a line's `ascent + descent`). Pure
    /// function, no state, no dependency on UIKit.
    public static func flippedForUIKit(_ point: CGPoint, frameHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: frameHeight - point.y)
    }
}
