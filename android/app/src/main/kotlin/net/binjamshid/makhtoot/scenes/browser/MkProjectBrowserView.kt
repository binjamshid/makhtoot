package net.binjamshid.makhtoot.scenes.browser

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.foundation.entitlement.MkEntitlementState
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec
import net.binjamshid.makhtoot.mk.persistence.metadata.MkProjectSummary
import net.binjamshid.makhtoot.stubs.MkProjectFolderSummary

@androidx.compose.runtime.Composable
fun MkProjectBrowserView(viewModel: MkProjectBrowserViewModel? = null, pendingDeletion: MkProjectSummary? = null, pendingFolderDeletion: MkProjectFolderSummary? = null, renamingProject: MkProjectSummary? = null, thumbnailReloadToken: Int = 0, showsNewProjectSheet: Boolean = false, showsNewFolderPrompt: Boolean = false, newFolderName: String = "", exportHistorySheet: ExportHistoryTarget? = null, emptyStateIconSize: Double = 40.0, syncErrorAlertTarget: SyncErrorAlertTarget? = null, entitlementState: MkEntitlementState? = null, onOpenSettings: () -> Unit, columns: List<String>? = null, vm: Any? = null, fixtures: List<Pair<String, MkSize>>? = null, name: Any = newFolderName, ordinal: Any? = null, signpostState: Any? = null, entries: Any? = null, state: Any? = null, id: Any? = null) { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_trialChip(daysLeft: Int) { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_folderChips(viewModel: MkProjectBrowserViewModel) { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_emptyState(isSearching: Boolean) { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_grid(projects: List<MkProjectSummary>, viewModel: MkProjectBrowserViewModel) { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_projectCard(project: MkProjectSummary, viewModel: MkProjectBrowserViewModel) { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_syncBadge(id: MkProjectId) { }
fun MkProjectBrowserView_syncStatusDetailMessage(id: MkProjectId): String? { throw MkNotYetPorted("app.MkProjectBrowserView.syncStatusDetailMessage") }
fun MkProjectBrowserView_presentSyncStatusDetail(id: MkProjectId) { throw MkNotYetPorted("app.MkProjectBrowserView.presentSyncStatusDetail") }
fun MkProjectBrowserView_createProject(canvas: MkCanvasSpec) { throw MkNotYetPorted("app.MkProjectBrowserView.createProject") }
fun MkProjectBrowserView_createProjectFromPhoto(canvas: MkCanvasSpec, data: ByteArray) { throw MkNotYetPorted("app.MkProjectBrowserView.createProjectFromPhoto") }
fun MkProjectBrowserView_deleteProject(id: MkProjectId) { throw MkNotYetPorted("app.MkProjectBrowserView.deleteProject") }
val MkProjectBrowserView_isPremium: Boolean
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.isPremium")
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_content() { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_titleHeading() { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_entitlementBanner() { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_gracePeriodBanner() { }
@androidx.compose.runtime.Composable
fun MkProjectBrowserView_billingRetryBanner() { }
val MkProjectBrowserView_browserTitle: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.browserTitle")
val MkProjectBrowserView_upgradeChipLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.upgradeChipLabel")
val MkProjectBrowserView_gracePeriodBannerCopy: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.gracePeriodBannerCopy")
val MkProjectBrowserView_billingRetryBannerCopy: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.billingRetryBannerCopy")
val MkProjectBrowserView_newProjectLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.newProjectLabel")
val MkProjectBrowserView_settingsLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.settingsLabel")
val MkProjectBrowserView_emptyStateTitle: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.emptyStateTitle")
val MkProjectBrowserView_emptySearchTitle: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.emptySearchTitle")
val MkProjectBrowserView_searchPrompt: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.searchPrompt")
val MkProjectBrowserView_deleteLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.deleteLabel")
val MkProjectBrowserView_openLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.openLabel")
val MkProjectBrowserView_renameLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.renameLabel")
val MkProjectBrowserView_duplicateLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.duplicateLabel")
val MkProjectBrowserView_moveToFolderLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.moveToFolderLabel")
val MkProjectBrowserView_noFolderLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.noFolderLabel")
val MkProjectBrowserView_exportHistoryLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.exportHistoryLabel")
val MkProjectBrowserView_orphanedLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.orphanedLabel")
val MkProjectBrowserView_allFoldersLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.allFoldersLabel")
val MkProjectBrowserView_newFolderChipLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.newFolderChipLabel")
val MkProjectBrowserView_newFolderTitle: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.newFolderTitle")
val MkProjectBrowserView_newFolderPlaceholder: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.newFolderPlaceholder")
val MkProjectBrowserView_renameTitle: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.renameTitle")
val MkProjectBrowserView_renamePlaceholder: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.renamePlaceholder")
val MkProjectBrowserView_createLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.createLabel")
val MkProjectBrowserView_saveLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.saveLabel")
val MkProjectBrowserView_cancelLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.cancelLabel")
val MkProjectBrowserView_deleteConfirmTitle: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.deleteConfirmTitle")
val MkProjectBrowserView_deleteConfirmMessage: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.deleteConfirmMessage")
val MkProjectBrowserView_deleteFolderConfirmTitle: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.deleteFolderConfirmTitle")
val MkProjectBrowserView_deleteFolderConfirmMessage: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.deleteFolderConfirmMessage")
val MkProjectBrowserView_deleteConfirmButton: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.deleteConfirmButton")
val MkProjectBrowserView_syncBadgeErrorAccessibilityLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.syncBadgeErrorAccessibilityLabel")
val MkProjectBrowserView_syncStatusAlertTitle: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.syncStatusAlertTitle")
val MkProjectBrowserView_okLabel: String
    get() = throw MkNotYetPorted("app.MkProjectBrowserView.okLabel")

@androidx.compose.runtime.Composable
fun MkProjectThumbnailView(url: java.net.URI? = null, isOrphaned: Boolean, reloadToken: Int, image: UIImage? = null, placeholderIconSize: Double = 28.0) { }

@androidx.compose.runtime.Composable
fun MkRenameProjectSheet(title: String, placeholder: String, saveLabel: String, cancelLabel: String, currentName: String, onSave: (String) -> Unit, onCancel: () -> Unit, draft: String, isFieldFocused: Boolean) { }
fun MkRenameProjectSheet_save() { throw MkNotYetPorted("app.MkRenameProjectSheet.save") }
val MkRenameProjectSheet_trimmed: String
    get() = throw MkNotYetPorted("app.MkRenameProjectSheet.trimmed")

data class MkThumbnailTaskId(
    val url: java.net.URI? = null,
    val reloadToken: Int
)

class MkProjectThumbnailCache(
    var cache: Map<java.net.URI, Cached> = emptyMap(),
    var inFlight: Map<java.net.URI, Task<Any?, Never>> = emptyMap(),
    val mtime: Any? = null,
    val task: Task<Any?, Never>,
    val cgImage: Any? = null,
    val image: Any? = null
) {
    val newTask: Any
        get() = throw MkNotYetPorted("app.MkProjectThumbnailCache.newTask")
    suspend fun image(url: java.net.URI): UIImage? { throw MkNotYetPorted("app.MkProjectThumbnailCache.image") }
    fun decodeCGImage(url: java.net.URI): Any? { throw MkNotYetPorted("app.MkProjectThumbnailCache.decodeCGImage") }
    companion object {
        val shared: MkProjectThumbnailCache = MkProjectThumbnailCache()
    }
    class Cached
}

