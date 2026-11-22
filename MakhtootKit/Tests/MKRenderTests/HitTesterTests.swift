import Testing
import CoreGraphics
import MKFoundation
import MKModel
@testable import MKRender

/// WS-07 packet §5 task 12 accept: "unit tests on rotated/scaled nodes;
/// glyph-level hits on the 'لا' arranged fixture."
@Suite struct HitTesterTests {
    private let tester = HitTester()

    @Test func hitsTopmostNodeWhenOverlapping() {
        let bottom = TestScenes.redRect(position: CGPoint(x: 100, y: 100), size: CGSize(width: 80, height: 80))
        let top = TestScenes.blueEllipse(position: CGPoint(x: 100, y: 100), size: CGSize(width: 80, height: 80))
        let scene = TestScenes.scene(nodes: [bottom, top])

        let hit = tester.node(at: CGPoint(x: 100, y: 100), in: scene)
        #expect(hit?.nodeID == top.id)
    }

    @Test func missesOutsideAnyNodeBounds() {
        let scene = TestScenes.scene(nodes: [TestScenes.redRect(position: CGPoint(x: 100, y: 100), size: CGSize(width: 20, height: 20))])
        let hit = tester.node(at: CGPoint(x: 300, y: 300), in: scene)
        #expect(hit == nil)
    }

    @Test func hiddenNodesAreNeverHit() {
        var rectNode = TestScenes.redRect(position: CGPoint(x: 100, y: 100), size: CGSize(width: 80, height: 80))
        var core = rectNode.core
        core.isHidden = true
        rectNode = rectNode.withCore(core)
        let scene = TestScenes.scene(nodes: [rectNode])

        let hit = tester.node(at: CGPoint(x: 100, y: 100), in: scene)
        #expect(hit == nil)
    }

    /// A 45°-rotated square: the CENTER always hits regardless of rotation,
    /// but a point near an AXIS-ALIGNED corner of the unrotated bounding
    /// box should MISS once the square is rotated 45° (that corner is now
    /// outside the diamond).
    @Test func rotatedNodeHitTestIsTransformAware() {
        let size = CGSize(width: 40, height: 40)
        let center = CGPoint(x: 100, y: 100)
        var rect = TestScenes.redRect(position: center, size: size)
        var core = rect.core
        core.transform.rotation = .pi / 4
        rect = rect.withCore(core)
        let scene = TestScenes.scene(nodes: [rect])

        #expect(tester.node(at: center, in: scene)?.nodeID == rect.id)

        // (100 + 19, 100 + 19) is just inside the UNROTATED 40×40 square's
        // corner but well outside the 45°-rotated diamond.
        let cornerPoint = CGPoint(x: center.x + 19, y: center.y + 19)
        #expect(tester.node(at: cornerPoint, in: scene) == nil)
    }

    @Test func scaledNodeHitTestUsesActualSize() {
        let center = CGPoint(x: 100, y: 100)
        let smallRect = TestScenes.redRect(position: center, size: CGSize(width: 10, height: 10))
        let scene = TestScenes.scene(nodes: [smallRect])

        // Inside the (small) 10×10 box.
        #expect(tester.node(at: CGPoint(x: 100, y: 100), in: scene)?.nodeID == smallRect.id)
        // Just outside it, but would be INSIDE a naive "always 40×40" test.
        #expect(tester.node(at: CGPoint(x: 100, y: 115), in: scene) == nil)
    }

    @Test func groupHitTestRecursesIntoChildrenWithComposedTransform() {
        let child = TestScenes.redRect(position: CGPoint(x: 10, y: 10), size: CGSize(width: 20, height: 20))
        let groupCore = MKNodeCore(name: "group", transform: MKTransform2D(position: CGPoint(x: 90, y: 90)))
        let group = MKNode.group(MKGroupNode(core: groupCore, children: [child]))
        let scene = TestScenes.scene(nodes: [group])

        // Child's world position = group position (90,90) + child local
        // position (10,10) = (100,100).
        let hit = tester.node(at: CGPoint(x: 100, y: 100), in: scene)
        #expect(hit?.nodeID == child.id)
    }

