package net.binjamshid.makhtoot.scenes.editor

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.assets.browser.MkAssetBrowserModel
import net.binjamshid.makhtoot.mk.assets.model.MkAssetDescriptor
import net.binjamshid.makhtoot.mk.canvas.MkCanvasMode
import net.binjamshid.makhtoot.mk.canvas.MkCanvasSession
import net.binjamshid.makhtoot.mk.canvas.MkCanvasViewController
import net.binjamshid.makhtoot.mk.canvas.MkInspectorModel
import net.binjamshid.makhtoot.mk.canvas.MkLayersModel
import net.binjamshid.makhtoot.mk.canvas.MkSelectionGranularity
import net.binjamshid.makhtoot.mk.canvas.MkTextEditingOverlayView
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeFormSelectorModel
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeInteractionModel
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeRecomposePreflight
import net.binjamshid.makhtoot.mk.canvas.arrange.MkArrangeRevertPreflight
import net.binjamshid.makhtoot.mk.canvas.pathtext.MkPathTextInteractionModel
import net.binjamshid.makhtoot.mk.export.MkExportCancellationToken
import net.binjamshid.makhtoot.mk.export.MkExportCoordinator
import net.binjamshid.makhtoot.mk.export.MkExportRequest
import net.binjamshid.makhtoot.mk.foundation.MkMemoryGovernor
import net.binjamshid.makhtoot.mk.foundation.MkNodeId
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementProviding
import net.binjamshid.makhtoot.mk.foundation.geometry.MkPoint
import net.binjamshid.makhtoot.mk.foundation.geometry.MkRect
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.stubs.MkFontProviding
import net.binjamshid.makhtoot.mk.model.MkBezierPathData
import net.binjamshid.makhtoot.mk.model.MkScene
import net.binjamshid.makhtoot.mk.model.MkTextStyle
import net.binjamshid.makhtoot.mk.model.arranged.MkJoiningForm
import net.binjamshid.makhtoot.mk.persistence.MkCrashRecoveryResult
import net.binjamshid.makhtoot.mk.persistence.MkMakhtootDocument
import net.binjamshid.makhtoot.mk.persistence.MkSaveReason
import net.binjamshid.makhtoot.mk.render.MkAutosaveTriggering
import net.binjamshid.makhtoot.mk.render.MkDegradationController
import net.binjamshid.makhtoot.mk.render.MkMemoryPressureMonitor
import net.binjamshid.makhtoot.mk.render.MkMemoryStage
import net.binjamshid.makhtoot.stubs.MkProjectLibraryProviding

