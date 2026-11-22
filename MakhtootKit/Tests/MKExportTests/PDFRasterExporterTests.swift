import Testing
import CoreGraphics
import Foundation
@testable import MKExport

// P10-COMPLETION (Run-3, packet §5 task 10). "correct page size in
// Preview; no text objects present."
@Suite struct PDFRasterExporterTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pdfraster-\(UUID().uuidString).pdf")
    }

    private func makeImage(width: Int = 100, height: Int = 100) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(srgbRed: 0.8, green: 0.1, blue: 0.1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    @Test func producesCorrectMediaBoxFromPixelSizeAndDPI() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let image = makeImage()
        // 300 px at 150 DPI = 144 pt.
        try PDFRasterExporter.export(image: image, pixelSize: CGSize(width: 300, height: 300), dpi: 150, title: "T", to: url)
        let document = try #require(CGPDFDocument(url as CFURL))
        let page = try #require(document.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        #expect(abs(box.width - 144) < 0.5)
        #expect(abs(box.height - 144) < 0.5)
    }

    @Test func containsNoTextObjects() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try PDFRasterExporter.export(image: makeImage(), pixelSize: CGSize(width: 100, height: 100), dpi: 72, title: "T", to: url)
        let bytes = try Data(contentsOf: url)
        let text = String(decoding: bytes, as: UTF8.self)
        #expect(!text.contains("/Font"))
        #expect(text.contains("/Image") || text.contains("/XObject"))
    }

    @Test func degenerateSizeThrows() {
        #expect(throws: MKExportError.self) {
            try PDFRasterExporter.export(image: makeImage(), pixelSize: .zero, dpi: 72, title: "T", to: tempURL())
        }
    }
}
