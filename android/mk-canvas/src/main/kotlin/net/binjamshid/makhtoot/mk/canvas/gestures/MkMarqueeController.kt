package net.binjamshid.makhtoot.mk.canvas.gestures

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.MkHitCandidate
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect

enum class MkMarqueeMode {
    INTERSECT, CONTAIN
}

object MkMarqueeController {
    fun rect(start: MkPoint, current: MkPoint): MkRect { throw MkNotYetPorted("mk-canvas.MkMarqueeController.rect") }
    fun select(marquee: MkRect, candidates: List<MkHitCandidate>, mode: MkMarqueeMode): Set<MkNodeId> { throw MkNotYetPorted("mk-canvas.MkMarqueeController.select") }
}

