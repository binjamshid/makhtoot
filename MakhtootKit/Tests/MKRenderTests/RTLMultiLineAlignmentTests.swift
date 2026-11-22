import Testing
import CoreGraphics
import MKFoundation
import MKModel
import MKTextEngine
@testable import MKRender

// MASTER-PLAN Phase-2 RTL-alignment bug (found reading `LiveTextDrawer`, not
// one of the 18 reported bugs): every line of a multi-line `.liveText` node
// was drawn at local x=0 (`LiveTextDrawer.draw`, pre-fix), i.e. flush LEFT
// against the node's `[0, boxWidth]` box (`MKNodeLocalBounds.localBounds`'s
// `.liveText` case ، `boxWidth` = the WIDEST line's own measured width).
// That is backwards for Arabic (D-109's RTL default): a paragraph's shorter
// lines must hug the box's RIGHT edge (ragged left), not its left edge.
//
// These tests pin the ACTUAL PIXELS `LiveTextDrawer` paints for a genuinely
// multi-line node (real word-wrap via `.widthConstrained`, not a synthetic
// two-line stand-in), following `LiveTextHighlightAndDecorationTests`'
// pattern of deriving expected geometry from the SAME `MKShapingEngine` call
// the drawer itself makes (never a hardcoded guess) ، the one difference:
// the "flush right"/"flush left" offset asserted here is written out
// independently as `boxWidth - lineWidth`/`0` rather than by calling the
// production `MKShapedParagraph.lineOriginX` helper, so a regression in
// that shared helper cannot silently escape detection by both the drawer
// and this test agreeing on the same (possibly wrong) call.
//
// **Tolerance note**: a line's measured `typographicBounds.width` is an
// ADVANCE metric, not an ink-extent metric ، the actual rightmost/leftmost
// painted pixel of a line can sit a few points short of its advance edge
// (normal side-bearing, verified empirically against this exact fixture:
// up to ~8pt on some wrapped lines of this font). Assertions below use a
// 15pt tolerance band, generous enough to absorb that per-glyph variance
// while still being FAR tighter than `boxWidth - shortestLineWidth` (the
// gap this whole fix is about, guarded to be `> 15pt` below) ، so the
// tolerance can never mask a flush-left/flush-right mixup.
@Suite struct RTLMultiLineAlignmentTests {
    private let renderer = MKSceneRenderer()
    private let engine = MKShapingEngine(fonts: SystemFontStubProvider())

    /// Basmala + trailing clause ، the SAME fixture `MKTextEngineTests
    /// .ShapingEngineSmokeTests.multiLineParagraphWrapsAndContinuesSourceRange`
    /// already verifies wraps to `>= 2` lines at this size/width on this
    /// host's CoreText.
    private let text = "بسم الله الرحمن الرحيم وعلى آله وصحبه أجمعين"
    private let pointSize: Double = 24
    private let maxWidth: CGFloat = 120
    private let nodeX: CGFloat = 20
    private let firstBaselineY: CGFloat = 60
    private let inkTolerance: CGFloat = 15

    private func makeContext(size: CGSize) -> CGContext {
        MKSnapshotRenderer.makeFlippedBitmapContext(width: Int(size.width), height: Int(size.height), scale: 1)!
    }

    /// Decodes `image` to a raw RGBA byte buffer ONCE (unlike re-drawing the
    /// whole `CGImage` into a fresh `CGContext` per pixel query, which is
    /// correct but prohibitively slow for a full-row ink-bounds scan).
    private struct PixelBuffer {
        let width: Int
        let height: Int
        let data: [UInt8]

        init?(_ image: CGImage) {
            width = image.width
            height = image.height
            var buffer = [UInt8](repeating: 0, count: width * height * 4)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(
                data: &buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            data = buffer
        }

        func isDark(x: Int, y: Int, threshold: UInt8 = 150) -> Bool {
            guard x >= 0, x < width, y >= 0, y < height else { return false }
            let offset = (y * width + x) * 4
            return data[offset] < threshold && data[offset + 1] < threshold && data[offset + 2] < threshold
        }

        /// Leftmost/rightmost column (inclusive) containing a dark pixel
        /// anywhere in `yRange`, i.e. this row-band's actual painted ink
        /// extent ، `nil` if the band has no ink at all.
        func inkBounds(yRange: ClosedRange<Int>) -> (minX: Int, maxX: Int)? {
            var minX: Int?
            var maxX: Int?
            for x in 0..<width {
                var found = false
                for y in yRange where y >= 0 && y < height {
                    if isDark(x: x, y: y) { found = true; break }
                }
                if found {
                    if minX == nil { minX = x }
                    maxX = x
                }
            }
            guard let lo = minX, let hi = maxX else { return nil }
            return (lo, hi)
        }
    }

    private struct BuiltParagraph {
        var paragraph: MKShapedParagraph
        var boxWidth: CGFloat
        var lineHeight: CGFloat
        var buffer: PixelBuffer
    }

