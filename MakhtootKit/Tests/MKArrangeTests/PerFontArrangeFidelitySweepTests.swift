import Testing
import CoreGraphics
import CoreText
import Foundation
import MKArrange
import MKFoundation
import MKModel
import MKRender
import MKTextEngine

// Run-3 WS-04 P6 (packet's D-222 sweep instruction). D-222 (DECISIONS_LOG.md)
// requires every bundled font, at the moment it passes WS-09 license
// verification, to ALSO pass the arrange-fidelity block ، T-AR-31/32/33 plus
// the decompose/recompose round trip T-AR-36..38 ، not just the reduced
// T-AR-58 sweep (TEST_MATRIX.md §7.0/§7.9). This suite is the AUTOMATED
// FUNCTIONAL TWIN of that block (TEST_MATRIX's own words: "also automated
// as a pixel-diff FUNCTIONAL twin in MKArrange tests"), run across every
// font currently released into `Sources/MKFonts/Resources/catalog-seed.json`
// (20 as of this session ، see `docs/impl-log/WS-04.md` for the full
// per-font table this suite's own run produced). This satisfies the
// PENDING per-font gate at the automated-twin level; the full MANUAL-ARABIC
// human-visual sign-off for T-AR-31/32/33/36-38 remains a separate,
// not-yet-run gate ، same honest disposition WS-16 already recorded for the
// 5 cursive-attachment fonts ("automated_twin_pass_manual_visual_pending"
// in `Resources/LicenseRecords/records.json`).
//
// Per the task's explicit instruction, failures are RECORDED, not hidden:
// the derivation-fidelity check (T-AR-31 twin) is asserted for every font ،
// it tests this MODULE's own internal cross-drawer consistency (live vs.
// arranged render of the SAME captured glyphs), not font quality, so it is
// expected to hold universally; a real failure here would be a genuine
// MKArrange bug, not a font limitation, and must not be silently weakened.
// The decompose/recompose check (T-AR-36..38 twin) instead RECORDS each
// font's actual, honest outcome ، whether لا fuses into one ligature
// cluster at all (font-dependent, `ArrangeDeriverTests`' own "do not
// hardcode glyph counts; assert relations" precedent), and whether the
// fidelity fit lands inside or outside the D-221 clamp (both are
// legitimate, non-error outcomes per WS04-A1's own real-font finding on
// Geeza Pro) ، never asserting a specific font-dependent outcome as if it
// were a correctness requirement, only that decompose/recompose completes
// and round-trips when it does apply.
@Suite struct PerFontArrangeFidelitySweepTests {
    private let fidelityTolerance = 0.005   // 0.5%, D-106/packet-normative ، see DerivationFidelityTests

    struct FontFixture: Sendable, CustomStringConvertible {
        let fontID: String
        let familyDir: String
        let fileName: String
        var description: String { fontID }
    }

    /// Every font in `Sources/MKFonts/Resources/catalog-seed.json` as of
    /// this session (20 ، confirmed by direct inspection, see
    /// `docs/impl-log/WS-04.md`). `(familyDir, fileName)` mirror
    /// `Resources/Fonts/<Family>/<file>.ttf` exactly; the REGULAR-weight
    /// face is used for every family (matching this target's existing
    /// `ArrangeFixtures`/`WS16Fixtures` convention of testing one
    /// representative face per family, not every weight).
    static let releasedFonts: [FontFixture] = [
        FontFixture(fontID: "almarai", familyDir: "Almarai", fileName: "Almarai-Regular.ttf"),
        FontFixture(fontID: "amiri", familyDir: "Amiri", fileName: "Amiri-Regular.ttf"),
        FontFixture(fontID: "amiri-quran", familyDir: "AmiriQuran", fileName: "AmiriQuran-Regular.ttf"),
        FontFixture(fontID: "aref-ruqaa", familyDir: "ArefRuqaa", fileName: "ArefRuqaa-Regular.ttf"),
        FontFixture(fontID: "el-messiri", familyDir: "ElMessiri", fileName: "ElMessiri[wght].ttf"),
        FontFixture(fontID: "harmattan", familyDir: "Harmattan", fileName: "Harmattan-Regular.ttf"),
        FontFixture(fontID: "jomhuria", familyDir: "Jomhuria", fileName: "Jomhuria-Regular.ttf"),
        FontFixture(fontID: "katibeh", familyDir: "Katibeh", fileName: "Katibeh-Regular.ttf"),
        FontFixture(fontID: "lateef", familyDir: "Lateef", fileName: "Lateef-Regular.ttf"),
        FontFixture(fontID: "mada", familyDir: "Mada", fileName: "Mada[wght].ttf"),
        FontFixture(fontID: "markazi-text", familyDir: "MarkaziText", fileName: "MarkaziText[wght].ttf"),
        FontFixture(fontID: "mirza", familyDir: "Mirza", fileName: "Mirza-Regular.ttf"),
        FontFixture(fontID: "noto-kufi-arabic", familyDir: "NotoKufiArabic", fileName: "NotoKufiArabic[wght].ttf"),
        FontFixture(fontID: "noto-naskh-arabic", familyDir: "NotoNaskhArabic", fileName: "NotoNaskhArabic[wght].ttf"),
        FontFixture(fontID: "noto-sans-arabic", familyDir: "NotoSansArabic", fileName: "NotoSansArabic[wdth,wght].ttf"),
        FontFixture(fontID: "qahiri", familyDir: "Qahiri", fileName: "Qahiri-Regular.ttf"),
        FontFixture(fontID: "rakkas", familyDir: "Rakkas", fileName: "Rakkas-Regular.ttf"),
        FontFixture(fontID: "reem-kufi", familyDir: "ReemKufi", fileName: "ReemKufi[wght].ttf"),
        FontFixture(fontID: "scheherazade-new", familyDir: "ScheherazadeNew", fileName: "ScheherazadeNew-Regular.ttf"),
        FontFixture(fontID: "tajawal", familyDir: "Tajawal", fileName: "Tajawal-Regular.ttf"),
    ]

