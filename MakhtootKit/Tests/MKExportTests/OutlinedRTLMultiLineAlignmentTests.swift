import Testing
import CoreGraphics
import CoreText
import Foundation
import MKFoundation
import MKModel
import MKTextEngine
@testable import MKExport

// MASTER-PLAN Phase-2 RTL-alignment bug, THIRD copy: `MKExport/SVGSerializer
// .renderLiveText`'s license-outline branch (`SVGRTLMultiLineAlignmentTests`
// already covers the sibling non-outlined `<text>` route) and
// `PDFVectorExporter`/`MKOutlineSubstitutePainter`'s restricted-font route
// both draw multi-line RTL live text via `MKTextOutlining.outlineLiveText`,
// which pinned every line's origin at a hardcoded `x: 0` instead of calling
// `paragraph.lineOriginX(lineWidth:baseDirection:)` (the same helper
// `LiveTextDrawer.draw`/`SVGTextWriter` already use) ، so a restricted-font
// (outlined) multi-line Arabic export rendered flush-LEFT, ragged-right,
// backwards from the required flush-RIGHT/ragged-left RTL layout.
//
// This test exercises `MKTextOutlining.outlineLiveText` directly (the exact
// function that owned the bug), not through the license/hidden-node
// machinery `PDFVectorExporterTests`/`SVGSerializerTests` use for the
// restricted-font PLUMBING ، this is a focused geometry test of the
// outlining math itself.
//
// Recovering each line's used origin.x from the flat, per-glyph
// `GlyphOutline` array: `outlineLine` sets
// `localTransform = flip.concatenating(translation(origin.x + position.x, origin.y - position.y))`,
// so for any glyph, `localTransform.tx - position.x == origin.x` exactly.
// This test independently re-shapes the SAME request via `MKShapingEngine`
// (never calling the production `paragraph.lineOriginX` helper) to recover
// each glyph's own `position.x`, then solves for the origin.x the export
// path actually used and compares it against `boxWidth - lineWidth`,
// computed by hand ، the same non-circular style
// `SVGRTLMultiLineAlignmentTests` uses.
@Suite struct OutlinedRTLMultiLineAlignmentTests {
    private let pointSize = 24.0
    private let maxWidth: CGFloat = 120
    // Same fixture as `SVGRTLMultiLineAlignmentTests`: verified elsewhere to
    // wrap to >= 2 lines, with a genuinely shorter line, at this size/width.
    private let text = "بسم الله الرحمن الرحيم وعلى آله وصحبه أجمعين"

    private func makeNode(direction: MKBaseDirection, frame: MKTextFrameSpec) -> MKLiveTextNode {
        let style = MKTextStyle(font: TestScenes.realFontRef, pointSize: pointSize, baseDirection: direction)
        return MKLiveTextNode(
            core: MKNodeCore(name: "Text", transform: MKTransform2D(position: CGPoint(x: 20, y: 60)), style: MKStyle(fill: .solid(.black))),
            text: MKSourceText(string: text),
            style: style,
            frame: frame
        )
    }

    @Test func outlinedRTLLinesRightFlushAgainstTheSharedBoxNotLeftFlushAtZero() throws {
        let frame = MKTextFrameSpec.widthConstrained(width: Double(maxWidth))
        let node = makeNode(direction: .rightToLeft, frame: frame)
        let fonts = SystemFontStubProvider()

        // Independently re-shape (never calling `paragraph.lineOriginX`
        // itself) to know each glyph's own `position.x` and each line's own
        // width/the shared box width.
        let engine = MKShapingEngine(fonts: fonts)
        let paragraph = engine.shapeParagraph(MKShapingRequest(text: node.text, style: node.style, frame: frame))
        #expect(paragraph.lines.count >= 2, "fixture must wrap to multiple lines for this test to be meaningful")
        let boxWidth = paragraph.lines.map(\.typographicBounds.width).max() ?? 0
        let minWidth = paragraph.lines.map(\.typographicBounds.width).min() ?? 0
        #expect(minWidth < boxWidth - 15, "need a genuinely shorter line vs. the box width to test the fix")

        // Flatten expected per-glyph `position.x`, tagged with which line it
        // came from, in the EXACT order `outlineLiveText`/`outlineLine`
        // themselves walk (line, then run, then glyph) ، but ONLY for
        // glyphs that actually produce a drawable path.
        // `CTFontCreatePathForGlyph` returns `nil` for glyphs with no
        // path (space chief among them), and `outlineLine` silently
        // `continue`s past those (see `guard let glyphPath = ... else {
        // continue }` in `TextOutlining.swift`), so a flat, unfiltered
        // per-position list does NOT line up index-for-index with
        // `outlines` below ، empirically 34 outlines vs 41 shaped
        // positions for this fixture. Rather than assume every glyph
        // produces a path (the assumption this test originally made, and
        // which is false), this independently re-derives, per glyph,
        // whether `CTFontCreatePathForGlyph` would skip it, using the
        // SAME font-resolution `outlineLine` uses (`fonts.resolve` with
        // the run's own `postScriptName`/`pointSize`) ، a real CoreText
        // call, not a call into any production helper under test ، so
        // the filtered list is aligned with `outlines` BY CONSTRUCTION,
        // not by a positional-index guess.
        var expectedPositionX: [CGFloat] = []
        var expectedLineIndex: [Int] = []
        for (lineIndex, line) in paragraph.lines.enumerated() {
            for run in line.runs {
                let ctFont = fonts.resolve(MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize))
                for (index, glyph) in run.glyphs.enumerated() {
                    guard CTFontCreatePathForGlyph(ctFont, glyph, nil) != nil else { continue }
                    expectedPositionX.append(run.positions[index].x)
                    expectedLineIndex.append(lineIndex)
                }
            }
        }

