import SwiftUI

/// **1D · طيف (Tayf) ، "Vivid Creator"**, an alternative theme (bold,
/// social, duotone). Uses two accent colors (`primary` violet, `secondary`
/// magenta) rather than one ، the only theme where `secondary` is a
/// genuinely distinct hue instead of a muted variant of `primary`.
public struct TayfTheme: MKTheme {
    public init() {}

    public static let `default` = TayfTheme()

    public var bg: Color { Color(light: Self.bgLight, dark: Self.bgDark) }
    public var bgAlt: Color { Color(light: Self.surfaceLight, dark: Self.bgAltDark) }
    public var surface: Color { Color(light: Self.surfaceLight, dark: Self.surfaceDark) }
    public var surfaceMuted: Color { surface }
    public var border: Color { Color(light: Self.surfaceLight, dark: Self.surfaceDark) }

    public var ink: Color { Color(light: Self.inkLight, dark: Self.inkDark) }
    public var inkMuted: Color { Color(light: Self.inkMutedLight, dark: Self.inkMutedDark) }
    public var inkFaint: Color { inkMuted }

    public var primary: Color { Color(light: Self.primaryLight, dark: Self.primaryDark) }
    public var primaryPressed: Color { Color(light: Color.darkened(hex: 0x5B37F0), dark: Color.darkened(hex: 0x7C5CFF)) }
    public var onPrimary: Color { Color(hex: 0xFFFFFF) }
    public var secondary: Color { Color(light: Self.secondaryLight, dark: Self.secondaryDark) }

    public var canvasBackdrop: Color { Color(light: Self.inkLight, dark: Self.surfaceDark) }
    public var selectionStroke: Color { primary }
    public var warning: Color { Color(light: Self.warningLight, dark: Self.warningDark) }
    public var destructive: Color { Color(light: Self.destructiveLight, dark: Self.destructiveDark) }

    // MARK: Token scales

    /// Spec: "Display font: Lalezar (single weight) / Cairo Black for
    /// headings." `Lalezar` is the wordmark/hero display face; `Cairo`
    /// (variable) is the UI face, and heading roles in `MKTypeRamp`
    /// already request a bold `.fontWeight`, which drives Cairo's
    /// variable weight axis toward its heavier instances.
    public static let fontSet = MKFontSet(
        display: "Lalezar-Regular",
        ui: "Cairo-Regular",
        mono: "IBMPlexMono-Regular"
    )
    public var fonts: MKFontSet { Self.fontSet }
    public var typeRamp: MKTypeRamp { MKTypeRamp(fonts: Self.fontSet) }
    public var spacing: MKSpacing { .default }
    public var radius: MKRadiusScale { MKRadiusScale(button: 12, card: 16, sheet: 16, pill: 999) }
    public var motion: MKMotionTokens { .default }

    public var elevation: MKElevationStyles {
        MKElevationStyles(
            panel: MKElevationStyle(radius: 16, yOffset: 6, opacity: 0.14),
            floatingBar: MKElevationStyle(radius: 10, yOffset: 3, opacity: 0.20)
        )
    }

    // MARK: - Raw hex constants

    private static let bgLight = Color(hex: 0xFAFAFA)
    private static let bgDark = Color(hex: 0x0E0B16)
    private static let bgAltDark = Color(hex: 0x000000)
    private static let surfaceLight = Color(hex: 0xEFEBFF)
    private static let surfaceDark = Color(hex: 0x1E1830)

    private static let inkLight = Color(hex: 0x111114)
    private static let inkDark = Color(hex: 0xF3F1FF)
    private static let inkMutedLight = Color(hex: 0x8F8F9C)
    private static let inkMutedDark = Color(hex: 0x8F8AA5)

    private static let primaryLight = Color(hex: 0x5B37F0)
    private static let primaryDark = Color(hex: 0x7C5CFF)
    private static let secondaryLight = Color(hex: 0xF0379B)
    private static let secondaryDark = Color(hex: 0xFF4FA8)

    private static let warningLight = Color(hex: 0xC08A2E)
    private static let warningDark = Color(hex: 0xD9A94F)
    private static let destructiveLight = Color(hex: 0xB3261E)
    private static let destructiveDark = Color(hex: 0xE05C51)
}
