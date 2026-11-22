import CoreGraphics
import MKFoundation
import MKModel

// WS-07 packet §5 task 2. Draws `MKShapeNode.geometry` ، CGPath fill/stroke
// for every case except `.asset` (see note below).
public struct ShapeDrawer: Sendable {
    public init() {}

    public func draw(
        _ node: MKShapeNode, into ctx: CGContext, quality: MKRenderQuality, report: inout MKRenderReportBuilder
    ) {
        guard let path = Self.localPath(for: node.geometry) else {
            // `.asset(MKAssetRef)` shape geometry needs `MKAssetVectorProgram`
            // (MKAssets, WS-14 ، not yet built, not a MKRender dependency;
            // see `AssetProviding.swift`'s note). Recorded, never crashes.
            if case .asset = node.geometry {
                report.recordSubstitution(nodeID: node.core.id, kind: .missingAsset, detail: "shape geometry .asset needs MKAssets vector program (WS-14, not yet built)")
            }
            return
        }
        MKStylePainting.paintReducedShadowIfNeeded(path: path, style: node.core.style, quality: quality, in: ctx)
        // P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 4): the
        // stroke-width scaling fix `docs/impl-log/WS-08.md`'s "Fixture-
        // authoring pitfall" section flagged ، see `MKStylePainting.paint`'s
        // `strokeWidthCompensationScale` doc comment for the full mechanism.
        // `node.core.transform.scale` is EXACTLY the factor `SceneRenderer`
        // concatenated onto `ctx` to turn this drawer's unit-square geometry
        // into the shape's real on-canvas box size (`localPath(for:)`'s own
        // doc comment above).
        MKStylePainting.paint(
            path: path, style: node.core.style, quality: quality, in: ctx,
            strokeWidthCompensationScale: node.core.transform.scale
        )
    }

    /// Package-internal (not `private`) so `HitTester` can test against the
    /// EXACT same path this drawer paints, rather than a second,
    /// potentially-drifting bounding-box approximation.
    static func localPath(for geometry: MKShapeGeometry) -> CGPath? {
        switch geometry {
        case .rect(let cornerRadius):
            // Unit-square-relative geometry: `SceneRenderer` has already
            // concatenated the node's own transform (which carries the
            // shape's size via `scale`, per how WS-06 is expected to author
            // shape nodes ، position/rotation/scale IS the box, D-111 "no
            // raw matrix" decomposed-transform convention applies to size
            // the same way it does to text/image nodes) ، so this draws a
            // canonical 1×1 rect centered at the origin, matching every
            // other geometry case's own-local-unit-space convention below.
            let rect = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)
            return CGPath(roundedRect: rect, cornerWidth: CGFloat(cornerRadius), cornerHeight: CGFloat(cornerRadius), transform: nil)
        case .ellipse:
            let rect = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)
            return CGPath(ellipseIn: rect, transform: nil)
        case .line:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -0.5, y: 0))
            path.addLine(to: CGPoint(x: 0.5, y: 0))
            return path
        case .polygon(let points):
            guard let first = points.first else { return nil }
            let path = CGMutablePath()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
            return path
        case .path(let pathData):
            // `MKPathData` is glyph-scale (1000/em) normalized (§3.6); a
            // freeform shape path uses the same encoding at `unitsPerEm`
            // scale directly (pointSize == unitsPerEm ⇒ 1:1), matching how
            // `MKShapeNode` geometry is otherwise unit-local (see `.rect`
            // note above) with sizing carried entirely by the node
            // transform's `scale`.
            return pathData.cgPath(at: pathData.unitsPerEm)
        case .asset:
            return nil
        }
    }
}
