import MKCanvas
import MKDesignSystem
import MKFonts
import MKModel
import SwiftUI

/// UX-6: the three tour-highlight frames below used to be captured once,
/// inside `.onAppear`, which never re-fires on rotation/split-view-resize/
/// size-class-change/tool-rail-relayout ، any of those left the tour
/// cutout pointing at empty space. A `PreferenceKey` re-reports on every
/// layout pass instead, so `EditorTourModel`'s frames stay current for the
/// lifetime of the tour. Keyed by button identity (`"font"`/`"add"`/
/// `"arrange"`) rather than three separate preference keys so a single
/// `.onPreferenceChange` at the ancestor owning `tourModel`
/// (`EditorScene.swift`'s `EditorContentView`) can update all three from
/// one callback.
struct MKTourFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct ToolRailView: View {
    @Environment(\.mkTheme) private var theme
    @Environment(AppContainer.self) private var container
    let viewModel: EditorViewModel
    let fontRegistry: MKFontRegistry
    let axis: Axis
    var isRegularWidth: Bool = false

    @State private var showFontSettings = false
    /// P2.1: Pattern B presentation (trigger and presenter are this SAME
    /// view), exactly like `showFontSettings` immediately above ، never
    /// routed through `EditorViewModel.presentedPanel`/`EditorPanel`
    /// (Pattern A, for when trigger and presenter differ).
    @State private var showTextInsertSheet = false
    /// P3.2: same Pattern B presentation ، the "شكل" (now "عناصر") menu
    /// item opens the full five-category asset library instead of directly
    /// calling `viewModel.addRectangleAtCenter()` (that method itself is
    /// KEPT, unchanged, for the DEBUG/E2E drive hooks that still call it
    /// directly ، see that method's own doc comment).
    @State private var showAssetBrowser = false
    /// P5.2: the new `MKColorPickerSheet` (P5.1), aimed at the canvas
    /// background instead of a node's fill ، same Pattern B presentation
    /// as `showFontSettings`/`showTextInsertSheet` above.
    @State private var showBackgroundColorPicker = false
    /// P5.3: same Pattern B presentation as `showBackgroundColorPicker`
    /// immediately above ، `BackgroundImageSheet` owns its own
    /// Photos/Files/Fit/Edit/Remove UI.
    @State private var showBackgroundImageSheet = false
    /// P7.4 (§2.2 "Merge Design"): same Pattern B presentation as
    /// `showBackgroundColorPicker`/`showBackgroundImageSheet` above.
    @State private var showMergeDesignSheet = false
    let tourModel: EditorTourModel

    /// UX-2: the rail's three same-sized icon glyphs (font-settings "أء",
    /// "+", "···") share one scaled metric ، base 17 pt, relative to
    /// `.body`, matching `MKToolbarButton`'s own icon scale immediately
    /// below (the wand/arrange button already goes through that
    /// component).
    @ScaledMetric(relativeTo: .body) private var railIconSize: CGFloat = 17

