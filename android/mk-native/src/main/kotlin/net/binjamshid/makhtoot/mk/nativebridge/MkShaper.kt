package net.binjamshid.makhtoot.mk.nativebridge

/**
 * The D-303 shaping entry point: one `hb_shape` call per [shape] invocation,
 * result extracted eagerly into [MkShapedGlyphs] so the native shape-result
 * handle never escapes this method (see [MkNative]'s handle-lifetime
 * contract KDoc). This is the Android analogue of
 * `MakhtootKit/Sources/MKTextEngine/MKShapingEngine.swift`'s capture core —
 * a thin bridge only, no shaping policy.
 *
 * [font] is borrowed, not owned: callers are responsible for the
 * [MkFontBlob]'s lifetime (typically one blob shared across many [shape]
 * calls for the same font).
 */
public class MkShaper(private val font: MkFontBlob, private val faceIndex: Int = 0) {

    /**
     * @param text the run's text (UTF-16, i.e. a plain Kotlin [String]).
     * @param script an ISO 15924 tag, e.g. `"Arab"`; empty string lets
     *   HarfBuzz guess from the text (`hb_buffer_guess_segment_properties`).
     * @param language a BCP 47 tag, e.g. `"ar"`; empty string lets HarfBuzz guess.
     * @param direction [MkShapeDirection.RTL] for Arabic (D-303).
     * @param features comma-separated `hb_feature_t` strings, e.g.
     *   `"liga=1,calt=0"` (D-108's feature-application seam); empty string
     *   for the font's default feature set.
     * @param fontSizePx the point size to shape at, in pixels — controls the
     *   26.6 fixed-point scale HarfBuzz positions are converted from (see
     *   `mk_shaping.cpp`'s `kFixedPointShift`), not merely a cosmetic value.
     */
    public fun shape(
        text: String,
        script: String = "",
        language: String = "",
        direction: MkShapeDirection = MkShapeDirection.RTL,
        features: String = "",
        fontSizePx: Float,
    ): MkShapedGlyphs {
        val resultHandle = MkNative.nativeShape(
            font.rawHandle(), faceIndex, text, script, language, direction.nativeValue,
            features, fontSizePx,
        )
        check(resultHandle != 0L) { "MkNative.nativeShape failed for text of length ${text.length}" }
        try {
            val glyphCount = MkNative.nativeShapeGlyphCount(resultHandle)
            val glyphIds = MkNative.nativeShapeGlyphIds(resultHandle)
            val clusters = MkNative.nativeShapeClusters(resultHandle)
            val advances = MkNative.nativeShapeAdvances(resultHandle) // interleaved x,y
            val offsets = MkNative.nativeShapeOffsets(resultHandle) // interleaved x,y
            val isRtl = MkNative.nativeShapeIsRtl(resultHandle)

            val xAdvances = FloatArray(glyphCount)
            val yAdvances = FloatArray(glyphCount)
            val xOffsets = FloatArray(glyphCount)
            val yOffsets = FloatArray(glyphCount)
            for (i in 0 until glyphCount) {
                xAdvances[i] = advances[2 * i]
                yAdvances[i] = advances[2 * i + 1]
                xOffsets[i] = offsets[2 * i]
                yOffsets[i] = offsets[2 * i + 1]
            }

            return MkShapedGlyphs(glyphIds, clusters, xAdvances, yAdvances, xOffsets, yOffsets, isRtl)
        } finally {
            MkNative.nativeShapeDestroy(resultHandle)
        }
    }
}
