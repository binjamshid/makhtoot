import CoreGraphics
import CoreText
import Foundation
import ImageIO
import MKFoundation
import MKModel
import MKRender
import MKTextEngine

// P10-COMPLETION (Run-3, packet §5 tasks 13-16). Hand-rolled, dependency-
// free SVG serializer (task 13: "no deps" ، D-101). Element mapping
// follows ARCHITECTURE §16.6's table verbatim (D-227(2)'s canonical
// schema): root `<svg>`, `<defs>` for `@font-face`, one `<g>` per node
// carrying `data-mk-node-id`/`data-mk-kind`, per-glyph-group `<g
// data-mk-schema="1">` for arranged content.
//
// **Why nested XML `<g>` elements need no separate "world transform"
// computation (unlike `PDFVectorExporter`'s flat-CTM approach)**: SVG
// natively supports NESTED `transform` attributes ، a child `<g
// transform="matrix(...)">` inside a parent `<g transform="matrix(...)">`
// composes automatically in the renderer, exactly mirroring
// `MKScene`'s own node tree. This serializer therefore recurses the tree
// directly and only ever writes each node's OWN local transform, never a
// pre-flattened one ، simpler and less error-prone than the PDF writer's
// approach (which has to flatten manually because it draws OUTSIDE
// `MKSceneRenderer`'s own group-transform-concatenation for the
// license-outline substitution case).
public enum SVGSerializer {
    public struct Result: Sendable {
        public var svg: String
        public var fallbacks: [FallbackNote]
    }

