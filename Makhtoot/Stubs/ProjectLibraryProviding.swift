import CoreGraphics
import Foundation
import MKFoundation
import MKModel

/// A project's browser-visible metadata (WS-13 packet §5 T4-T8). This is
/// the **shell's own seam**, deliberately distinct from `MKDocumentStoring`
/// (`MKFoundation`, WS-01): `MKDocumentStoring` persists opaque document
/// bytes keyed by `MKProjectID`, but the project browser needs to list,
/// name, sort, and organize documents *without* ever reading their content
/// (D-112: "browser reads ONLY the SwiftData metadata index, never
/// scene.json"). As of this P1-COMPLETION session the real conformer is
/// `MKPersistenceProjectLibrary` (`Makhtoot/AppShell/Persistence/`),
/// backed by WS-02's `MetadataStore`/`LaunchReconciler`/`DocumentPackage` ،
/// see `AppContainer`'s stub-matrix header for the swap-log entry.
struct ProjectSummary: Identifiable, Hashable, Sendable {
    let id: MKProjectID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
    /// `nil` = no folder (root level). Folder identity is a plain `UUID`
    /// (not an `MKID<Tag>`) since no folder phantom-tag exists in
    /// `MKFoundation` and this seam is app-local.
    var folderID: UUID?
    var canvasSize: CGSize
    /// D-119 gating marker ، mirrors `MKProjectRecord.premiumContentPresent`.
    var premiumContentPresent: Bool
    /// `true` when `LaunchReconciler` found no package on disk for this
    /// record (WS-02 §17) ، the browser renders a distinct "غير متاح على
    /// هذا الجهاز" (not available on this device) state instead of
    /// silently dropping the entry.
    var isOrphaned: Bool
    /// URL to the project's cached thumbnail PNG, or nil if not generated yet.
    var thumbnailURL: URL?
}

/// A project folder (WS-13 packet §5 T5). One level deep in v1 UI, per the
/// packet's own scope note ، nesting is a model-level seam
/// (`MKFolderRecord` has no `parentFolderID` either, matching WS-02's own
/// v1 shape), not something this slice's UI exposes.
struct ProjectFolderSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var sortOrder: Int
}

/// One export-history row (WS-13 packet §5 T16), mirroring WS-02's
/// `MKExportSummary` fields the browser's history sheet actually renders.
struct ProjectExportHistoryEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var format: String
    var pixelWidth: Int
    var pixelHeight: Int
    var wasPremium: Bool
    var success: Bool
}

/// Thrown by `ProjectLibraryProviding.importExternalPackage(at:)` when
/// `url` cannot be imported. UX-5: this used to be a single `.invalidPackage`
/// case, so `RootShellView`'s alert always rendered the same generic Arabic
/// sentence regardless of which of these actually happened ، three distinct
/// buckets now exist, matching the three distinct messages `RootShellView`
/// renders.
enum ProjectImportError: Error {
    /// No `.makhtoot` package exists at `url`, or this library's own
    /// metadata store could not be opened at all (which makes any import a
    /// no-op regardless of what's actually at `url`).
    case missingPackage
    /// A package directory exists at `url` but its `manifest.json` is
    /// missing, unreadable, or fails to decode.
    case malformedManifest
    /// The package failed S-4's byte/file-count/shape validation
    /// (`DocumentPackage.validateForImport`), the filesystem copy into this
    /// app's own managed storage failed outright (including a full disk), or
    /// the copy succeeded but the package could not be indexed afterward.
    /// `underlying` is preserved for logging only ، the UI collapses all
    /// three onto one Arabic message since none of them are actionable by
    /// the user beyond "try again" / "free up space".
    case copyFailed(underlying: Error)
}

extension ProjectImportError: Equatable {
    /// Hand-written: `Error` does not conform to `Equatable`, so
    /// `.copyFailed`'s associated value is compared by case only ، its
    /// `underlying` error is for logging, never for equality checks.
    static func == (lhs: ProjectImportError, rhs: ProjectImportError) -> Bool {
        switch (lhs, rhs) {
        case (.missingPackage, .missingPackage): return true
        case (.malformedManifest, .malformedManifest): return true
        case (.copyFailed, .copyFailed): return true
        default: return false
        }
    }
}

