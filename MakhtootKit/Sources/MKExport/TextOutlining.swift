import CoreGraphics
import CoreText
import Foundation
import ImageIO
import MKFoundation
import MKModel
import MKPathText
import MKTextEngine

// P10-COMPLETION (Run-3, packet §5 tasks 11/14). D-118/§16.5's per-license
// text-vs-outline switch: "live text in OFL fonts draws as text with subset
// embedding, otherwise outlines (per-license switch)." §16.3/D-118 also
// says "no per-format drawing code ، only per-format context construction
// and encoding," which `MKRender`'s drawers already satisfy for the
// EMBED-AS-TEXT case (handing `MKSceneRenderer.render` a PDF `CGContext`
// directly makes `LiveTextDrawer`'s existing `CTFontDrawGlyphs` calls
// produce real, automatically-subset-embedded PDF text ، verified in
// `PDFVectorExporterTests`).
//
// **The OUTLINE case is the genuine gap this file closes, and closing it
// here (not in `MKRender`) is a deliberate fence decision, not an
// oversight**: `MKRender`'s `LiveTextDrawer`/`PathTextDrawer` have no
// license/embedding-rights concept at all (by design ، `MKRender` draws
// the SAME way regardless of caller, matching every other "single render
// path" node kind) and this packet's fence is `MKExport`/`MKColor`
// sources only ، `MKRender` is explicitly out of scope ("no one else is
// editing" per this session's own task packet). Adding a
// license-conditional branch to `LiveTextDrawer` would also violate
// §16.3's own "no per-format drawing code" rule from the OTHER direction
// (the editor's live preview has no license-outline concept and must
// never draw outlines for on-screen editing).
//
// So: for a live-text/path-text node whose font lacks the target format's
// embedding right, `PDFVectorExporter`/`SVGSerializer` render a scene COPY
// with that node HIDDEN (`isHidden = true`, the exact same "value-type
// scene copy" pattern `ExportCoordinator.preparedScene` already uses for
// background-hiding), then draw an OUTLINE SUBSTITUTE for that node
// directly, using THIS file's `MKTextOutlining` helper ، which re-shapes
// the text via `MKShapingEngine` (the SAME engine
// `LiveTextDrawer`/`PathTextDrawer` already call; NOT a second, competing
// shaping implementation) and extracts `CTFontCreatePathForGlyph` outlines
// instead of calling `CTFontDrawGlyphs`. This mirrors `LiveTextDrawer`'s
// OWN existing outline-stroke branch (lines ~119-144 of that file) ، the
// exact same "extract glyph outlines instead of drawing glyphs directly"
// technique already lives in this codebase for a different reason
// (stroke-on-text); this file applies it for a different trigger
// (license), independently, in the module that owns the license concept.
public enum MKTextOutlining {
    /// One glyph's raw outline (font/em-unit space, CoreText y-up,
    /// UN-positioned) plus the affine that maps it into the OWNING NODE's
    /// local space (document/canvas convention: y-down, top-left origin ،
    /// i.e. the same space `ShapeDrawer`'s CGPaths live in, BEFORE
    /// `node.core.transform` is applied). Callers concatenate
    /// `node.core.transform` on top (PDF: `ctx.concatenate(...)`; SVG: a
    /// wrapping `<g transform="matrix(...)">`), exactly matching how
    /// `SceneRenderer.drawTopLevel` applies the node transform once and
    /// lets each drawer work in node-local space beneath it.
    /// `@unchecked Sendable`: `CGPath` is a Core Foundation opaque
    /// reference type with no compiler-visible `Sendable` conformance
    /// anywhere in this dependency graph, but is immutable-after-creation
    /// and safe to pass across isolation domains in practice (`CTFont`,
    /// this struct's OTHER CF-opaque field, already has a retroactive
    /// `@unchecked Sendable` conformance declared in
    /// `MKFonts/MKFontsCTFontSendable.swift`, visible here since
    /// `MKExport` depends on `MKFonts` ، same "immutable CF type, safe to
    /// share" reasoning applies to `CGPath`, just without an existing
    /// declared conformance to reuse). `GlyphOutline` values are only ever
    /// produced and consumed synchronously within one export call in this
    /// module ، never stored/retained across an `await` boundary ، so
    /// this is a documented, low-risk `@unchecked` use, not a blanket
    /// escape hatch.
    public struct GlyphOutline: @unchecked Sendable {
        public var path: CGPath
        public var localTransform: CGAffineTransform
        /// Source codepoints this glyph's cluster covers (SVG provenance,
        /// D-227(2)) ، best-effort from `MKClusterMap`, empty if
        /// unavailable.
        public var codepoints: [UInt32]
        public var fontPostScriptName: String
        public var ctFont: CTFont
        public var glyphID: CGGlyph
        /// D-227(4)/§16.6: true when `codepoints` indicate an
        /// Extended_Pictographic (emoji/color-glyph) cluster ،
        /// `CTFontCreatePathForGlyph` returns an empty/meaningless outline
        /// for COLR/CBDT/sbix color glyphs, so callers must render `image`
        /// content instead of `path` fill for these (see
        /// `emojiGlyphPNG(ctFont:glyph:)` below).
        public var isColorGlyph: Bool
    }

