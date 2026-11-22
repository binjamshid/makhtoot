package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.model.arranged.MkSourceTextBackup
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

/**
 * Revert-to-text: reconstructs the original `liveText`/`pathText` node from
 * an [MkSourceTextBackup], with a confirmation preflight — revert is itself
 * a forward, undoable command, never applied silently. Ports
 * `Sources/MKArrange/RevertService.swift`.
 */
class MkRevertService {
    /** Revert's preflight report: `{editedNodeCount, willDiscard}`. Ports the nested `RevertPreflight` struct. */
    data class RevertPreflight(
        var editedNodeCount: Int,
        var willDiscard: Boolean = true,
    ) {
        companion object {
            /** D-106/ARCHITECTURE §5.4's exact Arabic confirmation copy. */
            const val confirmationMessage: String = "استرجاع النص الأصلي سيلغي جميع التعديلات الحرة. متابعة؟"
        }
    }

    /**
     * Counts every child (including decomposed-ligature components) whose
     * current state differs from what a fresh derivation would have
     * produced. `willDiscard` is unconditionally `true` — revert always
     * discards manual arrangement, never a partial/selective revert.
     */
    fun preflight(composition: MkArrangedComposition): RevertPreflight =
        throw MkNotYetPorted("MkRevertService.preflight")

    /**
     * Verifies [backup]'s content hash still matches a fresh recomputation
     * (INV-4 tamper/drift guard) before reverting.
     */
    fun verifyBackupIntegrity(backup: MkSourceTextBackup): Unit =
        throw MkNotYetPorted("MkRevertService.verifyBackupIntegrity")

    /**
     * Rebuilds the `liveText` (or `pathText`, when the backup carries path
     * data) node from [node]'s source backup — same transform/z (the
     * arranged node's own `core`, reused verbatim). Undo of the returned
     * command restores the full arranged node exactly.
     */
    fun revertCommand(arrangedNodeId: MkNodeId, node: MkArrangedTextNode): MkCommand =
        throw MkNotYetPorted("MkRevertService.revertCommand")
}
