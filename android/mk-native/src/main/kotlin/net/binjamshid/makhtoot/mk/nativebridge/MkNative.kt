package net.binjamshid.makhtoot.mk.nativebridge

import android.content.res.AssetManager

/**
 * Batch 1 · Agent 1.2 (D-303/D-304/D-315/D-316) — the raw `external fun`
 * surface of the single JNI facade `libmknative.so`.
 *
 * This object is **package-internal on purpose**: nothing outside
 * `nativebridge` should call these functions directly, because several of
 * them hand back an opaque native handle ([Long]) that must be destroyed
 * exactly once. The safe, [java.io.Closeable]-based wrapper layer in this
 * same package ([MkFontBlob], [MkShaper], [MkGlyphOutliner],
 * [MkFontSubsetter], [MkIccTransform]) is the only supported entry point for
 * every other module (`:mk-textengine`, `:mk-render`, `:mk-export`,
 * `:mk-fonts`, `:mk-color` per `ANDROID_SPINE.md` §3.2's `:mk-native`
 * dependency edge).
 *
 * D-303: HarfBuzz `hb_shape` (GSUB/GPOS) + FreeType (outlines). ICU BiDi is
 * consumed from the platform (`android.icu`, API 24+) by whichever Batch 3
 * module needs paragraph/run levels — it is never linked into this native
 * facade (see `CMakeLists.txt`'s `HB_HAVE_ICU OFF`). **Never write a shaper,
 * never use presentation-form codepoints** — this object only marshals
 * primitive arrays across the JNI boundary; every shaping/joining/ligature/
 * mark-classification *policy* decision is Kotlin's job downstream in
 * `:mk-textengine` (Batch 3), mirroring how `MKShapingEngine.swift` only
 * captures `CTLine`/`CTRun` output rather than deciding shaping outcomes
 * itself.
 *
 * Handle lifetime contract (spot-checked per type in
 * `android/docs/impl-log/BATCH-1.2.md`):
 *  - Blob handles (`nativeBlobCreate*`) live as long as [MkFontBlob] is open;
 *    freed by `nativeBlobDestroy`.
 *  - Shape-result handles (`nativeShape`) are created and destroyed within a
 *    single [MkShaper.shape] call — never exposed outside this package.
 *  - Outline-path handles (`nativeGlyphOutline`) are created and destroyed
 *    within a single [MkGlyphOutliner.outline] call — same rule.
 */
internal object MkNative {

    init {
        System.loadLibrary("mknative")
    }

    // -------------------------------------------------------------------
    // Blob lifetime (D-316: AssetManager fd -> hb_blob_t, no extraction to
    // disk, no OS-level font registration needed).
    // -------------------------------------------------------------------

    /** Copies [bytes] into a native buffer and wraps it as an `hb_blob_t`. */
    external fun nativeBlobCreate(bytes: ByteArray): Long

    /**
     * Opens `path` (relative to `assets/`, e.g. `fonts/Cairo/Cairo[slnt,wght].ttf`
     * per D-316) via [assetManager]. Tries a zero-copy `fd`+`mmap` path first
     * (works when the asset is stored uncompressed — Agent 1.1's
     * `aaptOptions.noCompress` concern for `*.ttf`); falls back to
     * `AAsset_getBuffer` (still no disk write) if the asset is compressed.
     */
    external fun nativeBlobCreateFromAsset(assetManager: AssetManager, path: String): Long

    /** Destroys a handle from either `nativeBlobCreate*` variant. Idempotent misuse is the caller's job to prevent — call exactly once. */
    external fun nativeBlobDestroy(handle: Long)

    external fun nativeBlobFaceCount(handle: Long): Int

    /** `hb_face_reference_table` — returns `null` if the font has no such table. */
    external fun nativeGetTable(handle: Long, faceIndex: Int, tag: String): ByteArray?

    // -------------------------------------------------------------------
    // Shaping (D-303: hb_shape for GSUB/GPOS). direction: 0 = LTR, 1 = RTL
    // (see MkShapeDirection). Returns an opaque result handle, 0 on failure.
    // -------------------------------------------------------------------

    external fun nativeShape(
        blobHandle: Long,
        faceIndex: Int,
        text: String,
        script: String,
        language: String,
        direction: Int,
        features: String,
        fontSizePx: Float,
    ): Long

    external fun nativeShapeGlyphCount(resultHandle: Long): Int
    external fun nativeShapeGlyphIds(resultHandle: Long): IntArray
    external fun nativeShapeClusters(resultHandle: Long): IntArray

    /** Interleaved x,y pairs in pixels — length `2 * glyphCount`. */
    external fun nativeShapeAdvances(resultHandle: Long): FloatArray

    /** Interleaved x,y pairs in pixels — length `2 * glyphCount`. */
    external fun nativeShapeOffsets(resultHandle: Long): FloatArray
    external fun nativeShapeIsRtl(resultHandle: Long): Boolean
    external fun nativeShapeDestroy(resultHandle: Long)

    // -------------------------------------------------------------------
    // Outline extraction (D-303: FreeType for outlines). Returns an opaque
    // path handle, 0 on failure (including "this glyph has no vector
    // outline", e.g. a bitmap-only COLR/CBDT glyph outside the v1 bundled
    // catalog — not a shaping-delta case, see mk_outline.cpp).
    // -------------------------------------------------------------------

    external fun nativeGlyphOutline(
        blobHandle: Long,
        faceIndex: Int,
        glyphId: Int,
        fontSizePx: Float,
    ): Long

    /** Verb codes: 0=moveTo 1=lineTo 2=quadTo 3=cubicTo 4=close — see [MkOutlineVerb]. */
    external fun nativeOutlineVerbs(pathHandle: Long): IntArray

    /** Flattened x,y pairs, in verb order (2 floats/point, 4 for quadTo, 6 for cubicTo). */
    external fun nativeOutlinePoints(pathHandle: Long): FloatArray
    external fun nativeOutlineAdvance(pathHandle: Long): Float
    external fun nativeOutlineDestroy(pathHandle: Long)

    // -------------------------------------------------------------------
    // Subsetting (hb-subset, D-304) — feeds Batch 5.7b's PDF font embedding.
    // -------------------------------------------------------------------

    /** Returns a subsetted sfnt blob retaining exactly [unicodes], or `null` on failure. */
    external fun nativeSubset(blobHandle: Long, faceIndex: Int, unicodes: IntArray): ByteArray?

    // -------------------------------------------------------------------
    // ICC transform (lcms2, D-315). This facade exposes the transform
    // primitive only; the synthetic-generic-CMYK profile bytes (FDA-03) are
    // supplied by a later batch (ANDROID_SPINE.md §2 D-315 substitution
    // table: 2.3/5.7b), never baked into this native layer.
    // -------------------------------------------------------------------

    /** Synthesizes an sRGB ICC profile in-process (`cmsCreate_sRGBProfile`) — no asset needed. */
    external fun nativeCreateSrgbProfile(): ByteArray?

    /**
     * `cmsCreateTransform` + `cmsDoTransform`. [srcValues] is packed per the
     * input profile's channel count (e.g. 3 floats/pixel for RGB, 4 for
     * CMYK); the return array is packed per the output profile's channel
     * count. `null` on failure (unreadable profile, transform creation
     * failure).
     */
    external fun nativeIccTransform(
        inputProfile: ByteArray,
        outputProfile: ByteArray,
        srcValues: FloatArray,
        intent: Int,
    ): FloatArray?
}
