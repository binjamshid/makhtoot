package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontHandle
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkPathData

/**
 * WS-03 packet §5 task 12: glyph outline extraction into MKModel's
 * [MkPathData] (the flat, 1000/em-normalized command stream
 * `MKGlyphNode.outline` persists ، INV-13's lock-resilient representation),
 * with an LRU cache keyed (font handle, glyph id). Ports
 * `Sources/MKTextEngine/GlyphPathProvider.swift`.
 *
 * Ports a Swift `actor` (D-102: the cache is mutable state) — actor
 * isolation is a documented mechanical substitution (`ANDROID_SPINE.md`
 * §9); Kotlin has no `actor` language feature, so this is a plain class.
 */
class MkGlyphPathProvider(
    fonts: MkFontProviding = MkSystemFontStubProvider(),
    capacity: Int = 512,
) {
    data class CacheStats(var hits: Int, var misses: Int)

    /**
     * The outline for [glyphID] in the font [font] resolves to, normalized
     * to 1000/em glyph space (render at any size via `MkPathData.cgPath`).
     * Returns `null` for glyphs with no outline (whitespace, zero-width
     * controls) ، an empty path is normalized to `null` so callers can
     * distinguish "no visual" without probing command streams.
     */
    fun path(glyphID: Int, font: MkFontHandle): MkPathData? =
        throw MkNotYetPorted("MkGlyphPathProvider.path")

    /** Cache statistics (test observability ، the packet's "cache hit test" accept criterion). */
    fun cacheStats(): CacheStats = throw MkNotYetPorted("MkGlyphPathProvider.cacheStats")

    /** Drops every cached outline (font re-registration / memory-pressure hook). */
    fun invalidate(): Unit = throw MkNotYetPorted("MkGlyphPathProvider.invalidate")
}