    // MARK: - Arranged children ("لا" glyph-level hit)

    @Test func arrangedChildHitTestFindsBaseGlyphAtItsWorldPosition() {
        let (node, baseID, _) = TestScenes.arrangedBaseAndMark(baseTransform: .identity, markRelativeOffset: CGSize(width: 0, height: 60))
        // The base glyph's outline is a 1000-unit square (±500) at
        // `pointSize` 96 → half-width = 500/1000×96 = 48 pt, centered at
        // the base's world origin (0,0) since layout.position is `.zero`
        // and baseTransform is identity ، flipped Y doesn't change a
        // symmetric square's containment.
        let hit = tester.arrangedChild(at: CGPoint(x: 0, y: 0), in: node, compositionWorldTransform: .identity)
        #expect(hit?.childID == baseID)
    }

    @Test func arrangedChildHitTestFindsAttachedMarkAtItsOwnOffsetPosition() {
        let (node, _, markID) = TestScenes.arrangedBaseAndMark(baseTransform: .identity, markRelativeOffset: CGSize(width: 0, height: 150))
        // The flip (`scaleY: -1`) applied at the composition boundary
        // (`ArrangedDrawer`'s documented convention) means a positive
        // `relativeOffset.height` lands at NEGATIVE document-space y.
        let hit = tester.arrangedChild(at: CGPoint(x: 0, y: -150), in: node, compositionWorldTransform: .identity)
        #expect(hit?.childID == markID)
    }

    @Test func arrangedChildMissOutsideCompositionReturnsNil() {
        let (node, _, _) = TestScenes.arrangedBaseAndMark()
        let hit = tester.arrangedChild(at: CGPoint(x: 5000, y: 5000), in: node, compositionWorldTransform: .identity)
        #expect(hit == nil)
    }

    // MARK: - allHits / worldGeometry (CONTRACTS.md WS-07 gaps #1/#2, flagged by WS-06)

    @Test func allHitsReturnsEveryOverlappingNodeTopmostFirst() {
        let bottom = TestScenes.redRect(position: CGPoint(x: 100, y: 100), size: CGSize(width: 80, height: 80))
        let middle = TestScenes.blueEllipse(position: CGPoint(x: 100, y: 100), size: CGSize(width: 60, height: 60))
        let top = TestScenes.redRect(position: CGPoint(x: 100, y: 100), size: CGSize(width: 40, height: 40))
        let scene = TestScenes.scene(nodes: [bottom, middle, top])

        let hits = tester.allHits(at: CGPoint(x: 100, y: 100), in: scene)
        #expect(hits.map(\.nodeID) == [top.id, middle.id, bottom.id])
    }

    @Test func allHitsExcludesHiddenButNotLocked() {
        var hiddenNode = TestScenes.redRect(position: CGPoint(x: 100, y: 100), size: CGSize(width: 40, height: 40))
        var hiddenCore = hiddenNode.core
        hiddenCore.isHidden = true
        hiddenNode = hiddenNode.withCore(hiddenCore)

        var lockedNode = TestScenes.blueEllipse(position: CGPoint(x: 100, y: 100), size: CGSize(width: 40, height: 40))
        var lockedCore = lockedNode.core
        lockedCore.isLocked = true
        lockedNode = lockedNode.withCore(lockedCore)

        let scene = TestScenes.scene(nodes: [hiddenNode, lockedNode])
        let hits = tester.allHits(at: CGPoint(x: 100, y: 100), in: scene)
        #expect(hits.map(\.nodeID) == [lockedNode.id])
    }

