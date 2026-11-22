package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkNodeId

class MkTextEditingOverlayController {
    fun begin(session: MkCanvasSession, nodeID: MkNodeId) { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayController.begin") }
    fun textDidChange(session: MkCanvasSession, newText: String, now: Double? = null) { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayController.textDidChange") }
    fun commit(session: MkCanvasSession) { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayController.commit") }
    fun cancel(session: MkCanvasSession) { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayController.cancel") }
    companion object {
        val burstWindow: Double = 0.7
    }
}

object MkTashkeelInput {
    val palette: List<Mark>? = null
    fun isValidBase(character: Char): Boolean { throw MkNotYetPorted("mk-canvas.MkTashkeelInput.isValidBase") }
    data class Mark(
        val insertedText: String,
        val symbol: String,
        val accessibilityLabel: String
    )
}

class MkTextEditingOverlayView(
    val textView: Any,
    val controller: MkTextEditingOverlayController = MkTextEditingOverlayController(),
    var onFinished: (() -> Unit)? = null
) : UIView {
    fun begin(session: MkCanvasSession, nodeID: MkNodeId, initialText: String) { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayView.begin") }
    fun commit() { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayView.commit") }
    fun cancel() { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayView.cancel") }
}

fun MkTextEditingOverlayView.textViewDidChange(textView: Any) { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayView.textViewDidChange") }
fun MkTextEditingOverlayView.textViewDidChangeSelection(textView: Any) { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayView.textViewDidChangeSelection") }
fun MkTextEditingOverlayView.textViewDidEndEditing(textView: Any) { throw MkNotYetPorted("mk-canvas.MkTextEditingOverlayView.textViewDidEndEditing") }

