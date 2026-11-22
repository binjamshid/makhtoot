import Foundation
import MKModel

/// Unicode joining types for cursive-script shaping analysis (WS-03 packet
/// §5 task 10: "look up joining type ... from a bundled table (derived from
/// Unicode ArabicShaping semantics ، encode the table in Swift, cite UCD in
/// comments, no runtime file)").
///
/// Source: Unicode Character Database, `ArabicShaping.txt` (UCD 15/16 ،
/// the Arabic-block assignments below are stable across recent versions).
/// Coverage (C8-1): the Arabic block U+0600–06FF **plus** Arabic Supplement
/// U+0750–077F, Arabic Extended-B U+0870–089F and Arabic Extended-A
/// U+08A0–08FF ، the extended blocks were transcribed from ArabicShaping.txt
/// 16.0.0 and cross-checked against `extracted/DerivedJoiningType.txt`
/// (parity is enforced by `JoiningTypeUCDParityTests`), plus the Unicode
/// 17.0.0 addition U+088F NOON WITH RING ABOVE (`D`).
/// Categories (UAX #9 / UCD terminology):
/// - `D`  Dual_Joining ، joins on both sides (ب ت ث ج ح خ س ش …).
/// - `R`  Right_Joining ، joins only to the preceding letter (ا د ذ ر ز و …).
/// - `C`  Join_Causing ، makes neighbors join without joining itself
///        visually (U+0640 TATWEEL, U+200D ZWJ).
/// - `U`  Non_Joining ، never joins (U+0621 ء, U+200C ZWNJ, …).
/// - `T`  Transparent ، invisible to joining (combining marks Mn/Me and
///        most Cf format controls other than ZWJ/ZWNJ).
public enum MKJoiningType: Hashable, Sendable {
    case dual
    case rightJoining
    case joinCausing
    case nonJoining
    case transparent
}

public enum MKJoiningTypeTable {
    // UCD ArabicShaping.txt, Right_Joining (R) entries for the Arabic
    // block (U+0600–06FF), Arabic Supplement (U+0750–077F), Arabic
    // Extended-B (U+0870–089F) and Arabic Extended-A (U+08A0–08FF).
    // C8-1: the three extended blocks were previously untranscribed, so
    // ~120 genuine letters fell through to the default `U` clause below
    // and mis-shaped; ranges now mirror DerivedJoiningType.txt exactly.
    private static let rightJoining: [ClosedRange<UInt32>] = [
        0x0622...0x0625,   // آ أ ؤ إ (alef madda/hamza forms; 0624 waw-hamza)
        0x0627...0x0627,   // ا alef
        0x0629...0x0629,   // ة teh marbuta
        0x062F...0x0632,   // د ذ ر ز
        0x0648...0x0648,   // و waw
        0x0671...0x0673,   // ٱ alef wasla + wavy-hamza alefs
        0x0675...0x0677,   // high-hamza alef/waw/u
        0x0688...0x0699,   // ڈ..ڙ (dal/reh extensions incl. ژ U+0698)
        0x06C0...0x06C0,   // ۀ heh with yeh above
        0x06C3...0x06CB,   // ۃ..ۋ (teh marbuta goal, waw variants)
        0x06CD...0x06CD,   // ۍ yeh with tail
        0x06CF...0x06CF,   // ۏ waw with dot above
        0x06D2...0x06D3,   // ے ۓ yeh barree
        0x06D5...0x06D5,   // ە ae
        0x06EE...0x06EF,   // ڮ‑style dal/reh with inverted V
        // Arabic Supplement (C8-1), UCD R entries:
        0x0759...0x075B,   // ݙ ݚ dal extensions + ݛ reh with stroke
        0x076B...0x076C,   // ݫ ݬ reh with two dots above / with hamza
        0x0771...0x0771,   // ݱ reh with small tah and two dots
        0x0773...0x0774,   // ݳ ݴ alef with extended digit two/three above
        0x0778...0x0779,   // ݸ ݹ waw with extended digit two/three above
        // Arabic Extended-B (C8-1): Qur'anic attached-vowel alef variants
        // plus the vertical tail.
        0x0870...0x0882,   // ࡰ..ࢂ alef with attached fatha .. right hamza
        0x088E...0x088E,   // ࢎ vertical tail (UCD `R`, joining group VERTICAL TAIL)
        // Arabic Extended-A (C8-1), UCD R entries:
        0x08AA...0x08AC,   // ࢪ ࢫ ࢬ reh with loop, waw with dot within, rohingya yeh
        0x08AE...0x08AE,   // ࢮ dal with three dots below
        0x08B1...0x08B2,   // ࢱ ࢲ straight waw, zain with inverted V above
        0x08B9...0x08B9,   // ࢹ reh with small noon above
    ]

    // Join_Causing (C): tatweel + ZWJ, plus the Arabic Extended-B
    // tatweel-with-overstruck-mark letters U+0883–0885 which UCD also
    // classes `C` (C8-1).
    private static let joinCausing: Set<UInt32> = [
        0x0640, 0x200D,
        0x0883, 0x0884, 0x0885,   // ࢃ ࢄ ࢅ tatweel with overstruck hamza/waw/two dots
    ]