    public static func export(
        scene: MKScene, pixelSize: CGSize,
        fonts: any MKFontProviding = SystemFontStubProvider(),
        fontLicense: any FontLicenseProviding = AllOFLLicenseStub(),
        fontData: any MKExportFontDataProviding = MKNoFontDataProviding(),
        assets: any MKAssetProviding = MKEmptyAssetProvider()
    ) -> Result {
        var context = Context(fonts: fonts, fontLicense: fontLicense, fontData: fontData, assets: assets)
        let canvasSize = scene.canvas.size

        var body = renderBackground(scene.background, canvasSize: canvasSize, context: &context)
        for node in scene.nodes {
            body += renderNode(node, indent: "  ", context: &context)
        }

        var defs = ""
        if !context.fontFaces.isEmpty {
            defs += "  <defs>\n    <style type=\"text/css\"><![CDATA[\n" + context.fontFaces.sorted().joined(separator: "\n") + "\n    ]]></style>\n  </defs>\n"
        }
        if !context.clipPaths.isEmpty {
            defs += "  <defs>\n" + context.clipPaths.sorted().joined(separator: "\n") + "\n  </defs>\n"
        }

        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:mk="https://makhtoot.app/ns/mk" viewBox="0 0 \(SVGXML.number(canvasSize.width)) \(SVGXML.number(canvasSize.height))" width="\(width)" height="\(height)" data-mk-schema="1">
        \(defs)\(body)</svg>
        """
        return Result(svg: svg, fallbacks: context.fallbacks)
    }

    /// Threaded mutable state through the recursive walk ، a plain struct
    /// (not a class) kept `inout` at call sites, matching
    /// `MKRenderReportBuilder`'s own "mutable accumulator threaded through
    /// a render pass" pattern in `MKRender/RenderOptions.swift`.
    private struct Context {
        var fonts: any MKFontProviding
        var fontLicense: any FontLicenseProviding
        var fontData: any MKExportFontDataProviding
        var assets: any MKAssetProviding
        var fallbacks: [FallbackNote] = []
        var fontFaces: Set<String> = []
        var clipPaths: Set<String> = []
    }

    // MARK: - Background

    /// Mirrors `MKRender/Drawers/BackgroundDrawer.swift`'s `.image` case
    /// exactly (same `MKImageAspect.cover`/`MKGeometryMath.aspectFit`
    /// fitting functions, same centering math) so canvas⇄export parity
    /// holds by construction rather than by re-deriving similar geometry.
    private static func renderBackground(_ background: MKBackgroundNode, canvasSize: CGSize, context: inout Context) -> String {
        guard !background.core.isHidden else { return "" }
        switch background.content {
        case .solid(let color):
            return "  <rect data-mk-kind=\"background\" x=\"0\" y=\"0\" width=\"\(SVGXML.number(canvasSize.width))\" height=\"\(SVGXML.number(canvasSize.height))\" fill=\"\(SVGXML.hexColor(color))\"/>\n"
        case .image(let ref, let fit):
            guard let image = context.assets.resolveRasterImage(ref), let png = pngData(image) else {
                context.fallbacks.append(FallbackNote(nodeID: background.core.id, reason: .assetUnresolved(assetRef: "\(ref.digest).\(ref.ext)"), detail: "background image asset unresolved: \(ref.digest).\(ref.ext)"))
                return "  <rect data-mk-kind=\"background\" data-mk-outlined=\"imageBackgroundNotEmbedded\" x=\"0\" y=\"0\" width=\"\(SVGXML.number(canvasSize.width))\" height=\"\(SVGXML.number(canvasSize.height))\" fill=\"none\"/>\n"
            }
            let imageSize = CGSize(width: image.width, height: image.height)
            let fitted: CGSize
            switch fit {
            case .cover: fitted = MKImageAspect.cover(imageSize, in: canvasSize)
            case .contain: fitted = MKGeometryMath.aspectFit(imageSize, in: canvasSize)
            }
            let originX = canvasSize.width / 2 - fitted.width / 2
            let originY = canvasSize.height / 2 - fitted.height / 2
            let href = "data:image/png;base64,\(png.base64EncodedString())"
            // `.cover` overflows the canvas on one axis by construction
            // (`BackgroundDrawer.swift` clips to `canvasBounds` before
            // drawing) ، clip unconditionally here too, harmless for
            // `.contain`.
            context.clipPaths.insert("    <clipPath id=\"mk-canvas-clip\"><rect x=\"0\" y=\"0\" width=\"\(SVGXML.number(canvasSize.width))\" height=\"\(SVGXML.number(canvasSize.height))\"/></clipPath>")
            return "  <g clip-path=\"url(#mk-canvas-clip)\">\n    <image data-mk-kind=\"background\" x=\"\(SVGXML.number(originX))\" y=\"\(SVGXML.number(originY))\" width=\"\(SVGXML.number(fitted.width))\" height=\"\(SVGXML.number(fitted.height))\" preserveAspectRatio=\"none\" href=\"\(href)\"/>\n  </g>\n"
        }
    }

    // MARK: - Node dispatch

    private static func renderNode(_ node: MKNode, indent: String, context: inout Context) -> String {
        guard !node.core.isHidden else { return "" }
        switch node {
        case .group(let g):
            return renderGroup(g, indent: indent, context: &context)
        case .shape(let s):
            return renderShape(s, indent: indent, context: &context)
        case .image(let img):
            return renderImage(img, indent: indent, context: &context)
        case .liveText(let t):
            return renderLiveText(t, indent: indent, context: &context)
        case .pathText(let t):
            return renderPathText(t, indent: indent, context: &context)
        case .arranged(let a):
            return renderArranged(a, indent: indent, context: &context)
        case .background:
            return ""
        }
    }

    private static func renderGroup(_ g: MKGroupNode, indent: String, context: inout Context) -> String {
        var inner = ""
        for child in g.children { inner += renderNode(child, indent: indent + "  ", context: &context) }
        guard !inner.isEmpty else { return "" }
        return "\(indent)<g data-mk-kind=\"group\" data-mk-node-id=\"\(g.core.id.rawValue)\" transform=\"\(SVGXML.matrix(g.core.transform.affineTransform))\">\n\(inner)\(indent)</g>\n"
    }

    private static func renderShape(_ s: MKShapeNode, indent: String, context: inout Context) -> String {
        guard let path = SVGShapeGeometry.localPath(for: s.geometry) else {
            if case .asset = s.geometry {
                context.fallbacks.append(FallbackNote(nodeID: s.core.id, reason: .pdfAssetRasterized, detail: "shape .asset geometry not yet resolvable (MKAssets vector program, WS-14)"))
            }
            return ""
        }
        let d = SVGXML.pathData(path)
        let paint = paintAttributes(s.core.style)
        return "\(indent)<path data-mk-kind=\"shape\" data-mk-node-id=\"\(s.core.id.rawValue)\" transform=\"\(SVGXML.matrix(s.core.transform.affineTransform))\" d=\"\(d)\" \(paint)/>\n"
    }

    private static func paintAttributes(_ style: MKStyle) -> String {
        var attrs = ""
        switch style.fill {
        case .solid(let color): attrs += "fill=\"\(SVGXML.hexColor(color))\""
        case .none: attrs += "fill=\"none\""
        }
        if let stroke = style.stroke {
            attrs += " stroke=\"\(SVGXML.hexColor(stroke.color))\" stroke-width=\"\(SVGXML.number(stroke.width))\""
            attrs += " stroke-linejoin=\"\(svgLineJoin(stroke.join))\" stroke-linecap=\"\(svgLineCap(stroke.cap))\""
        }
        return attrs
    }

    private static func svgLineJoin(_ join: MKLineJoin) -> String {
        switch join { case .miter: return "miter"; case .round: return "round"; case .bevel: return "bevel" }
    }
    private static func svgLineCap(_ cap: MKLineCap) -> String {
        switch cap { case .butt: return "butt"; case .round: return "round"; case .square: return "square" }
    }

    // MARK: - Images

    private static func renderImage(_ node: MKImageNode, indent: String, context: inout Context) -> String {
        let unitSquare = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)
        switch node.kind {
        case .raster:
            guard let image = context.assets.resolveRasterImage(node.asset), let png = pngData(image) else {
                context.fallbacks.append(FallbackNote(nodeID: node.core.id, reason: .assetUnresolved(assetRef: "\(node.asset.digest).\(node.asset.ext)"), detail: "raster asset unresolved for SVG embed: \(node.asset.digest).\(node.asset.ext)"))
                return ""
            }
            let fitted = MKGeometryMath.aspectFit(CGSize(width: image.width, height: image.height), in: unitSquare.size)
            let rect = CGRect(x: -fitted.width / 2, y: -fitted.height / 2, width: fitted.width, height: fitted.height)
            let href = "data:image/png;base64,\(png.base64EncodedString())"
            return "\(indent)<image data-mk-kind=\"image\" data-mk-node-id=\"\(node.core.id.rawValue)\" transform=\"\(SVGXML.matrix(node.core.transform.affineTransform))\" x=\"\(SVGXML.number(rect.origin.x))\" y=\"\(SVGXML.number(rect.origin.y))\" width=\"\(SVGXML.number(rect.width))\" height=\"\(SVGXML.number(rect.height))\" href=\"\(href)\"/>\n"
        case .vectorPDF:
            guard let page = context.assets.resolvePDFPage(node.asset) else {
                context.fallbacks.append(FallbackNote(nodeID: node.core.id, reason: .pdfAssetRasterized, detail: "vector PDF asset unresolved"))
                return ""
            }
            let pageRect = page.getBoxRect(.mediaBox)
            guard pageRect.width > 0, pageRect.height > 0 else { return "" }
            let fitted = MKGeometryMath.aspectFit(pageRect.size, in: unitSquare.size)
            guard let png = rasterizePDFPage(page, fittedSize: fitted, pageRect: pageRect) else { return "" }
            let rect = CGRect(x: -fitted.width / 2, y: -fitted.height / 2, width: fitted.width, height: fitted.height)
            let href = "data:image/png;base64,\(png.base64EncodedString())"
            context.fallbacks.append(FallbackNote(nodeID: node.core.id, reason: .pdfAssetRasterized))
            return "\(indent)<image data-mk-kind=\"image\" data-mk-node-id=\"\(node.core.id.rawValue)\" data-mk-outlined=\"pdfAssetRasterized\" transform=\"\(SVGXML.matrix(node.core.transform.affineTransform))\" x=\"\(SVGXML.number(rect.origin.x))\" y=\"\(SVGXML.number(rect.origin.y))\" width=\"\(SVGXML.number(rect.width))\" height=\"\(SVGXML.number(rect.height))\" href=\"\(href)\"/>\n"
        case .vectorSVG:
            context.fallbacks.append(FallbackNote(nodeID: node.core.id, reason: .pdfAssetRasterized, detail: "SVG image nodes need MKAssets vector program (WS-14, not yet built)"))
            return ""
        }
    }

    /// Rasterizes a `CGPDFPage` at 2× `fitted` size (§16.6: "rasterized
    /// `<image>` at 2× target").
    private static func rasterizePDFPage(_ page: CGPDFPage, fittedSize: CGSize, pageRect: CGRect) -> Data? {
        let targetWidth = max(1, Int((fittedSize.width * 2).rounded()))
        let targetHeight = max(1, Int((fittedSize.height * 2).rounded()))
        guard let ctx = CGContext(
            data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        let scaleX = CGFloat(targetWidth) / pageRect.width
        let scaleY = CGFloat(targetHeight) / pageRect.height
        ctx.scaleBy(x: scaleX, y: scaleY)
        ctx.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
        ctx.drawPDFPage(page)
        guard let image = ctx.makeImage() else { return nil }
        return pngData(image)
    }

    private static func pngData(_ image: CGImage) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }

    // MARK: - Live text

    private static func renderLiveText(_ node: MKLiveTextNode, indent: String, context: inout Context) -> String {
        guard !node.text.string.isEmpty else { return "" }
        let hasSVGRights = context.fontLicense.embeddingRights(node.style.font).contains(.svg)
        let transformAttr = "transform=\"\(SVGXML.matrix(node.core.transform.affineTransform))\""
        if hasSVGRights {
            let (textXML, fontFaceCSS, fallback) = SVGTextWriter.renderLiveText(
                node, fonts: context.fonts, fontData: context.fontData, fontLicense: context.fontLicense, indent: indent + "  "
            )
            guard !textXML.isEmpty else { return "" }
            if let fontFaceCSS { context.fontFaces.insert(fontFaceCSS) }
            if let fallback { context.fallbacks.append(fallback) }
            return "\(indent)<g data-mk-kind=\"liveText\" data-mk-node-id=\"\(node.core.id.rawValue)\" data-mk-source-text=\"\(SVGXML.escape(node.text.string))\" data-mk-font=\"\(SVGXML.escape(node.style.font.postScriptName))\" \(transformAttr)>\n\(textXML)\n\(indent)</g>\n"
        } else {
            let outlines = MKTextOutlining.outlineLiveText(node, fonts: context.fonts)
            guard !outlines.isEmpty else { return "" }
            context.fallbacks.append(FallbackNote(nodeID: node.core.id, reason: .fontEmbeddingRestricted(fontName: node.style.font.postScriptName)))
            let inner = renderGlyphOutlines(outlines, style: node.core.style, kind: "liveText", context: &context, indent: indent + "  ")
            return "\(indent)<g data-mk-kind=\"liveText\" data-mk-node-id=\"\(node.core.id.rawValue)\" data-mk-source-text=\"\(SVGXML.escape(node.text.string))\" data-mk-outlined=\"fontEmbeddingRestricted\" \(transformAttr)>\n\(inner)\(indent)</g>\n"
        }
    }

    // MARK: - Path text (WS08-A5: always outlined, no <textPath>)

    private static func renderPathText(_ node: MKPathTextNode, indent: String, context: inout Context) -> String {
        guard !node.text.string.isEmpty else { return "" }
        let outlines = MKTextOutlining.outlinePathText(node, fonts: context.fonts)
        guard !outlines.isEmpty else { return "" }
        context.fallbacks.append(FallbackNote(nodeID: node.core.id, reason: .pathTextFidelity))
        let transformAttr = "transform=\"\(SVGXML.matrix(node.core.transform.affineTransform))\""

        // GAP2 canvas⇄export parity: the swept-ribbon highlight
        // (`MKTextOutlining.pathTextHighlightRibbon`, sharing
        // `MKPathText.PathHighlightRibbon`'s geometry with
        // `PathTextDrawer.paintHighlight`'s canvas render) is emitted as
        // its own `<path data-mk-kind="highlight">` BEFORE the glyph-
        // outline group, so SVG's back-to-front document-order painting
        // puts it BEHIND the glyphs ، mirrors `SVGTextWriter.renderLiveText`'s
        // own highlight `<rect>` (always emitted before its `<text>`
        // sibling, same reasoning) and `PathTextDrawer.paintHighlight`'s
        // canvas paint order (ribbon before the glyph loop). Both this
        // path and the glyph-outline group below share the SAME
        // `transformAttr` wrapper, so no separate re-basing is needed
        // (`pathTextHighlightRibbon`'s own doc comment on why that's
        // safe).
        var highlightXML = ""
        if let highlight = node.style.highlightColor,
           let ribbon = MKTextOutlining.pathTextHighlightRibbon(node, fonts: context.fonts) {
            var attrs = "d=\"\(SVGXML.pathData(ribbon))\" fill=\"\(SVGXML.hexColor(highlight))\""
            if highlight.a < 1 { attrs += " fill-opacity=\"\(SVGXML.number(highlight.a))\"" }
            highlightXML = "\(indent)  <path data-mk-kind=\"highlight\" \(attrs)/>\n"
        }

        let inner = renderGlyphOutlines(outlines, style: node.core.style, kind: "pathText", context: &context, indent: indent + "  ")
        return "\(indent)<g data-mk-kind=\"pathText\" data-mk-node-id=\"\(node.core.id.rawValue)\" data-mk-source-text=\"\(SVGXML.escape(node.text.string))\" data-mk-layout=\"pathText\" \(transformAttr)>\n\(highlightXML)\(inner)\(indent)</g>\n"
    }

    /// Shared per-glyph-group `<g data-mk-schema="1">` emission for the
    /// outlined live-text/path-text cases (D-227(2)'s schema ، same shape
    /// `renderArranged` below uses).
    private static func renderGlyphOutlines(
        _ outlines: [MKTextOutlining.GlyphOutline], style: MKStyle, kind: String, context: inout Context, indent: String
    ) -> String {
        var xml = ""
        let paint = paintAttributes(style)
        for outline in outlines {
            let codepointsAttr = SVGXML.hexCodepoints(outline.codepoints)
            if outline.isColorGlyph {
                guard let png = MKTextOutlining.emojiGlyphPNGData(ctFont: outline.ctFont, glyph: outline.glyphID) else { continue }
                context.fallbacks.append(FallbackNote(reason: .colorGlyphRasterized))
                let emSize = CGFloat(CTFontGetSize(outline.ctFont))
                let href = "data:image/png;base64,\(png.base64EncodedString())"
                xml += "\(indent)<image data-mk-schema=\"1\" data-mk-kind=\"emojiGlyph\" data-mk-codepoints=\"\(codepointsAttr)\" data-mk-font=\"\(SVGXML.escape(outline.fontPostScriptName))\" transform=\"\(SVGXML.matrix(outline.localTransform))\" x=\"\(SVGXML.number(-emSize * 0.1))\" y=\"\(SVGXML.number(-emSize * 0.75))\" width=\"\(SVGXML.number(emSize))\" height=\"\(SVGXML.number(emSize))\" href=\"\(href)\"/>\n"
            } else {
                let d = SVGXML.pathData(outline.path)
                xml += "\(indent)<g data-mk-schema=\"1\" data-mk-kind=\"glyph\" data-mk-codepoints=\"\(codepointsAttr)\" data-mk-font=\"\(SVGXML.escape(outline.fontPostScriptName))\">\n"
                xml += "\(indent)  <path transform=\"\(SVGXML.matrix(outline.localTransform))\" d=\"\(d)\" \(paint)/>\n"
                xml += "\(indent)</g>\n"
            }
        }
        return xml
    }

    // MARK: - Arranged composition (always vector/outline ، D-118)

    private static func renderArranged(_ node: MKArrangedTextNode, indent: String, context: inout Context) -> String {
        let index = MKArrangedGeometry.Index(composition: node.composition)
        let flip = CGAffineTransform(scaleX: 1, y: -1)
        // §3.6/`MKPathData`: outlines are glyph-scale (1000/em) normalized
        // and must be scaled to the composition's ACTUAL shaping point
        // size before `worldTransform` (whose translation components ،
        // `layout.position` ، are already in POINT space, per
        // `MKArrangedGeometry.localAffine`'s own doc comment) is applied ،
        // replicating `ArrangedDrawer.drawOutline`'s exact
        // `outline.cgPath(at: pointSize)` step (that file's `pointSize`
        // local variable, same source field).
        let pointSize = node.composition.sourceBackup.style.pointSize
        var inner = ""
        for childID in index.paintOrder {
            switch index.element(id: childID) {
            case .glyph(let glyph):
                inner += renderArrangedElement(
                    outline: glyph.outline, worldTransform: MKArrangedGeometry.worldTransform(ofChild: childID, index: index, compositionAffine: flip),
                    style: glyph.style, provenance: glyph.provenance, fontName: glyph.glyph.font.postScriptName,
                    kind: "glyph", pointSize: pointSize, indent: indent + "  ", context: &context
                )
            case .composedLigature(let id, _, let ligature):
                guard case .ligature(let group) = node.composition.child(id: id), !group.isHidden else { continue }
                inner += renderArrangedElement(
                    outline: ligature.outline, worldTransform: MKArrangedGeometry.worldTransform(ofChild: childID, index: index, compositionAffine: flip),
                    style: group.style, provenance: group.provenance, fontName: nil,
                    kind: "ligature", pointSize: pointSize, indent: indent + "  ", context: &context
                )
            case .mark(let mark):
                guard !mark.isHidden else { continue }
                inner += renderArrangedElement(
                    outline: mark.outline, worldTransform: MKArrangedGeometry.worldTransform(ofMark: childID, index: index, compositionAffine: flip),
                    style: mark.style, provenance: mark.provenance, fontName: nil,
                    kind: "mark", pointSize: pointSize, indent: indent + "  ", context: &context
                )
            case .none:
                continue
            }
        }
        guard !inner.isEmpty else { return "" }
        let transformAttr = "transform=\"\(SVGXML.matrix(node.core.transform.affineTransform))\""
        return "\(indent)<g data-mk-kind=\"arranged\" data-mk-node-id=\"\(node.core.id.rawValue)\" data-mk-source-text=\"\(SVGXML.escape(node.composition.sourceBackup.sourceString))\" \(transformAttr)>\n\(inner)\(indent)</g>\n"
    }

    private static func renderArrangedElement(
        outline: MKPathData?, worldTransform: CGAffineTransform?, style: MKStyle, provenance: MKProvenance,
        fontName: String?, kind: String, pointSize: Double, indent: String, context: inout Context
    ) -> String {
        guard let worldTransform, let outline, !outline.commands.isEmpty else { return "" }
        let path = outline.cgPath(at: pointSize)
        let d = SVGXML.pathData(path)
        let paint = paintAttributes(style)
        let codepointsAttr = SVGXML.hexCodepoints(provenance.codepoints)
        let isEmoji = MKTextOutlining.isEmojiCluster(provenance.codepoints)
        // D-227(4): even inside an arranged/ligature group, an emoji stays
        // an image-flavored element ، the carve-out to "arranged is
        // always outlined." No persisted COLOR BITMAP exists on
        // `MKArrangedChild` (only a vector `MKPathData` outline, INV-13),
        // so this emits the outline path's own (placeholder) geometry
        // wrapped with the SAME `data-mk-kind="emojiGlyph"` marker the
        // live-text emoji path uses (a REAL rasterized bitmap there),
        // rather than fabricating pixel content this module has no
        // font-glyph access to reconstruct for an ALREADY-ARRANGED
        // (frozen, no live CTFont/glyph id retained beyond `MKGlyphRef`)
        // node ، documented limitation (`data-mk-provenance-only`), never
        // silent. `kind` is overridden to `"emojiGlyph"` here (not
        // appended as a SECOND `data-mk-kind` attribute ، duplicate XML
        // attributes are malformed and were caught by this session's own
        // `SVGSerializerTests` well-formedness check).
        let effectiveKind = isEmoji ? "emojiGlyph" : kind
        var attrs = "data-mk-schema=\"1\" data-mk-kind=\"\(effectiveKind)\" data-mk-codepoints=\"\(codepointsAttr)\" data-mk-cluster=\"\(provenance.clusterID.rawValue)\""
        if let fontName { attrs += " data-mk-font=\"\(SVGXML.escape(fontName))\"" }
        if isEmoji {
            context.fallbacks.append(FallbackNote(reason: .colorGlyphRasterized))
            attrs += " data-mk-provenance-only=\"true\""
        }
        return "\(indent)<g \(attrs)>\n\(indent)  <path transform=\"\(SVGXML.matrix(worldTransform))\" d=\"\(d)\" \(paint)/>\n\(indent)</g>\n"
    }
}
