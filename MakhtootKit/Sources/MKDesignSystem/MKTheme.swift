import SwiftUI

/// One corner-radius/elevation/motion token set entry: a shadow style for a
/// panel or floating bar (D-126 "elevation styles").
public struct MKElevationStyle: Sendable {
    public var radius: CGFloat
    public var yOffset: CGFloat
    public var opacity: Double

    public init(radius: CGFloat, yOffset: CGFloat, opacity: Double) {
        self.radius = radius
        self.yOffset = yOffset
        self.opacity = opacity
    }
}

/// The two elevation contexts the shell needs at scaffold time. Later
/// workstreams (WS-06 canvas floating toolbars, WS-13 sheets) may extend
/// this struct with more cases; the shape stays additive.
public struct MKElevationStyles: Sendable {
    public var panel: MKElevationStyle
    public var floatingBar: MKElevationStyle

    public init(panel: MKElevationStyle, floatingBar: MKElevationStyle) {
        self.panel = panel
        self.floatingBar = floatingBar
    }
}

/// Corner-radius scale (D-126), one value per component role rather than a
/// generic small/medium/large scale ، the "حِبر / Hibr" design-system
/// handoff assigns radius by *what* is being drawn (icon button vs. card
/// vs. sheet vs. chip), and **كوفي / Kufi** ("Bauhaus", stark grid) sets
/// every one of these to `0` ، a themeable radius *value* per role, not a
/// fixed shape, is what lets one component (e.g. `MKChip`) render as a
/// capsule in four themes and a hard-edged rectangle in the fifth without
/// any per-theme branching in the component itself.
public struct MKRadiusScale: Sendable {
    /// Icon/toolbar buttons.
    public var button: CGFloat
    /// Cards / tiles (project browser grid, panels).
    public var card: CGFloat
    /// Sheets and other large surfaces.
    public var sheet: CGFloat
    /// Chips / pills. A "fully rounded" pill is expressed as a very large
    /// radius against a `RoundedRectangle` (equivalent to `Capsule()` at
    /// any reasonable component height) rather than a distinct shape type,
    /// so Kufi's `0` collapses it to a hard-edged rectangle for free.
    public var pill: CGFloat
    public var style: RoundedCornerStyle

    public init(button: CGFloat, card: CGFloat, sheet: CGFloat, pill: CGFloat, style: RoundedCornerStyle = .continuous) {
        self.button = button
        self.card = card
        self.sheet = sheet
        self.pill = pill
        self.style = style
    }
}

/// The named font roles a theme supplies PostScript names for (D-126 /
/// design-system handoff "Typography"). Every value must already be
/// registered process-wide by the time a view resolves it ، bundled fonts
/// are registered by `MKFontRegistrar` at launch (`MKFonts`); this type
/// intentionally holds only plain PostScript-name strings (no `MKFonts`
/// dependency) since that's all `Font.custom(_:size:)` needs.
public struct MKFontSet: Sendable {
    /// Wordmark, hero/canvas type, large screen titles.
    public var display: String
    /// Body copy, buttons, list rows, chips, metadata, general UI chrome.
    public var ui: String
    /// Optional editorial/italic accent face (e.g. quotes, subtitles).
    /// Falls back to `ui` when a theme has no dedicated accent face.
    public var accent: String?
    /// Spec/metadata labels (sizes, formats, the Latin sub-lockup).
    public var mono: String

    public init(display: String, ui: String, accent: String? = nil, mono: String) {
        self.display = display
        self.ui = ui
        self.accent = accent
        self.mono = mono
    }
}

/// The swappable-token contract for Makhtoot's visual identity (BRIEF
/// "Product identity" ، themeable Arabic-first design-system layer).
/// Every semantic color, the font set, type ramp, spacing, radii,
/// elevation, and motion tokens are exposed here so a re-theme swaps one
/// `MKTheme` conformer without touching any consuming view (D-126).
///
/// Semantic color names follow the approved "حِبر / Hibr" design-system
/// handoff directly (`bg`/`surface`/`ink`/`primary`/… rather than the
/// earlier scaffold's `backgroundPrimary`/`accent`/… names) so the token
/// table in code reads the same as the token table in the design spec.
///
/// `Sendable` because theme values may be read from both `@MainActor` UI
/// code and background-scheduled work (e.g. export progress UI state
/// updates, D-102).
public protocol MKTheme: Sendable {
    // MARK: Semantic colors ، backgrounds/surfaces

    /// App background.
    var bg: Color { get }
    /// Secondary surface (editor bg, grouped settings bg).
    var bgAlt: Color { get }
    /// Cards / tiles / artboard-on-app.
    var surface: Color { get }
    /// Chips, search field, toolbars.
    var surfaceMuted: Color { get }
    /// Hairlines around tiles/rows.
    var border: Color { get }

    // MARK: Semantic colors ، ink

    var ink: Color { get }
    var inkMuted: Color { get }
    var inkFaint: Color { get }

    // MARK: Semantic colors ، accents

    var primary: Color { get }
    var primaryPressed: Color { get }
    /// Text/icon color on top of a `primary`-filled surface.
    var onPrimary: Color { get }
    /// Secondary accent (e.g. Hibr's gold) ، highlights, hairlines.
    var secondary: Color { get }

    // MARK: Semantic colors ، canvas & utility

    var canvasBackdrop: Color { get }
    var selectionStroke: Color { get }
    var warning: Color { get }
    var destructive: Color { get }

    // MARK: Token scales

    var fonts: MKFontSet { get }
    var typeRamp: MKTypeRamp { get }
    var spacing: MKSpacing { get }
    var radius: MKRadiusScale { get }
    var elevation: MKElevationStyles { get }
    var motion: MKMotionTokens { get }
}

/// The five approved design directions, each a full `MKTheme` conformer
/// (`MakhtootKit/Sources/MKDesignSystem/Themes/`). Persisted as a user
/// preference (`mk.appearance.themeID`) and resolved at the app root
/// (`MakhtootApp`) into the `\.mkTheme` environment value below.
public enum MKThemeID: String, CaseIterable, Sendable, Identifiable {
    case hibr
    case naqsh
    case raml
    case tayf
    case kufi

    public var id: String { rawValue }

    /// Arabic display name for the Settings theme picker.
    public var displayName: String {
        switch self {
        case .hibr: return "حِبر"
        case .naqsh: return "نَقش"
        case .raml: return "رمل"
        case .tayf: return "طيف"
        case .kufi: return "كوفي"
        }
    }

    public func resolve() -> any MKTheme {
        switch self {
        case .hibr: return HibrTheme.default
        case .naqsh: return NaqshTheme.default
        case .raml: return RamlTheme.default
        case .tayf: return TayfTheme.default
        case .kufi: return KufiTheme.default
        }
    }
}

// MARK: - SwiftUI Environment plumbing

private struct MKThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: any MKTheme = HibrTheme.default
}

public extension EnvironmentValues {
    /// The active theme. `MakhtootApp` injects this once at the app root
    /// (`.environment(\.mkTheme, theme)`), re-resolved from the persisted
    /// `MKThemeID` whenever the user changes it in Settings; every
    /// component in `MKDesignSystem/Components` reads it via
    /// `@Environment(\.mkTheme)` rather than accepting a theme parameter,
    /// so a re-theme requires no per-view edits (PLAN P1 exit gate).
    var mkTheme: any MKTheme {
        get { self[MKThemeEnvironmentKey.self] }
        set { self[MKThemeEnvironmentKey.self] = newValue }
    }
}