        let outlines = MKTextOutlining.outlineLiveText(node, fonts: fonts)
        #expect(
            outlines.count == expectedPositionX.count,
            "expected one GlyphOutline per glyph that produces a path (got \(outlines.count) outlines for \(expectedPositionX.count) path-producing glyphs) ، a mismatch here would mean outlineLine's own path-skipping logic diverged from this independently-derived filter"
        )

        // Recover the origin.x `outlineLiveText` actually used for each
        // line: `localTransform.tx == origin.x + position.x` by
        // construction (see `outlineLine`), so `tx - position.x ==
        // origin.x`.
        var recoveredOriginByLine: [Int: CGFloat] = [:]
        for (i, outline) in outlines.enumerated() {
            let lineIndex = expectedLineIndex[i]
            let recoveredOrigin = outline.localTransform.tx - expectedPositionX[i]
            if let existing = recoveredOriginByLine[lineIndex] {
                #expect(abs(existing - recoveredOrigin) < 0.01, "every glyph on the same line must share one line origin.x")
            } else {
                recoveredOriginByLine[lineIndex] = recoveredOrigin
            }
        }

        let longestLineIndex = paragraph.lines.enumerated().max(by: { $0.element.typographicBounds.width < $1.element.typographicBounds.width })!.offset
        let shortestLineIndex = paragraph.lines.enumerated().min(by: { $0.element.typographicBounds.width < $1.element.typographicBounds.width })!.offset
        let longestWidth = paragraph.lines[longestLineIndex].typographicBounds.width
        let shortestWidth = paragraph.lines[shortestLineIndex].typographicBounds.width

        let longestOrigin = try #require(recoveredOriginByLine[longestLineIndex])
        let shortestOrigin = try #require(recoveredOriginByLine[shortestLineIndex])

        // The bug hardcoded EVERY line's origin.x at 0 (flush left, ragged
        // right). The fix must right-flush: the widest line sits at the
        // box's left edge (origin.x == boxWidth - boxWidth == 0) and every
        // narrower line is pushed right by `boxWidth - lineWidth`, so a
        // genuinely shorter line's origin.x must be strictly GREATER than
        // the longest line's ، a direction-sensitive assertion a "some x is
        // non-zero" check would miss entirely.
        #expect(abs(longestOrigin - Double(boxWidth - longestWidth)) < 0.5, "longest line's recovered origin.x must match boxWidth - its own width (\(boxWidth - longestWidth)), got \(longestOrigin)")
        #expect(abs(shortestOrigin - Double(boxWidth - shortestWidth)) < 0.5, "shortest line's recovered origin.x must match boxWidth - its own width (\(boxWidth - shortestWidth)), got \(shortestOrigin)")
        #expect(shortestOrigin > longestOrigin, "a shorter RTL line must be pushed further right (larger origin.x) than the longest line ، flush-right, ragged-left, got shortest=\(shortestOrigin) longest=\(longestOrigin)")
    }

    @Test func outlinedLTRLinesRemainFlushLeftAtZeroUnchanged() throws {
        let frame = MKTextFrameSpec.widthConstrained(width: Double(maxWidth))
        let node = makeNode(direction: .leftToRight, frame: frame)
        let fonts = SystemFontStubProvider()

        let engine = MKShapingEngine(fonts: fonts)
        let paragraph = engine.shapeParagraph(MKShapingRequest(text: node.text, style: node.style, frame: frame))
        #expect(paragraph.lines.count >= 2, "fixture must wrap to multiple lines for this test to be meaningful")

        // Same path-producing-glyph filter as the RTL test above ، see
        // that test's comment for why a flat, unfiltered per-position
        // list does not line up index-for-index with `outlines`.
        var expectedPositionX: [CGFloat] = []
        var expectedLineIndex: [Int] = []
        for (lineIndex, line) in paragraph.lines.enumerated() {
            for run in line.runs {
                let ctFont = fonts.resolve(MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize))
                for (index, glyph) in run.glyphs.enumerated() {
                    guard CTFontCreatePathForGlyph(ctFont, glyph, nil) != nil else { continue }
                    expectedPositionX.append(run.positions[index].x)
                    expectedLineIndex.append(lineIndex)
                }
            }
        }

        let outlines = MKTextOutlining.outlineLiveText(node, fonts: fonts)
        #expect(
            outlines.count == expectedPositionX.count,
            "expected one GlyphOutline per glyph that produces a path (got \(outlines.count) outlines for \(expectedPositionX.count) path-producing glyphs)"
        )

        var recoveredOriginByLine: [Int: CGFloat] = [:]
        for (i, outline) in outlines.enumerated() {
            let lineIndex = expectedLineIndex[i]
            let recoveredOrigin = outline.localTransform.tx - expectedPositionX[i]
            recoveredOriginByLine[lineIndex] = min(recoveredOriginByLine[lineIndex] ?? recoveredOrigin, recoveredOrigin)
        }

        for lineIndex in paragraph.lines.indices {
            let origin = try #require(recoveredOriginByLine[lineIndex])
            #expect(abs(origin - 0.0) < 0.5, "every LTR line's origin.x must remain 0 (unchanged prior behavior), got \(origin) for line \(lineIndex)")
        }
    }
}
