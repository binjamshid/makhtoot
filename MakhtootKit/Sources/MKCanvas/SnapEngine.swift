import CoreGraphics
import MKFoundation

// WS-06 packet §5 task 9 / ARCHITECTURE §10.5: "candidate snap lines each
// pan frame from: canvas edges/center, other nodes' edges/centers (visible,
// unlocked, within viewport, max 200 candidates by proximity), and
// equal-spacing triples. Snap threshold 6 view-pt (zoom-normalized);
// hysteresis 2 pt to prevent flicker." Pure math over plain `[CGFloat]`
// candidate axes ، no scene/geometry-source dependency, so this is
// directly unit-testable per the packet's own gate ("unit tests on snap
// math (edge/center/spacing)") without needing WS-07's real geometry.

public enum MKSnapAxis: Sendable, Equatable {
    case horizontal // a vertical guide line, snapping X positions
    case vertical   // a horizontal guide line, snapping Y positions
}

/// One candidate snap line plus where it came from ، the chrome layer
/// (`GuideRenderer`) uses `source` to pick a visual style if it ever wants
/// to (v1 renders all guides identically, per task 9's "accent color,
/// hairline").
public struct MKSnapCandidate: Sendable, Hashable {
    public enum Source: Sendable, Hashable {
        case canvasEdge
        case canvasCenter
        case nodeEdge(MKNodeID)
        case nodeCenter(MKNodeID)
        case equalSpacing
    }

    public var axis: MKSnapAxis
    public var position: CGFloat
    public var source: Source

    public init(axis: MKSnapAxis, position: CGFloat, source: Source) {
        self.axis = axis
        self.position = position
        self.source = source
    }
}

/// A guide the chrome layer should draw plus (for `.horizontal`, i.e. a
/// vertical line) the y-extent to draw it over, or (for `.vertical`) the
/// x-extent ، kept as a simple line segment so `GuideRenderer` doesn't need
/// scene access either.
public struct MKSnapGuide: Sendable, Hashable {
    public var axis: MKSnapAxis
    public var position: CGFloat
    public var extentStart: CGFloat
    public var extentEnd: CGFloat

    public init(axis: MKSnapAxis, position: CGFloat, extentStart: CGFloat, extentEnd: CGFloat) {
        self.axis = axis
        self.position = position
        self.extentStart = extentStart
        self.extentEnd = extentEnd
    }
}

public struct MKSnapResult: Sendable, Equatable {
    /// The delta to ADD to the drag's raw delta so the dragged edge/center
    /// lands exactly on a snap candidate. Zero components mean "no snap on
    /// that axis."
    public var adjustment: CGVector
    public var guides: [MKSnapGuide]

    public init(adjustment: CGVector = .zero, guides: [MKSnapGuide] = []) {
        self.adjustment = adjustment
        self.guides = guides
    }

    public static let none = MKSnapResult()
}

public enum MKSnapEngine {
    /// Base snap radius in VIEW points (task 9: "6 pt screen-space
    /// (zoom-adjusted)").
    public static let baseRadiusPoints: CGFloat = 6
    /// Hysteresis band (task 9 §10.5) ، once engaged, a snap stays engaged
    /// until the pointer moves this many extra canvas points past the
    /// radius, preventing flicker right at the boundary.
    public static let hysteresisPoints: CGFloat = 2

    public static func radius(zoomScale: CGFloat) -> CGFloat {
        guard zoomScale > 0 else { return baseRadiusPoints }
        return baseRadiusPoints / zoomScale
    }

    /// Canvas edge/center candidates for a canvas of `canvasSize` (task 9:
    /// "canvas edges/center").
    public static func canvasCandidates(canvasSize: CGSize) -> [MKSnapCandidate] {
        [
            MKSnapCandidate(axis: .horizontal, position: 0, source: .canvasEdge),
            MKSnapCandidate(axis: .horizontal, position: canvasSize.width / 2, source: .canvasCenter),
            MKSnapCandidate(axis: .horizontal, position: canvasSize.width, source: .canvasEdge),
            MKSnapCandidate(axis: .vertical, position: 0, source: .canvasEdge),
            MKSnapCandidate(axis: .vertical, position: canvasSize.height / 2, source: .canvasCenter),
            MKSnapCandidate(axis: .vertical, position: canvasSize.height, source: .canvasEdge),
        ]
    }

    /// Edge/center candidates for one other node's world OBB (task 9:
    /// "other nodes' edges/centers"). Rotated OBBs snap against their
    /// axis-aligned bounds, matching how `MarqueeController`/hit-testing
    /// treat rotated shapes for canvas-level chrome purposes.
    public static func nodeCandidates(nodeID: MKNodeID, obb: MKOrientedRect) -> [MKSnapCandidate] {
        let bounds = obb.axisAlignedBounds
        return [
            MKSnapCandidate(axis: .horizontal, position: bounds.minX, source: .nodeEdge(nodeID)),
            MKSnapCandidate(axis: .horizontal, position: bounds.midX, source: .nodeCenter(nodeID)),
            MKSnapCandidate(axis: .horizontal, position: bounds.maxX, source: .nodeEdge(nodeID)),
            MKSnapCandidate(axis: .vertical, position: bounds.minY, source: .nodeEdge(nodeID)),
            MKSnapCandidate(axis: .vertical, position: bounds.midY, source: .nodeCenter(nodeID)),
            MKSnapCandidate(axis: .vertical, position: bounds.maxY, source: .nodeEdge(nodeID)),
        ]
    }

