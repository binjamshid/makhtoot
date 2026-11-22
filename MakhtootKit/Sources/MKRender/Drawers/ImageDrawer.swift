import CoreGraphics
import MKFoundation
import MKModel

// WS-07 packet §5 task 2. `MKImageNode`: raster (`CGImage`) and vector-PDF
// (`CGPDFPage`) asset placement via `MKAssetProviding` (see that file's
// note on why this is a protocol seam rather than a `MKPersistence`
// import). `.vectorSVG` is a recorded substitution until `MKAssets` (WS-14)
// ships an `MKAssetVectorProgram` resolver.
public struct ImageDrawer: Sendable {
    public init() {}

    public func draw(
        _ node: MKImageNode, assets: any MKAssetProviding,
        into ctx: CGContext, quality: MKRenderQuality, report: inout MKRenderReportBuilder
    ) {
        // Images draw into their own local unit square (same "size lives in
        // the node transform's scale" convention as `ShapeDrawer`'s `.rect`/
        // `.ellipse` ، MKImageNode has no separate width/height field
        // either), aspect-FIT within it (never cropped) so the full asset
        // is always visible regardless of its native aspect ratio.
        let unitSquare = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)

        switch node.kind {
        case .raster:
            guard let image = assets.resolveRasterImage(node.asset) else {
                report.recordSubstitution(nodeID: node.core.id, kind: .missingAsset, detail: "raster asset unresolved: \(node.asset.digest).\(node.asset.ext)")
                return
            }
            let imageSize = CGSize(width: image.width, height: image.height)
            let fitted = MKGeometryMath.aspectFit(imageSize, in: unitSquare.size)
            let drawRect = CGRect(
                x: -fitted.width / 2, y: -fitted.height / 2, width: fitted.width, height: fitted.height
            )
            ctx.saveGState()
            ctx.interpolationQuality = quality.imageInterpolationQuality
            MKImageOrientation.drawUprightInYDownContext(image, in: drawRect, into: ctx)
            ctx.restoreGState()

        case .vectorPDF:
            guard let page = assets.resolvePDFPage(node.asset) else {
                report.recordSubstitution(nodeID: node.core.id, kind: .missingAsset, detail: "vector PDF asset unresolved: \(node.asset.digest).\(node.asset.ext)")
                return
            }
            let pageRect = page.getBoxRect(.mediaBox)
            guard pageRect.width > 0, pageRect.height > 0 else { return }
            let fitted = MKGeometryMath.aspectFit(pageRect.size, in: unitSquare.size)
            ctx.saveGState()
            // Same y-down correction the raster branch applies (see
            // `MKImageOrientation`): `drawPDFPage` also paints in
            // CoreGraphics' native y-UP space, so without this the page
            // renders vertically mirrored under the canvas CTM. The target
            // rect here is centered on the local origin, so reflecting
            // about `y == 0` maps it onto itself.
            ctx.scaleBy(x: 1, y: -1)
            ctx.translateBy(x: -fitted.width / 2, y: -fitted.height / 2)
            ctx.scaleBy(x: fitted.width / pageRect.width, y: fitted.height / pageRect.height)
            ctx.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
            ctx.drawPDFPage(page)
            ctx.restoreGState()

        case .vectorSVG:
            report.recordSubstitution(nodeID: node.core.id, kind: .missingAsset, detail: "SVG image nodes need MKAssets vector program (WS-14, not yet built)")
        }
    }
}

/// Bitmap orientation correction for this module's ONE drawing coordinate
/// system (bug fix, 2026-07-29, user report: "importing a photo flips it
/// upside-down" ، distinct from, and downstream of, the EXIF fix in
/// `MKFoundation.MKImageDownscale`, which only corrects camera-rotated
/// SOURCE pixels).
///
/// `MKSceneRenderer.render` concatenates `canvasToDevice(region:scale:)`,
/// whose `d` component is `-scale` ، i.e. every drawer paints into a
/// y-DOWN, top-left-origin user space (that file's "Coordinate
/// conventions" header states this explicitly). `CGContext.draw(_:in:)`,
/// however, always lays an image's first pixel row along the rect's
/// MAXIMUM-y edge, because CoreGraphics defines image drawing in its own
/// native y-UP space. Under a y-down CTM those two conventions cancel the
/// wrong way and every bitmap lands vertically mirrored ، which is why
/// text (`LiveTextDrawer`/`PathTextDrawer`, both of which re-flip with
/// `scaleBy(x: 1, y: -1)` before handing off to CoreText) has always been
/// upright while images never were.
///
/// Applied per-draw rather than by changing `canvasToDevice` because the
/// y-down convention is what every OTHER drawer, all node geometry, and
/// `MKNodeLocalBounds` are authored against.
public enum MKImageOrientation {
    /// Draws `image` filling `rect` the right way up, given a `ctx` whose
    /// CTM is the canvas's y-down space. Reflects about `rect`'s own
    /// horizontal centerline ، which maps `rect` exactly onto itself, so
    /// placement/aspect math at the call site needs no adjustment.
    public static func drawUprightInYDownContext(_ image: CGImage, in rect: CGRect, into ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: rect.midY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.translateBy(x: 0, y: -rect.midY)
        ctx.draw(image, in: rect)
        ctx.restoreGState()
    }
}

/// Cover-fit math (fills `bounds` entirely, may overflow one axis) ، the
/// one aspect mode `MKFoundation.MKGeometryMath` doesn't already provide
/// (`aspectFit` there covers the contain case `ImageDrawer` uses above).
/// `BackgroundDrawer` uses this for edge-to-edge image backgrounds.
public enum MKImageAspect {
    public static func cover(_ size: CGSize, in bounds: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = max(bounds.width / size.width, bounds.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
