import Foundation
import Testing
@testable import MKModel

/// WS-02 packet §5 task 2 accept criterion: Codable round-trip; defaults
/// documented.
@Suite("MKTextStyle / MKFontRef")
struct MKTextStyleTests {
    @Test func defaultsMatchDocumentedValues() {
        let style = MKTextStyle.default
        // P2.6: this was `24` until commit `e5d5a65` deliberately raised
        // the shipped default to `36` ("Default text size raised from
        // 24pt to 36pt") without updating this assertion, leaving
        // `MKModelTests` red at 25/26 ever since. No documented source
        // anywhere in the repo backs `24` over `36` ، `36` is the actual,
        // deliberate shipped value (see `MKTextStyle.init`'s own doc
        // comment on `pointSize`), so this now matches it.
        #expect(style.pointSize == 36)
        #expect(style.tracking == 0)
        #expect(style.baselineShift == 0)
        #expect(style.lineHeightMultiple == 1.2)
        #expect(style.ligatureSetting == .standard)
        #expect(style.baseDirection == .rightToLeft) // D-109
        #expect(style.font == .systemFallback)
    }

    @Test func fullyPopulatedStyleRoundTripsThroughJSON() throws {
        let style = MKTextStyle(
            font: MKFontRef(fontID: "bundled.amiri.regular", postScriptName: "Amiri-Regular"),
            pointSize: 48,
            kerningOverrides: [MKKernOverride(clusterPairIndex: 2, value: -1.5)],
            tracking: 0.4,
            baselineShift: 3,
            lineHeightMultiple: 1.5,
            ligatureSetting: .discretionaryOn,
            baseDirection: .leftToRight,
            // Phase A: this test's name promised "fully populated" but
            // never actually set the five trait fields (they silently
            // rode on their `false`/`nil` defaults), so it never exercised
            // Codable round-tripping for `isBold`/`isItalic`/etc. at all.
            isBold: true,
            isItalic: true,
            isUnderline: true,
            isStrikethrough: true,
            highlightColor: MKSolidColor(r: 0.9, g: 0.8, b: 0.1, a: 0.5)
        )
        let data = try JSONEncoder().encode(style)
        let decoded = try JSONDecoder().decode(MKTextStyle.self, from: data)
        #expect(decoded == style)
        // Spell out each trait explicitly ، a future accidental default-
        // reversion in `Codable` synthesis (e.g. a hand-written
        // `init(from:)` that forgets a key) would still pass `decoded ==
        // style` if `Equatable` were ever hand-rolled to ignore a field,
        // so assert the values directly too.
        #expect(decoded.isBold == true)
        #expect(decoded.isItalic == true)
        #expect(decoded.isUnderline == true)
        #expect(decoded.isStrikethrough == true)
        #expect(decoded.highlightColor == MKSolidColor(r: 0.9, g: 0.8, b: 0.1, a: 0.5))
    }

    @Test func systemFallbackFontIDIsSyntheticAndNonOptional() {
        let ref = MKFontRef.system(postScriptName: ".SFArabic")
        #expect(ref.fontID == "system..SFArabic")
        #expect(ref.userImported == false)
    }
}
