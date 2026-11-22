import CoreText
import Foundation
import MKModel

/// D-108 font-feature control (WS-03 packet §5 task 2): maps MKModel's
/// closed `MKLigatureSetting` to Core Text OpenType feature settings and
/// applies them on the **font** (not the string), so
/// `CTFontCreatePathForGlyph` later resolves against the identical
/// feature-configured font (ARCHITECTURE §4.3's note).
///
/// **`rlig` is deliberately not controllable** ، the packet's task-2
/// accept criterion is that "`rlig` disable attempts are rejected by API
/// design (no such option exposed)": required ligatures (the lam-alif
/// family) are non-negotiable in Arabic, and no case of `MKLigatureSetting`
/// maps to any `rlig` setting, so the closed enum IS the rejection
/// mechanism. Verified by `FontFeatureControlTests` (no emitted feature
/// dictionary ever names `rlig`; «لا» stays one glyph even at `.off`).
public enum MKFontFeatureControl {
    /// The OpenType feature settings for `setting`, as
    /// `kCTFontFeatureSettingsAttribute` dictionaries
    /// (`kCTFontOpenTypeFeatureTag`/`kCTFontOpenTypeFeatureValue` form).
    /// Exposed (not private) so tests can assert the exact dictionaries ،
    /// the packet's "attribute dump" accept criterion ، without shaping.
    ///
    /// Mapping:
    /// - `.standard` → no overrides (font defaults: `liga`/`calt`/`rlig`
    ///   all as the font ships them).
    /// - `.discretionaryOn` → `dlig=1` plus explicit `calt=1` (contextual
    ///   alternates confirmed on ، some fonts gate stylistic joins there).
    /// - `.off` → `liga=0`, `dlig=0`. `calt` is left untouched even at
    ///   `.off`: several Arabic fonts route required contextual behavior
    ///   through `calt`, and D-108's ban on breaking required shaping
    ///   outranks a maximal "off" (documented per-font expectation,
    ///   docs/impl-log/WS-03.md).
    public static func featureSettings(for setting: MKLigatureSetting) -> [[CFString: Any]] {
        switch setting {
        case .standard:
            return []
        case .discretionaryOn:
            return [
                [kCTFontOpenTypeFeatureTag: "dlig", kCTFontOpenTypeFeatureValue: 1],
                [kCTFontOpenTypeFeatureTag: "calt", kCTFontOpenTypeFeatureValue: 1],
            ]
        case .off:
            return [
                [kCTFontOpenTypeFeatureTag: "liga", kCTFontOpenTypeFeatureValue: 0],
                [kCTFontOpenTypeFeatureTag: "dlig", kCTFontOpenTypeFeatureValue: 0],
            ]
        }
    }

    /// Returns `base` reconfigured with the feature settings for `setting`
    /// (same size, same other attributes). `.standard` returns `base`
    /// unchanged (no descriptor round-trip cost on the default path).
    public static func font(_ base: CTFont, applying setting: MKLigatureSetting) -> CTFont {
        let settings = featureSettings(for: setting)
        guard !settings.isEmpty else { return base }
        let attributes: [CFString: Any] = [kCTFontFeatureSettingsAttribute: settings]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        return CTFontCreateCopyWithAttributes(base, 0, nil, descriptor)
    }

    /// The `NSAttributedString.Key.ligature` value paired with `setting`
    /// (0 = required ligatures only, 1 = default ligatures) ، applied by
    /// `MKAttributedStringBuilder` alongside the font-level features.
    /// Note even `0` never disables `rlig` (Core Text's documented
    /// semantics: value 0 keeps required ligatures).
    public static func ligatureAttributeValue(for setting: MKLigatureSetting) -> Int {
        setting == .off ? 0 : 1
    }
}
