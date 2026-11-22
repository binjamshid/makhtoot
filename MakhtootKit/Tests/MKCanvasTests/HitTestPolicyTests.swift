import CoreGraphics
import MKFoundation
import Testing
@testable import MKCanvas

@Suite("MKHitTestPolicy")
struct MKHitTestPolicyTests {
    private func candidate(x: CGFloat, y: CGFloat, z: Int, locked: Bool = false, hidden: Bool = false) -> MKHitCandidate {
        MKHitCandidate(
            nodeID: MKNodeID(),
            worldOBB: MKOrientedRect(center: CGPoint(x: x, y: y), size: CGSize(width: 20, height: 20), rotation: 0),
            zIndex: z, isLocked: locked, isHidden: hidden
        )
    }

    @Test func topmostZIndexWinsAtAnOverlappingPoint() {
        let bottom = candidate(x: 0, y: 0, z: 0)
        let top = candidate(x: 0, y: 0, z: 1)
        let hit = MKHitTestPolicy.topHit(at: .zero, in: [bottom, top], tolerance: 0)
        #expect(hit == top.nodeID)
    }

    @Test func lockedNodeFallsThroughToTheNodeBelow() {
        // Packet §5 task 3 accept criterion, literal wording: "locked node
        // taps fall through to node below." (Flagged elsewhere as
        // disagreeing with ARCHITECTURE §10.3 ، this test asserts the
        // packet's own literal behavior.)
        let bottom = candidate(x: 0, y: 0, z: 0)
        let lockedTop = candidate(x: 0, y: 0, z: 1, locked: true)
        let hit = MKHitTestPolicy.topHit(at: .zero, in: [bottom, lockedTop], tolerance: 0)
        #expect(hit == bottom.nodeID)
    }

    @Test func hiddenNodesAreNeverHit() {
        let hidden = candidate(x: 0, y: 0, z: 0, hidden: true)
        let hit = MKHitTestPolicy.topHit(at: .zero, in: [hidden], tolerance: 0)
        #expect(hit == nil)
    }

    @Test func emptyCanvasTapReturnsNil() {
        let hit = MKHitTestPolicy.topHit(at: CGPoint(x: 500, y: 500), in: [candidate(x: 0, y: 0, z: 0)], tolerance: 0)
        #expect(hit == nil)
    }

    @Test func toleranceExpandsTheHitArea() {
        let far = candidate(x: 15, y: 0, z: 0) // OBB spans x: 5...25 (half-width 10)
        #expect(MKHitTestPolicy.topHit(at: CGPoint(x: 30, y: 0), in: [far], tolerance: 0) == nil)
        #expect(MKHitTestPolicy.topHit(at: CGPoint(x: 30, y: 0), in: [far], tolerance: 10) == far.nodeID)
    }

    @Test func touchToleranceShrinksAsZoomIncreases() {
        let tightZoom = MKHitTestPolicy.touchTolerance(zoomScale: 4)
        let looseZoom = MKHitTestPolicy.touchTolerance(zoomScale: 0.5)
        #expect(tightZoom < looseZoom)
        #expect(tightZoom >= MKHitTestPolicy.minimumCanvasTolerance)
    }

    @Test func tapCyclingWalksOccludedObjectsOnRepeatedTaps() {
        let a = MKNodeID()
        let b = MKNodeID()
        let c = MKNodeID()
        var state = MKHitTestPolicy.TapCycleState()
        let point = CGPoint(x: 10, y: 10)
        let first = state.select(from: [a, b, c], at: point, now: 0)
        let second = state.select(from: [a, b, c], at: point, now: 0.1)
        let third = state.select(from: [a, b, c], at: point, now: 0.2)
        let wraps = state.select(from: [a, b, c], at: point, now: 0.3)
        #expect(first == a)
        #expect(second == b)
        #expect(third == c)
        #expect(wraps == a)
    }

    @Test func tapCyclingResetsAfterTheCycleWindowElapses() {
        let a = MKNodeID()
        let b = MKNodeID()
        var state = MKHitTestPolicy.TapCycleState()
        let point = CGPoint(x: 10, y: 10)
        _ = state.select(from: [a, b], at: point, now: 0)
        let afterWindow = state.select(from: [a, b], at: point, now: MKHitTestPolicy.TapCycleState.cycleWindow + 1)
        #expect(afterWindow == a)
    }

    @Test func tapCyclingResetsWhenTheTapMovesTooFar() {
        let a = MKNodeID()
        let b = MKNodeID()
        var state = MKHitTestPolicy.TapCycleState()
        _ = state.select(from: [a, b], at: CGPoint(x: 0, y: 0), now: 0)
        let movedFar = state.select(from: [a, b], at: CGPoint(x: 200, y: 200), now: 0.1)
        #expect(movedFar == a)
    }
}
