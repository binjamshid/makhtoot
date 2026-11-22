package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect

class MkEditorTourModel(
    var addButtonFrame: MkRect? = null,
    var fontButtonFrame: MkRect? = null,
    var arrangeButtonFrame: MkRect? = null,
    var step: Int = 0,
    var isCompleted: Boolean? = null,
    val stepCount: Int = 3
) {
    val isLastStep: Boolean
        get() = throw MkNotYetPorted("app.MkEditorTourModel.isLastStep")
    val currentHighlightFrame: MkRect
        get() = throw MkNotYetPorted("app.MkEditorTourModel.currentHighlightFrame")
    val currentTitle: String
        get() = throw MkNotYetPorted("app.MkEditorTourModel.currentTitle")
    val currentBody: String
        get() = throw MkNotYetPorted("app.MkEditorTourModel.currentBody")
    fun advance() { throw MkNotYetPorted("app.MkEditorTourModel.advance") }
    fun skip() { throw MkNotYetPorted("app.MkEditorTourModel.skip") }
    fun restart() { throw MkNotYetPorted("app.MkEditorTourModel.restart") }
}

