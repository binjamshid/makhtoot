package net.binjamshid.makhtoot.mk.arrange

import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.foundation.stubs.MkSystemFontStubProvider
import net.binjamshid.makhtoot.mk.model.MkPathData
import net.binjamshid.makhtoot.mk.model.MkTextStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedComposition
import net.binjamshid.makhtoot.mk.model.arranged.MkArrangedTextNode
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm
import net.binjamshid.makhtoot.mk.persistence.undo.MkCommand

/** One candidate contextual form for a letter's form-selector UI. Ports `MKFormOption`. */
data class MkFormOption(
    var form: MkJoiningForm,
    var isValid: Boolean,
    var achieved: Boolean,
    var previewOutline: MkPathData?,
    var previewAdvance: MkSize,
    var glyphID: Int,
)

/**
 * Builds/holds the set of contextual-form candidates for one glyph node, and
 * the command to apply a user's selection. Ports
 * `Sources/MKArrange/FormSelectorModel.swift`'s `FormSelectorModel`.
 */
data class MkFormSelectorModel(
    var nodeId: MkNodeId,
    var scalar: Long,
    var currentForm: MkJoiningForm,
    var options: List<MkFormOption>,
) {
    companion object {
        /** Builds the model for [nodeId] within [composition], or `null` if the node is not a glyph node. */
        suspend fun build(
            nodeId: MkNodeId,
            composition: MkArrangedComposition,
            style: MkTextStyle,
            fonts: MkFontProviding = MkSystemFontStubProvider(),
        ): MkFormSelectorModel? = throw MkNotYetPorted("MkFormSelectorModel.build")
    }

    /** The command that applies [form] as the selected contextual form. */
    fun command(form: MkJoiningForm, ownerNode: MkArrangedTextNode): MkCommand? =
        throw MkNotYetPorted("MkFormSelectorModel.command")
}
