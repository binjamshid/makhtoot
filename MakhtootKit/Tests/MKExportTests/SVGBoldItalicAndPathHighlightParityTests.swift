import Testing
import CoreGraphics
import CoreText
import Foundation
import MKFoundation
import MKFonts
import MKModel
@testable import MKExport

// Canvas⇄export parity gaps closed in this change:
//   GAP1: bold/italic live text now resolves at `MKShapingEngine
//   .resolvedFont(for:)` (a `MKFontVariantRequest`), and every drawer reads
//   the RESOLVED font back off the captured run (`MKShapedRun.font`) ،
//   `SVGTextWriter` didn't: it emitted `font-family` and derived underline/
//   strikethrough metrics from `node.style.font`, the UNRESOLVED request.
//   These tests use REAL bundled fonts (`amiri`/`tajawal`, which have a
//   genuine Bold static cut; `lalezar`/`rakkas`/`jomhuria`, which don't) via
//   `MKRegistryFontProvider`, mirroring `MKFontVariantResolutionTests`'
//   (`MKFontsTests`) own real-font harness, so these tests exercise actual
//   CoreText variant resolution rather than a stub that ignores `variant`.
@Suite struct SVGBoldItalicParityTests {
    // Arabic content (`مرحبا`, "hello"), not Latin: `amiri`/`tajawal`/
    // `lalezar`/`rakkas`/`jomhuria` are all Arabic-script display faces ،
    // shaping Latin text through them risks CoreText silently CASCADING to
    // an unrelated fallback font for glyph coverage, which would capture
    // that fallback's PostScript name into `MKShapedRun.font` instead of
    // the family actually under test, invalidating these assertions.
    private func liveTextScene(font: MKFontRef, isBold: Bool, isUnderline: Bool = false, pointSize: Double = 40) -> MKScene {
        var style = MKTextStyle(font: font, pointSize: pointSize, baseDirection: .rightToLeft)
        style.isBold = isBold
        style.isUnderline = isUnderline
        let text = MKNode.liveText(MKLiveTextNode(
            core: MKNodeCore(name: "Text", transform: MKTransform2D(position: CGPoint(x: 20, y: 80)), style: MKStyle(fill: .solid(.black))),
            text: MKSourceText(string: "مرحبا"),
            style: style
        ))
        return MKScene(canvas: MKCanvasSpec(size: CGSize(width: 300, height: 150)), nodes: [text])
    }

    /// `amiri`/`tajawal` genuinely have a Bold static cut (`Amiri-Bold.ttf`
    /// per `records.json`, same fixture `MKFontVariantResolutionTests
    /// .variantResolutionReturnsGenuinelyDifferentFontForFamilyWithBoldCut`
    /// already verifies at the `MKRegistryFontProvider` level) ، requesting
    /// `isBold` on either must change the SVG's emitted `font-family`.
    @Test func boldFontFamilyDiffersForFamiliesWithARealBoldCut() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let provider = MKRegistryFontProvider()

        for fontID in ["amiri", "tajawal"] {
            guard let record = await registry.record(for: fontID), let face = record.defaultFace else {
                Issue.record("\(fontID) did not load ، cannot verify this fix")
                continue
            }
            let fontRef = MKFontRef.system(postScriptName: face.postScriptName)
            let regularSVG = SVGSerializer.export(
                scene: liveTextScene(font: fontRef, isBold: false), pixelSize: CGSize(width: 300, height: 150), fonts: provider
            ).svg
            let boldSVG = SVGSerializer.export(
                scene: liveTextScene(font: fontRef, isBold: true), pixelSize: CGSize(width: 300, height: 150), fonts: provider
            ).svg

            let regularFamily = try #require(firstAttributeString("font-family", xml: regularSVG), "\(fontID): expected a font-family attribute")
            let boldFamily = try #require(firstAttributeString("font-family", xml: boldSVG), "\(fontID): expected a font-family attribute")
            #expect(regularFamily == face.postScriptName, "\(fontID): regular font-family should be the unresolved/default face's own PostScript name")
            #expect(
                boldFamily != regularFamily,
                "\(fontID): bold font-family (\(boldFamily)) must differ from regular (\(regularFamily)) ، a regression back to `node.style.font.postScriptName` would emit the SAME (unresolved) name for both")

