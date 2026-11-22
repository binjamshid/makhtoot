package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.model.MkBezierPathData

@androidx.compose.runtime.Composable
fun MkPathGhostGuideOverlay(viewModel: MkEditorViewModel, zoomScale: Double = 1.0, contentOffset: MkPoint? = null) { }
suspend fun MkPathGhostGuideOverlay_pollTransform() { throw MkNotYetPorted("app.MkPathGhostGuideOverlay.pollTransform") }

data class MkGhostGuideShape(
    val pathData: MkBezierPathData,
    val zoomScale: Double,
    val contentOffset: MkPoint,
    val cgPath: pathData.cgPath = pathData.cgPath(),
    var transform: Any? = null
) : Shape {
    fun path(rect: MkRect): Path { throw MkNotYetPorted("app.MkGhostGuideShape.path") }
}

