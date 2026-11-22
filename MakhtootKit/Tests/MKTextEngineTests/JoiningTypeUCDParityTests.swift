import Testing
import MKModel
@testable import MKTextEngine

/// C8-1 parity suite: `MKJoiningTypeTable.joiningType(of:)` versus the
/// normative UCD `Joining_Type` (ArabicShaping.txt / DerivedJoiningType.txt).
/// The audit found the table stopped at U+06FF, so every genuine letter in
/// Arabic Supplement (U+0750–077F), Arabic Extended-B (U+0870–089F) and
/// Arabic Extended-A (U+08A0–08FF) fell through to the default `U` clause
/// (~120 letters silently mis-shaped). The three extended blocks are
/// asserted codepoint-by-codepoint against a hardcoded transcription of the
/// UCD values; the core Arabic block U+0600–06FF is spot-checked per class.
///
/// Deliberately out of scope: the non-Arabic script blocks inside
/// U+0600–08FF (Syriac, Thaana, NKo, Samaritan, Mandaic, Syriac
/// Supplement). Makhtoot is Arabic-only (FOUNDATION.md / D-100 scope) and
/// its joining table intentionally treats those scripts as non-joining, so
/// UCD parity is neither claimed nor tested for them.
@Suite struct JoiningTypeUCDParityTests {

    // MARK: - Normative expectations (UCD 16.0 ArabicShaping.txt)

    /// Hardcoded UCD `Joining_Type` for every codepoint the UCD explicitly
    /// assigns in the three extended blocks, up to and including the
    /// Unicode 17.0 addition U+088F NOON WITH RING ABOVE (`D` ، verified
    /// against the OS ICU, Unicode 17.0.0; the default-rule fallback below
    /// would have masked it as `U` on both sides). Codepoints *not* covered
    /// here (U+0892–0897) are checked by the UCD default rules instead (see
    /// `expectedType(for:)`) so the suite stays green across the OS's
    /// ICU/Unicode version drift ، e.g. U+0897 ARABIC PEPET (Mn, added in
    /// Unicode 16).
    private static let ucdExpected: [(ClosedRange<UInt32>, MKJoiningType)] = [
        // Arabic Supplement U+0750–077F ، fully assigned letters.
        (0x0750...0x0758, .dual),           // beh/hah extensions
        (0x0759...0x075B, .rightJoining),   // dal extensions, reh with stroke
        (0x075C...0x076A, .dual),           // seen/ain/feh/keheh/meem/noon/lam
        (0x076B...0x076C, .rightJoining),   // reh with two dots / with hamza
        (0x076D...0x0770, .dual),           // seen/hah with small tah
        (0x0771...0x0771, .rightJoining),   // reh with small tah and two dots
        (0x0772...0x0772, .dual),           // hah with small tah above
        (0x0773...0x0774, .rightJoining),   // alef with extended digits
        (0x0775...0x0777, .dual),           // farsi yeh with extended digits
        (0x0778...0x0779, .rightJoining),   // waw with extended digits
        (0x077A...0x077F, .dual),           // yeh barree/hah/seen/kaf extensions

        // Arabic Extended-B U+0870–089F.
        (0x0870...0x0882, .rightJoining),   // Qur'anic attached-vowel alefs
        (0x0883...0x0885, .joinCausing),    // tatweel with overstruck hamza/waw/dots
        (0x0886...0x0886, .dual),           // thin yeh
        (0x0887...0x0888, .nonJoining),     // baseline round dot (Lo, U), raised round dot (Sk)
        (0x0889...0x088D, .dual),           // noon/hah/tah/keheh extensions
        (0x088E...0x088E, .rightJoining),   // vertical tail ، UCD `R`, group VERTICAL TAIL
        (0x088F...0x088F, .dual),           // noon with ring above ، Unicode 17.0, `D`
        (0x0890...0x0891, .nonJoining),     // pound/piastre marks ، Cf yet normatively U
        (0x0898...0x089F, .transparent),    // Mn small high/low Qur'anic marks

        // Arabic Extended-A U+08A0–08FF.
        (0x08A0...0x08A9, .dual),           // beh/jeem/tah/feh/qaf/lam/meem/yeh extensions
        (0x08AA...0x08AC, .rightJoining),   // reh with loop, waw with dot within, rohingya yeh
        (0x08AD...0x08AD, .nonJoining),     // low alef ، a genuine U letter
        (0x08AE...0x08AE, .rightJoining),   // dal with three dots below
        (0x08AF...0x08B0, .dual),           // sad three dots below, gaf inverted stroke
        (0x08B1...0x08B2, .rightJoining),   // straight waw, zain with inverted V
        (0x08B3...0x08B8, .dual),           // ain/kaf/qaf/beh/peh/teh extensions
        (0x08B9...0x08B9, .rightJoining),   // reh with small noon above
        (0x08BA...0x08C8, .dual),           // yeh..graf incl. african feh/qaf/noon
        (0x08C9...0x08C9, .nonJoining),     // small farsi yeh ، Lm, unlisted in ArabicShaping.txt → default U
        (0x08CA...0x08E1, .transparent),    // Mn Qur'anic/tone marks
        (0x08E2...0x08E2, .nonJoining),     // disputed end of ayah ، Cf yet normatively U
        (0x08E3...0x08FF, .transparent),    // Mn tashkeel extensions
    ]

