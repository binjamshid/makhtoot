import MKCanvas
import MKDesignSystem
import MKModel
import SwiftUI

/// The contextual Path-Edit Mode toolbar (packet task 16, R-9.1/R-9.3):
/// replaces the standard object toolbar while `session.mode == .pathEdit`,
/// the exact "contextual toolbar swap" convention `ArrangeToolbarView`
/// already establishes for Arrange Mode (`EditorScene.primaryRail` picks
/// between the three per `viewModel.session.mode`). Done/exit ("تم"),
/// path options popover trigger (R-9.4), reverse-direction, open/closed
/// toggle, delete-selected-anchor, and the curvature-warning indicator
/// (R-9.3's "curvature warning banner when WS-05 reports it"). Every
/// action is a thin dispatch to `EditorViewModel`/`MKPathTextInteractionModel`
/// ، this view owns no path-editing LOGIC, only presentation, matching
/// `ArrangeToolbarView`'s own role split.
struct PathEditToolbarView: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel
    let axis: Axis

    private var interaction: MKPathTextInteractionModel { viewModel.pathTextInteraction }

    var body: some View {
        VStack(alignment: .trailing, spacing: theme.spacing.xs) {
            if interaction.curvatureWarningActive {
                Text(curvatureWarningText)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.destructive)
                    .padding(.horizontal, theme.spacing.sm)
            }
            Group {
                // P1.2/P1.3 (RC-2 centering bug): see `ToolRailView`'s
                // matching doc comment ، same fix here, one nesting level
                // deeper inside this view's own outer `VStack` (which also
                // holds the optional curvature-warning `Text` above).
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
    }

    @ViewBuilder
    private var content: some View {
        MKToolbarButton(systemImage: "slider.horizontal.3", accessibilityLabel: pathOptionsLabel) {
            viewModel.presentedPathOptions = true
        }

        MKToolbarButton(systemImage: "arrow.left.arrow.right", accessibilityLabel: reverseDirectionLabel) {
            try? interaction.reverseDirection()
        }

        MKToolbarButton(systemImage: "circle.dashed", accessibilityLabel: toggleClosedLabel) {
            try? interaction.toggleClosed()
        }

        MKToolbarButton(systemImage: "trash", accessibilityLabel: deleteAnchorLabel) {
            guard let handle = interaction.selectedHandle else { return }
            try? interaction.deleteAnchor(handle.anchorID)
        }
        .disabled(interaction.selectedHandle == nil)
        .opacity(interaction.selectedHandle == nil ? 0.4 : 1)

        Divider().frame(height: axis == .horizontal ? 24 : nil)

        MKToolbarButton(systemImage: "checkmark.circle", accessibilityLabel: doneLabel) {
            viewModel.togglePathEditMode()
        }
    }

    private var pathOptionsLabel: String {
        // Latin gloss: path options
        "خيارات المسار"
    }
    private var reverseDirectionLabel: String {
        // Latin gloss: reverse direction
        "قلب الاتجاه"
    }
    private var toggleClosedLabel: String {
        // Latin gloss: toggle open/closed path
        "فتح/إغلاق المسار"
    }
    private var deleteAnchorLabel: String {
        // Latin gloss: delete the selected anchor point
        "حذف نقطة التثبيت المحددة"
    }
    private var doneLabel: String {
        // Latin gloss: done (exit path-edit mode)
        "تم"
    }
    private var curvatureWarningText: String {
        // Latin gloss: warning: a sharp turn on the path may distort the letters
        "تنبيه: انحناء حاد في المسار قد يشوّه الحروف"
    }
}
