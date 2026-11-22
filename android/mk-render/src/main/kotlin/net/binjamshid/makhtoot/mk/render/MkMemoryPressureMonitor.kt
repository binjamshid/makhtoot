package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * D-116 sampling seam: platform memory-pressure events + periodic
 * used-fraction sampling, mapped to [MkMemoryStage] via the D-116
 * thresholds. Ports `Sources/MKRender/MemoryPressureMonitor.swift`.
 */
object MkMemorySampling {
    /**
     * Returns the process's used-memory fraction (`1 - available/total`).
     * iOS sources this from `os_proc_available_memory()`; Android's real
     * implementation (Batch 4) is expected to use `ActivityManager.MemoryInfo`
     * (`ANDROID_SPINE.md` §2 platform substitution table).
     */
    fun currentUsedFraction(): Double = throw MkNotYetPorted("MkMemorySampling.currentUsedFraction")
}

/** D-116 threshold table: usedFraction >=0.70 -> stage1; >=0.85 -> stage2. */
object MkMemoryThresholds {
    const val stage1: Double = 0.70
    const val stage2: Double = 0.85

    /** Maps [fraction] to the D-116 stage it falls into (never `Critical` — that only comes from a real OS event). */
    fun stage(fraction: Double): MkMemoryStage = throw MkNotYetPorted("MkMemoryThresholds.stage")
}

/**
 * Samples memory pressure and drives an [MkDegradationController]. Ports a
 * Swift `actor` — a plain Kotlin `class` here (no Kotlin `actor` feature);
 * Android's real implementation (Batch 4) is expected to back the isolation
 * guarantee with a `Mutex`/confined coroutine dispatcher, and the platform
 * memory-pressure event source with `ComponentCallbacks2.onTrimMemory`.
 */
class MkMemoryPressureMonitor(
    private val sampler: () -> Double = MkMemorySampling::currentUsedFraction,
    private val ladder: MkDegradationController,
    private val sampleInterval: Duration = 2.seconds,
) {
    /** Starts periodic sampling + the platform memory-pressure event listener. Idempotent. */
    fun start(): Unit = throw MkNotYetPorted("MkMemoryPressureMonitor.start")

    fun stop(): Unit = throw MkNotYetPorted("MkMemoryPressureMonitor.stop")

    /** Test/production seam: forces exactly one sample-and-maybe-transition cycle synchronously. */
    suspend fun sampleNow(): Unit = throw MkNotYetPorted("MkMemoryPressureMonitor.sampleNow")
}