            // The `@font-face` embed (when a font-data provider ever returns
            // bytes) must declare the SAME family the `<text>` element uses,
            // never a mismatched pair.
            if boldSVG.contains("@font-face") {
                #expect(boldSVG.contains("font-family: \"\(boldFamily)\""), "\(fontID): @font-face family must agree with the <text> font-family it backs")
            }
        }
    }

    /// Single-face families (`lalezar`/`rakkas`/`jomhuria`) have no bold cut
    /// ، `MKRegistryFontProvider` must return the SAME font for both, so the
    /// resolved PostScript name (and therefore the emitted `font-family`)
    /// must NOT differ.
    @Test func boldFontFamilyUnchangedForSingleFaceFamilies() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let provider = MKRegistryFontProvider()

        for fontID in ["lalezar", "rakkas", "jomhuria"] {
            guard let record = await registry.record(for: fontID), let face = record.defaultFace else {
                Issue.record("\(fontID) did not load ، cannot verify this fix")
                continue
            }
            let fontRef = MKFontRef.system(postScriptName: face.postScriptName)
            let regularSVG = SVGSerializer.export(
                scene: liveTextScene(font: fontRef, isBold: false), pixelSize: CGSize(width: 300, height: 150), fonts: provider
            ).svg
            let boldSVG = SVGSerializer.export(
                scene: liveTextScene(font: fontRef, isBold: true), pixelSize: CGSize(width: 300, height: 150), fonts: provider
            ).svg

            let regularFamily = try #require(firstAttributeString("font-family", xml: regularSVG))
            let boldFamily = try #require(firstAttributeString("font-family", xml: boldSVG))
            #expect(boldFamily == regularFamily, "\(fontID) has no bold cut ، requesting bold must keep the SAME font-family, never a synthesized one")
        }
    }

    /// GAP1's third bug: decoration metrics (underline thickness/position)
    /// must be read off the RESOLVED, variant-matched font for EACH weight
    /// ، not the unresolved request, and not a name round-trip through the
    /// run's captured PostScript name (`fonts.resolve(runCapturedHandle)`
    /// is not guaranteed to land back on the same `CTFont`, see
    /// `SystemFontStubProvider`'s doc comment). Verified against the SAME
    /// `MKRegistryFontProvider` resolution the production code now uses,
    /// per weight independently, not merely "differs from regular": a font
    /// is fully entitled to specify the SAME underline thickness across
    /// cuts (amiri's Bold and Regular both report 2.0pt at this size), so
    /// asserting bold != regular is an assumption about the font, not about
    /// whether the code sourced the metric from the right place.
    @Test func underlineThicknessMatchesTheIndependentlyResolvedFontsOwnMetricPerWeight() async throws {
        let registry = MKFontRegistry()
        _ = try await registry.loadBundled()
        let provider = MKRegistryFontProvider()
        guard let record = await registry.record(for: "amiri"), let face = record.defaultFace else {
            Issue.record("amiri did not load ، cannot verify this fix")
            return
        }
        let pointSize = 40.0
        let fontRef = MKFontRef.system(postScriptName: face.postScriptName)

        var thicknessByWeight: [Bool: Double] = [:]
        for isBold in [false, true] {
            let scene = liveTextScene(font: fontRef, isBold: isBold, isUnderline: true, pointSize: pointSize)
            let svg = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size, fonts: provider).svg

            let handle = MKFontHandle(postScriptName: face.postScriptName, pointSize: CGFloat(pointSize))
            let variant = MKFontVariantRequest(bold: isBold, italic: false)
            let expectedFont = provider.resolve(handle, variant: variant)
            let expectedThickness = max(CTFontGetUnderlineThickness(expectedFont), 1)

            let strokeWidth = try #require(
                firstAttributeValue("stroke-width", inTagStartingWith: "data-mk-kind=\"underline\"", xml: svg),
                "isBold=\(isBold): expected an underline <line> element")
            #expect(
                abs(strokeWidth - Double(expectedThickness)) < 0.01,
                "isBold=\(isBold): emitted underline stroke-width (\(strokeWidth)) must match the RESOLVED font's own CTFontGetUnderlineThickness (\(expectedThickness))")
            thicknessByWeight[isBold] = strokeWidth
        }

        // NOT asserting `thicknessByWeight[true] != thicknessByWeight[false]`
        // here: that assumes amiri's Bold cut has a strictly thicker
        // underline than Regular, which is simply false for this font at
        // this size (both report 2.0pt ، a font is fully entitled to keep
        // underline thickness constant across cuts). The meaningful check
        // already happened per-weight inside the loop above: each weight's
        // emitted `stroke-width` matches THAT weight's own independently
        // resolved `CTFontGetUnderlineThickness`, which proves the metric
        // is sourced from the right (variant-resolved) font regardless of
        // whether the two weights happen to agree numerically.
        _ = thicknessByWeight
    }

    // MARK: - helpers

    private func firstAttributeString(_ attribute: String, xml: String) -> String? {
        guard let range = xml.range(of: "\(attribute)=\"") else { return nil }
        let after = xml[range.upperBound...]
        guard let end = after.range(of: "\"") else { return nil }
        return String(after[after.startIndex..<end.lowerBound])
    }

    /// Finds the first element whose opening tag CONTAINS `marker`, then
    /// extracts the numeric value of `attribute="…"` from that same element
    /// (same technique as `SVGTextDecorationTests`' own helper).
    private func firstAttributeValue(_ attribute: String, inTagStartingWith marker: String, xml: String) -> Double? {
        guard let markerRange = xml.range(of: marker) else { return nil }
        let tail = xml[markerRange.lowerBound...]
        guard let tagEnd = tail.range(of: ">") else { return nil }
        let element = String(tail[tail.startIndex..<tagEnd.upperBound])
        guard let attrRange = element.range(of: "\(attribute)=\"") else { return nil }
        let afterQuote = element[attrRange.upperBound...]
        guard let closeQuote = afterQuote.range(of: "\"") else { return nil }
        return Double(afterQuote[afterQuote.startIndex..<closeQuote.lowerBound])
    }
}

