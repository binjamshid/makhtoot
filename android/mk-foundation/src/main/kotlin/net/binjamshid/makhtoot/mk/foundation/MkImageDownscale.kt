package net.binjamshid.makhtoot.mk.foundation

/**
 * Ports `Sources/MKFoundation/ImageDownscale.swift` (P5.3 background-image ingest).
 * Swift's implementation is deliberately Core Graphics/ImageIO-based, never
 * UIKit-based; Android's real implementation (Batch 2) is expected to use
 * `android.graphics.BitmapFactory`/`Bitmap` directly, preserving the same
 * "never upscale, always re-encode PNG, always correct EXIF orientation"
 * contract documented on the Swift source.
 */
object MkImageDownscale {
    /**
     * Decodes [data], downscales (never upscales) so its pixel dimensions fit
     * within [maxPixelSize] while preserving aspect ratio, and re-encodes as
     * PNG. Returns `null` only when [data] cannot be decoded as an image at all.
     */
    fun downscaledPNG(data: ByteArray, maxPixelSize: net.binjamshid.makhtoot.mk.foundation.geometry.MkSize): ByteArray? =
        throw MkNotYetPorted("MkImageDownscale.downscaledPNG")
}
