import Testing
import Foundation
import QuartzCore
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKRender

/// P-3 (AUDIT_2026-07-28.md): "`MKLayerTreeController.lastVisibleRect` is
/// documented as living in the same (unscaled, host-layer) coordinate space
/// every layer's `.frame` lives in... The only caller passes
/// `vc.scrollView.bounds` — scroll-view coordinates, offset by
/// `contentOffset`, shifted by the centering insets, and scaled by
/// `zoomScale`... At any zoom ≠ 1, or whenever the canvas is inset-centered,
/// `evictOffscreen()` intersects mismatched rectangles — blanking layers the
/// user is currently looking at and skipping genuinely offscreen ones."
///
/// The fix (`EditorViewModel.attach(canvasViewController:)`) passes
/// `vc.scrollView.convert(vc.scrollView.bounds, to: vc.contentHostView)`
/// instead ، a UIKit-only call site this target has no reach into (no
/// `MKCanvas` dependency here, and the app-target file itself is outside
/// `MakhtootKit` entirely). This suite instead verifies the DOWNSTREAM
/// contract directly against `MKLayerTreeController.setVisibleRect(_:
/// zoomScale:)`/`evictOffscreen()`: given a rect that IS already in
/// `contentHostView` (canvas-point) space — exactly what the fixed call
/// site now produces — a centered layer survives eviction at any zoom;
/// given the OLD, unconverted-`scrollView.bounds`-shaped rect, it does not,
/// reproducing the bug this fix closes.
///
/// Every test calls `setVisibleRect(_:zoomScale:)` FIRST and measures
/// `accountedBytes()` immediately after (before `evictOffscreen()` runs at
/// all) ، `setVisibleRect` crossing a `§11.3` zoom-bucket boundary
/// re-rasterizes at a new `effectiveContentsScale` on its own (a legitimate
/// size change unrelated to eviction), so isolating "what did
/// `evictOffscreen()` itself change" means comparing bytes taken right
/// before it runs against bytes taken right after, never against a count
/// from before `setVisibleRect` was called at all. The background layer is
/// also intentionally NEVER evicted by `evictOffscreen()` (`id !=
/// backgroundLayerID` in that method's own loop, the "background always
/// renders" invariant), so it always contributes some nonzero bytes on its
/// own ، "the node survived" is `bytesAfter == bytesBeforeEviction`
/// (nothing new went to `nil`); "the node was wrongly evicted" is
/// `bytesAfter < bytesBeforeEviction` (strictly less, since only the
/// background's contribution remains).
@Suite("Evict-offscreen coordinate space (P-3)")
struct EvictOffscreenCoordinateSpaceTests {
    /// A 1000×1000 canvas with one 100×100 shape node centered at (500,500)
    /// ، `MKNodeLocalBounds.worldBounds(of:)` for a `.shape` node is its
    /// unit-square geometry scaled by `transform.scale` and positioned at
    /// `transform.position` (P2.1's own already-verified convention, see
    /// `EditorViewModel.addLiveTextAtCenter()`'s doc comment), so this
    /// node's rasterized layer frame lands at `(450, 450, 100, 100)`.
    private func makeCenteredScene() -> MKScene {
        let core = MKNodeCore(
            name: "centered",
            transform: MKTransform2D(position: CGPoint(x: 500, y: 500), scale: CGSize(width: 100, height: 100)),
            style: MKStyle(fill: .solid(MKSolidColor(r: 0.5, g: 0.5, b: 0.5, a: 1)))
        )
        let node = MKNode.shape(MKShapeNode(core: core, geometry: .rect(cornerRadius: 0)))
        return MKScene(
            canvas: MKCanvasSpec(size: CGSize(width: 1000, height: 1000)),
            background: MKBackgroundNode(core: MKNodeCore(name: "bg"), content: .solid(.white)),
            nodes: [node]
        )
    }

