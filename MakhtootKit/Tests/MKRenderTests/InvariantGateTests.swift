import Testing
import CoreGraphics
import Foundation
import MKFoundation
import MKModel
@testable import MKRender

/// §6 Arabic-correctness notes: "Never rasterize text through UILabel/
/// screen capture anywhere (D-118); grep gate for
/// `UIGraphicsGetImageFromCurrentImageContext`/`drawHierarchy` in
/// MKRender = zero." Automated so a future edit can't silently reintroduce
/// a screen-capture text path without a test failing.
@Suite struct InvariantGateTests {
    @Test func noScreenCaptureTextRasterizationAPIsAnywhereInMKRenderSources() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MKRenderTests/
            .deletingLastPathComponent()   // Tests/
            .appendingPathComponent("Sources/MKRender")

        let forbidden = ["UIGraphicsGetImageFromCurrentImageContext", "drawHierarchy(in:", "UILabel"]
        var offenders: [String] = []

        let enumerator = FileManager.default.enumerator(at: sourcesDir, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for needle in forbidden where contents.contains(needle) {
                offenders.append("\(url.lastPathComponent): \(needle)")
            }
        }

        #expect(offenders.isEmpty, "forbidden screen-capture/UILabel text APIs found: \(offenders)")
    }

    /// Task 6 accept: "drag test with signposts shows zero draw(in:)/
    /// bitmap work during gesture." Verified here as "the committed
    /// bitmap's identity never changes across N transient-transform calls,
    /// and `consumeRasterizationCount()` stays at whatever `sync(to:)`
    /// alone produced" ، a structural proxy for "no re-render happened,"
    /// exercised without needing an Instruments trace.
    @Test @MainActor func transientTransformNeverTriggersRasterization() {
        let scene = TestScenes.scene(nodes: [TestScenes.redRect(position: CGPoint(x: 50, y: 50))])
        let controller = MKLayerTreeController(screenScale: 1)
        controller.sync(to: scene)
        _ = controller.consumeRasterizationCount()   // drain the initial sync's count

        guard let nodeID = scene.nodes.first?.id else {
            Issue.record("expected a node")
            return
        }
        for i in 0..<30 {
            let live = CGAffineTransform(translationX: CGFloat(i), y: CGFloat(i))
            controller.applyTransientTransform(nodeID: nodeID, transform: live)
        }

        #expect(controller.consumeRasterizationCount() == 0)
    }

    /// Task 5 accept: "editing one node re-rasterizes exactly one layer."
    @Test @MainActor func editingOneNodeRerasterizesExactlyOneLayer() {
        let a = TestScenes.redRect(position: CGPoint(x: 20, y: 20))
        let b = TestScenes.blueEllipse(position: CGPoint(x: 80, y: 80))
        var scene = TestScenes.scene(nodes: [a, b])
        let controller = MKLayerTreeController(screenScale: 1)
        controller.sync(to: scene)
        _ = controller.consumeRasterizationCount()

        // Recolor ONLY `a` ، a content-affecting edit.
        guard case .shape(var shapeA) = a else { fatalError() }
        shapeA.core.style.fill = .solid(MKSolidColor(r: 0, g: 1, b: 0, a: 1))
        scene = MKScene(canvas: scene.canvas, background: scene.background, nodes: [.shape(shapeA), b])
        controller.sync(to: scene)

        #expect(controller.consumeRasterizationCount() == 1)
    }
}
