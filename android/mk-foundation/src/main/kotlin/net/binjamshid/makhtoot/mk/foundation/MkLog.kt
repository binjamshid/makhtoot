package net.binjamshid.makhtoot.mk.foundation

/**
 * Placeholder for the structured-logging handle `os.Logger` resolves to on
 * iOS. Android's real implementation (Batch 2) is expected to wrap
 * `android.util.Log` (or a small Timber-style facade) behind this same type
 * name so call sites ported in later batches do not need to change —
 * documented placeholder, not itself a `MkNotYetPorted` stub member, per
 * `ANDROID_SPINE.md` §9 (new supporting infrastructure, no 1:1 Swift source
 * line, needed only because the platform logging type has no direct Kotlin
 * equivalent at this layer).
 */
class MkLogger internal constructor(val subsystem: String, val category: String)

/**
 * Structured logging for MakhtootKit. Ports `Sources/MKFoundation/MKLog.swift`.
 * Every module gets a scoped logger for subsystem/category filtering.
 */
object MkLog {
    /** Real bundle-id-derived subsystem prefix, `net.binjamshid.makhtoot`. */
    const val subsystemPrefix: String = "net.binjamshid.makhtoot"

    /** Returns a logger for [module], subsystem `net.binjamshid.makhtoot.<module>`. */
    fun logger(module: String): MkLogger = throw MkNotYetPorted("MkLog.logger")

    // Pre-built loggers for the modules that exist as of Batch 1. `lazy` so
    // merely referencing `MkLog` does not eagerly trigger `logger(...)`'s
    // stub throw at class-init time — only actually reading one of these
    // does, matching the throw-on-use contract of every other Batch 1 stub.
    val foundation: MkLogger by lazy { logger("MKFoundation") }
    val designSystem: MkLogger by lazy { logger("MKDesignSystem") }
    val app: MkLogger by lazy { logger("App") }
}

/**
 * Reserved tracing-interval names for the D-115 performance budgets. Ports
 * `MKSignpost`. Android's real implementation (Batch 8.4 per
 * `ANDROID_SPINE.md` §2 platform substitution table) is expected to back
 * this with `android.os.Trace`/Perfetto.
 */
enum class MkSignpost {
    ManipulationFrame,
    TypingEcho,
    DocumentOpen,
    Autosave,
    Export,
    ArrangeDerive,
    ;

    companion object {
        /** The tracing facility this interval should be logged against. */
        val signposter: Any by lazy { throw MkNotYetPorted("MkSignpost.signposter") }
    }
}
