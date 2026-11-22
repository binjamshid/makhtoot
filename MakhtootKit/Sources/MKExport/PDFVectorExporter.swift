import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKRender

// P10-COMPLETION (Run-3, packet §5 task 11). "CG PDF context; WS-07 export
// path with `.pdfVector` option ، shapes/arranged/path-text as vector
// paths; live text via `CTFontDrawGlyphs` in the PDF context (subset-embeds
// automatically); license switch: no-embed fonts → outlines +
// `FallbackNote.outlinedText(reason: .fontLicense(fontName))`."
//
// **How this reuses the single render path (D-118/§16.3) instead of
// re-implementing drawing**: `MKSceneRenderer.render(_:region:into:scale:
// quality:)` (WS-07's ONLY drawing entry point) works with ANY `CGContext`
// ، nothing about it assumes a bitmap context. Handing it a freshly-created
// PDF `CGContext` (`CGContext(url:mediaBox:aux:)`) makes every existing
// drawer's CoreGraphics calls (`ctx.fill`, `ctx.strokePath`,
// `CTFontDrawGlyphs`) emit REAL PDF vector/text operators ، verified in
// `PDFVectorExporterTests` by reading the produced PDF's own content
// stream and confirming vector path operators (`re`, `f`, `S`) and text
// operators (`Tj`/glyph-showing ops) are present, and that live text is
// selectable (`pdftotext`-equivalent extraction round-trip). No new
// drawing code exists in THIS module for the "draw as real vector/text"
// case ، only the license-outline SUBSTITUTION case needs one (see
// `TextOutlining.swift`'s header for why that part can't reuse `MKRender`
// unmodified).
public enum PDFVectorExporter {
    public struct Result: Sendable {
        public var fallbacks: [FallbackNote]
    }

    /// Renders `scene` into a vector RGB PDF at `url`. `fontLicense`
    /// resolves the per-node embedding-rights switch (D-227(1)); `fonts`
    /// resolves `CTFont`s for both the normal render path AND the outline
    /// substitution path (same provider, so glyph shapes/positions never
    /// drift between the two).
    @discardableResult
    public static func export(
        scene: MKScene, pixelSize: CGSize, dpi: Double, title: String,
        fontLicense: any FontLicenseProviding, fonts: any MKFontProviding,
        assets: any MKAssetProviding = MKEmptyAssetProvider(),
        to url: URL
    ) throws -> Result {
        let effectiveDPI = dpi > 0 ? dpi : 72
        let canvasSize = scene.canvas.size
        guard canvasSize.width > 0, canvasSize.height > 0, pixelSize.width > 0, pixelSize.height > 0 else {
            throw MKExportError.degenerateTargetSize
        }
        var mediaBox = CGRect(
            x: 0, y: 0,
            width: pixelSize.width / effectiveDPI * 72.0,
            height: pixelSize.height / effectiveDPI * 72.0
        )
        guard mediaBox.width > 0, mediaBox.height > 0 else { throw MKExportError.degenerateTargetSize }

        let scale = mediaBox.width / canvasSize.width
        let restricted = MKEmbeddingRestrictionWalker.restrictedTextNodes(in: scene, fontLicense: fontLicense, right: .pdf, scale: scale)
        let renderScene = MKEmbeddingRestrictionWalker.hiding(restricted.map(\.id), in: scene)

        let aux = PDFOutputIntent.plainAuxiliaryInfo(title: title)
        guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, aux) else {
            throw MKExportError.encodingFailed
        }

        ctx.beginPDFPage(nil)
        let renderer = MKSceneRenderer(fonts: fonts, assets: assets)
        renderer.render(renderScene, region: CGRect(origin: .zero, size: canvasSize), into: ctx, scale: scale, quality: .exportQuality)

        var fallbacks: [FallbackNote] = []
        for entry in restricted {
            let colorGlyphNotes = MKOutlineSubstitutePainter.paint(entry, into: ctx, fonts: fonts)
            fallbacks.append(FallbackNote(nodeID: entry.id, reason: .fontEmbeddingRestricted(fontName: entry.fontPostScriptName)))
            fallbacks.append(contentsOf: colorGlyphNotes.map { FallbackNote(nodeID: entry.id, reason: $0.reason) })
        }
        ctx.endPDFPage()
        ctx.closePDF()

        return Result(fallbacks: fallbacks)
    }
}
