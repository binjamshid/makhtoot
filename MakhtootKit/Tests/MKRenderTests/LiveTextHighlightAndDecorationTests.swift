import Testing
import CoreGraphics
import CoreText
import MKFoundation
import MKModel
import MKTextEngine
@testable import MKRender

// MASTER-PLAN P5.6/P5.7 (Bug 11 / Bug 9): highlight, underline, and
// strikethrough on `MKLiveTextNode` were pure model round-trips with ZERO
// drawer painting them (`grep -rn "highlightColor"
// MakhtootKit/Sources/MKRender/` returned no hits before this change, and
// the same was true for `isUnderline`/`isStrikethrough`). These tests pin
// the ACTUAL PIXELS `LiveTextDrawer` now paints, not just that the model
// field round-trips ، a sign error in the local-space y-flip math (caught
// during this session's own implementation: the first draft placed the
// highlight rect mostly BELOW the baseline instead of wrapping the line)
// would pass every existing model-level test while still being visibly
// wrong on screen, which is exactly the class of bug a pixel-level check
// catches and a model-level one cannot.
//
// Expected geometry is derived from `MKShapingEngine` directly (the SAME
// shaping call `LiveTextDrawer.draw` makes internally) rather than raw
// `CTFontGetAscent`/`CTFontGetDescent`, since `CTLineGetTypographicBounds`'s
// per-line ascent/descent is what the drawer actually uses and need not
// equal the font's own whole-font metrics exactly.
@Suite struct LiveTextHighlightAndDecorationTests {
    private let renderer = MKSceneRenderer()
    private let fonts = SystemFontStubProvider()
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

    private struct Built {
        var node: MKLiveTextNode
        var ctFont: CTFont
        /// Absolute canvas-space y of the shaped line's baseline (accounts
        /// for `LiveTextDrawer.draw`'s own `lineOriginY = ascent` offset
        /// added on top of the node's `core.transform.position`, matching
        /// exactly what the drawer computes).
        var baselineY: CGFloat
        var ascent: CGFloat
        var descent: CGFloat
        var width: CGFloat
    }

    /// Builds a one-line Latin text node whose shaped BASELINE lands at
    /// `wantBaselineY` in absolute canvas space, by shaping once up front
    /// (via the same `MKShapingEngine` the drawer uses) to learn the
    /// line's real ascent and back-computing the node's `position.y`
    /// (`position.y = wantBaselineY - ascent`, mirroring `LiveTextDrawer
    /// .draw`'s `lineOriginY = paragraph.lines[0].typographicBounds.ascent`).
    private func node(pointSize: Double, wantBaselineY: CGFloat, style: (inout MKTextStyle) -> Void) -> Built {
        var textStyle = MKTextStyle(pointSize: pointSize)
        textStyle.baseDirection = .leftToRight
        style(&textStyle)
        let text = MKSourceText(string: "IIIIIIIIIIIIIIIIIIII")
        let shaped = engine.shapeSingleLine(MKShapingRequest(text: text, style: textStyle, frame: .singleLine))
        let ascent = shaped.typographicBounds.ascent
        let descent = shaped.typographicBounds.descent
        let width = shaped.typographicBounds.width

        let core = MKNodeCore(name: "text", transform: MKTransform2D(position: CGPoint(x: 20, y: wantBaselineY - ascent)), style: MKStyle(fill: .solid(.black)))
        let liveNode = MKLiveTextNode(core: core, text: text, style: textStyle, frame: .singleLine)
        let ctFont = fonts.resolve(MKFontHandle(postScriptName: textStyle.font.postScriptName, pointSize: CGFloat(pointSize)))
        return Built(node: liveNode, ctFont: ctFont, baselineY: wantBaselineY, ascent: ascent, descent: descent, width: width)
    }

    private func render(_ built: Built, canvasSize: CGSize = CGSize(width: 400, height: 300)) -> CGImage {
        let scene = MKScene(
            canvas: MKCanvasSpec(size: canvasSize),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [.liveText(built.node)]
        )
        let ctx = makeContext(size: canvasSize)
        renderer.render(scene, region: CGRect(origin: .zero, size: canvasSize), into: ctx, scale: 1, quality: .exportQuality)
        return ctx.makeImage()!
    }

    /// True if any pixel in the vertical column `x`, rows `yRange`, is
    /// "dark" (all channels below `threshold`) ، tolerant of the exact row
    /// a thin 1-2px stroke lands on without needing pixel-exact metric
    /// prediction.
    private func columnContainsDarkPixel(_ image: CGImage, x: Int, yRange: ClosedRange<Int>, threshold: UInt8 = 120) -> Bool {
        for y in yRange where y >= 0 && y < image.height {
            let p = pixel(image, x: x, y: y)
            if p.r < threshold && p.g < threshold && p.b < threshold { return true }
        }
        return false
    }

