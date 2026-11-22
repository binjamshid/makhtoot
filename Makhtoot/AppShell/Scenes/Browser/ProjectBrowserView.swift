import CoreGraphics
import Foundation
import ImageIO
import MKDesignSystem
import MKFoundation
import MKModel
import MKSync
import SwiftUI

/// The project browser (المشاريع) ، WS-13 packet §5 T4-T8, T16, wired to
/// real `.makhtoot` packages via `MKPersistenceProjectLibrary` as of this
/// P1-COMPLETION session (`docs/impl-log/WS-13.md`, this session's log).
/// Folders (T5), search (T6), duplicate/rename/move/delete (T7), a
/// preset-driven new-project sheet (T8), and an export-history read-only
/// entry point (T16) are all wired against the real `MetadataStore`.
struct ProjectBrowserView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container
    @Environment(AppNavigationModel.self) private var nav
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: ProjectBrowserViewModel?
    @State private var pendingDeletion: ProjectSummary?
    @State private var pendingFolderDeletion: ProjectFolderSummary?
    @State private var renamingProject: ProjectSummary?
    /// Bumped whenever on-disk thumbnails may have changed (a grid reload,
    /// or a `mkProjectThumbnailUpdated` post). Part of
    /// `ProjectThumbnailView`'s task id, which is otherwise just the
    /// thumbnail URL ، a path that never changes even when the file behind
    /// it is rewritten. See `Notification.Name.mkProjectThumbnailUpdated`.
    @State private var thumbnailReloadToken = 0
    @State private var showsNewProjectSheet = false
    @State private var showsNewFolderPrompt = false
    @State private var newFolderName = ""
    @State private var exportHistorySheet: ExportHistoryTarget?
    @ScaledMetric(relativeTo: .body) private var emptyStateIconSize: CGFloat = 40
    /// UX-5: the per-project sync badge used to be a silent icon ، tapping
    /// it while it shows `.error` (`SyncBadgeState`, which
    /// `MKSyncStatusAdapter.badge(for:)` also uses for the underlying
    /// `.conflictCopy`/`.needsAppUpdate` project states, not only a literal
    /// sync error) now surfaces the specific detail message here.
    @State private var syncErrorAlertTarget: SyncErrorAlertTarget?

    var onOpenSettings: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)]

    private struct ExportHistoryTarget: Identifiable {
        let id: MKProjectID
        let name: String
        let entries: [ProjectExportHistoryEntry]
    }

    private struct SyncErrorAlertTarget: Identifiable {
        let id: MKProjectID
        let message: String
    }

    var body: some View {
        content
            // A plain `.navigationTitle` renders through UIKit's large-title
            // chrome, which always uses the system font ، never the active
            // theme's `fonts.display` face (Aref Ruqaa / Lalezar / Reem
            // Kufi / …), so the one most-visible piece of text on this
            // screen silently ignored every theme change. Suppressing the
            // visible system title (empty string + `.inline`) and rendering
            // `titleHeading` as real content below the icon row instead is
            // what actually keeps the title on-theme; `browserTitle` still
            // backs VoiceOver's screen label via `.accessibilityLabel`.
            .navigationTitle(Text(""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    MKToolbarButton(systemImage: "gearshape", accessibilityLabel: settingsLabel) {
                        onOpenSettings()
                    }
                    MKToolbarButton(systemImage: "plus", accessibilityLabel: newProjectLabel, isProminent: true) {
                        showsNewProjectSheet = true
                    }
                }
            }
            .searchable(
                text: Binding(get: { viewModel?.searchQuery ?? "" }, set: { viewModel?.searchQuery = $0 }),
                prompt: Text(searchPrompt)
            )
            // See `MKSearchBarFontUpdater`'s header: `.searchable`'s native
            // UIKit search field ignores SwiftUI font modifiers entirely,
            // so it's kept on-theme by reaching into the live view
            // hierarchy directly, both on first appearance and whenever
            // the active theme's UI font changes.
            .onAppear {
                MKSearchBarFontUpdater.apply(postScriptName: theme.fonts.ui)
                // Returning here from the editor is the single most common
                // moment for a thumbnail to have just been rewritten.
                thumbnailReloadToken &+= 1
            }
            .onChange(of: theme.fonts.ui) { _, newValue in
                MKSearchBarFontUpdater.apply(postScriptName: newValue)
            }
            .task {
                if viewModel == nil {
                    let vm = ProjectBrowserViewModel(library: container.projectLibrary)
                    viewModel = vm
                    await vm.load()
                }
                #if DEBUG
                // Arrange-UX end-to-end drive entry point (WS-06/WS-13's
                // established precedent ، computer-use tap/drag injection
                // is unavailable in this environment, confirmed this
                // session via a `System Events` accessibility-access probe,
                // a strictly HARDER constraint than WS-13's own "drags are
                // unreliable" finding: taps are unreachable here at all).
                // `-mkE2EArrangeDrive` (an `xcrun simctl launch ... --args`
                // flag) auto-creates a project and opens the editor through
                // the EXACT SAME production call `createProject(canvas:)`
                // below uses ، never a bypass ، so an external screenshot
                // sequence can observe the real Arrange Mode flow end to
                // end. See `EditorScene.swift`'s matching DEBUG `.task` for
                // the in-editor half of the sequence.
                if ProcessInfo.processInfo.arguments.contains("-mkE2EArrangeDrive") {
                    createProject(canvas: MKCanvasSpec(size: CGSize(width: 1080, height: 1080)))
                }
                // Path Text end-to-end drive entry point (packet task 16's
                // E2E gate) ، same "auto-create a project through the real
                // `createProject(canvas:)` call, never a bypass" pattern as
                // `-mkE2EArrangeDrive` immediately above. See
                // `EditorScene.swift`'s matching DEBUG `.task` for the
                // in-editor half of the sequence.
                if ProcessInfo.processInfo.arguments.contains("-mkE2EPathDrive") {
                    createProject(canvas: MKCanvasSpec(size: CGSize(width: 1080, height: 1080)))
                }
                // TEMPORARY screenshot-fixture hooks (App Store screenshot
                // capture pass, not part of any WS packet) ، mirrors the
                // exact "auto-create via the real createProject(canvas:)
                // call" pattern the two flags above already establish.
                // `-mkScreenshotSeedProjects` populates the browser grid
                // with a handful of realistically-named/sized projects
                // (never the editor) so the browser screen doesn't screenshot
                // empty. `-mkScreenshotArrange` / `-mkScreenshotPath` create
                // one project each and open the editor, which then drives
                // its own screenshot-fixture sequence (see
                // `EditorScene.swift`'s matching `.task` and
                // `EditorViewModel.debugRunScreenshotArrangeSequence`/
                // `debugRunScreenshotPathSequence`). Intended to be reverted
                // after the screenshot pass ، see this block's own removal
                // note there.
                if ProcessInfo.processInfo.arguments.contains("-mkScreenshotSeedProjects") {
                    Task {
                        let fixtures: [(name: String, size: CGSize)] = [
                            ("بطاقة عيد الفطر", CGSize(width: 1080, height: 1080)),
                            ("دعوة زفاف", CGSize(width: 1200, height: 1600)),
                            ("غلاف كتاب ، ديوان شعر", CGSize(width: 1600, height: 2400)),
                            ("منشور تحفيزي", CGSize(width: 1080, height: 1350)),
                            ("شعار ، مخبز الأصالة", CGSize(width: 1200, height: 1200)),
                            ("لوحة خط الثلث", CGSize(width: 2000, height: 1400))
                        ]
                        for fixture in fixtures {
                            _ = await container.projectLibrary.create(name: fixture.name, canvas: MKCanvasSpec(size: fixture.size))
                        }
                        await viewModel?.load()
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("-mkScreenshotArrange") {
                    createProject(canvas: MKCanvasSpec(size: CGSize(width: 1080, height: 1080)))
                }
                if ProcessInfo.processInfo.arguments.contains("-mkScreenshotPath") {
                    createProject(canvas: MKCanvasSpec(size: CGSize(width: 1080, height: 1080)))
                }
                #endif
            }
            // Thumbnails are written out of band ، by the editor's detached
            // render task, after dismissal ، so the grid has to be told,
            // not left to notice. See
            // `Notification.Name.mkProjectThumbnailUpdated`.
            .onReceive(NotificationCenter.default.publisher(for: .mkProjectThumbnailUpdated)) { _ in
                thumbnailReloadToken &+= 1
            }
            // Refresh packages and thumbnails that changed in the background.
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                thumbnailReloadToken &+= 1
                Task { await viewModel?.refreshFromDisk() }
            }
            .sheet(isPresented: $showsNewProjectSheet) {
                NewProjectSheet(
                    onCreate: { canvas in createProject(canvas: canvas) },
                    onCreateFromPhoto: { canvas, data in
                        createProjectFromPhoto(canvas: canvas, data: data)
                    }
                )
            }
            .sheet(item: $exportHistorySheet) { target in
                ExportHistorySheet(projectName: target.name, entries: target.entries)
            }
            .alert(newFolderTitle, isPresented: $showsNewFolderPrompt) {
                TextField(newFolderPlaceholder, text: $newFolderName)
                Button(createLabel) {
                    let name = newFolderName
                    newFolderName = ""
                    Task { await viewModel?.createFolder(name: name) }
                }
                Button(cancelLabel, role: .cancel) { newFolderName = "" }
            }
            // Bug fix (2026-07-29, user report: "renaming a project is
            // super buggy"). This was a `.alert` carrying a `TextField`
            // bound to a separate `@State renameText` that the context-menu
            // action assigned just before flipping the presentation
            // binding, on a view that already hosts two `.sheet`s and three
            // more alerts/dialogs. That arrangement is the classic source
            // of a rename dialog that opens showing the PREVIOUS project's
            // name, opens blank, or ، presented straight out of a context
            // menu still running its own dismissal animation ، does not
            // open at all on the first try.
            //
            // A `.sheet(item:)` fixes all three by construction: the sheet
            // body cannot be built before an item exists, and
            // `RenameProjectSheet` seeds its own field state from that
            // item, so the text is right the first time and every time,
            // with no cross-presentation state to get out of step.
            .sheet(item: $renamingProject) { project in
                RenameProjectSheet(
                    title: renameTitle,
                    placeholder: renamePlaceholder,
                    saveLabel: saveLabel,
                    cancelLabel: cancelLabel,
                    currentName: project.name,
                    onSave: { newName in
                        Task { await viewModel?.rename(project.id, to: newName) }
                        renamingProject = nil
                    },
                    onCancel: { renamingProject = nil }
                )
            }
            .confirmationDialog(
                deleteConfirmTitle,
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(deleteConfirmButton, role: .destructive) {
                    if let pendingDeletion {
                        deleteProject(pendingDeletion.id)
                    }
                    self.pendingDeletion = nil
                }
                Button(cancelLabel, role: .cancel) { pendingDeletion = nil }
            } message: {
                Text(deleteConfirmMessage)
            }
            .confirmationDialog(
                deleteFolderConfirmTitle,
                isPresented: Binding(
                    get: { pendingFolderDeletion != nil },
                    set: { if !$0 { pendingFolderDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(deleteConfirmButton, role: .destructive) {
                    if let pendingFolderDeletion {
                        Task { await viewModel?.deleteFolder(pendingFolderDeletion.id) }
                    }
                    self.pendingFolderDeletion = nil
                }
                Button(cancelLabel, role: .cancel) { pendingFolderDeletion = nil }
            } message: {
                Text(deleteFolderConfirmMessage)
            }
            .alert(syncStatusAlertTitle, isPresented: Binding(
                get: { syncErrorAlertTarget != nil },
                set: { if !$0 { syncErrorAlertTarget = nil } }
            )) {
                Button(okLabel) { syncErrorAlertTarget = nil }
            } message: {
                Text(syncErrorAlertTarget?.message ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            VStack(spacing: 0) {
                titleHeading
                if !viewModel.isSearching {
                    folderChips(viewModel)
                }
                if viewModel.isLoading && viewModel.projects.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.bg)
                } else if viewModel.projects.isEmpty {
                    emptyState(isSearching: viewModel.isSearching)
                } else {
                    grid(viewModel.projects, viewModel: viewModel)
                }
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.bg)
        }
    }

    // MARK: - Title heading

    /// The real, theme-driven "hero" title (design handoff: "Large screen
    /// title المشاريع right-aligned, Aref Ruqaa 700, ink") ، see the
    /// `.navigationTitle` comment in `body` for why this exists instead of
    /// the native large-title chrome.
    private var titleHeading: some View {
        Text(browserTitle)
            .mkTypeStyle(theme.typeRamp.style(for: .largeTitle))
            .foregroundStyle(theme.ink)
            // RTL: `.leading` is the visual *right* edge ، matches the
            // handoff's "right-aligned" screen title.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, theme.spacing.lg)
            .padding(.top, theme.spacing.sm)
            .padding(.bottom, theme.spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Folders (T5)

    private func folderChips(_ viewModel: ProjectBrowserViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.sm) {
                MKChip(title: allFoldersLabel, isSelected: viewModel.selectedFolderID == nil) {
                    viewModel.selectFolder(nil)
                }
                ForEach(viewModel.folders) { folder in
                    MKChip(title: folder.name, isSelected: viewModel.selectedFolderID == folder.id) {
                        viewModel.selectFolder(folder.id)
                    }
                    .contextMenu {
                        Button {
                            pendingFolderDeletion = folder
                        } label: {
                            Label(deleteLabel, systemImage: "trash")
                        }
                    }
                }
                MKChip(title: newFolderChipLabel, isSelected: false) {
                    showsNewFolderPrompt = true
                }
            }
            .padding(.horizontal, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
        }
        .background(theme.bg)
    }

    // MARK: - Empty state

    private func emptyState(isSearching: Bool) -> some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            Image(systemName: isSearching ? "magnifyingglass" : "square.and.pencil")
                .font(.system(size: emptyStateIconSize))
                .foregroundStyle(theme.inkMuted)
            Text(isSearching ? emptySearchTitle : emptyStateTitle)
                .mkTypeStyle(theme.typeRamp.style(for: .title2))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            if !isSearching {
                Button(newProjectLabel) { showsNewProjectSheet = true }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primary)
            }
            Spacer()
            Spacer()
        }
        .padding(theme.spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
    }

    // MARK: - Grid (T4)

    private func grid(_ projects: [ProjectSummary], viewModel: ProjectBrowserViewModel) -> some View {
        let signpostState = MKAppSignpost.signposter.beginInterval("browserScroll")
        return ScrollView {
            LazyVGrid(columns: columns, spacing: theme.spacing.lg) {
                ForEach(projects) { project in
                    projectCard(project, viewModel: viewModel)
                }
            }
            .padding(theme.spacing.lg)
        }
        .background(theme.bg)
        .onAppear { MKAppSignpost.signposter.endInterval("browserScroll", signpostState) }
    }

    private func projectCard(_ project: ProjectSummary, viewModel: ProjectBrowserViewModel) -> some View {
        Button {
            guard !project.isOrphaned else { return }
            nav.openEditor(project.id, isRegularWidth: horizontalSizeClass == .regular)
        } label: {
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                    .fill(theme.canvasBackdrop)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProjectThumbnailView(
                            url: project.thumbnailURL,
                            isOrphaned: project.isOrphaned,
                            reloadToken: thumbnailReloadToken)
                    }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        syncBadge(for: project.id)
                            .padding(theme.spacing.xs)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style)
                            .strokeBorder(theme.border, lineWidth: 1)
                    }
                    .opacity(project.isOrphaned ? 0.5 : 1)

                Text(project.name)
                    .mkTypeStyle(theme.typeRamp.style(for: .callout))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)

                Text(project.isOrphaned ? orphanedLabel : MKArabicRelativeDate.string(from: project.modifiedAt))
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(project.isOrphaned ? theme.destructive : theme.inkFaint)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                nav.openEditor(project.id, isRegularWidth: horizontalSizeClass == .regular)
            } label: {
                Label(openLabel, systemImage: "arrow.up.forward.square")
            }
            Button {
                renamingProject = project
            } label: {
                Label(renameLabel, systemImage: "pencil")
            }
            Button {
                Task { await viewModel.duplicate(project.id) }
            } label: {
                Label(duplicateLabel, systemImage: "plus.square.on.square")
            }
            if !viewModel.folders.isEmpty {
                Menu {
                    Button(noFolderLabel) {
                        Task { await viewModel.move(project.id, toFolder: nil) }
                    }
                    ForEach(viewModel.folders) { folder in
                        Button(folder.name) {
                            Task { await viewModel.move(project.id, toFolder: folder.id) }
                        }
                    }
                } label: {
                    Label(moveToFolderLabel, systemImage: "folder")
                }
            }
            Button {
                Task {
                    let entries = await viewModel.exportHistory(project.id)
                    exportHistorySheet = ExportHistoryTarget(id: project.id, name: project.name, entries: entries)
                }
            } label: {
                Label(exportHistoryLabel, systemImage: "clock.arrow.circlepath")
            }
            Button(role: .destructive) {
                pendingDeletion = project
            } label: {
                Label(deleteLabel, systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func syncBadge(for id: MKProjectID) -> some View {
        switch container.syncStatusProvider.badge(for: id) {
        case .none:
            EmptyView()
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(theme.inkMuted)
        case .synced:
            Image(systemName: "checkmark.icloud.fill")
                .foregroundStyle(theme.primary)
        case .error:
            // UX-5: previously a silent icon. The coarse `SyncStatusProviding`
            // seam (`SyncBadgeState`) only exposes an `.error` bucket ،
            // `MKSyncStatusAdapter.badge(for:)` folds `.conflictCopy`/
            // `.error`/`.needsAppUpdate` all into it ، so the specific detail
            // is read straight from the real `MKSyncStatusPublisher`
            // (`container.syncStatusPublisher`, already exposed on
            // `AppContainer` alongside the `SyncStatusProviding` seam) rather
            // than through that coarser enum. `.highPriorityGesture` (not a
            // nested `Button`) intercepts the tap before `projectCard`'s own
            // outer `Button` ، the badge sits inside that button's label.
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundStyle(theme.destructive)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture().onEnded { presentSyncStatusDetail(for: id) }
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text(syncBadgeErrorAccessibilityLabel))
                .accessibilityValue(Text(syncStatusDetailMessage(for: id) ?? syncBadgeErrorAccessibilityLabel))
        }
    }

    /// The full detail message for `id`'s current sync state, when it's one
    /// of the "needs attention" states the badge's `.error` icon represents.
    /// `.error(let syncError)` gets the specific `MKSyncError.localizedMessage`
    /// (far more useful than the short badge label); `.conflictCopy`/
    /// `.needsAppUpdate` fall back to `MKSyncProjectState.badgeLabel`, which
    /// covers those two already. `nil` for every other state (never reached
    /// from the badge's `.error` branch above, since
    /// `MKSyncStatusAdapter.badge(for:)` only maps those three cases to
    /// `.error` in the first place).
    private func syncStatusDetailMessage(for id: MKProjectID) -> String? {
        let state = container.syncStatusPublisher.projectState(for: id.rawValue)
        if case .error(let syncError) = state {
            return syncError.localizedMessage
        }
        return state.badgeLabel
    }

    private func presentSyncStatusDetail(for id: MKProjectID) {
        guard let message = syncStatusDetailMessage(for: id) else { return }
        syncErrorAlertTarget = SyncErrorAlertTarget(id: id, message: message)
    }

    private func createProject(canvas: MKCanvasSpec) {
        showsNewProjectSheet = false
        Task {
            let id = await viewModel?.createProject(canvas: canvas)
            if let id {
                nav.openEditor(id, isRegularWidth: horizontalSizeClass == .regular)
            }
        }
    }

    /// P5.3: same creation/navigation path as `createProject(canvas:)`
    /// above, plus stashing the picked photo on `nav
    /// .pendingBackgroundImageImport` (keyed to the just-created project
    /// id) BEFORE navigating ، `EditorScene.open()` consumes it once that
    /// project's `EditorViewModel` exists, see that property's own doc
    /// comment for the full handoff and why it's needed at all (no
    /// `MakhtootDocument`/asset store exists yet at this call site).
    private func createProjectFromPhoto(canvas: MKCanvasSpec, data: Data) {
        showsNewProjectSheet = false
        Task {
            let id = await viewModel?.createProject(canvas: canvas)
            if let id {
                nav.pendingBackgroundImageImport = AppNavigationModel.PendingBackgroundImageImport(projectID: id, data: data)
                nav.openEditor(id, isRegularWidth: horizontalSizeClass == .regular)
            }
        }
    }

    private func deleteProject(_ id: MKProjectID) {
        Task { await viewModel?.delete(id) }
    }

    // MARK: - Strings

    private var browserTitle: String {
        // Latin gloss: projects (browser screen title)
        "المشاريع"
    }

    private var newProjectLabel: String {
        // Latin gloss: new project
        "مشروع جديد"
    }

    private var settingsLabel: String {
        // Latin gloss: settings
        "الإعدادات"
    }

    private var emptyStateTitle: String {
        // WS-13 packet §5 T4's exact copy: "start your first design"
        "ابدأ أول تصميم لك"
    }

    private var emptySearchTitle: String {
        // Latin gloss: no results
        "لا توجد نتائج"
    }

    private var searchPrompt: String {
        // Latin gloss: search projects
        "البحث في المشاريع"
    }

    private var deleteLabel: String {
        // Latin gloss: delete
        "حذف"
    }

    private var openLabel: String {
        // Latin gloss: open
        "فتح"
    }

    private var renameLabel: String {
        // Latin gloss: rename
        "إعادة تسمية"
    }

    private var duplicateLabel: String {
        // Latin gloss: duplicate
        "تكرار"
    }

    private var moveToFolderLabel: String {
        // Latin gloss: move to folder
        "نقل إلى مجلد"
    }

    private var noFolderLabel: String {
        // Latin gloss: no folder
        "بلا مجلد"
    }

    private var exportHistoryLabel: String {
        // Latin gloss: export history
        "سجل التصدير"
    }

    private var orphanedLabel: String {
        // Latin gloss: not available on this device
        "غير متاح على هذا الجهاز"
    }

    private var allFoldersLabel: String {
        // Latin gloss: all
        "الكل"
    }

    private var newFolderChipLabel: String {
        // Latin gloss: new folder (+)
        "مجلد جديد +"
    }

    private var newFolderTitle: String {
        // Latin gloss: new folder
        "مجلد جديد"
    }

    private var newFolderPlaceholder: String {
        // Latin gloss: folder name
        "اسم المجلد"
    }

    private var renameTitle: String {
        // Latin gloss: rename project
        "إعادة تسمية المشروع"
    }

    private var renamePlaceholder: String {
        // Latin gloss: project name
        "اسم المشروع"
    }

    private var createLabel: String {
        // Latin gloss: create
        "إنشاء"
    }

    private var saveLabel: String {
        // Latin gloss: save
        "حفظ"
    }

    private var cancelLabel: String {
        // Latin gloss: cancel
        "إلغاء"
    }

    private var deleteConfirmTitle: String {
        // Latin gloss: delete the project?
        "حذف المشروع؟"
    }

    private var deleteConfirmMessage: String {
        // WS-13 packet §5 T7's exact two-step-confirm copy: "the project
        // will be permanently deleted from this device"
        "سيُحذف المشروع نهائيًا من هذا الجهاز"
    }

    private var deleteFolderConfirmTitle: String {
        // Latin gloss: delete the folder?
        "حذف المجلد؟"
    }

    private var deleteFolderConfirmMessage: String {
        // Latin gloss: the folder will be deleted; its projects will move
        // to "all"
        "سيُحذف المجلد، وستنتقل مشاريعه إلى (الكل)"
    }

    private var deleteConfirmButton: String {
        "حذف"
    }

    private var syncBadgeErrorAccessibilityLabel: String {
        // Latin gloss: sync issue, double-tap for details
        "مشكلة في المزامنة، اضغط ضغطًا مزدوجًا للتفاصيل"
    }

    private var syncStatusAlertTitle: String {
        // Latin gloss: sync status
        "حالة المزامنة"
    }

    private var okLabel: String {
        // Latin gloss: OK
        "حسنًا"
    }
}

