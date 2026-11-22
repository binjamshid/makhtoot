import Testing
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKRender

// P6 leftover: `CanvasSession.flipSelection(axis:)` (`MKCanvas/
// EditingOperations.swift`) introduces the first-ever negative
// `MKTransform2D.scale` component in this codebase by directly negating
// `transform.scale.width`/`.height`. This suite is the render/hit-test half
// of the regression coverage the audit called for (session-level flip
// behavior + save/load round trip live in `MKCanvasTests`; SVG export in
// `MKExportTests`).
//
// Uses an asymmetric `.polygon` shape occupying only the LEFT half of its
// unit box (not `.rect`/`.ellipse`, which are symmetric about their own
// center and would render/hit-test identically whether flipped or not, per
// `ShapeDrawer.localPath(for:)`'s unit-square-relative convention: a flip
// about the node's own center is invisible on a centrally-symmetric shape).
@Suite struct FlipRenderingTests {
    private let renderer = MKSnapshotRenderer()
    private let tester = HitTester()

    /// Left-half-of-unit-box polygon (local space `x ∈ [-0.5, 0]`,
    /// `y ∈ [-0.5, 0.5]`) ، asymmetric under a horizontal flip specifically,
    /// so a horizontal flip provably swaps which world-space half is
    /// filled/hit, unlike `.rect`/`.ellipse`.
    private func leftHalfPolygonNode(position: CGPoint, scale: CGSize, stroke: MKStroke? = nil) -> MKNode {
        let core = MKNodeCore(
            name: "leftHalf",
            transform: MKTransform2D(position: position, scale: scale),
            style: MKStyle(fill: .solid(MKSolidColor(r: 0, g: 0.6, b: 0, a: 1)), stroke: stroke)
        )
        let geometry = MKShapeGeometry.polygon(points: [
            CGPoint(x: -0.5, y: -0.5), CGPoint(x: 0, y: -0.5), CGPoint(x: 0, y: 0.5), CGPoint(x: -0.5, y: 0.5),
        ])
        return .shape(MKShapeNode(core: core, geometry: geometry))
    }

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

    // MARK: - Rendering: a flipped node paints on the flipped side

    @Test func unflippedNodePaintsOnlyItsLeftHalf() {
        let node = leftHalfPolygonNode(position: CGPoint(x: 100, y: 100), scale: CGSize(width: 100, height: 100))
        let scene = TestScenes.scene(nodes: [node])
        guard let image = renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        let left = readPixel(image, x: 60, y: 100) // world x=60 → local x=-0.4, inside
        let right = readPixel(image, x: 140, y: 100) // world x=140 → local x=0.4, outside
        #expect(left.g > 100 && left.r < 60, "expected green fill on the left at \(left)")
        #expect(right.r > 200 && right.g > 200 && right.b > 200, "expected untouched white background on the right at \(right)")
    }

    /// The core regression: negating `scale.width` (a horizontal flip)
    /// must swap which world-space half paints, proving the render pipeline
    /// (`SceneRenderer` concatenating `transform.affineTransform` onto the
    /// context) honors a negative scale component rather than ignoring or
    /// mishandling its sign.
    @Test func horizontallyFlippedNodePaintsOnTheOppositeHalf() {
        var node = leftHalfPolygonNode(position: CGPoint(x: 100, y: 100), scale: CGSize(width: -100, height: 100))
        // Guard the fixture itself really has a negative scale component,
        // matching exactly what `flipSelection(axis: .horizontal)` produces.
        guard case .shape(let shapeNode) = node else { Issue.record("expected shape"); return }
        #expect(shapeNode.core.transform.scale.width < 0)
        node = .shape(shapeNode)

        let scene = TestScenes.scene(nodes: [node])
        guard let image = renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        let left = readPixel(image, x: 60, y: 100)
        let right = readPixel(image, x: 140, y: 100)
        #expect(left.r > 200 && left.g > 200 && left.b > 200, "expected untouched white background on the left (now unfilled) at \(left)")
        #expect(right.g > 100 && right.r < 60, "expected green fill on the right (now filled) at \(right)")
    }

