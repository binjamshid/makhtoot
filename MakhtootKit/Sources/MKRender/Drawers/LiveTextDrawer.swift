import CoreGraphics
import CoreText
import MKFoundation
import MKModel
import MKTextEngine

// WS-07 packet §5 task 2. Draws `MKLiveTextNode` through the WS-03 shaping
// capture (D-104: "committed rendering of Live Text objects is always the
// MKTextEngine→MKRender path so canvas and export are pixel-identical").
// Uses `MKShapingEngine` (sync, pure ، WS-03) directly, NOT the cached
// `MKShapingService` actor: `MKSceneRenderer.render` is a synchronous,
// any-queue entry point (CONTRACTS.md), so an actor-isolated cache would
// force this call chain async. A render-side shaping cache (keyed off
// `MKContentHash`) is a natural P14 addition if profiling shows re-shaping
// cost matters; v1 re-shapes per draw, matching every other drawer's
// "no font I/O assumptions baked into cached geometry" simplicity.
//
// **Coordinate convention** (see `README.md` "Coordinate conventions" for
// the full statement): Core Text shapes in a y-up, line-relative space
// (`MKTextEngine/CoordinateSpace.swift`); MKRender's document/canvas space
// is y-down, top-left origin (matching D-114's UIKit canvas). This drawer
// applies the standard CoreText-in-a-flipped-context idiom: translate to
// each line's document-space origin, then locally re-flip (`scaleBy(x: 1,
// y: -1)`) before calling `CTFontDrawGlyphs` with RAW (un-flipped)
// CoreText-captured positions ، the local flip cancels the ambient
// document flip so glyphs render upright, exactly the pattern every
// CoreText-into-UIKit-view tutorial uses.
public struct LiveTextDrawer: Sendable {
    private let fonts: any MKFontProviding
    private let engine: MKShapingEngine

    public init(fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.fonts = fonts
        self.engine = MKShapingEngine(fonts: fonts)
    }

    public func draw(
        _ node: MKLiveTextNode, into ctx: CGContext, quality: MKRenderQuality, report: inout MKRenderReportBuilder
    ) {
        guard !node.text.string.isEmpty else { return }
        let request = MKShapingRequest(text: node.text, style: node.style, frame: node.frame)
        let paragraph = engine.shapeParagraph(request)
        guard !paragraph.lines.isEmpty else { return }

        let lineHeight = CGFloat(node.style.lineHeightMultiple * node.style.pointSize)
        var lineOriginY: CGFloat = paragraph.lines[0].typographicBounds.ascent

        // MASTER-PLAN Phase-2 RTL-alignment fix: a multi-line node's box is
        // `[0, paragraph.boxWidth]` (the WIDEST line's own width ،
        // `MKNodeLocalBounds.localBounds(of:)`'s `.liveText` case computes
        // the identical number for the node's bounding box), so drawing
        // every line at local x=0 left-aligns EVERY node regardless of its
        // own `baseDirection` ، correct for `.leftToRight` but backwards for
        // the D-109 RTL default: an Arabic paragraph's shorter lines must
        // hug the box's RIGHT edge (ragged left), not its left edge.
        // `paragraph.lineOriginX` resolves the per-line offset against the
        // node's real base direction (never a hardcoded "flush right").
        for line in paragraph.lines {
            let x = paragraph.lineOriginX(lineWidth: line.typographicBounds.width, baseDirection: node.style.baseDirection)
            drawLine(line, origin: CGPoint(x: x, y: lineOriginY), node: node, quality: quality, into: ctx, report: &report)
            lineOriginY += lineHeight
        }
    }

    private func drawLine(
        _ line: MKShapedLine, origin: CGPoint, node: MKLiveTextNode, quality: MKRenderQuality,
        into ctx: CGContext, report: inout MKRenderReportBuilder
    ) {
        let strokeOnly: MKStroke? = node.core.style.stroke
        let usesOutlineStroke = strokeOnly != nil

        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.scaleBy(x: 1, y: -1)   // re-flip: CoreText draws in y-up local space

        // P5.6 (Bug 11): highlight paints BEHIND the glyph runs and BEFORE
        // the node's own shadow is set, so a highlighted run's shadow (if
        // any) falls on the TEXT only, not on the highlight rect itself ،
        // matching how a text-editor's selection/highlight background
        // never casts its own drop shadow.
        if let highlight = node.style.highlightColor {
            paintHighlight(highlight, line: line, in: ctx)
        }

        MKStylePainting.paintReducedShadowIfNeeded(
            path: linePath(line), style: node.core.style, quality: quality, in: ctx)
        applyShadowIfFull(node.core.style.shadow, quality: quality, in: ctx)

        for run in line.runs {
            drawRun(run, node: node, usesOutlineStroke: usesOutlineStroke, into: ctx, report: &report, nodeID: node.core.id)
        }

        // P5.7 (Bug 9): underline/strikethrough, painted on top of the
        // glyph runs using the RESOLVED FONT's own underline metrics (§6
        // Arabic-correctness ، never a hardcoded offset, since Arabic
        // faces position tashkeel/descenders differently per family and a
        // fixed offset would collide with them for some fonts).
        if node.style.isUnderline || node.style.isStrikethrough {
            paintTextDecorations(node, line: line, into: ctx)
        }

        ctx.restoreGState()
    }

