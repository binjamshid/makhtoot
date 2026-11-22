package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkSignpost

/**
 * Tracing instrumentation for every D-115 budget `:mk-render` itself is on
 * the hook for, plus the render-internal categories (`renderTile`,
 * `layerSync`, `pathRelayout`) not already covered by `MkFoundation`'s
 * shared vocabulary. Ports `Sources/MKRender/RenderSignposts.swift`.
 */

/** Render-internal tracing categories not already covered by `mk-foundation`'s `MkSignpost`. */
enum class MkRenderSignpost {
    RenderTile,
    LayerSync,
    PathRelayout,
    ;

    companion object {
        /** Dedicated tracing facility so render-internal categories can be filtered independently. */
        val signposter: Any by lazy { throw MkNotYetPorted("MkRenderSignpost.signposter") }
    }
}

/**
 * Convenience interval-tracking wrapper so call sites don't hand-roll
 * begin/end pairs. Used for both `mk-foundation`'s shared `MkSignpost`
 * vocabulary and this module's own [MkRenderSignpost] categories.
 */
object MkRenderSignposts {
    /** Wraps [body] in an `mk-foundation` `MkSignpost` interval and returns its result. */
    fun <T> interval(name: MkSignpost, body: () -> T): T = throw MkNotYetPorted("MkRenderSignposts.interval(MkSignpost)")

    /** Same, for this module's own render-internal categories. */
    fun <T> interval(name: MkRenderSignpost, body: () -> T): T =
        throw MkNotYetPorted("MkRenderSignposts.interval(MkRenderSignpost)")

    /** Async variant (e.g. `documentOpen` spanning a suspend chain). */
    suspend fun <T> intervalSuspend(name: MkSignpost, body: suspend () -> T): T =
        throw MkNotYetPorted("MkRenderSignposts.intervalSuspend")
}

/**
 * A rolling snapshot of the numbers a debug perf-HUD is expected to render:
 * frame time, memory stage, cache bytes.
 */
data class MkRenderPerfSnapshot(
    var lastFrameDuration: Double,
    var memoryStage: MkMemoryStage,
    var bitmapCacheBytes: Int,
    var rasterizationsSinceLastRead: Int,
)

/**
 * The seam a debug-only app-target HUD view reads from. Kept as a tiny
 * interface (not a concrete singleton) so [MkLayerTreeController]/
 * [MkDegradationController]/[MkBitmapCache] can each be adapted into one.
 */
interface MkRenderPerfHUDDataSource {
    fun currentPerfSnapshot(): MkRenderPerfSnapshot
}
