package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkMemoryGovernor
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import java.time.Instant

// Ports `Sources/MKRender/DegradationController.swift`. D-116/D-223 memory-
// pressure ladder: the stage machine + fidelity seam so drawers can honor
// `.editorPreview(stage:)`. `MkMemoryGovernor` (`:mk-foundation`) is wired
// into `transition(to:)` so stage transitions fire real cache eviction
// against whatever accountables the app composition root registered
// (`MkLayerTreeController`, `MkBitmapCache`).

/**
 * The D-116 ladder's four stages. Raw values and case order fixed to match
 * `MKMemoryStage` exactly, so any module can adopt this canonical type
 * without an API change.
 */
enum class MkMemoryStage(val rawValue: Int) {
    Normal(0),
    Stage1(1),
    Stage2(2),
    Critical(3),
    ;

    /**
     * Ports the Swift `static func <(lhs:rhs:)` operator
     * (`MKMemoryStage: Comparable`). Every Kotlin enum already extends
     * `Comparable<T>` itself, with a compiler-synthesized `compareTo`
     * (ordinal-based) that is `final` — an enum's declaration order IS
     * its natural order and cannot be overridden the way a plain class's
     * `compareTo` can, so `MkMemoryStage : Comparable<MkMemoryStage>` plus
     * `override fun compareTo` (this stub's original shape) does not
     * compile here. Named `compareToStub` — not `compareTo` under any
     * signature — because Kotlin overload/override resolution is
     * signature-based, not "is this the same declaration or a new one"
     * based: any member named `compareTo(other: MkMemoryStage): Int`,
     * override or not, collides with the inherited final one. Kept as a
     * throwing stub (not implemented against `ordinal`) per the Batch 1
     * contract-stub mechanism, since the Swift original has real
     * comparison logic, not trivial storage.
     */
    fun compareToStub(other: MkMemoryStage): Int = throw MkNotYetPorted("MkMemoryStage.compareTo")
}

/**
 * Render fidelity the degradation controller drives: `Reduced` is
 * half-resolution layer bitmaps + simplified (flat, no-blur) shadows +
 * low-interpolation images + no tile prefetch. Transitions are driven
 * exclusively by the memory ladder, never by entitlement.
 */
enum class MkRenderFidelity {
    Full,
    Reduced,
}

/**
 * The autosave seam the ladder calls at every stage transition, saving
 * BEFORE degrading (INV-17, amended D-223: stages 1-2 get a full
 * debounced-flush-equivalent, critical gets a journal-only append).
 */
interface MkAutosaveTriggering {
    /** Stage 1 (70%) or stage 2 (85%): full scene flush-equivalent. */
    suspend fun flushForMemoryPressure(stage: MkMemoryStage)

    /** Critical: D-223 journal-only append, no scene re-encode. */
    suspend fun flushJournalOnly()
}

/**
 * A no-op conformer so [MkDegradationController] is usable standalone
 * (tests, pre-composition-root development) without a real autosave wiring.
 */
class MkNoOpAutosaveTriggering : MkAutosaveTriggering {
    override suspend fun flushForMemoryPressure(stage: MkMemoryStage): Unit =
        throw MkNotYetPorted("MkNoOpAutosaveTriggering.flushForMemoryPressure")

    override suspend fun flushJournalOnly(): Unit =
        throw MkNotYetPorted("MkNoOpAutosaveTriggering.flushJournalOnly")
}

/**
 * FC-3 reclaim seam for the undo/redo stack: a second, independent path from
 * the `MkMemoryAccountable`/[MkMemoryGovernor] registration `MkUndoStack`
 * also participates in. Fires at stage1 and stage2 (the governor path only
 * fires at stage1/critical).
 */
interface MkUndoCapReclaiming {
    /** Shrinks the undo/redo budget to at most [newMax] entries. */
    suspend fun setMaxEntries(newMax: Int)
}

/**
 * One ladder-stage transition event, for banner/HUD observers.
 */
data class MkMemoryStageEvent(
    val stage: MkMemoryStage,
    val bannerText: String? = null,
)

/**
 * D-116/D-223 ladder state machine: owns the current [MkMemoryStage] and the
 * [MkRenderFidelity] it implies, drives the save-before-degrade sequence
 * (INV-17/D-223), and applies the hysteresis on the way back down.
 * `@MainActor`-isolated in Swift — Kotlin has no actor-isolation attribute;
 * callers are expected to confine this to the main/UI dispatcher
 * (`ANDROID_SPINE.md` §9 documented mechanical note, D-302's
 * `Dispatchers.Main.immediate` convention).
 */
class MkDegradationController(
    private val autosave: MkAutosaveTriggering = MkNoOpAutosaveTriggering(),
    private val governor: MkMemoryGovernor? = null,
    private val undoCapReclaimer: MkUndoCapReclaiming? = null,
) {
    /** Current ladder stage. */
    var stage: MkMemoryStage = MkMemoryStage.Normal
        private set

    /** Sequence of stage transitions, most-recent last — test/HUD observability. */
    var history: List<MkMemoryStageEvent> = emptyList()
        private set

    companion object {
        /** Cap on [history]'s length — oldest events are dropped first. */
        const val maxHistoryEntries: Int = 64

        /** D-116's exact Arabic banner copy, posted verbatim on every entry into stage2. */
        const val stage2BannerText: String = "الذاكرة شبه ممتلئة ، تم الحفظ تلقائيًا"
    }

    /** `stage >= .stage2 ? .reduced : .full`. */
    val fidelity: MkRenderFidelity
        get() = throw MkNotYetPorted("MkDegradationController.fidelity")

    /**
     * Advances (or retreats) the ladder to [newStage]. Downward transitions
     * enforce the D-116 hysteresis themselves; upward moves (or a
     * `.critical` event) are immediate.
     */
    suspend fun transition(newStage: MkMemoryStage, now: Instant = Instant.now()): Unit =
        throw MkNotYetPorted("MkDegradationController.transition")

    /** Test seam: bypasses hysteresis entirely. */
    suspend fun forceTransition(newStage: MkMemoryStage): Unit =
        throw MkNotYetPorted("MkDegradationController.forceTransition")
}
