import SwiftUI

/// A category/tag chip (font categories, asset categories) with a
/// selected state, used by pickers throughout the editor (FontPickerPanel,
/// AssetLibraryPanel ، both later workstreams; the token component ships
/// now).
public struct MKChip: View {
    @Environment(\.mkTheme) private var theme
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void

    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.pill, style: theme.radius.style)
        Button(action: action) {
            Text(title)
                .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.xs)
                .foregroundStyle(isSelected ? theme.onPrimary : theme.inkMuted)
                .background(
                    isSelected ? theme.primary : theme.surfaceMuted,
                    in: shape
                )
                .overlay(
                    shape.strokeBorder(theme.border, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .animation(theme.motion.fast, value: isSelected)
        // U8-2: selection state was visual-only (fill/ink swap) ، expose
        // it to VoiceOver via the standard selected trait so pickers read
        // "محدد" for the active chip.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
