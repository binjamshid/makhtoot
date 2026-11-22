import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence
import MKRender
import MKSync
import UIKit

/// UX-5: the two internal-bootstrap edge cases inside
/// `importExternalPackage(at:)` that aren't really statements about `url`'s
/// own validity (see the call sites) still need SOME `Error` to carry as
/// `ProjectImportError.copyFailed(underlying:)`'s associated value for
/// logging; this is that placeholder rather than reusing an unrelated error
/// type.
enum MKProjectImportInternalError: Error {
    /// `ensureStore()` returned nil ، the metadata store itself could not be
    /// opened, independent of anything at the import URL.
    case storeUnavailable
    /// The package was copied (or already existed) and `LaunchReconciler`
    /// ran, but no matching record appeared in the store afterward.
    case notIndexedAfterReconcile
}

/// The real `ProjectLibraryProviding` conformer (WS-13 P1-COMPLETION,
/// packet §5 T4-T8, T14, T16), replacing the EARLY-SLICE
/// `InMemoryProjectLibrary` (`Makhtoot/Stubs/ProjectLibraryProviding.swift`)
/// per the stub-matrix promise: swapping a stub for a real implementation
/// is a one-file change in `AppContainer.init`, and this is that file.
///
/// Backed directly by WS-02's `MetadataStore` (SwiftData metadata index,
/// D-112) plus `DocumentPackage`/`LaunchReconciler` for the on-disk
/// `.makhtoot` packages under `Documents/Projects/`. This type never opens
/// a scene graph to build the browser list (D-112's "browser reads ONLY
/// the metadata index" rule) ، the one place it *does* touch package
/// bytes is `create(name:canvas:)`/`duplicate(_:)`, which must create/copy
/// the actual `.makhtoot` package on disk for the new project to exist at
/// all; after that, everything routes through `MetadataStore`.
///
/// **Lazy bootstrap, not blocking `init`.** Opening the SwiftData
/// `ModelContainer` and running `LaunchReconciler.reconcile` (a full
/// `Documents/Projects/` directory scan) are both real I/O. Per WS-13-A2's
/// "first frame must not await real subsystem startup" principle ، now
/// that a real subsystem (`MKPersistence`) exists to apply it to ، this
/// type's `init` only captures URLs (near-instant, no I/O beyond cheap
/// `FileManager` directory-URL resolution); the actual store-open +
/// reconcile pass happens on first protocol-method call, memoized via
/// `bootstrapTask` so concurrent early callers (e.g. the browser's
/// `.task` firing while a background scene-phase refresh is also in
/// flight) share one bootstrap instead of racing two SwiftData container
/// opens against the same file.
actor MKPersistenceProjectLibrary: ProjectLibraryProviding {
    private let documentsRootURL: URL
    private let projectsRootURL: URL
    private let appSupportURL: URL

    private var store: MetadataStore?
    private var bootstrapTask: Task<MetadataStore, Error>?

    init() {
        let fm = FileManager.default
        let documentsRootURL = (try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        self.documentsRootURL = documentsRootURL
        self.projectsRootURL = documentsRootURL.appendingPathComponent("Projects", isDirectory: true)
        self.appSupportURL = ((try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory).appendingPathComponent("Makhtoot", isDirectory: true)
    }

    // MARK: - Bootstrap

    private func ensureStore() async -> MetadataStore? {
        if let store { return store }
        if let bootstrapTask {
            return try? await bootstrapTask.value
        }
        let projectsRootURL = self.projectsRootURL
        let appSupportURL = self.appSupportURL
        let task = Task<MetadataStore, Error> {
            let fm = FileManager.default
            try fm.createDirectory(at: projectsRootURL, withIntermediateDirectories: true)
            try fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            let storeURL = appSupportURL.appendingPathComponent("MKMetadata.store")
            let container = try MetadataStore.makeContainer(at: storeURL)
            let store = MetadataStore(modelContainer: container)
            try await LaunchReconciler.reconcile(store: store, projectsRootURL: projectsRootURL)
            return store
        }
        bootstrapTask = task
        let result = try? await task.value
        if let result { store = result }
        return result
    }

    /// Re-runs `LaunchReconciler` against the current on-disk state
    /// (T14 protocol requirement ، see `ProjectLibraryProviding.refreshFromDisk()`).
    /// Safe to call anytime; triggers first bootstrap if it hasn't run yet.
    func refreshFromDisk() async {
        guard let store = await ensureStore() else { return }
        try? await LaunchReconciler.reconcile(store: store, projectsRootURL: projectsRootURL)
    }

    // MARK: - Mapping

    private func summary(_ record: MKProjectSummary) -> ProjectSummary {
        let packageURL = documentsRootURL.appendingPathComponent(record.packageRelativePath)
        var thumbnailURL: URL? = record.thumbnailPath.map { packageURL.appendingPathComponent($0) }
        // P7.1 lazy backfill: `MKProjectRecord.thumbnailPath` can be nil
        // even though `thumbnail.png` already exists in the package ، e.g.
        // the app was killed between `EditorViewModel`'s fire-and-forget
        // background write finishing and `recordThumbnailGenerated`
        // landing, or the file predates this fix. A plain
        // `fileExists(atPath:)` is cheap enough to run on every card render
        // (no file content is read here); once found, use it immediately
        // for THIS display and fire a detached write so every subsequent
        // fetch skips the disk check entirely.
        if thumbnailURL == nil {
            let candidate = packageURL.appendingPathComponent("thumbnail.png")
            if FileManager.default.fileExists(atPath: candidate.path) {
                thumbnailURL = candidate
                let projectID = MKProjectID(rawValue: record.projectID)
                Task { await self.recordThumbnailGenerated(projectID, relativeFilename: "thumbnail.png") }
            }
        }
        return ProjectSummary(
            id: MKProjectID(rawValue: record.projectID),
            name: record.title,
            createdAt: record.createdAt,
            modifiedAt: record.modifiedAt,
            folderID: record.folderID,
            canvasSize: CGSize(width: record.canvasWidth, height: record.canvasHeight),
            premiumContentPresent: record.premiumContentPresent,
            isOrphaned: record.isOrphaned,
            thumbnailURL: thumbnailURL
        )
    }

    private func folderSummary(_ record: MKFolderSummary) -> ProjectFolderSummary {
        ProjectFolderSummary(id: record.folderID, name: record.name, sortOrder: record.sortOrder)
    }

    private func exportEntry(_ record: MKExportSummary) -> ProjectExportHistoryEntry {
        ProjectExportHistoryEntry(
            id: record.exportID, date: record.date, format: record.format,
            pixelWidth: record.pixelWidth, pixelHeight: record.pixelHeight,
            wasPremium: record.wasPremium, success: record.success
        )
    }

    private func packageURL(relativePath: String) -> URL {
        documentsRootURL.appendingPathComponent(relativePath)
    }

    // MARK: - ProjectLibraryProviding

    func fetchAll(folderID: UUID?) async -> [ProjectSummary] {
        guard let store = await ensureStore() else { return [] }
        return ((try? await store.listProjects(folderID: folderID)) ?? []).map(summary)
    }

    func search(_ query: String) async -> [ProjectSummary] {
        guard let store = await ensureStore() else { return [] }
        return ((try? await store.search(query)) ?? []).map(summary)
    }

    func listFolders() async -> [ProjectFolderSummary] {
        guard let store = await ensureStore() else { return [] }
        return ((try? await store.listFolders()) ?? []).map(folderSummary)
    }

    @discardableResult
    func createFolder(name: String) async -> ProjectFolderSummary? {
        guard let store = await ensureStore() else { return nil }
        let sortOrder = (try? await store.listFolders().count) ?? 0
        guard let record = try? await store.createFolder(name: name, sortOrder: sortOrder) else { return nil }
        return folderSummary(record)
    }

    func renameFolder(_ id: UUID, to name: String) async {
        guard let store = await ensureStore() else { return }
        try? await store.renameFolder(id: id, to: name)
    }

    func deleteFolder(_ id: UUID) async {
        guard let store = await ensureStore() else { return }
        try? await store.deleteFolder(id: id)
    }

    func move(_ id: MKProjectID, toFolder folderID: UUID?) async {
        guard let store = await ensureStore() else { return }
        try? await store.move(projectID: id.rawValue, toFolder: folderID)
    }

    @discardableResult
    func create(name: String, canvas: MKCanvasSpec) async -> ProjectSummary? {
        guard let store = await ensureStore() else { return nil }
        let id = MKProjectID()
        let relativePath = "Projects/\(id.rawValue.uuidString).makhtoot"
        do {
            // `DocumentPackage.create` (not the `@MainActor` `MakhtootDocument`)
            // is the right level here: T8 only needs a real, openable
            // `.makhtoot` package to exist on disk and be indexed ، there is
            // no live editing session to drive (the editor is still
            // `EditorPlaceholderView`, WS-06/07 not yet landed), so standing
            // up `MakhtootDocument`'s undo stack/journal/autosave controller
            // for a document nothing ever mutates would be dead weight.
            let rootURL = packageURL(relativePath: relativePath)
            let package = try DocumentPackage.create(at: rootURL, projectID: id, title: name, canvas: canvas)
            let record = try await store.addProject(
                projectID: id.rawValue, title: name, canvas: canvas, packageRelativePath: relativePath
            )
            // P7.1 (§2.2 project thumbnails, Bug 1): render + persist a
            // TEMPLATE thumbnail immediately, synchronously, before this
            // project is ever opened ، so a never-opened project shows its
            // real canvas (aspect ratio + background) in the browser grid
            // instead of the generic "doc.richtext" placeholder glyph.
            // Cheap enough to do inline: the freshly-created scene has no
            // nodes yet (`MKScene`'s own `nodes: []` default), so neither
            // font shaping nor asset resolution is ever exercised.
            if let thumbnailData = Self.renderTemplateThumbnail(canvas: canvas) {
                do {
                    try package.writeThumbnail(thumbnailData)
                    var manifest = try package.readManifest()
                    manifest.thumbnail = "thumbnail.png"
                    try package.writeManifest(manifest)
                    try await store.setThumbnailPath(projectID: id.rawValue, relativeFilename: "thumbnail.png")
                } catch {
                    // Non-fatal: the project itself was created successfully;
                    // a missing template thumbnail just falls back to the
                    // placeholder glyph (and the lazy-backfill path in
                    // `summary(_:)` will pick it up later if a subsequent
                    // editor-close write succeeds).
                    MKLog.app.error("MKPersistenceProjectLibrary.create: template thumbnail failed: \(String(describing: error), privacy: .public)")
                }
            }
            return summary(record)
        } catch {
            MKLog.app.error("MKPersistenceProjectLibrary.create failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Renders a small (capped at 600 pt on the long edge, matching the
    /// editor-close thumbnail's own cap) PNG of a canvas-only scene
    /// (background + canvas size, no nodes) ، used both for the P7.1
    /// project-creation template thumbnail above. `MKEmptyAssetProvider`/
    /// `SystemFontStubProvider` are correct (not a shortcut): a
    /// freshly-created scene has no image/text nodes to resolve.
    private static func renderTemplateThumbnail(canvas: MKCanvasSpec) -> Data? {
        guard canvas.size.width > 0, canvas.size.height > 0 else { return nil }
        let cap: CGFloat = 600
        let scale = min(min(cap / canvas.size.width, cap / canvas.size.height), 1)
        let renderer = MKSnapshotRenderer(fonts: SystemFontStubProvider(), assets: MKEmptyAssetProvider())
        let scene = MKScene(canvas: canvas)
        guard let cgImage = renderer.render(scene, region: CGRect(origin: .zero, size: canvas.size), scale: scale, quality: .exportQuality) else {
            return nil
        }
        return UIImage(cgImage: cgImage).pngData()
    }

    /// See `ProjectLibraryProviding.recordThumbnailGenerated(_:relativeFilename:)`.
    func recordThumbnailGenerated(_ id: MKProjectID, relativeFilename: String) async {
        guard let store = await ensureStore() else { return }
        try? await store.setThumbnailPath(projectID: id.rawValue, relativeFilename: relativeFilename)
        // The thumbnail bytes are on disk by the time this is called (the
        // caller writes the package first), so this is the correct moment
        // to tell any visible project grid its decode is stale ، see
        // `Notification.Name.mkProjectThumbnailUpdated` for why the grid
        // cannot notice on its own.
        await MainActor.run {
            NotificationCenter.default.post(name: .mkProjectThumbnailUpdated, object: nil)
        }
    }

    func rename(_ id: MKProjectID, to name: String) async {
        guard let store = await ensureStore() else { return }
        // Manifest-first (WS-13 P1-COMPLETION gate fix). `LaunchReconciler`
        // treats an already-indexed package's `manifest.json` as untouched
        // on every launch ، it only reads `manifest.title` to seed a
        // *brand-new* SwiftData record, never to correct an existing one ،
        // but the package itself remains the durable artifact: if the
        // SwiftData title were updated first and the manifest write then
        // failed, the store and the on-disk package would permanently
        // disagree, and any future rebuild (task 17's "delete the SwiftData
        // store and relaunch" path) would silently resurrect the stale
        // pre-rename title. Writing the manifest first and only advancing
        // the store on success keeps both artifacts consistent; on failure
        // the store is left untouched so the UI immediately reflects the
        // (unchanged) title rather than optimistically showing a rename
        // that didn't durably happen.
        guard let record = try? await store.project(id: id.rawValue) else {
            MKLog.app.error("MKPersistenceProjectLibrary.rename failed: no record for \(id.rawValue.uuidString, privacy: .public)")
            return
        }
        let url = packageURL(relativePath: record.packageRelativePath)
        let package = DocumentPackage(rootURL: url)
        do {
            var manifest = try package.readManifest()
            manifest.title = name
            manifest.modifiedAt = Date()
            try package.writeManifest(manifest)
        } catch {
            MKLog.app.error("MKPersistenceProjectLibrary.rename failed to write manifest: \(String(describing: error), privacy: .public)")
            return
        }
        try? await store.rename(projectID: id.rawValue, to: name)
    }

    func delete(_ id: MKProjectID) async {
        guard let store = await ensureStore() else { return }
        if let record = try? await store.project(id: id.rawValue) {
            let url = packageURL(relativePath: record.packageRelativePath)
            try? FileManager.default.removeItem(at: url)
        }
        try? await store.deleteProject(id: id.rawValue)
    }

    @discardableResult
    func duplicate(_ id: MKProjectID) async -> ProjectSummary? {
        guard let store = await ensureStore() else { return nil }
        guard let record = try? await store.duplicateProject(id: id.rawValue, documentsRootURL: documentsRootURL) else { return nil }
        return summary(record)
    }

    func exportHistory(_ id: MKProjectID) async -> [ProjectExportHistoryEntry] {
        guard let store = await ensureStore() else { return [] }
        return ((try? await store.exportHistory(projectID: id.rawValue)) ?? []).map(exportEntry)
    }

    /// WS-13 P4 EDITOR-CHROME session (T11): the editor's one real need
    /// from this seam beyond the browser-only summary shape ، a concrete
    /// package root URL so `MakhtootDocument.open(at:)` has something to
    /// open. Reuses the exact `packageURL(relativePath:)` helper every
    /// other package-touching method here already goes through.
    func packageRootURL(for id: MKProjectID) async -> URL? {
        guard let store = await ensureStore() else { return nil }
        guard let record = try? await store.project(id: id.rawValue) else { return nil }
        return packageURL(relativePath: record.packageRelativePath)
    }

    /// See `ProjectLibraryProviding.importExternalPackage(at:)`. Validates
    /// `url` with the same cheap `DocumentPackage`/`readManifest()` read
    /// `MakhtootDocument.open` itself performs before doing anything heavier
    /// ، this only needs to confirm the package is real and read its
    /// durable id, not stand up a live editing session (no crash-recovery
    /// journal replay is needed just to import). A never-before-seen
    /// package is copied into this app's own managed `Documents/Projects/`
    /// folder (its manifest/id untouched) and handed to `LaunchReconciler`
    /// ، the SAME mechanism that already discovers any other package
    /// dropped into that folder by other means (e.g. Finder/iCloud file
    /// sharing) ، rather than duplicating its registration logic here.
    /// Creates a sync engine controller backed by this library's own
    /// `MetadataStore` and documents root, sharing the entitlement provider
    /// so the controller can gate on premium access.
    func makeSyncEngineController(
        entitlementProvider: any MKEntitlementProviding,
        statusPublisher: MKSyncStatusPublisher,
        preference: MKSyncPreference
    ) async -> MKSyncEngineController? {
        guard let store = await ensureStore() else { return nil }
        let appSupportURL = self.appSupportURL
        return MKSyncEngineController(
            metadataStore: store,
            documentsRootURL: documentsRootURL,
            entitlementProvider: entitlementProvider,
            statusPublisher: statusPublisher,
            applicationSupportURL: appSupportURL,
            preference: preference
        )
    }

    func importExternalPackage(at url: URL) async throws -> ProjectSummary {
        guard let store = await ensureStore() else {
            // The metadata store itself couldn't be opened ، this makes any
            // import a no-op regardless of what's actually at `url`, so it's
            // not really about `url`'s validity. UX-5 buckets it with the
            // other "could not bring this into managed storage" causes
            // rather than inventing a fourth user-facing message for a rare
            // internal-bootstrap failure.
            throw ProjectImportError.copyFailed(underlying: MKProjectImportInternalError.storeUnavailable)
        }

        let package = DocumentPackage(rootURL: url)
        guard package.exists else { throw ProjectImportError.missingPackage }
        guard let manifest = try? package.readManifest() else { throw ProjectImportError.malformedManifest }
        let id = manifest.projectID

        // Already known ، either this IS our own canonical copy (e.g. the
        // user browsed Files.app > On My iPhone/iPad > Makhtoot, which
        // `LSSupportsOpeningDocumentsInPlace` exposes) or a duplicate of a
        // project that already exists here under the same durable id (e.g.
        // AirDropped from another of the user's own devices). Either way,
        // resolve to the ALREADY-registered summary rather than risk
        // overwriting canonical state with a possibly-stale copy.
        if let existing = try? await store.project(id: id.rawValue) {
            return summary(existing)
        }

        let fm = FileManager.default
        try? fm.createDirectory(at: projectsRootURL, withIntermediateDirectories: true)
        let destinationURL = projectsRootURL.appendingPathComponent("\(id.rawValue.uuidString).makhtoot", isDirectory: true)
        if !fm.fileExists(atPath: destinationURL.path) {
            // S-4: this is the app's widest untrusted-input surface ، bound
            // its total size/shape BEFORE copying anything into this app's
            // own managed `Documents/Projects/` (which S-3's sync path would
            // otherwise dutifully upload verbatim to the user's own CloudKit
            // container). UX-5: this rejection and an outright copy failure
            // (including a full disk) both surface as `.copyFailed` ، the
            // underlying `Error` is preserved for logging (see
            // `ProjectImportError.copyFailed`'s own doc comment on why the
            // UI collapses them onto one Arabic message anyway).
            do {
                try DocumentPackage.validateForImport(at: url)
            } catch {
                MKLog.app.error("MKPersistenceProjectLibrary.importExternalPackage failed validation: \(String(describing: error), privacy: .public)")
                throw ProjectImportError.copyFailed(underlying: error)
            }
            do {
                try fm.copyItem(at: url, to: destinationURL)
            } catch {
                MKLog.app.error("MKPersistenceProjectLibrary.importExternalPackage failed to copy: \(String(describing: error), privacy: .public)")
                throw ProjectImportError.copyFailed(underlying: error)
            }
        }

        try? await LaunchReconciler.reconcile(store: store, projectsRootURL: projectsRootURL)
        guard let record = try? await store.project(id: id.rawValue) else {
            // The copy (or the pre-existing canonical package) succeeded,
            // but `LaunchReconciler` still didn't index it ، also bucketed
            // under `.copyFailed` (see above) since it's the same "could not
            // bring this into managed storage" family from the user's
            // perspective, not a statement about `url` itself being invalid.
            throw ProjectImportError.copyFailed(underlying: MKProjectImportInternalError.notIndexedAfterReconcile)
        }
        return summary(record)
    }
}
