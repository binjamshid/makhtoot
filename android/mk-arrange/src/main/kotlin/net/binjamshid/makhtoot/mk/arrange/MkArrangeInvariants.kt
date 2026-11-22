package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.MkError
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

/**
 * `mk-arrange`'s error taxonomy (follows the [MkError] pattern from
 * `mk-foundation`). Ports `Sources/MKArrange/ArrangeInvariants.swift`'s
 * `MKArrangeError`. `mk-arrange` reserves the `"arrange"` `MkErrorCode`
 * prefix.
 */
sealed class MkArrangeError : Exception(), MkError {
    /** Attempted a reshape-requiring mutation on an `arranged` node — INV: arranged nodes never reshape implicitly. */
    object ArrangedNodeCannotReshape : MkArrangeError()

    /** D-221's widened recompose dirty check tripped and `force` was not passed. */
    data class RecomposeBlockedByEdits(val editedNodeCount: Int) : MkArrangeError()

    /** `RevertService` found the backup's content hash did not match its own recomputed hash — INV-4. */
    object RevertBackupCorrupted : MkArrangeError()

    /** A command targeted a node id that is not an `arranged` node (or does not exist). */
    data class SourceNodeNotArranged(val nodeId: MkNodeId) : MkArrangeError()

    /** A command targeted an arranged-child id (glyph/mark/ligature) not present in the composition. */
    data class ChildNodeNotFound(val nodeId: MkNodeId) : MkArrangeError()

    /** Decompose was requested on a ligature group whose `decomposable == false`. */
    data class LigatureNotDecomposable(val nodeId: MkNodeId) : MkArrangeError()

    /** A join-break/restore/form-selection target was not a glyph node, or has no valid contextual forms. */
    data class InvalidJoinTarget(val nodeId: MkNodeId) : MkArrangeError()

    override val errorCode: String
        get() = throw MkNotYetPorted("MkArrangeError.errorCode")
    override val arabicUserMessage: String?
        get() = throw MkNotYetPorted("MkArrangeError.arabicUserMessage")
    override val underlying: Throwable?
        get() = throw MkNotYetPorted("MkArrangeError.underlying")
}

/**
 * Task 15's enforcement surface: arranged nodes may only be scaled/
 * transformed/style-edited, never reshaped. Ports `MKArrangeInvariants`.
 */
object MkArrangeInvariants {
    /** Throws [MkArrangeError.ArrangedNodeCannotReshape] if [kind] is `Arranged`. */
    fun assertReshapeAllowed(kind: MkArrangeNodeKind): Unit = throw MkNotYetPorted("MkArrangeInvariants.assertReshapeAllowed")
}

/**
 * Minimal discriminator so [MkArrangeInvariants.assertReshapeAllowed] doesn't
 * need the full node enum's pattern-matching machinery. Ports `MKArrangeNodeKind`.
 */
enum class MkArrangeNodeKind {
    Arranged,
    LiveOrPath,
}
