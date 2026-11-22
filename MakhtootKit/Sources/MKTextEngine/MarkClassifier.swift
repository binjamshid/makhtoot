import Foundation
import MKModel

/// D-105 mark identification: "combining marks (Unicode categories Mn/Me,
/// incl. U+0610–061A, U+064B–065F, U+0670, U+06D6–06ED Qur'anic annotation
/// range)". Implements the classification via `Unicode.Scalar.Properties
/// .generalCategory` plus the explicit inclusion/exclusion table the packet
/// requires (WS-03 packet §5 task 8).
///
/// P3-completion note: classification now returns MKModel's `MKMarkClass`
/// directly (the type `MKMarkNode.markClass` stores) ، the early spike's
/// local `MKTEMarkClass` is gone. Range→class assignment follows
/// ARCHITECTURE §6.2 (honorifics U+0610–061A → `.quranicAnnotation`);
/// `MKMarkNode.swift`'s doc comment groups 0610–061A under `.tashkeel`
/// illustratively ، the enum cases are identical either way, and §6.2 is
/// the normative table, so this classifier follows §6.2 (flagged in
/// docs/impl-log/WS-03.md).
public enum MKMarkClassifier {
    // MARK: - D-105 explicit ranges

    /// U+0610–061A: honorific/Qur'anic marks (all `Mn`, verified against
    /// `Unicode.Scalar.Properties.generalCategory` at implementation time ،
    /// see docs/impl-log/WS-03.md session log).
    public static let honorifics: ClosedRange<UInt32> = 0x0610...0x061A
    /// U+064B–065F: harakat + extended harakat/hamza-mark block.
    public static let harakatBlock: ClosedRange<UInt32> = 0x064B...0x065F
    /// U+0670: Arabic letter superscript alef.
    public static let superscriptAlef: UInt32 = 0x0670
    /// U+06D6–06ED: Qur'anic annotation signs (small high ligatures, stop
    /// signs, sajdah/rub-el-hizb markers…). **Not every scalar in this
    /// range is a combining mark** ، three are spacing/format characters,
    /// excluded explicitly below per the packet's own callout ("U+06DD/
    /// U+06DE/U+06E9 are enclosing/other ، classify per actual category").
    public static let quranicAnnotations: ClosedRange<UInt32> = 0x06D6...0x06ED

    /// Scalars inside `quranicAnnotations` that are **not** marks, verified
    /// empirically against `Unicode.Scalar.Properties.generalCategory`
    /// (docs/impl-log/WS-03.md session log records the probe):
    /// - U+06DD ARABIC END OF AYAH ، general category `.format` (a
    ///   formatting control, not a glyph-attaching mark).
    /// - U+06DE ARABIC START OF RUB EL HIZB (۞) ، general category
    ///   `.otherSymbol`, a spacing sign; TEST_MATRIX T-TXT-4 requires it be
    ///   "classified as base glyphs, not marks."
    /// - U+06E9 ARABIC PLACE OF SAJDAH (۩) ، general category
    ///   `.otherSymbol`, same as above.
    public static let quranicNonMarkExceptions: Set<UInt32> = [0x06DD, 0x06DE, 0x06E9]

    // MARK: - Control/formatting scalars (never marks, never base letters)

    /// Zero-width joiners/formatting and bidi-control scalars. A cluster
    /// whose codepoints are entirely drawn from this set classifies as
    /// `.control` (D-105 cluster kind) ، dropped from renderable children
    /// downstream, retained in the cluster table.
    public static let controlFormatters: Set<UInt32> = [
        0x200B,   // ZERO WIDTH SPACE (defensive; not Arabic-specific but harmless to exclude)
        0x200C,   // ZERO WIDTH NON-JOINER (ZWNJ)
        0x200D,   // ZERO WIDTH JOINER (ZWJ)
        0x200E,   // LEFT-TO-RIGHT MARK
        0x200F,   // RIGHT-TO-LEFT MARK
        0x061C,   // ARABIC LETTER MARK
        0x202A, 0x202B, 0x202C, 0x202D, 0x202E,   // LRE/RLE/PDF/LRO/RLO
        0x2066, 0x2067, 0x2068, 0x2069,           // LRI/RLI/FSI/PDI
    ]

    // MARK: - Queries

    /// Whether `scalar` is a combining mark for D-105 purposes: explicit
    /// range membership (minus the documented spacing-sign exceptions),
    /// falling back to `generalCategory ∈ {nonspacingMark, enclosingMark}`
    /// for any other Mn/Me scalar the explicit ranges don't name.
    public static func isMark(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        if quranicNonMarkExceptions.contains(value) { return false }
        if honorifics.contains(value) { return true }
        if harakatBlock.contains(value) { return true }
        if value == superscriptAlef { return true }
        if quranicAnnotations.contains(value) { return true }
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark: return true
        default: return false
        }
    }

    /// Classifies a mark scalar into MKModel's `MKMarkClass` (the field
    /// `MKMarkNode.markClass` stores at derivation). Returns `nil` for
    /// non-mark scalars.
    public static func classify(_ scalar: Unicode.Scalar) -> MKMarkClass? {
        guard isMark(scalar) else { return nil }
        let value = scalar.value
        if honorifics.contains(value) || quranicAnnotations.contains(value) {
            return .quranicAnnotation
        }
        if harakatBlock.contains(value) || value == superscriptAlef {
            return .tashkeel
        }
        return .otherCombining
    }

    /// Whether `scalar` is a ZWJ/ZWNJ/bidi-control formatting character
    /// (D-105 `.control` cluster kind).
    public static func isControlFormatter(_ scalar: Unicode.Scalar) -> Bool {
        controlFormatters.contains(scalar.value)
    }
}
