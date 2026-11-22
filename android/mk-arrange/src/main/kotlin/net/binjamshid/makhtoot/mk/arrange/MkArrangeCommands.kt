package net.binjamshid.makhtoot.mk.arrange

import java.util.UUID
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.MkNodeCore
import net.binjamshid.makhtoot.mk.model.MkStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangeOrigin
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

/**
 * Every arrange mutation is an [MkCommand] (`mk-persistence`'s undo stack).
 * Ports `Sources/MKArrange/ArrangeCommands.swift`'s `ArrangeCommands` enum.
 */
object MkArrangeCommands {
    /** Converts a `.liveText`/`.pathText` node into `.arranged`, same [MkNodeCore] preserved. */
    fun arrangeCommand(
        sourceNodeId: MkNodeId,
        core: MkNodeCore,
        composition: MkArrangedComposition,
        origin: MkArrangeOrigin,
    ): MkCommand = throw MkNotYetPorted("MkArrangeCommands.arrangeCommand")

    /** The composition-internal mutation primitive every controller in this module builds its command through. */
    fun replaceComposition(
        ownerNode: MkArrangedTextNode,
        newComposition: MkArrangedComposition,
        label: String,
        coalescingKeySuffix: String? = null,
    ): MkCommand = throw MkNotYetPorted("MkArrangeCommands.replaceComposition")
}

/**
 * Thin, coalescable command builders over one selection of arranged children.
 * Ports `ArrangeStyleEditor` (also in `ArrangeCommands.swift`).
 */
object MkArrangeStyleEditor {
    /** Sets [style] (fill/stroke/shadow) on every child in [ids]. */
    fun setStyle(
        style: MkStyle,
        ids: Set<MkNodeId>,
        ownerNode: MkArrangedTextNode,
        gestureId: UUID = UUID.randomUUID(),
    ): MkCommand = throw MkNotYetPorted("MkArrangeStyleEditor.setStyle")

    /** Sets [opacity] on every child in [ids] (folded into `style.fill`'s alpha channel). */
    fun setOpacity(
        opacity: Double,
        ids: Set<MkNodeId>,
        ownerNode: MkArrangedTextNode,
        gestureId: UUID = UUID.randomUUID(),
    ): MkCommand = throw MkNotYetPorted("MkArrangeStyleEditor.setOpacity")

    /** Sets the per-child [transform] (position/rotation/scale) directly. */
    fun setTransform(
        transform: MkTransform2D,
        id: MkNodeId,
        ownerNode: MkArrangedTextNode,
        gestureId: UUID = UUID.randomUUID(),
    ): MkCommand = throw MkNotYetPorted("MkArrangeStyleEditor.setTransform")

    /** Baseline shift: adds [delta] points to a child's `transform.position.y` in composition-local (y-up) space. */
    fun nudgeBaseline(
        delta: Double,
        id: MkNodeId,
        ownerNode: MkArrangedTextNode,
        gestureId: UUID = UUID.randomUUID(),
    ): MkCommand = throw MkNotYetPorted("MkArrangeStyleEditor.nudgeBaseline")

    /** Kerning-like nudge: adds [delta] to a child's `transform.position` in composition-local space. */
    fun nudgePosition(
        delta: MkSize,
        id: MkNodeId,
        ownerNode: MkArrangedTextNode,
        gestureId: UUID = UUID.randomUUID(),
    ): MkCommand = throw MkNotYetPorted("MkArrangeStyleEditor.nudgePosition")
}
