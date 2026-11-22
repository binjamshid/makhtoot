import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKRender

// P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 4 ، the
// stroke-width scaling fix). Reproduces (and proves fixed) the exact defect
// `docs/impl-log/WS-08.md`'s "Fixture-authoring pitfall" section found: a
// `MKShapeNode` rect scaled to a real on-canvas size (`transform.scale`
// carries the box dimensions, per `MKShapeGeometry`'s unit-square
// convention) with `stroke.width` chosen as an absolute-document-point
// value (e.g. `3`) used to stroke the ENTIRE canvas solid, because
// CoreGraphics scales line width by the CTM like any other geometry. See
// `StylePainting.swift`'s `strokeWidthCompensationScale` doc comment for
// the fix mechanism (`ShapeDrawer` passes `node.core.transform.scale`;
// `MKStylePainting.paint` divides the requested width by that scale's
// geometric mean before calling `ctx.setLineWidth`).
@Suite struct StrokeWidthCompensationTests {
    private let renderer = MKSnapshotRenderer()

    private func readPixel(_ image: CGImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return (Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2]), Int(data[offset + 3]))
    }

    /// Exact WS-08 repro shape: a 320×160 rect, green fill, red 3pt stroke.
    /// Before the fix, `ctx.setLineWidth(3)` under a ~253pt (`sqrt(320·160)`)
    /// CTM scale rendered a stroke wide enough to swallow the entire box ،
    /// the CENTER pixel would read as the STROKE color (red), not the fill
    /// (green). With the fix, a 3pt stroke on a 320×160 box only affects a
    /// thin border; the center must be fill-colored.
    private func makeScene() -> MKScene {
        let core = MKNodeCore(
            name: "rect",
            transform: MKTransform2D(position: CGPoint(x: 200, y: 200), scale: CGSize(width: 320, height: 160)),
            style: MKStyle(
                fill: .solid(MKSolidColor(r: 0, g: 1, b: 0, a: 1)),
                stroke: MKStroke(color: MKSolidColor(r: 1, g: 0, b: 0, a: 1), width: 3)
            )
        )
        let node = MKNode.shape(MKShapeNode(core: core, geometry: .rect(cornerRadius: 0)))
        return TestScenes.scene(canvasSize: CGSize(width: 400, height: 400), background: .white, nodes: [node])
    }

    @Test func centerOfALargeScaledStrokedRectStaysFillColorNotSwallowedByTheStroke() {
        let scene = makeScene()
        guard let image = renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        let center = readPixel(image, x: 200, y: 200)
        // Fill is green ، WITHOUT the fix this would read solid red (the
        // stroke consuming the whole box, WS-08's exact repro).
        #expect(center.g > 200 && center.r < 60 && center.b < 60,
                "expected fill (green) at the box center, got \(center) ، stroke swallowed the shape")
    }

    /// A point 20pt in from the box's left edge (well outside a ~3pt-wide
    /// border) must also read as fill ، pins the stroke's actual rendered
    /// thickness to a small, bounded value rather than "proportional to box
    /// size."
    @Test func twentyPointsInsideTheEdgeIsAlreadyFillColor() {
        let scene = makeScene()
        guard let image = renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        // Box spans x ∈ [40, 360] (center 200, half-width 160); 20pt inside
        // the left edge is x = 60.
        let insideEdge = readPixel(image, x: 60, y: 200)
        #expect(insideEdge.g > 200 && insideEdge.r < 60,
                "expected fill (green) 20pt inside the edge, got \(insideEdge)")
    }

    /// The immediate edge pixel (on the box boundary) IS expected to be
    /// stroke-colored ، the fix compensates the WIDTH, it doesn't remove
    /// the stroke.
    @Test func theBoxBoundaryItselfIsStillStrokeColored() {
        let scene = makeScene()
        guard let image = renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        // Box left edge at x = 40 (center 200 − half-width 160).
        let boundary = readPixel(image, x: 40, y: 200)
        #expect(boundary.r > 150, "expected the stroke (red) still visible right at the box boundary, got \(boundary)")
    }

    /// Degenerate/near-zero node scale must not divide-by-zero into an
    /// infinite or NaN line width (would either crash CoreGraphics or draw
    /// nothing/garbage) ، `MKStylePainting.paint`'s guard falls back to no
    /// compensation (scale factor 1) instead.
    @Test func nearZeroScaleFallsBackToNoCompensationWithoutCrashing() {
        let core = MKNodeCore(
            name: "sliver",
            transform: MKTransform2D(position: CGPoint(x: 200, y: 200), scale: CGSize(width: 0, height: 40)),
            style: MKStyle(
                fill: .solid(MKSolidColor(r: 0, g: 1, b: 0, a: 1)),
                stroke: MKStroke(color: MKSolidColor(r: 1, g: 0, b: 0, a: 1), width: 3)
            )
        )
        let node = MKNode.shape(MKShapeNode(core: core, geometry: .rect(cornerRadius: 0)))
        let scene = TestScenes.scene(canvasSize: CGSize(width: 400, height: 400), background: .white, nodes: [node])
        // The accept criterion here is simply "does not crash and produces
        // a real image" ، a zero-width box has no meaningful visible
        // content to assert pixel colors against.
        let image = renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality)
        #expect(image != nil)
    }
}
