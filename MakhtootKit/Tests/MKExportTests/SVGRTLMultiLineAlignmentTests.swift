import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKTextEngine
@testable import MKExport

// MASTER-PLAN Phase-2 RTL-alignment bug, export-parity half (canvas half is
// `MKRenderTests/RTLMultiLineAlignmentTests.swift`). Pre-fix,
// `SVGTextWriter.renderLiveText` anchored EVERY RTL line's `<text
// text-anchor="end">` at a fixed `x="0"` ، `0` is the node's box's LEFT
// edge (`MKNodeLocalBounds`/`paragraph.boxWidth`'s `[0, boxWidth]`
// convention), not its right edge, so `text-anchor="end"`'s right-flush
// idiom right-flushed every line at the wrong edge, shifting the whole
// paragraph outside `[0, boxWidth]` into negative x. The highlight rect and
// underline/strikethrough `<line>`s (P5.6/P5.7) used the same wrong fixed
// `x="0"`/`x1="0"` for every line regardless of that line's own width ،
// after the `<text>` fix alone, those decorations would DETACH from their
// (now correctly positioned) glyphs on any line shorter than the box.
//
// These tests assert EXACT `x`/`x1`/`x2` attribute values (not merely that
// an element exists), following `SVGTextDecorationTests`' own pattern,
// against expected numbers derived independently from `MKShapingEngine`
// directly (the same shaping call `SVGTextWriter` makes internally with the
// SVGSerializer's default `SystemFontStubProvider`), never by calling the
// production `paragraph.boxWidth`/`lineOriginX` helpers themselves ، so a
// regression in those shared helpers cannot escape detection by both the
// writer and this test silently agreeing on the same (possibly wrong) math.
@Suite struct SVGRTLMultiLineAlignmentTests {
    private let pointSize = 24.0
    private let maxWidth: CGFloat = 120
    /// Same fixture `MKTextEngineTests.ShapingEngineSmokeTests
    /// .multiLineParagraphWrapsAndContinuesSourceRange` and
    /// `MKRenderTests.RTLMultiLineAlignmentTests` already verify wraps to
    /// `>= 2` lines, with a genuinely shorter line, at this size/width.
    private let text = "بسم الله الرحمن الرحيم وعلى آله وصحبه أجمعين"

    private func makeStyle(direction: MKBaseDirection) -> MKTextStyle {
        var style = MKTextStyle(font: TestScenes.realFontRef, pointSize: pointSize, baseDirection: direction)
        style.highlightColor = MKSolidColor(r: 1, g: 1, b: 0, a: 1)
        style.isUnderline = true
        return style
    }

