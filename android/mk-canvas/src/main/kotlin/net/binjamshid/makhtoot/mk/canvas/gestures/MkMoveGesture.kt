package net.binjamshid.makhtoot.mk.canvas.gestures

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.MkCanvasSession
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

class MkMoveGesture {
    val isActive: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkMoveGesture.isActive")
    fun begin(session: MkCanvasSession, point: MkPoint) { throw MkNotYetPorted("mk-canvas.MkMoveGesture.begin") }
    fun update(session: MkCanvasSession, point: MkPoint, zoomScale: Double): CGVector { throw MkNotYetPorted("mk-canvas.MkMoveGesture.update") }
    fun end(session: MkCanvasSession) { throw MkNotYetPorted("mk-canvas.MkMoveGesture.end") }
    fun cancel(session: MkCanvasSession) { throw MkNotYetPorted("mk-canvas.MkMoveGesture.cancel") }
}

