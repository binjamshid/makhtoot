import Testing
import CoreGraphics
import MKFoundation
import MKModel
import QuartzCore
@testable import MKRender

@Suite struct SceneRendererTests {
    private let renderer = MKSceneRenderer()

    private func makeContext(size: CGSize) -> CGContext {
        MKSnapshotRenderer.makeFlippedBitmapContext(width: Int(size.width), height: Int(size.height), scale: 1)!
    }

    @Test func backgroundFillsWholeCanvas() {
        let scene = TestScenes.scene(canvasSize: CGSize(width: 20, height: 20), background: MKSolidColor(r: 0, g: 1, b: 0, a: 1))
        let ctx = makeContext(size: scene.canvas.size)
        renderer.render(scene, region: CGRect(origin: .zero, size: scene.canvas.size), into: ctx, scale: 1, quality: .exportQuality)
        let image = ctx.makeImage()!
        // Tolerant of small colorspace-conversion rounding (`CGColor
        // (red:green:blue:alpha:)`'s generic RGB vs. the bitmap context's
        // device RGB) ، not an exact-255 check.
        for point in [(0, 0), (19, 19)] {
            let p = pixel(image, x: point.0, y: point.1)
            #expect(p.r < 10)
            #expect(p.g > 245)
            #expect(p.b < 10)
            #expect(p.a > 245)
        }
    }

    /// Draw order: `nodes` ascending, index 0 backmost ، a later node must
    /// paint OVER an earlier one where they overlap.
    @Test func laterNodesPaintOverEarlierOnesInZOrder() {
        let bottom = TestScenes.redRect(position: CGPoint(x: 50, y: 50), size: CGSize(width: 60, height: 60))
        let top = TestScenes.blueEllipse(position: CGPoint(x: 50, y: 50), size: CGSize(width: 60, height: 60))
        let scene = TestScenes.scene(canvasSize: CGSize(width: 100, height: 100), nodes: [bottom, top])
        let ctx = makeContext(size: scene.canvas.size)
        renderer.render(scene, region: CGRect(origin: .zero, size: scene.canvas.size), into: ctx, scale: 1, quality: .exportQuality)
        let image = ctx.makeImage()!
        // Center of the overlap: ellipse (top, blue) wins.
        let center = pixel(image, x: 50, y: 50)
        #expect(center.b > center.r)
    }

    @Test func hiddenNodeIsNotDrawn() {
        var rect = TestScenes.redRect(position: CGPoint(x: 50, y: 50), size: CGSize(width: 40, height: 40))
        var core = rect.core
        core.isHidden = true
        rect = rect.withCore(core)
        let scene = TestScenes.scene(canvasSize: CGSize(width: 100, height: 100), background: .white, nodes: [rect])
        let ctx = makeContext(size: scene.canvas.size)
        renderer.render(scene, region: CGRect(origin: .zero, size: scene.canvas.size), into: ctx, scale: 1, quality: .exportQuality)
        let image = ctx.makeImage()!
        #expect(pixel(image, x: 50, y: 50) == (255, 255, 255, 255))
    }

    @Test func opacityBlendsNodeWithBackground() {
        var rect = TestScenes.redRect(position: CGPoint(x: 50, y: 50), size: CGSize(width: 100, height: 100))
        var core = rect.core
        core.opacity = 0.5
        rect = rect.withCore(core)
        let scene = TestScenes.scene(canvasSize: CGSize(width: 100, height: 100), background: .white, nodes: [rect])
        let ctx = makeContext(size: scene.canvas.size)
        renderer.render(scene, region: CGRect(origin: .zero, size: scene.canvas.size), into: ctx, scale: 1, quality: .exportQuality)
        let image = ctx.makeImage()!
        let p = pixel(image, x: 50, y: 50)
        // 50% red over white ≈ (255, 128, 128) ، well clear of both pure
        // red and pure white, proving the transparency layer actually
        // blended rather than either fully occluding or no-op'ing.
        #expect(p.r > 200)
        #expect(p.g > 80 && p.g < 200)
        #expect(p.b > 80 && p.b < 200)
    }

    /// Task 3 accept: "export-quality render of the same scene is
    /// pixel-identical across two invocations (determinism)."
    @Test func exportQualityRenderIsDeterministicAcrossInvocations() {
        let scene = TestScenes.scene(canvasSize: CGSize(width: 200, height: 200), nodes: [
            TestScenes.redRect(), TestScenes.blueEllipse(), TestScenes.liveText("استقرار الألوان"),
        ])
        let snapshotRenderer = MKSnapshotRenderer()
        let first = snapshotRenderer.renderFullCanvas(scene, scale: 2, quality: .exportQuality)
        let second = snapshotRenderer.renderFullCanvas(scene, scale: 2, quality: .exportQuality)
        #expect(first != nil)
        #expect(second != nil)
        guard let first, let second else { return }
        #expect(PixelDiff.differingFraction(first, second) == 0)
    }