/// P7.1 (§2.2 project thumbnails, Bug 1): replaces a synchronous
/// `Data(contentsOf:)` + `UIImage(data:)` decode directly in
/// `projectCard`'s view body. That was harmless while `thumbnailURL` was
/// ALWAYS `nil` (`DocumentPackage.writeThumbnail(_:)` had zero production
/// callers before this phase), but now that real PNGs exist on disk, a
/// synchronous main-thread decode on every card ، re-run on every scroll
/// frame a card re-enters the viewport, since SwiftUI re-evaluates this
/// view's body freely ، would visibly stutter the grid. Decoding now
/// happens off the main thread inside `ProjectThumbnailCache`, keyed by URL
/// + content-modification-date so an updated thumbnail (a later
/// editor-close regenerating the same filename) invalidates the cache
/// entry instead of showing a stale image forever.
private struct ProjectThumbnailView: View {
    @Environment(\.mkTheme) private var theme
    let url: URL?
    let isOrphaned: Bool
    /// Changes whenever the file behind `url` may have been rewritten.
    /// Without it, `.task(id: url)` never re-runs ، `thumbnail.png` keeps
    /// the same path for a project's whole life, so the first decode (very
    /// often the blank creation-time template, which wins the race against
    /// the editor's detached real render) was the last one. `ProjectThumbnailCache`
    /// still short-circuits on mtime, so a token bump with nothing actually
    /// changed on disk costs one `stat`, not a decode.
    let reloadToken: Int