    // Non_Joining (U) within the Arabic blocks (everything non-Arabic is
    // also non-joining by the default clause below): hamza, high-hamza,
    // Arabic full stop, plus ZWNJ; extended-block additions per C8-1:
    // U+0887 baseline round dot and U+08AD low alef are `U` letters, and
    // the prepended concatenation signs (U+0600–0605 number/sanah/… signs,
    // U+06DD end of ayah, U+0890–0891 pound/piastre marks, U+08E2 disputed
    // end of ayah) are `Cf` yet normatively `U` in ArabicShaping.txt ، they
    // must *break* joining, so they are listed here ahead of the generic
    // `.format → T` fallback below.
    private static let nonJoining: Set<UInt32> = [
        0x0621, 0x0674, 0x06D4, 0x200C,
        0x0887, 0x08AD,
        0x0600, 0x0601, 0x0602, 0x0603, 0x0604, 0x0605,
        0x06DD, 0x0890, 0x0891, 0x08E2,
    ]

    // Dual_Joining (D): the remaining Arabic letters (incl. the three
    // extended blocks per C8-1). UCD ranges:
    private static let dualJoining: [ClosedRange<UInt32>] = [
        0x0620...0x0620,   // ؠ kashmiri yeh
        0x0626...0x0626,   // ئ yeh-hamza
        0x0628...0x0628,   // ب
        0x062A...0x062E,   // ت ث ج ح خ
        0x0633...0x063F,   // س ش ص ض ط ظ ع غ + 063B..063F keheh/farsi-yeh variants
        0x0641...0x0647,   // ف ق ك ل م ن ه
        0x0649...0x064A,   // ى ي
        0x066E...0x066F,   // dotless beh/qaf
        0x0678...0x0687,   // yeh/teh/hah extensions incl. پ U+067E چ U+0686
        0x069A...0x06BF,   // seen/sad/gaf extensions incl. ک U+06A9 گ U+06AF
        0x06C1...0x06C2,   // ہ ۂ heh goal
        0x06CC...0x06CC,   // ی farsi yeh
        0x06CE...0x06CE,   // ێ yeh with small v
        0x06D0...0x06D1,   // ې ۑ
        0x06FA...0x06FC,   // sheen/dad/ghain with dot below
        0x06FF...0x06FF,   // ھ heh with inverted v
        // Arabic Supplement (C8-1), UCD D entries:
        0x0750...0x0758,   // ݐ..ݘ beh/hah extensions
        0x075C...0x076A,   // ݜ..ݪ seen/ain/feh/keheh/meem/noon/lam extensions
        0x076D...0x0770,   // ݭ..ݰ seen/hah with small tah variants
        0x0772...0x0772,   // ݲ hah with small tah above
        0x0775...0x0777,   // ݵ..ݷ farsi yeh with extended digits
        0x077A...0x077F,   // ݺ..ݿ yeh barree/hah/seen/kaf extensions
        // Arabic Extended-B (C8-1), UCD D entries:
        0x0886...0x0886,   // ࢆ thin yeh
        0x0889...0x088D,   // ࢉ..ࢍ noon/hah/tah/keheh extensions (088E is `R`, above)
        0x088F...0x088F,   // noon with ring above ، Unicode 17.0 addition, `D`
                           // per ArabicShaping.txt 17.0.0 (verified against the
                           // OS ICU, Unicode 17.0.0) ، unassigned before 17.0,
                           // so absent from the 16.0.0 transcription (C8-1)
        // Arabic Extended-A (C8-1), UCD D entries:
        0x08A0...0x08A9,   // ࢠ..ࢩ beh/jeem/tah/feh/qaf/lam/meem/yeh extensions
        0x08AF...0x08B0,   // ࢯ ࢰ sad three dots below, gaf inverted stroke
        0x08B3...0x08B8,   // ࢳ..ࢸ ain/kaf/qaf/beh/peh/teh extensions
        0x08BA...0x08C8,   // ࢺ..ࣈ yeh..graf incl. african feh/qaf/noon
    ]

    /// The joining type of `scalar`. Marks (Mn/Me per `MKMarkClassifier`)
    /// and format controls other than ZWJ/ZWNJ are `T` (transparent);
    /// anything not otherwise listed is `U` (non-joining) ، the UCD default
    /// for unlisted codepoints.
    public static func joiningType(of scalar: Unicode.Scalar) -> MKJoiningType {
        let v = scalar.value
        if joinCausing.contains(v) { return .joinCausing }
        if nonJoining.contains(v) { return .nonJoining }
        if MKMarkClassifier.isMark(scalar) { return .transparent }
        if scalar.properties.generalCategory == .format { return .transparent }
        if rightJoining.contains(where: { $0.contains(v) }) { return .rightJoining }
        if dualJoining.contains(where: { $0.contains(v) }) { return .dual }
        return .nonJoining
    }

    /// The set of contextual forms a letter of this joining type can
    /// actually realize (T-TXT-6's "form selector metadata": right-joining
    /// letters expose only {isolated, final}). Non-joining and
    /// non-letter types expose only {isolated}.
    public static func validForms(for scalar: Unicode.Scalar) -> Set<MKJoiningForm> {
        switch joiningType(of: scalar) {
        case .dual:
            return [.isolated, .initial, .medial, .final]
        case .rightJoining:
            return [.isolated, .final]
        case .joinCausing, .nonJoining, .transparent:
            return [.isolated]
        }
    }
}
