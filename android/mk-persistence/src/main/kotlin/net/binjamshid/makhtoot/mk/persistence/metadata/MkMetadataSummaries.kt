package net.binjamshid.makhtoot.mk.persistence.metadata

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

data class MkProjectSummary(
    val projectID: java.util.UUID,
    val title: String,
    val folderID: java.util.UUID? = null,
    val createdAt: java.time.Instant,
    val modifiedAt: java.time.Instant,
    val canvasWidth: Double,
    val canvasHeight: Double,
    val thumbnailPath: String? = null,
    val searchText: String,
    val premiumContentPresent: Boolean,
    val packageRelativePath: String,
    val syncState: Int,
    val lastSyncedChangeTag: String? = null,
    val isOrphaned: Boolean
) {
    val id: java.util.UUID
        get() = throw MkNotYetPorted("mk-persistence.MkProjectSummary.id")
}

data class MkFolderSummary(
    val folderID: java.util.UUID,
    val name: String,
    val sortOrder: Int
) {
    val id: java.util.UUID
        get() = throw MkNotYetPorted("mk-persistence.MkFolderSummary.id")
}

data class MkExportSummary(
    val exportID: java.util.UUID,
    val projectID: java.util.UUID,
    val date: java.time.Instant,
    val format: String,
    val pixelWidth: Int,
    val pixelHeight: Int,
    val presetID: String? = null,
    val wasPremium: Boolean,
    val success: Boolean
) {
    val id: java.util.UUID
        get() = throw MkNotYetPorted("mk-persistence.MkExportSummary.id")
}

