package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.MkCanvasViewController
import net.binjamshid.makhtoot.mk.designsystem.MkTheme

data class MkCanvasHostView(
    val viewModel: MkEditorViewModel,
    val theme: MkTheme,
    val vc: Any? = null,
    val hostLayer: Any? = null
) : UIViewControllerRepresentable {
    fun makeUIViewController(context: Context): MkCanvasViewController { throw MkNotYetPorted("app.MkCanvasHostView.makeUIViewController") }
    fun updateUIViewController(vc: MkCanvasViewController, context: Context) { throw MkNotYetPorted("app.MkCanvasHostView.updateUIViewController") }
    fun makeCoordinator(): Coordinator { throw MkNotYetPorted("app.MkCanvasHostView.makeCoordinator") }
    class Coordinator
}

