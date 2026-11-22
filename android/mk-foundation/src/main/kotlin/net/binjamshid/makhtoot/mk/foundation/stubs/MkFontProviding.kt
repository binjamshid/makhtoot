package net.binjamshid.makhtoot.mk.foundation.stubs

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * Placeholder for the resolved native font handle `CTFont` represents on
 * iOS. Android's real type (arriving with `mk-native`'s HarfBuzz/FreeType JNI
 * facade, D-303, and `mk-fonts`'s catalog, D-316, in later batches) is
 * expected to wrap an `hb_font_t`/`FT_Face` pair. `mk-foundation` must not
 * depend on `:mk-native` (`ANDROID_SPINE.md` §3.2 dependency edges — only
 * `mk-color`, `mk-fonts`, `mk-textengine`, `mk-render`, `mk-export` depend on
 * it), so this stays a local, dependency-free placeholder here, per
 * `ANDROID_SPINE.md` §9's deviation-logging convention.
 */
class MkPlatformFont internal constructor()

/**
 * A stable font pointer good enough to resolve a concrete [MkPlatformFont]: a
 * PostScript name plus point size. Ports
 * `Sources/MKFoundation/Stubs/MKFontProviding.swift`.
 */
data class MkFontHandle(val postScriptName: String, val pointSize: Double)

/**
 * A bold/italic request against a resolved font handle. Never synthesized: a
 * conformer that cannot satisfy a request must return the base font
 * unchanged rather than fake-embolden/oblique it (synthetic emboldening
 * degrades Arabic letter joins).
 */
data class MkFontVariantRequest(val bold: Boolean, val italic: Boolean)

/**
 * Resolves a font handle to a concrete [MkPlatformFont]. `mk-fonts` ships the
 * real conformer.
 */
interface MkFontProviding {
    /** Resolves [handle] to a font. Conformers must always return a usable font. */
    fun resolve(handle: MkFontHandle): MkPlatformFont

    /**
     * Resolves [handle] to a font, additionally attempting to satisfy
     * [variant] with a genuine font-family cut or variable axis. Default
     * implementation ignores [variant] and forwards to `resolve(handle)`.
     */
    fun resolve(handle: MkFontHandle, variant: MkFontVariantRequest): MkPlatformFont =
        throw MkNotYetPorted("MkFontProviding.resolve(variant)")
}

/**
 * Resolves the requested `postScriptName` when possible, with an
 * Arabic-capable system-font fallback. `mk-fonts` ships the real
 * `MkFontRegistry` (bundled catalog + user imports) conforming to the same
 * [MkFontProviding] interface.
 */
class MkSystemFontStubProvider : MkFontProviding {
    override fun resolve(handle: MkFontHandle): MkPlatformFont =
        throw MkNotYetPorted("MkSystemFontStubProvider.resolve")
}
