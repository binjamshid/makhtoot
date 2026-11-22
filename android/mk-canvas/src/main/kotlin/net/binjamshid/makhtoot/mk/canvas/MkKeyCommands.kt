package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkNudgeController {
    fun nudge(session: MkCanvasSession, direction: Direction, shiftPressed: Boolean, now: Double? = null) { throw MkNotYetPorted("mk-canvas.MkNudgeController.nudge") }
    fun endBurst(session: MkCanvasSession) { throw MkNotYetPorted("mk-canvas.MkNudgeController.endBurst") }
    companion object {
        val normalStep: Double = 1.0
        val shiftStep: Double = 10.0
        val burstWindow: Double = 0.5
    }
    object Direction {
    }
}

object MkCanvasKeyCommands {
    fun makeKeyCommands(target: Any, nudgeUp: Selector, nudgeDown: Selector, nudgeLeft: Selector, nudgeRight: Selector, nudgeUpBig: Selector, nudgeDownBig: Selector, nudgeLeftBig: Selector, nudgeRightBig: Selector, undo: Selector, redo: Selector, group: Selector, ungroup: Selector, duplicate: Selector, delete: Selector, copy: Selector, paste: Selector, selectAll: Selector, deselectAll: Selector, flipHorizontal: Selector, flipVertical: Selector): List<UIKeyCommand> { throw MkNotYetPorted("mk-canvas.MkCanvasKeyCommands.makeKeyCommands") }
}

