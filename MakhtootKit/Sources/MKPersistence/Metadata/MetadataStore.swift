import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import SwiftData

// WS-02 packet §5 task 15. Query API over the SwiftData metadata store:
// list projects, search, create/rename/delete folder, duplicate project,
// record/list export history. `@ModelActor` gives this a private
// `modelContext`/`modelContainer` isolated to the actor, per SwiftData's
// concurrency model (a `ModelContext` is not `Sendable`).
//
// Every PUBLIC method returns `MKProjectSummary`/`MKFolderSummary`/
// `MKExportSummary` (Sendable structs, `MetadataSummaries.swift`), never
// the raw `@Model` classes ، see that file's header comment for why.

@ModelActor
public actor MetadataStore {
    // WS-11: AsyncStream continuation for MKProjectChange events.
    // Single consumer (MKSyncEngineController). Accessing `changes` again
    // replaces the continuation; the old stream ceases to receive events.
    private var changesContinuation: AsyncStream<MKProjectChange>.Continuation?
    /// Builds the `ModelContainer` this store's metadata lives in ،
    /// Application Support dir, `MKMetadataSchema`'s full model list
    /// (§13.6: "Store lives in Application Support; never contains scene
    /// JSON").
    public static func makeContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(MKMetadataSchema.models)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - Projects

    public func listProjects(folderID: UUID? = nil) throws -> [MKProjectSummary] {
        let descriptor: FetchDescriptor<MKProjectRecord>
        if let folderID {
            descriptor = FetchDescriptor(predicate: #Predicate { $0.folderID == folderID })
        } else {
            descriptor = FetchDescriptor()
        }
        return try modelContext.fetch(descriptor)
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .map(MKProjectSummary.init)
    }

    public func project(id: UUID) throws -> MKProjectSummary? {
        try fetchProjectRecord(id: id).map(MKProjectSummary.init)
    }

    private func fetchProjectRecord(id: UUID) throws -> MKProjectRecord? {
        let descriptor = FetchDescriptor<MKProjectRecord>(predicate: #Predicate { $0.projectID == id })
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    public func addProject(
        projectID: UUID, title: String, canvas: MKCanvasSpec, packageRelativePath: String,
        folderID: UUID? = nil, searchText: String? = nil, premiumContentPresent: Bool = false
    ) throws -> MKProjectSummary {
        let record = MKProjectRecord(
            projectID: projectID, title: title, folderID: folderID,
            canvasWidth: canvas.size.width, canvasHeight: canvas.size.height,
            searchText: searchText ?? SearchNormalizer.normalize(title),
            premiumContentPresent: premiumContentPresent, packageRelativePath: packageRelativePath
        )
        modelContext.insert(record)
        try modelContext.save()
        let summary = MKProjectSummary(record)
        changesContinuation?.yield(.created(summary))
        return summary
    }

    public func rename(projectID: UUID, to newTitle: String) throws {
        guard let record = try fetchProjectRecord(id: projectID) else { return }
        record.title = newTitle
        record.modifiedAt = Date()
        try modelContext.save()
        changesContinuation?.yield(.renamed(projectID, newTitle: newTitle))
    }

    public func move(projectID: UUID, toFolder folderID: UUID?) throws {
        guard let record = try fetchProjectRecord(id: projectID) else { return }
        record.folderID = folderID
        try modelContext.save()
        changesContinuation?.yield(.modified(MKProjectSummary(record)))
    }

    public func updateSearchText(projectID: UUID, sceneSearchText: String) throws {
        guard let record = try fetchProjectRecord(id: projectID) else { return }
        record.searchText = sceneSearchText
        try modelContext.save()
        // Not published as a change ، search text is local metadata only;
        // MKSync does not upload it.
    }

    public func markOrphaned(projectID: UUID, orphaned: Bool = true) throws {
        guard let record = try fetchProjectRecord(id: projectID) else { return }
        record.isOrphaned = orphaned
        try modelContext.save()
    }

    /// P7.1 (§2.2 project thumbnails, Bug 1): records the package-relative
    /// filename (e.g. `"thumbnail.png"`, matching `MKManifest.thumbnail`'s
    /// own convention) of a just-(re)generated thumbnail into the SwiftData
    /// index's `MKProjectRecord.thumbnailPath` ، this is the "derived
    /// Library/Caches-style cache" half of the two storage mechanisms the
    /// browser actually reads (`MKPersistenceProjectLibrary.summary(_:)`);
    /// `MKManifest.thumbnail` (the in-package copy `MKProjectRecordCoder`
    /// already syncs) is written separately, directly against the
    /// `DocumentPackage`, by whichever caller regenerated the PNG. Passing
    /// `nil` clears it (no thumbnail available/regeneration failed) rather
    /// than leaving a stale filename pointing at bytes that were never
    /// written this time.
    public func setThumbnailPath(projectID: UUID, relativeFilename: String?) throws {
        guard let record = try fetchProjectRecord(id: projectID) else { return }
        record.thumbnailPath = relativeFilename
        try modelContext.save()
        // Not published to `changesContinuation` ، a regenerated thumbnail
        // is local-display metadata only, not a user-visible project
        // mutation MKSync needs to know about (mirrors `updateSearchText`'s
        // own "local metadata only" precedent immediately above).
    }

    /// Marks the project as modified in the metadata store and publishes a
    /// `.modified` change event. Called by AutosaveController after a successful
    /// package write; `MKSync` uses this to know the project needs re-upload.
    public func markModified(projectID: UUID, modifiedAt: Date = Date(), contentHash: String? = nil) throws {
        guard let record = try fetchProjectRecord(id: projectID) else { return }
        record.modifiedAt = modifiedAt
        if let contentHash { record.lastSyncedChangeTag = contentHash }
        try modelContext.save()
        changesContinuation?.yield(.modified(MKProjectSummary(record)))
    }

    public func deleteProject(id: UUID) throws {
        guard let record = try fetchProjectRecord(id: id) else { return }
        modelContext.delete(record)
        try modelContext.save()
        // Record a tombstone so MKSync knows to delete upstream.
        try recordTombstone(id: id)
        changesContinuation?.yield(.deleted(id))
    }

    // MARK: - Tombstone registry (WS-11)

    /// Returns the IDs of all locally-deleted projects whose deletion has
    /// not yet been confirmed by the sync engine. Cleared per-id by
    /// `clearTombstone(id:)` once the server has accepted the deletion.
    public func tombstones() throws -> [UUID] {
        let descriptor = FetchDescriptor<MKTombstoneRecord>()
        return try modelContext.fetch(descriptor).map(\.projectID)
    }

    /// Records that project `id` was deleted locally. Called by
    /// `deleteProject(id:)` automatically; also callable directly when
    /// MKSync needs to record a deletion that bypasses the metadata store.
    public func recordTombstone(id: UUID) throws {
        // Idempotent: if a record already exists (e.g. double-delete), keep it.
        let descriptor = FetchDescriptor<MKTombstoneRecord>(
            predicate: #Predicate { $0.projectID == id }
        )
        guard try modelContext.fetch(descriptor).isEmpty else { return }
        let record = MKTombstoneRecord(projectID: id)
        modelContext.insert(record)
        try modelContext.save()
    }

    /// Removes the tombstone once the sync engine confirms server deletion.
    /// Safe to call even if no tombstone exists (idempotent).
    public func clearTombstone(id: UUID) throws {
        let descriptor = FetchDescriptor<MKTombstoneRecord>(
            predicate: #Predicate { $0.projectID == id }
        )
        for record in try modelContext.fetch(descriptor) {
            modelContext.delete(record)
        }
        try modelContext.save()
    }

    /// Deep-copies the `.makhtoot` package on disk with new ids and the
    /// Arabic "نسخة" (copy) name suffix (task 15/D-112).
    @discardableResult
    public func duplicateProject(id: UUID, documentsRootURL: URL) throws -> MKProjectSummary {
        guard let original = try fetchProjectRecord(id: id) else {
            throw MKPersistenceError.documentPackageNotFound(documentsRootURL)
        }
        let newID = UUID()
        let newRelativePath = "Projects/\(newID.uuidString).makhtoot"
        let sourceURL = documentsRootURL.appendingPathComponent(original.packageRelativePath)
        let destURL = documentsRootURL.appendingPathComponent(newRelativePath)

        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let package = DocumentPackage(rootURL: destURL)
        var manifest = try package.readManifest()
        let newTitle = "\(original.title) نسخة"
        manifest.projectID = MKProjectID(rawValue: newID)
        manifest.title = newTitle
        manifest.createdAt = Date()
        manifest.modifiedAt = Date()
        try package.writeManifest(manifest)

        // addProject publishes .created internally.
        return try addProject(
            projectID: newID, title: newTitle,
            canvas: MKCanvasSpec(size: CGSize(width: original.canvasWidth, height: original.canvasHeight)),
            packageRelativePath: newRelativePath, folderID: original.folderID,
            searchText: SearchNormalizer.normalize(newTitle), premiumContentPresent: original.premiumContentPresent
        )
    }

    // MARK: - Sync state helpers (WS-11)

    /// Updates the raw `syncState` integer and `lastSyncedChangeTag` on a
    /// project record. Called by `MKSyncEngineController` after a successful
    /// upload or remote-apply. Does NOT publish a change event (the sync
    /// engine's own state update must not trigger a re-upload loop).
    public func updateSyncState(projectID: UUID, syncState: Int, lastSyncedChangeTag: String?) throws {
        guard let record = try fetchProjectRecord(id: projectID) else { return }
        record.syncState = syncState
        record.lastSyncedChangeTag = lastSyncedChangeTag
        try modelContext.save()
        // Intentionally NOT publishing to changesContinuation: this is a
        // sync-engine metadata update, not a user-visible mutation.
    }

    /// A different iCloud account must not inherit the previous account's
    /// sync bookkeeping. Original project packages and local metadata stay.
    public func resetCloudSyncMetadata() throws {
        let projects = try modelContext.fetch(FetchDescriptor<MKProjectRecord>())
        let tombstones = try modelContext.fetch(FetchDescriptor<MKTombstoneRecord>())
        for record in projects {
            record.syncState = 0
            record.lastSyncedChangeTag = nil
        }
        for tombstone in tombstones {
            modelContext.delete(tombstone)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    // MARK: - Project change stream (WS-11)

    /// An `AsyncStream` of local project mutations. Single consumer (the
    /// `MKSyncEngineController`). Calling this property again replaces the
    /// previous continuation; the old stream stops receiving events.
    public var changes: AsyncStream<MKProjectChange> {
        // Finish the previous stream if one exists.
        changesContinuation?.finish()
        let (stream, continuation) = AsyncStream<MKProjectChange>.makeStream()
        changesContinuation = continuation
        return stream
    }

    // MARK: - Folders

    public func listFolders() throws -> [MKFolderSummary] {
        try modelContext.fetch(FetchDescriptor<MKFolderRecord>())
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(MKFolderSummary.init)
    }

    @discardableResult
    public func createFolder(name: String, sortOrder: Int = 0) throws -> MKFolderSummary {
        let record = MKFolderRecord(name: name, sortOrder: sortOrder)
        modelContext.insert(record)
        try modelContext.save()
        return MKFolderSummary(record)
    }

    public func renameFolder(id: UUID, to newName: String) throws {
        let descriptor = FetchDescriptor<MKFolderRecord>(predicate: #Predicate { $0.folderID == id })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.name = newName
        try modelContext.save()
    }

    public func deleteFolder(id: UUID) throws {
        let descriptor = FetchDescriptor<MKFolderRecord>(predicate: #Predicate { $0.folderID == id })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        // Projects in the deleted folder move to "no folder" rather than
        // being deleted themselves.
        let projectsDescriptor = FetchDescriptor<MKProjectRecord>(predicate: #Predicate { $0.folderID == id })
        for project in try modelContext.fetch(projectsDescriptor) {
            project.folderID = nil
        }
        try modelContext.save()
    }

    // MARK: - Search (task 15 accept: Arabic-normalized title/folder search)

    public func search(_ query: String) throws -> [MKProjectSummary] {
        let normalizedQuery = SearchNormalizer.normalize(query)
        guard !normalizedQuery.isEmpty else { return try listProjects() }
        return try modelContext.fetch(FetchDescriptor<MKProjectRecord>())
            .filter { $0.searchText.contains(normalizedQuery) || SearchNormalizer.matches(query: query, in: $0.title) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .map(MKProjectSummary.init)
    }

    // MARK: - Export history

    @discardableResult
    public func recordExport(
        projectID: UUID, format: String, pixelWidth: Int, pixelHeight: Int,
        presetID: String? = nil, wasPremium: Bool = false, success: Bool = true
    ) throws -> MKExportSummary {
        let record = MKExportRecord(
            projectID: projectID, format: format, pixelWidth: pixelWidth, pixelHeight: pixelHeight,
            presetID: presetID, wasPremium: wasPremium, success: success
        )
        modelContext.insert(record)
        try modelContext.save()
        return MKExportSummary(record)
    }

    public func exportHistory(projectID: UUID) throws -> [MKExportSummary] {
        let descriptor = FetchDescriptor<MKExportRecord>(predicate: #Predicate { $0.projectID == projectID })
        return try modelContext.fetch(descriptor).sorted { $0.date > $1.date }.map(MKExportSummary.init)
    }
}
