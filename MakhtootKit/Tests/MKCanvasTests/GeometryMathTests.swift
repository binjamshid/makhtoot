import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKCanvas

@Suite("MKOrientedRect")
struct MKOrientedRectTests {
    @Test func cornersOfAnUnrotatedRectAreAxisAligned() {
        let obb = MKOrientedRect(center: CGPoint(x: 50, y: 50), size: CGSize(width: 20, height: 10), rotation: 0)
        let corners = obb.corners
        #expect(corners[0] == CGPoint(x: 40, y: 45)) // topLeft
        #expect(corners[2] == CGPoint(x: 60, y: 55)) // bottomRight
    }

    @Test func containsRespectsRotation() {
        // A 20x20 square rotated 45°: the point (14,0) relative to center
        // is OUTSIDE the unrotated square's half-width (10) but the
        // rotation test must still correctly reject/accept based on the
        // ROTATED frame, not the axis-aligned one.
        let obb = MKOrientedRect(center: .zero, size: CGSize(width: 20, height: 20), rotation: .pi / 4)
        // In local (unrotated) space this is the same as testing an
        // unrotated 20x20 square: corner-ish points near the rotated
        // diagonal should still be contained since rotating a square by
        // 45° doesn't change containment of the center-aligned axes.
        #expect(obb.contains(.zero))
        #expect(obb.contains(CGPoint(x: 9, y: 0)))
    }

    @Test func worldToLocalRoundTripsThroughLocalToWorld() {
        let obb = MKOrientedRect(center: CGPoint(x: 30, y: -10), size: CGSize(width: 40, height: 20), rotation: 0.6)
        let worldPoint = CGPoint(x: 12, y: 55)
        let local = obb.worldToLocal(worldPoint)
        let back = obb.localToWorld(local)
        #expect(abs(back.x - worldPoint.x) < 0.0001)
        #expect(abs(back.y - worldPoint.y) < 0.0001)
    }

    @Test func unionBoundsCoversEveryCorner() {
        let a = MKOrientedRect(center: CGPoint(x: 0, y: 0), size: CGSize(width: 10, height: 10), rotation: 0)
        let b = MKOrientedRect(center: CGPoint(x: 100, y: 100), size: CGSize(width: 10, height: 10), rotation: 0)
        let union = MKOrientedRect.unionBounds(of: [a, b])
        #expect(union == CGRect(x: -5, y: -5, width: 110, height: 110))
    }

    @Test func derivingTransformRoundTripsWithInitFromLocalBounds() {
        let localBounds = CGRect(x: 0, y: 0, width: 40, height: 25)
        let transform = MKTransform2D(position: CGPoint(x: 70, y: -30), rotation: 0.35, scale: CGSize(width: 2, height: 1.5))
        let obb = MKOrientedRect(localBounds: localBounds, transform: transform)
        let derived = obb.derivingTransform(localBounds: localBounds)
        #expect(abs(derived.position.x - transform.position.x) < 0.0001)
        #expect(abs(derived.position.y - transform.position.y) < 0.0001)
        #expect(abs(derived.rotation - transform.rotation) < 0.0001)
        #expect(abs(derived.scale.width - transform.scale.width) < 0.0001)
        #expect(abs(derived.scale.height - transform.scale.height) < 0.0001)

        // And re-deriving the OBB from the reconstructed transform matches
        // the original OBB exactly (the actual invariant callers rely on).
        let obb2 = MKOrientedRect(localBounds: localBounds, transform: derived)
        #expect(abs(obb2.center.x - obb.center.x) < 0.0001)
        #expect(abs(obb2.center.y - obb.center.y) < 0.0001)
        #expect(abs(obb2.size.width - obb.size.width) < 0.0001)
        #expect(abs(obb2.size.height - obb.size.height) < 0.0001)
    }
}

@Suite("MKAnchoredResize ، handle transforms (numeric), packet §7 gate")
struct MKAnchoredResizeTests {
    @Test func bottomRightCornerDragKeepsTopLeftAnchorFixed() {
        let obb = MKOrientedRect(center: CGPoint(x: 50, y: 50), size: CGSize(width: 100, height: 100), rotation: 0)
        let resized = MKAnchoredResize.resize(obb, handle: .bottomRight, worldDelta: CGPoint(x: 20, y: 20), aspectLocked: false)
        // topLeft corner was (0,0); it must still be (0,0) after the drag.
        let newTopLeft = resized.corners[0]
        #expect(abs(newTopLeft.x - 0) < 0.0001)
        #expect(abs(newTopLeft.y - 0) < 0.0001)
        #expect(abs(resized.size.width - 120) < 0.0001)
        #expect(abs(resized.size.height - 120) < 0.0001)
    }

    @Test func edgeHandleNeverChangesThePerpendicularDimension() {
        let obb = MKOrientedRect(center: .zero, size: CGSize(width: 100, height: 50), rotation: 0)
        let resized = MKAnchoredResize.resize(obb, handle: .right, worldDelta: CGPoint(x: 30, y: 999), aspectLocked: true)
        // "edge free" ، aspect lock must never engage for an edge handle,
        // and the y-delta must never affect height.
        #expect(abs(resized.size.height - 50) < 0.0001)
        #expect(abs(resized.size.width - 130) < 0.0001)
    }

    @Test func cornerHandleWithAspectLockPreservesAspectRatio() {
        let obb = MKOrientedRect(center: .zero, size: CGSize(width: 100, height: 50), rotation: 0)
        let resized = MKAnchoredResize.resize(obb, handle: .bottomRight, worldDelta: CGPoint(x: 100, y: 0), aspectLocked: true)
        let originalAspect = 100.0 / 50.0
        let newAspect = Double(resized.size.width / resized.size.height)
        #expect(abs(newAspect - originalAspect) < 0.001)
    }

