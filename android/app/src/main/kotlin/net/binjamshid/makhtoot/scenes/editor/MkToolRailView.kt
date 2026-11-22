package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.fonts.MkFontRegistry
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect

class MkTourFramePreferenceKey : PreferenceKey {
    companion object {
        val defaultValue: Map<String, MkRect>
            get() = throw MkNotYetPorted("app.MkTourFramePreferenceKey.defaultValue")
        fun reduce(value: inout Map<String, MkRect>, nextValue: () -> Map<String, MkRect>) { throw MkNotYetPorted("app.MkTourFramePreferenceKey.reduce") }
    }
}

@androidx.compose.runtime.Composable
fun MkToolRailView(viewModel: MkEditorViewModel, fontRegistry: MkFontRegistry, axis: Axis, isRegularWidth: Boolean = false, showFontSettings: Boolean = false, showTextInsertSheet: Boolean = false, showAssetBrowser: Boolean = false, showBackgroundColorPicker: Boolean = false, showBackgroundImageSheet: Boolean = false, showMergeDesignSheet: Boolean = false, tourModel: MkEditorTourModel, railIconSize: Double = 17.0, bg: Any? = null) { }
@androidx.compose.runtime.Composable
fun MkToolRailView_content() { }
val MkToolRailView_fontSettingsLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.fontSettingsLabel")
val MkToolRailView_addObjectLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.addObjectLabel")
val MkToolRailView_addTextFieldLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.addTextFieldLabel")
val MkToolRailView_addShapeLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.addShapeLabel")
val MkToolRailView_addPathTextLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.addPathTextLabel")
val MkToolRailView_pathPresetArcLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.pathPresetArcLabel")
val MkToolRailView_pathPresetCircleLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.pathPresetCircleLabel")
val MkToolRailView_pathPresetWaveLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.pathPresetWaveLabel")
val MkToolRailView_pathPresetFreeformLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.pathPresetFreeformLabel")
val MkToolRailView_editPathLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.editPathLabel")
val MkToolRailView_arrangeModeLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.arrangeModeLabel")
val MkToolRailView_exitArrangeModeLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.exitArrangeModeLabel")
val MkToolRailView_arrangeModeHint: String
    get() = throw MkNotYetPorted("app.MkToolRailView.arrangeModeHint")
val MkToolRailView_arrangeDerivingLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.arrangeDerivingLabel")
val MkToolRailView_layersLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.layersLabel")
val MkToolRailView_inspectorLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.inspectorLabel")
val MkToolRailView_lockLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.lockLabel")
val MkToolRailView_hideLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.hideLabel")
val MkToolRailView_bringFrontLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.bringFrontLabel")
val MkToolRailView_sendBackLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.sendBackLabel")
val MkToolRailView_duplicateLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.duplicateLabel")
val MkToolRailView_groupLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.groupLabel")
val MkToolRailView_ungroupLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.ungroupLabel")
val MkToolRailView_copyLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.copyLabel")
val MkToolRailView_pasteLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.pasteLabel")
val MkToolRailView_flipHorizontalLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.flipHorizontalLabel")
val MkToolRailView_flipVerticalLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.flipVerticalLabel")
val MkToolRailView_flipProjectLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.flipProjectLabel")
val MkToolRailView_mergeDesignLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.mergeDesignLabel")
val MkToolRailView_selectAllLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.selectAllLabel")
val MkToolRailView_deselectAllLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.deselectAllLabel")
val MkToolRailView_deleteLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.deleteLabel")
val MkToolRailView_restartTourLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.restartTourLabel")
val MkToolRailView_moreActionsLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.moreActionsLabel")
val MkToolRailView_backgroundColorLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.backgroundColorLabel")
val MkToolRailView_backgroundImageLabel: String
    get() = throw MkNotYetPorted("app.MkToolRailView.backgroundImageLabel")

