import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// WS-08 packet §5 task 9. "ImageIO destinations with DPI metadata
// (kCGImagePropertyDPIWidth/Height), JPEG quality 0.85 default, opaque PNG
// composites canvas background, alpha PNG renders clear background
// (premium only)." The background-composite-vs-clear decision is made by
// the CALLER (`ExportCoordinator`, via which scene copy it hands to
// `MKTiledRasterExporter` ، see that file's/`ExportCoordinator.swift`'s
// header) ، this file only encodes an already-correctly-composed `CGImage`
// to bytes.
public enum MKRasterEncoders {
    /// sRGB tag written into the output file's color profile metadata
    /// (§15.4: "profile embedded, kCGImagePropertyProfileName sRGB").
    /// A lightweight ImageIO metadata write, not a pixel resample ، safe to
    /// apply even to an already-huge assembled image (task 8's memory
    /// budget is not reopened by this step).
    static let srgbProfileName = "sRGB IEC61966-2.1"

    public static func writeJPEG(_ image: CGImage, to url: URL, quality: Double, dpi: Double) throws {
        try write(image, to: url, utType: .jpeg, dpi: dpi, extraProperties: [
            kCGImageDestinationLossyCompressionQuality: max(0, min(1, quality)),
        ])
    }

    /// PNG is lossless ، `alphaPreserving` controls whether the encoded
    /// image keeps its (already-rendered) alpha channel meaningful
    /// (`pngAlpha`, premium) or is treated as fully opaque for metadata
    /// purposes (`pngOpaque` ، the pixels are already opaque because the
    /// renderer composited the canvas background; this flag exists only
    /// for callers/tests that want to assert intent, ImageIO itself
    /// encodes whatever alpha bytes are actually in `image`).
    public static func writePNG(_ image: CGImage, to url: URL, dpi: Double) throws {
        try write(image, to: url, utType: .png, dpi: dpi, extraProperties: [:])
    }

    private static func write(
        _ image: CGImage, to url: URL, utType: UTType, dpi: Double, extraProperties: [CFString: Any]
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, utType.identifier as CFString, 1, nil) else {
            throw MKExportError.encodingFailed
        }
        var properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
            kCGImagePropertyProfileName: srgbProfileName,
        ]
        for (key, value) in extraProperties { properties[key] = value }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MKExportError.encodingFailed
        }
    }
}
