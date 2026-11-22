package net.binjamshid.makhtoot.scenes.browser

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec
import net.binjamshid.makhtoot.mk.persistence.metadata.MkProjectSummary
import net.binjamshid.makhtoot.stubs.MkProjectExportHistoryEntry
import net.binjamshid.makhtoot.stubs.MkProjectFolderSummary
import net.binjamshid.makhtoot.stubs.MkProjectLibraryProviding

class MkProjectBrowserViewModel(
    var projects: List<MkProjectSummary> = emptyList(),
    var folders: List<MkProjectFolderSummary> = emptyList(),
    var isLoading: Boolean = false,
    var selectedFolderID: java.util.UUID? = null,
    val library: MkProjectLibraryProviding,
    var searchTask: Task<Unit, Never>? = null,
    val summary: Any? = null,
    val trimmed: Any? = null,
    val copy: Any? = null,
    val folder: Any? = null,
    val ordinal: Any? = null
) {
    val searchQuery: String
        get() = throw MkNotYetPorted("app.MkProjectBrowserViewModel.searchQuery")
    val isSearching: Boolean
        get() = throw MkNotYetPorted("app.MkProjectBrowserViewModel.isSearching")
    suspend fun load() { throw MkNotYetPorted("app.MkProjectBrowserViewModel.load") }
    suspend fun refreshFromDisk() { throw MkNotYetPorted("app.MkProjectBrowserViewModel.refreshFromDisk") }
    fun selectFolder(id: java.util.UUID?) { throw MkNotYetPorted("app.MkProjectBrowserViewModel.selectFolder") }
    fun scheduleSearch() { throw MkNotYetPorted("app.MkProjectBrowserViewModel.scheduleSearch") }
    suspend fun createProject(canvas: MkCanvasSpec): MkProjectId? { throw MkNotYetPorted("app.MkProjectBrowserViewModel.createProject") }
    suspend fun delete(id: MkProjectId) { throw MkNotYetPorted("app.MkProjectBrowserViewModel.delete") }
    suspend fun rename(id: MkProjectId, name: String) { throw MkNotYetPorted("app.MkProjectBrowserViewModel.rename") }
    suspend fun duplicate(id: MkProjectId): MkProjectSummary? { throw MkNotYetPorted("app.MkProjectBrowserViewModel.duplicate") }
    suspend fun move(id: MkProjectId, folderID: java.util.UUID?) { throw MkNotYetPorted("app.MkProjectBrowserViewModel.move") }
    suspend fun exportHistory(id: MkProjectId): List<MkProjectExportHistoryEntry> { throw MkNotYetPorted("app.MkProjectBrowserViewModel.exportHistory") }
    suspend fun createFolder(name: String): MkProjectFolderSummary? { throw MkNotYetPorted("app.MkProjectBrowserViewModel.createFolder") }
    suspend fun renameFolder(id: java.util.UUID, name: String) { throw MkNotYetPorted("app.MkProjectBrowserViewModel.renameFolder") }
    suspend fun deleteFolder(id: java.util.UUID) { throw MkNotYetPorted("app.MkProjectBrowserViewModel.deleteFolder") }
    companion object {
        fun defaultProjectName(existingCount: Int): String { throw MkNotYetPorted("app.MkProjectBrowserViewModel.defaultProjectName") }
    }
}

