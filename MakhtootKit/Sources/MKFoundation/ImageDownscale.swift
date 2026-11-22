import CoreGraphics
import Foundation
import ImageIO

// P5.3 (background-image ingest). Pure `CoreGraphics`/`ImageIO` bitmap
// downscale ، deliberately NOT UIKit-based (`UIImage`/
// `UIGraphicsImageRenderer`, this type's first draft, caught in review):
// this repo's `swift test` verification runs on the macOS HOST directly
// (`cd MakhtootKit && swift test --filter ...`), and `MKFoundation`
// supports `.macOS(.v14)` alongside `.iOS(.v18)` per `Package.swift` ،
// UIKit does not exist there. Living in the app target (UIKit-based) would
// make this logic untestable by `swift test` at all (no XCTest/Testing
// bundle exists for the `Makhtoot` app target either), so it moved here:
// cross-platform, and reachable by `MKFoundationTests`.
public enum MKImageDownscale {
    /// Decodes `data`, downscales (never upscales) so its pixel dimensions
    /// fit within `maxPixelSize` while preserving aspect ratio, and
    /// re-encodes as PNG. Always PNG, even when no resize was needed ،
    /// preserves any alpha channel intact (a JPEG re-save would silently
    /// flatten transparency, undermining P5.4's "present alpha honestly"
    /// the moment a transparent PNG was the very thing ingested). Returns
    /// `nil` only when `data` cannot be decoded as an image at all.
    ///
    /// Bug fix (2026-07-29, user report: "importing a photo makes it
    /// flipped upside-down"): `CGImageSourceCreateImageAtIndex` decodes
    /// the RAW pixel grid only ، it does not consult or apply the
    /// `kCGImagePropertyOrientation` EXIF/TIFF tag every photo captured
    /// with the device rotated (the overwhelming majority of real photos)
    /// carries. The re-encoded PNG this function produces carries no
    /// orientation tag of its own (plain `CGImageDestinationAddImage` with
    /// no properties dict), and nothing downstream in this Core-Graphics-
    /// only render pipeline consults one either ، so the orientation
    /// correction must be baked into the actual pixel data here, once,
    /// or it is lost permanently. `correctedForOrientation` below does
    /// exactly that before the existing downscale logic runs.
    public static func downscaledPNG(_ data: Data, maxPixelSize: CGSize) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }

        let image = correctedForOrientation(decoded, source: source)

        let pixelSize = CGSize(width: image.width, height: image.height)
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }

        guard pixelSize.width > maxPixelSize.width || pixelSize.height > maxPixelSize.height else {
            // Already within budget ، still re-encoded as PNG (see doc
            // comment: normalizes to the alpha-preserving path
            // unconditionally, no "return original bytes" special case).
            return encodePNG(image)
        }

        let scale = min(maxPixelSize.width / pixelSize.width, maxPixelSize.height / pixelSize.height)
        let targetWidth = max(1, Int((pixelSize.width * scale).rounded(.down)))
        let targetHeight = max(1, Int((pixelSize.height * scale).rounded(.down)))

        guard let context = CGContext(
            data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return encodePNG(image)
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let resized = context.makeImage() else { return encodePNG(image) }
        return encodePNG(resized)
    }

    /// Reads `kCGImagePropertyOrientation` from `source`'s metadata and, if
    /// it is anything other than `.up` (the identity case ، the vast
    /// majority of non-camera-sourced images, and the only case the
    /// pre-fix code implicitly assumed), redraws `image` into a freshly
    /// oriented bitmap so its pixel data alone is correct with no
    /// orientation tag required to interpret it. Returns `image` itself,
    /// untouched, for `.up` or when no orientation property is present
    /// (e.g. a screenshot or a PNG with no EXIF block at all) ، the common
    /// case, so this adds no redraw cost for images that don't need one.
    private static func correctedForOrientation(_ image: CGImage, source: CGImageSource) -> CGImage {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let rawOrientation = properties[kCGImagePropertyOrientation] as? UInt32,
            let orientation = CGImagePropertyOrientation(rawValue: rawOrientation),
            orientation != .up
        else { return image }

        let srcWidth = CGFloat(image.width)
        let srcHeight = CGFloat(image.height)
        let swapsDimensions: Bool
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored: swapsDimensions = true
        default: swapsDimensions = false
        }
        let outWidth = Int(swapsDimensions ? srcHeight : srcWidth)
        let outHeight = Int(swapsDimensions ? srcWidth : srcHeight)
        guard outWidth > 0, outHeight > 0 else { return image }

        guard let context = CGContext(
            data: nil, width: outWidth, height: outHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        // Standard EXIF-orientation-to-transform derivation: rotate first
        // (the four orientations that are 90°/270°-rotated, vs. the two
        // that are only 180°-rotated), then mirror (the four "Mirrored"
        // cases) ، composed in image-local coordinates (0...srcWidth,
        // 0...srcHeight) so the subsequent draw of the ORIGINAL,
        // uncorrected `image` at its own native size lands correctly once
        // this transform is applied to the context's CTM.
        var transform = CGAffineTransform.identity
        switch orientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: srcWidth, y: srcHeight).rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: srcHeight, y: 0).rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: srcWidth).rotated(by: -.pi / 2)
        case .up, .upMirrored:
            break
        }
        // The rotate step above has already mapped INTO the source image's
        // own frame (that is the whole point of it ، the draw below hands
        // over `CGRect(0, 0, srcWidth, srcHeight)`), so the reflection and
        // the translation that brings the reflected content back into
        // frame are both expressed in SOURCE units: always `srcWidth`,
        // for the rotated `*Mirrored` cases exactly as much as the
        // unrotated ones. (`srcHeight` here was a transcription slip from
        // Apple's `UIImage`-based derivation, where the same expression is
        // written `size.height` because `UIImage.size` is the already-
        // swapped DISPLAY size for `.left`/`.right`. It mirrored EXIF 5/7
        // about the wrong axis.)
        switch orientation {
        case .upMirrored, .downMirrored, .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: srcWidth, y: 0).scaledBy(x: -1, y: 1)
        default:
            break
        }

        context.concatenate(transform)
        context.draw(image, in: CGRect(x: 0, y: 0, width: srcWidth, height: srcHeight))
        return context.makeImage() ?? image
    }

    private static func encodePNG(_ image: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