    /// Stands in for `vc.scrollView.convert(vc.scrollView.bounds, to:
    /// vc.contentHostView)`'s RESULT at any zoom: once converted, the
    /// visible rect is always expressed in unscaled canvas points ، a
    /// viewport centered on the canvas center that comfortably contains the
    /// node's frame, independent of `zoomScale` (that is P-3's whole point:
    /// after conversion, zoom no longer matters to this rect's meaning).
    private static let correctlyConvertedVisibleRect = CGRect(x: 400, y: 400, width: 200, height: 200)

    @Test func centeredNodeSurvivesEvictionAtHalfZoomWithACorrectlyConvertedRect() async {
        let controller = await MKLayerTreeController()
        let scene = makeCenteredScene()
        await MainActor.run {
            controller.sync(to: scene)
            controller.setVisibleRect(Self.correctlyConvertedVisibleRect, zoomScale: 0.5)
        }
        let bytesBeforeEviction = await MainActor.run { controller.accountedBytes() }
        #expect(bytesBeforeEviction > 0, "sanity check: the scene must have rasterized something before eviction runs")

        await MainActor.run { controller.evictOffscreen() }

        let bytesAfterEviction = await MainActor.run { controller.accountedBytes() }
        #expect(bytesAfterEviction == bytesBeforeEviction, "A centered layer must survive evictOffscreen() at 0.5× zoom when the visible rect is already in contentHostView (canvas-point) space")
    }

    @Test func centeredNodeSurvivesEvictionAt4xZoomWithACorrectlyConvertedRect() async {
        let controller = await MKLayerTreeController()
        let scene = makeCenteredScene()
        await MainActor.run {
            controller.sync(to: scene)
            controller.setVisibleRect(Self.correctlyConvertedVisibleRect, zoomScale: 4.0)
        }
        let bytesBeforeEviction = await MainActor.run { controller.accountedBytes() }
        #expect(bytesBeforeEviction > 0, "sanity check: the scene must have rasterized something before eviction runs")

        await MainActor.run { controller.evictOffscreen() }

        let bytesAfterEviction = await MainActor.run { controller.accountedBytes() }
        #expect(bytesAfterEviction == bytesBeforeEviction, "A centered layer must survive evictOffscreen() at 4× zoom when the visible rect is already in contentHostView (canvas-point) space")
    }

    /// Reproduces the ACTUAL P-3 bug: a raw, UNCONVERTED `scrollView.bounds`
    /// -shaped rect (screen-point sized, anchored at `.zero`, with no
    /// relationship to the canvas's own coordinate space once zoom/
    /// centering insets are in play) does not intersect a centered node's
    /// frame in a 1000×1000 canvas ، proving the bug this suite guards
    /// against is real, not hypothetical, and that `evictOffscreen()`
    /// itself is not what changed: only the coordinate space of the rect
    /// handed to it matters.
    @Test func regressionAnUnconvertedScrollViewBoundsRectWronglyEvictsTheCenteredNode() async {
        let controller = await MKLayerTreeController()
        let scene = makeCenteredScene()

        // A plausible device-viewport-sized `scrollView.bounds`, origin
        // `.zero` ، exactly what the pre-fix poll passed straight through
        // with no `convert(_:to:)` call at all.
        let rawUnconvertedScrollViewBounds = CGRect(x: 0, y: 0, width: 390, height: 844)

        await MainActor.run {
            controller.sync(to: scene)
            controller.setVisibleRect(rawUnconvertedScrollViewBounds, zoomScale: 4.0)
        }
        let bytesBeforeEviction = await MainActor.run { controller.accountedBytes() }
        #expect(bytesBeforeEviction > 0, "sanity check: the scene must have rasterized something before eviction runs")

        await MainActor.run { controller.evictOffscreen() }

        let bytesAfterEviction = await MainActor.run { controller.accountedBytes() }
        #expect(bytesAfterEviction < bytesBeforeEviction, "This reproduces the P-3 bug: an unconverted scrollView.bounds-shaped rect at zoom ≠ 1 wrongly evicts a layer that IS actually on screen")
    }
}
