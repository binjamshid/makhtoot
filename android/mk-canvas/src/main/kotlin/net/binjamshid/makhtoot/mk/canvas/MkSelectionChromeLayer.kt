package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.geometry.MkHandleRole
import net.binjamshid.makhtoot.mk.canvas.geometry.MkOrientedRect
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint

object MkSelectionHandleLayout {
    val handleDiameter: Double = 10.0
    val grabRadiusScreenPoints: Double? = null
    fun worldPosition(handle: MkHandleRole, obb: MkOrientedRect, zoomScale: Double = 1.0): MkPoint { throw MkNotYetPorted("mk-canvas.MkSelectionHandleLayout.worldPosition") }
    fun allHandlePositions(obb: MkOrientedRect, zoomScale: Double = 1.0): Map<MkHandleRole, MkPoint> { throw MkNotYetPorted("mk-canvas.MkSelectionHandleLayout.allHandlePositions") }
    fun handle(point: MkPoint, obb: MkOrientedRect, zoomScale: Double): MkHandleRole? { throw MkNotYetPorted("mk-canvas.MkSelectionHandleLayout.handle") }
}

class MkSelectionChromeLayer(
    val containerLayer: Any = CALayer()
) {
    val strokeColor: Any
        get() = throw MkNotYetPorted("mk-canvas.MkSelectionChromeLayer.strokeColor")
    val handleFillColor: Any
        get() = throw MkNotYetPorted("mk-canvas.MkSelectionChromeLayer.handleFillColor")
    val differentiateWithoutColor: Boolean
        get() = throw MkNotYetPorted("mk-canvas.MkSelectionChromeLayer.differentiateWithoutColor")
    fun update(obbs: List<MkOrientedRect>, handleAnchor: MkOrientedRect?, zoomScale: Double) { throw MkNotYetPorted("mk-canvas.MkSelectionChromeLayer.update") }
    fun clear() { throw MkNotYetPorted("mk-canvas.MkSelectionChromeLayer.clear") }
}

