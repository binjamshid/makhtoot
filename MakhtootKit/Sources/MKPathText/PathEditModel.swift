import CoreGraphics
import MKFoundation
import MKModel

// WS-05 packet §5 task 10. Pure geometry operations over `BezierPathModel`
// for WS-06 (`MKCanvas`) to drive from gesture recognizers ، this file
// contains ZERO gesture/UIKit/hit-testing-UI code (out of scope per the
// packet's mission statement: "the mission includes model + engine +
// editing semantics, not UI"), only the pure functions WS-06 calls. Every
// operation keeps the path structurally valid (task 10's accept
// criterion) or returns `nil`/leaves the path unchanged rather than
// producing an invalid one.

/// One hit-testable control point on a live path: an anchor's own point,
/// or one of its handles.
public struct PathHandleID: Hashable, Sendable {
    public enum Kind: Hashable, Sendable { case anchor, handleIn, handleOut }
    public var anchorID: MKPathAnchorID
    public var kind: Kind

    public init(anchorID: MKPathAnchorID, kind: Kind) {
        self.anchorID = anchorID
        self.kind = kind
    }
}

/// A hit target WS-06 can present as a draggable handle.
public struct PathHitTarget: Hashable, Sendable {
    public var id: PathHandleID
    public var position: CGPoint

    public init(id: PathHandleID, position: CGPoint) {
        self.id = id
        self.position = position
    }
}

/// How dragging one handle affects its opposite sibling on the same anchor
/// (task 10: "move handle (with mirrored/free handle mode)").
public enum PathHandleMode: Sendable {
    /// The opposite handle mirrors this one exactly (`point`'s reflection
    /// through the anchor) ، smooth (C1-continuous) curves.
    case mirrored
    /// The opposite handle is left untouched ، corner points / cusps.
    case free
}

public enum PathEditModel {
    // MARK: - Hit-testing (task 10)

    /// Every anchor point plus its present handles, as hit targets.
    public static func hitTargets(in path: BezierPathModel) -> [PathHitTarget] {
        var targets: [PathHitTarget] = []
        for anchor in path.anchors {
            targets.append(PathHitTarget(id: PathHandleID(anchorID: anchor.id, kind: .anchor), position: anchor.point))
            if let handleIn = anchor.handleIn {
                targets.append(PathHitTarget(id: PathHandleID(anchorID: anchor.id, kind: .handleIn), position: handleIn))
            }
            if let handleOut = anchor.handleOut {
                targets.append(PathHitTarget(id: PathHandleID(anchorID: anchor.id, kind: .handleOut), position: handleOut))
            }
        }
        return targets
    }

    public static func nearestHitTarget(to point: CGPoint, in path: BezierPathModel, tolerance: CGFloat = .greatestFiniteMagnitude) -> PathHitTarget? {
        var best: PathHitTarget?
        var bestDistance = tolerance
        for target in hitTargets(in: path) {
            let d = hypot(target.position.x - point.x, target.position.y - point.y)
            if d <= bestDistance {
                bestDistance = d
                best = target
            }
        }
        return best
    }

    // MARK: - Anchor/handle mutation (task 10)

    /// Moves an anchor's own point by translating it AND its handles by
    /// the same delta (the natural "drag the whole control point" UX) when
    /// `moveHandles == true`; when `false`, only the anchor point moves
    /// (handles keep their absolute position, reshaping the curve around
    /// the anchor).
    public static func moveAnchor(_ id: MKPathAnchorID, to newPoint: CGPoint, in path: BezierPathModel, moveHandles: Bool = true) -> BezierPathModel {
        var copy = path
        guard let index = copy.anchors.firstIndex(where: { $0.id == id }) else { return path }
        let old = copy.anchors[index]
        let delta = CGPoint(x: newPoint.x - old.point.x, y: newPoint.y - old.point.y)
        var updated = old
        updated.point = newPoint
        if moveHandles {
            if let h = old.handleIn { updated.handleIn = CGPoint(x: h.x + delta.x, y: h.y + delta.y) }
            if let h = old.handleOut { updated.handleOut = CGPoint(x: h.x + delta.x, y: h.y + delta.y) }
        }
        copy.anchors[index] = updated
        return copy
    }

