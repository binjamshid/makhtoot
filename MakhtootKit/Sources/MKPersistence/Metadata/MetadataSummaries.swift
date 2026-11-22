import Foundation

// Sendable value snapshots of the SwiftData `@Model` classes in
// `MetadataModels.swift`. `PersistentModel` classes are context-bound
// reference types and are NOT `Sendable` (Swift 6 strict concurrency
// correctly rejects returning them across the `MetadataStore` actor
// boundary ، confirmed by trying it first: the compiler flags every
// cross-actor return of a raw `@Model` type). `MetadataStore`'s public API
// (task 15) therefore returns these plain-struct snapshots instead of the
// live model objects; only code running INSIDE the `@ModelActor` ever
// touches a `PersistentModel` instance directly.

public struct MKProjectSummary: Sendable, Equatable, Identifiable {
    public var id: UUID { projectID }
    public let projectID: UUID
    public let title: String
    public let folderID: UUID?
    public let createdAt: Date
    public let modifiedAt: Date
    public let canvasWidth: Double
    public let canvasHeight: Double
    public let thumbnailPath: String?
    public let searchText: String
    public let premiumContentPresent: Bool
    public let packageRelativePath: String
    public let syncState: Int
    public let lastSyncedChangeTag: String?
    public let isOrphaned: Bool

    public init(
        projectID: UUID, title: String, folderID: UUID?, createdAt: Date, modifiedAt: Date,
        canvasWidth: Double, canvasHeight: Double, thumbnailPath: String?, searchText: String,
        premiumContentPresent: Bool, packageRelativePath: String, syncState: Int,
        lastSyncedChangeTag: String?, isOrphaned: Bool
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

    init(_ record: MKProjectRecord) {
        self.init(
            projectID: record.projectID, title: record.title, folderID: record.folderID,
            createdAt: record.createdAt, modifiedAt: record.modifiedAt,
            canvasWidth: record.canvasWidth, canvasHeight: record.canvasHeight,
            thumbnailPath: record.thumbnailPath, searchText: record.searchText,
            premiumContentPresent: record.premiumContentPresent,
            packageRelativePath: record.packageRelativePath, syncState: record.syncState,
            lastSyncedChangeTag: record.lastSyncedChangeTag, isOrphaned: record.isOrphaned
        )
    }
}

public struct MKFolderSummary: Sendable, Equatable, Identifiable {
    public var id: UUID { folderID }
    public let folderID: UUID
    public let name: String
    public let sortOrder: Int

    public init(folderID: UUID, name: String, sortOrder: Int) {
        self.folderID = folderID
        self.name = name
        self.sortOrder = sortOrder
    }

    init(_ record: MKFolderRecord) {
        self.init(folderID: record.folderID, name: record.name, sortOrder: record.sortOrder)
    }
}

public struct MKExportSummary: Sendable, Equatable, Identifiable {
    public var id: UUID { exportID }
    public let exportID: UUID
    public let projectID: UUID
    public let date: Date
    public let format: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let presetID: String?
    public let wasPremium: Bool
    public let success: Bool

    public init(
        exportID: UUID, projectID: UUID, date: Date, format: String, pixelWidth: Int,
        pixelHeight: Int, presetID: String?, wasPremium: Bool, success: Bool
    ) {
        self.exportID = exportID
        self.projectID = projectID
        self.date = date
        self.format = format
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.presetID = presetID
        self.wasPremium = wasPremium
        self.success = success
    }

    init(_ record: MKExportRecord) {
        self.init(
            exportID: record.exportID, projectID: record.projectID, date: record.date,
            format: record.format, pixelWidth: record.pixelWidth, pixelHeight: record.pixelHeight,
            presetID: record.presetID, wasPremium: record.wasPremium, success: record.success
        )
    }
}
