package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkTextStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.model.arranged.MkGlyphNode
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

/** The result of breaking or restoring a join between two glyph nodes. Ports `JoinEditResult`. */
data class MkJoinEditResult(
    var updatedA: MkGlyphNode,
    var updatedB: MkGlyphNode,
    var formDeltaA: Double,
    var formDeltaB: Double,
) {
    /** Whether either side's cursive-attachment connecting stroke may not match exactly after this edit. */
    val cursiveFidelityNote: Boolean
        get() = throw MkNotYetPorted("MkJoinEditResult.cursiveFidelityNote")
}

/**
 * Break/restore a cursive join between two adjacent glyph nodes. Ports
 * `Sources/MKArrange/JoinController.swift`.
 */
class MkJoinController(private val fonts: MkFontProviding = MkSystemFontStubProvider()) {
    companion object {
        /** The default contextual form for a letter given its neighbor-join state. */
        fun defaultForm(joinsPrevious: Boolean, joinsNext: Boolean): MkJoiningForm =
            throw MkNotYetPorted("MkJoinController.defaultForm")
    }

    /** Breaks the cursive join between [nodeA] and [nodeB], switching both to isolated/terminal forms as needed. */
    suspend fun breakJoin(nodeA: MkGlyphNode, nodeB: MkGlyphNode, style: MkTextStyle): MkJoinEditResult =
        throw MkNotYetPorted("MkJoinController.breakJoin")

    /** Restores the cursive join between [nodeA] and [nodeB]. */
    suspend fun restoreJoin(nodeA: MkGlyphNode, nodeB: MkGlyphNode, style: MkTextStyle): MkJoinEditResult =
        throw MkNotYetPorted("MkJoinController.restoreJoin")

    /** The command that applies [result] (a break or a restore) to the composition. */
    fun command(result: MkJoinEditResult, ownerNode: MkArrangedTextNode, isBreak: Boolean): MkCommand =
        throw MkNotYetPorted("MkJoinController.command")
}