extension Notification.Name {
    /// Posted (on the main actor) once a project's `thumbnail.png` has
    /// actually landed on disk and been recorded.
    ///
    /// Bug fix (2026-07-29, user report: "photos don't appear in
    /// homescreen project previews"). The real thumbnail ، the one that
    /// contains the user's photo background and their design ، is rendered
    /// by `EditorViewModel.generateThumbnailInBackground()` from a
    /// `Task.detached` deliberately NOT awaited by editor dismissal, so it
    /// routinely lands AFTER the browser has already reappeared, reloaded,
    /// and decoded the blank canvas-only template thumbnail written at
    /// project-creation time. Nothing then invalidated that decode:
    /// `ProjectThumbnailView` keys its `.task` on the thumbnail URL, which
    /// is the same `thumbnail.png` path before and after, so the stale
    /// image survived until the next cold launch.
    ///
    /// The browser listens for this and bumps its reload token, which is
    /// part of the thumbnail view's task id ، closing the race from the
    /// writer's side rather than hoping the reader wins it.
    static let mkProjectThumbnailUpdated = Notification.Name("net.binjamshid.makhtoot.projectThumbnailUpdated")
}

/// The project-list seam the browser view model reads/writes: flat
/// create/list/rename/delete (T4), folders (T5), search (T6), duplicate
/// (T7), and export-history read access (T16 ، only if `MKPersistence`
/// exposes it, which `MetadataStore.exportHistory(projectID:)` does).
protocol ProjectLibraryProviding: Sendable {
    /// Lists projects, optionally scoped to one folder. `nil` = every
    /// project (flat "كل المشاريع" view); pass an explicit folder id to
    /// scope to that folder's contents only.
    func fetchAll(folderID: UUID?) async -> [ProjectSummary]

    /// Arabic-normalized search across project titles + layer names
    /// (T6, D-112 as amended ، never scene text content; the store already
    /// enforces this, see WS02-A6).
    func search(_ query: String) async -> [ProjectSummary]

    func listFolders() async -> [ProjectFolderSummary]
    @discardableResult func createFolder(name: String) async -> ProjectFolderSummary?
    func renameFolder(_ id: UUID, to name: String) async
    /// Deletes the folder; projects inside it move to root (never deleted
    /// with the folder ، T5 accept criterion).
    func deleteFolder(_ id: UUID) async
    func move(_ id: MKProjectID, toFolder folderID: UUID?) async

    @discardableResult func create(name: String, canvas: MKCanvasSpec) async -> ProjectSummary?
    func rename(_ id: MKProjectID, to name: String) async
    func delete(_ id: MKProjectID) async
    /// Deep-copy with a new id + "نسخة من X" name (T7).
    @discardableResult func duplicate(_ id: MKProjectID) async -> ProjectSummary?

    func exportHistory(_ id: MKProjectID) async -> [ProjectExportHistoryEntry]

    /// Best-effort "recheck backing storage" hook (T14: foreground
    /// scene-phase refresh ، catches packages that appeared/disappeared,
    /// e.g. iCloud Drive finishing a download, while the app was
    /// backgrounded). A no-op for conformers with no external state to
    /// reconcile against.
    func refreshFromDisk() async

    /// Resolves `id`'s on-disk `.makhtoot` package root URL (WS-13 P4
    /// EDITOR-CHROME session, T11) ، the one thing the editor needs from
    /// this seam that T4-T8's summary-only shape didn't: a real
    /// `MakhtootDocument.open(at:)` call needs a concrete package URL, not
    /// a metadata row. `nil` when `id` is unknown to this conformer
    /// (including every `InMemoryProjectLibrary` fixture, which never
    /// writes a real package to disk ، see that type's own doc comment).
    func packageRootURL(for id: MKProjectID) async -> URL?

    /// P7.1 (§2.2 project thumbnails, Bug 1): records that `id`'s package
    /// thumbnail (`thumbnail.png`, the SAME relative filename
    /// `MKManifest.thumbnail` carries) was just (re)generated, so the
    /// browser's SwiftData-backed listing (`MKProjectRecord.thumbnailPath`)
    /// picks it up without re-scanning disk on every fetch. Called from two
    /// places: `EditorScene`'s editor-close choke point (fire-and-forget,
    /// since the render itself happens off the main actor and must not
    /// block dismissal) and project creation (synchronous, the template
    /// thumbnail is cheap ، an empty/background-only canvas). A no-op for
    /// conformers with no real SwiftData-backed record to update
    /// (`InMemoryProjectLibrary`'s fixture summaries have no on-disk
    /// thumbnail file to point at in the first place).
    func recordThumbnailGenerated(_ id: MKProjectID, relativeFilename: String) async

    /// Registers an externally-provided `.makhtoot` package ، e.g. opened
    /// via `.onOpenURL` from Files.app/AirDrop/"Open In" (WS-15, ITMS-90737
    /// follow-up: `Info.plist`'s `LSSupportsOpeningDocumentsInPlace`
    /// declares the capability; this is the method that actually fulfills
    /// it). Idempotent by the package's own durable id (baked into
    /// `manifest.json` at creation, per `MKPersistence.DocumentPackage`):
    /// if a project with this id is already known to this library (its own
    /// canonical copy, or a duplicate re-opened from another device), the
    /// EXISTING summary is returned unchanged rather than creating a second
    /// entry. Throws a `ProjectImportError` case ، see that type's own doc
    /// comment ، if `url` is not a real, readable `.makhtoot` package, or if
    /// it could not be copied into this app's managed storage.
    func importExternalPackage(at url: URL) async throws -> ProjectSummary
}

