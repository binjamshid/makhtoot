import Foundation
import SwiftData

// WS-02 packet §5 task 14. SwiftData metadata models ، INV-14/D-112: this
// store holds ONLY metadata (projects, folders, names, search text, export
// history, font-catalog/favorites/download state, analytics counters,
// trial/consent records). It NEVER contains a scene graph; nothing in this
// file has a field shaped like `MKScene`/`MKNode`.
//
// Naming: packet task 14 names these bare (`ProjectRecord`, `FolderRecord`,
// …). Kept `MK`-prefixed here for the same reason logged for the
// `Arranged/` family in `MKModel` ، every other public type in this
// codebase (including this same packet's own `MKScene`/`MKNode`/
// `MKCommand`) carries the `MK` prefix, and introducing six bare names
// would be the only inconsistency in the module.

@Model
public final class MKProjectRecord {
    @Attribute(.unique) public var projectID: UUID
    public var title: String
    public var folderID: UUID?
    public var createdAt: Date
    public var modifiedAt: Date
    public var canvasWidth: Double
    public var canvasHeight: Double
    /// Derived copy path in `Library/Caches`, not inside the package.
    public var thumbnailPath: String?
    /// Titles + layer names only (INV-14/D-112 as amended ، see
    /// `SearchTextExtractor.swift` for the full note on why this
    /// deliberately does NOT include live-text/arranged source strings
    /// despite the packet's task-16 prose).
    public var searchText: String
    /// D-119 gating marker.
    public var premiumContentPresent: Bool
    /// Relative to the Documents directory, e.g. `"Projects/<uuid>.makhtoot"`.
    public var packageRelativePath: String
    /// Raw `MKSyncState` (§20.4) ، WS-11 populates/reads this; `0` = not
    /// yet synced (the only value this packet ever writes).
    public var syncState: Int
    public var lastSyncedChangeTag: String?
    /// `true` when `LaunchReconciler` found no package on disk for this
    /// record ، surfaced by the (future) project browser UI rather than
    /// silently deleted, so a user whose iCloud Drive hasn't finished
    /// downloading a package doesn't lose the entry.
    public var isOrphaned: Bool

    public init(
        projectID: UUID,
        title: String,
        folderID: UUID? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        canvasWidth: Double,
        canvasHeight: Double,
        thumbnailPath: String? = nil,
        searchText: String = "",
        premiumContentPresent: Bool = false,
        packageRelativePath: String,
        syncState: Int = 0,
        lastSyncedChangeTag: String? = nil,
        isOrphaned: Bool = false
    ) {
        self.projectID = projectID
        self.title = title
        self.folderID = folderID
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.thumbnailPath = thumbnailPath
        self.searchText = searchText
        self.premiumContentPresent = premiumContentPresent
        self.packageRelativePath = packageRelativePath
        self.syncState = syncState
        self.lastSyncedChangeTag = lastSyncedChangeTag
        self.isOrphaned = isOrphaned
    }
}

@Model
public final class MKFolderRecord {
    @Attribute(.unique) public var folderID: UUID
    public var name: String
    public var sortOrder: Int

    public init(folderID: UUID = UUID(), name: String, sortOrder: Int = 0) {
        self.folderID = folderID
        self.name = name
        self.sortOrder = sortOrder
    }
}

/// Export history ، BRIEF "export history (all users)"; consumed/written
/// primarily by WS-08.
@Model
public final class MKExportRecord {
    @Attribute(.unique) public var exportID: UUID
    public var projectID: UUID
    public var date: Date
    public var format: String // "jpeg"|"png"|"pngAlpha"|"svg"|"pdf"|"pdfPrint"
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var presetID: String?
    public var wasPremium: Bool
    public var outputBookmark: Data?
    public var success: Bool

    public init(
        exportID: UUID = UUID(),
        projectID: UUID,
        date: Date = Date(),
        format: String,
        pixelWidth: Int,
        pixelHeight: Int,
        presetID: String? = nil,
        wasPremium: Bool = false,
        outputBookmark: Data? = nil,
        success: Bool = true
    ) {
        self.exportID = exportID
        self.projectID = projectID
        self.date = date
        self.format = format
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.presetID = presetID
        self.wasPremium = wasPremium
        self.outputBookmark = outputBookmark
        self.success = success
    }
}

