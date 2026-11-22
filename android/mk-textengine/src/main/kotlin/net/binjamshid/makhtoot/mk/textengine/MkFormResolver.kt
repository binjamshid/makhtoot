package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkPathData
import net.binjamshid.makhtoot.mk.model.MkTextStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm

/**
 * The result of a D-107 form harvest: the requested [MkJoiningForm] (or the
 * nearest valid form when the letter cannot realize the requested one), the
 * harvested glyph, its advance, and its outline. Ports
 * `Sources/MKTextEngine/FormResolver.swift`.
 */
data class MkResolvedForm(
    /** The form actually realized. */
    var form: MkJoiningForm,
    /** The form the caller asked for. */
    var requestedForm: MkJoiningForm,
    /**
     * `true` when `form != requestedForm` ، right-joining letters (د ذ ر ز و
     * ا …) have no initial/medial, so those requests coerce to the nearest
     * valid form (initial→isolated, medial→final) and WS-04's form selector
     * uses this flag to disable invalid options.
     */
    var wasCoerced: Boolean,
    var glyphID: Int,
    var advance: MkSize,
    /** 1000/em-normalized outline (`MkGlyphPathProvider`); `null` when the glyph has no outline. */
    var outline: MkPathData?,
)

/**
 * D-107 ZWJ joining-form resolver (WS-03 packet §5 task 11): "reshape the
 * single letter in a synthetic context using U+200D ZWJ (e.g., ZWJ+ح+ZWJ
 * for medial) through the same font, then harvest that glyph."
 *
 * Synthetic contexts: isolated `L` · initial `L+ZWJ` · medial `ZWJ+L+ZWJ` ·
 * final `ZWJ+L`. The harvest shapes with the same font/features but
 * **without** kerning/tracking, then picks the glyph whose cluster contains
 * the letter's string index (ZWJ-produced glyphs map to the ZWJ indices and
 * are ignored).
 *
 * Ports a Swift `actor` — actor-isolation is a documented mechanical
 * substitution (`ANDROID_SPINE.md` §9): Kotlin has no `actor` language
 * feature, so this is a plain class; Batch 3's real implementation is
 * expected to back the isolation guarantee with a `Mutex`/confined
 * coroutine dispatcher guarding the harvest cache.
 */
class MkFormResolver(fonts: MkFontProviding = MkSystemFontStubProvider()) {
    /**
     * Resolves [form] for [letter] (a Unicode scalar value) in [style]'s
     * font. Returns `null` when the letter produced no glyph at all (not a
     * letter the font can shape). Cached per (font, size, scalar, form) ،
     * packet task 11.
     */
    suspend fun resolve(letter: Int, form: MkJoiningForm, style: MkTextStyle): MkResolvedForm? =
        throw MkNotYetPorted("MkFormResolver.resolve")

    /** Drops the harvest cache (font re-registration hook, WS-09). */
    fun invalidate(): Unit = throw MkNotYetPorted("MkFormResolver.invalidate")
}