extension ProjectLibraryProviding {
    /// Convenience overload matching the original T4-only seam's call
    /// sites (`fetchAll()` == "every project, no folder scope").
    func fetchAll() async -> [ProjectSummary] { await fetchAll(folderID: nil) }
}

/// In-memory conformer: no disk I/O, no crash recovery, nothing survives
/// process exit. Retained for SwiftUI `#Preview` bodies only ، the real
/// app wiring (`AppContainer.init`) uses `MKPersistenceProjectLibrary`
/// exclusively as of this session (see that type's header comment).
actor InMemoryProjectLibrary: ProjectLibraryProviding {
    private var summaries: [MKProjectID: ProjectSummary] = [:]
    private var folders: [UUID: ProjectFolderSummary] = [:]
    private let documentStore: any MKDocumentStoring

    init(documentStore: any MKDocumentStoring) {
        self.documentStore = documentStore
    }

    func fetchAll(folderID: UUID?) async -> [ProjectSummary] {
        summaries.values
            .filter { folderID == nil || $0.folderID == folderID }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func search(_ query: String) async -> [ProjectSummary] {
        guard !query.isEmpty else { return await fetchAll(folderID: nil) }
        return summaries.values
            .filter { $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func listFolders() async -> [ProjectFolderSummary] {
        folders.values.sorted { $0.sortOrder < $1.sortOrder }
    }

    @discardableResult
    func createFolder(name: String) async -> ProjectFolderSummary? {
        let folder = ProjectFolderSummary(id: UUID(), name: name, sortOrder: folders.count)
        folders[folder.id] = folder
        return folder
    }

    func renameFolder(_ id: UUID, to name: String) async {
        folders[id]?.name = name
    }

    func deleteFolder(_ id: UUID) async {
        folders.removeValue(forKey: id)
        for (key, var summary) in summaries where summary.folderID == id {
            summary.folderID = nil
            summaries[key] = summary
        }
    }

    func move(_ id: MKProjectID, toFolder folderID: UUID?) async {
        summaries[id]?.folderID = folderID
    }

    @discardableResult
    func create(name: String, canvas: MKCanvasSpec) async -> ProjectSummary? {
        let id = MKProjectID()
        let now = Date()
        let summary = ProjectSummary(
            id: id, name: name, createdAt: now, modifiedAt: now,
            folderID: nil, canvasSize: canvas.size, premiumContentPresent: false, isOrphaned: false, thumbnailURL: nil
        )
        summaries[id] = summary
        try? await documentStore.save(Data(), for: id)
        return summary
    }

    func rename(_ id: MKProjectID, to name: String) async {
        guard var summary = summaries[id] else { return }
        summary.name = name
        summary.modifiedAt = Date()
        summaries[id] = summary
    }

    func delete(_ id: MKProjectID) async {
        summaries.removeValue(forKey: id)
        try? await documentStore.delete(for: id)
    }

    @discardableResult
    func duplicate(_ id: MKProjectID) async -> ProjectSummary? {
        guard let original = summaries[id] else { return nil }
        let newID = MKProjectID()
        let now = Date()
        let copy = ProjectSummary(
            id: newID, name: "\(original.name) نسخة", createdAt: now, modifiedAt: now,
            folderID: original.folderID, canvasSize: original.canvasSize,
            premiumContentPresent: original.premiumContentPresent, isOrphaned: false, thumbnailURL: nil
        )
        summaries[newID] = copy
        return copy
    }

    func exportHistory(_ id: MKProjectID) async -> [ProjectExportHistoryEntry] { [] }

    func refreshFromDisk() async {}

    /// Always `nil` ، no real `.makhtoot` package backs this fixture
    /// conformer (see the type's own doc comment); the editor's "open a
    /// live document" path has nothing to open here.
    func packageRootURL(for id: MKProjectID) async -> URL? { nil }

    /// No-op ، see the protocol doc comment: this fixture conformer never
    /// writes a real `.makhtoot` package/thumbnail file to disk.
    func recordThumbnailGenerated(_ id: MKProjectID, relativeFilename: String) async {}

    /// No real `.makhtoot` package ever backs this fixture conformer (see
    /// `packageRootURL(for:)` above) ، there is nothing to validate or
    /// copy, so this always fails with `.missingPackage`.
    func importExternalPackage(at url: URL) async throws -> ProjectSummary {
        throw ProjectImportError.missingPackage
    }
}