    /// One highlight rect per line, spanning the line's full typographic
    /// width and ascent+descent (so Arabic descenders/tashkeel sitting
    /// below the baseline are still covered, not just the Latin-style
    /// em-box). Ships for `LiveTextDrawer` (straight, non-path text) only
    /// ، `PathTextDrawer` places each glyph individually along an
    /// arbitrary curve with per-glyph rotation, so a matching per-glyph
    /// quad-strip highlight is real additional geometry work, deliberately
    /// out of this pass (`FontSettingsSheet`'s highlight-color UI states
    /// this scoping explicitly rather than shipping a broken curved
    /// highlight).
    private func paintHighlight(_ color: MKSolidColor, line: MKShapedLine, in ctx: CGContext) {
        guard line.typographicBounds.width > 0 else { return }
        // Local space here is CoreText's native y-up glyph space (the
        // active `ctx.scaleBy(x:1,y:-1)` re-flip, same space `run
        // .positions` are drawn in directly): above-baseline is POSITIVE
        // y, below-baseline (descent) is NEGATIVE y ، so the box's bottom
        // edge is `-descent`, growing upward by `ascent + descent` reaches
        // the top edge at `+ascent`. (Getting this sign backwards silently
        // produces a highlight rect shifted mostly BELOW the baseline
        // instead of wrapping the line ، caught by
        // `LiveTextHighlightAndDecorationTests` before this shipped.)
        let rect = CGRect(
            x: 0, y: -line.typographicBounds.descent,
            width: line.typographicBounds.width,
            height: line.typographicBounds.ascent + line.typographicBounds.descent
        )
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
        ctx.restoreGState()
    }

