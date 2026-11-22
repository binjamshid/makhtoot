package net.binjamshid.makhtoot.mk.canvas.geometry

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

enum class MkHandleRole(val rawValue: String) {
    TOP_LEFT(""), TOP(""), TOP_RIGHT(""), RIGHT(""), BOTTOM_RIGHT(""), BOTTOM(""), BOTTOM_LEFT(""), LEFT(""), ROTATE("");
    val localUnitPosition: MkPoint
        get() = throw MkNotYetPorted("mk-canvas.MkHandleRole.localUnitPosition")
    val affectsX: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkHandleRole.affectsX")
    val affectsY: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkHandleRole.affectsY")
    val isCorner: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkHandleRole.isCorner")
}

object MkAnchoredResize {
    val rotateKnobOffset: Double = 44.0
    fun resize(obb: MkOrientedRect, handle: MkHandleRole, worldDelta: MkPoint, fromCenter: Boolean = false, aspectLocked: Boolean = false, minimumSize: Double = 1.0): MkOrientedRect { throw MkNotYetPorted("mk-canvas.MkAnchoredResize.resize") }
    fun rotate(startRotation: Double, startPointerAngle: Double, currentPointerAngle: Double, snapping: Boolean): Double { throw MkNotYetPorted("mk-canvas.MkAnchoredResize.rotate") }
    fun snappedAngle(angle: Double, gridStep: Double? = null, magneticThreshold: Double? = null): Double { throw MkNotYetPorted("mk-canvas.MkAnchoredResize.snappedAngle") }
}

