import CoreGraphics
import CoreText
import MKFoundation
import MKModel
@testable import MKTextEngine

/// Canonical Arabic fixture strings, reused verbatim across this test
/// target per WS-03 packet §6 ("reuse verbatim in tests") and
/// TEST_MATRIX.md §5 (T-TXT-2/3/4/9).
///
/// Fonts: cluster/bidi/mark fixtures shape against `SystemFontStubProvider`
/// (system SF Arabic ، the P0 seam, DEPENDENCY_GRAPH stub S2). The D-107
/// form-resolver fixtures use **Geeza Pro** via `NamedFontProvider`,
/// because the system SF font does not honor a *leading* ZWJ (documented
/// per-font finding, docs/impl-log/WS-03.md) while Geeza Pro ، bundled on
/// both macOS and iOS ، implements the full joining feature set the D-107
/// harvest depends on. The WS-09 fixture re-run replaces this with
/// Amiri/Noto Naskh across the whole suite (stub S2 flip).
enum Fixtures {
    static let engine = MKShapingEngine()

    static func style(size: Double = 36, direction: MKBaseDirection = .rightToLeft, ligatures: MKLigatureSetting = .standard) -> MKTextStyle {
        MKTextStyle(
            font: .systemFallback,
            pointSize: size,
            ligatureSetting: ligatures,
            baseDirection: direction)
    }

    static func shape(_ text: String, size: Double = 36, direction: MKBaseDirection = .rightToLeft) -> MKShapedLine {
        engine.shapeSingleLine(MKShapingRequest(string: text, style: style(size: size, direction: direction)))
    }

    // MARK: - Named-font path (Geeza Pro for D-107 harvests)

    /// Resolves the handle's PostScript name literally ، the test-side
    /// `MKFontProviding` conformer that lets D-107 fixtures run against a
    /// real Arabic font before WS-09's registry exists. Production wiring
    /// never uses this type.
    struct NamedFontProvider: MKFontProviding {
        func resolve(_ handle: MKFontHandle) -> CTFont {
            CTFontCreateWithName(handle.postScriptName as CFString, handle.pointSize, nil)
        }
    }

    static let geezaProName = "GeezaPro"

    static func geezaStyle(size: Double = 36) -> MKTextStyle {
        MKTextStyle(font: .system(postScriptName: geezaProName), pointSize: size)
    }

    static let geezaEngine = MKShapingEngine(fonts: NamedFontProvider())

    static func shapeGeeza(_ text: String, size: Double = 36) -> MKShapedLine {
        geezaEngine.shapeSingleLine(MKShapingRequest(string: text, style: geezaStyle(size: size)))
    }

    // MARK: - §6 fixture set

    /// Required-ligature family (لا لأ لإ لآ) ، never two separate glyphs.
    static let lamAlifFamily = ["لا", "لأ", "لإ", "لآ"]

    /// lam-lam-ha word ، per-font capture expectations documented, not
    /// hardcoded (§6 "الله").
    static let allah = "الله"

    /// Full tashkeel stack (damma, fatha, shadda, fatha, tanwin).
    static let muhammadTashkeel = "مُحَمَّدٌ"

    /// shadda + fatha/tanwin stack fixture named explicitly in the packet.
    static let shaddaStack = "شَدَّةٌ"

    /// lam-alif family embedded in a full sentence (T-TXT-2 fixture).
    static let laIlahaIllaAllah = "لا إله إلا الله"

    /// Qur'anic marks fixture: small high rounded zero (U+06E1, Qur'anic
    /// annotation subrange) + wasla (U+0671, a LETTER, not a mark).
    static let bismillahWasla = "بِسۡمِ ٱللَّهِ"

    /// Mixed Arabic + Western-digit fixture (T-TXT-3/9).
    static let mixedWesternDigits = "عام 2026"

    /// Mixed Arabic + Arabic-Indic-digit fixture (§6 "mixed bidi").
    static let mixedArabicIndicDigits = "عام ٢٠٢٦ ميلادي"

    /// Latin brand name embedded in Arabic (§6 "mixed bidi").
    static let brandMixed = "Makhtoot مخطوط"

    /// Kashida (tatweel, U+0640) fixture.
    static let kashidaChain = "مـحـمـد"

    /// ZWNJ-broken join fixture (§6 "می" vs "م‌ي").
    static let zwnjJoined = "می"
    static let zwnjBroken = "م\u{200C}ي"

    /// Degenerate input: a lone combining mark with nothing preceding it
    /// (task 11 / task 8 "free mark" case).
    static let standaloneFathatan = "\u{064B}"
}