/// Font catalog cache + download state slot (WS-09 populates real data;
/// this packet only ships the schema).
@Model
public final class MKFontCatalogRecord {
    @Attribute(.unique) public var fontID: String
    public var displayNameAr: String
    public var postScriptName: String
    /// naskh|ruqah|thuluth|diwani|kufi|maghrebi|display|quranStyle|handwriting|bilingual
    public var category: String
    /// 0 bundled, 1 premium, 2 userImported.
    public var tier: Int
    public var downloadState: Int
    public var localPath: String?
    public var isFavorite: Bool
    public var tags: [String]
    public var coverageClass: Int
    public var lockedByExpiry: Bool

    public init(
        fontID: String,
        displayNameAr: String,
        postScriptName: String,
        category: String,
        tier: Int,
        downloadState: Int = 0,
        localPath: String? = nil,
        isFavorite: Bool = false,
        tags: [String] = [],
        coverageClass: Int = 0,
        lockedByExpiry: Bool = false
    ) {
        self.fontID = fontID
        self.displayNameAr = displayNameAr
        self.postScriptName = postScriptName
        self.category = category
        self.tier = tier
        self.downloadState = downloadState
        self.localPath = localPath
        self.isFavorite = isFavorite
        self.tags = tags
        self.coverageClass = coverageClass
        self.lockedByExpiry = lockedByExpiry
    }
}

/// Favorites slot named separately per packet task 14's literal
/// "`FontCatalogRecord` + `FontFavoriteRecord` slots" ، `MKFontCatalogRecord`
/// above already carries an `isFavorite` flag (matching ARCHITECTURE
/// §13.6's shape); this record additionally tracks WHEN a font was
/// favorited, for a future "recently favorited" sort WS-09 may want.
@Model
public final class MKFontFavoriteRecord {
    @Attribute(.unique) public var fontID: String
    public var favoritedAt: Date

    public init(fontID: String, favoritedAt: Date = Date()) {
        self.fontID = fontID
        self.favoritedAt = favoritedAt
    }
}

@Model
public final class MKAnalyticsCounterRecord {
    @Attribute(.unique) public var key: String // "fontUsage.<fontID>.<isoWeek>"
    public var count: Int

    public init(key: String, count: Int = 0) {
        self.key = key
        self.count = count
    }
}

@Model
public final class MKConsentRecord {
    public var kind: String // "analytics"
    public var version: Int
    public var grantedAt: Date?
    public var revokedAt: Date?

    public init(kind: String, version: Int, grantedAt: Date? = nil, revokedAt: Date? = nil) {
        self.kind = kind
        self.version = version
        self.grantedAt = grantedAt
        self.revokedAt = revokedAt
    }
}

/// Display-cache mirror only (§13.6: "truth = Keychain", D-123) ، WS-10
/// reads/writes the real Keychain-backed trial clock; this record exists
/// only so Settings/UI can query trial state without a Keychain round trip
/// on every render.
@Model
public final class MKTrialRecord {
    public var firstLaunchAt: Date
    public var lastObservedWallClock: Date
    public var extensionDays: Int

    public init(firstLaunchAt: Date, lastObservedWallClock: Date, extensionDays: Int = 0) {
        self.firstLaunchAt = firstLaunchAt
        self.lastObservedWallClock = lastObservedWallClock
        self.extensionDays = extensionDays
    }
}

/// Records a local project deletion that has not yet been confirmed by the
/// sync engine. Cleared per-id by `MetadataStore.clearTombstone(id:)` once
/// the server accepts the deletion.
///
/// Tombstone lives here (not in MKSync) per CONTRACTS.md principle:
/// "tombstone lives with the store." WS-11 reads via
/// `MetadataStore.tombstones()` and clears via `clearTombstone(id:)`.
@Model
public final class MKTombstoneRecord {
    @Attribute(.unique) public var projectID: UUID
    public var deletedAt: Date

    public init(projectID: UUID, deletedAt: Date = Date()) {
        self.projectID = projectID
        self.deletedAt = deletedAt
    }
}

/// Full schema this module's `ModelContainer` is configured with.
public enum MKMetadataSchema {
    public static var models: [any PersistentModel.Type] {
        [
            MKProjectRecord.self,
            MKFolderRecord.self,
            MKExportRecord.self,
            MKFontCatalogRecord.self,
            MKFontFavoriteRecord.self,
            MKAnalyticsCounterRecord.self,
            MKConsentRecord.self,
            MKTrialRecord.self,
            MKTombstoneRecord.self,  // WS-11: sync deletion tracking
        ]
    }
}
