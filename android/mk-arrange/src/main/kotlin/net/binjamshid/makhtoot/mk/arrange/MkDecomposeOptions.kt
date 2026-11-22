package net.binjamshid.makhtoot.mk.arrange

import kotlinx.serialization.Serializable

/**
 * Options for [MkLigatureDecomposer.decompose] (D-108 "user opt-out switches
 * to default spacing/forms"). Ports `Sources/MKArrange/DecomposeOptions.swift`.
 *
 * `@Serializable` is added here even though the Swift `DecomposeOptions` is
 * only `Sendable, Equatable` (not `Codable`) — this is the module's
 * simplest, fully self-contained data shape (a single `Boolean`, no
 * cross-module type references), so it is the representative type
 * `MkArrangeStubTest`'s kotlinx-serialization round-trip check exercises
 * (`ANDROID_TASK_PACKETS/BATCH-1.md` Agent 1.3 deliverable). Documented
 * deviation, not a silent one — no other type in this module gained a
 * conformance its Swift source does not have.
 */
@Serializable
data class MkDecomposeOptions(
    /**
     * `true` (default): place constituents to match the original ligature's
     * visual bounds (affine fit). `false`: explicit opt-out — natural
     * standalone advances, no fit.
     */
    var fidelity: Boolean = true,
) {
    companion object {
        val fidelityDefault = MkDecomposeOptions(fidelity = true)
        val defaultForms = MkDecomposeOptions(fidelity = false)
    }
}
