import CoreGraphics
import MKFoundation
import MKModel
import MKTextEngine

// WS-07 packet §5 task 5 (`LayerTreeBuilder`/`MKLayerTreeController`).
// Per-node bounding-box math: `localBounds` is a node's own extent BEFORE
// its `core.transform` is applied (the node's local/intrinsic space ،
// same "unit square, size via transform.scale" convention `ShapeDrawer`/
// `ImageDrawer` use, see those files); `worldBounds` applies the node's
// transform on top (bbox of the four transformed corners, so rotation
// still yields a correct, if conservative for non-axis-aligned rotations,
// enclosing rect). `MKLayerTreeController` uses `worldBounds` to size/
// position each top-level node's `CALayer` and to isolate a node into its
// own single-node render scene for content rasterization.
public enum MKNodeLocalBounds {
    public static func worldBounds(of node: MKNode) -> CGRect {
        let local = localBounds(of: node)
        return local.applying(node.core.transform.affineTransform)
    }

    /// Bounds in the node's OWN local space, i.e. `worldBounds` for
    /// `.group`'s children unioned (group children are already local-to-
    /// the-group), or the per-kind intrinsic extent for every leaf kind.
    public static func localBounds(of node: MKNode) -> CGRect {
        switch node {
        case .group(let g):
            guard let first = g.children.first else { return .zero }
            return g.children.dropFirst().reduce(worldBounds(of: first)) { partial, child in
                partial.union(worldBounds(of: child))
            }
        case .shape(let n):
            return ShapeDrawer.localPath(for: n.geometry)?.boundingBoxOfPath ?? CGRect(x: -0.5, y: -0.5, width: 1, height: 1)
        case .image:
            return CGRect(x: -0.5, y: -0.5, width: 1, height: 1)
        case .liveText(let n):
            return textBounds(text: n.text, style: n.style, frame: n.frame) ?? .zero
        case .pathText(let n):
            let pathBounds = n.path.cgPath().boundingBoxOfPath
            // Text along the path can extend a little beyond the raw
            // control geometry (glyph height either side of the path) ،
            // padded by one line height as a v1 approximation.
            let padding = CGFloat(n.style.pointSize * n.style.lineHeightMultiple)
            return pathBounds.insetBy(dx: -padding, dy: -padding)
        case .arranged(let n):
            return n.composition.originFrame
        case .background:
            return .zero   // background is canvas-filling, not transform/bounds-driven (see BackgroundDrawer)
        }
    }

    private static func textBounds(text: MKSourceText, style: MKTextStyle, frame: MKTextFrameSpec) -> CGRect? {
        guard !text.string.isEmpty else { return nil }
        let engine = MKShapingEngine()
        let paragraph = engine.shapeParagraph(MKShapingRequest(text: text, style: style, frame: frame))
        guard !paragraph.lines.isEmpty else { return nil }
        // `paragraph.boxWidth` (MKTextEngine) ، the SAME widest-line-width
        // computation `LiveTextDrawer`/`SVGTextWriter` now align lines
        // against (MASTER-PLAN Phase-2 RTL-alignment fix), kept as one
        // shared definition so bounds and drawn/exported content never
        // silently drift apart.
        let width = paragraph.boxWidth
        let lineHeight = CGFloat(style.lineHeightMultiple * style.pointSize)
        // `boxHeight(lineHeight:)`, not `lineHeight × lineCount` ، see that
        // method's own doc comment for why the reserved-line-box number
        // clipped Arabic descenders/tashkeel off the bottom of every text
        // layer.
        let height = paragraph.boxHeight(lineHeight: lineHeight)
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
}
