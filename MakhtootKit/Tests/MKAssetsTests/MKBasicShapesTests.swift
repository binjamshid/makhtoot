import CoreGraphics
import Foundation
import Testing
@testable import MKAssets

// WS-14 packet §5 task 4 accept criteria: "≥10 shapes; geometry unit tests
// (winding, bounds); crescent renders correct even-odd fill."
@Suite("MKBasicShapeGenerator (T4)")
struct MKBasicShapesTests {
    @Test func atLeastTenShapesAreGeneratedAllFree() {
        let shapes = MKBasicShapeGenerator.makeAll()
        #expect(shapes.count >= 10)
        #expect(shapes.allSatisfy { $0.category == .basicShapes })
        #expect(shapes.allSatisfy { !$0.isPremium })
        #expect(Set(shapes.map(\.assetID)).count == shapes.count, "asset ids must be unique")
    }

    @Test func everyShapeHasPositiveBounds() {
        for shape in MKBasicShapeGenerator.makeAll() {
            let bounds = shape.pathData.localBounds
            #expect(bounds.width > 0 && bounds.height > 0, "\(shape.assetID)")
        }
    }

    @Test func regularPolygonWindingIsConsistent() {
        // A convex polygon's own signed area (shoelace formula) should be
        // nonzero and consistent in sign for a fixed construction ، a
        // structural "winding is well-defined, not degenerate" check.
        let hexagon = MKAssetPathBuilder.regularPolygon(sides: 6, radius: 40)
        let area = signedArea(of: hexagon)
        #expect(abs(area) > 100)
    }

    /// The crescent's hole must render correctly under NONZERO fill (the
    /// only rule `MKRender.StylePainting` applies) ، verified by
    /// rasterizing and sampling a point known to be inside the "bite"
    /// (subtracted inner circle) vs. a point known to be inside the solid
    /// crescent body.
    @Test func crescentRendersCorrectHoleUnderNonzeroFill() {
        let crescent = MKBasicShapeGenerator.makeAll().first { $0.assetID == "shape.crescent" }!
        let image = MKAssetThumbnailRenderer.render(descriptor: crescent, size: CGSize(width: 200, height: 200))
        #expect(image != nil)
        guard let image else { return }

        let bounds = crescent.pathData.localBounds
        // A point deep inside the subtracted inner circle (near its center,
        // offset toward +x per MKAssetPathBuilder.crescent's construction)
        // must be UNPAINTED (alpha 0).
        let holePointLocal = CGPoint(x: bounds.midX + bounds.width * 0.18, y: bounds.midY)
        // A point on the crescent's thick outer edge (far -x side) must be
        // PAINTED.
        let solidPointLocal = CGPoint(x: bounds.minX + bounds.width * 0.06, y: bounds.midY)

        let holeAlpha = alpha(at: holePointLocal, in: image, bounds: bounds)
        let solidAlpha = alpha(at: solidPointLocal, in: image, bounds: bounds)
        #expect(holeAlpha == 0, "expected the crescent's subtracted region to be unpainted")
        #expect(solidAlpha > 0, "expected the crescent's solid body to be painted")
    }

    // MARK: - Helpers

    private func signedArea(of subpath: MKAssetSubpath) -> Double {
        let points = subpath.segments.map(\.start)
        var sum = 0.0
        for i in 0..<points.count {
            let a = points[i]
            let b = points[(i + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }

    /// Samples alpha at `localPoint` (in the asset's own local coordinate
    /// space) by mapping it through the SAME fit transform
    /// `MKAssetThumbnailRenderer.renderSingleMotif` uses (margin-fitted,
    /// centered) ، duplicated deliberately (not `@testable`-reaching into
    /// the private helper) so the test independently re-derives the
    /// mapping instead of trusting the implementation's own math.
    private func alpha(at localPoint: CGPoint, in image: CGImage, bounds: CGRect, size: CGSize = CGSize(width: 200, height: 200)) -> UInt8 {
        let margin = 0.08
        let availableW = size.width * (1 - 2 * margin)
        let availableH = size.height * (1 - 2 * margin)
        let scale = min(availableW / bounds.width, availableH / bounds.height)
        let dx = (localPoint.x - bounds.midX) * scale
        let dy = (localPoint.y - bounds.midY) * scale
        // The renderer's flip-to-top-left-origin context (`makeContext`)
        // inverts the y axis relative to the asset's own local (math-
        // convention, y-up) coordinate space ، device.y = H/2 − dy, not
        // H/2 + dy. (For this test's own sample points dy == 0 either way,
        // but the sign matters for any future reuse of this helper.)
        let px = Int(size.width / 2 + dx)
        let py = Int(size.height / 2 - dy)
        return pixelAlpha(in: image, x: px, y: py)
    }

    private func pixelAlpha(in image: CGImage, x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < image.width, y < image.height, let data = image.dataProvider?.data else { return 0 }
        let ptr = CFDataGetBytePtr(data)!
        let bytesPerPixel = 4
        let bytesPerRow = image.bytesPerRow
        let offset = y * bytesPerRow + x * bytesPerPixel
        // premultipliedLast: R,G,B,A
        return ptr[offset + 3]
    }
}
