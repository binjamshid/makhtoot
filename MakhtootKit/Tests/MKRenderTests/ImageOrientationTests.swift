import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKRender
import Testing

// Regression coverage for the 2026-07-29 user report "importing a photo
// flips it upside-down".
//
// `MKSceneRenderer.render` concatenates a y-DOWN canvas CTM
// (`canvasToDevice`'s `d == -scale`), while `CGContext.draw(_:in:)` places
// an image's first pixel row along the rect's MAXIMUM-y edge because
// CoreGraphics defines image drawing in its own y-UP space. Uncorrected,
// the two cancel the wrong way and every bitmap paints vertically
// mirrored. `MKImageOrientation.drawUprightInYDownContext` is the fix;
// these tests assert the property directly in pixels, since a flipped
// image is exactly the kind of defect that survives code review.

@Suite("Image orientation through the render path")
struct ImageOrientationTests {
    /// A 2-row image: row 0 (the TOP row, as any image viewer would show
    /// it) is red, row 1 is blue. Encoded through a `CGContext`, whose
    /// origin is bottom-left ، so the red top row is filled at the HIGH y
    /// end of the context.
    private static func topRedBottomBlue(width: Int = 8, height: Int = 8) -> CGImage {
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { fatalError("failed to create fixture context") }
        // Bottom half of CG space == bottom half of the displayed image.
        ctx.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        // Top half of CG space == top half of the displayed image.
        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: height / 2, width: width, height: height - height / 2))
        guard let image = ctx.makeImage() else { fatalError("failed to create fixture image") }
        return image
    }

    private struct SingleImageProvider: MKAssetProviding {
        let ref: MKAssetRef
        let image: CGImage
        func resolveRasterImage(_ ref: MKAssetRef) -> CGImage? { ref == self.ref ? image : nil }
        func resolvePDFPage(_ ref: MKAssetRef) -> CGPDFPage? { nil }
    }

    /// Reads one pixel out of a `CGImage` in TOP-LEFT-origin (screen/
    /// document) coordinates ، the way a user looks at it.
    ///
    /// Read straight off the image's own data provider rather than by
    /// re-drawing into a scratch context: `CGImage` pixel data is defined
    /// top-row-first regardless of the origin convention of whatever
    /// context produced it, so this readback carries no orientation
    /// assumption of its own. A test for an orientation bug must not
    /// depend on the very convention it is checking.
    private static func pixel(_ image: CGImage, x: Int, yFromTop: Int) -> (r: UInt8, g: UInt8, b: UInt8)? {
        guard x >= 0, x < image.width, yFromTop >= 0, yFromTop < image.height else { return nil }
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return nil }
        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else { return nil }
        let offset = yFromTop * image.bytesPerRow + x * bytesPerPixel
        guard offset + 2 < CFDataGetLength(data) else { return nil }
        // The render path's contexts are all `premultipliedLast` with
        // default byte order, i.e. R,G,B,A in memory order.
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2])
    }

    private static let assetRef = MKAssetRef(digest: "orientation-fixture", ext: "png")

    @Test("a background photo's top stays on top after rendering")
    func backgroundImageIsNotVerticallyMirrored() throws {
        let scene = MKScene(
            canvas: MKCanvasSpec(size: CGSize(width: 64, height: 64)),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .image(Self.assetRef, fit: .cover)),
            nodes: []
        )
        let provider = SingleImageProvider(ref: Self.assetRef, image: Self.topRedBottomBlue())
        let renderer = MKSnapshotRenderer(assets: provider)
        let rendered = try #require(renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality))

        let top = try #require(Self.pixel(rendered, x: 32, yFromTop: 8))
        let bottom = try #require(Self.pixel(rendered, x: 32, yFromTop: 55))
        // Red on top, blue on the bottom ، i.e. exactly how the source
        // image reads. Before the fix these were swapped.
        #expect(top.r > 200 && top.b < 60)
        #expect(bottom.b > 200 && bottom.r < 60)
    }

    @Test("a placed image node's top stays on top after rendering")
    func imageNodeIsNotVerticallyMirrored() throws {
        let imageNode = MKNode.image(MKImageNode(
            core: MKNodeCore(
                name: "photo",
                transform: MKTransform2D(
                    position: CGPoint(x: 32, y: 32), rotation: 0, scale: CGSize(width: 48, height: 48))),
            asset: Self.assetRef,
            kind: .raster
        ))
        let scene = MKScene(
            canvas: MKCanvasSpec(size: CGSize(width: 64, height: 64)),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(MKSolidColor(r: 0, g: 1, b: 0, a: 1))),
            nodes: [imageNode]
        )
        let provider = SingleImageProvider(ref: Self.assetRef, image: Self.topRedBottomBlue())
        let renderer = MKSnapshotRenderer(assets: provider)
        let rendered = try #require(renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality))

        // The node spans y 8…56 about its centre at 32; sample well inside
        // each half.
        let top = try #require(Self.pixel(rendered, x: 32, yFromTop: 16))
        let bottom = try #require(Self.pixel(rendered, x: 32, yFromTop: 48))
        #expect(top.r > 200 && top.b < 60)
        #expect(bottom.b > 200 && bottom.r < 60)
    }

    @Test("a contained (letterboxed) background photo is not mirrored either")
    func containFitIsNotVerticallyMirrored() throws {
        // `.contain` and `.cover` compute different draw rects, and the
        // correction is expressed relative to that rect ، so the fit mode
        // must not be able to reintroduce the flip.
        let scene = MKScene(
            canvas: MKCanvasSpec(size: CGSize(width: 64, height: 64)),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .image(Self.assetRef, fit: .contain)),
            nodes: []
        )
        let provider = SingleImageProvider(ref: Self.assetRef, image: Self.topRedBottomBlue(width: 32, height: 16))
        let renderer = MKSnapshotRenderer(assets: provider)
        let rendered = try #require(renderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality))

        // A 32×16 image aspect-fit into 64×64 becomes 64×32, centred ، so
        // it occupies y 16…48, red on 16…32 and blue on 32…48.
        let top = try #require(Self.pixel(rendered, x: 32, yFromTop: 20))
        let bottom = try #require(Self.pixel(rendered, x: 32, yFromTop: 44))
        #expect(top.r > 200 && top.b < 60)
        #expect(bottom.b > 200 && bottom.r < 60)
    }
}
