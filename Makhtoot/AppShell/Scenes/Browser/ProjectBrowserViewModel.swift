import Foundation
import MKFoundation
import MKModel
import Observation

/// Reads/writes the project metadata index ، real `MKPersistence` as of
/// this P1-COMPLETION session (`MKPersistenceProjectLibrary`), never a
/// document's scene content (D-112: "browser reads ONLY the metadata
/// index"). Covers packet §5 T4 (grid/list), T5 (folders), T6 (search),
/// T7 (duplicate/rename/move/delete), T8 (preset-driven creation), and T16
/// (export-history read access).
@Observable
@MainActor
final class ProjectBrowserViewModel {
    private(set) var projects: [ProjectSummary] = []
    private(set) var folders: [ProjectFolderSummary] = []
    private(set) var isLoading = false

    /// `nil` = "الكل" (every project, unscoped ، matches
    /// `ProjectLibraryProviding.fetchAll(folderID: nil)`'s "every project"
    /// semantics); a folder id scopes the grid to that folder only (T5).
    private(set) var selectedFolderID: UUID?

    /// T6: debounced 200 ms search. Non-empty `searchQuery` replaces the
    /// grid with search results (ignoring the folder scope, per the
    /// packet's "results replace grid" wording); clearing it restores the
    /// folder-scoped list.
    var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            scheduleSearch()
        }
    }

    private let library: any ProjectLibraryProviding
    private var searchTask: Task<Void, Never>?

    init(library: any ProjectLibraryProviding) {
        self.library = library
    }

    var isSearching: Bool { !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - Load

    func load() async {
        isLoading = true
        async let projectsResult = isSearching ? library.search(searchQuery) : library.fetchAll(folderID: selectedFolderID)
        async let foldersResult = library.listFolders()
        projects = await projectsResult
        folders = await foldersResult
        isLoading = false
    }

    /// T14 foreground scene-phase refresh: re-run `LaunchReconciler`
    /// against on-disk state, then reload the grid.
    func refreshFromDisk() async {
        await library.refreshFromDisk()
        await load()
    }

    func selectFolder(_ id: UUID?) {
        guard selectedFolderID != id else { return }
        selectedFolderID = id
        searchQuery = ""
        Task { await load() }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    // MARK: - Projects (T4, T7, T8)

    /// Creates a project at `canvas` size (T8's preset sheet is the only
    /// caller). Returns `nil` on a real persistence failure (disk full,
    /// package write error) rather than throwing across the environment ،
    /// the caller (the browser view) treats `nil` as "stay on the sheet,
    /// nothing to navigate to."
    @discardableResult
    func createProject(canvas: MKCanvasSpec) async -> MKProjectID? {
        let summary = await library.create(name: Self.defaultProjectName(existingCount: projects.count), canvas: canvas)
        if let folderID = selectedFolderID, let id = summary?.id {
            await library.move(id, toFolder: folderID)
        }
        await load()
        return summary?.id
    }

    func delete(_ id: MKProjectID) async {
        await library.delete(id)
        await load()
    }

    func rename(_ id: MKProjectID, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await library.rename(id, to: trimmed)
        await load()
    }

    @discardableResult
    func duplicate(_ id: MKProjectID) async -> ProjectSummary? {
        let copy = await library.duplicate(id)
        await load()
        return copy
    }

    func move(_ id: MKProjectID, toFolder folderID: UUID?) async {
        await library.move(id, toFolder: folderID)
        await load()
    }

    func exportHistory(_ id: MKProjectID) async -> [ProjectExportHistoryEntry] {
        await library.exportHistory(id)
    }

    // MARK: - Folders (T5)

    @discardableResult
    func createFolder(name: String) async -> ProjectFolderSummary? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let folder = await library.createFolder(name: trimmed)
        await load()
        return folder
    }

    func renameFolder(_ id: UUID, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await library.renameFolder(id, to: trimmed)
        await load()
    }

    /// T5 accept criterion: "deleting a folder with 3 projects leaves 3
    /// projects at root" ، enforced by `MetadataStore.deleteFolder`
    /// (WS-02), not re-implemented here.
    func deleteFolder(_ id: UUID) async {
        if selectedFolderID == id { selectedFolderID = nil }
        await library.deleteFolder(id)
        await load()
    }

    private static func defaultProjectName(existingCount: Int) -> String {
        // Latin gloss: "untitled design <n>"
        let ordinal = MKRTLUtilities.toArabicIndicDigits(String(existingCount + 1))
        return "تصميم بلا عنوان \(ordinal)"
    }
}
