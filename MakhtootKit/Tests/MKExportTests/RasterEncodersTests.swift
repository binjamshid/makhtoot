import Testing
import CoreGraphics
import Foundation
import ImageIO
@testable import MKExport

// WS-08 packet §5 task 9 accept: "correct DPI in Preview/Photos; alpha PNG
// truly transparent (checker test)."
@Suite struct RasterEncodersTests {
    private func makeSolidImage(color: (CGFloat, CGFloat, CGFloat, CGFloat), side: Int = 32) -> CGImage {
        let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: color.3))
        ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        return ctx.makeImage()!
    }

    /// A checkerboard image: opaque red in the top-left quadrant, fully
    /// TRANSPARENT everywhere else ، the exact "checker test" task 9 asks
    /// for.
    private func makeCheckerImage(side: Int = 32) -> CGImage {
        let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // Leave the whole canvas transparent, then fill only the
        // top-left quadrant opaque.
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: side / 2, width: side / 2, height: side / 2))
        return ctx.makeImage()!
    }

    private func tempURL(ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("raster-encoder-test-\(UUID().uuidString).\(ext)")
    }

    private func imageProperties(of url: URL) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }

    @Test func jpegWritesCorrectDPIMetadata() throws {
        let image = makeSolidImage(color: (0.2, 0.4, 0.6, 1))
        let url = tempURL(ext: "jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try MKRasterEncoders.writeJPEG(image, to: url, quality: 0.85, dpi: 300)

        let props = try #require(imageProperties(of: url))
        #expect((props[kCGImagePropertyDPIWidth] as? Double).map { abs($0 - 300) < 0.5 } == true)
        #expect((props[kCGImagePropertyDPIHeight] as? Double).map { abs($0 - 300) < 0.5 } == true)
    }

    @Test func pngWritesCorrectDPIMetadata() throws {
        let image = makeSolidImage(color: (0.1, 0.9, 0.1, 1))
        let url = tempURL(ext: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        try MKRasterEncoders.writePNG(image, to: url, dpi: 72)

        let props = try #require(imageProperties(of: url))
        #expect((props[kCGImagePropertyDPIWidth] as? Double).map { abs($0 - 72) < 0.5 } == true)
    }

    @Test func jpegRoundTripDecodesToTheSameApproximatePixelCount() throws {
        let image = makeSolidImage(color: (0.5, 0.5, 0.5, 1), side: 64)
        let url = tempURL(ext: "jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try MKRasterEncoders.writeJPEG(image, to: url, quality: 0.85, dpi: 72)

        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.width == 64)
        #expect(decoded.height == 64)
    }

    /// The checker test: alpha PNG must round-trip TRUE transparency ، a
    /// pixel outside the painted quadrant decodes back with alpha == 0,
    /// not merely "looks transparent."
    @Test func alphaPNGPreservesTrueTransparency() throws {
        let image = makeCheckerImage(side: 32)
        let url = tempURL(ext: "png")
        defer { try? FileManager.default.removeItem(at: url) }
        try MKRasterEncoders.writePNG(image, to: url, dpi: 72)

        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(decoded.alphaInfo != .none, "PNG must round-trip an alpha channel, not flatten to opaque")

        // Re-render the decoded image into a known RGBA8 buffer so pixel
        // sampling is unambiguous regardless of the source PNG's internal
        // storage format (indexed/8-bit/etc ، ImageIO may re-encode).
        let side = decoded.width
        var buffer = [UInt8](repeating: 0, count: side * side * 4)
        let ctx = buffer.withUnsafeMutableBytes { ptr in
            CGContext(
                data: ptr.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }
        ctx?.draw(decoded, in: CGRect(x: 0, y: 0, width: side, height: side))

        func alpha(x: Int, y: Int) -> UInt8 {
            buffer[(y * side + x) * 4 + 3]
        }
        // Top-right corner (device space, y-up: high y = top) should be
        // fully transparent; the painted quadrant (low x, low y in this
        // CG y-up buffer = bottom-left) should be opaque.
        #expect(alpha(x: side - 1, y: side - 1) == 0, "unpainted region must be fully transparent")
        #expect(alpha(x: 1, y: 1) == 255, "painted quadrant must be fully opaque")
    }

    @Test func writingToAnUnwritableDirectoryThrowsEncodingFailed() {
        let image = makeSolidImage(color: (0, 0, 0, 1))
        let badURL = URL(fileURLWithPath: "/no/such/directory/output.png")
        #expect(throws: MKExportError.encodingFailed) {
            try MKRasterEncoders.writePNG(image, to: badURL, dpi: 72)
        }
    }
}
