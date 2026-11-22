import CoreGraphics

// P5.5 (§2.2) "Show Grid". Pure math, no UIKit/rendering dependency ،
// mirrors `SnapEngine.swift`'s own "pure math over plain candidate axes"
// shape so it's directly unit-testable and reusable by whatever chrome
// layer wants to draw it (`MKCanvasViewController.gridRenderer`, a second
// `GuideRenderer` instance, reuses the SAME `MKSnapGuide` descriptor this
// produces ، no new rendering primitive needed). Screen-only presentation:
// nothing here ever touches `MKScene`/export, matching this feature's own
// "grid must not appear in export" requirement by construction (there is
// no call site anywhere in `MKExport`/`MKRender` for this type).
public enum MKGridLines {
    /// Evenly-spaced vertical + horizontal reference lines across
    /// `canvasSize`, `divisions` cells per axis (default 10, a common
    /// design-tool default ، not derived from any BRIEF-mandated spacing
    /// value, since none is specified). Includes the canvas edges
    /// themselves (i == 0 and i == divisions) ، harmless (they coincide
    /// with the canvas bounds already visible via the render layer/
    /// backdrop), and keeps this a single uniform loop rather than a
    /// special-cased interior-only range.
    public static func guides(canvasSize: CGSize, divisions: Int = 10) -> [MKSnapGuide] {
        guard divisions > 0, canvasSize.width > 0, canvasSize.height > 0 else { return [] }
        var guides: [MKSnapGuide] = []
        for i in 0...divisions {
            let x = canvasSize.width * CGFloat(i) / CGFloat(divisions)
            guides.append(MKSnapGuide(axis: .horizontal, position: x, extentStart: 0, extentEnd: canvasSize.height))
            let y = canvasSize.height * CGFloat(i) / CGFloat(divisions)
            guides.append(MKSnapGuide(axis: .vertical, position: y, extentStart: 0, extentEnd: canvasSize.width))
        }
        return guides
    }
}
