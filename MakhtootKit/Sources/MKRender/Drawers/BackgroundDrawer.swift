import CoreGraphics
import MKFoundation
import MKModel

// WS-07 packet §5 task 2. `MKBackgroundNode`: "transform ignored; always
// canvas-filling" (MKNode.swift's own doc comment on `MKBackgroundNode`) ،
// this drawer fills exactly `canvasBounds` (the document's `MKCanvasSpec
// .size` rect, in canvas-local space), never the node's own
// `core.transform`. Both `.solid` and `.image` content are implemented
// (`.image` background is premium content the renderer does not gate ،
// §12.5 ، but DOES need `MKAssetProviding`, same as `ImageDrawer`).
public struct BackgroundDrawer: Sendable {
    public init() {}

    public func draw(
        _ node: MKBackgroundNode, canvasBounds: CGRect, assets: any MKAssetProviding,
        into ctx: CGContext, quality: MKRenderQuality, report: inout MKRenderReportBuilder
    ) {
        switch node.content {
        case .solid(let color):
            ctx.setFillColor(color.cgColor)
            ctx.fill(canvasBounds)
        case .image(let ref, let fit):
            guard let image = assets.resolveRasterImage(ref) else {
                report.recordSubstitution(nodeID: node.core.id, kind: .missingAsset, detail: "background image asset unresolved: \(ref.digest).\(ref.ext)")
                return
            }
            ctx.saveGState()
            ctx.clip(to: canvasBounds)
            // P5.3: `fit` picks the aspect strategy ، `.cover` (v1's only
            // behavior, kept as the default everywhere a fit isn't
            // explicitly chosen) fills the canvas edge to edge, may crop;
            // `.contain` fits the whole image inside the canvas, may leave
            // the background's own solid-color carrier visible at the
            // edges (never transparent ، this drawer already clipped to
            // `canvasBounds`, and nothing beneath it is drawn here).
            let imageSize = CGSize(width: image.width, height: image.height)
            let fitted: CGSize
            switch fit {
            case .cover: fitted = MKImageAspect.cover(imageSize, in: canvasBounds.size)
            case .contain: fitted = MKGeometryMath.aspectFit(imageSize, in: canvasBounds.size)
            }
            let originX = canvasBounds.midX - fitted.width / 2
            let originY = canvasBounds.midY - fitted.height / 2
            ctx.interpolationQuality = quality.imageInterpolationQuality
            // See `MKImageOrientation`: the canvas CTM is y-down, but
            // `CGContext.draw(_:in:)` is defined in CoreGraphics' native
            // y-up space, so an uncorrected draw mirrors the photo
            // vertically (user-reported "importing a photo flips it
            // upside-down").
            MKImageOrientation.drawUprightInYDownContext(
                image, in: CGRect(x: originX, y: originY, width: fitted.width, height: fitted.height), into: ctx)
            ctx.restoreGState()
        }
    }
}
