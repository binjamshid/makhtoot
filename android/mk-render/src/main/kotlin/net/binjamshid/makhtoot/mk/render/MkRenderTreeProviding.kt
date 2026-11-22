package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkScene

/**
 * The canvas-host contract (D-114): a live layer tree kept in sync with a
 * scene, with a cheap transient-transform hot path for gesture frames.
 * Ports `Sources/MKRender/RenderTreeProviding.swift`.
 *
 * `@MainActor` in Swift — confining conformers to the main/UI dispatcher is
 * a caller responsibility on Android (`ANDROID_SPINE.md` §9).
 */
interface MkRenderTreeProviding {
    /** The layer `mk-canvas` inserts as a sublayer of its canvas content view. */
    val hostLayer: MkPlatformLayer

    /** Reconciles the layer tree to match [scene] (D-114 diffing via `MkContentHash`). */
    fun sync(scene: MkScene)

    /** 60/120 Hz hot path: applies [transform] to one node's layer as a cheap property update. */
    fun applyTransientTransform(nodeId: MkNodeId, transform: MkAffineTransform)

    /** Gesture end: clears transient-only bookkeeping. */
    fun commitTransients()

    /** Zoom/pan bookkeeping feeding the zoom-bucket policy and offscreen-eviction hooks. */
    fun setVisibleRect(visibleRect: MkRect, zoomScale: Double)

    /** Test/HUD observability: resets the rasterization counter on read. */
    fun consumeRasterizationCount(): Int
}
