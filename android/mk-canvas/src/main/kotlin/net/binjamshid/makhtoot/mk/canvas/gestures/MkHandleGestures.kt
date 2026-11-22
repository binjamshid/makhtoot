package net.binjamshid.makhtoot.mk.canvas.gestures

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.MkCanvasSession
import net.binjamshid.makhtoot.mk.canvas.geometry.MkHandleRole
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

class MkHandleGestures {
    val isActive: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkHandleGestures.isActive")
    fun beginResize(session: MkCanvasSession, handle: MkHandleRole) { throw MkNotYetPorted("mk-canvas.MkHandleGestures.beginResize") }
    fun updateResize(session: MkCanvasSession, worldDelta: MkPoint, fromCenter: Boolean = false, aspectLocked: Boolean? = null) { throw MkNotYetPorted("mk-canvas.MkHandleGestures.updateResize") }
    fun endResize(session: MkCanvasSession) { throw MkNotYetPorted("mk-canvas.MkHandleGestures.endResize") }
    fun beginRotate(session: MkCanvasSession, pointerStart: MkPoint) { throw MkNotYetPorted("mk-canvas.MkHandleGestures.beginRotate") }
    fun updateRotate(session: MkCanvasSession, pointerCurrent: MkPoint, snapping: Boolean) { throw MkNotYetPorted("mk-canvas.MkHandleGestures.updateRotate") }
    fun endRotate(session: MkCanvasSession) { throw MkNotYetPorted("mk-canvas.MkHandleGestures.endRotate") }
}

