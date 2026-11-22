package net.binjamshid.makhtoot.mk.nativebridge

/**
 * lcms2 ICC transform facade (D-315) — the Android replacement for
 * `CGColorSpace(iccData:)`. This object exposes the transform primitive
 * only; the actual synthetic-generic-CMYK profile bytes (FDA-03) are a
 * later batch's concern (`ANDROID_SPINE.md` §2 D-315 platform-substitution
 * table: 2.3/5.7b) — this facade does not bake in any particular CMYK
 * profile, and stays agnostic to which two profiles a caller supplies.
 */
public object MkIccTransform {

    /**
     * Synthesizes an sRGB ICC profile in-process (`cmsCreate_sRGBProfile` +
     * `cmsSaveProfileToMem`) — the extended-sRGB working space (D-315) never
     * has to ship as a bundled asset. Returns `null` only on an
     * out-of-memory-class lcms2 failure.
     */
    public fun createSrgbProfile(): ByteArray? = MkNative.nativeCreateSrgbProfile()

    /**
     * @param inputProfile ICC profile bytes for [srcValues]' colour space.
     * @param outputProfile ICC profile bytes for the destination colour space.
     * @param srcValues packed per [inputProfile]'s channel count (3
     *   floats/pixel for RGB, 4 for CMYK, 1 for gray).
     * @param intent D-315 defaults to [MkRenderingIntent.RELATIVE_COLORIMETRIC].
     * @return values packed per [outputProfile]'s channel count, or `null`
     *   on failure (unreadable profile bytes, transform creation failure).
     */
    public fun transform(
        inputProfile: ByteArray,
        outputProfile: ByteArray,
        srcValues: FloatArray,
        intent: MkRenderingIntent = MkRenderingIntent.RELATIVE_COLORIMETRIC,
    ): FloatArray? = MkNative.nativeIccTransform(inputProfile, outputProfile, srcValues, intent.nativeValue)
}
