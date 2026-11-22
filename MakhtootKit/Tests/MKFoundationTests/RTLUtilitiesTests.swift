import Testing
@testable import MKFoundation

/// WS-01 packet §5 task 6 accept criterion: fixture coverage for
/// "١٢٣" (Arabic-Indic digits), "123" (Latin digits), "مرحبا Hello"
/// (mixed Arabic/Latin ، Latin gloss: "hello Hello"), and the empty
/// string.
@Suite("MKRTLUtilities")
struct RTLUtilitiesTests {
    @Test func arabicIndicDigitsConvertToLatin() {
        #expect(MKRTLUtilities.toLatinDigits("١٢٣") == "123")
    }

    @Test func latinDigitsConvertToArabicIndic() {
        #expect(MKRTLUtilities.toArabicIndicDigits("123") == "١٢٣")
    }

    @Test func latinDigitsPassThroughLatinConversionUnchanged() {
        #expect(MKRTLUtilities.toLatinDigits("123") == "123")
    }

    @Test func mixedArabicLatinStringBaseDirectionIsRightToLeft() {
        // "مرحبا Hello" (Latin gloss: "hello Hello") ، first-strong
        // character is Arabic, so base direction is RTL even though Latin
        // text follows.
        #expect(MKRTLUtilities.baseDirection(of: "مرحبا Hello") == .rightToLeft)
    }

    @Test func emptyStringBaseDirectionIsNeutral() {
        #expect(MKRTLUtilities.baseDirection(of: "") == .neutral)
    }

    @Test func pureLatinStringBaseDirectionIsLeftToRight() {
        #expect(MKRTLUtilities.baseDirection(of: "Hello") == .leftToRight)
    }

    @Test func pureArabicIndicDigitStringHasNoStrongDirection() {
        // Digits alone carry no strong directionality under the
        // first-strong heuristic.
        #expect(MKRTLUtilities.baseDirection(of: "١٢٣") == .neutral)
    }

    @Test func consistentDigitSystemDetection() {
        #expect(MKRTLUtilities.hasConsistentDigitSystem("١٢٣"))
        #expect(MKRTLUtilities.hasConsistentDigitSystem("123"))
        #expect(MKRTLUtilities.hasConsistentDigitSystem(""))
        #expect(!MKRTLUtilities.hasConsistentDigitSystem("١2٣"))
    }

    @Test func isRTLCharacterRecognizesArabicRange() {
        #expect(MKRTLUtilities.isRTLCharacter(Character("م")))
        #expect(!MKRTLUtilities.isRTLCharacter(Character("H")))
    }

    @Test func isRTLCharacterExcludesArabicIndicDigits() {
        // C8-3: Arabic-Indic digits sit inside the Arabic block but carry
        // bidi class AN (weak) ، the strong-RTL predicate must reject them
        // itself, not rely on caller-side guards.
        #expect(!MKRTLUtilities.isRTLCharacter(Character("٣")))
        #expect(!MKRTLUtilities.isRTLCharacter(Character("۳")))   // U+06F3 Extended Arabic-Indic
    }

    @Test func isolatedWrapsValueInFSIAndPDI() {
        // N8-2: FSI (U+2068) / PDI (U+2069) around the fragment, content
        // untouched in between.
        #expect(MKRTLUtilities.isolated("Amiri") == "\u{2068}Amiri\u{2069}")
    }
}
