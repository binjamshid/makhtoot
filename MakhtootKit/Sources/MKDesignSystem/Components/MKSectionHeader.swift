import SwiftUI

/// A section header row: Arabic title, optional trailing action (e.g.
/// "المزيد" ، Latin gloss: "more"). RTL order ، the title leads (right
/// edge), the action trails (left edge) ، falls out of `HStack` under the
/// forced RTL layout direction, no manual reordering required.
public struct MKSectionHeader: View {
    @Environment(\.mkTheme) private var theme
    private let title: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack {
            Text(title)
                .mkTypeStyle(theme.typeRamp.style(for: .headline))
                .foregroundStyle(theme.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .mkTypeStyle(theme.typeRamp.style(for: .footnote))
                    .foregroundStyle(theme.primary)
            }
        }
    }
}
