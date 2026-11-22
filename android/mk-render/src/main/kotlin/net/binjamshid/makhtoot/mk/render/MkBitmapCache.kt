package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkMemoryAccountable
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

// Ports `Sources/MKRender/BitmapCache.swift`. LRU bitmap cache keyed
// `(nodeContentHash, scaleBucket)`, byte-budgeted, offscreen-first eviction
// (D-116 ladder). Conforms to `MkMemoryAccountable` so any owner that
// registers an instance with `MkMemoryGovernor` gets real ladder-driven
// eviction.

/**
 * Cache key: a node's content-affecting-fields digest ([MkContentHash])
 * plus the quantized zoom bucket ([MkScaleBucket]) it was rendered at.
 */
data class MkBitmapCacheKey(
    val nodeContentHash: String,
    val scaleBucket: Double,
)

/**
 * One cached entry: the rendered bitmap, its accounted byte cost
 * (`bytesPerRow × height`, the same accounting `MkMemoryGovernor` uses),
 * and whether the owning layer is currently offscreen (stage-1 eviction
 * priority).
 */
data class MkBitmapCacheEntry(
    val image: MkPlatformImage,
    var bytes: Int,
    var isOffscreen: Boolean = false,
)

/**
 * Swift `actor` → plain Kotlin `class` (Kotlin has no `actor` language
 * feature, `ANDROID_SPINE.md` §9 documented mechanical substitution,
 * matching `MkMemoryGovernor`'s own note — Android's real isolation
 * guarantee, Batch 4, is expected to come from a `Mutex`-guarded map or a
 * confined coroutine dispatcher). D-116 stage 1 (70%): "drop offscreen
 * bitmap caches"; critical: "drop everything."
 */
class MkBitmapCache(budgetBytes: Int = maxBudgetBytes) : MkMemoryAccountable {

    companion object {
        /** `min(256 MB, 15% of available memory at init)` — see Swift doc comment for the VERIFY-AT-IMPLEMENTATION note this ceiling defaults to. */
        const val maxBudgetBytes: Int = 256 * 1024 * 1024
    }

    /**
     * Sum of every cached entry's accounted bytes. Ports the Swift
     * synchronous computed property `var accountedBytes: Int`. Renamed from
     * `accountedBytes` — Kotlin (unlike Swift) does not allow a property and
     * a function of the same name in one class, and the `MkMemoryAccountable`
     * override below must keep the exact name `accountedBytes()`. Documented
     * naming-rule deviation (`ANDROID_SPINE.md` §9).
     */
    val currentAccountedBytes: Int
        get() = throw MkNotYetPorted("MkBitmapCache.currentAccountedBytes")

    /** Recomputes the budget and evicts if now over it. */
    fun setBudget(bytes: Int): Unit = throw MkNotYetPorted("MkBitmapCache.setBudget")

    fun insert(image: MkPlatformImage, key: MkBitmapCacheKey, isOffscreen: Boolean = false): Unit =
        throw MkNotYetPorted("MkBitmapCache.insert")

    fun image(key: MkBitmapCacheKey): MkPlatformImage? = throw MkNotYetPorted("MkBitmapCache.image")

    fun markOffscreen(key: MkBitmapCacheKey, isOffscreen: Boolean): Unit =
        throw MkNotYetPorted("MkBitmapCache.markOffscreen")

    /** D-116 stage 1 (70%): "drop offscreen bitmap caches." */
    fun purgeOffscreen(): Unit = throw MkNotYetPorted("MkBitmapCache.purgeOffscreen")

    /** D-116 critical: "purgeAll()." */
    fun purgeAll(): Unit = throw MkNotYetPorted("MkBitmapCache.purgeAll")

    fun containsKey(key: MkBitmapCacheKey): Boolean = throw MkNotYetPorted("MkBitmapCache.containsKey")

    val entryCount: Int
        get() = throw MkNotYetPorted("MkBitmapCache.entryCount")

    // MARK: - MkMemoryAccountable (P14)

    override suspend fun accountedBytes(): Int = throw MkNotYetPorted("MkBitmapCache.accountedBytes()")
    override suspend fun evictOffscreen(): Unit = throw MkNotYetPorted("MkBitmapCache.evictOffscreen")
    override suspend fun evictAll(): Unit = throw MkNotYetPorted("MkBitmapCache.evictAll")
}
