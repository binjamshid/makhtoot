package net.binjamshid.makhtoot.mk.foundation

/**
 * Cross-module memory-accounting participant interface. Ports
 * `Sources/MKFoundation/MKMemoryGovernor.swift`'s `MKMemoryAccountable`.
 * Any module's cache conforms to this and registers with [MkMemoryGovernor];
 * `mk-render`'s `MkDegradationController` (the D-116 ladder state machine)
 * calls [evictOffscreen]/[evictAll] at stage transitions.
 */
interface MkMemoryAccountable {
    /** Current bytes this accountable is holding. */
    suspend fun accountedBytes(): Int

    /** D-116 stage 1 (70%): drop only content that is not currently visible. */
    suspend fun evictOffscreen()

    /** D-116/D-223 critical stage: drop everything. */
    suspend fun evictAll()
}

/**
 * Eviction ordering hint for future governor policy. Ports
 * `MKMemoryEvictionPriority`.
 */
enum class MkMemoryEvictionPriority(val rawValue: Int) : Comparable<MkMemoryEvictionPriority> {
    OffscreenFirst(0),
    Standard(1),
}

/**
 * The cross-module memory-accounting registry. Ports `MKMemoryGovernor`
 * (a Swift `actor`). Android's real implementation (Batch 2) is expected to
 * back the actor-isolation guarantee with a `Mutex`/single-threaded
 * coroutine dispatcher — documented mechanical substitution
 * (`ANDROID_SPINE.md` §9): Kotlin has no `actor` language feature.
 */
class MkMemoryGovernor {
    /**
     * Registers [accountable] for ladder-driven eviction. Idempotent-safe to
     * call multiple times with the same instance.
     */
    fun register(accountable: MkMemoryAccountable, priority: MkMemoryEvictionPriority = MkMemoryEvictionPriority.Standard): Unit =
        throw MkNotYetPorted("MkMemoryGovernor.register")

    /** Sum of every live registrant's `accountedBytes()`. */
    suspend fun totalAccountedBytes(): Int = throw MkNotYetPorted("MkMemoryGovernor.totalAccountedBytes")

    /** D-116 stage 1 (70%): "drop offscreen bitmap caches." */
    suspend fun evictOffscreen(): Unit = throw MkNotYetPorted("MkMemoryGovernor.evictOffscreen")

    /** D-116/D-223 critical: drop everything across every registrant. */
    suspend fun evictAll(): Unit = throw MkNotYetPorted("MkMemoryGovernor.evictAll")

    /** Number of currently-live (non-deallocated) registrations — test/HUD observability only. */
    val liveRegistrationCount: Int
        get() = throw MkNotYetPorted("MkMemoryGovernor.liveRegistrationCount")
}
