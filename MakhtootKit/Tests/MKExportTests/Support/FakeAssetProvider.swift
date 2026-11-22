import CoreGraphics
import MKModel
import MKRender

// Test-only `MKAssetProviding` conformer ، resolves a single, synthetically
// generated `CGImage` for one `MKAssetRef` and reports every other lookup as
// missing (matching `MKEmptyAssetProvider`'s "everything unresolved" default
// for anything not explicitly registered). Used by `SVGSerializerTests`/
// `PDFVectorExporterTests` to exercise the real base64/PNG-embed pipeline
// end to end without needing an on-disk asset store (`MKAssets`, WS-14, not
// yet built ، see `AssetProviding.swift`'s own note on why `MKRender` takes
// this protocol seam instead).
struct FakeAssetProvider: MKAssetProviding {
    let ref: MKAssetRef
    let image: CGImage

    func resolveRasterImage(_ ref: MKAssetRef) -> CGImage? {
        ref == self.ref ? image : nil
    }

    func resolvePDFPage(_ ref: MKAssetRef) -> CGPDFPage? { nil }
}

enum FakeAssetFactory {
    /// Synthesises a deliberately NON-SQUARE `CGImage` (a two-tone
    /// horizontal/vertical split so cover-crop vs. contain-letterbox math
    /// is actually exercised ، a square-in-square fixture would prove
    /// nothing about aspect-fit correctness) via a small `CGContext` +
    /// `makeImage()`.
    static func nonSquareImage(width: Int = 300, height: Int = 150) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { fatalError("failed to create test CGContext") }
        ctx.setFillColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
        ctx.setFillColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1)
        ctx.fill(CGRect(x: 0, y: height / 2, width: width, height: height - height / 2))
        guard let image = ctx.makeImage() else { fatalError("failed to create test CGImage") }
        return image
    }
}