    // MARK: - Highlight

    @Test func highlightPaintsBehindTheLineWrappingAscentAndDescent() {
        let built = node(pointSize: 40, wantBaselineY: 150) { $0.highlightColor = MKSolidColor(r: 0, g: 1, b: 0, a: 1) }
        let image = render(built)
        let x = Int(20 + built.width / 2)

        // Comfortably inside the line box (a few points above baseline,
        // within the ascent) must be highlight green.
        let inside = pixel(image, x: x, y: Int(built.baselineY - built.ascent / 2))
        #expect(inside.g > 200 && inside.r < 100, "expected green highlight inside the line box, got \(inside)")

        // Well above the top of the box (2x ascent above baseline) must
        // still be white ، exactly the bound a top/bottom sign inversion
        // blows through.
        let farAbove = pixel(image, x: x, y: max(0, Int(built.baselineY - built.ascent * 2 - 6)))
        #expect(farAbove.r > 240 && farAbove.g > 240 && farAbove.b > 240, "expected white background far above the line, got \(farAbove)")

        // Well below the bottom of the box (4x descent below baseline)
        // must also still be white.
        let farBelow = pixel(image, x: x, y: min(Int(built.node.core.transform.position.y) + 250, Int(built.baselineY + built.descent * 4 + 10)))
        #expect(farBelow.r > 240 && farBelow.g > 240 && farBelow.b > 240, "expected white background far below the line, got \(farBelow)")
    }

    @Test func noHighlightLeavesBackgroundUntouched() {
        let built = node(pointSize: 40, wantBaselineY: 150) { _ in }
        let image = render(built)
        let x = Int(20 + built.width / 2)
        let above = pixel(image, x: x, y: Int(built.baselineY - built.ascent - 8))
        #expect(above.r > 240 && above.g > 240 && above.b > 240)
    }

    // MARK: - Underline / strikethrough

    @Test func underlinePaintsBelowBaselineAtTheFontsOwnPosition() {
        let built = node(pointSize: 48, wantBaselineY: 150) { $0.isUnderline = true }
        let image = render(built)
        let x = Int(20 + built.width / 2)

        let underlinePosition = CTFontGetUnderlinePosition(built.ctFont)
        #expect(underlinePosition <= 0, "test assumption: this font's underline sits at/below baseline")
        let expectedY = Int(built.baselineY - underlinePosition)
        #expect(expectedY > Int(built.baselineY), "underline must be below the baseline in document (y-down) space")

        #expect(columnContainsDarkPixel(image, x: x, yRange: (expectedY - 4)...(expectedY + 4)), "expected an underline stroke near the font's own offset below baseline")
        // And nothing dark well ABOVE the baseline (rules out a sign flip
        // that painted the stroke above instead of below).
        #expect(!columnContainsDarkPixel(image, x: x, yRange: Int(built.baselineY - built.ascent)...Int(built.baselineY - 6)), "did not expect a dark stroke above the baseline")
    }

    @Test func noUnderlineLeavesTheOffsetRowUntouched() {
        let built = node(pointSize: 48, wantBaselineY: 150) { _ in }
        let image = render(built)
        let x = Int(20 + built.width / 2)
        let underlinePosition = CTFontGetUnderlinePosition(built.ctFont)
        let expectedY = Int(built.baselineY - underlinePosition)
        #expect(!columnContainsDarkPixel(image, x: x, yRange: (expectedY - 4)...(expectedY + 4)), "expected no underline stroke with isUnderline == false")
    }

    @Test func strikethroughPaintsAboveBaselineAtHalfXHeight() {
        let built = node(pointSize: 48, wantBaselineY: 150) { $0.isStrikethrough = true }
        let image = render(built)
        let x = Int(20 + built.width / 2)

        let halfXHeight = CTFontGetXHeight(built.ctFont) / 2
        let expectedY = Int(built.baselineY - halfXHeight)   // above baseline → smaller document y
        #expect(expectedY < Int(built.baselineY))

        #expect(columnContainsDarkPixel(image, x: x, yRange: (expectedY - 4)...(expectedY + 4)), "expected a strikethrough stroke near half x-height above baseline")
        // And nothing dark well below the baseline (rules out a sign flip).
        #expect(!columnContainsDarkPixel(image, x: x, yRange: Int(built.baselineY + 6)...Int(built.baselineY + built.descent)), "did not expect a dark stroke below the baseline")
    }
}
