import Foundation
import MKCanvas
import MKDesignSystem
import MKExport
import MKFonts
import MKFoundation
import SwiftUI

/// The real editor composition (WS-13 P4 EDITOR-CHROME session, packet
/// T11) ، replaces `EditorPlaceholderView` as the `.editor(projectID)`
/// route destination. Opens a real `MakhtootDocument`, hosts the real
/// `MKCanvasViewController` (WS-06) full-bleed with WS-07's real render
/// tree, and composes toolbar/tool-rail/layers/inspector chrome around it,
/// adaptively per size class (T12).
struct EditorScene: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container
    @Environment(AppNavigationModel.self) private var nav
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let projectID: MKProjectID
    var onDone: () -> Void

    @State private var viewModel: EditorViewModel?
    @State private var openErrorText: String?
    @State private var isClosing = false

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if let viewModel {
                EditorContentView(viewModel: viewModel, fontRegistry: container.fontRegistry, isRegularWidth: isRegularWidth, onDone: { finish(viewModel) })
                    .disabled(isClosing)
            } else if let openErrorText {
                EditorOpenErrorView(message: openErrorText, onDone: onDone)
            } else {
                EditorLoadingView()
            }
        }
        .task { await open() }
    }

    private func open() async {
        guard viewModel == nil, openErrorText == nil else { return }
        guard let rootURL = await container.projectLibrary.packageRootURL(for: projectID) else {
            openErrorText = openErrorMissingPackage
            return
        }
        do {
            let vm = try await EditorViewModel(projectID: projectID, rootURL: rootURL, projectLibrary: container.projectLibrary, fontProvider: container.fontProvider)
            viewModel = vm
            // P5.3: consumes `NewProjectSheet`'s "ابدأ من صورة" handoff, if
            // this is the project it was created for ، see
            // `AppNavigationModel.pendingBackgroundImageImport`'s own doc
            // comment. Cleared immediately (not just on success) so a
            // failed/blocked ingest never re-fires on a later re-open of
            // the SAME project (`.task` only runs once per `EditorScene`
            // instance, but this guard also protects a fresh instance from
            // ever picking up a stale pending import left over from a
            // different, unrelated project).
            if let pending = nav.pendingBackgroundImageImport, pending.projectID == projectID {
                nav.pendingBackgroundImageImport = nil
                Task { await vm.setBackgroundImage(data: pending.data, entitlement: container.entitlementProvider) }
            }
            #if DEBUG
            // See `ProjectBrowserView.swift`'s matching DEBUG `.task` header
            // comment for why this exists at all (no interactive tap
            // injection available in this environment).
            if ProcessInfo.processInfo.arguments.contains("-mkE2EArrangeDrive") {
                Task { await vm.debugRunE2EArrangeSequence() }
            }
            // Path Text end-to-end drive (packet task 16's E2E gate) ،
            // mirrors `-mkE2EArrangeDrive`'s exact hook shape immediately
            // above; both flags can coexist (each editor session only ever
            // runs the one it was launched with, since `ProjectBrowserView`
            // only auto-creates ONE project per launch-arg check).
            if ProcessInfo.processInfo.arguments.contains("-mkE2EPathDrive") {
                Task { await vm.debugRunE2EPathSequence() }
            }
            // TEMPORARY screenshot-fixture hooks ، see
            // `ProjectBrowserView.swift`'s matching `.task` comment. Unlike
            // `-mkE2EArrangeDrive`/`-mkE2EPathDrive` (which end by
            // reverting/undoing back toward the original state, since
            // they're regression-evidence drives), these two end ON the
            // showcased feature state, for `xcrun simctl io screenshot`.
            if ProcessInfo.processInfo.arguments.contains("-mkScreenshotArrange") {
                Task { await vm.debugRunScreenshotArrangeSequence() }
            }
            if ProcessInfo.processInfo.arguments.contains("-mkScreenshotPath") {
                Task { await vm.debugRunScreenshotPathSequence() }
            }
            #endif
        } catch {
            openErrorText = openErrorGeneric
        }
    }

    private func finish(_ viewModel: EditorViewModel) {
        guard !isClosing else { return }
        isClosing = true
        Task {
            await viewModel.close()
            onDone()
        }
    }

    private var openErrorMissingPackage: String {
        // Latin gloss: this project could not be located on this device
        "تعذّر العثور على هذا المشروع على هذا الجهاز"
    }
    private var openErrorGeneric: String {
        // Latin gloss: an error occurred while opening the project
        "حدث خطأ أثناء فتح المشروع"
    }
}

private struct EditorLoadingView: View {
    @Environment(\.mkTheme) private var theme
    var body: some View {
        VStack(spacing: theme.spacing.md) {
            ProgressView()
            Text(loadingText)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
    }
    private var loadingText: String {
        // Latin gloss: opening the project…
        "جارٍ فتح المشروع…"
    }
}

private struct EditorOpenErrorView: View {
    @Environment(\.mkTheme) private var theme
    let message: String
    var onDone: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 40

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: iconSize))
                .foregroundStyle(theme.destructive)
            Text(message)
                .mkTypeStyle(theme.typeRamp.style(for: .body))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Button(doneLabel, action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding(theme.spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
    }
    private var doneLabel: String {
        // Latin gloss: done
        "تم"
    }
}

