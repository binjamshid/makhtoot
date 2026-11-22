package net.binjamshid.makhtoot.mk.nativebridge

/**
 * Path-verb encoding produced by [MkGlyphOutliner.outline] / consumed from
 * [MkGlyphOutline.verbs]. Matches `mk_native.h`'s `MkOutlinePath` comment
 * and `FT_Outline_Decompose`'s callback shape 1:1 (D-303's FreeType half —
 * the Android replacement for `CTFontCreatePathForGlyph`/
 * `GlyphPathProvider.swift`).
 */
public enum class MkOutlineVerb(public val nativeValue: Int, public val pointCount: Int) {
    MOVE_TO(0, 1),
    LINE_TO(1, 1),
    QUAD_TO(2, 2),
    CUBIC_TO(3, 3),
    CLOSE(4, 0),
    ;

    public companion object {
        public fun fromNativeValue(value: Int): MkOutlineVerb =
            entries.firstOrNull { it.nativeValue == value }
                ?: error("Unknown MkOutlineVerb native value: $value")
    }
}
