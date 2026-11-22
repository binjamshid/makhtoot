import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKRender
@testable import MKExport

// Closes the `imageBackgroundNotEmbedded` gap: canvas background images
// were silently dropped from SVG export (an empty, transparent hole, with
// NO warning). Vector PDF export already embedded background images
// correctly (see `PDFVectorExporterTests.vectorPDFAlreadyEmbedsTheCanvas
// BackgroundImage` below, which pins that pre-existing behavior as a
// regression guard) ، this file exercises the NEW SVG-side fix.
@Suite struct SVGBackgroundImageTests {
    /// A deliberately non-square image (300×150) against a differently-
    /// shaped (square, 200×200) canvas ، a square-in-square fixture would
    /// prove nothing about cover-crop vs. contain-letterbox math actually
    /// being exercised.
    private static let assetRef = MKAssetRef(digest: "feedface", ext: "png")
    private static let image = FakeAssetFactory.nonSquareImage(width: 300, height: 150)
    private static let canvasSize = CGSize(width: 200, height: 200)

    private func scene(fit: MKBackgroundImageFit) -> MKScene {
        var background = MKBackgroundNode.defaultBackground()
        background.content = .image(Self.assetRef, fit: fit)
        return MKScene(canvas: MKCanvasSpec(size: Self.canvasSize), background: background, nodes: [])
    }

    @Test func coverBackgroundEmbedsAsBase64ImageWithCoverFittedGeometry() throws {
        let result = SVGSerializer.export(
            scene: scene(fit: .cover), pixelSize: Self.canvasSize,
            assets: FakeAssetProvider(ref: Self.assetRef, image: Self.image)
        )
        #expect(result.svg.contains("<image"))
        #expect(result.svg.contains("data:image/png;base64,"))
        #expect(result.svg.contains("data-mk-kind=\"background\""))
        #expect(result.svg.contains("preserveAspectRatio=\"none\""))
        #expect(result.svg.contains("clip-path=\"url(#mk-canvas-clip)\""))

        // Geometry must match `MKImageAspect.cover`'s OWN output, not a
        // hardcoded number ، the same function `BackgroundDrawer` uses.
        let imageSize = CGSize(width: Self.image.width, height: Self.image.height)
        let fitted = MKImageAspect.cover(imageSize, in: Self.canvasSize)
        #expect(result.svg.contains("width=\"\(SVGXML.number(fitted.width))\""))
        #expect(result.svg.contains("height=\"\(SVGXML.number(fitted.height))\""))
        #expect(result.fallbacks.isEmpty)
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    @Test func containBackgroundEmbedsAsBase64ImageWithAspectFitGeometry() throws {
        let result = SVGSerializer.export(
            scene: scene(fit: .contain), pixelSize: Self.canvasSize,
            assets: FakeAssetProvider(ref: Self.assetRef, image: Self.image)
        )
        #expect(result.svg.contains("<image"))
        #expect(result.svg.contains("data:image/png;base64,"))
        #expect(result.svg.contains("preserveAspectRatio=\"none\""))

        let imageSize = CGSize(width: Self.image.width, height: Self.image.height)
        let fitted = MKGeometryMath.aspectFit(imageSize, in: Self.canvasSize)
        #expect(result.svg.contains("width=\"\(SVGXML.number(fitted.width))\""))
        #expect(result.svg.contains("height=\"\(SVGXML.number(fitted.height))\""))
        #expect(result.fallbacks.isEmpty)
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    /// Unresolved asset (the existing `MKEmptyAssetProvider` default, which
    /// answers `nil` for every lookup) must emit the new `.assetUnresolved`
    /// fallback note and must NOT emit an `<image>` element ، the honest,
    /// visibly-empty marker rect from before the fix stays in place.
    @Test func unresolvedBackgroundAssetEmitsFallbackNoteAndNoImageElement() throws {
        let result = SVGSerializer.export(scene: scene(fit: .cover), pixelSize: Self.canvasSize)
        #expect(!result.svg.contains("<image"))
        #expect(result.svg.contains("data-mk-outlined=\"imageBackgroundNotEmbedded\""))
        #expect(result.fallbacks.contains { if case .assetUnresolved = $0.reason { return true }; return false })
        try XMLWellFormedness.assertWellFormed(result.svg)
    }
}
