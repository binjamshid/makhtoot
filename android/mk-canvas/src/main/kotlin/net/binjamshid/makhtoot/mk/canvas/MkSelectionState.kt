package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId

enum class MkSelectionGranularity {
    OBJECT, GLYPH, LETTER
}

data class MkSelectionState(
    var granularity: MkSelectionGranularity = MkSelectionGranularity.OBJECT,
    var compositionScope: MkNodeId? = null
) {
    val isEmpty: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkSelectionState.isEmpty")
    val count: Int
        get() = throw MkNotYetPorted("mk-canvas.MkSelectionState.count")
    val isMultiple: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkSelectionState.isMultiple")
    val single: MkNodeId?
        get() = throw MkNotYetPorted("mk-canvas.MkSelectionState.single")
    fun contains(id: MkNodeId): Boolean { throw MkNotYetPorted("mk-canvas.MkSelectionState.contains") }
    fun `set`(newIDs: Set<MkNodeId>) { throw MkNotYetPorted("mk-canvas.MkSelectionState.set") }
    fun toggle(id: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkSelectionState.toggle") }
    fun clear() { throw MkNotYetPorted("mk-canvas.MkSelectionState.clear") }
    companion object {
        val empty: MkSelectionState = MkSelectionState()
        fun selectable(candidates: Sequence<MkNodeId>, isLocked: (MkNodeId) -> Boolean, isHidden: (MkNodeId) -> Boolean): Set<MkNodeId> { throw MkNotYetPorted("mk-canvas.MkSelectionState.selectable") }
    }
}