    struct NamedFontProvider: MKFontProviding {
        let postScriptName: String
        func resolve(_ handle: MKFontHandle) -> CTFont {
            CTFontCreateWithName(postScriptName as CFString, handle.pointSize, nil)
        }
    }

    private static var fontsRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PerFontArrangeFidelitySweepTests.swift
            .deletingLastPathComponent()   // MKArrangeTests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("Sources/MKFonts/Resources/Fonts")
    }

    /// Registers `fixture`'s font file by URL and resolves its REAL
    /// PostScript name ، NOT assumed from the filename, since several
    /// released fonts are variable fonts (e.g. `ElMessiri[wght].ttf`,
    /// `Mada[wght].ttf`) whose PostScript name does not match the filename
    /// stem. Uses `CTFontManagerCreateFontDescriptorsFromURL` (not a guess)
    /// to read the font's own default-instance PostScript name.
    static func registerAndResolvePostScriptName(_ fixture: FontFixture) -> String? {
        let url = fontsRoot.appendingPathComponent(fixture.familyDir).appendingPathComponent(fixture.fileName)
        var registerErr: Unmanaged<CFError>?
        _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registerErr)
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let first = descriptors.first
        else { return nil }
        let font = CTFontCreateWithFontDescriptor(first, 0, nil)
        return (CTFontCopyPostScriptName(font) as String)
    }

    // MARK: - T-AR-31 automated functional twin (derivation fidelity)

    @Test(arguments: releasedFonts)
    func derivationFidelityHoldsAcrossReleasedFonts(_ fixture: FontFixture) async {
        guard let ps = Self.registerAndResolvePostScriptName(fixture) else {
            Issue.record("[\(fixture.fontID)] could not register/resolve PostScript name from \(fixture.fileName)")
            return
        }
        let fonts = NamedFontProvider(postScriptName: ps)
        let style = MKTextStyle(font: .system(postScriptName: ps), pointSize: 36, lineHeightMultiple: 1.2)
        let text = "لا"
        let paintStyle = MKStyle(fill: .solid(.defaultInk))
        let core = MKNodeCore(name: "text", transform: MKTransform2D(position: CGPoint(x: 20, y: 60)), style: paintStyle)
        let canvasSize = CGSize(width: 300, height: 160)

        let liveNode = MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style)
        let liveScene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.liveText(liveNode)])

        let service = MKShapingService(fonts: fonts)
        let capture = await service.captureResult(MKShapingRequest(string: text, style: style))
        let composition = await ArrangeDeriver(fonts: fonts).derive(sourceText: text, style: style, capture: capture, paintStyle: paintStyle)
        let arrangedNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        let arrangedScene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.arranged(arrangedNode)])

        let renderer = MKSnapshotRenderer()
        guard let liveImage = renderer.renderFullCanvas(liveScene, scale: 3, quality: .exportQuality),
              let arrangedImage = renderer.renderFullCanvas(arrangedScene, scale: 3, quality: .exportQuality)
        else {
            Issue.record("[\(fixture.fontID)] failed to render one of the two scenes")
            return
        }
        let diff = PixelDiff.differingFraction(liveImage, arrangedImage)
        print("[D-222 sweep] \(fixture.fontID) (\(ps)): derivation-fidelity diff = \(String(format: "%.5f", diff))")
        #expect(diff <= fidelityTolerance, "[\(fixture.fontID)] لا derivation-vs-live diff \(diff) exceeds \(fidelityTolerance)")
    }

    // MARK: - T-AR-36..38 automated functional twin (decompose/opt-out/recompose)

    private func ligatureGroup(in composition: ArrangedComposition) -> MKLigatureGroup? {
        composition.nodes.compactMap { child -> MKLigatureGroup? in
            if case .ligature(let l) = child { return l }
            return nil
        }.first
    }

    @Test(arguments: releasedFonts)
    func ligatureDecomposeRecomposeRoundTripsAcrossReleasedFonts(_ fixture: FontFixture) async throws {
        guard let ps = Self.registerAndResolvePostScriptName(fixture) else {
            Issue.record("[\(fixture.fontID)] could not register/resolve PostScript name from \(fixture.fileName)")
            return
        }
        let fonts = NamedFontProvider(postScriptName: ps)
        let style = MKTextStyle(font: .system(postScriptName: ps), pointSize: 36, lineHeightMultiple: 1.2)
        let text = "لا"

        let service = MKShapingService(fonts: fonts)
        let capture = await service.captureResult(MKShapingRequest(string: text, style: style))
        let composition = await ArrangeDeriver(fonts: fonts).derive(sourceText: text, style: style, capture: capture)

        guard let group = ligatureGroup(in: composition), case .composed(let composed) = group.state, composed.decomposable else {
            // Font-dependent (packet §6's own "الله... decomposition
            // availability is font-dependent" precedent): لا did not fuse
            // into one decomposable ligature cluster on this font. Not a
            // failure ، recorded, not hidden, per this suite's own header.
            print("[D-222 sweep] \(fixture.fontID) (\(ps)): لا did not fuse into a decomposable ligature cluster ، decompose/recompose sweep N/A for this font")
            return
        }

        let decomposer = LigatureDecomposer(fonts: fonts)
        let result = try await decomposer.decompose(group, sourceString: text, style: style, options: .fidelityDefault)
        guard case .decomposed(let decomposed) = result.group.state else {
            Issue.record("[\(fixture.fontID)] decompose did not produce a decomposed state")
            return
        }
        print("[D-222 sweep] \(fixture.fontID) (\(ps)): naturalScaleFactor=\(String(format: "%.4f", result.naturalScaleFactor)) fidelityAutoRefused=\(result.fidelityAutoRefused) mode=\(decomposed.fidelityMode)")

        // When the fit was actually applied (not clamp-refused), the
        // assembled outline must land within the packet's documented 2%
        // tolerance of the original ligature's own outline width (task 9
        // accept criterion; same check `LigatureDecomposerTests
        // .fidelityFitAlignsWithinTwoPercentWhenWithinClamp` already
        // performs for the single Geeza Pro synthetic fixture ، this is the
        // same assertion, generalized across every released font's REAL لا
        // ligature whenever the natural fit happens to land inside the
        // clamp).
        if !result.fidelityAutoRefused, decomposed.fidelityMode == .matchOriginal,
           let ligBox = composed.outline?.cgPath(at: style.pointSize).boundingBoxOfPath,
           decomposed.components.count >= 2,
           let firstBox = decomposed.components.first?.outline?.cgPath(at: style.pointSize).boundingBoxOfPath,
           let lastBox = decomposed.components.last?.outline?.cgPath(at: style.pointSize).boundingBoxOfPath
        {
            let assembledMinX = decomposed.components.first!.layout.position.x + firstBox.minX
            let assembledMaxX = decomposed.components.last!.layout.position.x + lastBox.maxX
            let assembledWidth = assembledMaxX - assembledMinX
            let toleranceRatio = 0.02
            #expect(abs(assembledWidth - ligBox.width) <= ligBox.width * toleranceRatio + 0.5,
                    "[\(fixture.fontID)] assembled outline width \(assembledWidth) not within 2% of original ligature outline width \(ligBox.width)")
        }

        // Opt-out mode must also complete without throwing (task 10).
        _ = try await decomposer.decompose(group, sourceString: text, style: style, options: .defaultForms)

        // Recompose (task 11): no-edit round trip must be exact.
        let recomposed = try decomposer.recompose(result.group, force: false)
        #expect(recomposed.state == group.state, "[\(fixture.fontID)] decompose→recompose with no edits must round-trip exactly")
    }
}
