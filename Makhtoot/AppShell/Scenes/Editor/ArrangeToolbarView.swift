import MKCanvas
import MKDesignSystem
import MKModel
import SwiftUI

/// The contextual Arrange Mode toolbar (packet task 15, R-6.7): "replaces
/// the standard object toolbar" while `session.mode == .arrange`. Level
/// toggle (R-6.4), join break/restore (§8.1), form selector trigger (R-8.3),
/// decompose/recompose (§8.2), mark detach/re-attach (§7.5), revert
/// (R-6.12), close (R-6.7). Every action is a thin dispatch to
/// `EditorViewModel`'s arrange-mode methods, which themselves dispatch to
/// `MKArrangeInteractionModel` ، this view owns no arrange LOGIC, only
/// presentation, matching every other panel in this file (`ToolRailView`,
/// `LayersPanelView`).
struct ArrangeToolbarView: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel
    let axis: Axis

    private var interaction: MKArrangeInteractionModel { viewModel.arrangeInteraction }

    var body: some View {
        Group {
            // P1.2/P1.3 (RC-2 centering bug): see `ToolRailView`'s matching
            // doc comment ، same fix here. This bar genuinely has the most
            // items of the three (level toggle + up to 8 icon buttons +
            // dividers), so the `ScrollView` fallback is the one most
            // likely to actually engage in practice; `ViewThatFits` still
            // centers it whenever it fits without scrolling.
            if axis == .horizontal {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: theme.spacing.sm) { content }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacing.sm) { content }
                    }
                    .frame(maxWidth: 320)
                }
            } else {
                ViewThatFits(in: .vertical) {
                    VStack(spacing: theme.spacing.sm) { content }
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: theme.spacing.sm) { content }
                    }
                    .frame(maxHeight: 420)
                }
            }
        }
        .mkFloatingBar()
    }

    @ViewBuilder
    private var content: some View {
        // R-6.4: level toggle ("حروف" letters / "أشكال" glyphs).
        HStack(spacing: theme.spacing.xs) {
            MKChip(title: glyphsLevelLabel, isSelected: interaction.granularity == .glyph) {
                viewModel.setArrangeGranularity(.glyph)
            }
            MKChip(title: lettersLevelLabel, isSelected: interaction.granularity == .letter) {
                viewModel.setArrangeGranularity(.letter)
            }
        }

        Divider().frame(height: axis == .horizontal ? 24 : nil)

        let joinState = viewModel.canBreakOrRestoreJoinForSelection
        MKToolbarButton(systemImage: "link.badge.plus", accessibilityLabel: breakJoinLabel) {
            viewModel.breakJoinWithNextForSelection()
        }
        .disabled(!joinState.breakNext)
        .opacity(joinState.breakNext ? 1 : 0.4)

        MKToolbarButton(systemImage: "link", accessibilityLabel: restoreJoinLabel) {
            viewModel.restoreJoinWithNextForSelection()
        }
        .disabled(!joinState.restoreNext)
        .opacity(joinState.restoreNext ? 1 : 0.4)

        MKToolbarButton(systemImage: "character", accessibilityLabel: formSelectorLabel) {
            viewModel.presentFormSelectorForSelection()
        }
        .disabled(viewModel.session.selection.single == nil)
        .opacity(viewModel.session.selection.single == nil ? 0.4 : 1)

        Divider().frame(height: axis == .horizontal ? 24 : nil)

        MKToolbarButton(systemImage: "square.on.square", accessibilityLabel: decomposeLabel) {
            viewModel.decomposeSelection(fidelity: true)
        }
        .disabled(!viewModel.canDecomposeSelection)
        .opacity(viewModel.canDecomposeSelection ? 1 : 0.4)

        MKToolbarButton(systemImage: "square.on.square.dashed", accessibilityLabel: decomposeDefaultFormsLabel) {
            viewModel.decomposeSelection(fidelity: false)
        }
        .disabled(!viewModel.canDecomposeSelection)
        .opacity(viewModel.canDecomposeSelection ? 1 : 0.4)

        MKToolbarButton(systemImage: "square.stack", accessibilityLabel: recomposeLabel) {
            viewModel.requestRecomposeSelection()
        }

        Divider().frame(height: axis == .horizontal ? 24 : nil)

        MKToolbarButton(systemImage: "pin.slash", accessibilityLabel: detachMarkLabel) {
            viewModel.detachSelectedMark()
        }
        .disabled(!viewModel.canDetachSelectedMark)
        .opacity(viewModel.canDetachSelectedMark ? 1 : 0.4)

        MKToolbarButton(systemImage: "pin", accessibilityLabel: reattachMarkLabel, isProminent: viewModel.pendingMarkReattachID != nil) {
            viewModel.armReattachForSelectedMark()
        }

        // R-9.9: "إظهار المسار" (show path) ghost-guide toggle ، only
        // reachable when the current arranged composition actually derives
        // from a Path Text object (`derivedFrom == .pathText`, checked via
        // `EditorViewModel.arrangedGhostGuidePath`'s own gate, mirrored
        // here for the button's enabled state).
        if case .pathText? = viewModel.arrangeInteraction.activeOwnerNode?.derivedFrom {
            MKToolbarButton(systemImage: "point.topleft.down.curvedto.point.bottomright.up", accessibilityLabel: ghostGuideLabel, isProminent: viewModel.showsPathGhostGuide) {
                viewModel.showsPathGhostGuide.toggle()
                viewModel.refreshCanvasChrome()
            }
        }

        Divider().frame(height: axis == .horizontal ? 24 : nil)

        MKToolbarButton(systemImage: "arrow.uturn.backward.circle", accessibilityLabel: revertLabel) {
            viewModel.requestRevert()
        }

        MKToolbarButton(systemImage: "xmark.circle", accessibilityLabel: closeLabel) {
            Task { await viewModel.toggleArrangeMode() }
        }
    }

    private var glyphsLevelLabel: String {
        // Latin gloss: shapes (glyph level)
        "أشكال"
    }
    private var lettersLevelLabel: String {
        // Latin gloss: letters (letter level)
        "حروف"
    }
    private var breakJoinLabel: String {
        // Latin gloss: break the join
        "فك الارتباط"
    }
    private var restoreJoinLabel: String {
        // Latin gloss: restore the join
        "إعادة الارتباط"
    }
    private var formSelectorLabel: String {
        // Latin gloss: choose the letter form
        "اختيار الشكل"
    }
    private var decomposeLabel: String {
        // Latin gloss: decompose the ligature
        "فك الوصلة"
    }
    private var decomposeDefaultFormsLabel: String {
        // Latin gloss: use default forms
        "استخدام الأشكال الافتراضية"
    }
    private var recomposeLabel: String {
        // Latin gloss: recompose the ligature
        "إعادة الوصلة"
    }
    private var detachMarkLabel: String {
        // Latin gloss: detach the mark
        "فصل الحركة"
    }
    private var reattachMarkLabel: String {
        // Latin gloss: attach to a letter
        "إرفاق بالحرف"
    }
    private var revertLabel: String {
        // Latin gloss: revert to text
        "العودة إلى النص"
    }
    private var ghostGuideLabel: String {
        // Latin gloss: show the path (ghost guide, R-9.9)
        "إظهار المسار"
    }
    private var closeLabel: String {
        // Latin gloss: close (arrange mode)
        "إغلاق"
    }
}
