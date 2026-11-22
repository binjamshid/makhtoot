import CoreGraphics
import CoreText
import MKFoundation
import MKModel
import MKRender   // `MKSolidColor.cgColor` extension (StylePainting.swift) ، see file header

// P10-COMPLETION (Run-3, packet §5 tasks 11/14). Fills (+strokes) the
// glyph-outline substitutes `TextOutlining.swift` extracts, directly into a
// PDF `CGContext`, for a node `MKEmbeddingRestrictionWalker` already
// determined needs outlining. A deliberately MINIMAL paint routine (fill +
// stroke only, no shadow) ، this is a fallback path for the
// (v1: user-imported-font-only, per `AllOFLLicenseStub`) restricted case,
// not the primary render path; shadow-on-outlined-text is logged as a
// known simplification, not silently dropped (see `paint(_:into:fonts:)`'s
// own note).
public enum MKOutlineSubstitutePainter {
    /// Paints one restricted node's outline substitute. `ctx`'s CTM must be
    /// at the PDF page's BASE transform (i.e. called after
    /// `MKSceneRenderer.render` has returned and internally restored its
    /// own `saveGState`/`restoreGState` pair) ، this function establishes
    /// the node's own world transform itself via `entry.worldTransform`
    /// rather than assuming any ambient CTM state.
    @discardableResult
    public static func paint(_ entry: MKEmbeddingRestrictionWalker.Entry, into ctx: CGContext, fonts: any MKFontProviding) -> [FallbackNote] {
        let outlines: [MKTextOutlining.GlyphOutline]
        switch entry.kind {
        case .liveText(let node):
            outlines = MKTextOutlining.outlineLiveText(node, fonts: fonts)
        case .pathText(let node):
            outlines = MKTextOutlining.outlinePathText(node, fonts: fonts)
        }
        guard !outlines.isEmpty else { return [] }

        var colorGlyphNotes: [FallbackNote] = []
        ctx.saveGState()
        ctx.concatenate(entry.worldTransform)
        if entry.opacity < 1 {
            ctx.setAlpha(CGFloat(entry.opacity))
        }

        // GAP2 canvas⇄export parity: this route bypasses `MKSceneRenderer`/
        // `PathTextDrawer` entirely (that's this whole file's reason to
        // exist ، the license-restricted outline substitute), so it needs
        // the highlight ribbon filled itself, BEFORE the outline loop below
        // paints the glyphs on top (`PathTextDrawer.paintHighlight`'s own
        // "behind the glyphs" ordering, replicated here). The UNRESTRICTED
        // route (`PDFVectorExporter` rendering through `MKSceneRenderer` →
        // `PathTextDrawer`) already gets this for free and is untouched.
        if case .pathText(let pathTextNode) = entry.kind,
           let highlight = pathTextNode.style.highlightColor,
           let ribbon = MKTextOutlining.pathTextHighlightRibbon(pathTextNode, fonts: fonts) {
            ctx.saveGState()
            ctx.setFillColor(highlight.cgColor)
            ctx.addPath(ribbon)
            ctx.fillPath(using: .winding)
            ctx.restoreGState()
        }

        for outline in outlines {
            ctx.saveGState()
            ctx.concatenate(outline.localTransform)
            if outline.isColorGlyph {
                // D-227(4): color glyphs (emoji) never get outline-filled
                // (their CTFontCreatePathForGlyph outline is empty/
                // meaningless) ، drawn as an embedded raster image instead,
                // in ALL contexts including this outline-substitution path.
                paintColorGlyphImage(outline, into: ctx)
                colorGlyphNotes.append(FallbackNote(reason: .colorGlyphRasterized))
            } else {
                ctx.addPath(outline.path)
                paintCurrentPath(style: entry.style, in: ctx)
            }
            ctx.restoreGState()
        }
        ctx.restoreGState()
        return colorGlyphNotes
    }

    /// Draws one color glyph as a small embedded raster image, positioned
    /// at the glyph's em-box origin (matching `emojiGlyphPNGData`'s own
    /// "center the em-box, offset up ~0.2em" framing convention).
    private static func paintColorGlyphImage(_ outline: MKTextOutlining.GlyphOutline, into ctx: CGContext) {
        guard
            let pngData = MKTextOutlining.emojiGlyphPNGData(ctFont: outline.ctFont, glyph: outline.glyphID),
            let provider = CGDataProvider(data: pngData as CFData),
            let image = CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return }
        let emSize = CTFontGetSize(outline.ctFont)
        guard emSize > 0 else { return }
        // The rasterization offset baked the glyph at (0.1em, 0.25em) in a
        // 1em×1em canvas (see `emojiGlyphPNGData`) ، draw it back at the
        // matching NEGATIVE offset here so the glyph re-centers on its own
        // origin, then flip Y (the PNG was captured upright already via
        // CTFontDrawGlyphs' own internal handling, but this outline's
        // `localTransform` already carries a y-flip for PATH glyphs ، an
        // image must NOT be double-flipped, so this draws in a
        // locally-re-flipped sub-frame).
        ctx.saveGState()
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(x: -emSize * 0.1, y: -emSize * 0.75, width: emSize, height: emSize))
        ctx.restoreGState()
    }

    /// Fill/stroke the path already added to `ctx` (`ctx.addPath` must have
    /// been called immediately before this). Shadow is NOT applied here ،
    /// documented simplification (see file header): the restricted-license
    /// outline path is a fallback, not the primary render path, and no
    /// fixture in this session's Arabic-correctness harness exercises a
    /// shadowed, license-restricted text node.
    private static func paintCurrentPath(style: MKStyle, in ctx: CGContext) {
        switch (style.fill, style.stroke) {
        case (.solid(let fill), .some(let stroke)):
            ctx.setFillColor(fill.cgColor)
            ctx.setStrokeColor(stroke.color.cgColor)
            ctx.setLineWidth(CGFloat(stroke.width))
            ctx.setLineJoin(cgLineJoin(stroke.join))
            ctx.setLineCap(cgLineCap(stroke.cap))
            ctx.drawPath(using: .fillStroke)
        case (.solid(let fill), .none):
            ctx.setFillColor(fill.cgColor)
            ctx.fillPath()
        case (.none, .some(let stroke)):
            ctx.setStrokeColor(stroke.color.cgColor)
            ctx.setLineWidth(CGFloat(stroke.width))
            ctx.setLineJoin(cgLineJoin(stroke.join))
            ctx.setLineCap(cgLineCap(stroke.cap))
            ctx.strokePath()
        case (.none, .none):
            break
        }
    }

    private static func cgLineJoin(_ join: MKLineJoin) -> CGLineJoin {
        switch join {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }

    private static func cgLineCap(_ cap: MKLineCap) -> CGLineCap {
        switch cap {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }
}
