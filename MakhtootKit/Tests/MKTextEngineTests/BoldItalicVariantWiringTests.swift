import CoreText
import Foundation
import MKFoundation
import MKModel
import Testing
@testable import MKTextEngine

/// Phase A wiring test (Step 3): `MKShapingEngine.resolvedFont(for:)` must
/// call the variant-aware `MKFontProviding.resolve(_:variant:)` overload
/// with `MKFontVariantRequest(bold: style.isBold, italic: style.isItalic)`,
/// and the resolved font must be what gets captured into
/// `MKShapedRun.font` (`MKShapingEngine.capture`) ، NOT re-derived
/// downstream. `MKTextEngineTests` doesn't depend on `MKFonts` (only
/// `MKTextEngine`, per `Package.swift`), so real per-family variant
/// RESOLUTION LOGIC is covered in `MKFontsTests` against the real catalog
/// (`MKFontVariantResolutionTests.swift`); this suite only proves the
/// wiring itself, against real system fonts already used elsewhere in this
/// target (`Fixtures.geezaProName` = "GeezaPro", bundled on macOS/iOS,
/// which genuinely ships a "GeezaPro-Bold" static cut ، confirmed via
/// `fontTools` inspection of `/System/Library/Fonts/GeezaPro.ttc` during
/// this work, not merely assumed).
@Suite("MKShapingEngine variant-aware resolve(_:variant:) wiring")
struct BoldItalicVariantWiringTests {
    /// A test-local `MKFontProviding` conformer that performs real
    /// symbolic-trait resolution directly (mirrors, but does not call,
    /// `MKRegistryFontProvider` ، `MKFonts` is not a dependency of this
    /// test target). Exists solely to prove `MKShapingEngine` reaches the
    /// variant-aware overload rather than the plain one.
    private struct VariantAwareNamedFontProvider: MKFontProviding {
        func resolve(_ handle: MKFontHandle) -> CTFont {
            CTFontCreateWithName(handle.postScriptName as CFString, handle.pointSize, nil)
        }

        func resolve(_ handle: MKFontHandle, variant: MKFontVariantRequest) -> CTFont {
            let base = resolve(handle)
            guard variant.bold else { return base }
            // Real cut or nothing: never synthesize.
            return CTFontCreateCopyWithSymbolicTraits(base, 0, nil, [.traitBold], [.traitBold]) ?? base
        }
    }

    private static let engine = MKShapingEngine(fonts: VariantAwareNamedFontProvider())

    @Test func isBoldTrueVsFalseYieldsDifferentResolvedRunPostScriptNameForGeezaPro() {
        let regularStyle = MKTextStyle(font: .system(postScriptName: Fixtures.geezaProName), pointSize: 36, isBold: false)
        let boldStyle = MKTextStyle(font: .system(postScriptName: Fixtures.geezaProName), pointSize: 36, isBold: true)

        let regularLine = Self.engine.shapeSingleLine(MKShapingRequest(string: Fixtures.allah, style: regularStyle))
        let boldLine = Self.engine.shapeSingleLine(MKShapingRequest(string: Fixtures.allah, style: boldStyle))

        let regularPS = regularLine.runs.first?.font.postScriptName
        let boldPS = boldLine.runs.first?.font.postScriptName
        #expect(regularPS == "GeezaPro")
        #expect(boldPS == "GeezaPro-Bold", "GeezaPro genuinely ships a Bold static cut ، isBold must resolve to it")
        #expect(regularPS != boldPS)
    }

    @Test func isBoldTrueIsIdenticalToFalseForASingleFaceFamily() {
        // KufiStandardGK ships exactly one style (Regular, confirmed via
        // `fc-list`) ، no Bold sibling exists in its family, so
        // `CTFontCreateCopyWithSymbolicTraits` must return nil and the
        // provider must fall through to the SAME (unresolved) font,
        // never synthesizing a fake bold.
        let regularStyle = MKTextStyle(font: .system(postScriptName: "KufiStandardGK"), pointSize: 36, isBold: false)
        let boldStyle = MKTextStyle(font: .system(postScriptName: "KufiStandardGK"), pointSize: 36, isBold: true)

        let regularLine = Self.engine.shapeSingleLine(MKShapingRequest(string: Fixtures.allah, style: regularStyle))
        let boldLine = Self.engine.shapeSingleLine(MKShapingRequest(string: Fixtures.allah, style: boldStyle))

        let regularPS = regularLine.runs.first?.font.postScriptName
        let boldPS = boldLine.runs.first?.font.postScriptName
        #expect(regularPS == "KufiStandardGK")
        #expect(boldPS == regularPS, "single-face family: requesting bold must return the SAME font, never synthesized")
    }

    // MARK: - Step 4: MKFormResolver cache no longer collides bold/regular

    @Test func formResolverDoesNotCollideBoldAndRegularHarvests() async throws {
        let resolver = MKFormResolver(fonts: VariantAwareNamedFontProvider())
        let hah = Unicode.Scalar(0x062D)!   // ح
        let regularStyle = MKTextStyle(font: .system(postScriptName: Fixtures.geezaProName), pointSize: 36, isBold: false)
        let boldStyle = MKTextStyle(font: .system(postScriptName: Fixtures.geezaProName), pointSize: 36, isBold: true)

        let regular = try #require(await resolver.resolve(letter: hah, form: .isolated, style: regularStyle))
        let bold = try #require(await resolver.resolve(letter: hah, form: .isolated, style: boldStyle))

        // GeezaPro-Bold is a genuinely different font file from GeezaPro ،
        // its glyph-ID table and/or metrics for ح are extremely unlikely
        // to be byte-identical, so a distinguishable result here is strong
        // evidence the (isBold/isItalic-extended) cache key kept the two
        // harvests separate rather than colliding.
        #expect(
            regular.glyphID != bold.glyphID || regular.advance != bold.advance,
            "bold and regular harvests were indistinguishable ، suggests a cache-key collision")

        // Re-requesting regular after bold must still return the regular
        // result (not a stale hit from a collided key).
        let regularAgain = try #require(await resolver.resolve(letter: hah, form: .isolated, style: regularStyle))
        #expect(regularAgain.glyphID == regular.glyphID)
        #expect(regularAgain.advance == regular.advance)
    }
}
