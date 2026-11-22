package net.binjamshid.makhtoot.mk.nativebridge

/**
 * Paragraph/run direction for [MkShaper.shape] (D-303). Maps 1:1 onto the
 * `direction` `Int` [MkNative.nativeShape] takes (`0 = LTR`, `1 = RTL`) —
 * kept as a real enum here so callers in `:mk-textengine` never pass a raw
 * magic number.
 *
 * Script direction beyond LTR/RTL (e.g. vertical text) is out of scope for
 * v1 (`ANDROID_SPINE.md` §14 mirrors iOS's own scope), so this is
 * intentionally a two-value enum, not a full `hb_direction_t` mirror.
 */
public enum class MkShapeDirection(internal val nativeValue: Int) {
    LTR(0),
    RTL(1),
}