    private func build(direction: MKBaseDirection) -> BuiltParagraph {
        var style = MKTextStyle(pointSize: pointSize)
        style.baseDirection = direction
        let sourceText = MKSourceText(string: text)
        let frame = MKTextFrameSpec.widthConstrained(width: Double(maxWidth))

        let paragraph = engine.shapeParagraph(MKShapingRequest(text: sourceText, style: style, frame: frame))
        let boxWidth = paragraph.boxWidth
        let lineHeight = CGFloat(style.lineHeightMultiple * style.pointSize)
        let ascent = paragraph.lines[0].typographicBounds.ascent

        let core = MKNodeCore(
            name: "text", transform: MKTransform2D(position: CGPoint(x: nodeX, y: firstBaselineY - ascent)),
            style: MKStyle(fill: .solid(.black)))
        let node = MKLiveTextNode(core: core, text: sourceText, style: style, frame: frame)

        let canvasSize = CGSize(
            width: Double(nodeX + boxWidth + 40),
            height: Double(firstBaselineY) + Double(lineHeight) * Double(paragraph.lines.count) + 60)
        let scene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.liveText(node)])
        let ctx = makeContext(size: canvasSize)
        renderer.render(scene, region: CGRect(origin: .zero, size: canvasSize), into: ctx, scale: 1, quality: .exportQuality)
        guard let buffer = PixelBuffer(ctx.makeImage()!) else {
            fatalError("failed to decode rendered image into a pixel buffer")
        }
        return BuiltParagraph(paragraph: paragraph, boxWidth: boxWidth, lineHeight: lineHeight, buffer: buffer)
    }

    @Test func rtlShortLineIsFlushRightRaggedLeft() {
        let built = build(direction: .rightToLeft)
        let paragraph = built.paragraph
        #expect(paragraph.lines.count >= 2, "fixture must wrap to multiple lines for this test to be meaningful")

        let shortestWidth = paragraph.lines.map(\.typographicBounds.width).min() ?? 0
        #expect(shortestWidth < built.boxWidth - 15, "need a genuinely shorter line vs. the box width to test raggedness; got short=\(shortestWidth) box=\(built.boxWidth)")

        for (i, line) in paragraph.lines.enumerated() {
            let width = line.typographicBounds.width
            let baselineY = firstBaselineY + built.lineHeight * CGFloat(i)
            let yRange = Int(baselineY - line.typographicBounds.ascent)...Int(baselineY + line.typographicBounds.descent)

            guard let bounds = built.buffer.inkBounds(yRange: yRange) else {
                Issue.record("line \(i) (width \(width)) painted no ink at all in its expected row band")
                continue
            }

            // Every line, short or long, must be flush RIGHT: its rightmost
            // ink must sit within tolerance of the box's shared right edge
            // (`nodeX + boxWidth`), regardless of that line's own width.
            let expectedRightEdge = nodeX + built.boxWidth
            #expect(CGFloat(bounds.maxX) > expectedRightEdge - inkTolerance, "line \(i) (width \(width)) right ink edge (\(bounds.maxX)) is too far left of the box's right edge (\(expectedRightEdge)) ، expected flush right")

            // A genuinely shorter line's LEFT ink edge must land near its
            // OWN right-flushed left edge (`boxWidth - width` in from the
            // box's left), not at the box's left edge itself (`nodeX`) ،
            // the exact position the pre-fix flush-left-always bug painted.
            if width < built.boxWidth - 15 {
                let expectedLeftEdge = nodeX + built.boxWidth - width
                #expect(CGFloat(bounds.minX) > nodeX + inkTolerance, "line \(i) (width \(width)) left ink edge (\(bounds.minX)) sits at the box's LEFT edge ، looks flush-left (the pre-fix bug), not ragged-left")
                #expect(abs(CGFloat(bounds.minX) - expectedLeftEdge) < inkTolerance, "line \(i) (width \(width)) left ink edge (\(bounds.minX)) does not match its predicted flush-right left edge (\(expectedLeftEdge))")
            }
        }
    }

    @Test func ltrAlignmentIsUnchangedFlushLeftRaggedRight() {
        let built = build(direction: .leftToRight)
        let paragraph = built.paragraph
        #expect(paragraph.lines.count >= 2, "fixture must wrap to multiple lines for this test to be meaningful")

        let shortestWidth = paragraph.lines.map(\.typographicBounds.width).min() ?? 0
        #expect(shortestWidth < built.boxWidth - 15, "need a genuinely shorter line vs. the box width to test raggedness; got short=\(shortestWidth) box=\(built.boxWidth)")

        for (i, line) in paragraph.lines.enumerated() {
            let width = line.typographicBounds.width
            let baselineY = firstBaselineY + built.lineHeight * CGFloat(i)
            let yRange = Int(baselineY - line.typographicBounds.ascent)...Int(baselineY + line.typographicBounds.descent)

            guard let bounds = built.buffer.inkBounds(yRange: yRange) else {
                Issue.record("line \(i) (width \(width)) painted no ink at all in its expected row band")
                continue
            }

            // Every line must remain flush LEFT (prior/unchanged behavior):
            // its leftmost ink must sit within tolerance of the box's
            // shared left edge (`nodeX`).
            #expect(CGFloat(bounds.minX) < nodeX + inkTolerance, "line \(i) (width \(width)) left ink edge (\(bounds.minX)) is too far right of the box's left edge (\(nodeX)) ، expected flush left")

            // A genuinely shorter line's RIGHT ink edge must land near its
            // OWN left-flushed right edge (`nodeX + width`), not at the
            // box's right edge (the ragged side must stay ragged).
            if width < built.boxWidth - 15 {
                let expectedRightEdge = nodeX + width
                let boxRightEdge = nodeX + built.boxWidth
                #expect(CGFloat(bounds.maxX) < boxRightEdge - inkTolerance, "line \(i) (width \(width)) right ink edge (\(bounds.maxX)) sits at the box's RIGHT edge ، looks flush-right, not ragged-right")
                #expect(abs(CGFloat(bounds.maxX) - expectedRightEdge) < inkTolerance, "line \(i) (width \(width)) right ink edge (\(bounds.maxX)) does not match its predicted flush-left right edge (\(expectedRightEdge))")
            }
        }
    }
}
