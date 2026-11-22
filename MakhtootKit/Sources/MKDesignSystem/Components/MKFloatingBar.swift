import SwiftUI

/// The floating-chrome surface shared by every contextual bar/popover that
/// hovers over the live canvas (P1.2/P1.3 bugfix): `ToolRailView`,
/// `ArrangeToolbarView`, `PathEditToolbarView`, `PathOptionsPopoverView`,
/// `FormSelectorPopoverView`, and `ZoomControlsView` (`Makhtoot/AppShell
/// /Scenes/Editor`). Before this, the exact same
/// `.padding` + `.background(theme.surface, in: RoundedRectangle(...))` +
/// `.shadow(...)` triple was hand-rolled independently in five of those six
/// views (with a small drift: two used `theme.spacing.md`, the rest
/// `.sm`), and entirely ABSENT from the sixth (`ZoomControlsView`, Bug 7:
/// bare `theme.ink` glyphs drawn straight onto the canvas backdrop ،
/// illegible over busy artwork, and in compact layout sitting directly
/// above the tool-rail pill with no visual separation at all). One
/// definition now, adopted everywhere.
///
/// Always resolves corner radius from `theme.radius.sheet`/`.style` ،
/// never a hardcoded `Capsule()` or radius literal ، the Kufi theme sets
/// `radius == 0` everywhere, and a hardcoded round shape would silently
/// break that theme's flat-corner identity.
public struct MKFloatingBarModifier: ViewModifier {
    @Environment(\.mkTheme) private var theme
    private let padding: CGFloat?
    private let usesMaterial: Bool

    /// - Parameters:
    ///   - padding: Overrides the default `theme.spacing.sm` padding (the
    ///     two popovers, `PathOptionsPopoverView`/`FormSelectorPopoverView`,
    ///     want `theme.spacing.md` to match their existing denser layout).
    ///   - usesMaterial: Draws `.ultraThinMaterial` instead of the flat
    ///     `theme.surface` fill. `.ultraThinMaterial` is the right call
    ///     once background images ship (P5.3) but is expensive to
    ///     composite over a LIVE, frequently-redrawn canvas ، reserve this
    ///     for small, low-content bars only (`ZoomControlsView` is the one
    ///     adopter today). Larger bars (the tool rail, Arrange/Path-Edit
    ///     toolbars, the two popovers) keep the opaque `theme.surface`
    ///     fill.
    public init(padding: CGFloat? = nil, usesMaterial: Bool = false) {
        self.padding = padding
        self.usesMaterial = usesMaterial
    }

    public func body(content: Content) -> some View {
        Group {
            if usesMaterial {
                content
                    .padding(padding ?? theme.spacing.sm)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: theme.radius.sheet, style: theme.radius.style))
            } else {
                content
                    .padding(padding ?? theme.spacing.sm)
                    .background(theme.surface, in: RoundedRectangle(cornerRadius: theme.radius.sheet, style: theme.radius.style))
            }
        }
        .shadow(
            color: .black.opacity(theme.elevation.floatingBar.opacity),
            radius: theme.elevation.floatingBar.radius,
            y: theme.elevation.floatingBar.yOffset
        )
    }
}

public extension View {
    /// Applies the shared floating-bar chrome (padding + surface/material
    /// fill + elevation shadow). See `MKFloatingBarModifier` for the full
    /// rationale.
    func mkFloatingBar(padding: CGFloat? = nil, usesMaterial: Bool = false) -> some View {
        modifier(MKFloatingBarModifier(padding: padding, usesMaterial: usesMaterial))
    }
}
