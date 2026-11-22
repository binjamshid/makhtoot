import Testing
import CoreGraphics
import MKFoundation
import MKModel
import QuartzCore
@testable import MKRender

/// Regression suite for WS-13 Session 3 Bug 2 (`docs/impl-log/WS-13.md`,
/// P4-exit blocker): a COMMITTED transform-only change (move/resize/
/// rotate with no content/style edit) must be visually applied by
/// `MKLayerTreeController` as a layer-property update ، no re-raster, no
/// cache-busting event (the editor's `EditorViewModel
/// .workAroundStaleLayerPositionBug()` zoom-bucket hack must not be
/// needed). Also covers the latent anchor bug this fix surfaced in the
/// TRANSIENT path (delta applied about the layer anchor, wrong for
/// rotation/scale deltas, silently correct for translations ، which is
/// why WS-06's drag tests never caught it).
@Suite struct CommittedTransformSyncTests {
    @MainActor
    private func flatten(_ controller: MKLayerTreeController, canvasSize: CGSize) -> CGImage? {
        guard let ctx = MKSnapshotRenderer.makeFlippedBitmapContext(
            width: Int(canvasSize.width), height: Int(canvasSize.height), scale: 1
        ) else { return nil }
        ctx.concatenate(MKSceneRenderer.canvasToDevice(region: CGRect(origin: .zero, size: canvasSize), scale: 1))
        controller.hostLayer.render(in: ctx)
        return ctx.makeImage()
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let ctx = CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return (Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2]))
    }

    /// The coordinator-requested regression test, strongest form: commit a
    /// MOVE, assert (a) zero rasterizations happened for it, and (b) the
    /// flattened layer tree is pixel-identical to a fresh export-path
    /// render of the moved scene ، with no cache-busting event anywhere.
    @Test @MainActor func committedMoveIsAppliedWithZeroRerasterizationAndMatchesExportPath() {
        let canvasSize = CGSize(width: 120, height: 120)
        var scene = TestScenes.scene(canvasSize: canvasSize, background: .white, nodes: [
            TestScenes.redRect(position: CGPoint(x: 40, y: 40), size: CGSize(width: 30, height: 30)),
        ])
        let nodeID = scene.nodes[0].id

        let controller = MKLayerTreeController(screenScale: 1)
        controller.sync(to: scene)
        _ = controller.consumeRasterizationCount()

        // Committed transform-only change through the same pure-scene
        // mutation path a real command uses.
        scene = scene.updatingNode(id: nodeID) { node in
            var core = node.core
            core.transform.position = CGPoint(x: 85, y: 70)
            node = node.withCore(core)
        }
        controller.sync(to: scene)

        // (a) The bitmap is transform-invariant ، no re-raster may happen.
        #expect(controller.consumeRasterizationCount() == 0)

        // (b) The rendered layer tree reflects the committed move exactly.
        guard let canvasImage = flatten(controller, canvasSize: canvasSize),
              let exportImage = MKSnapshotRenderer().renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        let diff = PixelDiff.differingFraction(exportImage, canvasImage, perChannelTolerance: 10)
        #expect(diff <= 0.001, "committed move: canvas-layer vs export diff = \(diff)")

        // Direct stale-position probe (the WS-13 symptom): the old
        // position must be back to the white background (a stale red
        // layer there would have g < 60), the new position painted red.
        #expect(pixel(canvasImage, x: 40, y: 40).g > 200, "old position still painted ، layer is stale")
        let newCenter = pixel(canvasImage, x: 85, y: 70)
        #expect(newCenter.r > 200 && newCenter.g < 60, "new position not painted")
    }

    /// Committed ROTATION-only change ، exercises the anchor-adjusted
    /// delta math (a pure `setAffineTransform(delta)` without anchor
    /// correction renders translations right but rotations displaced).
    /// Asymmetric 40×10 rect at (60,60), rotated 90°: a probe point on the
    /// new long (vertical) axis must be painted, a probe on the old long
    /// (horizontal) axis must be clear.
    @Test @MainActor func committedRotationIsAppliedAboutTheCorrectAnchor() {
        let canvasSize = CGSize(width: 120, height: 120)
        var scene = TestScenes.scene(canvasSize: canvasSize, background: .white, nodes: [
            TestScenes.redRect(position: CGPoint(x: 60, y: 60), size: CGSize(width: 40, height: 10)),
        ])
        let nodeID = scene.nodes[0].id

        let controller = MKLayerTreeController(screenScale: 1)
        controller.sync(to: scene)
        _ = controller.consumeRasterizationCount()

        // Pre-rotation sanity: (75,60) is inside the horizontal bar,
        // (60,75) is outside it.
        if let before = flatten(controller, canvasSize: canvasSize) {
            #expect(pixel(before, x: 75, y: 60).r > 200)
            #expect(pixel(before, x: 60, y: 75).g > 200)   // white background above the bar
        }

        scene = scene.updatingNode(id: nodeID) { node in
            var core = node.core
            core.transform.rotation = .pi / 2
            node = node.withCore(core)
        }
        controller.sync(to: scene)
        #expect(controller.consumeRasterizationCount() == 0)

        guard let after = flatten(controller, canvasSize: canvasSize) else {
            Issue.record("flatten failed")
            return
        }
        let onNewAxis = pixel(after, x: 60, y: 75)     // inside the now-vertical bar
        let onOldAxis = pixel(after, x: 75, y: 60)     // outside it post-rotation
        #expect(onNewAxis.r > 200 && onNewAxis.g < 60, "rotation not visually applied (stale layer)")
        #expect(onOldAxis.g > 200 && onOldAxis.b > 200, "old orientation still painted ، rotation applied about the wrong anchor or not at all")
    }

    /// The same anchor math on the TRANSIENT path: a live 90° rotation
    /// delta must pivot about the node, not displace it (latent bug ،
    /// translations masked it).
    @Test @MainActor func transientRotationPivotsAboutTheNodeNotTheWorldOrigin() {
        let canvasSize = CGSize(width: 120, height: 120)
        let scene = TestScenes.scene(canvasSize: canvasSize, background: .white, nodes: [
            TestScenes.redRect(position: CGPoint(x: 60, y: 60), size: CGSize(width: 40, height: 10)),
        ])
        let nodeID = scene.nodes[0].id

        let controller = MKLayerTreeController(screenScale: 1)
        controller.sync(to: scene)
        _ = controller.consumeRasterizationCount()

        // Live world transform: same position, rotated 90° (what a rotate
        // gesture mid-flight hands `applyTransientTransform`).
        let live = MKTransform2D(position: CGPoint(x: 60, y: 60), rotation: .pi / 2, scale: CGSize(width: 40, height: 10))
        controller.applyTransientTransform(nodeID: nodeID, transform: live.affineTransform)

        #expect(controller.consumeRasterizationCount() == 0)
        guard let image = flatten(controller, canvasSize: canvasSize) else {
            Issue.record("flatten failed")
            return
        }
        let onNewAxis = pixel(image, x: 60, y: 75)
        #expect(onNewAxis.r > 200 && onNewAxis.g < 60, "transient rotation displaced the node (anchor bug)")
    }

    /// A committed transform-only change followed by a real content edit:
    /// the content edit re-rasterizes ONCE at the new transform and the
    /// result still matches the export path (baked-transform bookkeeping
    /// stays consistent across the two-step sequence).
    @Test @MainActor func contentEditAfterCommittedMoveRebakesAtTheNewTransform() {
        let canvasSize = CGSize(width: 120, height: 120)
        var scene = TestScenes.scene(canvasSize: canvasSize, background: .white, nodes: [
            TestScenes.redRect(position: CGPoint(x: 40, y: 40), size: CGSize(width: 30, height: 30)),
        ])
        let nodeID = scene.nodes[0].id
        let controller = MKLayerTreeController(screenScale: 1)
        controller.sync(to: scene)
        _ = controller.consumeRasterizationCount()

        scene = scene.updatingNode(id: nodeID) { node in
            var core = node.core
            core.transform.position = CGPoint(x: 85, y: 70)
            node = node.withCore(core)
        }
        controller.sync(to: scene)
        #expect(controller.consumeRasterizationCount() == 0)

        scene = scene.updatingNode(id: nodeID) { node in
            var core = node.core
            core.style.fill = .solid(MKSolidColor(r: 0, g: 0, b: 1, a: 1))
            node = node.withCore(core)
        }
        controller.sync(to: scene)
        #expect(controller.consumeRasterizationCount() == 1)

        guard let canvasImage = flatten(controller, canvasSize: canvasSize),
              let exportImage = MKSnapshotRenderer().renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("render failed")
            return
        }
        let diff = PixelDiff.differingFraction(exportImage, canvasImage, perChannelTolerance: 10)
        #expect(diff <= 0.001, "post-rebake canvas-layer vs export diff = \(diff)")
    }
}
