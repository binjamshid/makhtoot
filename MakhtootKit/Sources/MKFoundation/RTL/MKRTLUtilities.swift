import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// RTL / Arabic-script helpers shared by every module that touches text
/// direction, digit display, or layout mirroring.
///
/// Detection-only note (D-103): the Unicode *presentation-form* ranges
/// (U+FB50–FDFF, U+FE70–FEFF) appear below strictly so this file can
/// recognize already-composed presentation-form text if it is ever
/// encountered (e.g. pasted from another app). MakhtootKit itself never
/// *produces* presentation-form codepoints for rendering ، shaping always
/// goes through Core Text (D-103). This is the one sanctioned mention of
/// those ranges app-wide.
public enum MKRTLUtilities {

    // MARK: - Arabic-script detection

    /// Unicode scalar ranges that count as "Arabic script" for direction
    /// probing purposes.
    private static let arabicRanges: [ClosedRange<UInt32>] = [
        0x0600...0x06FF,   // Arabic
        0x0750...0x077F,   // Arabic Supplement
        0x0870...0x089F,   // Arabic Extended-B (C8-1: was missing ، letters
                           // there fell out of Arabic-script detection)
        0x08A0...0x08FF,   // Arabic Extended-A
        0xFB50...0xFDFF,   // Arabic Presentation Forms-A (detection only)
        0xFE70...0xFEFF,   // Arabic Presentation Forms-B (detection only)
    ]

    /// Whether `scalar` is a **strong-RTL** Arabic-script character
    /// (including presentation-form ranges, for detection of foreign
    /// input only ، see the type-level note above).
    ///
    /// C8-3: Arabic-Indic digits (U+0660–0669 / U+06F0–06F9) fall inside
    /// the Arabic block but carry bidi class AN ، a *weak* direction ، so
    /// this predicate excludes them itself instead of relying on every
    /// caller to guard them out the way `baseDirection(of:)` already did.
    /// The predicate therefore means "strong-RTL Arabic letter/mark", not
    /// "codepoint inside an Arabic Unicode block".
    public static func isRTLCharacter(_ scalar: Unicode.Scalar) -> Bool {
        if isArabicDigit(scalar) { return false }
        return arabicRanges.contains { $0.contains(scalar.value) }
    }