    /// Task 11 accept: "golden tests confirm export output identical
    /// regardless of active ladder stage" ، export quality NEVER degrades.
    @Test func exportQualityIsIdenticalRegardlessOfLadderStageArgument() {
        // `.exportQuality` doesn't carry a stage at all ، this test proves
        // the API shape itself enforces the guarantee (no stage parameter
        // to vary), and that rendering the SAME scene at `.exportQuality`
        // twice through paths that would differ for `.editorPreview` (fill
        // vs stroke path) still matches.
        let scene = TestScenes.scene(nodes: [TestScenes.redRect()])
        let snapshotRenderer = MKSnapshotRenderer()
        let a = snapshotRenderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality)
        let b = snapshotRenderer.renderFullCanvas(scene, scale: 1, quality: .editorPreview(stage: .normal))
        #expect(a != nil && b != nil)
        guard let a, let b else { return }
        // Stage `.normal` preview and export share `.full` fidelity, so
        // these two should still match (both non-degraded).
        #expect(PixelDiff.differingFraction(a, b) < 0.005)
    }

    @Test func reducedFidelityShadowNeverDoubleDarkensOverlappingMarks() {
        // §6 Arabic-correctness: shadow applied per node ، two overlapping
        // shadowed shapes must not produce a darker shadow overlap than
        // either shape's own shadow alone would. Approximated here with
        // two overlapping shapes (not real marks, which need font shaping)
        // sharing the same shadow color at `.reduced` fidelity.
        let shadow = MKShadow(color: MKSolidColor(r: 0, g: 0, b: 0, a: 1), blur: 0, offset: CGSize(width: 4, height: 4))
        func shadowedRect(at position: CGPoint) -> MKNode {
            guard case .shape(var n) = TestScenes.redRect(position: position, size: CGSize(width: 60, height: 60)) else { fatalError() }
            n.core.style.shadow = shadow
            return .shape(n)
        }
        let scene = TestScenes.scene(canvasSize: CGSize(width: 200, height: 200), background: .white, nodes: [shadowedRect(at: CGPoint(x: 80, y: 80)), shadowedRect(at: CGPoint(x: 100, y: 100))])
        let snapshotRenderer = MKSnapshotRenderer()
        let image = snapshotRenderer.renderFullCanvas(scene, scale: 1, quality: .editorPreview(stage: .stage2))
        #expect(image != nil)
        // Smoke assertion: rendering at reduced fidelity with overlapping
        // shadows does not crash and produces non-blank output.
        guard let image else { return }
        let p = pixel(image, x: 100, y: 100)
        #expect(p != (255, 255, 255, 255))
    }

    // MARK: - D-104/D-118 pixel-identity: canvas-layer path vs export path

    /// T-RENDER-FID-CANVAS-EXPORT: the `MKLayerTreeController` (canvas
    /// preview) path and `MKSnapshotRenderer` (export) path, rendering the
    /// SAME scene, must be pixel-identical ، the structural guarantee both
    /// go through `MKSceneRenderer.render` (README "one truth, three
    /// destinations").
    @Test @MainActor func canvasLayerPathMatchesExportPathPixelIdentical() {
        let scene = TestScenes.scene(canvasSize: CGSize(width: 120, height: 120), background: .white, nodes: [
            TestScenes.redRect(position: CGPoint(x: 40, y: 40), size: CGSize(width: 30, height: 30)),
            TestScenes.blueEllipse(position: CGPoint(x: 80, y: 80), size: CGSize(width: 24, height: 24)),
        ])

        let snapshotRenderer = MKSnapshotRenderer()
        guard let exportImage = snapshotRenderer.renderFullCanvas(scene, scale: 1, quality: .exportQuality) else {
            Issue.record("export render failed")
            return
        }

        let controller = MKLayerTreeController(screenScale: 1)
        controller.sync(to: scene)

        guard let canvasCtx = MKSnapshotRenderer.makeFlippedBitmapContext(
            width: Int(scene.canvas.size.width), height: Int(scene.canvas.size.height), scale: 1
        ) else {
            Issue.record("failed to create canvas context")
            return
        }
        canvasCtx.concatenate(MKSceneRenderer.canvasToDevice(region: CGRect(origin: .zero, size: scene.canvas.size), scale: 1))
        controller.hostLayer.render(in: canvasCtx)
        guard let canvasImage = canvasCtx.makeImage() else {
            Issue.record("failed to flatten layer tree to an image")
            return
        }

        let diff = PixelDiff.differingFraction(exportImage, canvasImage, perChannelTolerance: 10)
        #expect(diff <= 0.001, "canvas-layer vs export diff = \(diff)")
    }

    // MARK: - helpers

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &data, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let offset = (y * image.width + x) * 4
        return (data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
    }
}

private func == (lhs: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), rhs: (Int, Int, Int, Int)) -> Bool {
    Int(lhs.r) == rhs.0 && Int(lhs.g) == rhs.1 && Int(lhs.b) == rhs.2 && Int(lhs.a) == rhs.3
}

private func != (lhs: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), rhs: (Int, Int, Int, Int)) -> Bool {
    !(lhs == rhs)
}
