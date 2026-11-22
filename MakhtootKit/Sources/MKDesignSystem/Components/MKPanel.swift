import SwiftUI

/// A grouped, elevated container ، the base chrome for inspector sections,
/// layer groups, and settings groups. Reads the active theme from the
/// environment (`\.mkTheme`) so it never needs a theme parameter.
public struct MKPanel<Content: View>: View {
    @Environment(\.mkTheme) private var theme
    private let title: String?
    private let content: Content

    /// - Parameter title: Optional Arabic section title shown above the
    ///   panel body, RTL-aligned (leading edge in RTL = the right).
    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            if let title {
                Text(title)
                    .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                    .foregroundStyle(theme.inkMuted)
            }
            VStack(alignment: .leading, spacing: theme.spacing.sm) {
                content
            }
            .padding(theme.spacing.md)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radius.card, style: theme.radius.style))
            .shadow(
                color: .black.opacity(theme.elevation.panel.opacity),
                radius: theme.elevation.panel.radius,
                y: theme.elevation.panel.yOffset
            )
        }
    }
}