    /// D-227(4): "emoji/color-glyph... in ALL contexts, including as a
    /// child of an otherwise-vector arranged group ، a deliberate
    /// carve-out." `Unicode.Scalar.Properties.isEmojiPresentation` is used
    /// (not the broader `isEmoji`, which also flags plain ASCII digits/`#`/
    /// `*` that are emoji ONLY in combination with U+FE0F) so a bare Arabic
    /// digit doesn't get misclassified as a color glyph.
    public static func isEmojiCluster(_ codepoints: [UInt32]) -> Bool {
        codepoints.contains { codepoint in
            guard let scalar = Unicode.Scalar(codepoint) else { return false }
            return scalar.properties.isEmojiPresentation || scalar.value == 0xFE0F
        }
    }

    /// Rasterizes ONE glyph (color or not ، used only for glyphs already
    /// identified as color glyphs) via `CTFontDrawGlyphs` (which, unlike
    /// `CTFontCreatePathForGlyph`, correctly renders COLR/CBDT/sbix color
    /// tables) into a small, tightly-cropped-to-em-box PNG, for embedding
    /// as an `<image>`/PDF image XObject (D-227(4)).
    public static func emojiGlyphPNGData(ctFont: CTFont, glyph: CGGlyph, pixelSize: Int = 128) -> Data? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let emSize = CTFontGetSize(ctFont)
        guard emSize > 0 else { return nil }
        let scale = CGFloat(pixelSize) / emSize
        // Center the glyph's em-box in the bitmap: CoreText glyph space is
        // y-up with baseline at y=0 ، offset up by ~0.2em so typical
        // emoji (which sit mostly above the baseline) are framed
        // reasonably; not pixel-perfect bounds-fitting (unnecessary for a
        // fallback rasterization), documented simplification.
        ctx.translateBy(x: CGFloat(pixelSize) * 0.1, y: CGFloat(pixelSize) * 0.25)
        ctx.scaleBy(x: scale, y: scale)
        var glyphs = [glyph]
        var positions = [CGPoint.zero]
        CTFontDrawGlyphs(ctFont, &glyphs, &positions, 1, ctx)
        guard let image = ctx.makeImage() else { return nil }
        guard let destinationData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(destinationData, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return destinationData as Data
    }

