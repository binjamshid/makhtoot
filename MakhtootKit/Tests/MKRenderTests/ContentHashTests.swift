import Testing
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKRender

/// WS-07 packet §5 task 7 accept criterion: "transform-only edit does not
/// invalidate cache; fill-color edit does."
@Suite struct ContentHashTests {
    @Test func transformOnlyEditDoesNotChangeHash() {
        let node = TestScenes.redRect()
        var movedCore = node.core
        movedCore.transform.position = CGPoint(x: 999, y: 999)
        movedCore.transform.rotation = .pi / 3
        let moved = node.withCore(movedCore)

        let before = MKContentHash.hash(of: node, scaleBucket: 1)
        let after = MKContentHash.hash(of: moved, scaleBucket: 1)
        #expect(before == after)
    }

    @Test func opacityOnlyEditDoesNotChangeHash() {
        let node = TestScenes.redRect()
        var opaqueCore = node.core
        opaqueCore.opacity = 0.2
        let dimmed: MKNode = node.withCore(opaqueCore)

        #expect(MKContentHash.hash(of: node, scaleBucket: 1) == MKContentHash.hash(of: dimmed, scaleBucket: 1))
    }

    @Test func fillColorEditChangesHash() {
        guard case .shape(let shapeNode) = TestScenes.redRect() else { fatalError() }
        var recoloredCore = shapeNode.core
        recoloredCore.style.fill = .solid(MKSolidColor(r: 0, g: 1, b: 0, a: 1))
        let recolored = MKNode.shape(MKShapeNode(core: recoloredCore, geometry: shapeNode.geometry))

        #expect(MKContentHash.hash(of: .shape(shapeNode), scaleBucket: 1) != MKContentHash.hash(of: recolored, scaleBucket: 1))
    }

    @Test func textStringEditChangesHash() {
        let a = TestScenes.liveText("مرحبا")
        let b = TestScenes.liveText("وداعا")
        #expect(MKContentHash.hash(of: a, scaleBucket: 1) != MKContentHash.hash(of: b, scaleBucket: 1))
    }

    @Test func differentScaleBucketChangesHash() {
        let node = TestScenes.redRect()
        #expect(MKContentHash.hash(of: node, scaleBucket: 1) != MKContentHash.hash(of: node, scaleBucket: 2))
    }

    @Test func hashIsStableAcrossRepeatedCalls() {
        let node = TestScenes.liveText("استقرار")
        let a = MKContentHash.hash(of: node, scaleBucket: 1.5)
        let b = MKContentHash.hash(of: node, scaleBucket: 1.5)
        #expect(a == b)
    }

    // MARK: - Scale bucket quantization

    /// §11.3: buckets are powers of √2 STARTING AT `minScale` (0.025) ،
    /// the sequence `0.025 × (√2)^n` does not necessarily pass through
    /// exactly 1.0, so this checks the actual documented contract ("nearest
    /// at or BELOW") rather than a specific numeric bucket value.
    @Test func scaleBucketQuantizesDownNeverUp() {
        let raw = 1.3
        let bucket = MKScaleBucket.quantize(raw)
        #expect(bucket <= raw)
        // The next bucket up (× √2) must exceed `raw`, or quantize would
        // have picked THAT one instead ، i.e. `bucket` really is the
        // nearest-at-or-below, not just "some" bucket below `raw`.
        #expect(bucket * 2.0.squareRoot() > raw + 0.0001)
    }

    @Test func scaleBucketIsIdempotent() {
        let once = MKScaleBucket.quantize(3.7)
        let twice = MKScaleBucket.quantize(once)
        #expect(abs(once - twice) < 0.0001)
    }

    @Test func scaleBucketClampsToDocumentedRange() {
        #expect(MKScaleBucket.quantize(0.001) == MKScaleBucket.minScale)
        // Values at/above `maxScale` quantize to the LARGEST valid bucket
        // at or below `maxScale` (never above it, and never simply clamped
        // to the raw ceiling ، see `scaleBucketQuantizesDownNeverUp`).
        let atCeiling = MKScaleBucket.quantize(1000)
        #expect(atCeiling <= MKScaleBucket.maxScale)
        #expect(atCeiling > MKScaleBucket.maxScale / 2.0.squareRoot())
    }
}
