import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKRender
import MKTextEngine
import Testing

// Regression coverage for the 2026-07-29 user report "text can overflow in
// a text field box and get cutoff".
//
// `MKLayerTreeController` sizes each node's `CALayer` to exactly
// `MKNodeLocalBounds.worldBounds(of:)` and rasterises the node into a
// region of exactly that size, so anything a drawer paints outside those
// bounds is not clipped by a stylistic choice ، it is destroyed. The
// `.liveText` case used to report `lineHeightMultiple × pointSize ×
// lineCount`, the height a LAYOUT engine reserves, while `LiveTextDrawer`
// places line 0's baseline at the font's own ascent and lets the last
// line's descent run past it. Arabic faces routinely have `ascent +
// descent` well over the 1.2 em default, so descenders and below-baseline
// tashkeel were cut off.

@Suite("Text bounds contain what the drawer paints")
struct TextBoundsClippingTests {
    /// The invariant, stated directly: the reported box must reach at
    /// least as far down as the lowest ink the drawer will produce.
    private func assertBoundsContainPaintedExtent(_ node: MKLiveTextNode, sourceLabel: String) throws {
        let engine = MKShapingEngine()
        let paragraph = engine.shapeParagraph(
            MKShapingRequest(text: node.text, style: node.style, frame: node.frame))
        try #require(!paragraph.lines.isEmpty)

        let lineHeight = CGFloat(node.style.lineHeightMultiple * node.style.pointSize)
        // Exactly what `LiveTextDrawer.draw` does: baseline 0 at ascent₀,
        // stepping by `lineHeight`, with the final line's descent below it.
        let paintedBottom = paragraph.lines[0].typographicBounds.ascent
            + CGFloat(paragraph.lines.count - 1) * lineHeight
            + (paragraph.lines.last?.typographicBounds.descent ?? 0)

        let bounds = MKNodeLocalBounds.localBounds(of: .liveText(node))
        #expect(
            bounds.maxY >= paintedBottom - 1e-6,
            "\(sourceLabel): bounds bottom \(bounds.maxY) clips painted bottom \(paintedBottom)")
        #expect(bounds.minY <= 0 + 1e-6)
    }

    private func node(_ string: String, pointSize: Double = 48, lineHeightMultiple: Double = 1.2, frame: MKTextFrameSpec = .singleLine) -> MKLiveTextNode {
        MKLiveTextNode(
            core: MKNodeCore(name: "text"),
            text: MKSourceText(string: string),
            style: MKTextStyle(pointSize: pointSize, lineHeightMultiple: lineHeightMultiple),
            frame: frame
        )
    }

    @Test("single-line Arabic with tashkeel is not clipped")
    func singleLineWithTashkeel() throws {
        try assertBoundsContainPaintedExtent(node("بِسْمِ اللَّهِ"), sourceLabel: "tashkeel")
    }

    @Test("Arabic with descenders is not clipped")
    func descenders() throws {
        try assertBoundsContainPaintedExtent(node("مجرى ججج"), sourceLabel: "descenders")
    }

    /// The case that made the old formula wrong most often: a line height
    /// tighter than the face's own ascent + descent. At 1.2 em (the model
    /// default) many Arabic faces already overflow; at 0.8 every face does.
    @Test("a tight line height still reports bounds that contain the ink")
    func tightLineHeight() throws {
        try assertBoundsContainPaintedExtent(
            node("بِسْمِ اللَّهِ", lineHeightMultiple: 0.8), sourceLabel: "tight line height")
    }

    @Test("multi-line wrapped text is not clipped at the bottom")
    func multiLine() throws {
        try assertBoundsContainPaintedExtent(
            node("بسم الله الرحمن الرحيم والحمد لله رب العالمين", frame: .widthConstrained(width: 200)),
            sourceLabel: "wrapped")
    }

    /// The hit-testable area and the drawn/selected area must be the same
    /// rect, or a node becomes tappable somewhere it is not visible (or
    /// vice versa). Both now go through the same shared paragraph helpers.
    @Test("hit-test bounds and layer bounds agree")
    func hitTestBoundsMatchLayerBounds() throws {
        let live = node("بِسْمِ اللَّهِ")
        let layerBounds = MKNodeLocalBounds.localBounds(of: .liveText(live))

        // `HitTester` computes its own copy; drive it through the public
        // entry point and compare against the layer bounds.
        let scene = MKScene(
            canvas: MKCanvasSpec(size: CGSize(width: 500, height: 500)),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.liveText(live)]
        )
        let tester = HitTester()
        let geometry = try #require(tester.worldGeometry(of: live.core.id, in: scene))
        #expect(abs(geometry.localBounds.height - layerBounds.height) < 1e-6)
        #expect(abs(geometry.localBounds.width - layerBounds.width) < 1e-6)

        // A point just above the bottom edge of the reported box must hit,
        // which is the property that used to fail for the clipped strip.
        let insideBottom = CGPoint(x: layerBounds.midX, y: layerBounds.maxY - 1)
        #expect(tester.containsPrecise(nodeID: live.core.id, worldPoint: insideBottom, in: scene))
    }

    @Test("boxHeight never reports less than the reserved line boxes")
    func boxHeightNeverShrinks() throws {
        let engine = MKShapingEngine()
        let live = node("بسم الله الرحمن الرحيم", frame: .widthConstrained(width: 150))
        let paragraph = engine.shapeParagraph(
            MKShapingRequest(text: live.text, style: live.style, frame: live.frame))
        let lineHeight = CGFloat(live.style.lineHeightMultiple * live.style.pointSize)
        #expect(paragraph.boxHeight(lineHeight: lineHeight) >= lineHeight * CGFloat(paragraph.lines.count))
    }
}
