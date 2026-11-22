package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkMemoryAccountable
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkAffineTransform
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkScene

/**
 * A monotonically increasing per-node revision counter used to invalidate a
 * bitmap-cache entry when a node's content changes in a way
 * [MkContentHash] alone might not catch (e.g. an in-flight edit burst).
 * Ports `Sources/MKRender/LayerTreeBuilder.swift`'s `MKCompositionRevision`.
 */
object MkCompositionRevision {
    /** Bumps [nodeId]'s revision counter. */
    fun bump(nodeId: MkNodeId): Unit = throw MkNotYetPorted("MkCompositionRevision.bump")

    /** The current revision counter for [nodeId] (`0` if never bumped). */
    fun current(nodeId: MkNodeId): Int = throw MkNotYetPorted("MkCompositionRevision.current")

    /** Forgets [nodeId]'s revision counter entirely (node removed from the scene). */
    fun forget(nodeId: MkNodeId): Unit = throw MkNotYetPorted("MkCompositionRevision.forget")
}

/**
 * The real [MkRenderTreeProviding] conformer: one [MkPlatformLayer] per
 * top-level node (D-114), diffed against [MkContentHash] so unchanged nodes
 * are never re-rasterized, transient gesture transforms applied as cheap
 * layer-property updates, and D-116 ladder-driven eviction via
 * [MkMemoryAccountable]. Ports `MKLayerTreeController`.
 *
 * `@MainActor`-isolated in Swift — confining this to the main/UI dispatcher
 * is a caller responsibility on Android (`ANDROID_SPINE.md` §9, D-302's
 * `Dispatchers.Main.immediate` convention).
 */
class MkLayerTreeController(
    private val fonts: MkFontProviding = MkSystemFontStubProvider(),
    private val assets: MkAssetProviding = MkEmptyAssetProvider(),
    private val screenScale: Double = 2.0,
    private val degradationController: MkDegradationController? = null,
) : MkRenderTreeProviding, MkMemoryAccountable {
    override val hostLayer: MkPlatformLayer = MkPlatformLayer()

    override fun sync(scene: MkScene): Unit = throw MkNotYetPorted("MkLayerTreeController.sync")

    override fun applyTransientTransform(nodeId: MkNodeId, transform: MkAffineTransform): Unit =
        throw MkNotYetPorted("MkLayerTreeController.applyTransientTransform")

    override fun commitTransients(): Unit = throw MkNotYetPorted("MkLayerTreeController.commitTransients")

    override fun setVisibleRect(visibleRect: MkRect, zoomScale: Double): Unit =
        throw MkNotYetPorted("MkLayerTreeController.setVisibleRect")

    override fun consumeRasterizationCount(): Int = throw MkNotYetPorted("MkLayerTreeController.consumeRasterizationCount")

    /**
     * Ports both `LayerTreeBuilder.swift`'s own public `func accountedBytes() -> Int`
     * AND (the same method, by Swift's "a synchronous, actor-isolated method
     * satisfies an async protocol requirement" rule — see `MkMemoryGovernor`'s
     * own doc comment for the identical pattern) `MkMemoryAccountable`'s
     * `accountedBytes()` requirement. Kotlin has no such actor-isolation
     * shortcut, so this is modeled as the one `suspend fun` the interface
     * requires — a documented mechanical unification, not a dropped symbol
     * (`ANDROID_SPINE.md` §9).
     */
    override suspend fun accountedBytes(): Int = throw MkNotYetPorted("MkLayerTreeController.accountedBytes")
    override suspend fun evictOffscreen(): Unit = throw MkNotYetPorted("MkLayerTreeController.evictOffscreen")
    override suspend fun evictAll(): Unit = throw MkNotYetPorted("MkLayerTreeController.evictAll")
}
