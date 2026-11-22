package net.binjamshid.makhtoot.mk.arrange

import java.util.UUID
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.model.arranged.MkMarkNode
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

/**
 * Detach/reattach/move a tashkeel (diacritic) mark independently of its base
 * letter. Ports `Sources/MKArrange/MarkAttachmentController.swift`.
 */
class MkMarkAttachmentController {
    companion object {
        /** Whether a reattached mark automatically follows its new base's transform (always `true`, D-105). */
        fun attachedMarksFollowForFree(): Boolean = throw MkNotYetPorted("MkMarkAttachmentController.attachedMarksFollowForFree")

        /** The composition-world position of [mark] within [composition]. */
        fun worldPosition(mark: MkMarkNode, composition: MkArrangedComposition): MkPoint =
            throw MkNotYetPorted("MkMarkAttachmentController.worldPosition")
    }

    /** Detaches [mark] from its base, converting it to a free (absolutely-positioned) mark. */
    fun detach(mark: MkMarkNode, composition: MkArrangedComposition): MkMarkNode =
        throw MkNotYetPorted("MkMarkAttachmentController.detach")

    /** Reattaches [mark] to [targetId] as its new base, or `null` if the target is invalid. */
    fun reattach(mark: MkMarkNode, targetId: MkNodeId, composition: MkArrangedComposition): MkMarkNode? =
        throw MkNotYetPorted("MkMarkAttachmentController.reattach")

    /** Moves [mark] by [delta] (relative offset if attached, absolute position if free). */
    fun move(mark: MkMarkNode, delta: MkSize): MkMarkNode = throw MkNotYetPorted("MkMarkAttachmentController.move")

    /** The command that applies a detach to [markId] within [ownerNode]'s composition. */
    fun detachCommand(markId: MkNodeId, ownerNode: MkArrangedTextNode): MkCommand? =
        throw MkNotYetPorted("MkMarkAttachmentController.detachCommand")

    /** The command that applies a reattach of [markId] to [targetId] within [ownerNode]'s composition. */
    fun reattachCommand(markId: MkNodeId, targetId: MkNodeId, ownerNode: MkArrangedTextNode): MkCommand? =
        throw MkNotYetPorted("MkMarkAttachmentController.reattachCommand")

    /** The command that applies a move of [markId] by [delta] within [ownerNode]'s composition. */
    fun moveCommand(
        markId: MkNodeId,
        delta: MkSize,
        ownerNode: MkArrangedTextNode,
        gestureId: UUID = UUID.randomUUID(),
    ): MkCommand? = throw MkNotYetPorted("MkMarkAttachmentController.moveCommand")
}
