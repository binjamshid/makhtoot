package net.binjamshid.makhtoot.mk.color

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * Placeholder for `CGColorRenderingIntent`. Ports the four ICC rendering
 * intents `MKCmykConverter`'s public API references.
 */
enum class MkColorRenderingIntent {
    Perceptual,
    RelativeColorimetric,
    Saturation,
    AbsoluteColorimetric,
}

/**
 * sRGB -> CMYK conversion (D-226 tightens D-117: relative colorimetric is
 * EXPLICIT at every call site, never a default). Ports
 * `Sources/MKColor/CMYKConverter.swift`.
 *
 * Android's real implementation (Batch 2) is expected to route through
 * lcms2 via the `:mk-native` NDK facade (D-315) rather than CoreGraphics'
 * `CGColor.converted(to:intent:options:)`.
 */
object MkCmykConverter {
    /** The one call every whole-image / per-swatch CMYK conversion in this module goes through. */
    val intent: MkColorRenderingIntent = MkColorRenderingIntent.RelativeColorimetric

    /** Converts one [MkColorSpec] (extended sRGB) to CMYK components `[C, M, Y, K]` against [profile]. */
    fun cmyk(color: MkColorSpec, profile: MkIccProfile): DoubleArray? =
        throw MkNotYetPorted("MkCmykConverter.cmyk")

    /** Batch conversion for the scene palette — de-duplicates identical colors. */
    fun cmykPalette(colors: List<MkColorSpec>, profile: MkIccProfile): Map<MkColorSpec, DoubleArray> =
        throw MkNotYetPorted("MkCmykConverter.cmykPalette")

    /**
     * The `.perceptual`-intent conversion of the SAME color/profile pair — exists only for
     * intent-divergence test fixtures (D-226(3)/(5)). Never used by any production export path.
     */
    fun cmykPerceptual(color: MkColorSpec, profile: MkIccProfile): DoubleArray? =
        throw MkNotYetPorted("MkCmykConverter.cmykPerceptual")

    /** Converts a whole raster image (the raster-asset / whole-page path, D-226(5)) into a CMYK bitmap. */
    fun convertWholeImage(image: MkPlatformImage, profile: MkIccProfile): MkPlatformImage? =
        throw MkNotYetPorted("MkCmykConverter.convertWholeImage")
}
