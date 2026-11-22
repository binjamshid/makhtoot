package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId

sealed class MkCanvasMode {
    object Browse : MkCanvasMode()
    data class EditText(val nodeID: MkNodeId) : MkCanvasMode()
    data class Arrange(val nodeID: MkNodeId) : MkCanvasMode()
    data class PathEdit(val nodeID: MkNodeId) : MkCanvasMode()
    val isEditingText: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasMode.isEditingText")
    val scopedNodeID: MkNodeId?
        get() = throw MkNotYetPorted("mk-canvas.MkCanvasMode.scopedNodeID")
}