    /// Live text → outlines, one flat array across all lines/runs, in
    /// NODE-LOCAL space. Mirrors `LiveTextDrawer.draw`'s exact line-origin/
    /// flip math (see that file's header), INCLUDING `paragraph.lineOriginX`'s
    /// direction-aware per-line x offset (D-109/MASTER-PLAN Phase-2), so an
    /// outlined export is pixel-identical in POSITION to the text-mode
    /// render ، only the draw technique (fill-a-path vs `CTFontDrawGlyphs`)
    /// differs. This is the THIRD copy of this line-origin math
    /// (`LiveTextDrawer.swift:58-62`, `SVGTextWriter.swift:104`, here) ،
    /// a future change to the alignment rule must touch all three.
    public static func outlineLiveText(_ node: MKLiveTextNode, fonts: any MKFontProviding) -> [GlyphOutline] {
        guard !node.text.string.isEmpty else { return [] }
        let engine = MKShapingEngine(fonts: fonts)
        let request = MKShapingRequest(text: node.text, style: node.style, frame: node.frame)
        let paragraph = engine.shapeParagraph(request)
        guard !paragraph.lines.isEmpty else { return [] }

        var outlines: [GlyphOutline] = []
        let lineHeight = CGFloat(node.style.lineHeightMultiple * node.style.pointSize)
        var lineOriginY: CGFloat = paragraph.lines[0].typographicBounds.ascent
        for line in paragraph.lines {
            let x = paragraph.lineOriginX(lineWidth: line.typographicBounds.width, baseDirection: node.style.baseDirection)
            outlines.append(contentsOf: outlineLine(line, origin: CGPoint(x: x, y: lineOriginY), fonts: fonts))
            lineOriginY += lineHeight
        }
        return outlines
    }