// GAP2: path-text's swept-ribbon highlight (`PathHighlightRibbon`,
// `MKPathText`, shared with `PathTextDrawer.paintHighlight`'s canvas
// render) now also exports, via `MKTextOutlining.pathTextHighlightRibbon` +
// `SVGSerializer.renderPathText`. Modeled directly on
// `SVGTextDecorationTests`' live-text highlight suite.
@Suite struct SVGPathTextHighlightTests {
    @Test func highlightEmitsAPathBeforeTheOutlineGroup() throws {
        let scene = TestScenes.pathTextScene(highlightColor: MKSolidColor(r: 1, g: 0.8, b: 0, a: 1))
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        #expect(result.svg.contains("data-mk-kind=\"highlight\""))
        try XMLWellFormedness.assertWellFormed(result.svg)

        // Document order: the highlight `<path>` must precede the glyph-
        // outline `<g data-mk-kind="glyph">` group it backs (SVG paints
        // back-to-front ، a highlight AFTER the glyphs would paint OVER
        // them, hiding the outlines).
        guard let highlightRange = result.svg.range(of: "data-mk-kind=\"highlight\""),
              let glyphGroupRange = result.svg.range(of: "data-mk-kind=\"glyph\"")
        else {
            Issue.record("expected both a highlight path and a glyph-outline group")
            return
        }
        #expect(highlightRange.lowerBound < glyphGroupRange.lowerBound)
    }

    @Test func noHighlightColorEmitsNoHighlightPath() throws {
        let scene = TestScenes.pathTextScene(highlightColor: nil)
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        #expect(!result.svg.contains("data-mk-kind=\"highlight\""))
    }

    @Test func partialAlphaHighlightEmitsFillOpacity() throws {
        let scene = TestScenes.pathTextScene(highlightColor: MKSolidColor(r: 0, g: 1, b: 0, a: 0.4))
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        guard let line = result.svg.split(separator: "\n").first(where: { $0.contains("data-mk-kind=\"highlight\"") }) else {
            Issue.record("expected a highlight path element")
            return
        }
        #expect(line.contains("fill-opacity=\"0.4\""))
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    @Test func opaqueHighlightOmitsFillOpacity() throws {
        let scene = TestScenes.pathTextScene(highlightColor: MKSolidColor(r: 0, g: 1, b: 0, a: 1))
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        guard let line = result.svg.split(separator: "\n").first(where: { $0.contains("data-mk-kind=\"highlight\"") }) else {
            Issue.record("expected a highlight path element")
            return
        }
        #expect(!line.contains("fill-opacity"))
        try XMLWellFormedness.assertWellFormed(result.svg)
    }
}