    /// Convenience overload for a single-character `Character`.
    public static func isRTLCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { isRTLCharacter($0) }
    }

    // MARK: - Base direction (first-strong heuristic)

    public enum BaseDirection: Sendable, Equatable {
        case rightToLeft
        case leftToRight
        /// No strongly-directional character was found (digits/punctuation/
        /// whitespace only, or empty string).
        case neutral
    }

    /// Arabic-Indic (U+0660–0669) and Extended Arabic-Indic (U+06F0–06F9)
    /// digit ranges. Per the Unicode Bidirectional Algorithm these carry
    /// bidi class AN/EN (Arabic/European Number) ، a **weak**, not strong,
    /// direction ، so a run of digits alone must not decide base direction
    /// even though the codepoints fall inside the Arabic Unicode block.
    private static let arabicDigitRanges: [ClosedRange<UInt32>] = [
        0x0660...0x0669,
        0x06F0...0x06F9,
    ]

    private static func isArabicDigit(_ scalar: Unicode.Scalar) -> Bool {
        arabicDigitRanges.contains { $0.contains(scalar.value) }
    }

    /// A lightweight first-strong-character heuristic: scans `string` for
    /// the first character with the Unicode Bidi_Class of a strong
    /// left-to-right or right-to-left character and returns its direction.
    /// Digits (Arabic-Indic or Latin) and punctuation are weak/neutral and
    /// are skipped, matching the Unicode Bidirectional Algorithm's
    /// first-strong-character rule (P2/P3) ، this is sufficient for
    /// Makhtoot's Arabic-only (D-100) UI without pulling in a full bidi
    /// implementation (shaping-level bidi is Core Text's job, D-103/D-109;
    /// this heuristic is only for UI-shell-level direction probing, e.g.
    /// search field placeholder alignment).
    public static func baseDirection(of string: String) -> BaseDirection {
        guard !string.isEmpty else { return .neutral }
        for scalar in string.unicodeScalars {
            if isArabicDigit(scalar) {
                continue
            }
            if isRTLCharacter(scalar) {
                return .rightToLeft
            }
            if CharacterSet.letters.contains(scalar) {
                // A "letter" that isn't in an Arabic range, in an
                // Arabic-only app, is treated as the LTR case (e.g. Latin
                // brand names mixed into Arabic copy).
                return .leftToRight
            }
        }
        return .neutral
    }

    #if canImport(UIKit)
    /// Maps a `BaseDirection` to the `UISemanticContentAttribute` a host
    /// UIKit view should adopt. Per WS-01 packet §5 task 16, the app does
    /// NOT force RTL via `semanticContentAttribute` overrides globally ،
    /// this helper exists for the rare UIKit host view (e.g. the canvas,
    /// WS-06) that needs to mirror a specific piece of mixed-direction
    /// content rather than relying on the `ar` locale's natural RTL flow.
    public static func semanticContentAttribute(for direction: BaseDirection) -> UISemanticContentAttribute {
        switch direction {
        case .rightToLeft: return .forceRightToLeft
        case .leftToRight: return .forceLeftToRight
        case .neutral: return .unspecified
        }
    }
    #endif

    // MARK: - Bidi isolation (N8-2)

    /// Wraps `value` in FSI (U+2068) / PDI (U+2069) ، the UAX #9 explicit
    /// *isolate* formatting characters ، so an interpolated fragment that
    /// may carry a Latin-script or weakly-directional run (font file
    /// names, project titles, record counters) resolves its direction in
    /// isolation instead of leaking into, or being reordered by, the
    /// surrounding Arabic sentence. Use this at every interpolation site
    /// where the inserted value is not guaranteed Arabic-script (N8-2).
    public static func isolated(_ value: String) -> String {
        "\u{2068}" + value + "\u{2069}"
    }

    // MARK: - Arabic-Indic digit conversion

    /// Arabic-Indic digits ٠١٢٣٤٥٦٧٨٩ (Latin gloss: Arabic-Indic zero
    /// through nine), indexed 0...9 to match their Latin equivalents.
    private static let arabicIndicDigits: [Character] = Array("٠١٢٣٤٥٦٧٨٩")
    private static let latinDigits: [Character] = Array("0123456789")

    /// Converts every Latin digit `0`–`9` in `string` to its Arabic-Indic
    /// equivalent. Non-digit characters pass through unchanged.
    public static func toArabicIndicDigits(_ string: String) -> String {
        String(string.map { char in
            if let index = latinDigits.firstIndex(of: char) {
                return arabicIndicDigits[index]
            }
            return char
        })
    }

    /// Converts every Arabic-Indic digit ٠–٩ in `string` to its Latin
    /// equivalent. Non-digit characters pass through unchanged. This is
    /// the normalization path numeric inspector fields use so `١٢٣` and
    /// `123` are equivalent input (WS-01 packet §6).
    public static func toLatinDigits(_ string: String) -> String {
        String(string.map { char in
            if let index = arabicIndicDigits.firstIndex(of: char) {
                return latinDigits[index]
            }
            return char
        })
    }

    /// Whether every digit character in `string` (if any) is Arabic-Indic,
    /// Latin, or the string has no digits at all ، i.e. `string` is not a
    /// mix of both digit systems. Useful for input validation.
    public static func hasConsistentDigitSystem(_ string: String) -> Bool {
        var sawArabicIndic = false
        var sawLatin = false
        for char in string {
            if arabicIndicDigits.contains(char) { sawArabicIndic = true }
            if latinDigits.contains(char) { sawLatin = true }
        }
        return !(sawArabicIndic && sawLatin)
    }
}
