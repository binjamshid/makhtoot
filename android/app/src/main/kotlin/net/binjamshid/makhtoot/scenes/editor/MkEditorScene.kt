package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.fonts.MkFontRegistry
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize

@androidx.compose.runtime.Composable
fun MkEditorScene(projectID: MkProjectId, onDone: () -> Unit, viewModel: MkEditorViewModel? = null, openErrorText: String? = null, isClosing: Boolean = false, vm: Any? = null) { }
suspend fun MkEditorScene_open() { throw MkNotYetPorted("app.MkEditorScene.open") }
fun MkEditorScene_finish(viewModel: MkEditorViewModel) { throw MkNotYetPorted("app.MkEditorScene.finish") }
val MkEditorScene_isRegularWidth: Boolean
    get() = throw MkNotYetPorted("app.MkEditorScene.isRegularWidth")
val MkEditorScene_openErrorMissingPackage: String
    get() = throw MkNotYetPorted("app.MkEditorScene.openErrorMissingPackage")
val MkEditorScene_openErrorGeneric: String
    get() = throw MkNotYetPorted("app.MkEditorScene.openErrorGeneric")

@androidx.compose.runtime.Composable
fun MkEditorLoadingView() { }
val MkEditorLoadingView_loadingText: String
    get() = throw MkNotYetPorted("app.MkEditorLoadingView.loadingText")

@androidx.compose.runtime.Composable
fun MkEditorOpenErrorView(message: String, onDone: () -> Unit, iconSize: Double = 40.0) { }
val MkEditorOpenErrorView_doneLabel: String
    get() = throw MkNotYetPorted("app.MkEditorOpenErrorView.doneLabel")

@androidx.compose.runtime.Composable
fun MkEditorContentView(viewModel: MkEditorViewModel, fontRegistry: MkFontRegistry, isRegularWidth: Boolean, onDone: () -> Unit, tourModel: MkEditorTourModel = MkEditorTourModel(), exportURL: java.net.URI? = null, showsExportSheet: Boolean = false) { }
@androidx.compose.runtime.Composable
fun MkEditorContentView_primaryRail(axis: Axis, isRegularWidth: Boolean = false) { }
val MkEditorContentView_recomposeConfirmationTitle: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.recomposeConfirmationTitle")
val MkEditorContentView_recomposeConfirmAction: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.recomposeConfirmAction")
val MkEditorContentView_decomposeNoticeTitle: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.decomposeNoticeTitle")
val MkEditorContentView_okLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.okLabel")
val MkEditorContentView_reattachArmedText: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.reattachArmedText")
@androidx.compose.runtime.Composable
fun MkEditorContentView_regularLayout() { }
@androidx.compose.runtime.Composable
fun MkEditorContentView_compactLayout() { }
@androidx.compose.runtime.Composable
fun MkEditorContentView_canvasArea() { }
@androidx.compose.runtime.Composable
fun MkEditorContentView_panelToggleRow() { }
val MkEditorContentView_toolbarContent: ToolbarContent
    get() = throw MkNotYetPorted("app.MkEditorContentView.toolbarContent")
