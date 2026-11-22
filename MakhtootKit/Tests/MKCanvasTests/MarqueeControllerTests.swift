import CoreGraphics
import MKFoundation
import Testing
@testable import MKCanvas

@Suite("MKMarqueeController ، packet §7 gate: marquee hit-sets")
struct MKMarqueeControllerTests {
    private func candidate(x: CGFloat, y: CGFloat, w: CGFloat = 20, h: CGFloat = 20, locked: Bool = false, hidden: Bool = false) -> MKHitCandidate {
        MKHitCandidate(nodeID: MKNodeID(), worldOBB: MKOrientedRect(center: CGPoint(x: x, y: y), size: CGSize(width: w, height: h), rotation: 0), zIndex: 0, isLocked: locked, isHidden: hidden)
    }

    @Test func rectNormalizesAnyDragDirection() {
        let r1 = MKMarqueeController.rect(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 0, y: 0))
        #expect(r1 == CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    @Test func intersectModeSelectsAnyTouchedNode() {
        let inside = candidate(x: 50, y: 50)
        let straddling = candidate(x: 95, y: 50) // half in, half out of a 0..<100 marquee
        let outside = candidate(x: 500, y: 500)
        let marquee = CGRect(x: 0, y: 0, width: 100, height: 100)
        let selected = MKMarqueeController.select(marquee: marquee, candidates: [inside, straddling, outside], mode: .intersect)
        #expect(selected.contains(inside.nodeID))
        #expect(selected.contains(straddling.nodeID))
        #expect(!selected.contains(outside.nodeID))
    }

    @Test func containModeRequiresFullContainment() {
        let inside = candidate(x: 50, y: 50)
        let straddling = candidate(x: 95, y: 50)
        let marquee = CGRect(x: 0, y: 0, width: 100, height: 100)
        let selected = MKMarqueeController.select(marquee: marquee, candidates: [inside, straddling], mode: .contain)
        #expect(selected.contains(inside.nodeID))
        #expect(!selected.contains(straddling.nodeID))
    }

    @Test func lockedAndHiddenAreExcludedInBothModes() {
        let locked = candidate(x: 50, y: 50, locked: true)
        let hidden = candidate(x: 50, y: 50, hidden: true)
        let marquee = CGRect(x: 0, y: 0, width: 100, height: 100)
        let intersectResult = MKMarqueeController.select(marquee: marquee, candidates: [locked, hidden], mode: .intersect)
        let containResult = MKMarqueeController.select(marquee: marquee, candidates: [locked, hidden], mode: .contain)
        #expect(intersectResult.isEmpty)
        #expect(containResult.isEmpty)
    }

    @Test func emptyMarqueeSelectsNothing() {
        let node = candidate(x: 500, y: 500)
        let selected = MKMarqueeController.select(marquee: CGRect(x: 0, y: 0, width: 10, height: 10), candidates: [node], mode: .intersect)
        #expect(selected.isEmpty)
    }
}
