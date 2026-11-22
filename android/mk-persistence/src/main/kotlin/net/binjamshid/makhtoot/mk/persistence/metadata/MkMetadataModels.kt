package net.binjamshid.makhtoot.mk.persistence.metadata

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkProjectRecord(
    var projectID: java.util.UUID,
    var title: String,
    var folderID: java.util.UUID? = null,
    var createdAt: java.time.Instant = java.time.Instant.now(),
    var modifiedAt: java.time.Instant = java.time.Instant.now(),
    var canvasWidth: Double,
    var canvasHeight: Double,
    var thumbnailPath: String? = null,
    var searchText: String = "",
    var premiumContentPresent: Boolean = false,
    var packageRelativePath: String,
    var syncState: Int = 0,
    var lastSyncedChangeTag: String? = null,
    var isOrphaned: Boolean = false
)

class MkFolderRecord(
    var folderID: java.util.UUID = java.util.UUID.randomUUID(),
    var name: String,
    var sortOrder: Int = 0
)

class MkExportRecord(
    var exportID: java.util.UUID = java.util.UUID.randomUUID(),
    var projectID: java.util.UUID,
    var date: java.time.Instant = java.time.Instant.now(),
    var format: String,
    var pixelWidth: Int,
    var pixelHeight: Int,
    var presetID: String? = null,
    var wasPremium: Boolean = false,
    var outputBookmark: ByteArray? = null,
    var success: Boolean = true
)

class MkFontCatalogRecord(
    var fontID: String,
    var displayNameAr: String,
    var postScriptName: String,
    var category: String,
    var tier: Int,
    var downloadState: Int = 0,
    var localPath: String? = null,
    var isFavorite: Boolean = false,
    var tags: List<String> = emptyList(),
    var coverageClass: Int = 0,
    var lockedByExpiry: Boolean = false
)

class MkFontFavoriteRecord(
    var fontID: String,
    var favoritedAt: java.time.Instant = java.time.Instant.now()
)

class MkAnalyticsCounterRecord(
    var key: String,
    var count: Int = 0
)

class MkConsentRecord(
    var kind: String,
    var version: Int,
    var grantedAt: java.time.Instant? = null,
    var revokedAt: java.time.Instant? = null
)

class MkTrialRecord(
    var firstLaunchAt: java.time.Instant,
    var lastObservedWallClock: java.time.Instant,
    var extensionDays: Int = 0
)

class MkTombstoneRecord(
    var projectID: java.util.UUID,
    var deletedAt: java.time.Instant = java.time.Instant.now()
)

object MkMetadataSchema {
    val models: List<Any>
        get() = throw MkNotYetPorted("mk-persistence.MkMetadataSchema.models")
}

