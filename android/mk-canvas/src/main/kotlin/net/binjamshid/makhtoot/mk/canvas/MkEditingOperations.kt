package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

fun MkCanvasSession.selectAll() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.selectAll") }
fun MkCanvasSession.deselectAll() { throw MkNotYetPorted("mk-canvas.MkCanvasSession.deselectAll") }

fun MkCanvasSession.flipSelection(axis: FlipAxis) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.flipSelection") }
fun MkCanvasSession.flipScene(axis: FlipAxis) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.flipScene") }

enum class MkPasteError {
    EMPTY_OR_MALFORMED_PAYLOAD
}

fun MkCanvasSession.copySelectionPayloadData(): ByteArray? { throw MkNotYetPorted("mk-canvas.MkCanvasSession.copySelectionPayloadData") }
fun MkCanvasSession.paste(data: ByteArray) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.paste") }

fun MkCanvasSession.mergeDesign(url: java.net.URI) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.mergeDesign") }

fun MkCanvasSession.copySelectionToPasteboard(pasteboard: UIPasteboard? = null) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.copySelectionToPasteboard") }
fun MkCanvasSession.pasteFromPasteboard(pasteboard: UIPasteboard? = null) { throw MkNotYetPorted("mk-canvas.MkCanvasSession.pasteFromPasteboard") }