    // MARK: - Stroke width stays sane (positive, non-NaN) after a flip

    /// `MKStylePainting.paint` divides the requested stroke width by
    /// `sqrt(|sx·sy|)` (`StylePainting.swift:74`, geometric mean of the
    /// node's own scale) ، with a negative `sx` this must still resolve to a
    /// finite, positive line width, never NaN (from `sqrt` of a negative
    /// product) or negative (which CoreGraphics would treat as an invalid/
    /// zero-width stroke).
    @Test func flippedNodeStrokeWidthStaysPositiveAndFinite() {
        let node = leftHalfPolygonNode(
            position: CGPoint(x: 100, y: 100), scale: CGSize(width: -100, height: 100),
            stroke: MKStroke(color: MKSolidColor(r: 1, g: 0, b: 0, a: 1), width: 3)
        )
        let scene = TestScenes.scene(nodes: [node])
        // Rendering must complete without producing a degenerate context
        // state (NaN line width would either crash CoreGraphics in debug
        // builds or silently no-op the stroke ، either way, a rendered
        // image with a visible red border pixel near the shape's edge is
        // proof a REAL, finite, positive stroke was painted.)
        guard let image = renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        // Scan a wide band straddling the flipped shape's outer edge
        // (world x=150, the boundary of the now-flipped-to-the-right fill)
        // and record every x where the pixel reads recognizably stroke-red
        // (r dominant over g/b). A finite, positive, ~3pt-wide compensated
        // stroke must show red across a SMALL, bounded run of x values
        // near the edge ، not zero (a NaN/degenerate width silently
        // dropping the stroke) and not a huge run spanning many points (a
        // sign/compensation bug inflating the width toward the box size,
        // exactly WS-08's original un-flipped defect this compensation
        // exists to prevent).
        var redXs: [Int] = []
        for x in stride(from: 130, through: 170, by: 1) {
            let pixel = readPixel(image, x: x, y: 100)
            if pixel.r > 150 && pixel.g < 100 && pixel.b < 100 { redXs.append(x) }
        }
        #expect(!redXs.isEmpty, "expected a visible red stroke band near the flipped shape's edge, found none in x∈[130,170]")
        if let minX = redXs.min(), let maxX = redXs.max() {
            #expect(maxX - minX < 10, "stroke band spans \(maxX - minX)pt (\(redXs)) ، expected a thin ~3pt band, not one inflated by a botched flip-sign stroke-width compensation")
        }
    }

    // MARK: - Hit-testing matches where the flipped node actually draws

    @Test func hitTestOnUnflippedNodeMatchesItsLeftHalf() {
        let node = leftHalfPolygonNode(position: CGPoint(x: 100, y: 100), scale: CGSize(width: 100, height: 100))
        let scene = TestScenes.scene(nodes: [node])
        #expect(tester.node(at: CGPoint(x: 60, y: 100), in: scene)?.nodeID == node.id)
        #expect(tester.node(at: CGPoint(x: 140, y: 100), in: scene) == nil)
    }

    /// Mirrors `horizontallyFlippedNodePaintsOnTheOppositeHalf` at the
    /// hit-testing layer: `HitTester` must agree with `SceneRenderer` about
    /// which half is "inside" after a flip, both driven by the exact same
    /// `transform.affineTransform` (no separate, potentially-drifting
    /// bounding-box approximation for the flipped case).
    @Test func hitTestOnFlippedNodeMatchesTheOppositeHalf() {
        let node = leftHalfPolygonNode(position: CGPoint(x: 100, y: 100), scale: CGSize(width: -100, height: 100))
        let scene = TestScenes.scene(nodes: [node])
        #expect(tester.node(at: CGPoint(x: 60, y: 100), in: scene) == nil, "the now-unfilled left half must miss")
        #expect(tester.node(at: CGPoint(x: 140, y: 100), in: scene)?.nodeID == node.id, "the now-filled right half must hit")
    }
}