class MkEditorViewModel(
    val projectID: MkProjectId,
    val packageURL: java.net.URI,
    val document: MkMakhtootDocument,
    val session: MkCanvasSession,
    val layers: MkLayersModel,
    val inspector: MkInspectorModel,
    val renderAdapter: MkCanvasRenderAdapter,
    val recovery: MkCrashRecoveryResult,
    val projectLibrary: MkProjectLibraryProviding,
    val fontProvider: MkFontProviding,
    val assetProvider: MkDocumentAssetProvider,
    val arrangeInteraction: MkArrangeInteractionModel,
    val arrangeAdapter: MkArrangeInteractionAdapter,
    val pathTextInteraction: MkPathTextInteractionModel,
    val pathTextAdapter: MkPathTextInteractionAdapter,
    var presentedPathOptions: Boolean = false,
    var showsPathGhostGuide: Boolean = false,
    var arrangeSourceEditConflictNodeID: MkNodeId? = null,
    var pendingRevertPreflight: MkArrangeRevertPreflight? = null,
    var presentedFormSelectorModel: MkArrangeFormSelectorModel? = null,
    var pendingRecomposeConfirmation: Pair<MkNodeId, MkArrangeRecomposePreflight>? = null,
    var decomposeFidelityNotice: String? = null,
    var pendingMarkReattachID: MkNodeId? = null,
    var showsLayersColumn: Boolean = false,
    var showsInspectorColumn: Boolean = false,
    var presentedPanel: MkEditorPanel? = null,
    var showsPerfHUD: Boolean = false,
    var lastManipulationFrameDuration: Double = 0.0,
    var isDirty: Boolean = false,
    var lastMutationAt: java.time.Instant? = null,
    var memoryBannerText: String? = null,
    val degradation: MkDegradationController,
    var memoryMonitor: MkMemoryPressureMonitor? = null,
    var sceneObservationTask: Task<Unit, Never>? = null,
    var dirtyClearTask: Task<Unit, Never>? = null,
    var memoryPollTask: Task<Unit, Never>? = null,
    var lastReportedZoomScale: Double = 1.0,
    var currentZoomScale: Double = 1.0,
    var lastObservedMode: MkCanvasMode? = null,
    var lastObservedSelectionIDs: Set<MkNodeId>? = null,
    var didEnterBackgroundObserver: NSObjectProtocol? = null,
    var didBecomeActiveObserver: NSObjectProtocol? = null,
    var canvasViewController: MkCanvasViewController? = null,
    var overlayView: MkTextEditingOverlayView? = null,
    var pendingRestorationState: EditorRestorationState? = null,
    var lastRestorationPersistAt: java.time.Instant? = null,
    val governor: MkMemoryGovernor = MkMemoryGovernor(),
    val screenScale: Any? = null,
    val layerTree: Any? = null,
    val adapter: Any? = null,
    val openedScene: Any? = null,
    val stream: Any? = null,
    var isFirst: Boolean = true,
    val monitor: Any? = null,
    val newText: Any? = null,
    val center: Any? = null,
    val visibleRect: Any? = null,
    val scrollView: Any? = null,
    val clampedZoom: Any? = null,
    val state: Any? = null,
    val newlySelected: Any? = null,
    var isExporting: Boolean = false,
    var exportProgress: Double? = null,
    var exportCancellationToken: MkExportCancellationToken? = null,
    var exportFailureMessage: String? = null,
    val token: MkExportCancellationToken = MkExportCancellationToken(),
    val progressStream: Any? = null,
    val result: Any? = null,
    val request: Any? = null,
    val coordinator: Any? = null,
    val url: Any? = null,
    val canvasSize: Any? = null,
    val scene: Any? = null,
    val library: Any? = null,
    var manifest: Any? = null,
    val cap: Double = 600.0,
    val scale: Any? = null,
    val region: Any? = null,
    val renderer: Any? = null,
    val anchored: Any? = null,
    val shortSide: Any? = null,
    val lines: Any? = null,
    val lineHeight: Any? = null,
    val spaceWidth: Any? = null,
    val spacing: Any? = null,
    val blockWidth: Any? = null,
    val blockHeight: Any? = null,
    val canvasCenter: Any? = null,
    val blockOrigin: Any? = null,
    var createdTopLevelIDs: List<MkNodeId> = emptyList(),
    val lineY: Any? = null,
    val lineLeftX: Double,
    var cursorX: Any? = null,
    var lineNodeIDs: List<MkNodeId> = emptyList(),
    val position: Any? = null,
    var core: Any? = null,
    val node: Any? = null,
    val wrapped: Any? = null,
    val rawLines: Any = text,
    val edge: Any? = null,
    val unitCornerRadius: Any? = null,
    var style: Any? = null,
    val outcome: Any? = null,
    val maxPixelSize: Any? = null,
    val ref: Any? = null,
    val fit: Any? = null,
    val path: MkBezierPathData,
    val radius: Any? = null,
    val width: Any? = null,
    val rect: Any? = null,
    val left: Any? = null,
    val top: Any? = null,
    val right: Any? = null,
    val anchors: List<String>? = null,
    val neighbors: Any? = null,
    val autoRefused: Any? = null,
    val renderBridge: Any? = null,
    val clock: ContinuousClock = ContinuousClock(),
    val start: Any? = null,
    val dx: Any? = null,
    val transform: Any? = null,
    val totalSeconds: Any? = null,
    val perFrame: Any? = null,
    val uiImage: Any? = null,
    var undoCount: Int = 0,
    val target: Any? = null,
    val lut: Any? = null,
    val sampleCount: Int = 32,
    val length: Any? = null,
    val point: Any? = null,
    val optionsGestureID: java.util.UUID = java.util.UUID.randomUUID(),
    val encoder: JSONEncoder = JSONEncoder(),
    val frame: Any? = null,
    val overlay: Any? = null,
    val height: Any? = null,
    val originX: Any? = null,
    val originY: Any? = null
) {
    val arrangedGhostGuidePath: MkBezierPathData?
        get() = throw MkNotYetPorted("app.MkEditorViewModel.arrangedGhostGuidePath")
    val validIDs: Any
        get() = throw MkNotYetPorted("app.MkEditorViewModel.validIDs")
    val selectedTextForFontSettings: String
        get() = throw MkNotYetPorted("app.MkEditorViewModel.selectedTextForFontSettings")
    val progressTask: Any
        get() = throw MkNotYetPorted("app.MkEditorViewModel.progressTask")
    val defaultTextColorLabel: String
        get() = throw MkNotYetPorted("app.MkEditorViewModel.defaultTextColorLabel")
    val measuredLines: List<Pair<List<Pair<String, MkSize>>, Double>>
        get() = throw MkNotYetPorted("app.MkEditorViewModel.measuredLines")
    val measured: Any
        get() = throw MkNotYetPorted("app.MkEditorViewModel.measured")
    val width: Any
        get() = throw MkNotYetPorted("app.MkEditorViewModel.width")
    val lineGroupLabel: String
        get() = throw MkNotYetPorted("app.MkEditorViewModel.lineGroupLabel")
    val hasSelection: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.hasSelection")
    val hasMultipleSelected: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.hasMultipleSelected")
    val hasSingleSelection: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.hasSingleSelection")
    val canCopySelection: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canCopySelection")
    val canFlipProject: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canFlipProject")
    val canToggleArrangeMode: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canToggleArrangeMode")
    val canTogglePathEditMode: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canTogglePathEditMode")
    val canBreakOrRestoreJoinForSelection: (breakNext: Boolean, breakPrevious: Boolean, restoreNext: Boolean, restorePrevious: Boolean)
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canBreakOrRestoreJoinForSelection")
    val canDecomposeSelection: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canDecomposeSelection")
    val canDetachSelectedMark: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canDetachSelectedMark")
    val decomposeFidelityAutoRefusedText: String
        get() = throw MkNotYetPorted("app.MkEditorViewModel.decomposeFidelityAutoRefusedText")
    val canUndo: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canUndo")
    val canRedo: Boolean
        get() = throw MkNotYetPorted("app.MkEditorViewModel.canRedo")
    val elapsed: Any
        get() = throw MkNotYetPorted("app.MkEditorViewModel.elapsed")
    val glyphs: Any
        get() = throw MkNotYetPorted("app.MkEditorViewModel.glyphs")
    fun startSceneObservation() { throw MkNotYetPorted("app.MkEditorViewModel.startSceneObservation") }
    fun startMemoryLadder(degradation: MkDegradationController) { throw MkNotYetPorted("app.MkEditorViewModel.startMemoryLadder") }
    fun startMemoryBannerPoll() { throw MkNotYetPorted("app.MkEditorViewModel.startMemoryBannerPoll") }
    fun observeScenePhaseForMemoryLadder() { throw MkNotYetPorted("app.MkEditorViewModel.observeScenePhaseForMemoryLadder") }
    fun attach(canvasViewController: MkCanvasViewController) { throw MkNotYetPorted("app.MkEditorViewModel.attach") }
    fun restoreViewportIfNeeded() { throw MkNotYetPorted("app.MkEditorViewModel.restoreViewportIfNeeded") }
    fun persistRestorationCheckpoint() { throw MkNotYetPorted("app.MkEditorViewModel.persistRestorationCheckpoint") }
    fun persistRestorationCheckpointThrottled() { throw MkNotYetPorted("app.MkEditorViewModel.persistRestorationCheckpointThrottled") }
    fun startModeAndSelectionObservation() { throw MkNotYetPorted("app.MkEditorViewModel.startModeAndSelectionObservation") }
    fun trackModeAndSelection() { throw MkNotYetPorted("app.MkEditorViewModel.trackModeAndSelection") }
    fun handleModeOrSelectionChange() { throw MkNotYetPorted("app.MkEditorViewModel.handleModeOrSelectionChange") }
    fun syncOverlay() { throw MkNotYetPorted("app.MkEditorViewModel.syncOverlay") }
    fun cancelActiveExport() { throw MkNotYetPorted("app.MkEditorViewModel.cancelActiveExport") }
    suspend fun runExport(request: MkExportRequest, coordinator: MkExportCoordinator, entitlement: MkEntitlementProviding): java.net.URI? { throw MkNotYetPorted("app.MkEditorViewModel.runExport") }
    suspend fun exportForSharing(entitlement: MkEntitlementProviding): java.net.URI? { throw MkNotYetPorted("app.MkEditorViewModel.exportForSharing") }
    suspend fun exportPNGForSharing(entitlement: MkEntitlementProviding): java.net.URI? { throw MkNotYetPorted("app.MkEditorViewModel.exportPNGForSharing") }
    suspend fun exportSVGForSharing(entitlement: MkEntitlementProviding): java.net.URI? { throw MkNotYetPorted("app.MkEditorViewModel.exportSVGForSharing") }
    suspend fun exportPDFVectorForSharing(entitlement: MkEntitlementProviding): java.net.URI? { throw MkNotYetPorted("app.MkEditorViewModel.exportPDFVectorForSharing") }
    suspend fun exportPDFRasterForSharing(entitlement: MkEntitlementProviding): java.net.URI? { throw MkNotYetPorted("app.MkEditorViewModel.exportPDFRasterForSharing") }
    suspend fun close() { throw MkNotYetPorted("app.MkEditorViewModel.close") }
    fun generateThumbnailInBackground() { throw MkNotYetPorted("app.MkEditorViewModel.generateThumbnailInBackground") }
    suspend fun renderThumbnailPNG(scene: MkScene, assetProvider: MkDocumentAssetProvider, fontProvider: MkFontProviding): ByteArray? { throw MkNotYetPorted("app.MkEditorViewModel.renderThumbnailPNG") }
    fun markDirty() { throw MkNotYetPorted("app.MkEditorViewModel.markDirty") }
    suspend fun saveNow() { throw MkNotYetPorted("app.MkEditorViewModel.saveNow") }
    fun refreshCanvasChrome() { throw MkNotYetPorted("app.MkEditorViewModel.refreshCanvasChrome") }
    fun addLiveTextAtCenter(): MkNodeId? { throw MkNotYetPorted("app.MkEditorViewModel.addLiveTextAtCenter") }
    fun insertTextFromSheet(fullText: String, style: MkTextStyle, splitBySpaces: Boolean, groupLines: Boolean, alignment: TextInsertAlignment): List<MkNodeId> { throw MkNotYetPorted("app.MkEditorViewModel.insertTextFromSheet") }
    fun insertSingleLiveText(text: String, style: MkTextStyle, position: MkPoint): MkNodeId? { throw MkNotYetPorted("app.MkEditorViewModel.insertSingleLiveText") }
    fun addRectangleAtCenter(): MkNodeId? { throw MkNotYetPorted("app.MkEditorViewModel.addRectangleAtCenter") }
    suspend fun placeAsset(descriptor: MkAssetDescriptor, model: MkAssetBrowserModel): MkAssetBrowserModel.PlacementOutcome { throw MkNotYetPorted("app.MkEditorViewModel.placeAsset") }
    suspend fun setBackgroundImage(data: ByteArray): BackgroundImageOutcome { throw MkNotYetPorted("app.MkEditorViewModel.setBackgroundImage") }
    fun toggleBackgroundImageFit() { throw MkNotYetPorted("app.MkEditorViewModel.toggleBackgroundImageFit") }
    fun removeBackgroundImage() { throw MkNotYetPorted("app.MkEditorViewModel.removeBackgroundImage") }
    fun groupSelection() { throw MkNotYetPorted("app.MkEditorViewModel.groupSelection") }
    fun ungroupSelection() { throw MkNotYetPorted("app.MkEditorViewModel.ungroupSelection") }
    fun deleteSelection() { throw MkNotYetPorted("app.MkEditorViewModel.deleteSelection") }
    fun duplicateSelection() { throw MkNotYetPorted("app.MkEditorViewModel.duplicateSelection") }
    fun toggleLockForSelection() { throw MkNotYetPorted("app.MkEditorViewModel.toggleLockForSelection") }
    fun toggleHideForSelection() { throw MkNotYetPorted("app.MkEditorViewModel.toggleHideForSelection") }
    fun bringSelectionToFront() { throw MkNotYetPorted("app.MkEditorViewModel.bringSelectionToFront") }
    fun sendSelectionToBack() { throw MkNotYetPorted("app.MkEditorViewModel.sendSelectionToBack") }
    fun selectAll() { throw MkNotYetPorted("app.MkEditorViewModel.selectAll") }
    fun deselectAll() { throw MkNotYetPorted("app.MkEditorViewModel.deselectAll") }
    fun copySelection() { throw MkNotYetPorted("app.MkEditorViewModel.copySelection") }
    fun pasteFromClipboard() { throw MkNotYetPorted("app.MkEditorViewModel.pasteFromClipboard") }
    fun flipSelectionHorizontally() { throw MkNotYetPorted("app.MkEditorViewModel.flipSelectionHorizontally") }
    fun flipSelectionVertically() { throw MkNotYetPorted("app.MkEditorViewModel.flipSelectionVertically") }
    fun flipProjectHorizontally() { throw MkNotYetPorted("app.MkEditorViewModel.flipProjectHorizontally") }
    fun flipProjectVertically() { throw MkNotYetPorted("app.MkEditorViewModel.flipProjectVertically") }
    suspend fun mergeDesign(sourceProjectID: MkProjectId) { throw MkNotYetPorted("app.MkEditorViewModel.mergeDesign") }
    suspend fun toggleArrangeMode() { throw MkNotYetPorted("app.MkEditorViewModel.toggleArrangeMode") }
    fun setArrangeGranularity(granularity: MkSelectionGranularity) { throw MkNotYetPorted("app.MkEditorViewModel.setArrangeGranularity") }
    fun addPathText(preset: PathTextPreset): MkNodeId? { throw MkNotYetPorted("app.MkEditorViewModel.addPathText") }
    fun togglePathEditMode() { throw MkNotYetPorted("app.MkEditorViewModel.togglePathEditMode") }
    fun requestRevert() { throw MkNotYetPorted("app.MkEditorViewModel.requestRevert") }
    fun confirmRevert() { throw MkNotYetPorted("app.MkEditorViewModel.confirmRevert") }
    fun cancelRevert() { throw MkNotYetPorted("app.MkEditorViewModel.cancelRevert") }
    fun resolveArrangeConflictRevertAndEdit() { throw MkNotYetPorted("app.MkEditorViewModel.resolveArrangeConflictRevertAndEdit") }
    fun resolveArrangeConflictDuplicateThenEdit() { throw MkNotYetPorted("app.MkEditorViewModel.resolveArrangeConflictDuplicateThenEdit") }
    fun resolveArrangeConflictCancel() { throw MkNotYetPorted("app.MkEditorViewModel.resolveArrangeConflictCancel") }
    fun breakJoinWithNextForSelection() { throw MkNotYetPorted("app.MkEditorViewModel.breakJoinWithNextForSelection") }
    fun breakJoinWithPreviousForSelection() { throw MkNotYetPorted("app.MkEditorViewModel.breakJoinWithPreviousForSelection") }
    fun restoreJoinWithNextForSelection() { throw MkNotYetPorted("app.MkEditorViewModel.restoreJoinWithNextForSelection") }
    fun restoreJoinWithPreviousForSelection() { throw MkNotYetPorted("app.MkEditorViewModel.restoreJoinWithPreviousForSelection") }
    fun presentFormSelectorForSelection() { throw MkNotYetPorted("app.MkEditorViewModel.presentFormSelectorForSelection") }
    fun selectForm(form: MkJoiningForm) { throw MkNotYetPorted("app.MkEditorViewModel.selectForm") }
    fun dismissFormSelector() { throw MkNotYetPorted("app.MkEditorViewModel.dismissFormSelector") }
    fun decomposeSelection(fidelity: Boolean = true) { throw MkNotYetPorted("app.MkEditorViewModel.decomposeSelection") }
    fun requestRecomposeSelection() { throw MkNotYetPorted("app.MkEditorViewModel.requestRecomposeSelection") }
    fun confirmRecompose() { throw MkNotYetPorted("app.MkEditorViewModel.confirmRecompose") }
    fun cancelRecompose() { throw MkNotYetPorted("app.MkEditorViewModel.cancelRecompose") }
    fun detachSelectedMark() { throw MkNotYetPorted("app.MkEditorViewModel.detachSelectedMark") }
    fun armReattachForSelectedMark() { throw MkNotYetPorted("app.MkEditorViewModel.armReattachForSelectedMark") }
    fun completePendingMarkReattach(baseID: MkNodeId) { throw MkNotYetPorted("app.MkEditorViewModel.completePendingMarkReattach") }
    fun cancelPendingMarkReattach() { throw MkNotYetPorted("app.MkEditorViewModel.cancelPendingMarkReattach") }
    fun undo() { throw MkNotYetPorted("app.MkEditorViewModel.undo") }
    fun redo() { throw MkNotYetPorted("app.MkEditorViewModel.redo") }
    fun debugSetActiveOverlayText(text: String) { throw MkNotYetPorted("app.MkEditorViewModel.debugSetActiveOverlayText") }
    fun debugCommitActiveOverlay() { throw MkNotYetPorted("app.MkEditorViewModel.debugCommitActiveOverlay") }
    fun debugForceMemoryStage(stage: MkMemoryStage) { throw MkNotYetPorted("app.MkEditorViewModel.debugForceMemoryStage") }
    fun debugApplyTestTransform() { throw MkNotYetPorted("app.MkEditorViewModel.debugApplyTestTransform") }
    fun debugMeasureManipulationFrames(frameCount: Int = 30): Double { throw MkNotYetPorted("app.MkEditorViewModel.debugMeasureManipulationFrames") }
    fun debugDumpSnapshotPNG() { throw MkNotYetPorted("app.MkEditorViewModel.debugDumpSnapshotPNG") }
    fun debugArrangeSelection() { throw MkNotYetPorted("app.MkEditorViewModel.debugArrangeSelection") }
    fun debugMoveFirstGlyph(dx: Double, dy: Double) { throw MkNotYetPorted("app.MkEditorViewModel.debugMoveFirstGlyph") }
    fun debugMoveFirstMark(dx: Double, dy: Double) { throw MkNotYetPorted("app.MkEditorViewModel.debugMoveFirstMark") }
    fun debugBreakFirstJoin() { throw MkNotYetPorted("app.MkEditorViewModel.debugBreakFirstJoin") }
    fun debugSelectIsolatedFormOnFirstGlyph() { throw MkNotYetPorted("app.MkEditorViewModel.debugSelectIsolatedFormOnFirstGlyph") }
    fun debugDecomposeFirstLigature() { throw MkNotYetPorted("app.MkEditorViewModel.debugDecomposeFirstLigature") }
    fun debugRevertArrangedSelection() { throw MkNotYetPorted("app.MkEditorViewModel.debugRevertArrangedSelection") }
    suspend fun debugRunE2EArrangeSequence() { throw MkNotYetPorted("app.MkEditorViewModel.debugRunE2EArrangeSequence") }
    fun debugDragFirstPathAnchor(dx: Double, dy: Double) { throw MkNotYetPorted("app.MkEditorViewModel.debugDragFirstPathAnchor") }
    fun debugDragFirstPathGlyph(dx: Double, dy: Double) { throw MkNotYetPorted("app.MkEditorViewModel.debugDragFirstPathGlyph") }
    suspend fun debugRunE2EPathSequence() { throw MkNotYetPorted("app.MkEditorViewModel.debugRunE2EPathSequence") }
    fun debugDumpSceneJSON(label: String) { throw MkNotYetPorted("app.MkEditorViewModel.debugDumpSceneJSON") }
    suspend fun debugRunScreenshotArrangeSequence() { throw MkNotYetPorted("app.MkEditorViewModel.debugRunScreenshotArrangeSequence") }
    suspend fun debugRunScreenshotPathSequence() { throw MkNotYetPorted("app.MkEditorViewModel.debugRunScreenshotPathSequence") }
    fun presentOverlay(nodeID: MkNodeId, vc: MkCanvasViewController) { throw MkNotYetPorted("app.MkEditorViewModel.presentOverlay") }
    fun dismissOverlayIfNeeded() { throw MkNotYetPorted("app.MkEditorViewModel.dismissOverlayIfNeeded") }
    fun finishOverlayPresentation(vc: MkCanvasViewController?) { throw MkNotYetPorted("app.MkEditorViewModel.finishOverlayPresentation") }
    fun currentText(nodeID: MkNodeId): String { throw MkNotYetPorted("app.MkEditorViewModel.currentText") }
    fun initialPointSize(nodeID: MkNodeId): Double { throw MkNotYetPorted("app.MkEditorViewModel.initialPointSize") }
    fun overlayFrame(nodeID: MkNodeId): MkRect { throw MkNotYetPorted("app.MkEditorViewModel.overlayFrame") }
    companion object {
        fun restorationDefaultsKey(projectID: MkProjectId): String { throw MkNotYetPorted("app.MkEditorViewModel.restorationDefaultsKey") }
        fun loadRestorationState(projectID: MkProjectId): EditorRestorationState? { throw MkNotYetPorted("app.MkEditorViewModel.loadRestorationState") }
        fun userFacingExportErrorMessage(error: Throwable): String { throw MkNotYetPorted("app.MkEditorViewModel.userFacingExportErrorMessage") }
        fun defaultInsertPointSize(canvasSize: MkSize): Double { throw MkNotYetPorted("app.MkEditorViewModel.defaultInsertPointSize") }
        fun tokenizeForInsert(text: String, splitBySpaces: Boolean): List<List<String>> { throw MkNotYetPorted("app.MkEditorViewModel.tokenizeForInsert") }
        fun measureSingleLineSize(text: String, style: MkTextStyle): MkSize { throw MkNotYetPorted("app.MkEditorViewModel.measureSingleLineSize") }
        fun spaceWidthApproximation(pointSize: Double): Double { throw MkNotYetPorted("app.MkEditorViewModel.spaceWidthApproximation") }
        val rectangleCornerRadiusPoints: Double = 8.0
    }
    data class EditorRestorationState(
        var zoomScale: Double,
        var contentOffsetX: Double,
        var contentOffsetY: Double,
        var selectedNodeIDs: List<MkNodeId>
    )
    enum class TextInsertAlignment {
        RIGHT, CENTER, LEFT
    }
    enum class BackgroundImageOutcome {
        SET, FAILED
    }
    enum class PathTextPreset {
        ARC, CIRCLE, WAVE, FREEFORM
    }
}

enum class MkEditorPanel(val rawValue: String) {
    LAYERS(""), INSPECTOR("");
    val id: String
        get() = throw MkNotYetPorted("app.MkEditorPanel.id")
}

class MkDocumentAutosaveTrigger(
    var document: MkMakhtootDocument? = null,
    val reason: MkSaveReason? = null
) : MkAutosaveTriggering {
    override suspend fun flushForMemoryPressure(stage: MkMemoryStage) { throw MkNotYetPorted("app.MkDocumentAutosaveTrigger.flushForMemoryPressure") }
    override suspend fun flushJournalOnly() { throw MkNotYetPorted("app.MkDocumentAutosaveTrigger.flushJournalOnly") }
}

