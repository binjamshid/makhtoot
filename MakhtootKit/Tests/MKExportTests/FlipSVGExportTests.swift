import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKExport

// P6 leftover: regression coverage for `CanvasSession.flipSelection(axis:)`
// (`MKCanvas/EditingOperations.swift`) surviving SVG export ، the render/
// hit-test half lives in `MKRenderTests/FlipRenderingTests.swift`, the
// session-level (undo/save-load round trip) half in `MKCanvasTests`.
//
// `SVGXML.matrix(_:)` (`SVGProvenance.swift`) emits a node's transform
// verbatim as `matrix(a,b,c,d,tx,ty)` from `CGAffineTransform` (no
// decomposition, no clamping) ، so a negative `MKTransform2D.scale`
// component must show up as a negative `a`/`d` component in the exported
// matrix, exactly matching `MKTransform2D.affineTransform`'s own formula.
@Suite struct FlipSVGExportTests {
    private func flippedRectScene(scaleWidth: CGFloat, canvasSize: CGSize = CGSize(width: 200, height: 200)) -> MKScene {
        let node = MKNode.shape(MKShapeNode(
            core: MKNodeCore(
                name: "Rect",
                transform: MKTransform2D(position: CGPoint(x: 100, y: 100), scale: CGSize(width: scaleWidth, height: 60)),
                style: MKStyle(fill: .solid(MKSolidColor(r: 0.8, g: 0.1, b: 0.1)))
            ),
            geometry: .rect(cornerRadius: 0)
        ))
        return MKScene(canvas: MKCanvasSpec(size: canvasSize), nodes: [node])
    }

    @Test func unflippedShapeMatrixHasAPositiveAComponent() throws {
        let scene = flippedRectScene(scaleWidth: 120)
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 200, height: 200))
        try XMLWellFormedness.assertWellFormed(result.svg)
        // Rotation 0 ، `a = scale.width * cos(0) = scale.width`.
        #expect(result.svg.contains("matrix(120,0,0,60,100,100)"))
    }

    /// The core regression: a horizontally-flipped node's negative
    /// `scale.width` must round-trip into the SVG `matrix()`'s `a`
    /// component as a literal negative number, not silently dropped,
    /// clamped to zero/positive, or NaN'd out (`SVGXML.number(_:)` maps
    /// NaN/infinite to `"0"`, which would otherwise mask exactly this
    /// class of bug).
    @Test func horizontallyFlippedShapeMatrixCarriesTheNegativeSign() throws {
        let scene = flippedRectScene(scaleWidth: -120)
        guard case .shape(let shapeNode) = scene.nodes[0] else { Issue.record("expected shape"); return }
        #expect(shapeNode.core.transform.scale.width < 0) // fixture sanity: matches flipSelection's own effect

        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 200, height: 200))
        try XMLWellFormedness.assertWellFormed(result.svg)
        #expect(result.svg.contains("matrix(-120,0,0,60,100,100)"),
                "expected the flip's negative scale to survive into the exported matrix() literally")
        // And not silently coerced to `0` by `SVGXML.number`'s NaN/infinite
        // guard (a plain negative number is neither) ، a regression here
        // would show `matrix(0,...)` instead.
        #expect(!result.svg.contains("matrix(0,0,0,60,100,100)"))
    }

    @Test func verticallyFlippedShapeMatrixCarriesTheNegativeSignOnD() throws {
        let node = MKNode.shape(MKShapeNode(
            core: MKNodeCore(
                name: "Rect",
                transform: MKTransform2D(position: CGPoint(x: 100, y: 100), scale: CGSize(width: 120, height: -60)),
                style: MKStyle(fill: .solid(MKSolidColor(r: 0.8, g: 0.1, b: 0.1)))
            ),
            geometry: .rect(cornerRadius: 0)
        ))
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 200, height: 200)), nodes: [node])
        let result = SVGSerializer.export(scene: scene, pixelSize: CGSize(width: 200, height: 200))
        try XMLWellFormedness.assertWellFormed(result.svg)
        #expect(result.svg.contains("matrix(120,0,0,-60,100,100)"))
    }
}