    @Test func worldGeometryComposesAncestorTransformsForNestedNodes() {
        let child = TestScenes.redRect(position: CGPoint(x: 10, y: 5), size: CGSize(width: 20, height: 20))
        let groupCore = MKNodeCore(name: "group", transform: MKTransform2D(position: CGPoint(x: 90, y: 90)))
        let group = MKNode.group(MKGroupNode(core: groupCore, children: [child]))
        let scene = TestScenes.scene(nodes: [group])

        guard let geometry = tester.worldGeometry(of: child.id, in: scene) else {
            Issue.record("expected world geometry for nested child")
            return
        }
        let worldOrigin = CGPoint.zero.applying(geometry.worldTransform)
        #expect(abs(worldOrigin.x - 100) < 0.01)   // group (90) + child local (10)
        #expect(abs(worldOrigin.y - 95) < 0.01)    // group (90) + child local (5)
    }

    @Test func worldGeometryReturnsNilForUnknownID() {
        let scene = TestScenes.scene(nodes: [TestScenes.redRect()])
        #expect(tester.worldGeometry(of: MKNodeID(), in: scene) == nil)
    }

    @Test func containsPreciseDistinguishesInsideVsOutsideActualGeometry() {
        // An ellipse's OBB (its bounding square) has corners that are NOT
        // inside the ellipse itself ، the classic case a precise test must
        // get right where a bbox-only test would not.
        let ellipse = TestScenes.blueEllipse(position: CGPoint(x: 100, y: 100), size: CGSize(width: 40, height: 40))
        let scene = TestScenes.scene(nodes: [ellipse])

        #expect(tester.containsPrecise(nodeID: ellipse.id, worldPoint: CGPoint(x: 100, y: 100), in: scene))
        // Corner of the 40×40 bounding square (100±20, 100±20) ، outside
        // the inscribed ellipse.
        #expect(!tester.containsPrecise(nodeID: ellipse.id, worldPoint: CGPoint(x: 119, y: 119), in: scene))
    }

    @Test func containsPreciseComposesAncestorTransformsForNestedNodes() {
        let child = TestScenes.redRect(position: CGPoint(x: 10, y: 5), size: CGSize(width: 20, height: 20))
        let groupCore = MKNodeCore(name: "group", transform: MKTransform2D(position: CGPoint(x: 90, y: 90)))
        let group = MKNode.group(MKGroupNode(core: groupCore, children: [child]))
        let scene = TestScenes.scene(nodes: [group])

        #expect(tester.containsPrecise(nodeID: child.id, worldPoint: CGPoint(x: 100, y: 95), in: scene))
        #expect(!tester.containsPrecise(nodeID: child.id, worldPoint: CGPoint(x: 500, y: 500), in: scene))
    }

    @Test func containsPreciseReturnsFalseForUnknownID() {
        let scene = TestScenes.scene(nodes: [TestScenes.redRect()])
        #expect(!tester.containsPrecise(nodeID: MKNodeID(), worldPoint: .zero, in: scene))
    }

    // MARK: - Path proximity

    @Test func pathProximityFindsNearestPointWithinTolerance() {
        var path = MKBezierPathData()
        path.segments = [MKBezierSegment(start: CGPoint(x: 0, y: 0), c1: CGPoint(x: 0, y: 0), c2: CGPoint(x: 100, y: 0), end: CGPoint(x: 100, y: 0))]
        let result = tester.pathProximity(to: CGPoint(x: 50, y: 3), on: path, tolerance: 8)
        #expect(result != nil)
        if let result {
            #expect(abs(result.length - 50) < 1)
            #expect(abs(result.distance - 3) < 0.5)
        }
    }

    @Test func pathProximityReturnsNilBeyondTolerance() {
        var path = MKBezierPathData()
        path.segments = [MKBezierSegment(start: CGPoint(x: 0, y: 0), c1: CGPoint(x: 0, y: 0), c2: CGPoint(x: 100, y: 0), end: CGPoint(x: 100, y: 0))]
        let result = tester.pathProximity(to: CGPoint(x: 50, y: 50), on: path, tolerance: 8)
        #expect(result == nil)
    }
}
