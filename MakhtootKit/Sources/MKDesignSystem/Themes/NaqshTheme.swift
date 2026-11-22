import SwiftUI

/// **1B · نَقش (Naqsh) ، "Studio Noir"**, an alternative theme (pro, molten
/// gold). Dark is the primary/native mode for this direction; light is
/// provided for parity with the theme-switching contract.
public struct NaqshTheme: MKTheme {
    public init() {}

    public static let `default` = NaqshTheme()

    public var bg: Color { Color(light: Self.bgLight, dark: Self.bgDark) }
    public var bgAlt: Color { Color(light: Self.bgAltLight, dark: Self.bgAltDark) }
    public var surface: Color { Color(light: Self.surfaceLight, dark: Self.surfaceDark) }
    public var surfaceMuted: Color { Color(light: Self.surfaceLight, dark: Self.surfaceDark) }
    public var border: Color { Color(light: Self.borderLight, dark: Self.borderDark) }

    public var ink: Color { Color(light: Self.inkLight, dark: Self.inkDark) }
    public var inkMuted: Color { Color(light: Self.inkMutedLight, dark: Self.inkMutedDark) }
    public var inkFaint: Color { inkMuted }

    public var primary: Color { Color(light: Self.primaryLight, dark: Self.primaryDark) }
    public var primaryPressed: Color { Color(light: Color.darkened(hex: 0xB07E2E), dark: Color.darkened(hex: 0xE0A64B)) }
    public var onPrimary: Color { Color(light: Self.onPrimaryLight, dark: Self.onPrimaryDark) }
    public var secondary: Color { primary }

    public var canvasBackdrop: Color { Color(light: Self.surfaceDark, dark: Self.surfaceLight) }
    public var selectionStroke: Color { primary }
    public var warning: Color { Color(light: Self.warningLight, dark: Self.warningDark) }
    public var destructive: Color { Color(light: Self.destructiveLight, dark: Self.destructiveDark) }

    // MARK: Token scales

    public static let fontSet = MKFontSet(
        display: "ReemKufi",
        ui: "IBMPlexSansArabic-Regular",
        mono: "IBMPlexMono-Regular"
    )
    public var fonts: MKFontSet { Self.fontSet }
    public var typeRamp: MKTypeRamp { MKTypeRamp(fonts: Self.fontSet) }
    public var spacing: MKSpacing { .default }
    public var radius: MKRadiusScale { MKRadiusScale(button: 11, card: 14, sheet: 18, pill: 999) }
    public var motion: MKMotionTokens { .default }

    public var elevation: MKElevationStyles {
        MKElevationStyles(
            panel: MKElevationStyle(radius: 12, yOffset: 4, opacity: 0.10),
            floatingBar: MKElevationStyle(radius: 8, yOffset: 2, opacity: 0.16)
        )
    }

    // MARK: - Raw hex constants

    private static let bgLight = Color(hex: 0xFBFAF6)
    private static let bgDark = Color(hex: 0x0C0C0E)
    private static let bgAltLight = Color(hex: 0xF1EFE8)
    private static let bgAltDark = Color(hex: 0x000000)
    private static let surfaceLight = Color(hex: 0xFFFFFF)
    private static let surfaceDark = Color(hex: 0x17171A)
    private static let borderLight = Color(hex: 0xE3E1D8)
    private static let borderDark = Color(hex: 0x232327)

    private static let inkLight = Color(hex: 0x17171A)
    private static let inkDark = Color(hex: 0xF4F3EF)
    private static let inkMutedLight = Color(hex: 0x8A8A8F)
    private static let inkMutedDark = Color(hex: 0x8A8A8F)

    private static let primaryLight = Color(hex: 0xB07E2E)
    private static let primaryDark = Color(hex: 0xE0A64B)
    private static let onPrimaryLight = Color(hex: 0xFFFFFF)
    private static let onPrimaryDark = Color(hex: 0x0C0C0E)

    private static let warningLight = Color(hex: 0xC08A2E)
    private static let warningDark = Color(hex: 0xD9A94F)
    private static let destructiveLight = Color(hex: 0xB3261E)
    private static let destructiveDark = Color(hex: 0xE05C51)
}
