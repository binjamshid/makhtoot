import CoreGraphics
import Foundation
@testable import MKCanvas
import MKFoundation
import MKModel
import Testing

// Regression coverage for the 2026-07-29 user reports:
//   * "resizing text makes the text go to the far left"
//   * "text corner handles only move text but doesn't reliably resize it"
//   * "rotate handle is too close to middle top handle and doesn't work
//      reliably"
//
// All three are handle-geometry defects, and all three are the kind that
// only show up under a finger on a real canvas ، so they are pinned here as
// pure numeric properties.

@Suite("Handle geometry regressions")
struct HandleGeometryRegressionTests {
    // MARK: - Grab targets

    /// The whole point of the fix: a handle's tappable area is a constant
    /// 44 × 44 SCREEN points at any zoom, which in world units means the
    /// radius grows as you zoom out. The old `max(16, diameter / zoom)`
    /// was world-constant with a floor, so it collapsed to an 8-point
    /// on-screen target at 0.5× and every near-miss fell through to the
    /// move gesture ، "the corner handle drags the object instead of
    /// resizing it".
    @Test("handle grab targets stay a constant size on screen across zoom")
    func grabRadiusIsScreenConstant() {
        let obb = MKOrientedRect(center: CGPoint(x: 100, y: 100), size: CGSize(width: 80, height: 60), rotation: 0)
        let corner = MKSelectionHandleLayout.worldPosition(of: .bottomRight, on: obb)

        for zoom in [0.25, 0.5, 1.0, 2.0, 4.0] as [CGFloat] {
            let radius = MKSelectionHandleLayout.grabRadiusScreenPoints / zoom
            // Just inside the target, expressed in world units for this
            // zoom ، must hit at every zoom level.
            let near = CGPoint(x: corner.x + radius * 0.8, y: corner.y)
            #expect(
                MKSelectionHandleLayout.handle(at: near, on: obb, zoomScale: zoom) == .bottomRight,
                "corner handle unreachable at zoom \(zoom)")
        }
    }

    @Test("a tap far from every handle grabs none of them")
    func farTapMissesEveryHandle() {
        let obb = MKOrientedRect(center: CGPoint(x: 100, y: 100), size: CGSize(width: 80, height: 60), rotation: 0)
        #expect(MKSelectionHandleLayout.handle(at: CGPoint(x: 100, y: 100), on: obb, zoomScale: 1) == nil)
        #expect(MKSelectionHandleLayout.handle(at: CGPoint(x: 400, y: 400), on: obb, zoomScale: 1) == nil)
    }

    // MARK: - Rotate knob

    /// The knob offset used to be applied as a flat WORLD distance, so at
    /// low zoom it collapsed onto the top-centre handle. Now it is divided
    /// by the zoom scale, which means the on-SCREEN gap is invariant.
    @Test("the rotate knob sits a constant distance above the top edge on screen")
    func rotateKnobGapIsScreenConstant() {
        let obb = MKOrientedRect(center: CGPoint(x: 100, y: 100), size: CGSize(width: 80, height: 60), rotation: 0)
        for zoom in [0.25, 0.5, 1.0, 2.0, 4.0] as [CGFloat] {
            let top = MKSelectionHandleLayout.worldPosition(of: .top, on: obb, zoomScale: zoom)
            let knob = MKSelectionHandleLayout.worldPosition(of: .rotate, on: obb, zoomScale: zoom)
            let screenGap = (top.y - knob.y) * zoom
            #expect(abs(screenGap - MKAnchoredResize.rotateKnobOffset) < 1e-6, "gap drifted at zoom \(zoom)")
        }
    }

    /// The other half of "the rotate handle doesn't work reliably": handle
    /// positions live in a `Dictionary`, and the old first-match loop over
    /// its unspecified iteration order meant an overlapping tap resolved
    /// differently between runs. Nearest-wins is deterministic ، and with
    /// a 44-point offset against a 22-point grab radius the two targets no
    /// longer overlap at all.
    @Test("rotate and top-centre targets are disjoint and resolve deterministically")
    func rotateAndTopDoNotCompete() {
        let obb = MKOrientedRect(center: CGPoint(x: 100, y: 100), size: CGSize(width: 80, height: 60), rotation: 0)
        for zoom in [0.25, 0.5, 1.0, 2.0] as [CGFloat] {
            let top = MKSelectionHandleLayout.worldPosition(of: .top, on: obb, zoomScale: zoom)
            let knob = MKSelectionHandleLayout.worldPosition(of: .rotate, on: obb, zoomScale: zoom)
            #expect(MKSelectionHandleLayout.handle(at: top, on: obb, zoomScale: zoom) == .top)
            #expect(MKSelectionHandleLayout.handle(at: knob, on: obb, zoomScale: zoom) == .rotate)
            // Repeated queries must agree ، the property the Dictionary
            // iteration order used to break.
            for _ in 0..<20 {
                #expect(MKSelectionHandleLayout.handle(at: knob, on: obb, zoomScale: zoom) == .rotate)
            }
        }
    }

    // MARK: - Intrinsic bounds

    /// `MKOrientedRect.derivingTransform(localBounds:)` anchors the derived
    /// position on `localBounds.midX/.midY`, so it is only the inverse of
    /// `init(localBounds:transform:)` when handed the SAME rect. Feeding it
    /// a synthesized origin-anchored rect ، which is what
    /// `HandleGestures`/`InspectorModel.setSize` used to do ، teleports
    /// every node whose real local bounds are not origin-anchored: shapes
    /// and images (unit square centred on the origin), path text (bezier
    /// bbox outset by a line height) and arranged compositions
    /// (`originFrame`). "Resizing text makes the text go to the far left"
    /// is this bug, seen on an arranged composition.
    @Test("round-tripping a centred-unit-square node's OBB does not move it")
    func centredLocalBoundsRoundTripIsIdentity() {
        let localBounds = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)   // shapes/images
        let transform = MKTransform2D(
            position: CGPoint(x: 120, y: 200), rotation: 0.4, scale: CGSize(width: 60, height: 40))

        let obb = MKOrientedRect(localBounds: localBounds, transform: transform)
        let derived = obb.derivingTransform(localBounds: localBounds)

        #expect(abs(derived.position.x - transform.position.x) < 1e-6)
        #expect(abs(derived.position.y - transform.position.y) < 1e-6)
        #expect(abs(derived.scale.width - transform.scale.width) < 1e-6)
        #expect(abs(derived.scale.height - transform.scale.height) < 1e-6)

        // And the old behaviour, pinned as the thing that was wrong: the
        // synthesized origin-anchored rect displaces the node by a full
        // half of its own size along each axis.
        let synthesized = CGRect(origin: .zero, size: CGSize(width: 1, height: 1))
        let wrong = obb.derivingTransform(localBounds: synthesized)
        let displacement = hypot(wrong.position.x - transform.position.x, wrong.position.y - transform.position.y)
        #expect(displacement > 30, "fixture no longer demonstrates the defect it pins")
    }

    /// Live text IS origin-anchored (`MKNodeLocalBounds`'s `.liveText`
    /// case returns `CGRect(x: 0, y: 0, …)`), which is why the old
    /// synthesized rect happened to be right for it ، and why the defect
    /// looked kind-specific rather than systematic.
    @Test("an origin-anchored node round-trips under either rect")
    func originAnchoredLocalBoundsRoundTripIsIdentity() {
        let localBounds = CGRect(x: 0, y: 0, width: 220, height: 60)
        let transform = MKTransform2D(
            position: CGPoint(x: 40, y: 90), rotation: 0, scale: CGSize(width: 2, height: 2))

        let obb = MKOrientedRect(localBounds: localBounds, transform: transform)
        let derived = obb.derivingTransform(localBounds: localBounds)

        #expect(abs(derived.position.x - transform.position.x) < 1e-6)
        #expect(abs(derived.position.y - transform.position.y) < 1e-6)
    }
}
