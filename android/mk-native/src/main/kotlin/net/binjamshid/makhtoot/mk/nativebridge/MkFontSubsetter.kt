package net.binjamshid.makhtoot.mk.nativebridge

/**
 * `hb-subset` facade (D-303/D-304) — feeds Batch 5.7b's in-house PDF writer
 * (D-314): a PDF embedding live Arabic text needs a Type0/CIDFontType2
 * subset containing only the glyphs actually used, not the full bundled
 * font. This object only exposes the subsetting primitive; the
 * CID-mapping/Type0-embedding policy belongs to 5.7b, not this facade.
 */
public object MkFontSubsetter {

    /**
     * Returns a subsetted `sfnt` blob retaining exactly the glyphs needed
     * for [unicodes] (plus whatever `hb-subset` includes by default, e.g.
     * `.notdef`/required tables), or `null` on failure. Note: `hb-subset`
     * remaps glyph ids by default (no `RETAIN_GIDS` flag is set here) — a
     * subsetted font's glyph ids are **not** the same as the source font's.
     */
    public fun subset(font: MkFontBlob, unicodes: IntArray, faceIndex: Int = 0): ByteArray? =
        MkNative.nativeSubset(font.rawHandle(), faceIndex, unicodes)
}