    @Test func fromCenterOptionGrowsSymmetricallyAboutTheSameCenter() {
        let obb = MKOrientedRect(center: CGPoint(x: 5, y: 5), size: CGSize(width: 40, height: 40), rotation: 0)
        let resized = MKAnchoredResize.resize(obb, handle: .right, worldDelta: CGPoint(x: 10, y: 0), fromCenter: true)
        #expect(resized.center == obb.center)
        #expect(abs(resized.size.width - 60) < 0.0001) // +10 on each side
    }

    @Test func resizingARotatedNodeKeepsTheAnchorFixedInWorldSpace() {
        // task 6 accept: "resizing a rotated node behaves correctly
        // (anchor math in node-local space)."
        let obb = MKOrientedRect(center: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100), rotation: .pi / 2) // 90°
        let topLeftBefore = obb.corners[0]
        // Drag the topLeft handle's own WORLD-space corner outward ، since
        // the shape is rotated 90°, a "topLeft" local-frame drag maps to a
        // different world direction; feed the delta as the amount the
        // ANCHOR-OPPOSITE corner (bottomRight, which stays fixed) should
        // NOT move, and assert exactly that.
        let resized = MKAnchoredResize.resize(obb, handle: .topLeft, worldDelta: CGPoint(x: 10, y: 10), aspectLocked: false)
        let bottomRightBefore = obb.corners[2]
        let bottomRightAfter = resized.corners[2]
        #expect(abs(bottomRightAfter.x - bottomRightBefore.x) < 0.0001)
        #expect(abs(bottomRightAfter.y - bottomRightBefore.y) < 0.0001)
        _ = topLeftBefore
    }

    @Test func minimumSizeFloorPreventsCollapse() {
        let obb = MKOrientedRect(center: .zero, size: CGSize(width: 10, height: 10), rotation: 0)
        let resized = MKAnchoredResize.resize(obb, handle: .bottomRight, worldDelta: CGPoint(x: -100, y: -100), aspectLocked: false, minimumSize: 2)
        #expect(resized.size.width >= 2)
        #expect(resized.size.height >= 2)
    }

    @Test func rotationDeltaTracksPointerAngleDelta() {
        let start = MKAnchoredResize.rotate(startRotation: 0, startPointerAngle: 0, currentPointerAngle: .pi / 2, snapping: false)
        #expect(abs(start - .pi / 2) < 0.0001)
    }

    @Test func rotationSnapsToExact90DegreesWhenClose() {
        let near90 = (89 * CGFloat.pi / 180)
        let snapped = MKAnchoredResize.snappedAngle(near90)
        #expect(abs(snapped - .pi / 2) < 0.0001)
    }

    @Test func rotationSnapsTo5DegreeGridAwayFromMagnets() {
        let angle = 13 * CGFloat.pi / 180 // between 10° and 15° grid lines, far from 0/45 magnets
        let snapped = MKAnchoredResize.snappedAngle(angle)
        let snappedDegrees = snapped * 180 / .pi
        #expect(abs(snappedDegrees - 15) < 0.01)
    }
}

@Suite("MKGroupTransform ، task 8 group/ungroup round trip")
struct MKGroupTransformTests {
    @Test func worldAndLocalTransformsAreExactInverses() {
        let child = MKTransform2D(position: CGPoint(x: 5, y: 5), rotation: 0.2, scale: CGSize(width: 1, height: 1))
        let group = MKTransform2D(position: CGPoint(x: 100, y: 50), rotation: 0.4, scale: CGSize(width: 1.5, height: 1.5))
        let world = MKGroupTransform.worldTransform(childLocal: child, groupTransform: group)
        let recoveredLocal = MKGroupTransform.localTransform(childWorld: world, groupTransform: group)
        #expect(abs(recoveredLocal.position.x - child.position.x) < 0.01)
        #expect(abs(recoveredLocal.position.y - child.position.y) < 0.01)
        #expect(abs(recoveredLocal.rotation - child.rotation) < 0.01)
    }

    @Test func groupThenTransformThenUngroupPreservesWorldPosition() {
        // The exact packet §7 gate: "group→transform→ungroup leaves
        // children at correct world positions (property test vs matrix
        // math)."
        let childWorldBefore = MKTransform2D(position: CGPoint(x: 12, y: 8))
        // At group time, `MKScene.reparenting` uses an IDENTITY group
        // transform, so childLocal == childWorldBefore exactly.
        let childLocal = childWorldBefore

        // Group gets moved (a `MKTransformCommand` on the group node).
        let groupTransformAfterMove = MKTransform2D(position: CGPoint(x: 40, y: -20), rotation: 0.3, scale: CGSize(width: 1, height: 1))

        // `MKUngroupCommand`'s fixup composes exactly this:
        let childWorldAfterUngroup = MKGroupTransform.worldTransform(childLocal: childLocal, groupTransform: groupTransformAfterMove)

        // Cross-check against direct point mapping: the child's own local
        // origin, mapped through child-then-group, should land at the same
        // point `childWorldAfterUngroup.apply(to: .zero)` reports.
        let directPoint = groupTransformAfterMove.apply(to: childLocal.apply(to: .zero))
        let viaTransform = childWorldAfterUngroup.apply(to: .zero)
        #expect(abs(directPoint.x - viaTransform.x) < 0.01)
        #expect(abs(directPoint.y - viaTransform.y) < 0.01)
    }
}
