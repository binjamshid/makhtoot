import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKExport

// MASTER-PLAN P5.6/P5.7 canvas⇄export parity: every trait `LiveTextDrawer`
// gained (highlight/underline/strikethrough, `LiveTextHighlightAndDecorationTests`
// in `MKRenderTests`) lands in `SVGSerializer`/`SVGTextWriter` in the SAME
// change. These tests exercise the embeddable-font `<text>` path
// (`TestScenes.realFontRef`, D-227(2)'s "SVG rights" branch), which is the
// one `SVGTextWriter.renderLiveText` owns.
@Suite struct SVGTextDecorationTests {
    private func liveTextScene(highlight: MKSolidColor? = nil, underline: Bool = false, strikethrough: Bool = false) -> MKScene {
        var style = MKTextStyle(font: TestScenes.realFontRef, pointSize: 24, baseDirection: .leftToRight)
        style.highlightColor = highlight
        style.isUnderline = underline
        style.isStrikethrough = strikethrough
        let text = MKNode.liveText(MKLiveTextNode(
            core: MKNodeCore(name: "Text", transform: MKTransform2D(position: CGPoint(x: 20, y: 60)), style: MKStyle(fill: .solid(.black))),
            text: MKSourceText(string: "Hello"),
            style: style
        ))
        return MKScene(canvas: MKCanvasSpec(size: CGSize(width: 200, height: 150)), nodes: [text])
    }

    @Test func highlightEmitsARectBeforeTheTextElement() throws {
        let scene = liveTextScene(highlight: MKSolidColor(r: 1, g: 1, b: 0, a: 1))
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        #expect(result.svg.contains("data-mk-kind=\"highlight\""))
        try XMLWellFormedness.assertWellFormed(result.svg)

        // Document order: the highlight `<rect>` must precede the `<text>`
        // it backs (SVG paints back-to-front ، a rect AFTER the text would
        // paint OVER the glyphs, hiding them).
        guard let rectRange = result.svg.range(of: "data-mk-kind=\"highlight\""),
              let textRange = result.svg.range(of: "<text ")
        else {
            Issue.record("expected both a highlight rect and a text element")
            return
        }
        #expect(rectRange.lowerBound < textRange.lowerBound)
    }

    @Test func partialAlphaHighlightEmitsFillOpacity() throws {
        let scene = liveTextScene(highlight: MKSolidColor(r: 0, g: 1, b: 0, a: 0.4))
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        #expect(result.svg.contains("fill-opacity=\"0.4\""))
    }

    @Test func opaqueHighlightOmitsFillOpacity() throws {
        let scene = liveTextScene(highlight: MKSolidColor(r: 0, g: 1, b: 0, a: 1))
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        // Only the highlight rect's own attrs are being checked here ،
        // grep the rect element specifically, not the whole document (a
        // fully-opaque scene could coincidentally contain the substring
        // elsewhere).
        guard let rectLine = result.svg.split(separator: "\n").first(where: { $0.contains("data-mk-kind=\"highlight\"") }) else {
            Issue.record("expected a highlight rect element")
            return
        }
        #expect(!rectLine.contains("fill-opacity"))
    }

    @Test func noHighlightEmitsNoRect() throws {
        let scene = liveTextScene(highlight: nil)
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        #expect(!result.svg.contains("data-mk-kind=\"highlight\""))
    }

    @Test func underlineEmitsALineElement() throws {
        let scene = liveTextScene(underline: true)
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        #expect(result.svg.contains("data-mk-kind=\"underline\""))
        #expect(!result.svg.contains("data-mk-kind=\"strikethrough\""))
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    @Test func strikethroughEmitsALineElement() throws {
        let scene = liveTextScene(strikethrough: true)
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        #expect(result.svg.contains("data-mk-kind=\"strikethrough\""))
        #expect(!result.svg.contains("data-mk-kind=\"underline\""))
        try XMLWellFormedness.assertWellFormed(result.svg)
    }

    @Test func neitherTraitEmitsNoDecorationLines() throws {
        let scene = liveTextScene()
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        #expect(!result.svg.contains("data-mk-kind=\"underline\""))
        #expect(!result.svg.contains("data-mk-kind=\"strikethrough\""))
    }

    /// The underline `<line>`'s `y1`/`y2` must sit BELOW the text's own
    /// baseline y (document y-down: below = larger) ، the exact sign this
    /// writer's own doc comment calls out (`lineOriginY - underlineY`,
    /// `underlineY` typically negative). A regression back to `lineOriginY
    /// + underlineY` would place the stroke ABOVE the baseline instead.
    @Test func underlineSitsBelowTheTextBaselineNotAbove() throws {
        let scene = liveTextScene(underline: true)
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        guard let textY = firstAttributeValue("y", inTagStartingWith: "<text ", xml: result.svg),
              let lineY = firstAttributeValue("y1", inTagStartingWith: "data-mk-kind=\"underline\"", xml: result.svg)
        else {
            Issue.record("expected both <text y=…> and underline <line y1=…>")
            return
        }
        #expect(lineY > textY, "underline y1 (\(lineY)) must be greater (further down) than the text baseline y (\(textY))")
    }

    /// Mirror check for strikethrough: must sit ABOVE the baseline
    /// (smaller document y), never below.
    @Test func strikethroughSitsAboveTheTextBaselineNotBelow() throws {
        let scene = liveTextScene(strikethrough: true)
        let result = SVGSerializer.export(scene: scene, pixelSize: scene.canvas.size)
        guard let textY = firstAttributeValue("y", inTagStartingWith: "<text ", xml: result.svg),
              let lineY = firstAttributeValue("y1", inTagStartingWith: "data-mk-kind=\"strikethrough\"", xml: result.svg)
        else {
            Issue.record("expected both <text y=…> and strikethrough <line y1=…>")
            return
        }
        #expect(lineY < textY, "strikethrough y1 (\(lineY)) must be less (further up) than the text baseline y (\(textY))")
    }

    // MARK: - helpers

    /// Finds the first element whose opening tag CONTAINS `marker`, then
    /// extracts the numeric value of `attribute="…"` from that same
    /// element (searched within a bounded window after the marker, up to
    /// the element's closing `/>` or `>`).
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
