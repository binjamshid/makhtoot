package net.binjamshid.makhtoot.mk.textengine

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider

/** One shaped line's D-105/D-107 analysis outputs, alongside the raw shape. */
data class MkLineAnalysis(
    var marks: List<MkMarkAttachment>,
    var ligatures: List<MkDetectedLigature>,
    var joining: List<MkLetterJoining>,
)

/**
 * The frozen shaping output `mk-arrange`'s deriver consumes: the shaped
 * paragraph plus per-line D-105/D-107/D-109 analysis. Ports
 * `Sources/MKTextEngine/ShapingService.swift`'s `MKShapingCaptureResult`.
 */
data class MkShapingCaptureResult(
    var paragraph: MkShapedParagraph,
    var lineAnalyses: List<MkLineAnalysis>,
)

/**
 * The shaping engine service: request in, shaped paragraph (or full capture
 * result) out, with a bounded shaping cache. Ports `MKShapingService` (a
 * Swift `actor`) — a plain Kotlin `class` here (no Kotlin `actor` feature);
 * Android's real implementation (Batch 3) is expected to back the
 * isolation guarantee with a `Mutex`/confined coroutine dispatcher.
 */
class MkShapingService(
    private val fonts: MkFontProviding = MkSystemFontStubProvider(),
    private val costLimit: Int = 32 * 1024 * 1024,
) {
    /** Shapes [request], returning just the paragraph. */
    fun shape(request: MkShapingRequest): MkShapedParagraph = throw MkNotYetPorted("MkShapingService.shape")

    /** Shapes [request], returning the full capture result (paragraph + D-105/D-107/D-109 analyses). */
    fun captureResult(request: MkShapingRequest): MkShapingCaptureResult =
        throw MkNotYetPorted("MkShapingService.captureResult")

    /** Drops the shaping cache (font re-registration hook). */
    fun invalidateCache(): Unit = throw MkNotYetPorted("MkShapingService.invalidateCache")

    /** `(hits, misses)` cache counters, for tests/perf HUD. */
    fun cacheCounters(): Pair<Int, Int> = throw MkNotYetPorted("MkShapingService.cacheCounters")
}
