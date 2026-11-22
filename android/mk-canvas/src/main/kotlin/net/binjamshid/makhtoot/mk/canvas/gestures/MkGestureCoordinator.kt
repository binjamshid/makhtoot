package net.binjamshid.makhtoot.mk.canvas.gestures

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.MkCanvasSession
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeInteractionModel
import net.binjamshid.makhtoot.mk.canvas.geometry.MkHandleRole
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathTextInteractionModel
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

interface MkSelectionFeedbackGenerating : Any {
    fun selectionChanged()
}

class MkGestureCoordinator(
    var session: MkCanvasSession? = null,
    var hostView: UIView? = null,
    var onSelectionChromeNeedsUpdate: (() -> Unit)? = null,
    var selectionFeedbackGenerator: MkSelectionFeedbackGenerating = UISelectionFeedbackGenerator(),
    var arrangeInteraction: MkArrangeInteractionModel? = null,
    var pathTextInteraction: MkPathTextInteractionModel? = null,
    var marqueeContainModeEnabled: Boolean = false,
    var onArrangedNodeDoubleTapped: ((MkNodeId) -> Unit)? = null
) : Any {
    val zoomScaleProvider: () -> Double
        get() = throw MkNotYetPorted("mk-canvas.MkGestureCoordinator.zoomScaleProvider")
    fun beginHandleResize(handle: MkHandleRole) { throw MkNotYetPorted("mk-canvas.MkGestureCoordinator.beginHandleResize") }
    fun updateHandleResize(worldDelta: MkPoint, fromCenter: Boolean, aspectLocked: Boolean?) { throw MkNotYetPorted("mk-canvas.MkGestureCoordinator.updateHandleResize") }
    fun endHandleResize() { throw MkNotYetPorted("mk-canvas.MkGestureCoordinator.endHandleResize") }
    fun beginHandleRotate(pointerStart: MkPoint) { throw MkNotYetPorted("mk-canvas.MkGestureCoordinator.beginHandleRotate") }
    fun updateHandleRotate(pointerCurrent: MkPoint, snapping: Boolean) { throw MkNotYetPorted("mk-canvas.MkGestureCoordinator.updateHandleRotate") }
    fun endHandleRotate() { throw MkNotYetPorted("mk-canvas.MkGestureCoordinator.endHandleRotate") }
}


