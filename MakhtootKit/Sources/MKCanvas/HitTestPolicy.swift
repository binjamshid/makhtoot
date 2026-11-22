import CoreGraphics
import Foundation
import MKFoundation
import MKModel

// WS-06 packet §5 task 3: "Hit-test policy: tap → `HitTester.node(at:)`
// respecting z-order (topmost first), `isLocked`/`isHidden` skip, 44 pt
// minimum touch slop for thin strokes; inside an `arranged` node in arrange
// mode, hit at glyph/mark granularity (WS-07 geometry); otherwise arranged
// node is one object." "You own priority/policy, WS-07 owns geometry" ،
// this file is pure ordering/filtering/tap-cycling policy over a candidate
// list a geometry source (real WS-07 render tree, or a test double today)
// produces; it never computes a `CGPath` itself.
//
// NOTE ، locked-node behavior (conflict flagged, then RESOLVED by
// coordinator gate ruling; see docs/impl-log/WS-06.md): locked nodes are
// SKIPPED by canvas tap hit-testing ، taps fall through to the node below
// ، per PRD R-4.6 (P0) and this packet's task-3 accept criterion. A
// locked node remains selectable from the layers panel (with lock badge).
// ARCHITECTURE.md §10.3 step 5 originally said the opposite; that was the
// stale text and has been corrected to match R-4.6.

/// One candidate a geometry source offers up for hit-testing ، the input
/// shape `HitTestPolicy` consumes. In production this is built from
/// `MKCanvasGeometrySource.worldOBB(for:in:)` plus the scene's own
/// `core.isLocked`/`core.isHidden`/z-order; kept as a separate struct
/// (rather than making `HitTestPolicy` take the geometry source directly)
/// so the ordering/filtering logic itself has zero dependency on how
/// candidates were produced and is trivially unit-testable with synthetic
/// data.
public struct MKHitCandidate: Sendable, Hashable {
    public var nodeID: MKNodeID
    public var worldOBB: MKOrientedRect
    /// Paint order ، same convention as `MKScene.nodes`/`MKGroupNode
    /// .children` (index 0 = backmost). Callers building this list from a
    /// scene pass each node's array index (or a stable topological index
    /// for nested groups).
    public var zIndex: Int
    public var isLocked: Bool
    public var isHidden: Bool

    public init(nodeID: MKNodeID, worldOBB: MKOrientedRect, zIndex: Int, isLocked: Bool = false, isHidden: Bool = false) {
        self.nodeID = nodeID
        self.worldOBB = worldOBB
        self.zIndex = zIndex
        self.isLocked = isLocked
        self.isHidden = isHidden
    }
}

/// Which part of the scene a hit-test query is scoped to (ARCHITECTURE
/// §10.3's `MKHitScope`, reproduced here as `MKCanvas`'s own consumption
/// shape since no real `MKRender.MKHitScope` exists yet to import).
public enum MKCanvasHitScope: Sendable, Equatable {
    case topLevel
    case insideGroup(MKNodeID)
    case insideComposition(MKNodeID)
}

public enum MKHitTestPolicy {
    /// 44 pt minimum touch target (task 3), expressed as canvas-space
    /// tolerance once the caller has divided by `zoomScale` ، see
    /// `touchTolerance(zoomScale:)`.
    public static let minimumTouchTargetPoints: CGFloat = 44
    /// Floor tolerance in CANVAS points regardless of zoom (ARCHITECTURE
    /// §10.3: "tolerance in canvas points (view 22 pt / zoomScale, min 2 pt)").
    public static let minimumCanvasTolerance: CGFloat = 2
    /// View-space slop before dividing by zoom (half the 44 pt touch
    /// target, matching ARCHITECTURE §10.3's literal "22 pt / zoomScale").
    public static let viewSlopPoints: CGFloat = 22

    /// Canvas-space hit tolerance for the given zoom scale (view points
    /// shrink to fewer canvas points as you zoom in, more as you zoom out ،
    /// small on-screen targets still need a generous canvas-space
    /// tolerance at high zoom-out).
    public static func touchTolerance(zoomScale: CGFloat) -> CGFloat {
        guard zoomScale > 0 else { return minimumCanvasTolerance }
        return max(minimumCanvasTolerance, viewSlopPoints / zoomScale)
    }

    /// All candidates whose (tolerance-inflated) OBB contains `point`,
    /// topmost first (task 3: "respecting z-order (topmost first)"),
    /// excluding locked/hidden entirely (see the header note above).
    public static func hits(
        at point: CGPoint,
        in candidates: [MKHitCandidate],
        tolerance: CGFloat
    ) -> [MKNodeID] {
        candidates
            .filter { !$0.isLocked && !$0.isHidden }
            .filter { $0.worldOBB.contains(point, tolerance: tolerance) }
            .sorted { $0.zIndex > $1.zIndex }
            .map(\.nodeID)
    }

    /// The single topmost hit, or `nil` (empty-canvas tap → deselect,
    /// ARCHITECTURE §10.2).
    public static func topHit(
        at point: CGPoint,
        in candidates: [MKHitCandidate],
        tolerance: CGFloat
    ) -> MKNodeID? {
        hits(at: point, in: candidates, tolerance: tolerance).first
    }

    /// Tap-cycling state (ARCHITECTURE §10.3: "repeated taps within 1.5 s
    /// at ≤8 pt distance walk the `hits` array so occluded objects are
    /// reachable"). Kept as a small value type `CanvasSession`/the gesture
    /// coordinator owns an instance of, updated on every tap.
    public struct TapCycleState: Sendable, Equatable {
        public var lastPoint: CGPoint?
        public var lastTimestamp: TimeInterval?
        public var lastIndex: Int = -1

        public init() {}

        public static let cycleWindow: TimeInterval = 1.5
        public static let cycleDistance: CGFloat = 8

        /// Returns the id to select for a tap at `point`/`now`, advancing
        /// through `hits` (which must already be topmost-first) on
        /// consecutive same-spot taps within the cycle window, and resets
        /// to the top hit otherwise. Mutates `self` to record the new tap.
        public mutating func select(from hits: [MKNodeID], at point: CGPoint, now: TimeInterval) -> MKNodeID? {
            guard !hits.isEmpty else {
                lastPoint = point
                lastTimestamp = now
                lastIndex = -1
                return nil
            }
            let isRepeat: Bool = {
                guard let lastPoint, let lastTimestamp else { return false }
                let dx = point.x - lastPoint.x
                let dy = point.y - lastPoint.y
                let distance = (dx * dx + dy * dy).squareRoot()
                return (now - lastTimestamp) <= Self.cycleWindow && distance <= Self.cycleDistance
            }()
            let nextIndex = isRepeat ? (lastIndex + 1) % hits.count : 0
            lastPoint = point
            lastTimestamp = now
            lastIndex = nextIndex
            return hits[nextIndex]
        }
    }
}