/// The real chrome composition ، separated from `EditorScene` so it only
/// exists once `viewModel` is non-nil (every subview below assumes a live
/// document).
private struct EditorContentView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container
    @Environment(AppNavigationModel.self) private var nav
    let viewModel: EditorViewModel
    let fontRegistry: MKFontRegistry
    let isRegularWidth: Bool
    var onDone: () -> Void
    @State private var tourModel = EditorTourModel()
    @State private var exportURL: URL?
    /// EU-4 (AUDIT_2026-07-28.md): drives the new export sheet ، replaces
    /// the old flat `Menu` of five bare format buttons (see
    /// `toolbarContent` and `ExportFormatSheet` below).
    @State private var showsExportSheet = false

    var body: some View {
        Group {
            if isRegularWidth {
                regularLayout
            } else {
                compactLayout
            }
        }
        .toolbar { toolbarContent }
        .navigationTitle(Text(viewModel.document.title))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // R-6.12/FL-13: revert-to-text confirmation ، exact PRD copy.
        .alert(
            MKArrangeRevertPreflight.confirmationTitle,
            isPresented: Binding(get: { viewModel.pendingRevertPreflight != nil }, set: { if !$0 { viewModel.cancelRevert() } })
        ) {
            Button(MKArrangeRevertPreflight.cancelAction, role: .cancel) { viewModel.cancelRevert() }
            Button(MKArrangeRevertPreflight.confirmAction, role: .destructive) { viewModel.confirmRevert() }
        } message: {
            Text(MKArrangeRevertPreflight.confirmationBody)
        }
        // R-6.11: arrange-then-edit-source conflict ، three-action choice
        // sheet, exact PRD copy.
        .confirmationDialog(
            MKArrangeSourceEditConflict.title,
            isPresented: Binding(get: { viewModel.arrangeSourceEditConflictNodeID != nil }, set: { if !$0 { viewModel.resolveArrangeConflictCancel() } }),
            titleVisibility: .visible
        ) {
            Button(MKArrangeSourceEditConflict.revertAndEdit, role: .destructive) { viewModel.resolveArrangeConflictRevertAndEdit() }
            Button(MKArrangeSourceEditConflict.duplicateThenEdit) { viewModel.resolveArrangeConflictDuplicateThenEdit() }
            Button(MKArrangeSourceEditConflict.cancel, role: .cancel) { viewModel.resolveArrangeConflictCancel() }
        }
        // R-8.12/D-221: recompose-after-edit confirmation ، exact PRD copy.
        .alert(
            recomposeConfirmationTitle,
            isPresented: Binding(get: { viewModel.pendingRecomposeConfirmation != nil }, set: { if !$0 { viewModel.cancelRecompose() } })
        ) {
            Button(MKArrangeSourceEditConflict.cancel, role: .cancel) { viewModel.cancelRecompose() }
            Button(recomposeConfirmAction, role: .destructive) { viewModel.confirmRecompose() }
        } message: {
            Text(MKArrangeRecomposePreflight.confirmationBody)
        }
        // R-8.10: fidelity-clamp auto-refusal notice.
        .alert(
            decomposeNoticeTitle,
            isPresented: Binding(get: { viewModel.decomposeFidelityNotice != nil }, set: { if !$0 { viewModel.decomposeFidelityNotice = nil } })
        ) {
            Button(okLabel) { viewModel.decomposeFidelityNotice = nil }
        } message: {
            Text(viewModel.decomposeFidelityNotice ?? "")
        }
        // EU-4 (AUDIT_2026-07-28.md): every export method used to
        // `catch { return nil }` ، a failed export silently did nothing.
        // `EditorViewModel.exportFailureMessage` (set from each export
        // method's `catch` block, via `runExport(_:coordinator:
        // entitlement:)`) now drives this alert instead, same
        // Optional-property convention as `decomposeFidelityNotice` above.
        .alert(
            exportFailedTitle,
            isPresented: Binding(get: { viewModel.exportFailureMessage != nil }, set: { if !$0 { viewModel.exportFailureMessage = nil } })
        ) {
            Button(okLabel) { viewModel.exportFailureMessage = nil }
        } message: {
            Text(viewModel.exportFailureMessage ?? "")
        }
        // R-7.5: armed mark re-attach ، long-press-to-cancel affordance
        // shown as a lightweight dismissible banner via the same alert
        // primitive (kept minimal ، this is a transient mode indicator,
        // not a data-loss confirmation).
        .overlay(alignment: .top) {
            if viewModel.pendingMarkReattachID != nil {
                Button {
                    viewModel.cancelPendingMarkReattach()
                } label: {
                    Text(reattachArmedText)
                        .mkTypeStyle(theme.typeRamp.style(for: .caption))
                        .padding(.horizontal, theme.spacing.md)
                        .padding(.vertical, theme.spacing.sm)
                        .background(theme.primary.opacity(0.85), in: Capsule())
                        .foregroundStyle(theme.onPrimary)
                }
                .padding(.top, theme.spacing.sm)
            }
        }
        .overlay {
            EditorTourOverlay(tourModel: tourModel)
        }
        // UX-6: `ToolRailView`'s three tour-highlight `GeometryReader`s now
        // report through `MKTourFramePreferenceKey` on every layout pass
        // instead of once via `.onAppear` ، this is the ancestor that owns
        // `tourModel`, so it's where the merged `[String: CGRect]` gets
        // applied back onto the model's three frame properties.
        .onPreferenceChange(MKTourFramePreferenceKey.self) { frames in
            if let frame = frames["font"] { tourModel.fontButtonFrame = frame }
            if let frame = frames["add"] { tourModel.addButtonFrame = frame }
            if let frame = frames["arrange"] { tourModel.arrangeButtonFrame = frame }
        }
        .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { exportURL = nil } })) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
        // EU-4: the new export sheet ، one row per format with a purpose
        // string, premium lock badge, and resolved output dimensions,
        // replacing the old flat `Menu` (see `toolbarContent` below).
        .sheet(isPresented: $showsExportSheet) {
            ExportFormatSheet(
                viewModel: viewModel,
                entitlementProvider: container.entitlementProvider,
                canvasSize: viewModel.session.scene.canvas.size,
                onPaywall: { nav.presentPaywall(.premiumFeatureTap(.exportFormat)) },
                onExported: { url in exportURL = url }
            )
        }
    }

    private var recomposeConfirmationTitle: String {
        // Latin gloss: recompose the ligature?
        "إعادة الوصلة؟"
    }
    private var recomposeConfirmAction: String {
        // Latin gloss: recompose
        "إعادة الدمج"
    }
    private var decomposeNoticeTitle: String {
        // Latin gloss: notice
        "تنبيه"
    }
    private var okLabel: String {
        // Latin gloss: OK
        "حسنًا"
    }
    private var reattachArmedText: String {
        // Latin gloss: tap a letter to attach the mark to it ، tap here to cancel
        "اضغط على حرف لإرفاق الحركة به ، اضغط هنا للإلغاء"
    }

    // MARK: - Layouts

    private var regularLayout: some View {
        HStack(spacing: 0) {
            canvasArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if viewModel.showsLayersColumn || viewModel.showsInspectorColumn {
                Divider()
                VStack(spacing: 0) {
                    // **Real bug found and fixed (WS-13 Session 3), root
                    // cause confirmed + re-verified (WS-13 Session 4,
                    // "Bug 4"):** both panels originally used
                    // `.frame(maxHeight: showsOther ? .infinity : nil)` ،
                    // when only ONE column was visible, `maxHeight: nil`
                    // left the `ScrollView` inside `LayersPanelView`/
                    // `InspectorPanelView` unconstrained in this `VStack`,
                    // which collapsed the `LazyVStack`'s available height
                    // to something too small to lay out more than one row
                    // (the iPad persistent-column layers list showed only
                    // the background row, while the IDENTICAL data through
                    // the iPhone sheet's `NavigationStack`-bounded context
                    // correctly showed every row). Unconditional
                    // `.frame(maxHeight: .infinity)` below ، always, not
                    // just when a sibling panel is also showing ، is the
                    // fix. Session 3's own re-test concluded this did NOT
                    // resolve the bug and left it open; Session 4 re-ran a
                    // full clean build + fresh install and could not
                    // reproduce the failure across solo-panel, dual-panel,
                    // cold-launch, and 2-to-28-row configurations ، every
                    // row rendered correctly in all of them, matching the
                    // iPhone sheet exactly (see `docs/impl-log/WS-13.md`
                    // Session 4 for the full reproduction matrix). The most
                    // likely explanation is that Session 3's re-test ran
                    // against a stale build/install (that session's own log
                    // documents an incomplete `xcrun simctl uninstall` and
                    // sibling-agent build races elsewhere), not that this
                    // fix is ineffective ، treat Bug 4 as CLOSED.
                    if viewModel.showsLayersColumn {
                        LayersPanelView(viewModel: viewModel)
                            .frame(maxHeight: .infinity)
                    }
                    if viewModel.showsLayersColumn, viewModel.showsInspectorColumn {
                        Divider()
                    }
                    if viewModel.showsInspectorColumn {
                        InspectorPanelView(viewModel: viewModel, fontRegistry: fontRegistry)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .background(theme.bg)
            }
        }
    }

    private var compactLayout: some View {
        canvasArea
            .sheet(item: Binding(get: { viewModel.presentedPanel }, set: { viewModel.presentedPanel = $0 })) { panel in
                NavigationStack {
                    Group {
                        switch panel {
                        case .layers: LayersPanelView(viewModel: viewModel)
                        case .inspector: InspectorPanelView(viewModel: viewModel, fontRegistry: fontRegistry)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(closeLabel) { viewModel.presentedPanel = nil }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
    }

    private var canvasArea: some View {
        ZStack {
            CanvasHostView(viewModel: viewModel, theme: theme)
                .ignoresSafeArea(edges: .bottom)

            // R-9.9: the frozen source-path ghost guide, drawn ABOVE the
            // canvas render but below the toolbar/panel chrome below ،
            // see `PathGhostGuideOverlay`'s own header for why this is
            // pure SwiftUI (never touches `MKRender`/export).
            PathGhostGuideOverlay(viewModel: viewModel)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)

            #if DEBUG
            if viewModel.showsPerfHUD {
                VStack {
                    HStack {
                        Spacer()
                        PerfHUDView(dataSource: viewModel.perfHUDDataSource)
                            .padding(theme.spacing.sm)
                    }
                    Spacer()
                }
            }
            #endif

            VStack(spacing: theme.spacing.sm) {
                MemoryBannerView(viewModel: viewModel)
                    .padding(.horizontal, theme.spacing.md)
                    .padding(.top, theme.spacing.sm)
                ArrangeErrorBannerView(viewModel: viewModel)
                    .padding(.horizontal, theme.spacing.md)
                Spacer()
                // P2.4: the token strip sits just above the toolbar row,
                // below the live canvas. Hidden during Arrange/Path-Edit
                // Mode ، `primaryRail` already swaps to a dedicated
                // toolbar in those modes (`ArrangeToolbarView`/
                // `PathEditToolbarView`), and jumping the top-level
                // selection out from under either mode mid-session would
                // fight that mode's own selection scope.
                if !viewModel.arrangeInteraction.isActive, !viewModel.pathTextInteraction.isActive {
                    TokenStripView(viewModel: viewModel)
                        .padding(.horizontal, theme.spacing.md)
                }
                if isRegularWidth {
                    // iPad: plenty of width ، rail and zoom controls share
                    // one row, rail on the leading (right-in-RTL) edge.
                    HStack(alignment: .bottom) {
                        primaryRail(axis: .horizontal, isRegularWidth: true)
                        Spacer()
                        VStack(alignment: .trailing, spacing: theme.spacing.sm) {
                            ZoomControlsView(viewModel: viewModel)
                            panelToggleRow
                        }
                    }
                    .padding(theme.spacing.md)
                } else {
                    // iPhone / compact: stacked, NOT side-by-side ، a
                    // shared row let the two floating bars compete for the
                    // same horizontal space and pushed content off-screen
                    // (see `ToolRailView`'s own doc comment on the bug this
                    // caught). Each bar gets its own full-width row and
                    // scrolls internally if it's still too wide.
                    VStack(spacing: theme.spacing.sm) {
                        ZoomControlsView(viewModel: viewModel)
                            .frame(maxWidth: .infinity, alignment: .center)
                        primaryRail(axis: .horizontal)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, theme.spacing.md)
                    .padding(.bottom, theme.spacing.md)
                }

                if let model = viewModel.presentedFormSelectorModel {
                    FormSelectorPopoverView(
                        model: model,
                        onSelect: { viewModel.selectForm($0) },
                        onDismiss: { viewModel.dismissFormSelector() }
                    )
                    .padding(theme.spacing.md)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                // R-9.4: the path options popover ، same "overlay at the
                // bottom of `canvasArea`" convention as the form selector
                // immediately above, driven by `EditorViewModel
                // .presentedPathOptions`.
                if viewModel.presentedPathOptions, viewModel.pathTextInteraction.isActive {
                    PathOptionsPopoverView(viewModel: viewModel)
                        .padding(theme.spacing.md)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.easeInOut(duration: theme.motion.standardDuration), value: viewModel.memoryBannerText)
            .animation(.easeInOut(duration: theme.motion.standardDuration), value: viewModel.arrangeInteraction.lastErrorMessage)
            .animation(.easeInOut(duration: theme.motion.standardDuration), value: viewModel.presentedFormSelectorModel != nil)
            .animation(.easeInOut(duration: theme.motion.standardDuration), value: viewModel.presentedPathOptions)
        }
    }

    /// R-6.7: the arrange toolbar REPLACES the standard object toolbar
    /// while Arrange Mode is active (FL-4 step 3's exact framing).
    @ViewBuilder
    private func primaryRail(axis: Axis, isRegularWidth: Bool = false) -> some View {
        if viewModel.arrangeInteraction.isActive {
            ArrangeToolbarView(viewModel: viewModel, axis: axis)
        } else if viewModel.pathTextInteraction.isActive {
            // R-9.3: the Path-Edit Mode toolbar replaces the standard
            // object toolbar exactly the way `ArrangeToolbarView` replaces
            // it for Arrange Mode above.
            PathEditToolbarView(viewModel: viewModel, axis: axis)
        } else {
            ToolRailView(viewModel: viewModel, fontRegistry: fontRegistry, axis: axis, isRegularWidth: isRegularWidth, tourModel: tourModel)
        }
    }

    private var panelToggleRow: some View {
        HStack(spacing: theme.spacing.xs) {
            MKChip(title: layersLabel, isSelected: viewModel.showsLayersColumn) {
                viewModel.showsLayersColumn.toggle()
            }
            MKChip(title: inspectorLabel, isSelected: viewModel.showsInspectorColumn) {
                viewModel.showsInspectorColumn.toggle()
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(doneLabel, action: onDone)
        }
        ToolbarItem(placement: .principal) {
            AutosaveIndicatorView(viewModel: viewModel)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            // Layers/inspector toggles moved OUT of this group entirely ،
            // see `ToolRailView`'s own doc comment on the bug this fixes:
            // iPhone's `.primaryAction` toolbar area silently DROPS items
            // past what fits (unlike a `Menu`, there is no overflow
            // affordance at all for plain `Button`s in a
            // `ToolbarItemGroup`), so with layers+inspector+undo+redo+
            // export+DEBUG all competing for the same compact-width bar,
            // "تراجع" (undo) itself became UNREACHABLE ، confirmed on-
            // simulator, not a hypothetical. Compact width now opens
            // panels from `ToolRailView` (already scrollable, so no
            // reachability risk); iPad already has `panelToggleRow`'s
            // `MKChip`s for the persistent-column toggle, which this
            // group's old buttons duplicated pointlessly anyway (setting
            // `presentedPanel`, a sheet-presentation trigger `regularLayout`
            // never reads).
            Button {
                viewModel.undo()
                viewModel.refreshCanvasChrome()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            // `MakhtootDocument` and `MKUndoStack` are now both
            // `@Observable` (P0.1), so `session.canUndo` is tracked
            // end-to-end and this button's `.disabled` state updates
            // correctly on its own. `EditorViewModel.canUndo` is now just a
            // thin passthrough to `session.canUndo` ، the manual mirror
            // that used to live here was removed in P0.1 (see that
            // property's doc comment in `EditorViewModel.swift`).
            .disabled(!viewModel.canUndo)
            .accessibilityLabel(undoLabel)

            Button {
                viewModel.redo()
                viewModel.refreshCanvasChrome()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!viewModel.canRedo)
            .accessibilityLabel(redoLabel)

            // P1.5 (§2.2): surfaces "Actual Size" (100% zoom) outside the
            // undiscoverable tap-the-percentage-badge gesture
            // (`ZoomControlsView`'s own `onTapGesture`, left as-is ، it
            // still works, this is an ADDITIONAL affordance, not a
            // replacement). `zoomToFit()` already has its own always-
            // visible, labelled `MKToolbarButton` in `ZoomControlsView`
            // (accessibilityLabel "ملائمة للشاشة") ، deliberately NOT
            // duplicated here, only Actual Size was missing a discoverable
            // affordance. Neither of this file's two existing `Menu`s (the
            // export menu below, the `#if DEBUG` menu further down) is a
            // sensible home for a view/zoom action, so this is a new,
            // minimal, single-item menu rather than overloading either of
            // them.
            Menu {
                Button(actualSizeLabel) {
                    viewModel.canvasViewController?.zoomTo100Percent()
                }
                // P5.5 (§2.2): display-only toggle over the existing
                // `SnapEngine`/`GuideRenderer` chrome mechanism ،
                // `session.showsGrid` never touches snap CANDIDATES/
                // threshold math (`SnapEngine.swift`), only whether
                // `MKCanvasViewController.gridRenderer` draws. Toggling an
                // `@Observable` `CanvasSession` property doesn't itself
                // trigger `MKCanvasViewController`'s UIKit-side refresh (no
                // SwiftUI `body` reads it), so this explicitly calls
                // `refreshCanvasChrome()` right after, the same forced-
                // refresh path undo/redo and inspector edits already use
                // (see that method's own doc comment).
                Button {
                    viewModel.session.showsGrid.toggle()
                    viewModel.refreshCanvasChrome()
                } label: {
                    Label(showGridLabel, systemImage: viewModel.session.showsGrid ? "checkmark.square" : "square.grid.3x3")
                }
            } label: {
                Image(systemName: "viewfinder")
            }
            .accessibilityLabel(viewOptionsLabel)

            // EU-4 (AUDIT_2026-07-28.md): the flat five-button `Menu` this
            // used to be gave no explanation of when to use which format,
            // no premium indication before tapping, no export progress, and
            // no way to cancel a long export. Replaced with a sheet (see
            // the `.sheet(isPresented: $showsExportSheet)` modifier above
            // and `ExportFormatSheet` below) that owns all five formats'
            // pre-check + paywall + export + share-sheet-handoff logic in
            // one place instead of duplicating it per button.
            Button {
                showsExportSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel(exportLabel)

            #if DEBUG
            Menu {
                Button(debugTypeArabicLabel) {
                    viewModel.debugSetActiveOverlayText("مرحبا بالعالم")
                    viewModel.debugCommitActiveOverlay()
                }
                Button(debugForceMemoryLabel) {
                    viewModel.debugForceMemoryStage(.stage2)
                }
                Button(debugApplyTransformLabel) {
                    viewModel.debugApplyTestTransform()
                }
                Button(debugMeasureManipulationLabel) {
                    viewModel.debugMeasureManipulationFrames()
                }
                Button(viewModel.showsPerfHUD ? debugHidePerfHUDLabel : debugShowPerfHUDLabel) {
                    viewModel.showsPerfHUD.toggle()
                }
                Button(debugDumpSnapshotLabel) {
                    viewModel.debugDumpSnapshotPNG()
                }
                Divider()
                // Arrange Mode E2E chain (packet task 15's end-to-end drive
                // gate ، mirrors the DEBUG-hook precedent above exactly:
                // computer-use drag/text-entry are unreliable in this
                // environment, docs/impl-log/WS-13.md Session 3, so this
                // exercises the same production model methods a real
                // gesture/tap would).
                Button(debugArrangeLabel) { viewModel.debugArrangeSelection() }
                Button(debugMoveGlyphLabel) { viewModel.debugMoveFirstGlyph(dx: 20, dy: -15) }
                Button(debugMoveMarkLabel) { viewModel.debugMoveFirstMark(dx: -8, dy: 6) }
                Button(debugBreakJoinLabel) { viewModel.debugBreakFirstJoin() }
                Button(debugSelectFormLabel) { viewModel.debugSelectIsolatedFormOnFirstGlyph() }
                Button(debugDecomposeLabel) { viewModel.debugDecomposeFirstLigature() }
                Button(debugRevertArrangedLabel) { viewModel.debugRevertArrangedSelection() }
                Divider()
                // Path Text E2E chain (packet task 16's manual-smoke-test
                // twin of the `-mkE2EPathDrive` launch-arg drive ، same
                // "computer-use drag/text-entry unreliable" precedent, kept
                // for a developer driving the app interactively instead of
                // via launch-arg).
                Button(debugAddCirclePathTextLabel) { viewModel.addPathText(preset: .circle) }
                Button(debugTogglePathEditLabel) { viewModel.togglePathEditMode() }
                Button(debugDragPathAnchorLabel) { viewModel.debugDragFirstPathAnchor(dx: 30, dy: -20) }
                Button(debugDragPathGlyphLabel) { viewModel.debugDragFirstPathGlyph(dx: 6, dy: -6) }
            } label: {
                Image(systemName: "ladybug")
            }
            .accessibilityLabel(debugMenuLabel)
            #endif
        }
    }

    private var doneLabel: String {
        // Latin gloss: done
        "تم"
    }
    private var closeLabel: String {
        // Latin gloss: close
        "إغلاق"
    }
    private var layersLabel: String {
        // Latin gloss: layers
        "الطبقات"
    }
    private var inspectorLabel: String {
        // Latin gloss: properties
        "الخصائص"
    }
    // UX-7: catalog-extractable accessibility labels ، feeds
    // `.accessibilityLabel(_:)` directly.
    private var undoLabel: LocalizedStringResource {
        // Latin gloss: undo
        "تراجع"
    }
    private var redoLabel: LocalizedStringResource {
        // Latin gloss: redo
        "إعادة"
    }
    private var viewOptionsLabel: LocalizedStringResource {
        // Latin gloss: view options
        "خيارات العرض"
    }
    private var actualSizeLabel: String {
        // Latin gloss: actual size (100% zoom)
        "الحجم الفعلي"
    }
    private var showGridLabel: String {
        // Latin gloss: show grid
        "إظهار الشبكة"
    }
    private var exportLabel: LocalizedStringResource {
        // Latin gloss: export
        "تصدير"
    }
    // EU-4: per-format labels (`exportJPEGLabel`/`exportPNGLabel`/etc.)
    // moved into `ExportFormatSheet`'s own `ExportFormatOption.displayName`
    // below ، this file's old flat `Menu` (five bare buttons) is gone, so
    // these lived nowhere else.
    private var exportFailedTitle: String {
        // Latin gloss: export failed
        "فشل التصدير"
    }
    private var debugMenuLabel: LocalizedStringResource { "DEBUG" }
    private var debugTypeArabicLabel: String {
        // Latin gloss: DEBUG: type sample Arabic text into the active overlay
        "DEBUG: كتابة نص عربي تجريبي"
    }
    private var debugArrangeLabel: String {
        // Latin gloss: DEBUG: arrange the selected text
        "DEBUG: تنسيق النص المحدد"
    }
    private var debugMoveGlyphLabel: String {
        // Latin gloss: DEBUG: move the first glyph
        "DEBUG: تحريك أول حرف"
    }
    private var debugMoveMarkLabel: String {
        // Latin gloss: DEBUG: move the first mark
        "DEBUG: تحريك أول حركة"
    }
    private var debugBreakJoinLabel: String {
        // Latin gloss: DEBUG: break the first join
        "DEBUG: فك أول ارتباط"
    }
    private var debugSelectFormLabel: String {
        // Latin gloss: DEBUG: select the isolated form on the first glyph
        "DEBUG: اختيار الشكل المنفصل لأول حرف"
    }
    private var debugDecomposeLabel: String {
        // Latin gloss: DEBUG: decompose the first ligature
        "DEBUG: فك أول وصلة"
    }
    private var debugRevertArrangedLabel: String {
        // Latin gloss: DEBUG: revert the arranged selection
        "DEBUG: استرجاع النص للعنصر المنسّق"
    }
    private var debugAddCirclePathTextLabel: String {
        // Latin gloss: DEBUG: add circle path text
        "DEBUG: إضافة نص على مسار دائري"
    }
    private var debugTogglePathEditLabel: String {
        // Latin gloss: DEBUG: toggle path-edit mode
        "DEBUG: تبديل وضع تحرير المسار"
    }
    private var debugDragPathAnchorLabel: String {
        // Latin gloss: DEBUG: drag the first path anchor
        "DEBUG: تحريك أول نقطة تثبيت في المسار"
    }
    private var debugDragPathGlyphLabel: String {
        // Latin gloss: DEBUG: drag a glyph offset on the path
        "DEBUG: تحريك إزاحة حرف على المسار"
    }
    private var debugForceMemoryLabel: String {
        // Latin gloss: DEBUG: force memory stage 2
        "DEBUG: فرض مرحلة الذاكرة ٢"
    }
    private var debugMeasureManipulationLabel: String {
        // Latin gloss: DEBUG: measure manipulation-frame performance
        "DEBUG: قياس أداء إطار التحريك"
    }
    private var debugShowPerfHUDLabel: String {
        // Latin gloss: DEBUG: show performance HUD
        "DEBUG: إظهار لوحة الأداء"
    }
    private var debugHidePerfHUDLabel: String {
        // Latin gloss: DEBUG: hide performance HUD
        "DEBUG: إخفاء لوحة الأداء"
    }
    private var debugApplyTransformLabel: String {
        // Latin gloss: DEBUG: apply a test move/scale/rotate to the selection
        "DEBUG: تحريك/تكبير/تدوير تجريبي"
    }
    private var debugDumpSnapshotLabel: String {
        // Latin gloss: DEBUG: dump a snapshot PNG (renderer diagnostic)
        "DEBUG: تصدير لقطة PNG للتشخيص"
    }
}

/// EU-4 (AUDIT_2026-07-28.md): the five export formats, in a fixed display
/// order, each carrying a one-line Arabic purpose string and premium-gate
/// status. A small UI-only enum (not the underlying `MKExportFormat`,
/// whose `.jpeg(quality:)` associated value doesn't give a free
/// `CaseIterable`/`Identifiable`/fixed-order row list) that mirrors D-118's
/// free/premium split exactly (`MKExportFormat.isFreeTierFormat`: JPEG +
/// raster PDF free; PNG + SVG + vector PDF premium).
private enum ExportFormatOption: CaseIterable, Identifiable {
    case jpeg, png, pdfRaster, svg, pdfVector
    var id: Self { self }

    var isPremium: Bool {
        switch self {
        case .jpeg, .pdfRaster: return false
        case .png, .svg, .pdfVector: return true
        }
    }

    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .pdfRaster: return "PDF (نقطية)"
        case .svg: return "SVG"
        case .pdfVector: return "PDF (متجه)"
        }
    }

    /// One-line purpose guidance, EU-4's exact three-way vocabulary
    /// («للطباعة»/«للنشر»/«للتحرير»). JPEG's fixed social-square preset
    /// maps to «للنشر» (publishing/sharing); PNG/SVG's native-canvas-size,
    /// further-editable output both map to «للتحرير» (editing elsewhere);
    /// the two PDF formats map to «للطباعة» (printing), matching PDF's
    /// conventional print role — raster for a quick print, vector for a
    /// professional one.
    var purposeText: String {
        switch self {
        case .jpeg:
            // Latin gloss: for sharing on social media
            return "للنشر على وسائل التواصل"
        case .png:
            // Latin gloss: for editing in another app
            return "للتحرير في تطبيق آخر"
        case .pdfRaster:
            // Latin gloss: for quick printing
            return "للطباعة السريعة"
        case .svg:
            // Latin gloss: for editing in another app
            return "للتحرير في تطبيق آخر"
        case .pdfVector:
            // Latin gloss: for professional printing
            return "للطباعة الاحترافية"
        }
    }

    /// JPEG/PDF-raster resolve through the fixed `"social.square"` preset
    /// (mirrors `EditorViewModel.exportForSharing()`/
    /// `exportPDFRasterForSharing()`'s own request construction exactly);
    /// PNG/SVG/vector-PDF resolve to the canvas's own native size (mirrors
    /// those methods' `.custom(pixelSize: canvasSize)` target). Falls back
    /// to `canvasSize` if the preset catalog is ever missing the id (never
    /// true in production ، `MKExportPresetCatalog.standard` traps at
    /// process start on a malformed bundle, see that type's own doc
    /// comment), purely so this stays a total function.
    func resolvedPixelSize(canvasSize: CGSize) -> CGSize {
        switch self {
        case .jpeg, .pdfRaster:
            return MKExportPresetCatalog.standard.preset(id: "social.square")?.pixelSize ?? canvasSize
        case .png, .svg, .pdfVector:
            return canvasSize
        }
    }
}

/// EU-4: the export sheet ، one row per format with a purpose string, a
/// premium lock badge shown BEFORE tapping (not discovered only after
/// hitting the paywall), and the resolved output pixel dimensions.
/// Replaces the old flat `Menu` of five bare buttons
/// (`EditorContentView.toolbarContent`). While an export is in flight
/// (`viewModel.isExporting`), the row list is replaced by a progress view +
/// Cancel button bound to `viewModel.cancelActiveExport()` ،
/// `viewModel.exportProgress` drives a DETERMINATE bar once the
/// tiled-raster/CMYK-PDF path starts reporting real fractions
/// (`MKExportCoordinator.progressUpdates()`); every other path (SVG, vector
/// PDF, or any raster export small enough to take the untiled fast path)
/// shows an indeterminate spinner instead, since it never populates
/// `exportProgress`.
private struct ExportFormatSheet: View {
    @Environment(\.mkTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let viewModel: EditorViewModel
    let entitlementProvider: any MKEntitlementProviding
    let canvasSize: CGSize
    var onPaywall: () -> Void
    var onExported: (URL) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isExporting {
                    exportingView
                } else {
                    formList
                }
            }
            .navigationTitle(Text(titleText))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeLabel) { dismiss() }
                        .disabled(viewModel.isExporting)
                }
            }
        }
        // While an export is in flight, the Cancel button in `exportingView`
        // is the one deliberate way to stop it ، disable the toolbar close
        // button (above) AND swipe-to-dismiss, so a stray swipe can't leave
        // the user unsure whether their export is still running.
        .interactiveDismissDisabled(viewModel.isExporting)
    }

    private var formList: some View {
        List(ExportFormatOption.allCases) { kind in
            Button {
                perform(kind)
            } label: {
                row(for: kind)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func row(for kind: ExportFormatOption) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(spacing: theme.spacing.xs) {
                Text(kind.displayName)
                    .mkTypeStyle(theme.typeRamp.style(for: .body))
                    .foregroundStyle(theme.ink)
                if kind.isPremium {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                        .accessibilityLabel(premiumLockLabel)
                }
            }
            Text(kind.purposeText)
                .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                .foregroundStyle(theme.inkMuted)
            Text(dimensionsText(for: kind))
                .mkTypeStyle(theme.typeRamp.style(for: .caption))
                .foregroundStyle(theme.inkMuted)
        }
        .contentShape(Rectangle())
        .padding(.vertical, theme.spacing.xs)
    }

    private var exportingView: some View {
        VStack(spacing: theme.spacing.lg) {
            Spacer()
            if let progress = viewModel.exportProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, theme.spacing.xxl)
                Text(percentageText(progress))
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
            } else {
                ProgressView()
            }
            Text(exportingText)
                .mkTypeStyle(theme.typeRamp.style(for: .callout))
                .foregroundStyle(theme.ink)
            Button(cancelLabel, role: .cancel) {
                viewModel.cancelActiveExport()
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(theme.spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    private func dimensionsText(for kind: ExportFormatOption) -> String {
        let size = kind.resolvedPixelSize(canvasSize: canvasSize)
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        // Latin gloss: "<width>×<height> px"
        return "\(width)×\(height) بكسل"
    }

    private func percentageText(_ fraction: Double) -> String {
        let percent = Int((fraction * 100).rounded(.toNearestOrAwayFromZero))
        // Latin gloss: "<percent>%" (Arabic percent sign)
        return "\(percent)٪"
    }

    private func perform(_ kind: ExportFormatOption) {
        if kind.isPremium, !entitlementProvider.isEntitled(.premiumExportFormats) {
            dismiss()
            onPaywall()
            return
        }
        Task {
            let url: URL?
            switch kind {
            case .jpeg: url = await viewModel.exportForSharing(entitlement: entitlementProvider)
            case .png: url = await viewModel.exportPNGForSharing(entitlement: entitlementProvider)
            case .pdfRaster: url = await viewModel.exportPDFRasterForSharing(entitlement: entitlementProvider)
            case .svg: url = await viewModel.exportSVGForSharing(entitlement: entitlementProvider)
            case .pdfVector: url = await viewModel.exportPDFVectorForSharing(entitlement: entitlementProvider)
            }
            // EU-4: a `nil` result no longer means silent failure ، the
            // export method already populated `viewModel.exportFailureMessage`
            // in its `catch` block (`EditorViewModel.runExport(_:coordinator:
            // entitlement:)`), and `EditorContentView`'s `.alert` (bound to
            // that property, an ancestor of this sheet) shows it on top of
            // whatever this sheet is doing by then.
            if let url {
                dismiss()
                onExported(url)
            }
        }
    }

    private var titleText: String {
        // Latin gloss: export
        "تصدير"
    }
    private var closeLabel: String {
        // Latin gloss: close
        "إغلاق"
    }
    private var cancelLabel: String {
        // Latin gloss: cancel
        "إلغاء"
    }
    private var exportingText: String {
        // Latin gloss: exporting…
        "جارٍ التصدير…"
    }
    private var premiumLockLabel: LocalizedStringResource {
        // Latin gloss: requires Makhtoot Premium
        "يتطلب اشتراك مخطوط المميز"
    }
}

#if os(iOS)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