    private static func outlineLine(_ line: MKShapedLine, origin: CGPoint, fonts: any MKFontProviding) -> [GlyphOutline] {
        var result: [GlyphOutline] = []
        let flip = CGAffineTransform(scaleX: 1, y: -1)
        for run in line.runs {
            let ctFont = fonts.resolve(MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize))
            for (index, glyph) in run.glyphs.enumerated() {
                guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else { continue }
                let position = run.positions[index]
                let localTransform = flip.concatenating(
                    CGAffineTransform(translationX: origin.x + position.x, y: origin.y - position.y)
                )
                let stringIndex = index < run.stringIndices.count ? run.stringIndices[index] : run.stringRange.lowerBound
                let codepoints = codepointsAt(stringIndex, in: line)
                result.append(GlyphOutline(
                    path: glyphPath, localTransform: localTransform, codepoints: codepoints,
                    fontPostScriptName: run.font.postScriptName, ctFont: ctFont, glyphID: glyph,
                    isColorGlyph: isEmojiCluster(codepoints)
                ))
            }
        }
        return result
    }

    /// Path text → outlines placed/rotated along the path (WS08-A5 ADR:
    /// "no textPath ، path text exported as placed glyphs" ، this applies
    /// to BOTH the PDF license-outline case AND, unconditionally, the SVG
    /// writer, per that ADR). Mirrors `PathTextDrawer.draw`'s exact
    /// translate/rotate/flip math.
    public static func outlinePathText(_ node: MKPathTextNode, fonts: any MKFontProviding) -> [GlyphOutline] {
        guard !node.text.string.isEmpty else { return [] }
        let pathModel = BezierPathModel(node.path)
        let lut = ArcLengthLUT(path: pathModel)
        guard lut.totalLength > 0 else { return [] }

        let engine = MKShapingEngine(fonts: fonts)
        let request = MKShapingRequest(text: node.text, style: node.style, frame: .singleLine)
        let line = engine.shapeSingleLine(request)
        let options = PathLayoutOptions(node: node.layout)
        let result = node.path.isClosed
            ? PathLayoutEngine.layoutClosed(line: line, lut: lut, options: options)
            : PathLayoutEngine.layout(line: line, lut: lut, options: options)

        var outlines: [GlyphOutline] = []
        let flip = CGAffineTransform(scaleX: 1, y: -1)
        for placement in result.placements {
            let run = line.runs[placement.address.run]
            let glyphIndex = placement.address.glyph
            guard glyphIndex < run.glyphs.count else { continue }
            let ctFont = fonts.resolve(MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize))
            let glyph = run.glyphs[glyphIndex]
            guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else { continue }
            let localTransform = flip
                .concatenating(CGAffineTransform(rotationAngle: placement.rotation))
                .concatenating(CGAffineTransform(translationX: placement.position.x, y: placement.position.y))
            let stringIndex = glyphIndex < run.stringIndices.count ? run.stringIndices[glyphIndex] : run.stringRange.lowerBound
            let codepoints = codepointsAt(stringIndex, in: line)
            outlines.append(GlyphOutline(
                path: glyphPath, localTransform: localTransform, codepoints: codepoints,
                fontPostScriptName: run.font.postScriptName, ctFont: ctFont, glyphID: glyph,
                isColorGlyph: isEmojiCluster(codepoints)
            ))
        }
        return outlines
    }

    /// GAP2 canvas⇄export parity: path-text's swept-ribbon highlight
    /// (`PathHighlightRibbon`, `MKPathText`), built in the SAME node-local
    /// placement space `outlinePathText`'s glyph outlines above are
    /// computed in (both share `lut`/`line`/`result`'s coordinate
    /// convention, so a caller that already wraps `outlinePathText`'s
    /// outlines in the node's own transform can wrap THIS path in the
    /// identical transform with no separate re-basing).
    ///
    /// Returns `nil` when the node has no highlight color, an empty/
    /// degenerate path, or the resolved ribbon geometry is empty (mirrors
    /// `PathHighlightRibbon.path(...)`'s own `nil`-for-degenerate
    /// contract).
    ///
    /// This function DUPLICATES `MKRender/Drawers/PathTextDrawer
    /// .paintHighlight`'s own orchestration (closed-path arc-length
    /// wrapping, `.clip`-overflow span clamping) rather than sharing it
    /// directly ، that orchestration is `private` to a drawer file in
    /// `MKRender`, which is out of this session's fence ("no one else is
    /// editing" / another agent owns `MKRender` except this file's own
    /// `LiveTextDrawer.swift` fence-carve-out). The GENUINELY shared
    /// primitive, `PathHighlightRibbon.path(...)` itself (the actual
    /// per-rung geometry math), IS reused here, not re-derived ، only the
    /// "which arc-length span(s) to ask it for" bookkeeping is duplicated,
    /// matching this file's own existing precedent of duplicating
    /// `PathTextDrawer.draw`'s translate/rotate/flip math in
    /// `outlinePathText` above for the identical structural reason.
    public static func pathTextHighlightRibbon(_ node: MKPathTextNode, fonts: any MKFontProviding) -> CGPath? {
        guard node.style.highlightColor != nil, !node.text.string.isEmpty else { return nil }
        let pathModel = BezierPathModel(node.path)
        let lut = ArcLengthLUT(path: pathModel)
        guard lut.totalLength > 0 else { return nil }

        let engine = MKShapingEngine(fonts: fonts)
        let request = MKShapingRequest(text: node.text, style: node.style, frame: .singleLine)
        let line = engine.shapeSingleLine(request)
        let options = PathLayoutOptions(node: node.layout)
        let result = node.path.isClosed
            ? PathLayoutEngine.layoutClosed(line: line, lut: lut, options: options)
            : PathLayoutEngine.layout(line: line, lut: lut, options: options)

        let ascent = line.typographicBounds.ascent
        let descent = line.typographicBounds.descent
        let baselineOffset = CGFloat(options.signedBaselineOffset)
        let combined = CGMutablePath()

        if node.path.isClosed {
            // Closed-path wrap: `result.penStartArcLength`/`.penEndArcLength`
            // are UNWRAPPED cumulative pen values (`PathLayoutResult`'s own
            // doc comment) ، resolve against the cycle exactly the way
            // `PathTextDrawer.paintHighlight` does.
            let cycleLength = lut.totalLength + CGFloat(options.closedPathGap)
            let effectiveTotal = result.penEndArcLength - result.penStartArcLength
            if cycleLength <= 0 || effectiveTotal >= lut.totalLength {
                if let ring = PathHighlightRibbon.path(
                    lut: lut, from: 0, to: lut.totalLength, ascent: ascent, descent: descent,
                    baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: .clip
                ) {
                    combined.addPath(ring)
                }
            } else {
                let wrappedStart = wrapClosedArcLength(result.penStartArcLength, cycleLength: cycleLength, totalLength: lut.totalLength)
                let wrappedEnd = wrapClosedArcLength(result.penEndArcLength, cycleLength: cycleLength, totalLength: lut.totalLength)
                if wrappedStart <= wrappedEnd {
                    if let seg = PathHighlightRibbon.path(
                        lut: lut, from: wrappedStart, to: wrappedEnd, ascent: ascent, descent: descent,
                        baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: .clip
                    ) {
                        combined.addPath(seg)
                    }
                } else {
                    // Span crosses the loop's own seam ، two contiguous
                    // sub-ribbons, unioned into one path.
                    if let seg1 = PathHighlightRibbon.path(
                        lut: lut, from: wrappedStart, to: lut.totalLength, ascent: ascent, descent: descent,
                        baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: .clip
                    ) {
                        combined.addPath(seg1)
                    }
                    if let seg2 = PathHighlightRibbon.path(
                        lut: lut, from: 0, to: wrappedEnd, ascent: ascent, descent: descent,
                        baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: .clip
                    ) {
                        combined.addPath(seg2)
                    }
                }
            }
        } else {
            var penEnd = result.penEndArcLength
            if options.overflow == .clip, result.overflow.isOverflowing {
                // `.clip`: a glyph past `lut.totalLength` produced NO
                // placement at all, so the theoretical full pen span can
                // overstate where the glyphs actually stopped ، clamp to
                // the last ACTUALLY EMITTED placement's own span end.
                var lastSpanEnd = result.penStartArcLength
                for placement in result.placements where !placement.isMark {
                    let advance = line.runs[placement.address.run].advances[placement.address.glyph].width
                    lastSpanEnd = max(lastSpanEnd, placement.arcLength + advance / 2)
                }
                penEnd = lastSpanEnd
            }
            if let ribbon = PathHighlightRibbon.path(
                lut: lut, from: result.penStartArcLength, to: penEnd, ascent: ascent, descent: descent,
                baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: options.overflow
            ) {
                combined.addPath(ribbon)
            }
        }

        guard !combined.isEmpty else { return nil }
        return combined
    }

    /// Mirrors `PathTextDrawer.paintHighlight`'s own private `wrap(_:)`-
    /// equivalent (`wrapClosedArcLength`) exactly: negative/gap-region
    /// values clamp to the path's own start/end rather than wrapping
    /// backward or sitting in the (visually non-existent) gap.
    private static func wrapClosedArcLength(_ s: CGFloat, cycleLength: CGFloat, totalLength: CGFloat) -> CGFloat {
        guard cycleLength > 0 else { return 0 }
        var w = max(0, s).truncatingRemainder(dividingBy: cycleLength)
        if w < 0 { w += cycleLength }
        return min(w, totalLength)
    }

    /// Best-effort codepoint lookup for a UTF-16 index via the line's
    /// cluster map (SVG provenance, D-227(2)) ، falls back to decoding the
    /// scalar directly from `line.sourceText` if the cluster map doesn't
    /// cover the index (never crashes on an out-of-range index).
    private static func codepointsAt(_ utf16Index: Int, in line: MKShapedLine) -> [UInt32] {
        if let clusterIndex = line.clusterMap.utf16ToCluster[utf16Index], clusterIndex < line.clusterMap.clusters.count {
            return line.clusterMap.clusters[clusterIndex].codepoints
        }
        let utf16 = Array(line.sourceText.utf16)
        guard utf16Index >= 0, utf16Index < utf16.count else { return [] }
        // `Unicode.Scalar(UInt32)` is the failable initializer (returns
        // `nil` for lone surrogate code units, which is correct ، a lone
        // surrogate is not a valid scalar) ، using the `UInt32` overload
        // explicitly rather than relying on a `UInt16` overload that may
        // not exist for every code-unit value.
        if let scalar = Unicode.Scalar(UInt32(utf16[utf16Index])) {
            return [scalar.value]
        }
        return []
    }
}
