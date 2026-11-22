import CoreGraphics
import Foundation
import MKFoundation
import MKModel

// WS-07 packet §5 task 3. `MKSceneRenderer` ، "the ONLY drawing entry
// point" (ARCHITECTURE §11.1, INV-2/INV-6). Traverses `scene` in z-order
// (background → `nodes` ascending, index 0 backmost), applies each node's
// transform/opacity, and dispatches to the per-kind drawer.
//
// **Coordinate conventions** (see `README.md` for the full statement):
// `MKScene`/`MKNode` geometry (`MKTransform2D.position`, `MKCanvasSpec
// .size`) lives in canvas/document space: origin top-left, y increases
// DOWNWARD (matching D-114's UIKit canvas host and every design-tool
// convention Makhtoot's competitors use). `render` converts canvas space
// to `ctx`'s device pixels itself, in ONE step (`canvasToDevice(region:
// scale:)` below) ، callers MUST hand in an untouched, freshly-created
// `ctx` sized to EXACTLY `region.size * scale` pixels (this is what
// `MKSnapshotRenderer.makeFlippedBitmapContext`/`render` do; every other
// MKRender consumer ، `MKLayerTreeController`, `MKExport`'s tiled strips ،
// is expected to go through that same helper rather than pre-transforming
// `ctx` itself, so there is exactly one orientation/scale computation in
// the whole render path, not one per call site).
public struct MKSceneRenderer: Sendable {
    private let fonts: any MKFontProviding
    private let assets: any MKAssetProviding
    private let shapeDrawer = ShapeDrawer()
    private let imageDrawer = ImageDrawer()
    private let backgroundDrawer = BackgroundDrawer()
    private let liveTextDrawer: LiveTextDrawer
    private let pathTextDrawer: PathTextDrawer
    private let arrangedDrawer = ArrangedDrawer()

    public init(fonts: any MKFontProviding = SystemFontStubProvider(), assets: any MKAssetProviding = MKEmptyAssetProvider()) {
        self.fonts = fonts
        self.assets = assets
        self.liveTextDrawer = LiveTextDrawer(fonts: fonts)
        self.pathTextDrawer = PathTextDrawer(fonts: fonts)
    }

    /// The ONLY drawing entry point (INV-2, INV-6). Synchronous, callable
    /// from any queue ، `MKScene` is an immutable `Sendable` value (D-102).
    @discardableResult
    public func render(
        _ scene: MKScene, region: CGRect, into ctx: CGContext, scale: CGFloat, quality: MKRenderQuality
    ) -> MKRenderReport {
        let start = Date()
        var report = MKRenderReportBuilder()

        ctx.saveGState()
        ctx.concatenate(Self.canvasToDevice(region: region, scale: scale))

        let canvasBounds = CGRect(origin: .zero, size: scene.canvas.size)
        if !scene.background.core.isHidden {
            backgroundDrawer.draw(scene.background, canvasBounds: canvasBounds, assets: assets, into: ctx, quality: quality, report: &report)
        }
        report.nodeCount += 1

        for node in scene.nodes {
            drawTopLevel(node, into: ctx, quality: quality, report: &report)
        }

        ctx.restoreGState()
        return MKRenderReport(substitutions: report.substitutions, nodeCount: report.nodeCount, duration: Date().timeIntervalSince(start))
    }

    /// Canvas (y-down, top-left origin, document points) → raw device
    /// pixels (CoreGraphics' native bottom-left-origin, y-up space every
    /// freshly-created `CGContext`/PDF context starts in), scaled by
    /// `scale` and offset so `region`'s top-left lands at device (0,0).
    /// Derived once here (closed form, not sequential `translateBy`/
    /// `scaleBy` calls) so the math is auditable in one place ، see
    /// `MKRenderTests` for the numeric derivation check.
    static func canvasToDevice(region: CGRect, scale: CGFloat) -> CGAffineTransform {
        CGAffineTransform(
            a: scale, b: 0, c: 0, d: -scale,
            tx: -scale * region.origin.x,
            ty: scale * region.maxY
        )
    }

    private func drawTopLevel(_ node: MKNode, into ctx: CGContext, quality: MKRenderQuality, report: inout MKRenderReportBuilder) {
        guard !node.core.isHidden else { return }
        report.nodeCount += 1

        ctx.saveGState()
        ctx.concatenate(node.core.transform.affineTransform)

        let needsTransparencyLayer = node.core.opacity < 1
        if needsTransparencyLayer {
            ctx.setAlpha(CGFloat(node.core.opacity))
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        }

        switch node {
        case .group(let g):
            for child in g.children {
                drawTopLevel(child, into: ctx, quality: quality, report: &report)
            }
        case .liveText(let n):
            liveTextDrawer.draw(n, into: ctx, quality: quality, report: &report)
        case .pathText(let n):
            pathTextDrawer.draw(n, into: ctx, quality: quality, report: &report)
        case .arranged(let n):
            arrangedDrawer.draw(n, into: ctx, quality: quality, report: &report)
        case .shape(let n):
            shapeDrawer.draw(n, into: ctx, quality: quality, report: &report)
        case .image(let n):
            imageDrawer.draw(n, assets: assets, into: ctx, quality: quality, report: &report)
        case .background(let n):
            // A `.background` case can only appear here via `MKNode
            // .background` lookups (e.g. `MKScene.node(id:)`); `MKScene
            // .nodes` never contains one (`MKScene.background` is a
            // dedicated field, see `MKNode.swift`'s doc comment) ، drawn
            // defensively for completeness, same code path as the real
            // background above.
            backgroundDrawer.draw(n, canvasBounds: CGRect(origin: .zero, size: .zero), assets: assets, into: ctx, quality: quality, report: &report)
        }

        if needsTransparencyLayer {
            ctx.endTransparencyLayer()
        }
        ctx.restoreGState()
    }
}