val MkEditorContentView_doneLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.doneLabel")
val MkEditorContentView_closeLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.closeLabel")
val MkEditorContentView_layersLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.layersLabel")
val MkEditorContentView_inspectorLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.inspectorLabel")
val MkEditorContentView_undoLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.undoLabel")
val MkEditorContentView_redoLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.redoLabel")
val MkEditorContentView_viewOptionsLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.viewOptionsLabel")
val MkEditorContentView_actualSizeLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.actualSizeLabel")
val MkEditorContentView_showGridLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.showGridLabel")
val MkEditorContentView_exportLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.exportLabel")
val MkEditorContentView_exportFailedTitle: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.exportFailedTitle")
val MkEditorContentView_debugMenuLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugMenuLabel")
val MkEditorContentView_debugTypeArabicLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugTypeArabicLabel")
val MkEditorContentView_debugArrangeLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugArrangeLabel")
val MkEditorContentView_debugMoveGlyphLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugMoveGlyphLabel")
val MkEditorContentView_debugMoveMarkLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugMoveMarkLabel")
val MkEditorContentView_debugBreakJoinLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugBreakJoinLabel")
val MkEditorContentView_debugSelectFormLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugSelectFormLabel")
val MkEditorContentView_debugDecomposeLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugDecomposeLabel")
val MkEditorContentView_debugRevertArrangedLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugRevertArrangedLabel")
val MkEditorContentView_debugAddCirclePathTextLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugAddCirclePathTextLabel")
val MkEditorContentView_debugTogglePathEditLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugTogglePathEditLabel")
val MkEditorContentView_debugDragPathAnchorLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugDragPathAnchorLabel")
val MkEditorContentView_debugDragPathGlyphLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugDragPathGlyphLabel")
val MkEditorContentView_debugForceMemoryLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugForceMemoryLabel")
val MkEditorContentView_debugMeasureManipulationLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugMeasureManipulationLabel")
val MkEditorContentView_debugShowPerfHUDLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugShowPerfHUDLabel")
val MkEditorContentView_debugHidePerfHUDLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugHidePerfHUDLabel")
val MkEditorContentView_debugApplyTransformLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugApplyTransformLabel")
val MkEditorContentView_debugDumpSnapshotLabel: String
    get() = throw MkNotYetPorted("app.MkEditorContentView.debugDumpSnapshotLabel")

enum class MkExportFormatOption {
    JPEG, PNG, PDF_RASTER, SVG, PDF_VECTOR;
    val id: MkExportFormatOption
        get() = throw MkNotYetPorted("app.MkExportFormatOption.id")
    val displayName: String
        get() = throw MkNotYetPorted("app.MkExportFormatOption.displayName")
    val purposeText: String
        get() = throw MkNotYetPorted("app.MkExportFormatOption.purposeText")
    fun resolvedPixelSize(canvasSize: MkSize): MkSize { throw MkNotYetPorted("app.MkExportFormatOption.resolvedPixelSize") }
}

@androidx.compose.runtime.Composable
fun MkExportFormatSheet(viewModel: MkEditorViewModel, entitlementProvider: MkEntitlementProviding, canvasSize: MkSize, onExported: (java.net.URI) -> Unit, size: Any? = null, width: Any? = null, height: Any? = null, percent: Any? = null, url: java.net.URI? = null) { }
@androidx.compose.runtime.Composable
fun MkExportFormatSheet_row(kind: MkExportFormatOption) { }
fun MkExportFormatSheet_dimensionsText(kind: MkExportFormatOption): String { throw MkNotYetPorted("app.MkExportFormatSheet.dimensionsText") }
fun MkExportFormatSheet_percentageText(fraction: Double): String { throw MkNotYetPorted("app.MkExportFormatSheet.percentageText") }
fun MkExportFormatSheet_perform(kind: MkExportFormatOption) { throw MkNotYetPorted("app.MkExportFormatSheet.perform") }
@androidx.compose.runtime.Composable
fun MkExportFormatSheet_formList() { }
@androidx.compose.runtime.Composable
fun MkExportFormatSheet_exportingView() { }
val MkExportFormatSheet_titleText: String
    get() = throw MkNotYetPorted("app.MkExportFormatSheet.titleText")
val MkExportFormatSheet_closeLabel: String
    get() = throw MkNotYetPorted("app.MkExportFormatSheet.closeLabel")
val MkExportFormatSheet_cancelLabel: String
    get() = throw MkNotYetPorted("app.MkExportFormatSheet.cancelLabel")
val MkExportFormatSheet_exportingText: String
    get() = throw MkNotYetPorted("app.MkExportFormatSheet.exportingText")

data class MkShareSheet(
    val items: List<Any>
) : UIViewControllerRepresentable {
    fun makeUIViewController(context: Context): UIActivityViewController { throw MkNotYetPorted("app.MkShareSheet.makeUIViewController") }
    fun updateUIViewController(uiViewController: UIActivityViewController, context: Context) { throw MkNotYetPorted("app.MkShareSheet.updateUIViewController") }
}

