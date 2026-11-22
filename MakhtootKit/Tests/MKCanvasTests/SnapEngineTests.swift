import CoreGraphics
import MKFoundation
import Testing
@testable import MKCanvas

@Suite("MKSnapEngine ، packet §7 gate: unit tests on snap math (edge/center/spacing)")
struct MKSnapEngineTests {
    @Test func canvasCandidatesIncludeEdgesAndCenter() {
        let candidates = MKSnapEngine.canvasCandidates(canvasSize: CGSize(width: 200, height: 400))
        let xs = Set(candidates.filter { $0.axis == .horizontal }.map(\.position))
        let ys = Set(candidates.filter { $0.axis == .vertical }.map(\.position))
        #expect(xs == [0, 100, 200])
        #expect(ys == [0, 200, 400])
    }

    @Test func nodeCandidatesUseAxisAlignedBoundsOfTheOBB() {
        let obb = MKOrientedRect(center: CGPoint(x: 50, y: 50), size: CGSize(width: 20, height: 10), rotation: 0)
        let candidates = MKSnapEngine.nodeCandidates(nodeID: MKNodeID(), obb: obb)
        let xs = Set(candidates.filter { $0.axis == .horizontal }.map(\.position))
        #expect(xs == [40, 50, 60])
    }

    @Test func snapEngagesWithinRadiusAndReportsTheAdjustmentDelta() {
        let candidates = [MKSnapCandidate(axis: .horizontal, position: 100, source: .canvasEdge)]
        let draggedBounds = CGRect(x: 97, y: 0, width: 20, height: 20) // left edge at 97, within 6pt radius of 100
        let result = MKSnapEngine.snap(draggedBounds: draggedBounds, candidates: candidates, zoomScale: 1, viewportExtent: CGRect(x: -1000, y: -1000, width: 2000, height: 2000))
        #expect(abs(result.adjustment.dx - 3) < 0.0001)
        #expect(result.guides.count == 1)
    }

    @Test func snapDoesNotEngageOutsideRadius() {
        let candidates = [MKSnapCandidate(axis: .horizontal, position: 100, source: .canvasEdge)]
        let draggedBounds = CGRect(x: 50, y: 0, width: 20, height: 20) // far from 100
        let result = MKSnapEngine.snap(draggedBounds: draggedBounds, candidates: candidates, zoomScale: 1, viewportExtent: .zero)
        #expect(result.adjustment.dx == 0)
        #expect(result.guides.isEmpty)
    }

    @Test func snapRadiusShrinksAsZoomIncreases() {
        let tight = MKSnapEngine.radius(zoomScale: 4)
        let loose = MKSnapEngine.radius(zoomScale: 0.5)
        #expect(tight < loose)
    }

    @Test func equalSpacingCandidatesDetectAMatchingGapBetweenNeighbors() {
        // Two neighbor intervals with a 20pt gap between them; the dragged
        // node (size 10) should get a candidate position reproducing that
        // same 20pt gap on the near side.
        let left = 0.0...50.0
        let right = 70.0...120.0 // gap of 20 between left.upperBound and right.lowerBound
        let candidates = MKSnapEngine.equalSpacingCandidates(axis: .horizontal, neighborIntervals: [CGFloat(left.lowerBound)...CGFloat(left.upperBound), CGFloat(right.lowerBound)...CGFloat(right.upperBound)], draggedSize: 10)
        #expect(candidates.contains { abs($0.position - 70) < 0.0001 })
    }

    @Test func nearestPicksTheClosestCandidateWithinRadius() {
        let candidates = [
            MKSnapCandidate(axis: .horizontal, position: 90, source: .canvasEdge),
            MKSnapCandidate(axis: .horizontal, position: 110, source: .canvasEdge),
        ]
        let nearest = MKSnapEngine.nearest(to: 100, in: candidates, axis: .horizontal, radius: 15)
        #expect(nearest?.position == 90 || nearest?.position == 110)
        // Exactly equidistant (10 vs 10) is a tie ، assert it picked ONE
        // of the two, not that it silently returned neither.
        #expect(nearest != nil)
    }

    @Test func snappedRotationDelegatesToAnchoredResizeAngleSnap() {
        let near45 = 44 * CGFloat.pi / 180
        #expect(abs(MKSnapEngine.snappedRotation(near45) - .pi / 4) < 0.0001)
    }
}
