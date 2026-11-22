import SwiftUI

/// **1C · رمل (Raml) ، "Warm Sand"**, an alternative theme (calm,
/// boutique). Light is the primary/native mode for this direction.
public struct RamlTheme: MKTheme {
    public init() {}

    public static let `default` = RamlTheme()

    public var bg: Color { Color(light: Self.bgLight, dark: Self.bgDark) }
    public var bgAlt: Color { Color(light: Self.surfaceLight, dark: Self.bgAltDark) }
    public var surface: Color { Color(light: Self.surfaceLight, dark: Self.surfaceDark) }
    public var surfaceMuted: Color { Color(light: Self.bgLight, dark: Self.borderDark) }
    public var border: Color { Color(light: Self.borderLight, dark: Self.borderDark) }

    public var ink: Color { Color(light: Self.inkLight, dark: Self.inkDark) }
    public var inkMuted: Color { Color(light: Self.inkMutedLight, dark: Self.inkMutedLight) }
    public var inkFaint: Color { inkMuted }

    public var primary: Color { Color(light: Self.primaryLight, dark: Self.primaryDark) }
    public var primaryPressed: Color { Color(light: Color.darkened(hex: 0xC0603E), dark: Color.darkened(hex: 0xD5744F)) }
    public var onPrimary: Color { Color(light: Self.surfaceLight, dark: Self.bgDark) }
    public var secondary: Color { primary }

    public var canvasBackdrop: Color { Color(light: Self.bgAltDark, dark: Self.surfaceLight) }
    public var selectionStroke: Color { primary }
    public var warning: Color { Color(light: Self.warningLight, dark: Self.warningDark) }
    public var destructive: Color { Color(light: Self.destructiveLight, dark: Self.destructiveDark) }

    // MARK: Token scales

    public static let fontSet = MKFontSet(
        display: "ElMessiri-Regular",
        ui: "Tajawal-Regular",
        mono: "IBMPlexMono-Regular"
    )
    public var fonts: MKFontSet { Self.fontSet }
    public var typeRamp: MKTypeRamp { MKTypeRamp(fonts: Self.fontSet) }
    public var spacing: MKSpacing { .default }
    public var radius: MKRadiusScale { MKRadiusScale(button: 12, card: 16, sheet: 20, pill: 999) }
    public var motion: MKMotionTokens { .default }

    public var elevation: MKElevationStyles {
        MKElevationStyles(
            panel: MKElevationStyle(radius: 14, yOffset: 4, opacity: 0.08),
            floatingBar: MKElevationStyle(radius: 8, yOffset: 2, opacity: 0.12)
        )
    }

    // MARK: - Raw hex constants

    private static let bgLight = Color(hex: 0xF5EFE6)
    private static let bgDark = Color(hex: 0x1E1913)
    private static let bgAltDark = Color(hex: 0x161009)
    private static let surfaceLight = Color(hex: 0xFBF7F0)
    private static let surfaceDark = Color(hex: 0x282118)
    private static let borderLight = Color(hex: 0xE7DCC8)
    private static let borderDark = Color(hex: 0x352C20)

    private static let inkLight = Color(hex: 0x33291F)
    private static let inkDark = Color(hex: 0xEFE7D9)
    private static let inkMutedLight = Color(hex: 0x9A9082)

    private static let primaryLight = Color(hex: 0xC0603E)
    private static let primaryDark = Color(hex: 0xD5744F)

    private static let warningLight = Color(hex: 0xC08A2E)
    private static let warningDark = Color(hex: 0xD9A94F)
    private static let destructiveLight = Color(hex: 0xB3261E)
    private static let destructiveDark = Color(hex: 0xE05C51)
}
