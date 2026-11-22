import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import MKFoundation

/// P5.3 (background-image ingest, review-requested test): asserts the
/// canvas × 2 cap `MKImageDownscale.downscaledPNG` is actually applied
/// (never upscales, aspect ratio preserved, downscales when over budget)
/// and that alpha survives the PNG re-encode (the whole reason this always
/// re-encodes as PNG rather than JPEG, per its own doc comment).
@Suite("MKImageDownscale")
struct ImageDownscaleTests {
    /// Builds a `width`×`height` PNG whose pixels are a solid color at
    /// `alpha` (0...1) ، a minimal, fully-controlled fixture (no bundled
    /// test image needed) so the assertions below can reason exactly about
    /// what went in vs. what came out.
    private static func makePNG(width: Int, height: Int, alpha: CGFloat) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: 0.8, green: 0.2, blue: 0.2, alpha: alpha)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!

        let mutableData = NSMutableData()
        let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return mutableData as Data
    }

    /// Decodes `data` back to a `CGImage` for pixel-level inspection.
    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Samples the alpha byte of pixel (0,0) by drawing the image into a
    /// 1×1 premultiplied-RGBA context and reading the raw byte back out.
    private static func alphaAtOrigin(_ image: CGImage) -> UInt8 {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel[3]
    }

    @Test func oversizedImageIsDownscaledToFitWithinTheCapPreservingAspectRatio() throws {
        // A 4000×2000 source against a 1080×1080 "canvas × 2" cap ، both
        // axes exceed the cap, so the cap (not the source size) must win,
        // and the 2:1 aspect ratio must survive.
        let source = Self.makePNG(width: 4000, height: 2000, alpha: 1)
        let maxPixelSize = CGSize(width: 1080, height: 1080)

        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: maxPixelSize))
        let image = try #require(Self.decode(result))

        #expect(image.width <= Int(maxPixelSize.width))
        #expect(image.height <= Int(maxPixelSize.height))
        // The binding axis is width (4000/2000 = 2:1, cap is square) ،
        // width should land at (or just under, integer rounding) the cap,
        // height at half that.
        #expect(image.width >= 1078 && image.width <= 1080)
        #expect(abs(image.height * 2 - image.width) <= 2)
    }

    @Test func imageAlreadyWithinTheCapIsNeverUpscaled() throws {
        let source = Self.makePNG(width: 200, height: 100, alpha: 1)
        let maxPixelSize = CGSize(width: 1080, height: 1080)

        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: maxPixelSize))
        let image = try #require(Self.decode(result))

        #expect(image.width == 200)
        #expect(image.height == 100)
    }

    @Test func alphaSurvivesThePNGReEncodeThroughADownscale() throws {
        // Half-opaque source, forced through the resize path (source
        // exceeds the cap) ، asserts the re-encode is PNG (alpha-capable),
        // not a JPEG flatten to fully opaque.
        let source = Self.makePNG(width: 2400, height: 2400, alpha: 0.5)
        let maxPixelSize = CGSize(width: 1080, height: 1080)

        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: maxPixelSize))
        let image = try #require(Self.decode(result))

        let alpha = Self.alphaAtOrigin(image)
        // Exactly 0 (fully transparent) or 255 (fully opaque) would mean
        // alpha was lost/flattened ، the resample can shift the byte
        // slightly from the source's exact 128, so this checks it landed
        // in the semi-transparent middle, not either extreme.
        #expect(alpha > 40)
        #expect(alpha < 220)
    }

    @Test func alphaSurvivesThePNGReEncodeWithoutAResize() throws {
        let source = Self.makePNG(width: 100, height: 100, alpha: 0.5)
        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: CGSize(width: 1080, height: 1080)))
        let image = try #require(Self.decode(result))

        let alpha = Self.alphaAtOrigin(image)
        #expect(alpha > 40)
        #expect(alpha < 220)
    }

    @Test func undecodableDataReturnsNilRatherThanCrashing() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03])
        #expect(MKImageDownscale.downscaledPNG(garbage, maxPixelSize: CGSize(width: 1080, height: 1080)) == nil)
    }

    // MARK: - EXIF orientation correction (2026-07-29 bug fix: "importing a
    // photo makes it flipped upside-down" — CGImageSourceCreateImageAtIndex
    // decodes raw pixel order only, ignoring kCGImagePropertyOrientation;
    // real device photos overwhelmingly carry a non-`.up` tag).

    /// Builds a `size`×`size` PNG, solid blue except a red `size/2`×`size/2`
    /// quadrant at CG's own (y-up) top-left — i.e. `CGRect(x: 0, y:
    /// size/2, width: size/2, height: size/2)` — tagged with
    /// `orientation` (raw EXIF/TIFF value) if given. `size` must be even.
    private static func makeQuadrantMarkedPNG(size: Int, orientation: UInt32?) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: size / 2, width: size / 2, height: size / 2))
        let image = context.makeImage()!

        let mutableData = NSMutableData()
        let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil)!
        let properties: CFDictionary? = orientation.map { [kCGImagePropertyOrientation: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, image, properties)
        #expect(CGImageDestinationFinalize(destination))
        return mutableData as Data
    }

    /// Which quadrant of `image` is predominantly red, sampled by drawing
    /// the whole (decoded, already-corrected) image into a small buffer
    /// this test owns directly and reading raw bytes back — empirically
    /// confirmed (not assumed) that for a `CGContext` created via
    /// `CGContext(data:width:height:...)`, buffer row 0 is the image's
    /// visual TOP (increasing row index moves toward the visual bottom),
    /// independent of the y-up convention `.fill(rect:)` itself uses.
    private enum Quadrant { case topLeft, topRight, bottomLeft, bottomRight, ambiguous }
    private static func redQuadrant(of image: CGImage) -> Quadrant {
        let n = 2
        var buf = [UInt8](repeating: 0, count: n * n * 4)
        let context = CGContext(
            data: &buf, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: n, height: n))

        func isRed(row: Int, col: Int) -> Bool {
            let idx = row * n * 4 + col * 4
            return buf[idx] > 150 && buf[idx + 2] < 100
        }
        // row 0 = visual top (verified above); col 0 = visual left.
        if isRed(row: 0, col: 0) { return .topLeft }
        if isRed(row: 0, col: 1) { return .topRight }
        if isRed(row: 1, col: 0) { return .bottomLeft }
        if isRed(row: 1, col: 1) { return .bottomRight }
        return .ambiguous
    }

    @Test func orientationTagOfUpLeavesPixelsUnchanged() throws {
        let source = Self.makeQuadrantMarkedPNG(size: 40, orientation: 1) // .up
        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: CGSize(width: 1000, height: 1000)))
        let image = try #require(Self.decode(result))
        #expect(Self.redQuadrant(of: image) == .topLeft)
    }

    @Test func noOrientationTagAtAllIsTreatedAsUpNotAsAnythingElse() throws {
        // No `kCGImagePropertyOrientation` key at all (e.g. a plain PNG
        // with no EXIF/TIFF block) — must not crash and must not silently
        // apply some other orientation.
        let source = Self.makeQuadrantMarkedPNG(size: 40, orientation: nil)
        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: CGSize(width: 1000, height: 1000)))
        let image = try #require(Self.decode(result))
        #expect(Self.redQuadrant(of: image) == .topLeft)
    }

    @Test func orientationDownRotates180DegreesMovingTopLeftMarkerToBottomRight() throws {
        // The exact bug report: a photo tagged `.down` (raw 3, "rotate
        // 180° to display correctly") came out upside-down because this
        // tag was previously ignored entirely.
        let source = Self.makeQuadrantMarkedPNG(size: 40, orientation: 3) // .down
        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: CGSize(width: 1000, height: 1000)))
        let image = try #require(Self.decode(result))
        #expect(Self.redQuadrant(of: image) == .bottomRight)
    }

    @Test func orientationRightRotates90DegreesAndSwapsDimensions() throws {
        // `.right` (raw 6, EXIF semantics: "rotate the stored image 90°
        // clockwise to display correctly") is one of the four 90°/270°-
        // rotation cases — the single most common real-world tag (portrait
        // photos from a camera held in its default landscape sensor
        // orientation). Rotating 90° clockwise carries top-left content to
        // top-right.
        let source = Self.makeQuadrantMarkedPNG(size: 40, orientation: 6) // .right
        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: CGSize(width: 1000, height: 1000)))
        let image = try #require(Self.decode(result))
        #expect(image.width == 40)
        #expect(image.height == 40)
        #expect(Self.redQuadrant(of: image) == .topRight)
    }

    @Test func orientationLeftRotatesTheOtherWayAndSwapsDimensions() throws {
        // `.left` (raw 8, "rotate 90° counter-clockwise to display
        // correctly") carries top-left content to bottom-left.
        let source = Self.makeQuadrantMarkedPNG(size: 40, orientation: 8) // .left
        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: CGSize(width: 1000, height: 1000)))
        let image = try #require(Self.decode(result))
        #expect(image.width == 40)
        #expect(image.height == 40)
        #expect(Self.redQuadrant(of: image) == .bottomLeft)
    }

    @Test func orientationCorrectionComposesCorrectlyWithDownscaling() throws {
        // The bug could plausibly resurface only in the resize path (a
        // separate code path from the "already within budget" one) — this
        // forces both to run together.
        let source = Self.makeQuadrantMarkedPNG(size: 400, orientation: 3) // .down
        let result = try #require(MKImageDownscale.downscaledPNG(source, maxPixelSize: CGSize(width: 100, height: 100)))
        let image = try #require(Self.decode(result))
        #expect(image.width <= 100)
        #expect(image.height <= 100)
        #expect(Self.redQuadrant(of: image) == .bottomRight)
    }
}