    @State private var image: UIImage?
    // UX-2: the call site (`ProjectBrowserView`'s grid card) applies
    // `.clipped()` right after this placeholder, so a scaled glyph never
    // spills past the thumbnail's own card bounds.
    @ScaledMetric(relativeTo: .body) private var placeholderIconSize: CGFloat = 28

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: isOrphaned ? "exclamationmark.icloud" : "doc.richtext")
                    .font(.system(size: placeholderIconSize))
                    .foregroundStyle(theme.inkMuted.opacity(0.5))
            }
        }
        .task(id: ThumbnailTaskID(url: url, reloadToken: reloadToken)) {
            guard let url else { image = nil; return }
            // Deliberately does NOT clear `image` first: on a reload token
            // bump the existing thumbnail is almost always still current,
            // and blanking it to the placeholder for the duration of a
            // `stat` makes the whole grid flicker every time the browser
            // reappears.
            if let decoded = await ProjectThumbnailCache.shared.image(for: url) {
                image = decoded
            }
        }
    }
}

/// Rename form (replacing the old `.alert` + `TextField`, see the call
/// site for what was wrong with that). Owns its own draft text, seeded
/// once from `currentName` at init ، the sheet body cannot even be
/// constructed until `.sheet(item:)` has a project, so there is no window
/// in which the field can hold a stale or empty value.
private struct RenameProjectSheet: View {
    @Environment(\.mkTheme) private var theme
    let title: String
    let placeholder: String
    let saveLabel: String
    let cancelLabel: String
    let currentName: String
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var draft: String
    @FocusState private var isFieldFocused: Bool