    /// Underline/strikethrough for one line, spanning its full
    /// typographic width. Every `MKTextStyle` is uniform across its whole
    /// node (no per-run style overrides exist in this model, WS-02), so
    /// the decoration's font metrics are resolved once, node-wide, never
    /// per-run (decorations stay node/line-wide, matching the highlight
    /// rect's own node-wide policy above).
    ///
    /// The metrics come from `node.style.font`/`.pointSize`, resolved
    /// through the SAME variant-resolution path
    /// `MKShapingEngine.resolvedFont(for:)` uses to pick the run's font in
    /// the first place: `fonts.resolve(handle, variant:
    /// MKFontVariantRequest(bold: node.style.isBold, italic:
    /// node.style.isItalic))`. Two things this deliberately does NOT do:
    /// - Resolve `node.style.font` with NO variant: a bold node's
    ///   `node.style.font` is still the UNBOLDED request, so a plain
    ///   resolve would draw a regular-weight underline/strikethrough under
    ///   bold text (bold cuts have thicker underlines and different
    ///   x-heights than their regular sibling).
    /// - Round-trip the run's captured PostScript name
    ///   (`line.runs.first?.font`) back through `fonts.resolve(_:)`. This
    ///   looks equivalent (the shaper captured exactly the resolved face's
    ///   name) but is NOT guaranteed to land back on the same `CTFont`:
    ///   system/fallback faces resolve through dot-prefixed names CoreText
    ///   does not reliably re-resolve by name alone (see
    ///   `SystemFontStubProvider`'s doc comment, `MKFoundation/Stubs/
    ///   MKFontProviding.swift`, on exactly this failure mode), and a
    ///   variable-font instance's PS name is not guaranteed to round-trip
    ///   to the same instance either. Re-deriving `(font, variant)` the
    ///   way the shaper does is deterministic and needs no name round-trip
    ///   at all ، do NOT reintroduce a `line.runs.first?.font` read here.
    ///
    /// - Underline: `CTFontGetUnderlinePosition`/`CTFontGetUnderlineThickness`
    ///   ، the font's OWN designed values (never a hardcoded offset), which
    ///   is exactly what makes this safe for Arabic: a script-appropriate
    ///   Arabic face positions its underline low enough to clear tashkeel
    ///   sitting below the baseline, a fixed constant tuned for Latin faces
    ///   would not.
    /// - Strikethrough: Core Text has no dedicated strikethrough-position
    ///   accessor (unlike underline) ، half the font's x-height is the
    ///   standard typographic convention (crosses through the visual
    ///   middle of lowercase/short letterforms), still font-metric-derived
    ///   rather than an arbitrary constant.
    private func paintTextDecorations(_ node: MKLiveTextNode, line: MKShapedLine, into ctx: CGContext) {
        guard case .solid(let color) = node.core.style.fill else { return }
        let width = line.typographicBounds.width
        guard width > 0 else { return }
        let handle = MKFontHandle(postScriptName: node.style.font.postScriptName, pointSize: CGFloat(node.style.pointSize))
        let variant = MKFontVariantRequest(bold: node.style.isBold, italic: node.style.isItalic)
        let ctFont = fonts.resolve(handle, variant: variant)
        let thickness = max(CTFontGetUnderlineThickness(ctFont), 1)

        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(thickness)

        if node.style.isUnderline {
            let y = CTFontGetUnderlinePosition(ctFont)
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: width, y: y))
            ctx.strokePath()
        }
        if node.style.isStrikethrough {
            let y = CTFontGetXHeight(ctFont) / 2
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: width, y: y))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private func applyShadowIfFull(_ shadow: MKShadow?, quality: MKRenderQuality, in ctx: CGContext) {
        guard quality.fidelity == .full, let shadow else { return }
        // The local CTM here is already flipped back to y-up for text
        // drawing (`scaleBy(x: 1, y: -1)` above) ، negate the shadow's own
        // y offset so it still reads as "down/right" in DOCUMENT space
        // regardless of this drawer's local re-flip.
        ctx.setShadow(offset: CGSize(width: shadow.offset.width, height: -shadow.offset.height), blur: CGFloat(shadow.blur), color: shadow.color.cgColor)
    }

    /// Builds a combined fill path for the line's runs ، used only for the
    /// `.reduced`-fidelity flat-shadow fallback (`paintReducedShadowIfNeeded`
    /// needs one path to offset+fill; per-glyph `CTFontDrawGlyphs` calls
    /// have no single `CGPath` otherwise).
    private func linePath(_ line: MKShapedLine) -> CGPath {
        let combined = CGMutablePath()
        for run in line.runs {
            let ctFont = fonts.resolve(MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize))
            for (index, glyph) in run.glyphs.enumerated() {
                guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else { continue }
                let t = CGAffineTransform(translationX: run.positions[index].x, y: run.positions[index].y)
                combined.addPath(glyphPath, transform: t)
            }
        }
        return combined
    }

    private func drawRun(
        _ run: MKShapedRun, node: MKLiveTextNode, usesOutlineStroke: Bool,
        into ctx: CGContext, report: inout MKRenderReportBuilder, nodeID: MKNodeID
    ) {
        let ctFont = fonts.resolve(MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize))

        if case .solid(let color) = node.core.style.fill {
            ctx.setFillColor(color.cgColor)
        }

        if !usesOutlineStroke {
            // Fast path: fill directly via CTFontDrawGlyphs (no outline
            // extraction) when there's no stroke to apply.
            ctx.setTextDrawingMode(.fill)
            CTFontDrawGlyphs(ctFont, run.glyphs, run.positions, run.glyphs.count, ctx)
            return
        }

        // Stroke path (ARCHITECTURE §11.1: "Stroke/shadow on live text draw
        // per-glyph paths instead (outline needed) ، automatic internal
        // switch, geometry identical"): extract each glyph's outline and
        // fill+stroke it as a path, rather than using CTFontDrawGlyphs'
        // built-in stroke text-drawing mode, so counters (e.g. عين/ه loops)
        // stroke the OUTLINE per §6 Arabic-correctness notes.
        guard let stroke = node.core.style.stroke else { return }
        for (index, glyph) in run.glyphs.enumerated() {
            guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else {
                report.recordSubstitution(nodeID: nodeID, kind: .missingOutline, detail: "live text glyph \(glyph) has no outline")
                continue
            }
            ctx.saveGState()
            ctx.translateBy(x: run.positions[index].x, y: run.positions[index].y)
            ctx.addPath(glyphPath)
            if case .solid = node.core.style.fill {
                ctx.fillPath(using: .winding)
                ctx.addPath(glyphPath)
            }
            ctx.setStrokeColor(stroke.color.cgColor)
            ctx.setLineWidth(CGFloat(stroke.width))
            ctx.setLineJoin(stroke.join.cgLineJoin)
            ctx.setLineCap(stroke.cap.cgLineCap)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }
}
