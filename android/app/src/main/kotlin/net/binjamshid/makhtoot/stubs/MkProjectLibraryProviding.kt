package net.binjamshid.makhtoot.stubs

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.foundation.MkProjectId
import net.binjamshid.makhtoot.mk.foundation.geometry.MkSize
import net.binjamshid.makhtoot.mk.foundation.stubs.MkDocumentStoring
import net.binjamshid.makhtoot.mk.model.MkCanvasSpec

data class MkProjectSummary(
    val id: MkProjectId,
    var name: String,
    var createdAt: java.time.Instant,
    var modifiedAt: java.time.Instant,
    var folderID: java.util.UUID? = null,
    var canvasSize: MkSize,
    var premiumContentPresent: Boolean,
    var isOrphaned: Boolean,
    var thumbnailURL: java.net.URI? = null
)

data class MkProjectFolderSummary(
    val id: java.util.UUID,
    var name: String,
    var sortOrder: Int
)

data class MkProjectExportHistoryEntry(
    val id: java.util.UUID,
    var date: java.time.Instant,
    var format: String,
    var pixelWidth: Int,
    var pixelHeight: Int,
    var wasPremium: Boolean,
    var success: Boolean
)

sealed class MkProjectImportError : Exception() {
    object MissingPackage : MkProjectImportError()
    object MalformedManifest : MkProjectImportError()
    data class CopyFailed(val underlying: Throwable) : MkProjectImportError()
}



interface MkProjectLibraryProviding {
    suspend fun search(query: String): List<MkProjectSummary>
    suspend fun listFolders(): List<MkProjectFolderSummary>
    suspend fun createFolder(name: String): MkProjectFolderSummary?
    suspend fun renameFolder(id: java.util.UUID, name: String)
    suspend fun deleteFolder(id: java.util.UUID)
    suspend fun create(name: String, canvas: MkCanvasSpec): MkProjectSummary?
    suspend fun rename(id: MkProjectId, name: String)
    suspend fun duplicate(id: MkProjectId): MkProjectSummary?
    suspend fun exportHistory(id: MkProjectId): List<MkProjectExportHistoryEntry>
    suspend fun refreshFromDisk()
    suspend fun packageRootURL(id: MkProjectId): java.net.URI?
    suspend fun recordThumbnailGenerated(id: MkProjectId, relativeFilename: String)
    suspend fun importExternalPackage(url: java.net.URI): MkProjectSummary
    suspend fun fetchAll(): List<MkProjectSummary> { throw MkNotYetPorted("app.MkProjectLibraryProviding.fetchAll") }
}

class MkInMemoryProjectLibrary(
    var summaries: Map<MkProjectId, MkProjectSummary> = emptyMap(),
    var folders: Map<java.util.UUID, MkProjectFolderSummary> = emptyMap(),
    val documentStore: MkDocumentStoring,
    val folder: Any? = null,
    val id: MkProjectId = MkProjectId(),
    val now: java.time.Instant = java.time.Instant.now(),
    val summary: Any? = null,
    val newID: MkProjectId = MkProjectId(),
    val copy: Any? = null
) : MkProjectLibraryProviding {
    override suspend fun fetchAll(folderID: java.util.UUID?): List<MkProjectSummary> { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.fetchAll") }
    override suspend fun search(query: String): List<MkProjectSummary> { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.search") }
    override suspend fun listFolders(): List<MkProjectFolderSummary> { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.listFolders") }
    override suspend fun createFolder(name: String): MkProjectFolderSummary? { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.createFolder") }
    override suspend fun renameFolder(id: java.util.UUID, name: String) { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.renameFolder") }
    override suspend fun deleteFolder(id: java.util.UUID) { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.deleteFolder") }
    suspend fun move(id: MkProjectId, folderID: java.util.UUID?) { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.move") }
    override suspend fun create(name: String, canvas: MkCanvasSpec): MkProjectSummary? { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.create") }
    override suspend fun rename(id: MkProjectId, name: String) { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.rename") }
    suspend fun delete(id: MkProjectId) { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.delete") }
    override suspend fun duplicate(id: MkProjectId): MkProjectSummary? { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.duplicate") }
    override suspend fun exportHistory(id: MkProjectId): List<MkProjectExportHistoryEntry> { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.exportHistory") }
    override suspend fun refreshFromDisk() { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.refreshFromDisk") }
    override suspend fun packageRootURL(id: MkProjectId): java.net.URI? { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.packageRootURL") }
    override suspend fun recordThumbnailGenerated(id: MkProjectId, relativeFilename: String) { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.recordThumbnailGenerated") }
    override suspend fun importExternalPackage(url: java.net.URI): MkProjectSummary { throw MkNotYetPorted("app.MkInMemoryProjectLibrary.importExternalPackage") }
}