    init(
        title: String, placeholder: String, saveLabel: String, cancelLabel: String,
        currentName: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.saveLabel = saveLabel
        self.cancelLabel = cancelLabel
        self.currentName = currentName
        self.onSave = onSave
        self.onCancel = onCancel
        _draft = State(initialValue: currentName)
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(placeholder, text: $draft)
                    .focused($isFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { save() }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelLabel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveLabel, action: save)
                        // An empty name is silently discarded by
                        // `ProjectBrowserViewModel.rename`, which from the
                        // outside is indistinguishable from a rename that
                        // failed ، disable instead of pretending.
                        .disabled(trimmed.isEmpty || trimmed == currentName)
                }
            }
            .task {
                // Selecting the whole existing name is what every rename
                // field on the platform does; at minimum the keyboard must
                // come up without a second tap.
                isFieldFocused = true
            }
        }
        .presentationDetents([.height(200)])
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
    }
}

/// Composite `.task` id for `ProjectThumbnailView` ، the thumbnail's URL
/// plus the browser's reload token, so a rewritten file at an unchanged
/// path still re-runs the decode.
private struct ThumbnailTaskID: Hashable {
    let url: URL?
    let reloadToken: Int
}

/// Shared, `@MainActor`-confined (SwiftUI `Image`/`UIImage` are main-thread
/// types once handed to a view, but the decode itself runs off it) decode
/// cache. **Touches a file-timestamp API**
/// (`URLResourceValues.contentModificationDate`, `URL.resourceValues
/// (forKeys:)`) to key cache invalidation ، covered by
/// `Makhtoot/Resources/PrivacyInfo.xcprivacy`, which declares
/// `NSPrivacyAccessedAPICategoryFileTimestamp` with approved reason
/// `C617.1` ("access the timestamps, size, or other metadata of files
/// inside the app container, app group container, or the app's CloudKit
/// container") ، this call site reads only app-container project package
/// URLs, so it is within scope of that declaration.
@MainActor
final class ProjectThumbnailCache {
    static let shared = ProjectThumbnailCache()
    private init() {}

    private struct Cached { let mtime: Date?; let image: UIImage }
    private var cache: [URL: Cached] = [:]
    // `CGImage` (unlike `UIImage`) is `Sendable` in the SDK, so the
    // in-flight decode task crosses the `Task.detached` boundary as a
    // `CGImage?` ، `UIImage` itself is only ever constructed back on this
    // `@MainActor`-isolated type, never inside the detached closure.
    private var inFlight: [URL: Task<CGImage?, Never>] = [:]

    func image(for url: URL) async -> UIImage? {
        let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if let cached = cache[url], cached.mtime == mtime {
            return cached.image
        }
        let task: Task<CGImage?, Never>
        if let existing = inFlight[url] {
            task = existing
        } else {
            let newTask = Task<CGImage?, Never>.detached(priority: .utility) {
                Self.decodeCGImage(at: url)
            }
            inFlight[url] = newTask
            task = newTask
        }
        let cgImage = await task.value
        inFlight[url] = nil
        guard let cgImage else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache[url] = Cached(mtime: mtime, image: image)
        return image
    }

    private static nonisolated func decodeCGImage(at url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
