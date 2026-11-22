package net.binjamshid.makhtoot.mk.persistence.undo

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkScene

class MkUndoStack(
    val maxEntries: Int = 500
) {
    val canUndo: Boolean
        get() = throw MkNotYetPorted("mk-persistence.MkUndoStack.canUndo")
    val canRedo: Boolean
        get() = throw MkNotYetPorted("mk-persistence.MkUndoStack.canRedo")
    fun setMaxEntries(newMax: Int) { throw MkNotYetPorted("mk-persistence.MkUndoStack.setMaxEntries") }
    fun beginGesture() { throw MkNotYetPorted("mk-persistence.MkUndoStack.beginGesture") }
    fun endGesture() { throw MkNotYetPorted("mk-persistence.MkUndoStack.endGesture") }
    fun perform(command: MkCommand, currentScene: MkScene): MkScene { throw MkNotYetPorted("mk-persistence.MkUndoStack.perform") }
    fun undoLast(currentScene: MkScene): MkScene? { throw MkNotYetPorted("mk-persistence.MkUndoStack.undoLast") }
    fun redoLast(currentScene: MkScene): MkScene? { throw MkNotYetPorted("mk-persistence.MkUndoStack.redoLast") }
}

fun MkUndoStack.accountedBytes(): Int { throw MkNotYetPorted("mk-persistence.MkUndoStack.accountedBytes") }
fun MkUndoStack.evictOffscreen() { throw MkNotYetPorted("mk-persistence.MkUndoStack.evictOffscreen") }
fun MkUndoStack.evictAll() { throw MkNotYetPorted("mk-persistence.MkUndoStack.evictAll") }

