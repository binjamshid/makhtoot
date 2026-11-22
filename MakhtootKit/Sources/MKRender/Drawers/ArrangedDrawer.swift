import CoreGraphics
import MKFoundation
import MKModel

// WS-07 packet §5 task 2. Draws `MKArrangedTextNode`: per child in
// `Index.paintOrder` (glyphs/ligatures interleaved with marks in the
// composition's own visual order, D-220's z-within-composition), concat
// the world affine per §5.3's normative chain (`MKArrangedGeometry`), then
// fill/stroke the stored `outline` path ، "never consult the font at
// render time (INV-13)": a `nil` outline records a `.missingOutline`
// substitution and skips, it never falls back to `CTFontCreatePathForGlyph`.
//
// **Composition-space axis convention** (the one genuinely underspecified
// corner of D-220/§5.3, since `MKArrange`/WS-04 ، the module that WOULD
// pin this down by construction ، doesn't exist yet, P5): `layout.position`,
// `relativeOffset`, and `outline` path coordinates are produced by the
// SAME Core Text capture pipeline `MKTextEngine` uses everywhere else
// (`CTRunGetPositions`, `CTFontCreatePathForGlyph`), which is y-up
// (`MKTextEngine/CoordinateSpace.swift`: "never flips or rewrites a
// captured position"). MKRender's document/canvas space is y-down
// (`LiveTextDrawer`'s file comment, `README.md`). This drawer therefore
// treats "composition-local space" as y-up and applies exactly ONE axis
// flip at the boundary where composition-local content enters document
// space ، folded into what it passes as `MKArrangedGeometry`'s
// `compositionAffine` parameter (`flip.concatenating(node.core.transform
// .affineTransform)`), so `MKArrangedGeometry`'s own chain stays a pure,
// convention-agnostic implementation of the D-220 formula (verified against
// the formula directly by `T-ARR-1`/`T-ARR-2` with `compositionAffine =
// .identity`, matching those tests' own "isolation" fixture setup). If
// WS-04 lands and derives `layout.position`/`relativeOffset` in a DOCUMENT-
// space (y-down) convention instead, only this one flip needs to change ،
// not the D-220 math itself.
public struct ArrangedDrawer: Sendable {
    public init() {}

    public func draw(
        _ node: MKArrangedTextNode, into ctx: CGContext, quality: MKRenderQuality, report: inout MKRenderReportBuilder
    ) {
        let index = MKArrangedGeometry.Index(composition: node.composition)
        // `SceneRenderer` has ALREADY concatenated `node.core.transform`
        // onto `ctx` before calling this drawer (§11.1's "concat node
        // affine" step, shared by every node kind), so each child's world
        // transform is computed relative to the composition's own local
        // origin ، `compositionAffine: flip` (the y-up→y-down axis
        // correction only, see file header) ، and baked directly into the
        // outline PATH DATA (`path.copy(using:)` in `drawOutline` below)
        // rather than via `ctx.concatenate`, so nothing double-applies
        // `node.core.transform`.
        let flip = CGAffineTransform(scaleX: 1, y: -1)
        let pointSize = node.composition.sourceBackup.style.pointSize

        for childID in index.paintOrder {
            switch index.element(id: childID) {
            case .glyph(let glyph):
                drawOutline(
                    glyph.outline, worldTransform: MKArrangedGeometry.worldTransform(ofChild: childID, index: index, compositionAffine: flip),
                    style: glyph.style, pointSize: pointSize, nodeID: node.core.id, childID: childID,
                    quality: quality, into: ctx, report: &report)
            case .composedLigature(let id, _, let ligature):
                // The ligature GROUP's own style/hidden/locked apply here
                // (composed state only ، decomposed components are drawn
                // as plain `.glyph` elements above via `Index`'s
                // flattening, using each component's OWN style).
                guard case .ligature(let group) = node.composition.child(id: id), !group.isHidden else { continue }
                drawOutline(
                    ligature.outline, worldTransform: MKArrangedGeometry.worldTransform(ofChild: childID, index: index, compositionAffine: flip),
                    style: group.style, pointSize: pointSize, nodeID: node.core.id, childID: childID,
                    quality: quality, into: ctx, report: &report)
            case .mark(let mark):
                guard !mark.isHidden else { continue }
                drawOutline(
                    mark.outline, worldTransform: MKArrangedGeometry.worldTransform(ofMark: childID, index: index, compositionAffine: flip),
                    style: mark.style, pointSize: pointSize, nodeID: node.core.id, childID: childID,
                    quality: quality, into: ctx, report: &report)
            case .none:
                continue
            }
        }
    }

    private func drawOutline(
        _ outline: MKPathData?, worldTransform: CGAffineTransform?, style: MKStyle, pointSize: Double,
        nodeID: MKNodeID, childID: MKNodeID, quality: MKRenderQuality, into ctx: CGContext, report: inout MKRenderReportBuilder
    ) {
        guard let worldTransform else { return }
        guard let outline, !outline.commands.isEmpty else {
            report.recordSubstitution(nodeID: nodeID, kind: .missingOutline, detail: "arranged child \(childID) has no persisted outline (INV-13: never re-extracted at render time)")
            return
        }
        var transform = worldTransform
        guard let path = outline.cgPath(at: pointSize).copy(using: &transform) else { return }
        MKStylePainting.paintReducedShadowIfNeeded(path: path, style: style, quality: quality, in: ctx)
        MKStylePainting.paint(path: path, style: style, quality: quality, in: ctx)
    }
}
