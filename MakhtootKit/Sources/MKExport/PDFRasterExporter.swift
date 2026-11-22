import CoreGraphics
import Foundation

// P10-COMPLETION (Run-3, packet §5 task 10). "Rasterized PDF (free): single
// page CG PDF context at preset pt size embedding the ≤2 MP raster."
// *Accept*: "correct page size in Preview; no text objects present." Reuses
// the SAME raster this session's JPEG/PNG writers already produce
// (`MKTiledRasterExporter.renderAssembled`, called by `ExportCoordinator`
// before dispatching to this file) ، this file's only job is wrapping an
// already-rendered `CGImage` into a one-page PDF, never re-rendering.
public enum PDFRasterExporter {
    /// `pixelSize` is the ALREADY free-tier-clamped size (`ExportGate`'s
    /// resolved size); `dpi` drives the pt-size media box math (task 10's
    /// "preset pt size" ، `points = pixels / dpi * 72`, same conversion
    /// `ExportPresets`'/task 7's pt↔px math uses elsewhere).
    public static func export(image: CGImage, pixelSize: CGSize, dpi: Double, title: String, to url: URL) throws {
        let effectiveDPI = dpi > 0 ? dpi : 72
        var mediaBox = CGRect(
            x: 0, y: 0,
            width: pixelSize.width / effectiveDPI * 72.0,
            height: pixelSize.height / effectiveDPI * 72.0
        )
        guard mediaBox.width > 0, mediaBox.height > 0 else { throw MKExportError.degenerateTargetSize }

        let aux = PDFOutputIntent.plainAuxiliaryInfo(title: title)
        guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, aux) else {
            throw MKExportError.encodingFailed
        }
        ctx.beginPDFPage(nil)
        // Image XObject fills the whole page ، no vector/text content at
        // all (task 10 accept: "no text objects present").
        ctx.draw(image, in: CGRect(origin: .zero, size: mediaBox.size))
        ctx.endPDFPage()
        ctx.closePDF()
    }
}