    /// The UCD expectation for `value`: the hardcoded table above when it
    /// covers the codepoint, otherwise the UCD default rules (`Mn`/`Me` →
    /// `T`, everything else including unassigned → `U`) so the assertion
    /// tracks whatever Unicode version the OS's tables ship.
    private func expectedType(for value: UInt32) -> MKJoiningType {
        for (range, type) in Self.ucdExpected where range.contains(value) {
            return type
        }
        guard let scalar = Unicode.Scalar(value) else { return .nonJoining }
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .enclosingMark: return .transparent
        default: return .nonJoining
        }
    }

    private func verify(block: ClosedRange<UInt32>) {
        for value in block {
            guard let scalar = Unicode.Scalar(value) else { continue }
            let actual = MKJoiningTypeTable.joiningType(of: scalar)
            let expected = expectedType(for: value)
            #expect(
                actual == expected,
                "U+\(String(value, radix: 16, uppercase: true)): table says \(actual), UCD says \(expected)"
            )
        }
    }

    // MARK: - Extended blocks: full codepoint-by-codepoint parity (C8-1)

    @Test func arabicSupplementMatchesUCD() {
        verify(block: 0x0750...0x077F)
    }

    @Test func arabicExtendedBMatchesUCD() {
        verify(block: 0x0870...0x089F)
    }

    @Test func arabicExtendedAMatchesUCD() {
        verify(block: 0x08A0...0x08FF)
    }

    // MARK: - Core Arabic block U+0600–06FF: per-class spot checks

    @Test func coreBlockRightJoiningSpotChecks() {
        for value: UInt32 in [0x0622, 0x0627, 0x0629, 0x062F, 0x0631, 0x0648, 0x0671, 0x06D2] {
            #expect(MKJoiningTypeTable.joiningType(of: Unicode.Scalar(value)!) == .rightJoining)
        }
    }

    @Test func coreBlockDualJoiningSpotChecks() {
        for value: UInt32 in [0x0628, 0x0633, 0x0645, 0x064A, 0x066E, 0x0686, 0x06A9, 0x06CC] {
            #expect(MKJoiningTypeTable.joiningType(of: Unicode.Scalar(value)!) == .dual)
        }
    }

    @Test func coreBlockJoinCausingAndTransparentSpotChecks() {
        #expect(MKJoiningTypeTable.joiningType(of: Unicode.Scalar(0x0640)!) == .joinCausing)   // tatweel
        #expect(MKJoiningTypeTable.joiningType(of: Unicode.Scalar(0x064E)!) == .transparent)   // fatha
        #expect(MKJoiningTypeTable.joiningType(of: Unicode.Scalar(0x0670)!) == .transparent)   // superscript alef
        #expect(MKJoiningTypeTable.joiningType(of: Unicode.Scalar(0x061C)!) == .transparent)   // ALM (Cf → T)
    }

    @Test func coreBlockNonJoiningSpotChecks() {
        // Letters/punctuation UCD assigns `U`, digits (default `U`), and ،
        // per the C8-1 fix ، the prepended concatenation signs (Cf yet
        // normatively `U`; joining must break across them, e.g. letters
        // must never join through U+06DD END OF AYAH).
        for value: UInt32 in [0x0621, 0x0674, 0x06D4, 0x061F, 0x0660, 0x06F0, 0x0600, 0x0605, 0x06DD] {
            #expect(
                MKJoiningTypeTable.joiningType(of: Unicode.Scalar(value)!) == .nonJoining,
                "U+\(String(value, radix: 16, uppercase: true)) must be non-joining"
            )
        }
    }

    // MARK: - Extended-block letters expose the right T-TXT-6 form sets

    @Test func extendedBlockValidFormsFollowJoiningType() {
        // ݙ (R) exposes {isolated, final}; ࢆ thin yeh (D) exposes all four;
        // tatweel-with-hamza (C) and baseline round dot (U) expose isolated.
        #expect(MKJoiningTypeTable.validForms(for: Unicode.Scalar(0x0759)!) == [.isolated, .final])
        #expect(MKJoiningTypeTable.validForms(for: Unicode.Scalar(0x0886)!) == [.isolated, .initial, .medial, .final])
        #expect(MKJoiningTypeTable.validForms(for: Unicode.Scalar(0x0883)!) == [.isolated])
        #expect(MKJoiningTypeTable.validForms(for: Unicode.Scalar(0x0887)!) == [.isolated])
    }
}
