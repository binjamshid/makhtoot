import CoreText
import Foundation
import MKFoundation
import MKModel
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// D-103's single attributed-string construction path (WS-03 packet §5
/// task 1): every shaping call in this module goes through this function so
/// attributes never diverge between capture paths (display, derivation,
/// form resolution ، ARCHITECTURE §4.3).
///
/// P3-completion pass: consumes the real MKModel types (`MKSourceText` with
/// per-range `MKStyleRun` overrides, `MKTextStyle`), applies D-108 feature
/// control on the font via `MKFontFeatureControl`, and applies the forced
/// writing-direction attribute for `.rightToLeftOverride`. Per-cluster-pair
/// kerning overrides (`MKTextStyle.kerningOverrides`) are applied by
/// `MKShapingEngine` in a second pass (cluster boundaries only exist after
/// a first shape) ، see `MKShapingEngine.kernOverrideAttributes`.
public enum MKAttributedStringBuilder {
    /// Builds the fully-attributed string for `text`/`style`.
    /// `resolveFont` maps a style to its feature-configured `CTFont`
    /// (the engine passes `MKFontProviding` resolution + D-108 feature
    /// application); it is called once for the base style and once per
    /// `styleRuns` override.
    /// `extraKerning` carries the engine's second-pass per-range kern
    /// values (UTF-16 range → points), empty on the first pass.
    public static func make(
        text: MKSourceText,
        style: MKTextStyle,
        resolveFont: (MKTextStyle) -> CTFont,
        extraKerning: [(range: Range<Int>, value: Double)] = []
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: text.string,
            attributes: baseAttributes(for: style, font: resolveFont(style)))

        // Per-range style-run overrides (MKSourceText.styleRuns).
        let length = result.length
        for run in text.styleRuns {
            let start = max(0, run.utf16Start)
            let end = min(length, run.utf16Start + run.utf16Length)
            guard start < end else { continue }
            result.addAttributes(
                overrideAttributes(for: run.style, font: resolveFont(run.style)),
                range: NSRange(location: start, length: end - start))
        }

        // Engine second-pass kerning (cluster-pair overrides, D-105).
        for kern in extraKerning {
            let start = max(0, kern.range.lowerBound)
            let end = min(length, kern.range.upperBound)
            guard start < end else { continue }
            result.addAttribute(.kern, value: kern.value, range: NSRange(location: start, length: end - start))
        }

        return result
    }

    /// Whole-string attributes for the base style: font, paragraph style
    /// (base direction + line height), tracking, baseline shift, ligature
    /// attribute, and the forced-direction override when the style demands
    /// it.
    static func baseAttributes(for style: MKTextStyle, font: CTFont) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        switch style.baseDirection {
        case .rightToLeft, .rightToLeftOverride:
            paragraph.baseWritingDirection = .rightToLeft
        case .leftToRight:
            paragraph.baseWritingDirection = .leftToRight
        }
        paragraph.lineHeightMultiple = CGFloat(style.lineHeightMultiple)

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
            .kern: style.tracking,
            .baselineOffset: style.baselineShift,
            .ligature: MKFontFeatureControl.ligatureAttributeValue(for: style.ligatureSetting),
        ]
        // Forced direction (user override, D-109/ARCHITECTURE §4.3): the
        // kCTWritingDirection attribute with the override flag makes every
        // run take RTL direction regardless of character classes.
        if style.baseDirection == .rightToLeftOverride {
            let overrideValue = Int(CTWritingDirection.rightToLeft.rawValue) | kCTWritingDirectionOverride
            attrs[NSAttributedString.Key(kCTWritingDirectionAttributeName as String)] =
                [NSNumber(value: overrideValue)]
        }
        return attrs
    }

    /// Range-override attributes: everything font/metric-affecting from the
    /// override style. Paragraph style and writing direction stay
    /// whole-string properties (a per-range paragraph override is not
    /// meaningful for a single shaped line).
    static func overrideAttributes(for style: MKTextStyle, font: CTFont) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .kern: style.tracking,
            .baselineOffset: style.baselineShift,
            .ligature: MKFontFeatureControl.ligatureAttributeValue(for: style.ligatureSetting),
        ]
    }
}
