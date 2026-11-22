package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkPlatformFont
import net.binjamshid.makhtoot.mk.model.MkLigatureSetting

/**
 * D-108 font-feature control (WS-03 packet §5 task 2): maps MKModel's
 * closed [MkLigatureSetting] to OpenType feature settings and applies them
 * on the **font** (not the string), so glyph-path extraction later resolves
 * against the identical feature-configured font (ARCHITECTURE §4.3's
 * note). Ports `Sources/MKTextEngine/FontFeatureControl.swift`.
 *
 * **`rlig` is deliberately not controllable** ، the packet's task-2 accept
 * criterion is that "`rlig` disable attempts are rejected by API design (no
 * such option exposed)": required ligatures (the lam-alif family) are
 * non-negotiable in Arabic, and no case of [MkLigatureSetting] maps to any
 * `rlig` setting, so the closed enum IS the rejection mechanism. Verified
 * by `FontFeatureControlTests` (no emitted feature dictionary ever names
 * `rlig`; «لا» stays one glyph even at `.off`).
 */
object MkFontFeatureControl {
    /**
     * The OpenType feature settings for [setting], as feature-tag/value
     * dictionaries (`kCTFontOpenTypeFeatureTag`/`kCTFontOpenTypeFeatureValue`
     * shape on iOS). Exposed (not private) so tests can assert the exact
     * dictionaries ، the packet's "attribute dump" accept criterion ،
     * without shaping.
     *
     * Mapping:
     * - `.standard` → no overrides (font defaults: `liga`/`calt`/`rlig` all
     *   as the font ships them).
     * - `.discretionaryOn` → `dlig=1` plus explicit `calt=1` (contextual
     *   alternates confirmed on ، some fonts gate stylistic joins there).
     * - `.off` → `liga=0`, `dlig=0`. `calt` is left untouched even at
     *   `.off`: several Arabic fonts route required contextual behavior
     *   through `calt`, and D-108's ban on breaking required shaping
     *   outranks a maximal "off".
     */
    fun featureSettings(setting: MkLigatureSetting): List<Map<String, Any>> =
        throw MkNotYetPorted("MkFontFeatureControl.featureSettings")

    /**
     * Returns [base] reconfigured with the feature settings for [setting]
     * (same size, same other attributes). `.standard` returns [base]
     * unchanged (no descriptor round-trip cost on the default path).
     */
    fun font(base: MkPlatformFont, setting: MkLigatureSetting): MkPlatformFont =
        throw MkNotYetPorted("MkFontFeatureControl.font")

    /**
     * The ligature-attribute value paired with [setting] (0 = required
     * ligatures only, 1 = default ligatures) ، applied by
     * `MkAttributedStringBuilder` alongside the font-level features. Note
     * even `0` never disables `rlig`.
     */
    fun ligatureAttributeValue(setting: MkLigatureSetting): Int =
        throw MkNotYetPorted("MkFontFeatureControl.ligatureAttributeValue")
}
