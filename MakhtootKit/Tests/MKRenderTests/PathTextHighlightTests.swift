import Testing
import CoreGraphics
import MKFoundation
import MKModel
import MKTextEngine
@testable import MKRender

// Path-text highlight painting (`PathTextDrawer.paintHighlight`, WS-07's
// path-text half of the highlight feature ، `LiveTextHighlightAndDecorationTests`
// is this file's own live-text counterpart, same header rationale: a
// sign-flip in the ribbon's ascent/descent direction, or a dropped
// save/restore around the highlight fill clobbering the glyph fill color,
// would each pass any model-level test while being visibly wrong on
// screen). Before this file, `MKRenderTests` had ZERO `pathText`
// references (`grep -rn "pathText" MakhtootKit/Tests/MKRenderTests/`
// returned no hits) ، this is new ground, not an update to an existing
// suite.
//
// Uses a STRAIGHT horizontal path so the expected pixel geometry reduces
// to the exact same "rect above/below baseline" reasoning
// `LiveTextHighlightAndDecorationTests` already uses, rather than needing
// curved-path pixel math: a horizontal path's tangent is `(1,0)`, so every
// glyph's rotation is `0` and the path-text glyph loop
// (`PathTextDrawer.draw`) draws exactly like `LiveTextDrawer` would for
// the same string.
@Suite struct PathTextHighlightTests {
    private let renderer = MKSceneRenderer()
    private let engine = MKShapingEngine(fonts: SystemFontStubProvider())

