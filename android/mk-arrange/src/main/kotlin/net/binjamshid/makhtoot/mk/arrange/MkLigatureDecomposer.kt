package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkTextStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.model.arranged.MkLigatureGroup
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

/**
 * Decompose a ligature group into independently-manipulable constituent
 * glyphs, and recompose it back. Ports
 * `Sources/MKArrange/LigatureDecomposer.swift`.
 */
class MkLigatureDecomposer(private val fonts: MkFontProviding = MkSystemFontStubProvider()) {
    companion object {
        /** The natural-scale-factor clamp range a fidelity-mode affine fit is bounded to. */
        val clampRange: ClosedRange<Double> = 0.85..1.15
    }

    /** The result of a decompose operation. Ports `DecomposeResult`. */
    data class MkDecomposeResult(
        var group: MkLigatureGroup,
        var fidelityAutoRefused: Boolean,
        var naturalScaleFactor: Double,
    ) {
        /** Whether the decomposed constituents' cursive-attachment connecting stroke may not match exactly. */
        val cursiveFidelityNote: Boolean
            get() = throw MkNotYetPorted("MkDecomposeResult.cursiveFidelityNote")
    }

    /** Decomposes [group] into independently-manipulable constituents. */
    suspend fun decompose(
        group: MkLigatureGroup,
        sourceString: String,
        style: MkTextStyle,
        options: MkDecomposeOptions = MkDecomposeOptions.fidelityDefault,
    ): MkDecomposeResult = throw MkNotYetPorted("MkLigatureDecomposer.decompose")

    /** Recomposes [group]'s constituents back into a single ligature, unless [force] is required by an edit-dirty check. */
    fun recompose(group: MkLigatureGroup, force: Boolean = false): MkLigatureGroup =
        throw MkNotYetPorted("MkLigatureDecomposer.recompose")

    /** The command that applies a decompose to [groupId] within [ownerNode]'s composition. */
    suspend fun decomposeCommand(
        groupId: MkNodeId,
        ownerNode: MkArrangedTextNode,
        options: MkDecomposeOptions = MkDecomposeOptions.fidelityDefault,
    ): MkCommand = throw MkNotYetPorted("MkLigatureDecomposer.decomposeCommand")

    /** The command that applies a recompose to [groupId] within [ownerNode]'s composition. */
    fun recomposeCommand(groupId: MkNodeId, ownerNode: MkArrangedTextNode, force: Boolean = false): MkCommand =
        throw MkNotYetPorted("MkLigatureDecomposer.recomposeCommand")
}
