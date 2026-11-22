package net.binjamshid.makhtoot.mk.canvas.geometry

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkTransform2D

object MkGroupTransform {
    fun worldTransform(childLocal: MkTransform2D, groupTransform: MkTransform2D): MkTransform2D { throw MkNotYetPorted("mk-canvas.MkGroupTransform.worldTransform") }
    fun localTransform(childWorld: MkTransform2D, groupTransform: MkTransform2D): MkTransform2D { throw MkNotYetPorted("mk-canvas.MkGroupTransform.localTransform") }
}

