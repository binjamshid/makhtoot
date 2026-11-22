package net.binjamshid.makhtoot.mk.canvas.pathtext

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D
import net.binjamshid.makhtoot.mk.model.MkBezierPathData

object MkPathEditChromeGeometry {
    val anchorDiameter: Double = 10.0
    val handleDiameter: Double = 6.0
    fun guidePath(path: MkBezierPathData, transform: MkTransform2D): Any { throw MkNotYetPorted("mk-canvas.MkPathEditChromeGeometry.guidePath") }
    fun connectorSegments(targets: List<MkPathHitTarget>): List<Pair<MkPoint, MkPoint>> { throw MkNotYetPorted("mk-canvas.MkPathEditChromeGeometry.connectorSegments") }
    fun dotRect(center: MkPoint, diameter: Double, zoomScale: Double): MkRect { throw MkNotYetPorted("mk-canvas.MkPathEditChromeGeometry.dotRect") }
}

class MkPathEditChromeLayer(
    val containerLayer: Any = CALayer(),
    var highlightColor: Any? = null
) {
    val strokeColor: Any
        get() = throw MkNotYetPorted("mk-canvas.MkPathEditChromeLayer.strokeColor")
    val dotFillColor: Any
        get() = throw MkNotYetPorted("mk-canvas.MkPathEditChromeLayer.dotFillColor")
    fun update(guidePath: Any?, targets: List<MkPathHitTarget>, selected: MkPathHandleId?, zoomScale: Double) { throw MkNotYetPorted("mk-canvas.MkPathEditChromeLayer.update") }
    fun clear() { throw MkNotYetPorted("mk-canvas.MkPathEditChromeLayer.clear") }
}

