import SwiftUI

/// **1E · كوفي (Kufi) ، "Bauhaus"**, an alternative theme (stark grid,
/// type-as-art). The one theme with a genuinely different *shape*
/// language: `radius` is `0` everywhere, which ، combined with
/// `MKRadiusScale.pill` driving chip/pill shapes as a `RoundedRectangle`
/// rather than a hardcoded `Capsule()` ، collapses every rounded surface
/// to a hard edge without any per-theme branching in the components
/// themselves.
public struct KufiTheme: MKTheme {
    public init() {}

    public static let `default` = KufiTheme()

    public var bg: Color { Color(light: Self.bgLight, dark: Self.bgDark) }
    public var bgAlt: Color { Color(light: Self.surfaceLight, dark: Self.surfaceDark) }
    public var surface: Color { Color(light: Self.surfaceLight, dark: Self.surfaceDark) }
    public var surfaceMuted: Color { surface }
    public var border: Color { Color(light: Self.inkLight, dark: Self.inkDark) }

    public var ink: Color { Color(light: Self.inkLight, dark: Self.inkDark) }
    public var inkMuted: Color { Color(light: Self.inkMutedLight, dark: Self.inkMutedDark) }
    public var inkFaint: Color { inkMuted }

    public var primary: Color { Color(light: Self.primaryLight, dark: Self.primaryDark) }
    public var primaryPressed: Color { Color(light: Color.darkened(hex: 0xE23B2E), dark: Color.darkened(hex: 0xFF5445)) }
    public var onPrimary: Color { Color(hex: 0xFFFFFF) }
    public var secondary: Color { primary }

    public var canvasBackdrop: Color { Color(light: Self.inkLight, dark: Self.surfaceLight) }
    public var selectionStroke: Color { primary }
    public var warning: Color { Color(light: Self.warningLight, dark: Self.warningDark) }
    public var destructive: Color { primary }

    // MARK: Token scales

    public static let fontSet = MKFontSet(
        display: "ReemKufi",
        ui: "ReemKufi",
        mono: "IBMPlexMono-Regular"
    )
    public var fonts: MKFontSet { Self.fontSet }
    public var typeRamp: MKTypeRamp { MKTypeRamp(fonts: Self.fontSet) }
    public var spacing: MKSpacing { .default }
    /// Sharp corners everywhere, per spec ، `0` for every radius role,
    /// including `pill` (chips render as hard-edged rectangles).
    public var radius: MKRadiusScale { MKRadiusScale(button: 0, card: 0, sheet: 0, pill: 0, style: .circular) }
    public var motion: MKMotionTokens { .default }

    public var elevation: MKElevationStyles {
        MKElevationStyles(
            panel: MKElevationStyle(radius: 0, yOffset: 0, opacity: 0),
            floatingBar: MKElevationStyle(radius: 0, yOffset: 0, opacity: 0)
        )
    }

    // MARK: - Raw hex constants

    private static let bgLight = Color(hex: 0xFFFFFF)
    private static let bgDark = Color(hex: 0x0A0A0A)
    private static let surfaceLight = Color(hex: 0xF2F2EF)
    private static let surfaceDark = Color(hex: 0x161616)

    private static let inkLight = Color(hex: 0x0A0A0A)
    private static let inkDark = Color(hex: 0xFFFFFF)
    private static let inkMutedLight = Color(hex: 0x6E6E6E)
    private static let inkMutedDark = Color(hex: 0x8A8A8A)

    private static let primaryLight = Color(hex: 0xE23B2E)
    private static let primaryDark = Color(hex: 0xFF5445)

    private static let warningLight = Color(hex: 0xC08A2E)
    private static let warningDark = Color(hex: 0xD9A94F)
}
