package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkNode

// Ports `Sources/MKRender/ContentHash.swift`. Stable hash of a node's
// CONTENT-affecting fields, deliberately excluding transform/opacity (those
// are layer properties — a pure transform edit must not invalidate
// `MkBitmapCache`/`MkLayerTreeController` entries).

/**
 * A stable, transform/opacity-excluding digest of an [MkNode]'s paintable
 * content — the key [MkBitmapCache] and `MkLayerTreeController`'s scene diff
 * use to decide "does this node need to be re-rendered." Swift namespace
 * enum (no cases) → Kotlin `object`.
 */
object MkContentHash {
    /** Hashes exactly the fields that affect pixels at a given size/style. */
    fun hash(node: MkNode, scaleBucket: Double): String = throw MkNotYetPorted("MkContentHash.hash")
}

/**
 * The zoom-scale quantization policy: powers of √2 from 0.025× to 64×, used
 * both as a [MkBitmapCache]/[MkContentHash] key component and by
 * `MkLayerTreeController`'s re-rasterization hysteresis. Swift namespace enum
 * (no cases) → Kotlin `object`.
 */
object MkScaleBucket {
    const val minScale: Double = 0.025
    const val maxScale: Double = 64.0

    /**
     * Quantizes an arbitrary zoom/contentsScale value down to the nearest
     * √2 power bucket at or below it, clamped to `[minScale, maxScale]`.
     */
    fun quantize(scale: Double): Double = throw MkNotYetPorted("MkScaleBucket.quantize")
}
