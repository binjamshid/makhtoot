package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeFormOption
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeFormSelectorModel
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkPathData
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm

@androidx.compose.runtime.Composable
fun MkFormSelectorPopoverView(model: MkArrangeFormSelectorModel, onSelect: (MkJoiningForm) -> Unit, onDismiss: () -> Unit, order: List<MkJoiningForm>? = null, index: Any = startIndex, candidate: Any? = null) { }
fun MkFormSelectorPopoverView_adjacentValidForm(form: MkJoiningForm, step: Int): MkJoiningForm? { throw MkNotYetPorted("app.MkFormSelectorPopoverView.adjacentValidForm") }
fun MkFormSelectorPopoverView_label(form: MkJoiningForm): String { throw MkNotYetPorted("app.MkFormSelectorPopoverView.label") }
val MkFormSelectorPopoverView_option: Any
    get() = throw MkNotYetPorted("app.MkFormSelectorPopoverView.option")
val MkFormSelectorPopoverView_title: String
    get() = throw MkNotYetPorted("app.MkFormSelectorPopoverView.title")
val MkFormSelectorPopoverView_dismissLabel: String
    get() = throw MkNotYetPorted("app.MkFormSelectorPopoverView.dismissLabel")
val MkFormSelectorPopoverView_previousFormLabel: String
    get() = throw MkNotYetPorted("app.MkFormSelectorPopoverView.previousFormLabel")
val MkFormSelectorPopoverView_nextFormLabel: String
    get() = throw MkNotYetPorted("app.MkFormSelectorPopoverView.nextFormLabel")

@androidx.compose.runtime.Composable
fun MkFormOptionTile(option: MkArrangeFormOption? = null, isCurrent: Boolean, label: String, action: () -> Unit) { }

data class MkGlyphOutlineShape(
    val pathData: MkPathData,
    val advance: MkSize,
    val cgPath: Any? = null,
    val bounds: Any? = null,
    val scale: Any? = null,
    var transform: Any? = null
) : Shape {
    fun path(rect: MkRect): Path { throw MkNotYetPorted("app.MkGlyphOutlineShape.path") }
}

