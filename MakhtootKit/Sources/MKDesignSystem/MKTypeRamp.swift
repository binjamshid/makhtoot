import SwiftUI

/// The roles in the Arabic UI type ramp (D-126). This is the **UI** ramp ،
/// the active theme's bundled display/UI/mono fonts (`MKFontSet`), never
/// system SF Arabic. Canvas text fonts (the Arabic font catalog: Naskh,
/// Ruq'ah, Thuluth, Diwani, Kufi, …) are a completely separate concern
/// owned by `MKFonts`; nothing in this ramp is ever used to render
/// user-authored canvas text.
public enum MKTypeRole: Sendable, CaseIterable {
    /// Hero/logo-scale display type (wordmark, canvas hero text).
    case display
    case largeTitle
    case title
    case title2
    case headline
    case body
    case callout
    case footnote
    case caption
    /// Spec/metadata labels ، always the theme's `mono` face.
    case mono
}

/// One resolved type-ramp entry: the SwiftUI `Font`, an optional weight to
/// apply via `.fontWeight(_:)` (needed for the variable-font families ،
/// Cairo, Reem Kufi, El Messiri ، that are bundled as a single registered
/// PostScript name and select weight via the variable axis rather than a
/// distinct face), plus the line-height multiplier. Arabic ascender/
/// descender space (tashkeel stacks in particular ، "خَطٌّ عَرَبِيٌّ") needs
/// generous line height, hence the ≥1.3 multiplier floor at every ramp
/// step.
public struct MKTypeStyle: Sendable {
    public let font: Font
    public let weight: Font.Weight?
    /// Multiplier against the point size to derive extra line spacing via
    /// `.lineSpacing(pointSize * (lineHeightMultiplier - 1))`.
    public let lineHeightMultiplier: CGFloat
    public let pointSize: CGFloat

    public init(font: Font, pointSize: CGFloat, lineHeightMultiplier: CGFloat, weight: Font.Weight? = nil) {
        self.font = font
        self.pointSize = pointSize
        self.lineHeightMultiplier = lineHeightMultiplier
        self.weight = weight
    }

    /// The `.lineSpacing(...)` value to pair with `font` so SwiftUI text
    /// gets the full multiplier (SwiftUI's `lineSpacing` is *extra* space
    /// added on top of the font's natural line height, not a multiplier
    /// itself).
    public var extraLineSpacing: CGFloat {
        pointSize * (lineHeightMultiplier - 1)
    }
}

/// The Arabic type ramp: the active theme's bundled fonts at fixed sizes/
/// weights, tuned with line-height multipliers ≥1.3 so Qur'anic-annotation-
/// range tashkeel stacks never clip at any ramp step (WS-01 packet §6
/// fixture: "خَطٌّ عَرَبِيٌّ"). `.display`/`.largeTitle` resolve to the theme's
/// `fonts.display` face; every other role resolves to `fonts.ui`; `.mono`
/// resolves to `fonts.mono`.
public struct MKTypeRamp: Sendable {
    private let fonts: MKFontSet

    public init(fonts: MKFontSet) {
        self.fonts = fonts
    }

    public func style(for role: MKTypeRole) -> MKTypeStyle {
        switch role {
        case .display:
            return MKTypeStyle(font: .custom(fonts.display, size: 74, relativeTo: .largeTitle), pointSize: 74, lineHeightMultiplier: 1.2, weight: .bold)
        case .largeTitle:
            return MKTypeStyle(font: .custom(fonts.display, size: 34, relativeTo: .largeTitle), pointSize: 34, lineHeightMultiplier: 1.3, weight: .bold)
        case .title:
            return MKTypeStyle(font: .custom(fonts.ui, size: 28, relativeTo: .title), pointSize: 28, lineHeightMultiplier: 1.3, weight: .bold)
        case .title2:
            return MKTypeStyle(font: .custom(fonts.ui, size: 22, relativeTo: .title2), pointSize: 22, lineHeightMultiplier: 1.3, weight: .semibold)
        case .headline:
            return MKTypeStyle(font: .custom(fonts.ui, size: 17, relativeTo: .headline), pointSize: 17, lineHeightMultiplier: 1.35, weight: .semibold)
        case .body:
            return MKTypeStyle(font: .custom(fonts.ui, size: 17, relativeTo: .body), pointSize: 17, lineHeightMultiplier: 1.35, weight: .regular)
        case .callout:
            return MKTypeStyle(font: .custom(fonts.ui, size: 16, relativeTo: .callout), pointSize: 16, lineHeightMultiplier: 1.35, weight: .regular)
        case .footnote:
            return MKTypeStyle(font: .custom(fonts.ui, size: 13, relativeTo: .footnote), pointSize: 13, lineHeightMultiplier: 1.4, weight: .regular)
        case .caption:
            return MKTypeStyle(font: .custom(fonts.ui, size: 11, relativeTo: .caption), pointSize: 11, lineHeightMultiplier: 1.4, weight: .medium)
        case .mono:
            return MKTypeStyle(font: .custom(fonts.mono, size: 10, relativeTo: .caption2), pointSize: 10, lineHeightMultiplier: 1.3, weight: .regular)
        }
    }

    /// The Hibr (default theme) type ramp, kept as a static convenience for
    /// call sites/previews that don't have a theme in scope.
    public static let `default` = MKTypeRamp(fonts: HibrTheme.fontSet)
}

public extension View {
    /// Applies a full `MKTypeStyle` (font + weight + tuned line spacing) in
    /// one modifier, the way every MakhtootKit component should consume
    /// the type ramp rather than reaching for `.font(...)` alone.
    func mkTypeStyle(_ style: MKTypeStyle) -> some View {
        self.font(style.font)
            .fontWeight(style.weight)
            .lineSpacing(style.extraLineSpacing)
    }

    /// Sets the theme's UI font as the *ambient default* for this subtree
    /// (`\.font` environment value) ، for native-chrome containers like
    /// `List` whose row `Label`/`Text` content is plain and never calls
    /// `.mkTypeStyle(...)` itself (so it would otherwise silently render
    /// in the system font instead of the active theme's `fonts.ui` face).
    /// Any descendant that *does* set an explicit font (including every
    /// `.mkTypeStyle(...)` call) still wins locally ، this only fills in
    /// the un-styled default, it never overrides.
    func mkDefaultFont(_ theme: any MKTheme, size: CGFloat = 17) -> some View {
        self.environment(\.font, .custom(theme.fonts.ui, size: size))
    }
}
