import CoreGraphics
import MKFonts
import MKFoundation
import MKModel

// P10-COMPLETION (Run-3, packet §5 tasks 11/14). Finds every `.liveText`/
// `.pathText` node whose font lacks the target format's embedding right
// (D-227(1): `MKEmbeddingRights`), computes each such node's FULL world
// transform (canvas→device chain, replicated here per this file's own
// note below ، the SAME closed-form `TiledRasterExporter.swift`'s
// `MKMappedBitmapAssembly.draw` already documents copying, for the
// identical "the real formula lives in `MKSceneRenderer.canvasToDevice`,
// which is `internal` to `MKRender`, not exported" reason), and builds a
// scene COPY with those nodes hidden (so `MKSceneRenderer.render` skips
// them ، the caller then draws an outline substitute separately, see
// `MKOutlineSubstitutePainter.swift`).
//
// **Arranged/mark/ligature nodes are deliberately excluded** ، D-118/§16.5
// already always outlines them (they are "geometry no longer a text run"),
// and `MKArrangedTextNode`'s glyphs carry their own PERSISTED outline
// (`MKGlyphNode.outline`, INV-13 "never consult font at render time") ،
// there is no license switch to apply; `MKRender`'s `ArrangedDrawer`
// already renders them correctly as real vector paths in a PDF context
// with zero help from this file.
public enum MKEmbeddingRestrictionWalker {
    public struct Entry: Sendable {
        public enum Kind: Sendable {
            case liveText(MKLiveTextNode)
            case pathText(MKPathTextNode)
        }
        public var id: MKNodeID
        public var worldTransform: CGAffineTransform
        public var style: MKStyle
        public var opacity: Double
        public var fontPostScriptName: String
        public var kind: Kind
    }

    /// `deviceTransform`: canvas(points, y-down)→PDF-page(points, y-up)
    /// transform, replicated from `MKSceneRenderer.canvasToDevice`'s
    /// documented closed form (`region = CGRect(origin: .zero, size:
    /// canvasSize)`): `CGAffineTransform(a: scale, b: 0, c: 0, d: -scale,
    /// tx: 0, ty: scale * canvasSize.height)`.
    public static func restrictedTextNodes(
        in scene: MKScene, fontLicense: any FontLicenseProviding, right: MKEmbeddingRights,
        deviceTransform: CGAffineTransform
    ) -> [Entry] {
        var results: [Entry] = []

        func visit(_ node: MKNode, outerTransform: CGAffineTransform) {
            guard !node.core.isHidden else { return }
            let composed = node.core.transform.affineTransform.concatenating(outerTransform)
            switch node {
            case .group(let g):
                for child in g.children { visit(child, outerTransform: composed) }
            case .liveText(let n):
                if !fontLicense.embeddingRights(n.style.font).contains(right) {
                    results.append(Entry(
                        id: n.core.id, worldTransform: composed, style: n.core.style, opacity: n.core.opacity,
                        fontPostScriptName: n.style.font.postScriptName, kind: Entry.Kind.liveText(n)
                    ))
                }
            case .pathText(let n):
                if !fontLicense.embeddingRights(n.style.font).contains(right) {
                    results.append(Entry(
                        id: n.core.id, worldTransform: composed, style: n.core.style, opacity: n.core.opacity,
                        fontPostScriptName: n.style.font.postScriptName, kind: Entry.Kind.pathText(n)
                    ))
                }
            case .arranged, .shape, .image, .background:
                break
            }
        }

        for node in scene.nodes { visit(node, outerTransform: deviceTransform) }
        return results
    }

    /// Convenience: derives `deviceTransform` from `scene`/`scale` itself
    /// (the common case ، callers computing their own custom region-render
    /// pass are rare enough not to need a second entry point).
    public static func restrictedTextNodes(
        in scene: MKScene, fontLicense: any FontLicenseProviding, right: MKEmbeddingRights, scale: CGFloat
    ) -> [Entry] {
        let device = CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: 0, ty: scale * scene.canvas.size.height)
        return restrictedTextNodes(in: scene, fontLicense: fontLicense, right: right, deviceTransform: device)
    }

    /// A value-type scene copy with every node in `ids` hidden ، the same
    /// "value-type copy, one field flipped" pattern
    /// `ExportCoordinator.preparedScene` already uses for background-hiding
    /// (never a `MKModel`/`MKRender` source change).
    public static func hiding(_ ids: [MKNodeID], in scene: MKScene) -> MKScene {
        var copy = scene
        for id in ids {
            copy = copy.updatingNode(id: id) { node in
                var core = node.core
                core.isHidden = true
                node = node.withCore(core)
            }
        }
        return copy
    }
}
