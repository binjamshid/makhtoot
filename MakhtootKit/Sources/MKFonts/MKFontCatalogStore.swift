import Foundation
import MKPersistence
import SwiftData

/// T6 ، SwiftData-backed catalog/favorites/download-state persistence.
///
/// `MKPersistence` (WS-02) already ships the schema this needs
/// (`MKFontCatalogRecord`/`MKFontFavoriteRecord`, part of
/// `MKMetadataSchema.models`) but its own `MetadataStore` actor (WS-02
/// territory, out of this packet's fence) has no CRUD methods over those
/// two models yet. Rather than edit `MetadataStore.swift` (a file this
/// packet does not own), `MKFontCatalogStore` is its own `@ModelActor`
/// wrapping a `ModelContext` over the SAME `ModelContainer`
/// `MetadataStore.makeContainer(at:)` already vends (that factory is
/// `public static`) ، the same multi-context-over-one-container pattern
/// SwiftData/CoreData support natively. Two independent actor-isolated
/// contexts over one container is standard SwiftData usage (each save is
/// scoped to its own context); it does mean a read in this store won't see
/// an uncommitted write from `MetadataStore` until that write's
/// transaction lands, which is fine here since the two stores touch
/// disjoint model types (`MKFontCatalogRecord`/`MKFontFavoriteRecord`
/// here; `MKProjectRecord`/`MKFolderRecord`/`MKExportRecord` there).
@ModelActor
public actor MKFontCatalogStore {
    public enum DownloadStateValue: Sendable, Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case failed(errorCode: String)

        // `Equatable`-friendly encode/decode to the SwiftData `Int` column
        // (`MKFontCatalogRecord.downloadState`) ، persisted state is just
        // "which case", not the transient `progress`/`errorCode` payload
        // (those live only in-memory via `MKFontRegistry`'s AsyncStream /
        // `MKFontDownloader`'s progress stream).
        public var rawValue: Int {
            switch self {
            case .notDownloaded: return 0
            case .downloading: return 1
            case .downloaded: return 2
            case .failed: return 3
            }
        }
        public static func from(rawValue: Int) -> DownloadStateValue {
            switch rawValue {
            case 1: return .downloading(progress: 0)
            case 2: return .downloaded
            case 3: return .failed(errorCode: "")
            default: return .notDownloaded
            }
        }
    }

    public func upsertCatalogEntry(
        fontID: MKFontID, displayNameAr: String, postScriptName: String, category: MKFontCategory,
        origin: MKFontOrigin, downloadState: DownloadStateValue = .notDownloaded, coverageClass: Int = 0
    ) throws {
        let descriptor = FetchDescriptor<MKFontCatalogRecord>(predicate: #Predicate { $0.fontID == fontID })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.displayNameAr = displayNameAr
            existing.postScriptName = postScriptName
            existing.category = category.rawValue
            existing.tier = origin.rawValue
            existing.downloadState = downloadState.rawValue
            existing.coverageClass = coverageClass
        } else {
            let record = MKFontCatalogRecord(
                fontID: fontID, displayNameAr: displayNameAr, postScriptName: postScriptName,
                category: category.rawValue, tier: origin.rawValue, downloadState: downloadState.rawValue,
                coverageClass: coverageClass
            )
            modelContext.insert(record)
        }
        try modelContext.save()
    }

    public func setFavorite(_ isFavorite: Bool, fontID: MKFontID) throws {
        let descriptor = FetchDescriptor<MKFontCatalogRecord>(predicate: #Predicate { $0.fontID == fontID })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.isFavorite = isFavorite

        let favDescriptor = FetchDescriptor<MKFontFavoriteRecord>(predicate: #Predicate { $0.fontID == fontID })
        let existingFav = try modelContext.fetch(favDescriptor).first
        if isFavorite, existingFav == nil {
            modelContext.insert(MKFontFavoriteRecord(fontID: fontID))
        } else if !isFavorite, let existingFav {
            modelContext.delete(existingFav)
        }
        try modelContext.save()
    }

    public func setTags(_ tags: [String], fontID: MKFontID) throws {
        let descriptor = FetchDescriptor<MKFontCatalogRecord>(predicate: #Predicate { $0.fontID == fontID })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.tags = tags
        try modelContext.save()
    }

    public func setDownloadState(_ state: DownloadStateValue, fontID: MKFontID, localPath: String? = nil) throws {
        let descriptor = FetchDescriptor<MKFontCatalogRecord>(predicate: #Predicate { $0.fontID == fontID })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.downloadState = state.rawValue
        if let localPath { record.localPath = localPath }
        try modelContext.save()
    }

    public func setLocked(_ locked: Bool, fontID: MKFontID) throws {
        let descriptor = FetchDescriptor<MKFontCatalogRecord>(predicate: #Predicate { $0.fontID == fontID })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.lockedByExpiry = locked
        try modelContext.save()
    }

    public func setLocked(_ locked: Bool, tiers: Set<Int>) throws {
        let descriptor = FetchDescriptor<MKFontCatalogRecord>()
        for record in try modelContext.fetch(descriptor) where tiers.contains(record.tier) {
            record.lockedByExpiry = locked
        }
        try modelContext.save()
    }

    public struct Summary: Sendable, Equatable {
        public var fontID: String
        public var displayNameAr: String
        public var category: String
        public var tier: Int
        public var downloadState: Int
        public var isFavorite: Bool
        public var tags: [String]
        public var lockedByExpiry: Bool
    }

    public func allEntries() throws -> [Summary] {
        try modelContext.fetch(FetchDescriptor<MKFontCatalogRecord>()).map {
            Summary(
                fontID: $0.fontID, displayNameAr: $0.displayNameAr, category: $0.category, tier: $0.tier,
                downloadState: $0.downloadState, isFavorite: $0.isFavorite, tags: $0.tags, lockedByExpiry: $0.lockedByExpiry
            )
        }
    }

    public func removeEntry(fontID: MKFontID) throws {
        let descriptor = FetchDescriptor<MKFontCatalogRecord>(predicate: #Predicate { $0.fontID == fontID })
        if let record = try modelContext.fetch(descriptor).first {
            modelContext.delete(record)
        }
        let favDescriptor = FetchDescriptor<MKFontFavoriteRecord>(predicate: #Predicate { $0.fontID == fontID })
        if let fav = try modelContext.fetch(favDescriptor).first {
            modelContext.delete(fav)
        }
        try modelContext.save()
    }
}
