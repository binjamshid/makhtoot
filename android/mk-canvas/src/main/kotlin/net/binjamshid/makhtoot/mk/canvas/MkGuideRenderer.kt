package net.binjamshid.makhtoot.mk.canvas

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

interface MkImpactFeedbackGenerating : Any {
    fun impactOccurred()
}

class MkGuideRenderer(
    val containerLayer: Any = CALayer(),
    var lineWidthPoints: Double = 1.0,
    var impactFeedbackGenerator: (MkImpactFeedbackGenerating)? = null
) {
    val color: Any
        get() = throw MkNotYetPorted("mk-canvas.MkGuideRenderer.color")
    fun update(guides: List<MkSnapGuide>, zoomScale: Double) { throw MkNotYetPorted("mk-canvas.MkGuideRenderer.update") }
    fun clear() { throw MkNotYetPorted("mk-canvas.MkGuideRenderer.clear") }
}