    private func exportSVG(style: MKTextStyle, sourceText: MKSourceText, frame: MKTextFrameSpec) -> String {
        let node = MKNode.liveText(MKLiveTextNode(
            core: MKNodeCore(name: "Text", transform: MKTransform2D(position: CGPoint(x: 20, y: 60)), style: MKStyle(fill: .solid(.black))),
            text: sourceText,
            style: style,
            frame: frame
        ))
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 400, height: 400)), nodes: [node])
        return SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size).svg
    }

    /// Every occurrence of `attribute="…"` inside every element whose
    /// opening tag contains `marker`, in document order ، the multi-line
    /// generalization of `SVGTextDecorationTests.firstAttributeValue`
    /// (which only ever needed the FIRST match, single-line fixtures).
    private func allAttributeValues(_ attribute: String, inTagsStartingWith marker: String, xml: String) -> [Double] {
        var results: [Double] = []
        var searchStart = xml.startIndex
        while let markerRange = xml.range(of: marker, range: searchStart..<xml.endIndex) {
            let tail = xml[markerRange.lowerBound...]
            guard let tagEnd = tail.range(of: ">") else { break }
            let element = tail[tail.startIndex..<tagEnd.upperBound]
            if let attrRange = element.range(of: "\(attribute)=\"") {
                let afterQuote = element[attrRange.upperBound...]
                if let closeQuote = afterQuote.range(of: "\""), let value = Double(afterQuote[afterQuote.startIndex..<closeQuote.lowerBound]) {
                    results.append(value)
                }
            }
            searchStart = tagEnd.upperBound
        }
        return results
    }

    @Test func rtlLinesAnchorAtTheSharedBoxRightEdgeAndDecorationsMoveWithEachLine() throws {
        let style = makeStyle(direction: .rightToLeft)
        let sourceText = MKSourceText(string: text)
        let frame = MKTextFrameSpec.widthConstrained(width: Double(maxWidth))

        let engine = MKShapingEngine(fonts: SystemFontStubProvider())
        let paragraph = engine.shapeParagraph(MKShapingRequest(text: sourceText, style: style, frame: frame))
        #expect(paragraph.lines.count >= 2, "fixture must wrap to multiple lines for this test to be meaningful")
        let boxWidth = paragraph.lines.map(\.typographicBounds.width).max() ?? 0
        let minWidth = paragraph.lines.map(\.typographicBounds.width).min() ?? 0
        #expect(minWidth < boxWidth - 15, "need a genuinely shorter line vs. the box width to test the fix")

        let svg = exportSVG(style: style, sourceText: sourceText, frame: frame)
        try XMLWellFormedness.assertWellFormed(svg)

        // Every line's <text> shares the SAME x = boxWidth (the box's right
        // edge) ، text-anchor="end" then right-flushes that line's own
        // rendered width against it automatically.
        let textXs = allAttributeValues("x", inTagsStartingWith: "<text ", xml: svg)
        #expect(textXs.count == paragraph.lines.count, "expected one <text> per shaped line, got \(textXs.count)")
        for x in textXs {
            #expect(abs(x - Double(boxWidth)) < 0.01, "every RTL line's <text> x must be the box's right edge (\(boxWidth)), got \(x)")
        }

        // Highlight rect / underline <line> have no anchor mechanic ، each
        // line's x/x1/x2 must be manually offset by `boxWidth - lineWidth`
        // so the decoration stays attached to that (now right-flushed)
        // line's own glyphs, not fixed at the box's left edge.
        let rectXs = allAttributeValues("x", inTagsStartingWith: "data-mk-kind=\"highlight\"", xml: svg)
        let underlineX1s = allAttributeValues("x1", inTagsStartingWith: "data-mk-kind=\"underline\"", xml: svg)
        let underlineX2s = allAttributeValues("x2", inTagsStartingWith: "data-mk-kind=\"underline\"", xml: svg)
        #expect(rectXs.count == paragraph.lines.count, "expected one highlight rect per line")
        #expect(underlineX1s.count == paragraph.lines.count, "expected one underline <line> per line")
        #expect(underlineX2s.count == paragraph.lines.count)

        for (i, line) in paragraph.lines.enumerated() {
            let width = line.typographicBounds.width
            let expectedX = Double(boxWidth - width)
            #expect(abs(rectXs[i] - expectedX) < 0.01, "line \(i) (width \(width)) highlight rect x must move with the line: expected \(expectedX), got \(rectXs[i])")
            #expect(abs(underlineX1s[i] - expectedX) < 0.01, "line \(i) underline x1 must move with the line: expected \(expectedX), got \(underlineX1s[i])")
            #expect(abs(underlineX2s[i] - (expectedX + Double(width))) < 0.01, "line \(i) underline x2 must be x1 + this line's own width")
        }
    }

    @Test func ltrLinesRemainAnchoredAtZeroForEveryLineUnchanged() throws {
        let style = makeStyle(direction: .leftToRight)
        let sourceText = MKSourceText(string: text)
        let frame = MKTextFrameSpec.widthConstrained(width: Double(maxWidth))

        let engine = MKShapingEngine(fonts: SystemFontStubProvider())
        let paragraph = engine.shapeParagraph(MKShapingRequest(text: sourceText, style: style, frame: frame))
        #expect(paragraph.lines.count >= 2, "fixture must wrap to multiple lines for this test to be meaningful")

        let svg = exportSVG(style: style, sourceText: sourceText, frame: frame)
        try XMLWellFormedness.assertWellFormed(svg)

        let textXs = allAttributeValues("x", inTagsStartingWith: "<text ", xml: svg)
        #expect(textXs.count == paragraph.lines.count)
        for x in textXs {
            #expect(abs(x - 0.0) < 0.01, "every LTR line's <text> x must remain the box's left edge (0), got \(x)")
        }

        let rectXs = allAttributeValues("x", inTagsStartingWith: "data-mk-kind=\"highlight\"", xml: svg)
        let underlineX1s = allAttributeValues("x1", inTagsStartingWith: "data-mk-kind=\"underline\"", xml: svg)
        #expect(rectXs.count == paragraph.lines.count)
        for x in rectXs {
            #expect(abs(x - 0.0) < 0.01, "every LTR line's highlight rect x must remain 0 (unchanged prior behavior), got \(x)")
        }
        for x1 in underlineX1s {
            #expect(abs(x1 - 0.0) < 0.01, "every LTR line's underline x1 must remain 0 (unchanged prior behavior), got \(x1)")
        }
    }
}
