import MKCanvas
import MKDesignSystem
import MKModel
import SwiftUI

/// R-9.4's path options popover: start-offset slider (arc position), side
/// picker (above/below/center = baseline flip), spacing mode (natural/
/// justify tracking-on-path), reverse direction. Presentation style
/// mirrors `FormSelectorPopoverView`'s own "overlay at the bottom of
/// `canvasArea`, driven by a view-model `Bool`" convention
/// (`EditorViewModel.presentedPathOptions`) ، this view owns no path-layout
/// LOGIC, only presentation, dispatching every control straight to
/// `MKPathTextInteractionModel`.
struct PathOptionsPopoverView: View {
    @Environment(\.mkTheme) private var theme
    let viewModel: EditorViewModel

    /// Fresh per continuous slider scrub (D-112 coalescing ، see
    /// `MKPathTextInteractionModel.beginOptionsGesture`'s doc comment for
    /// why BOTH a stable `gestureID` AND the begin/end transaction wrapper
    /// are required).
    @State private var startOffsetGestureID = UUID()

    private var interaction: MKPathTextInteractionModel { viewModel.pathTextInteraction }
    private var layout: MKPathLayoutOptions { interaction.activeNode?.layout ?? MKPathLayoutOptions() }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            Text(title)
                .mkTypeStyle(theme.typeRamp.style(for: .headline))
                .foregroundStyle(theme.ink)

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(startOffsetLabel)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
                Slider(
                    value: Binding(
                        get: { layout.startOffset },
                        set: { try? interaction.setStartOffset($0, gestureID: startOffsetGestureID) }
                    ),
                    in: 0...1,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            startOffsetGestureID = UUID()
                            interaction.beginOptionsGesture()
                        } else {
                            interaction.endOptionsGesture()
                        }
                    }
                )
            }

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(sideLabel)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
                Picker(sideLabel, selection: Binding(
                    get: { layout.side },
                    set: { try? interaction.setSide($0) }
                )) {
                    Text(aboveLabel).tag(MKPathSide.above)
                    Text(belowLabel).tag(MKPathSide.below)
                    Text(centerLabel).tag(MKPathSide.center)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(spacingLabel)
                    .mkTypeStyle(theme.typeRamp.style(for: .caption))
                    .foregroundStyle(theme.inkMuted)
                Picker(spacingLabel, selection: Binding(
                    get: { layout.spacingMode },
                    set: { try? interaction.setSpacingMode($0) }
                )) {
                    Text(naturalLabel).tag(MKPathSpacingMode.natural)
                    Text(justifyLabel).tag(MKPathSpacingMode.justify)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Button(reverseDirectionLabel) {
                    try? interaction.reverseDirection()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(dismissLabel) {
                    viewModel.presentedPathOptions = false
                }
                .buttonStyle(.bordered)
            }
        }
        .mkFloatingBar(padding: theme.spacing.md)
        .frame(maxWidth: 340)
    }

    private var title: String {
        // Latin gloss: path options
        "خيارات المسار"
    }
    private var startOffsetLabel: String {
        // Latin gloss: start position on the path
        "موضع البداية على المسار"
    }
    private var sideLabel: String {
        // Latin gloss: side (relative to the path)
        "الجانب"
    }
    private var aboveLabel: String {
        // Latin gloss: above
        "فوق"
    }
    private var belowLabel: String {
        // Latin gloss: below
        "تحت"
    }
    private var centerLabel: String {
        // Latin gloss: center (on the path)
        "وسط"
    }
    private var spacingLabel: String {
        // Latin gloss: spacing along the path
        "التباعد على المسار"
    }
    private var naturalLabel: String {
        // Latin gloss: natural
        "طبيعي"
    }
    private var justifyLabel: String {
        // Latin gloss: justified
        "موزّع"
    }
    private var reverseDirectionLabel: String {
        // Latin gloss: reverse direction
        "قلب الاتجاه"
    }
    private var dismissLabel: String {
        // Latin gloss: close
        "إغلاق"
    }
}