    /// Detects an equal-spacing opportunity: three axis-sorted node
    /// intervals (by their bounds along `axis`) where the gap the dragged
    /// node WOULD create matches an existing neighbor gap within
    /// `tolerance`. Returns candidate positions (for the dragged edge) that
    /// would equalize the spacing (task 9: "equal-spacing between neighbor
    /// pairs").
    public static func equalSpacingCandidates(
        axis: MKSnapAxis,
        neighborIntervals: [ClosedRange<CGFloat>],
        draggedSize: CGFloat
    ) -> [MKSnapCandidate] {
        guard neighborIntervals.count >= 2 else { return [] }
        let sorted = neighborIntervals.sorted { $0.lowerBound < $1.lowerBound }
        var results: [MKSnapCandidate] = []
        for i in 0..<(sorted.count - 1) {
            let left = sorted[i]
            let right = sorted[i + 1]
            let gap = right.lowerBound - left.upperBound
            guard gap > 0 else { continue }
            // Position the dragged node's leading edge so it creates the
            // SAME gap after `left` ، i.e. slot it into the middle of a
            // (left, right) pair reproducing the observed spacing.
            let candidatePosition = left.upperBound + gap
            results.append(MKSnapCandidate(axis: axis, position: candidatePosition, source: .equalSpacing))
            results.append(MKSnapCandidate(axis: axis, position: candidatePosition + draggedSize + gap, source: .equalSpacing))
        }
        return results
    }

    /// Finds the nearest candidate on `axis` to `value` within `radius`,
    /// or `nil`.
    public static func nearest(to value: CGFloat, in candidates: [MKSnapCandidate], axis: MKSnapAxis, radius: CGFloat) -> MKSnapCandidate? {
        candidates
            .filter { $0.axis == axis }
            .map { ($0, abs($0.position - value)) }
            .filter { $0.1 <= radius }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// Snaps a dragged OBB's key positions (edges + center on each axis)
    /// against `candidates`, returning the smallest adjustment that snaps
    /// ANY of those key positions, plus guide descriptors for whichever
    /// candidate(s) matched. `viewportExtent` bounds how far guide lines
    /// are drawn (task 9: chrome-layer rendering).
    public static func snap(
        draggedBounds: CGRect,
        candidates: [MKSnapCandidate],
        zoomScale: CGFloat,
        viewportExtent: CGRect
    ) -> MKSnapResult {
        let radius = radius(zoomScale: zoomScale)
        let xKeyPositions: [CGFloat] = [draggedBounds.minX, draggedBounds.midX, draggedBounds.maxX]
        let yKeyPositions: [CGFloat] = [draggedBounds.minY, draggedBounds.midY, draggedBounds.maxY]

        var bestX: (delta: CGFloat, candidate: MKSnapCandidate)?
        for key in xKeyPositions {
            if let match = nearest(to: key, in: candidates, axis: .horizontal, radius: radius) {
                let delta = match.position - key
                if bestX == nil || abs(delta) < abs(bestX!.delta) { bestX = (delta, match) }
            }
        }
        var bestY: (delta: CGFloat, candidate: MKSnapCandidate)?
        for key in yKeyPositions {
            if let match = nearest(to: key, in: candidates, axis: .vertical, radius: radius) {
                let delta = match.position - key
                if bestY == nil || abs(delta) < abs(bestY!.delta) { bestY = (delta, match) }
            }
        }

        var guides: [MKSnapGuide] = []
        if let bestX {
            guides.append(MKSnapGuide(axis: .horizontal, position: bestX.candidate.position, extentStart: viewportExtent.minY, extentEnd: viewportExtent.maxY))
        }
        if let bestY {
            guides.append(MKSnapGuide(axis: .vertical, position: bestY.candidate.position, extentStart: viewportExtent.minX, extentEnd: viewportExtent.maxX))
        }

        return MKSnapResult(adjustment: CGVector(dx: bestX?.delta ?? 0, dy: bestY?.delta ?? 0), guides: guides)
    }

    /// Rotation angle snap re-export ، rotation snapping is angle math
    /// shared with the handle-resize gesture, so it lives on
    /// `MKAnchoredResize.snappedAngle` rather than being duplicated here
    /// (task 9: "angle snapping for rotation").
    public static func snappedRotation(_ angle: CGFloat) -> CGFloat {
        MKAnchoredResize.snappedAngle(angle)
    }
}
