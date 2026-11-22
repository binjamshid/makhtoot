package net.binjamshid.makhtoot.mk.nativebridge

/**
 * D-303's FreeType-outline entry point, independent of [MkShaper] — this
 * facade never links HarfBuzz against FreeType (`HB_HAVE_FREETYPE OFF` in
 * `CMakeLists.txt`); a glyph id produced by [MkShaper.shape] is handed to
 * [outline] separately, exactly as `CTFontCreatePathForGlyph` is called
 * downstream of `CTLine` capture on iOS.
 *
 * [font] is borrowed, not owned — same contract as [MkShaper].
 */
public class MkGlyphOutliner(private val font: MkFontBlob, private val faceIndex: Int = 0) {

    /** Returns `null` if [glyphId] has no vector outline (see [MkGlyphOutline]'s KDoc). */
    public fun outline(glyphId: Int, fontSizePx: Float): MkGlyphOutline? {
        val pathHandle = MkNative.nativeGlyphOutline(font.rawHandle(), faceIndex, glyphId, fontSizePx)
        if (pathHandle == 0L) return null
        try {
            val verbs = MkNative.nativeOutlineVerbs(pathHandle)
            val points = MkNative.nativeOutlinePoints(pathHandle)
            val advance = MkNative.nativeOutlineAdvance(pathHandle)
            return MkGlyphOutline(verbs, points, advance)
        } finally {
            MkNative.nativeOutlineDestroy(pathHandle)
        }
    }
}
