import SwiftUI

/// The three approved brand-mark lockups (design-system handoff, "LOGO"
/// section). The wordmark itself never changes ، only whether an
/// accompanying mark glyph (م / meem) is shown, and in what shape.
/// Persisted as a user preference (`mk.brand.markStyle`), default
/// `.wordmarkOnly`.
public enum MKBrandMarkStyle: String, CaseIterable, Sendable, Identifiable {
    case wordmarkOnly
    case circle
    case diamond

    public var id: String { rawValue }

    /// Arabic label for the Settings brand-mark picker.
    public var displayName: String {
        switch self {
        case .wordmarkOnly: return "الشعار النصي فقط"
        case .circle: return "دائرة"
        case .diamond: return "معين"
        }
    }
}

/// The `مخطوط` wordmark, optionally paired with a circle/diamond meem
/// mark, per the approved logo spec. Every call site that previously
/// rendered `Text("مخطوط", ...)` directly should use this instead, so a
/// brand-mark preference change (or theme change ، the wordmark always
/// renders in the active theme's `display` font and `ink` color) updates
/// every appearance of the brand at once.
public struct MKBrandMark: View {
    @Environment(\.mkTheme) private var theme
    private let style: MKBrandMarkStyle
    private let wordmarkRole: MKTypeRole

    public init(style: MKBrandMarkStyle, wordmarkRole: MKTypeRole = .largeTitle) {
        self.style = style
        self.wordmarkRole = wordmarkRole
    }

    public var body: some View {
        HStack(spacing: theme.spacing.sm) {
            switch style {
            case .wordmarkOnly:
                wordmark
            case .circle:
                markGlyph
                    .frame(width: 60, height: 60)
                    .background(theme.primary, in: Circle())
                    .overlay(Circle().strokeBorder(theme.secondary, lineWidth: 2).padding(2))
                wordmark
            case .diamond:
                ZStack {
                    // A 34pt square rotated 45° yields a ~48pt-wide visible
                    // diamond (34 × √2 ≈ 48), matching the spec's "Square
                    // ≈ 48pt" diamond-mark scale without clipping.
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.primary)
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(45))
                    markGlyph
                }
                .frame(width: 48, height: 48)
                wordmark
            }
        }
    }

    private var wordmark: some View {
        Text("مخطوط")
            .mkTypeStyle(theme.typeRamp.style(for: wordmarkRole))
            .foregroundStyle(theme.ink)
    }

    private var markGlyph: some View {
        Text("م")
            .font(.custom(theme.fonts.display, size: 28))
            .fontWeight(.bold)
            .foregroundStyle(theme.onPrimary)
    }
}
