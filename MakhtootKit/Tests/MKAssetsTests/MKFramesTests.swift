import CoreGraphics
import Foundation
import MKModel
import Testing
@testable import MKAssets

// WS-14 packet §5 task 6 accept criteria: "frames place + transform
// correctly; non-uniform-scale behavior documented; ≥3 free."
@Suite("MKFrameGenerator (T6)")
struct MKFramesTests {
    @Test func atLeastEightFramesWithAtLeastThreeFree() {
        let frames = MKFrameGenerator.makeAll()
        #expect(frames.count >= 8)
        #expect(frames.allSatisfy { $0.category == .frames })
        #expect(frames.filter { !$0.isPremium }.count >= 3)
        #expect(Set(frames.map(\.assetID)).count == frames.count)
    }

    @Test func framesPlaceAndTransformCorrectly() {
        let instantiator = MKAssetInstantiator()
        for frame in MKFrameGenerator.makeAll() {
            let placement = instantiator.place(frame, at: CGPoint(x: 50, y: 60), scale: CGSize(width: 2, height: 2))
            guard case .shape(let shapeNode) = placement.node else {
                Issue.record("\(frame.assetID) did not instantiate as a shape node")
                continue
            }
            #expect(shapeNode.core.transform.position == CGPoint(x: 50, y: 60))
            #expect(shapeNode.core.transform.scale == CGSize(width: 2, height: 2))
        }
    }

    /// Task 6's explicit v1 simplification: "uniform scale allowed,
    /// non-uniform documented as seam; keep model field now." Verifies the
    /// seam field exists and is populated for the rectangular frames (where
    /// a 9-slice margin is a meaningful concept) without v1 actually
    /// stretching edges independently ، i.e. `MKAssetInstantiator.place`
    /// applies `scale` uniformly to the WHOLE geometry regardless of
    /// `nineSliceInsets` being present.
    @Test func nineSliceInsetsAreRecordedForRectangularFramesButUniformScaleIsWhatV1Applies() {
        let rectSingle = MKFrameGenerator.makeAll().first { $0.assetID == "frame.rect-single-rule" }!
        #expect(rectSingle.nineSliceInsets != nil)

        let instantiator = MKAssetInstantiator()
        let placement = instantiator.place(rectSingle, scale: CGSize(width: 3, height: 1)) // non-uniform
        guard case .shape(let shapeNode) = placement.node else {
            Issue.record("expected shape node")
            return
        }
        // v1 behavior: the transform's scale is applied as-is (uniformly
        // across the WHOLE path, corners included) ، no edge/corner
        // differentiation happens anywhere in this module. This test locks
        // that documented limitation rather than silently assuming
        // 9-slice stretching exists.
        #expect(shapeNode.core.transform.scale == CGSize(width: 3, height: 1))
    }

    @Test func archAndCartoucheFramesHaveNoNineSliceInsets() {
        let arch = MKFrameGenerator.makeAll().first { $0.assetID == "frame.arch" }!
        let cartouche = MKFrameGenerator.makeAll().first { $0.assetID == "frame.cartouche" }!
        #expect(arch.nineSliceInsets == nil)
        #expect(cartouche.nineSliceInsets == nil)
    }

    @Test func everyFrameHasAHollowCenterUnderNonzeroFill() {
        // A structural "this is actually a FRAME (hollow), not a solid
        // rect" check: the geometric center of every frame's local bounds
        // must be unpainted.
        for frame in MKFrameGenerator.makeAll() {
            let image = MKAssetThumbnailRenderer.render(descriptor: frame, size: CGSize(width: 200, height: 200))
            #expect(image != nil, "\(frame.assetID)")
            guard let image else { continue }
            let alpha = centerAlpha(of: image)
            #expect(alpha == 0, "\(frame.assetID) center should be hollow, got alpha \(alpha)")
        }
    }

    private func centerAlpha(of image: CGImage) -> UInt8 {
        guard let data = image.dataProvider?.data else { return 255 }
        let ptr = CFDataGetBytePtr(data)!
        let x = image.width / 2
        let y = image.height / 2
        let offset = y * image.bytesPerRow + x * 4
        return ptr[offset + 3]
    }
}
