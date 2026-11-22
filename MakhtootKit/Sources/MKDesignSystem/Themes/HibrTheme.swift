import SwiftUI

/// **1A · حِبر (Hibr) ، "Ink & Parchment"**, the approved default theme
/// (design-system handoff, `assets/Design system direction exploration.zip`
/// → `design_handoff_makhtoot_design_system/README.md`). Personality:
/// scholarly, literary, warm ، parchment surfaces, deep ink text, an
/// oxblood primary and a muted gold secondary.
///
/// **Dark-mode primary/secondary swap (spec note, not a bug):** the
/// handoff calls out that gold reads better than oxblood as the dominant
/// interactive color on a near-black background, so in dark mode
/// `primary` resolves to the theme's gold value (dominant buttons, active
/// chip, "+", "تم") while `secondary` resolves to the oxblood accent
/// value (reserved for smaller highlights) ، the exact inverse of light
/// mode. Every call site just reads `theme.primary`/`theme.onPrimary`, so
/// this swap is fully contained here.
public struct HibrTheme: MKTheme {
    public init() {}

    public static let `default` = HibrTheme()

    // MARK: Semantic colors ، backgrounds/surfaces

    public var bg: Color { Color(light: Self.bgLight, dark: Self.bgDark) }
    public var bgAlt: Color { Color(light: Self.bgAltLight, dark: Self.bgAltDark) }
    public var surface: Color { Color(light: Self.surfaceLight, dark: Self.surfaceDark) }
    public var surfaceMuted: Color { Color(light: Self.surfaceMutedLight, dark: Self.surfaceMutedDark) }
    public var border: Color { Color(light: Self.borderLight, dark: Self.borderDark) }

    // MARK: Semantic colors ، ink

    public var ink: Color { Color(light: Self.inkLight, dark: Self.inkDark) }
    public var inkMuted: Color { Color(light: Self.inkMutedLight, dark: Self.inkMutedDark) }
    public var inkFaint: Color { Color(light: Self.inkFaintLight, dark: Self.inkFaintDark) }

    // MARK: Semantic colors ، accents (see dark-mode swap note above)

    public var primary: Color { Color(light: Self.oxbloodLight, dark: Self.goldDark) }
    public var primaryPressed: Color { Color(light: Color.darkened(hex: 0x8A3324), dark: Color.darkened(hex: 0xC89A56)) }
    public var onPrimary: Color { Color(light: Self.onOxbloodLight, dark: Self.onGoldDark) }
    public var secondary: Color { Color(light: Self.goldLight, dark: Self.oxbloodDarkAccent) }

    // MARK: Semantic colors ، canvas & utility

    public var canvasBackdrop: Color { Color(light: Self.canvasBackdropLight, dark: Self.canvasBackdropDark) }
    public var selectionStroke: Color { primary }
    public var warning: Color { Color(light: Self.warningLight, dark: Self.warningDark) }
    public var destructive: Color { Color(light: Self.destructiveLight, dark: Self.destructiveDark) }

    // MARK: Token scales

    public static let fontSet = MKFontSet(
        display: "ArefRuqaa-Bold",
        ui: "IBMPlexSansArabic-Regular",
        accent: "Amiri-Regular",
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

    // MARK: - Raw hex constants (design-handoff-editable)

    private static let bgLight = Color(hex: 0xF3EAD8)
    private static let bgDark = Color(hex: 0x16120C)
    private static let bgAltLight = Color(hex: 0xEFE4CF)
    private static let bgAltDark = Color(hex: 0x0F0C08)
    private static let surfaceLight = Color(hex: 0xFBF5E7)
    private static let surfaceDark = Color(hex: 0x211A11)
    private static let surfaceMutedLight = Color(hex: 0xE5D8BF)
    private static let surfaceMutedDark = Color(hex: 0x221B11)
    private static let borderLight = Color(hex: 0xE6D9BF)
    private static let borderDark = Color(hex: 0x2E2415)

    private static let inkLight = Color(hex: 0x1C1712)
    private static let inkDark = Color(hex: 0xEFE3CC)
    private static let inkMutedLight = Color(hex: 0x6B5A44)
    private static let inkMutedDark = Color(hex: 0x9A8A68)
    private static let inkFaintLight = Color(hex: 0x9A8F78)
    private static let inkFaintDark = Color(hex: 0x7A6C50)

    // Oxblood ، light-mode primary, dark-mode secondary (see swap note).
    private static let oxbloodLight = Color(hex: 0x8A3324)
    private static let oxbloodDarkAccent = Color(hex: 0xB5462F)
    private static let onOxbloodLight = Color(hex: 0xF1E7D3)

    // Gold ، light-mode secondary, dark-mode primary (see swap note).
    private static let goldLight = Color(hex: 0xB4894C)
    private static let goldDark = Color(hex: 0xC89A56)
    private static let onGoldDark = Color(hex: 0x16120C)

    private static let canvasBackdropLight = Color(hex: 0x14110C)
    private static let canvasBackdropDark = Color(hex: 0xFBF5E7)

    private static let warningLight = Color(hex: 0xC08A2E)
    private static let warningDark = Color(hex: 0xD9A94F)
    private static let destructiveLight = Color(hex: 0xB3261E)
    private static let destructiveDark = Color(hex: 0xE05C51)
}