    private func makeContext(size: CGSize) -> CGContext {
        MKSnapshotRenderer.makeFlippedBitmapContext(width: Int(size.width), height: Int(size.height), scale: 1)!
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return (data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
    }

    /// True if any pixel in the vertical column `x`, rows `yRange`, is
    /// "dark" (all channels below `threshold`) ، same tolerant-of-exact-row
    /// helper `LiveTextHighlightAndDecorationTests` uses for its own
    /// stroke checks.
    private func columnContainsDarkPixel(_ image: CGImage, x: Int, yRange: ClosedRange<Int>, threshold: UInt8 = 120) -> Bool {
        for y in yRange where y >= 0 && y < image.height {
            let p = pixel(image, x: x, y: y)
            if p.r < threshold && p.g < threshold && p.b < threshold { return true }
        }
        return false
    }

    /// Same as `columnContainsDarkPixel`, swept over a whole `xRange` ،
    /// used for the "glyph ink wasn't clobbered" check below, where the
    /// exact x-offset of a glyph's own stroke within its advance width
    /// (side-bearings) isn't something this test wants to hardcode against
    /// one specific font's metrics.
    private func regionContainsDarkPixel(_ image: CGImage, xRange: ClosedRange<Int>, yRange: ClosedRange<Int>, threshold: UInt8 = 120) -> Bool {
        for x in xRange where x >= 0 && x < image.width {
            if columnContainsDarkPixel(image, x: x, yRange: yRange, threshold: threshold) { return true }
        }
        return false
    }

    private struct Built {
        var node: MKPathTextNode
        var baselineY: CGFloat
        var pathStartX: CGFloat
        var ascent: CGFloat
        var descent: CGFloat
        var width: CGFloat
    }

    /// Builds a one-line Latin path-text node on a STRAIGHT horizontal
    /// path starting at `(pathStartX, baselineY)`, `width + 400` pt long
    /// (the 400pt pad is well beyond the text's own pen span, so it can
    /// double as "definitely outside the ribbon" real estate for the
    /// "ribbon only covers the pen span, not the whole path" check).
    private func node(pointSize: Double, baselineY: CGFloat, pathStartX: CGFloat = 20, style: (inout MKTextStyle) -> Void) -> Built {
        var textStyle = MKTextStyle(pointSize: pointSize)
        textStyle.baseDirection = .leftToRight
        style(&textStyle)
        let text = MKSourceText(string: "IIIIIIIIIIIIIIIIIIII")
        let shaped = engine.shapeSingleLine(MKShapingRequest(text: text, style: textStyle, frame: .singleLine))
        let ascent = shaped.typographicBounds.ascent
        let descent = shaped.typographicBounds.descent
        let width = shaped.typographicBounds.width

        let pathLength = width + 400
        let seg = MKBezierSegment(
            start: CGPoint(x: pathStartX, y: baselineY),
            c1: CGPoint(x: pathStartX + pathLength / 3, y: baselineY),
            c2: CGPoint(x: pathStartX + pathLength * 2 / 3, y: baselineY),
            end: CGPoint(x: pathStartX + pathLength, y: baselineY))
        let path = MKBezierPathData(segments: [seg], isClosed: false)

        let core = MKNodeCore(name: "pathText", style: MKStyle(fill: .solid(.black)))
        let pathNode = MKPathTextNode(core: core, text: text, style: textStyle, path: path, layout: MKPathLayoutOptions())
        return Built(node: pathNode, baselineY: baselineY, pathStartX: pathStartX, ascent: ascent, descent: descent, width: width)
    }

    private func render(_ built: Built, canvasSize: CGSize = CGSize(width: 700, height: 300)) -> CGImage {
        let scene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.pathText(built.node)]
        )
        let ctx = makeContext(size: canvasSize)
        renderer.render(scene, region: CGRect(origin: .zero, size: canvasSize), into: ctx, scale: 1, quality: .exportQuality)
        return ctx.makeImage()!
    }

    @Test func highlightPaintsBehindGlyphsWrappingAscentAndDescent() {
        let built = node(pointSize: 40, baselineY: 150) { $0.highlightColor = MKSolidColor(r: 0, g: 1, b: 0, a: 1) }
        let image = render(built)

        // Well inside the pen span, in the sliver of the ribbon's own
        // ascent band that sits ABOVE the "I" glyphs' own ink (an
        // all-caps Latin string has no ascender/diacritic ink above its
        // cap height, and a font's `ascent` metric always reserves
        // headroom above cap height for exactly that ، verified against
        // this suite's own font/size/string via `CTFontGetBoundingRectsForGlyphs`:
        // ascent 38.67pt vs glyph ink top 28.18pt at this 40pt size, a
        // 10.49pt gap, so a 4pt inset from the ribbon's own top edge stays
        // comfortably clear of ink for ANY x in the pen span, not just one
        // hand-picked column). Mid-ascent height (this test's ORIGINAL
        // sample point) sits well inside that 28.18pt ink band instead ،
        // the actual cause of both this test's and
        // `noHighlightLeavesBackgroundUntouched`'s prior failures was the
        // sample point landing on glyph ink, not a ribbon geometry bug
        // (independently re-derived: `PathTextDrawer`'s glyph composition
        // `translate → rotate → scale(1,-1) → CTFontDrawGlyphs` does put a
        // glyph's ascent-side ink at `-frame.normal` when `insideOut ==
        // false`, matching `PathHighlightRibbon`'s own `insideOutSign`
        // exactly).
        let gapX = Int(built.pathStartX + built.width / 2)
        let insideY = Int(built.baselineY - built.ascent + 4)
        let inside = pixel(image, x: gapX, y: insideY)
        #expect(inside.g > 200 && inside.r < 100, "expected green highlight inside the ribbon, got \(inside)")

        // Well above/below the ribbon's own ascent+descent band must stay
        // white ، exactly the bound a top/bottom sign inversion blows
        // through.
        let farAbove = pixel(image, x: gapX, y: max(0, Int(built.baselineY - built.ascent * 2 - 6)))
        #expect(farAbove.r > 240 && farAbove.g > 240 && farAbove.b > 240, "expected white background far above the ribbon, got \(farAbove)")
        let farBelow = pixel(image, x: gapX, y: Int(built.baselineY + built.descent * 4 + 10))
        #expect(farBelow.r > 240 && farBelow.g > 240 && farBelow.b > 240, "expected white background far below the ribbon, got \(farBelow)")

        // Well PAST the pen's own span (still along the path's 400pt pad)
        // must also stay white ، the ribbon covers `[penStart, penEnd]`
        // only, never the whole path.
        let beyondPenX = Int(built.pathStartX + built.width + 200)
        let beyondPen = pixel(image, x: beyondPenX, y: Int(built.baselineY))
        #expect(beyondPen.r > 240 && beyondPen.g > 240 && beyondPen.b > 240, "expected white background beyond the pen's own span, got \(beyondPen)")

        // Actual glyph ink (the first letter's stroke) must still be
        // dark, NOT clobbered into the highlight color ، this is the
        // GState save/restore trap: `PathTextDrawer.draw` sets the glyph
        // fill color BEFORE the highlight paint call; without its own
        // saveGState/restoreGState around the highlight fill, the glyph
        // loop below would draw in highlight green instead of the node's
        // own black fill.
        let inkXRange = Int(built.pathStartX)...Int(built.pathStartX + 25)
        #expect(
            regionContainsDarkPixel(image, xRange: inkXRange, yRange: Int(built.baselineY - built.ascent)...Int(built.baselineY + built.descent)),
            "expected dark glyph ink to still be drawn (not clobbered by the highlight fill)")
    }

    @Test func noHighlightLeavesBackgroundUntouched() {
        let built = node(pointSize: 40, baselineY: 150) { _ in }
        let image = render(built)
        // Same ink-free point `highlightPaintsBehindGlyphsWrappingAscentAndDescent`
        // samples (top-of-ascent sliver, clear of the "I" glyphs' own ink
        // regardless of x) ، with no `highlightColor` set at all, this
        // point must stay untouched white. It is NOT a tautology: if a
        // regression ever painted the ribbon unconditionally (ignoring
        // `node.style.highlightColor == nil`), this exact point sits
        // inside the ribbon's own span and would turn green, failing this
        // assertion.
        let gapX = Int(built.pathStartX + built.width / 2)
        let insideY = Int(built.baselineY - built.ascent + 4)
        let inside = pixel(image, x: gapX, y: insideY)
        #expect(inside.r > 240 && inside.g > 240 && inside.b > 240, "expected untouched white background with no highlightColor set, got \(inside)")
    }
}
