package net.binjamshid.makhtoot.mk.nativebridge

/**
 * ICC rendering intent for [MkIccTransform.transform] — mirrors lcms2's
 * `INTENT_*` constants (and the ICC spec's own numbering) exactly, so the
 * native side (`mk_color.cpp`) passes [nativeValue] straight through with
 * no translation table to keep in sync.
 *
 * D-315: the working default is [RELATIVE_COLORIMETRIC], matching
 * `CGColorSpace`'s sRGB→CMYK conversion intent on iOS (D-117). The other
 * three exist so a later batch can exercise them if ever needed — v1 ships
 * no on-screen soft-proofing and no intent picker (`ANDROID_SPINE.md` §14).
 */
public enum class MkRenderingIntent(internal val nativeValue: Int) {
    PERCEPTUAL(0),
    RELATIVE_COLORIMETRIC(1),
    SATURATION(2),
    ABSOLUTE_COLORIMETRIC(3),
}
