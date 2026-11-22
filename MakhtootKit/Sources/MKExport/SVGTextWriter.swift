import CoreGraphics
import CoreText
import Foundation
import MKFoundation
import MKModel
import MKTextEngine

// P10-COMPLETION (Run-3, packet §5 task 14). Live-text → `<text>`.
//
// **Subset-embedding assessment (packet's explicit instruction: "assess
// feasibility of a native sfnt subsetter honestly")**: a CORRECT minimal
// TrueType/OpenType subsetter needs to rewrite `glyf`/`loca` (or `CFF `),
// remap `cmap`, patch `hmtx`/`hhea`/`maxp` counts, and regenerate
// `head.checkSumAdjustment` + the font-wide checksum ، a real, nontrivial
// binary-format transform (dozens of interacting tables, several of them
// with cross-references that must stay internally consistent or the font
// fails to parse in strict viewers). Building this correctly, from
// scratch, with no dependency (D-101), inside this session is assessed as
// TOO LARGE to do safely ، a half-correct subsetter that occasionally
// produces a malformed font is a strictly worse outcome than a larger,
// definitely-valid file, and D-227(3) already flags the subset-embedding
// legal question itself (OFL Reserved Font Names) as `VERIFY-AT-SUBMISSION`
// regardless. **Decision**: this session ships FULL-font embedding for
// fonts with `.svg` embedding rights (a valid, spec-compliant `@font-face`
// payload, just larger than a subset would be) and records subsetting as a
// follow-up (`SUBSETTING_FOLLOWUP.md`). Non-OFL/user-imported fonts are
// NEVER embedded (outline-only, via `MKEmbeddingRestrictionWalker` ، this
// file is never reached for those nodes at all).
public enum SVGTextWriter {
    /// One `<text>` element per shaped line (task 14: "One `<text>` per
    /// line"). `x`/`text-anchor` follow `baseDirection` (RTL → anchor
    /// "end", `x` = the node's box's RIGHT edge in node-local space, i.e.
    /// `paragraph.boxWidth` ، MASTER-PLAN Phase-2 RTL-alignment fix: an
    /// earlier v1 used `0` here, which is the box's LEFT edge, silently
    /// shifting every RTL line's rendered position outside `[0, boxWidth]`
    /// into negative x. `text-anchor="end"` then right-flushes each line's
    /// own rendered width against that shared `x` automatically, matching
    /// `LiveTextDrawer`'s per-line `paragraph.lineOriginX` offset for the
    /// canvas render.
    public static func renderLiveText(
        _ node: MKLiveTextNode, fonts: any MKFontProviding, fontData: any MKExportFontDataProviding,
        fontLicense: any FontLicenseProviding, indent: String
    ) -> (xml: String, fontFaceCSS: String?, fallback: FallbackNote?) {
        guard !node.text.string.isEmpty else { return ("", nil, nil) }
        let engine = MKShapingEngine(fonts: fonts)
        let request = MKShapingRequest(text: node.text, style: node.style, frame: node.frame)
        let paragraph = engine.shapeParagraph(request)
        guard !paragraph.lines.isEmpty else { return ("", nil, nil) }

        let isRTL = node.style.baseDirection != .leftToRight
        let anchor = isRTL ? "end" : "start"
        // MASTER-PLAN Phase-2 RTL-alignment fix (canvas⇄export parity with
        // `LiveTextDrawer`): the node's box is `[0, boxWidth]` (widest
        // line's own width, `MKNodeLocalBounds`/`paragraph.boxWidth`'s
        // shared definition). SVG's `text-anchor="end"` + `direction="rtl"`
        // is the standard RTL right-flush idiom, but it anchors the text's
        // RIGHT edge at whatever `x` is given ، `x` must therefore be the
        // box's right edge (`boxWidth`), not `0` (the box's LEFT edge, what
        // this previously used, which silently shifted every RTL line's
        // rendered position entirely outside `[0, boxWidth]` into negative
        // x). The SAME fixed `x` is correct for every line: each line is
        // its own `<text>` element (this file's own "one `<text>` per line"
        // rule), so `text-anchor="end"` right-flushes THAT line's own
        // rendered width against `x` automatically ، no manual per-line
        // width math needed for the `<text>` element itself (unlike the
        // highlight/decoration shapes below, which have no anchor mechanic
        // and must be shifted manually).
        let boxWidth = paragraph.boxWidth
        let textX = isRTL ? boxWidth : 0.0
        let fillHex: String? = {
            if case .solid(let color) = node.core.style.fill { return SVGXML.hexColor(color) }
            return nil
        }()
        // GAP1 bold/italic parity: `node.style.font.postScriptName` is the
        // UNRESOLVED request (e.g. `Amiri-Regular` even when `isBold` asked
        // for `Amiri-Bold`) ، `MKShapingEngine.resolvedFont(for:)` resolves
        // bold/italic via `MKFontVariantRequest` and the shaper captures
        // THAT resolved face's PostScript name into `MKShapedRun.font`
        // (`resolvedFont(for:)`'s own doc comment: "every downstream
        // consumer... reads the RESOLVED font back off the captured run").
        // `LiveTextDrawer`/PDF already read `run.font` for exactly this
        // reason ، this writer must too, or bold/italic text keeps
        // declaring its UNBOLDED family name in the SVG while the glyphs
        // themselves were shaped (and, for the outlined/PDF paths, drawn)
        // from the bold cut. Read off the FIRST run of the FIRST
        // non-empty line (uniform per node, WS-02 ، no per-run style
        // overrides exist, so any run is representative), falling back to
        // the unresolved request only for a degenerate all-empty-lines
        // paragraph (already guarded against above, but kept defensive).
        let resolvedFont: MKFontHandle = {
            for line in paragraph.lines {
                if let font = line.runs.first?.font { return font }
            }
            return MKFontHandle(postScriptName: node.style.font.postScriptName, pointSize: CGFloat(node.style.pointSize))
        }()
        let fontFamily = SVGXML.escape(resolvedFont.postScriptName)
        let lineHeight = node.style.lineHeightMultiple * node.style.pointSize
        var lineOriginY = paragraph.lines[0].typographicBounds.ascent

        // P5.6/P5.7 canvas⇄export parity (MASTER-PLAN's hard rule: every
        // trait/fill a drawer gains lands in `SVGSerializer` in the SAME
        // change): `LiveTextDrawer.paintHighlight`/`.paintTextDecorations`'
        // exact geometry, replicated here so the export is pixel-parity
        // with the canvas, not merely "also shows a highlight/underline
        // somehow." Resolved once (uniform per node, WS-02 ، no per-run
        // style overrides exist), from `node.style.font`/`.pointSize`
        // resolved through the SAME variant-resolution path
        // `MKShapingEngine.resolvedFont(for:)` uses ،
        // `fonts.resolve(handle, variant: MKFontVariantRequest(bold:
        // node.style.isBold, italic: node.style.isItalic))` ، mirroring
        // `LiveTextDrawer.paintTextDecorations`' own fix. Deliberately NOT
        // `fonts.resolve(resolvedFont)` (the `resolvedFont` handle just
        // above, built from the run's CAPTURED PostScript name): that
        // round-trip looks equivalent but is NOT guaranteed to land back on
        // the same `CTFont` ، system/fallback faces resolve through
        // dot-prefixed names CoreText does not reliably re-resolve by name
        // alone (`SystemFontStubProvider`'s doc comment, `MKFoundation/
        // Stubs/MKFontProviding.swift`, covers exactly this failure mode),
        // and a variable-font instance's PS name is not guaranteed to
        // round-trip to the same instance either. `resolvedFont` above
        // remains correct for the `<text>` element's `font-family` string
        // (a label, never fed back through `fonts.resolve(_:)`) ، only the
        // DECORATION metrics need the round-trip-free variant re-resolve.
        // Do NOT reintroduce `fonts.resolve(resolvedFont)` here.
        let decorationHandle = MKFontHandle(postScriptName: node.style.font.postScriptName, pointSize: CGFloat(node.style.pointSize))
        let decorationVariant = MKFontVariantRequest(bold: node.style.isBold, italic: node.style.isItalic)
        let decorationFont = fonts.resolve(decorationHandle, variant: decorationVariant)
        let underlineY = CTFontGetUnderlinePosition(decorationFont)
        let strikethroughY = CTFontGetXHeight(decorationFont) / 2
        let decorationThickness = max(CTFontGetUnderlineThickness(decorationFont), 1)

        var lines: [String] = []
        let sourceUTF16 = Array(node.text.string.utf16)
        for line in paragraph.lines {
            let lower = max(0, min(line.sourceRange.lowerBound, sourceUTF16.count))
            let upper = max(lower, min(line.sourceRange.upperBound, sourceUTF16.count))
            let lineText = String(decoding: sourceUTF16[lower..<upper], as: UTF16.self)
            let width = line.typographicBounds.width
            // The highlight rect and underline/strikethrough `<line>`s
            // below are plain geometry (no `text-anchor` mechanic), so ،
            // unlike the `<text>` element's fixed `textX` above ، they need
            // THIS line's own manual offset (`LiveTextDrawer.paintHighlight`
            // / `.paintTextDecorations`' exact per-line origin, replicated
            // here) or a short line's decoration would detach from its
            // (now correctly right-flushed) glyphs.
            let lineX = paragraph.lineOriginX(lineWidth: width, baseDirection: node.style.baseDirection)

            // Highlight rect: BEHIND the `<text>` element (emitted first,
            // SVG paints document order back-to-front), same rect as
            // `LiveTextDrawer.paintHighlight` (full line ascent+descent,
            // so Arabic descenders/tashkeel stay covered).
            if let highlight = node.style.highlightColor, width > 0 {
                let rectY = lineOriginY - line.typographicBounds.ascent
                let rectHeight = line.typographicBounds.ascent + line.typographicBounds.descent
                var rectAttrs = "x=\"\(SVGXML.number(lineX))\" y=\"\(SVGXML.number(rectY))\" width=\"\(SVGXML.number(width))\" height=\"\(SVGXML.number(rectHeight))\" fill=\"\(SVGXML.hexColor(highlight))\""
                if highlight.a < 1 { rectAttrs += " fill-opacity=\"\(SVGXML.number(highlight.a))\"" }
                lines.append("\(indent)<rect data-mk-kind=\"highlight\" \(rectAttrs)/>")
            }

            var attrs = "x=\"\(SVGXML.number(textX))\" y=\"\(SVGXML.number(lineOriginY))\" direction=\"rtl\" unicode-bidi=\"plaintext\" text-anchor=\"\(anchor)\" font-family=\"\(fontFamily)\" font-size=\"\(SVGXML.number(node.style.pointSize))\""
            if node.style.tracking != 0 { attrs += " letter-spacing=\"\(SVGXML.number(node.style.tracking))\"" }
            if let fillHex { attrs += " fill=\"\(fillHex)\"" }
            lines.append("\(indent)<text \(attrs)>\(SVGXML.escape(lineText))</text>")

            // Underline/strikethrough: explicit `<line>` elements using the
            // SAME font-metric-derived offsets `LiveTextDrawer
            // .paintTextDecorations` uses (never a hardcoded offset, never
            // CSS `text-decoration` ، a browser's own underline placement
            // would NOT match the canvas render, breaking parity).
            if width > 0, let fillHex, node.style.isUnderline || node.style.isStrikethrough {
                let strokeAttrs = "stroke=\"\(fillHex)\" stroke-width=\"\(SVGXML.number(decorationThickness))\""
                if node.style.isUnderline {
                    // `underlineY` (`CTFontGetUnderlinePosition`) is in
                    // CoreText's native y-up space and typically NEGATIVE
                    // (below baseline); this SVG writer works in plain
                    // y-DOWN document space with no CoreGraphics re-flip,
                    // so converting a native y-up offset to a document-
                    // space y is `lineOriginY - underlineY` (matches
                    // `LiveTextDrawer.paintTextDecorations`' un-negated use
                    // of the SAME value directly in ITS already-y-up-
                    // flipped local space ، same font metric, two
                    // different ambient coordinate conventions).
                    lines.append("\(indent)<line data-mk-kind=\"underline\" x1=\"\(SVGXML.number(lineX))\" y1=\"\(SVGXML.number(lineOriginY - underlineY))\" x2=\"\(SVGXML.number(lineX + width))\" y2=\"\(SVGXML.number(lineOriginY - underlineY))\" \(strokeAttrs)/>")
                }
                if node.style.isStrikethrough {
                    lines.append("\(indent)<line data-mk-kind=\"strikethrough\" x1=\"\(SVGXML.number(lineX))\" y1=\"\(SVGXML.number(lineOriginY - strikethroughY))\" x2=\"\(SVGXML.number(lineX + width))\" y2=\"\(SVGXML.number(lineOriginY - strikethroughY))\" \(strokeAttrs)/>")
                }
            }
            lineOriginY += CGFloat(lineHeight)
        }

        // §16.6: `@font-face` with a full-font base64 payload ONLY when the
        // license seam allows `.svg` embedding ، otherwise still `<text>`
        // (family name only, `FallbackReason.fontNotEmbedded`), NEVER
        // outlined here (a node reaching THIS function already passed
        // `MKEmbeddingRestrictionWalker`'s `.svg`-rights check upstream in
        // `SVGSerializer` ، see that file).
        var fontFaceCSS: String?
        var fallback: FallbackNote?
        if fontLicense.embeddingRights(node.style.font).contains(.svg) {
            // FIXME(bold/italic embedding): `fontData.fontFileData(for:)` is
            // keyed by `MKFontRef` (`MKExportFontDataProviding`'s only
            // lookup shape), and the only `MKFontRef` this function has is
            // `node.style.font` ، the UNRESOLVED request. There is no
            // `MKFontRef` for the RESOLVED bold/italic face: resolution
            // (`MKFontProviding.resolve(_:variant:)`) picks a concrete
            // `CTFont`/PostScript name at shape time (`resolvedFont`
            // above), but never mints a catalog entry for that specific
            // cut, so this call necessarily fetches the REGULAR face's file
            // bytes even when `fontFamily` (just above) now correctly names
            // the resolved BOLD/ITALIC PostScript name. Today this is
            // latent, not user-visible: the wired production conformer is
            // `MKNoFontDataProviding`, which returns `nil` unconditionally
            // (see this type's own doc comment + `ExportFallbacks.md`), so
            // `fontFaceCSS` is never actually produced. A REAL conformer
            // (backed by `MKFontRegistry`, per `MKExportFontDataProviding`'s
            // own "coordination note") would need to resolve bold/italic
            // ITSELF from `fontRef` + a variant flag ، which means either
            // (a) widening `MKExportFontDataProviding.fontFileData(for:)`
            // to also take an `MKFontVariantRequest` (or the resolved
            // PostScript name directly), so it can look up the family's
            // Bold/Italic FACE file instead of always the default face's;
            // or (b) minting a synthetic per-variant `MKFontRef` at
            // resolution time (font catalog surgery, a bigger change). This
            // session does not redesign that provider protocol ، documented
            // here rather than silently emitting a `font-family` that
            // claims Bold while embedding Regular bytes.
            if let data = fontData.fontFileData(for: node.style.font) {
                let base64 = data.base64EncodedString()
                fontFaceCSS = "@font-face { font-family: \"\(fontFamily)\"; src: url(data:font/ttf;base64,\(base64)) format(\"truetype\"); }"
            } else {
                fallback = FallbackNote(nodeID: node.core.id, reason: .fontNotEmbedded(fontName: node.style.font.postScriptName))
            }
        }

        return (lines.joined(separator: "\n"), fontFaceCSS, fallback)
    }
}
