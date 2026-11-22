package net.binjamshid.makhtoot.persistence

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec
import net.binjamshid.makhtoot.mk.persistence.metadata.MkExportSummary
import net.binjamshid.makhtoot.mk.persistence.metadata.MkFolderSummary
import net.binjamshid.makhtoot.mk.persistence.metadata.MkMetadataStore
import net.binjamshid.makhtoot.mk.persistence.metadata.MkProjectSummary
import net.binjamshid.makhtoot.mk.sync.engine.MkSyncEngineController
import net.binjamshid.makhtoot.mk.sync.status.MkSyncStatusPublisher
import net.binjamshid.makhtoot.stubs.MkProjectExportHistoryEntry
import net.binjamshid.makhtoot.stubs.MkProjectFolderSummary
import net.binjamshid.makhtoot.stubs.MkProjectLibraryProviding

enum class MkProjectImportInternalError {
    STORE_UNAVAILABLE, NOT_INDEXED_AFTER_RECONCILE
}

class MkPersistenceProjectLibrary(
    val documentsRootURL: java.net.URI,
    val projectsRootURL: java.net.URI,
    val appSupportURL: java.net.URI,
    var store: MkMetadataStore? = null,
    var bootstrapTask: Task<MkMetadataStore, Throwable>? = null,
    val fm: Any? = null,
    val storeURL: Any? = null,
    val container: Any? = null,
    val result: Any? = null,
    val packageURL: Any? = null,
    val candidate: Any? = null,
    val projectID: Any? = null,
    val sortOrder: Any? = null,
    val id: MkProjectId = MkProjectId(),
    val relativePath: String = "Projects/\(id.rawValue.uuidString).makhtoot",
    val rootURL: Any? = null,
    val record: Any? = null,
    var manifest: Any? = null,
    val cap: Double = 600.0,
    val scale: Any? = null,
    val renderer: Any? = null,
    val scene: Any? = null,
    val url: Any? = null,
    val destinationURL: Any? = null
) : MkProjectLibraryProviding {
    val task: Any
        get() = throw MkNotYetPorted("app.MkPersistenceProjectLibrary.task")
    val thumbnailURL: java.net.URI?
        get() = throw MkNotYetPorted("app.MkPersistenceProjectLibrary.thumbnailURL")
    suspend fun ensureStore(): MkMetadataStore? { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.ensureStore") }
    override suspend fun refreshFromDisk() { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.refreshFromDisk") }
    fun summary(record: MkProjectSummary): MkProjectSummary { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.summary") }
    fun folderSummary(record: MkFolderSummary): MkProjectFolderSummary { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.folderSummary") }
    fun exportEntry(record: MkExportSummary): MkProjectExportHistoryEntry { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.exportEntry") }
    fun packageURL(relativePath: String): java.net.URI { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.packageURL") }
    override suspend fun fetchAll(folderID: java.util.UUID?): List<MkProjectSummary> { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.fetchAll") }
    override suspend fun search(query: String): List<MkProjectSummary> { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.search") }
    override suspend fun listFolders(): List<MkProjectFolderSummary> { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.listFolders") }
    override suspend fun createFolder(name: String): MkProjectFolderSummary? { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.createFolder") }
    override suspend fun renameFolder(id: java.util.UUID, name: String) { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.renameFolder") }
    override suspend fun deleteFolder(id: java.util.UUID) { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.deleteFolder") }
    suspend fun move(id: MkProjectId, folderID: java.util.UUID?) { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.move") }
    override suspend fun create(name: String, canvas: MkCanvasSpec): MkProjectSummary? { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.create") }
    override suspend fun recordThumbnailGenerated(id: MkProjectId, relativeFilename: String) { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.recordThumbnailGenerated") }
    override suspend fun rename(id: MkProjectId, name: String) { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.rename") }
    suspend fun delete(id: MkProjectId) { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.delete") }
    override suspend fun duplicate(id: MkProjectId): MkProjectSummary? { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.duplicate") }
    override suspend fun exportHistory(id: MkProjectId): List<MkProjectExportHistoryEntry> { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.exportHistory") }
    override suspend fun packageRootURL(id: MkProjectId): java.net.URI? { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.packageRootURL") }
    suspend fun makeSyncEngineController(statusPublisher: MkSyncStatusPublisher): MkSyncEngineController? { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.makeSyncEngineController") }
    override suspend fun importExternalPackage(url: java.net.URI): MkProjectSummary { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.importExternalPackage") }
    companion object {
        fun renderTemplateThumbnail(canvas: MkCanvasSpec): ByteArray? { throw MkNotYetPorted("app.MkPersistenceProjectLibrary.renderTemplateThumbnail") }
    }
}

