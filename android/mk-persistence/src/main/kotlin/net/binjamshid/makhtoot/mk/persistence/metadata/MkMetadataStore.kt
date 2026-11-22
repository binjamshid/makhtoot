package net.binjamshid.makhtoot.mk.persistence.metadata

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec
import net.binjamshid.makhtoot.mk.persistence.MkProjectChange

class MkMetadataStore {
    val changes: kotlinx.coroutines.flow.Flow<MkProjectChange>
        get() = throw MkNotYetPorted("mk-persistence.MkMetadataStore.changes")
    fun listProjects(folderID: java.util.UUID? = null): List<MkProjectSummary> { throw MkNotYetPorted("mk-persistence.MkMetadataStore.listProjects") }
    fun project(id: java.util.UUID): MkProjectSummary? { throw MkNotYetPorted("mk-persistence.MkMetadataStore.project") }
    fun addProject(projectID: java.util.UUID, title: String, canvas: MkCanvasSpec, packageRelativePath: String, folderID: java.util.UUID? = null, searchText: String? = null, premiumContentPresent: Boolean = false): MkProjectSummary { throw MkNotYetPorted("mk-persistence.MkMetadataStore.addProject") }
    fun rename(projectID: java.util.UUID, newTitle: String) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.rename") }
    fun move(projectID: java.util.UUID, folderID: java.util.UUID?) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.move") }
    fun updateSearchText(projectID: java.util.UUID, sceneSearchText: String) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.updateSearchText") }
    fun markOrphaned(projectID: java.util.UUID, orphaned: Boolean = true) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.markOrphaned") }
    fun setThumbnailPath(projectID: java.util.UUID, relativeFilename: String?) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.setThumbnailPath") }
    fun markModified(projectID: java.util.UUID, modifiedAt: java.time.Instant = java.time.Instant.now(), contentHash: String? = null) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.markModified") }
    fun deleteProject(id: java.util.UUID) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.deleteProject") }
    fun tombstones(): List<java.util.UUID> { throw MkNotYetPorted("mk-persistence.MkMetadataStore.tombstones") }
    fun recordTombstone(id: java.util.UUID) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.recordTombstone") }
    fun clearTombstone(id: java.util.UUID) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.clearTombstone") }
    fun duplicateProject(id: java.util.UUID, documentsRootURL: java.net.URI): MkProjectSummary { throw MkNotYetPorted("mk-persistence.MkMetadataStore.duplicateProject") }
    fun updateSyncState(projectID: java.util.UUID, syncState: Int, lastSyncedChangeTag: String?) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.updateSyncState") }
    fun listFolders(): List<MkFolderSummary> { throw MkNotYetPorted("mk-persistence.MkMetadataStore.listFolders") }
    fun createFolder(name: String, sortOrder: Int = 0): MkFolderSummary { throw MkNotYetPorted("mk-persistence.MkMetadataStore.createFolder") }
    fun renameFolder(id: java.util.UUID, newName: String) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.renameFolder") }
    fun deleteFolder(id: java.util.UUID) { throw MkNotYetPorted("mk-persistence.MkMetadataStore.deleteFolder") }
    fun search(query: String): List<MkProjectSummary> { throw MkNotYetPorted("mk-persistence.MkMetadataStore.search") }
    fun recordExport(projectID: java.util.UUID, format: String, pixelWidth: Int, pixelHeight: Int, presetID: String? = null, wasPremium: Boolean = false, success: Boolean = true): MkExportSummary { throw MkNotYetPorted("mk-persistence.MkMetadataStore.recordExport") }
    fun exportHistory(projectID: java.util.UUID): List<MkExportSummary> { throw MkNotYetPorted("mk-persistence.MkMetadataStore.exportHistory") }
    companion object {
        fun makeContainer(url: java.net.URI): Any { throw MkNotYetPorted("mk-persistence.MkMetadataStore.makeContainer") }
    }
}