    var body: some View {
        Group {
            // P1.2/P1.3 (RC-2 centering bug): a bare `ScrollView` always
            // takes the full proposed width/height and left/top-aligns its
            // content inside itself ، with only ~152 pt of buttons inside a
            // 260 pt-wide scroll view, that left the pill's content flush
            // against the scroll view's LEADING origin, which under this
            // app's ambient RTL (`MakhtootApp.swift`'s Arabic-only bundle
            // locale) is the bar's RIGHT edge, not centered. `ViewThatFits`
            // tries the plain, intrinsically-sized stack first (which
            // centers naturally, since nothing forces it to a fixed
            // width/height) and only falls back to the capped `ScrollView`
            // when the content genuinely overflows the available space.
            if axis == .horizontal {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.spacing.sm) { content }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacing.sm) { content }
                    }
                    .frame(maxWidth: 260)
                }
            } else {
                ViewThatFits(in: .vertical) {
                    VStack(spacing: theme.spacing.sm) { content }
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: theme.spacing.sm) { content }
                    }
                    .frame(maxHeight: 360)
                }
            }
        }
        .mkFloatingBar()
        // UX-2: the rail's icon buttons keep small, fixed-ish hit targets
        // (32×32 icon frames) ، unlike the empty-state/onboarding artwork
        // elsewhere in this sweep, this is a "layout-fragile surface" the
        // audit calls out by name. Icons still scale (below), but the
        // surface as a whole is clamped at `.accessibility3` so it degrades
        // to "bigger, still usable" rather than breaking outright at the
        // top accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .sheet(isPresented: $showFontSettings) {
            FontSettingsSheet(inspector: viewModel.inspector, fontRegistry: fontRegistry, sampleText: viewModel.selectedTextForFontSettings)
        }
        .sheet(isPresented: $showTextInsertSheet) {
            TextInsertSheet(viewModel: viewModel, fontRegistry: fontRegistry)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAssetBrowser) {
            MKAssetBrowserSheet(
                viewModel: viewModel,
                model: container.assetBrowserModel,
                thumbnailRenderer: container.assetThumbnailRenderer
            )
        }
        .sheet(isPresented: $showBackgroundColorPicker) {
            let bg = viewModel.inspector.backgroundColorValue
            MKColorPickerSheet(
                title: backgroundColorLabel,
                initialColor: (bg.r, bg.g, bg.b, bg.a)
            ) { color in
                viewModel.inspector.setBackgroundColor(MKSolidColor(r: color.red, g: color.green, b: color.blue, a: color.alpha))
                viewModel.refreshCanvasChrome()
            }
        }
        .sheet(isPresented: $showBackgroundImageSheet) {
            BackgroundImageSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showMergeDesignSheet) {
            MergeDesignSheet(excludingProjectID: viewModel.projectID) { pickedProjectID in
                Task { await viewModel.mergeDesign(fromProjectID: pickedProjectID) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        // أء ، font settings
        Button {
            showFontSettings = true
        } label: {
            Text("أء")
                .font(.system(size: railIconSize, weight: .medium))
                .frame(minWidth: 32, minHeight: 32)
                .foregroundStyle(theme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fontSettingsLabel)
        .background(GeometryReader { geo in
            Color.clear.preference(key: MKTourFramePreferenceKey.self, value: ["font": geo.frame(in: .global)])
        })

        // + ، add objects (text, shapes) and path text presets
        Menu {
            Section {
                // P2.1: opens the insert-time text dialog instead of
                // inserting a blank field and jumping straight into inline
                // canvas editing ، see `TextInsertSheet`'s own header
                // comment for the full rationale.
                Button(addTextFieldLabel) { showTextInsertSheet = true }
                // P3.2: was `viewModel.addRectangleAtCenter()` (a single
                // hardcoded rectangle) ، now opens the full five-category
                // asset library (`MKAssetBrowserSheet`: shapes/ornaments/
                // frames/calligraphic elements/pattern backgrounds).
                Button(addShapeLabel) { showAssetBrowser = true }
                // P3.3/Bug 14: the old "تشكيل" (tashkeel) menu item called
                // the exact SAME method as "حقل نص" immediately above ،
                // a copy-paste stub, not a real feature (it never actually
                // added tashkeel). The real fix ships as an accessory
                // palette INSIDE the text-editing overlay itself
                // (`TextEditingOverlay.swift`'s `TashkeelAccessoryRow`),
                // automatically available the moment ANY live/path text
                // starts editing ، there is nothing left for a separate
                // canvas-level menu entry to distinctly do (a button
                // that just re-opened "حقل نص" under a different label
                // would be the exact "silently does the wrong thing" stub
                // this fixes), so the item is REMOVED rather than kept as
                // a second, misleading way to add text.
            }
            Section(addPathTextLabel) {
                Button(pathPresetArcLabel) { viewModel.addPathText(preset: .arc) }
                Button(pathPresetCircleLabel) { viewModel.addPathText(preset: .circle) }
                Button(pathPresetWaveLabel) { viewModel.addPathText(preset: .wave) }
                Button(pathPresetFreeformLabel) { viewModel.addPathText(preset: .freeform) }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: railIconSize, weight: .medium))
                .frame(minWidth: 32, minHeight: 32)
                .foregroundStyle(theme.ink)
        }
        .accessibilityLabel(addObjectLabel)
        .background(GeometryReader { geo in
            Color.clear.preference(key: MKTourFramePreferenceKey.self, value: ["add": geo.frame(in: .global)])
        })

        // wand ، arrange mode toggle (kept as button to show active state)
        //
        // Bug fix (2026-07-29, "the wand button is very buggy and unclear
        // in its function"): the icon alone never said what Arrange Mode
        // IS, and `.disabled` made a tap with nothing selected completely
        // inert. It is now always tappable ، `toggleArrangeMode()` answers
        // an inapplicable tap with a real message through
        // `ArrangeErrorBannerView` instead of returning silently ، and the
        // symbol changes on entry so "I am now in Arrange Mode" is visible
        // beyond a tint change.
        MKToolbarButton(
            systemImage: viewModel.arrangeInteraction.isActive ? "wand.and.stars.inverse" : "wand.and.stars",
            accessibilityLabel: viewModel.arrangeInteraction.isActive ? exitArrangeModeLabel : arrangeModeLabel,
            isProminent: viewModel.arrangeInteraction.isActive
        ) {
            Task { await viewModel.toggleArrangeMode() }
        }
        .accessibilityHint(arrangeModeHint)
        .opacity(viewModel.canToggleArrangeMode ? 1 : 0.55)
        .background(GeometryReader { geo in
            Color.clear.preference(key: MKTourFramePreferenceKey.self, value: ["arrange": geo.frame(in: .global)])
        })
        // Bug 16 follow-up: a derive on a long string isn't instantaneous
        // ، without this, a tap that hasn't resolved yet reads identically
        // to a tap that silently did nothing. The button itself stays
        // tappable (a second tap supersedes the in-flight derive per
        // `MKArrangeInteractionModel.enterArrangeMode`'s own cancellation
        // handling, not blocked here).
        .overlay {
            if viewModel.arrangeInteraction.isDeriving {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(viewModel.arrangeInteraction.isActive ? theme.onPrimary : theme.primary)
                    .accessibilityLabel(arrangeDerivingLabel)
            }
        }

        // ··· ، path edit, selection actions, panels
        Menu {
            Button {
                viewModel.togglePathEditMode()
            } label: {
                Label(editPathLabel, systemImage: "pencil.and.outline")
            }
            .disabled(!viewModel.canTogglePathEditMode)

            Section {
                Button { viewModel.bringSelectionToFront() } label: {
                    Label(bringFrontLabel, systemImage: "square.3.layers.3d.top.filled")
                }
                .disabled(!viewModel.hasSingleSelection)
                Button { viewModel.sendSelectionToBack() } label: {
                    Label(sendBackLabel, systemImage: "square.3.layers.3d.bottom.filled")
                }
                .disabled(!viewModel.hasSingleSelection)
            }

            Section {
                Button { viewModel.duplicateSelection() } label: {
                    Label(duplicateLabel, systemImage: "rectangle.on.rectangle")
                }
                .disabled(!viewModel.hasSingleSelection)
                Button { viewModel.groupSelection() } label: {
                    Label(groupLabel, systemImage: "square.grid.2x2")
                }
                .disabled(!viewModel.hasMultipleSelected)
                Button { viewModel.ungroupSelection() } label: {
                    Label(ungroupLabel, systemImage: "square.dashed")
                }
                .disabled(!viewModel.hasSingleSelection)
            }

            // P6 (§2.3 "Editing operations"): copy/paste, select all/
            // deselect all, flip horizontal/vertical ، the same "edit" menu
            // group §2.3 calls for, alongside the rest of this Menu's
            // selection-scoped actions.
            Section {
                Button { viewModel.copySelection() } label: {
                    Label(copyLabel, systemImage: "doc.on.doc")
                }
                .disabled(!viewModel.canCopySelection)
                Button { viewModel.pasteFromClipboard() } label: {
                    Label(pasteLabel, systemImage: "doc.on.clipboard")
                }
                Button { viewModel.flipSelectionHorizontally() } label: {
                    Label(flipHorizontalLabel, systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                .disabled(!viewModel.hasSelection)
                Button { viewModel.flipSelectionVertically() } label: {
                    Label(flipVerticalLabel, systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                }
                .disabled(!viewModel.hasSelection)
                // Whole-composition mirror ، NOT selection-gated, and a
                // genuinely different operation from the two above (which
                // flip each selected object where it stands). See
                // `CanvasSession.flipScene(axis:)`. Nested in its own
                // submenu so the four flip commands don't read as one
                // undifferentiated list.
                Menu {
                    Button { viewModel.flipProjectHorizontally() } label: {
                        Label(flipHorizontalLabel, systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                    }
                    Button { viewModel.flipProjectVertically() } label: {
                        Label(flipVerticalLabel, systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down")
                    }
                } label: {
                    Label(flipProjectLabel, systemImage: "square.on.square.dashed")
                }
                .disabled(!viewModel.canFlipProject)
                // P7.4 (§2.2 "Merge Design"): not selection-gated ، picking
                // a source project is the whole point of the flow, so it
                // must be reachable with nothing (or anything) selected.
                Button { showMergeDesignSheet = true } label: {
                    Label(mergeDesignLabel, systemImage: "arrow.triangle.merge")
                }
            }

            Section {
                Button { viewModel.selectAll() } label: {
                    Label(selectAllLabel, systemImage: "checkmark.circle")
                }
                Button { viewModel.deselectAll() } label: {
                    Label(deselectAllLabel, systemImage: "circle.slash")
                }
                .disabled(!viewModel.hasSelection)
            }

            // P5.2: the missing entry point ، `BackgroundDrawer` already
            // renders `.solid(color)` (fills `canvasBounds`), only the UI
            // to CHOOSE that color was missing. Not selection-gated (the
            // background isn't a selectable node, `LayersPanelView`
            // deliberately excludes it from row actions).
            Section {
                Button { showBackgroundColorPicker = true } label: {
                    Label(backgroundColorLabel, systemImage: "paintpalette")
                }
                // P5.3 (Bug 2): the missing background-IMAGE entry point,
                // alongside the background-color one immediately above.
                Button { showBackgroundImageSheet = true } label: {
                    Label(backgroundImageLabel, systemImage: "photo")
                }
            }

            Section {
                Button { viewModel.toggleLockForSelection() } label: {
                    Label(lockLabel, systemImage: "lock")
                }
                .disabled(!viewModel.hasSelection)
                Button { viewModel.toggleHideForSelection() } label: {
                    Label(hideLabel, systemImage: "eye.slash")
                }
                .disabled(!viewModel.hasSelection)
            }

            if !isRegularWidth {
                Section {
                    Button { viewModel.presentedPanel = .layers } label: {
                        Label(layersLabel, systemImage: "square.3.layers.3d")
                    }
                    Button { viewModel.presentedPanel = .inspector } label: {
                        Label(inspectorLabel, systemImage: "slider.horizontal.3")
                    }
                }
            }

            Section {
                Button { tourModel.restart() } label: {
                    Label(restartTourLabel, systemImage: "questionmark.circle")
                }
            }

            Section {
                Button(role: .destructive) { viewModel.deleteSelection() } label: {
                    Label(deleteLabel, systemImage: "trash")
                }
                .disabled(!viewModel.hasSelection)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: railIconSize, weight: .medium))
                .frame(minWidth: 32, minHeight: 32)
                .foregroundStyle(theme.ink)
        }
        .accessibilityLabel(moreActionsLabel)
    }

    // UX-7: catalog-extractable accessibility labels ، feeds either a
    // direct `.accessibilityLabel(_:)` modifier or `MKToolbarButton`'s
    // `LocalizedStringResource` initializer.
    private var fontSettingsLabel: LocalizedStringResource { "الخط والحجم" }
    private var addObjectLabel: LocalizedStringResource { "إضافة عنصر" }
    private var addTextFieldLabel: String { "حقل نص" }
    /// P3.2: opens the full asset library (`MKAssetBrowserSheet`) ، renamed
    /// from "شكل" (a single hardcoded rectangle) since the same entry now
    /// covers all five BRIEF categories, not shapes alone.
    private var addShapeLabel: String { "عناصر" }
    private var addPathTextLabel: String { "نص على مسار" }
    private var pathPresetArcLabel: String { "قوس" }
    private var pathPresetCircleLabel: String { "دائرة" }
    private var pathPresetWaveLabel: String { "موجة" }
    private var pathPresetFreeformLabel: String { "حر" }
    private var editPathLabel: String { "تحرير المسار" }
    private var arrangeModeLabel: LocalizedStringResource { "الترتيب الحر" }
    // Latin gloss: exit the free arrangement
    private var exitArrangeModeLabel: LocalizedStringResource { "إنهاء الترتيب الحر" }
    // Latin gloss: breaks the selected text into letters and marks you can
    // move one by one
    private var arrangeModeHint: LocalizedStringResource { "يفكّك النص المحدد إلى حروف وحركات يمكن تحريكها واحدة واحدة" }
    // Latin gloss: converting to a free arrangement…
    private var arrangeDerivingLabel: LocalizedStringResource { "جارٍ التحويل إلى تنسيق حر…" }
    private var layersLabel: String { "الطبقات" }
    private var inspectorLabel: String { "الخصائص" }
    private var lockLabel: String { "قفل/فتح" }
    private var hideLabel: String { "إظهار/إخفاء" }
    private var bringFrontLabel: String { "إحضار للأمام" }
    private var sendBackLabel: String { "إرسال للخلف" }
    private var duplicateLabel: String { "تكرار" }
    private var groupLabel: String { "تجميع" }
    private var ungroupLabel: String { "فك التجميع" }
    // Latin gloss: copy
    private var copyLabel: String { "نسخ" }
    // Latin gloss: paste
    private var pasteLabel: String { "لصق" }
    // Latin gloss: flip horizontal
    private var flipHorizontalLabel: String { "عكس أفقي" }
    // Latin gloss: flip vertical
    private var flipVerticalLabel: String { "عكس رأسي" }
    // Latin gloss: mirror the whole design
    private var flipProjectLabel: String { "عكس التصميم كاملًا" }
    // Latin gloss: merge design…
    private var mergeDesignLabel: String { "دمج تصميم…" }
    // Latin gloss: select all
    private var selectAllLabel: String { "تحديد الكل" }
    // Latin gloss: deselect all
    private var deselectAllLabel: String { "إلغاء تحديد الكل" }
    private var deleteLabel: String { "حذف" }
    private var restartTourLabel: String { "إعادة الجولة التعريفية" }
    private var moreActionsLabel: LocalizedStringResource { "المزيد" }
    // Latin gloss: background color
    private var backgroundColorLabel: String { "لون الخلفية" }
    // Latin gloss: background image
    private var backgroundImageLabel: String { "صورة الخلفية" }
}