    /// Moves one handle to an absolute new position, applying `mode` to
    /// its opposite sibling on the same anchor.
    public static func moveHandle(_ handleID: PathHandleID, to newPoint: CGPoint, in path: BezierPathModel, mode: PathHandleMode) -> BezierPathModel {
        var copy = path
        guard let index = copy.anchors.firstIndex(where: { $0.id == handleID.anchorID }) else { return path }
        var anchor = copy.anchors[index]
        switch handleID.kind {
        case .anchor:
            return moveAnchor(handleID.anchorID, to: newPoint, in: path)
        case .handleOut:
            anchor.handleOut = newPoint
            if mode == .mirrored {
                let delta = CGPoint(x: newPoint.x - anchor.point.x, y: newPoint.y - anchor.point.y)
                anchor.handleIn = CGPoint(x: anchor.point.x - delta.x, y: anchor.point.y - delta.y)
            }
        case .handleIn:
            anchor.handleIn = newPoint
            if mode == .mirrored {
                let delta = CGPoint(x: newPoint.x - anchor.point.x, y: newPoint.y - anchor.point.y)
                anchor.handleOut = CGPoint(x: anchor.point.x - delta.x, y: anchor.point.y - delta.y)
            }
        }
        copy.anchors[index] = anchor
        return copy
    }

    /// Splits the segment nearest `length` at its EXACT parameter via de
    /// Casteljau subdivision ، this is a lossless split (the two resulting
    /// segments trace precisely the same curve as the original one),
    /// which is what makes the task's "insert-at-point lands within 1 pt
    /// of the tapped location" accept criterion hold with effectively zero
    /// error, not just "within tolerance."
    public static func insertAnchor(atLength length: CGFloat, in path: BezierPathModel, lut: ArcLengthLUT) -> BezierPathModel {
        guard path.anchors.count >= 2 else { return path }
        let (segIndex, localT) = lut.segmentAndLocalT(atLength: length)
        let count = path.anchors.count
        guard segIndex >= 0, segIndex < (path.isClosed ? count : count - 1) else { return path }

        let startIndex = segIndex
        let endIndex = (segIndex + 1) % count
        let a = path.anchors[startIndex]
        let b = path.anchors[endIndex]
        let seg = MKBezierSegment(start: a.point, c1: a.handleOut ?? a.point, c2: b.handleIn ?? b.point, end: b.point)
        let (left, right) = Self.splitCubic(seg, at: localT)

        var newA = a
        newA.handleOut = (left.c1 == left.start) ? nil : left.c1
        var newB = b
        newB.handleIn = (right.c2 == right.end) ? nil : right.c2
        let midAnchor = PathAnchor(
            point: left.end,
            handleIn: (left.c2 == left.end) ? nil : left.c2,
            handleOut: (right.c1 == right.start) ? nil : right.c1)

        var copy = path
        copy.anchors[startIndex] = newA
        if path.isClosed, endIndex == 0 {
            // The split segment is the CLOSING segment (last anchor ->
            // first anchor): the new anchor goes at the very end of the
            // array, `b` (the first anchor) is updated in place at index 0.
            copy.anchors[0] = newB
            copy.anchors.append(midAnchor)
        } else {
            copy.anchors[endIndex] = newB
            copy.anchors.insert(midAnchor, at: endIndex)
        }
        return copy
    }

    private static func splitCubic(_ seg: MKBezierSegment, at t: CGFloat) -> (MKBezierSegment, MKBezierSegment) {
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        let p01 = lerp(seg.start, seg.c1, t)
        let p12 = lerp(seg.c1, seg.c2, t)
        let p23 = lerp(seg.c2, seg.end, t)
        let p012 = lerp(p01, p12, t)
        let p123 = lerp(p12, p23, t)
        let p0123 = lerp(p012, p123, t)
        return (
            MKBezierSegment(start: seg.start, c1: p01, c2: p012, end: p0123),
            MKBezierSegment(start: p0123, c1: p123, c2: p23, end: seg.end)
        )
    }

    /// Removes an anchor, keeping the path structurally valid (`nil` if
    /// removal would drop below the minimum ، 2 anchors open, 3 closed).
    public static func deleteAnchor(_ id: MKPathAnchorID, in path: BezierPathModel) -> BezierPathModel? {
        var copy = path
        guard let index = copy.anchors.firstIndex(where: { $0.id == id }) else { return path }
        copy.anchors.remove(at: index)
        guard copy.isValid else { return nil }
        return copy
    }

    /// Flips `isClosed`, keeping the path structurally valid (`nil` if the
    /// result would violate the minimum anchor count ، e.g. closing a
    /// 2-anchor path needs ≥3).
    public static func toggleClosed(in path: BezierPathModel) -> BezierPathModel? {
        var copy = path
        copy.isClosed.toggle()
        guard copy.isValid else { return nil }
        return copy
    }

    public static func isValid(_ path: BezierPathModel) -> Bool { path.isValid }
}
