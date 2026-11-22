package net.binjamshid.makhtoot.mk.canvas.geometry

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D

data class MkOrientedRect(
    var center: MkPoint,
    var size: MkSize,
    var rotation: Double
) {
    val corners: List<MkPoint>
        get() = throw MkNotYetPorted("mk-canvas.MkOrientedRect.corners")
    val axisAlignedBounds: MkRect
        get() = throw MkNotYetPorted("mk-canvas.MkOrientedRect.axisAlignedBounds")
    fun worldToLocal(p: MkPoint): MkPoint { throw MkNotYetPorted("mk-canvas.MkOrientedRect.worldToLocal") }
    fun localToWorld(p: MkPoint): MkPoint { throw MkNotYetPorted("mk-canvas.MkOrientedRect.localToWorld") }
    fun contains(p: MkPoint, tolerance: Double = 0.0): Boolean { throw MkNotYetPorted("mk-canvas.MkOrientedRect.contains") }
    fun derivingTransform(localBounds: MkRect): MkTransform2D { throw MkNotYetPorted("mk-canvas.MkOrientedRect.derivingTransform") }
    companion object {
        fun unionBounds(rects: List<MkOrientedRect>): MkRect? { throw MkNotYetPorted("mk-canvas.MkOrientedRect.unionBounds") }
    }
}

