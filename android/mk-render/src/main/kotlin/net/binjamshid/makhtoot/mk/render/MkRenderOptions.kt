package net.binjamshid.makhtoot.mk.render

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId

// Ports `Sources/MKRender/RenderOptions.swift`. Render options:
// `.editorPreview(stage:)` vs `.exportQuality`, plus the small value types
// `MkSceneRenderer`/`MkSnapshotRenderer` share.

/**
 * The renderer's two operating modes: preview quality tracks the D-116
 * degradation ladder's current stage; export quality NEVER degrades
 * regardless of ladder stage (D-118 — "if memory can't support export,
 * tiling handles it," not a quality cut). Swift enum WITH an associated
 * value (`.editorPreview(stage:)`) → Kotlin `sealed class`.
 */
sealed class MkRenderQuality {
    data class EditorPreview(val stage: MkMemoryStage) : MkRenderQuality()
    object ExportQuality : MkRenderQuality()

    /** The [MkRenderFidelity] this quality implies for drawers. */
    val fidelity: MkRenderFidelity
        get() = throw MkNotYetPorted("MkRenderQuality.fidelity")

    /** Image interpolation quality for raster assets. */
    val imageInterpolationQuality: MkImageInterpolationQuality
        get() = throw MkNotYetPorted("MkRenderQuality.imageInterpolationQuality")
}

/**
 * Mutable accumulator `MkSceneRenderer` threads through a render pass;
 * finalized into the immutable [MkRenderReport] it returns. Swift `struct`
 * with stored `var` properties → Kotlin `data class`; the Swift `inout`
 * parameter convention every drawer's `draw(...)` uses becomes a plain
 * reference parameter here (a Kotlin class is already reference-typed, so
 * callee mutation is visible to the caller without an `inout` equivalent).
 */
data class MkRenderReportBuilder(
    var substitutions: MutableList<MkRenderSubstitution> = mutableListOf(),
    var nodeCount: Int = 0,
) {
    fun recordSubstitution(nodeId: MkNodeId, kind: MkRenderSubstitution.Kind, detail: String): Unit =
        throw MkNotYetPorted("MkRenderReportBuilder.recordSubstitution")
}

/**
 * Per-render substitution events (missing asset/outline/font) — surfaced in
 * the debug HUD and asserted empty in export tests.
 */
data class MkRenderReport(
    val substitutions: List<MkRenderSubstitution>,
    val nodeCount: Int,
    val duration: Double,
)

data class MkRenderSubstitution(
    val nodeId: MkNodeId,
    val kind: Kind,
    val detail: String,
) {
    enum class Kind {
        MissingAsset,
        MissingOutline,
        MissingFont,
    }
}
