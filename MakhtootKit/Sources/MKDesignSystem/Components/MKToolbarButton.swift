import SwiftUI

/// An icon toolbar/tab button used by the editor toolbar, secondary bar,
/// and settings support rows (later workstreams). Always pass a
/// direction-aware SF Symbol name for directional icons (e.g.
/// `"chevron.forward"`, never `"chevron.right"`) ، those symbols mirror
/// automatically under `\.layoutDirection == .rightToLeft`, which is how
/// "forward" correctly renders as a *leftward*-pointing chevron in the
/// Arabic-only UI (WS-01 packet §5 task 15 accept criterion).
public struct MKToolbarButton: View {
    @Environment(\.mkTheme) private var theme
    private let systemImage: String
    private let accessibilityLabel: LocalizedStringResource
    private let isProminent: Bool
    private let action: () -> Void

    /// UX-7: accessibility labels should be catalog-extractable
    /// (`LocalizedStringResource`), not a plain `String` ، this is the
    /// primary initializer every call site owned by the UX-2/UX-6/UX-7/
    /// UX-8 design-system sweep (`ToolRailView`, `ZoomControlsView`) now
    /// goes through.
    public init(
        systemImage: String,
        accessibilityLabel: LocalizedStringResource,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.isProminent = isProminent
        self.action = action
    }

    /// Back-compat overload, deliberately kept: `MKToolbarButton` is public
    /// and also called from `ArrangeToolbarView.swift`/
    /// `PathEditToolbarView.swift`/`DesignSystemGallery.swift`, none of
    /// which this agent's Owns list covers (Wave 3 · Agent 3.2). Those
    /// call sites still pass `private var xLabel: String` properties ،
    /// changing this initializer's parameter type outright (as the audit's
    /// literal fix text suggests) would fail to compile in files this
    /// agent cannot touch. This overload keeps them building unchanged
    /// while every owned call site migrates to the `LocalizedStringResource`
    /// initializer above; `LocalizedStringResource(stringLiteral:)` is the
    /// same conversion `ExpressibleByStringLiteral` performs for a literal,
    /// just invoked explicitly against a runtime `String` here.
    public init(
        systemImage: String,
        accessibilityLabel: String,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            systemImage: systemImage,
            accessibilityLabel: LocalizedStringResource(stringLiteral: accessibilityLabel),
            isProminent: isProminent,
            action: action
        )
    }

    /// P1.1 (Bug 3, hit-target part): every floating bar built from this
    /// component (`ToolRailView`, `ArrangeToolbarView`, `PathEditToolbarView`,
    /// `ZoomControlsView`) lives inside a `ScrollView`, whose touch-delay
    /// swallows short taps unless the tappable area is unambiguous and
    /// ≥44 pt (Apple HIG minimum). The old 32×32 frame with no explicit
    /// `contentShape` fell short on both counts. 44×44 here is the tap
    /// target; the icon itself stays visually 17 pt, just centered in more
    /// breathing room, so background chips (the `Circle`/`RoundedRectangle`
    /// below) grow with it rather than leaving dead space around a
    /// smaller icon.
    private static let hitTargetSide: CGFloat = 44

    /// UX-2: the icon glyph itself scales with Dynamic Type (base 17 pt,
    /// relative to `.body`) ، the 44×44 hit target above already has
    /// headroom for this to grow without needing a frame change.
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 17

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                .frame(width: Self.hitTargetSide, height: Self.hitTargetSide)
                .foregroundStyle(isProminent ? theme.onPrimary : theme.ink)
                .background {
                    if isProminent {
                        // The primary "+" action always reads as a round
                        // affordance ، even in Kufi, whose own radius
                        // scale is otherwise `0` everywhere ، rather than
                        // following the per-theme corner radius like a
                        // regular icon button.
                        Circle().fill(theme.primary)
                    } else {
                        RoundedRectangle(cornerRadius: theme.radius.button, style: theme.radius.style)
                            .fill(Color.clear)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
