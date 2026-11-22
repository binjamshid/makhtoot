import CoreGraphics
import MKFoundation
import MKModel

// WS-05 packet §5 task 1. The editable (anchor + in/out handle) view over
// `MKModel.MKBezierPathData`'s flat cubic-segment encoding. `MKModel` owns
// the storage shape (segments of `{start,c1,c2,end}` + `isClosed`, D-110's
// document representation ، see `MKBezierPathData.swift`'s own header for
// why `MKModel`, not this module, owns that type: `MKPathTextNode` needs it
// and `MKModel` cannot depend on `MKPathText`). This module owns the
// EDITABLE anchor/handle representation `PathEditModel` hit-tests and
// mutates, plus a handful of geometry presets ، both layered strictly on
// top of `MKBezierPathData`, never replacing it.
//
// Anchor/segment correspondence:
// - **Open path**, `n` anchors ⇒ `n - 1` segments: `segments[i]` connects
//   `anchors[i]` → `anchors[i+1]`, using `anchors[i].handleOut` (falling
//   back to `anchors[i].point` when `nil`, degenerating the cubic formula
//   to a straight line exactly) as `c1` and `anchors[i+1].handleIn`
//   (falling back to `anchors[i+1].point`) as `c2`.
// - **Closed path**, `n` anchors ⇒ `n` segments: same rule, with an extra
//   closing segment `anchors[n-1]` → `anchors[0]`.
//
// This mapping round-trips losslessly in both directions (verified by
// `BezierPathModelTests.anchorSegmentRoundTrip*`): converting segments →
// anchors → segments reproduces the exact same `MKBezierSegment` array.
public struct PathAnchorTag: Sendable {}
public typealias MKPathAnchorID = MKID<PathAnchorTag>

/// One editable control point: its own position plus optional incoming/
/// outgoing Bézier handles (`nil` = a straight join on that side ، the
/// cubic formula's `c1 == start`/`c2 == end` degeneration).
public struct PathAnchor: Hashable, Sendable {
    public var id: MKPathAnchorID
    public var point: CGPoint
    public var handleIn: CGPoint?
    public var handleOut: CGPoint?

    public init(id: MKPathAnchorID = MKPathAnchorID(), point: CGPoint, handleIn: CGPoint? = nil, handleOut: CGPoint? = nil) {
        self.id = id
        self.point = point
        self.handleIn = handleIn
        self.handleOut = handleOut
    }
}

/// The editable Bézier path model (task 1): ordered anchors, open/closed,
/// bridging to/from `MKModel.MKBezierPathData` for persistence and to
/// `CGPath` for hit-testing/rendering.
public struct BezierPathModel: Hashable, Sendable {
    public var anchors: [PathAnchor]
    public var isClosed: Bool

    public init(anchors: [PathAnchor], isClosed: Bool = false) {
        self.anchors = anchors
        self.isClosed = isClosed
    }

    // MARK: - MKBezierPathData interop

    /// Builds the editable model from the document representation.
    public init(_ data: MKBezierPathData) {
        self.isClosed = data.isClosed
        let segments = data.segments
        guard !segments.isEmpty else {
            self.anchors = []
            return
        }
        if data.isClosed {
            var built: [PathAnchor] = []
            built.reserveCapacity(segments.count)
            for (i, seg) in segments.enumerated() {
                let prev = segments[(i - 1 + segments.count) % segments.count]
                let handleIn: CGPoint? = (prev.c2 == prev.end) ? nil : prev.c2
                let handleOut: CGPoint? = (seg.c1 == seg.start) ? nil : seg.c1
                built.append(PathAnchor(point: seg.start, handleIn: handleIn, handleOut: handleOut))
            }
            self.anchors = built
        } else {
            var built: [PathAnchor] = []
            built.reserveCapacity(segments.count + 1)
            let first = segments[0]
            built.append(PathAnchor(point: first.start, handleIn: nil, handleOut: (first.c1 == first.start) ? nil : first.c1))
            for i in 1..<segments.count {
                let prev = segments[i - 1]
                let seg = segments[i]
                let handleIn: CGPoint? = (prev.c2 == prev.end) ? nil : prev.c2
                let handleOut: CGPoint? = (seg.c1 == seg.start) ? nil : seg.c1
                built.append(PathAnchor(point: seg.start, handleIn: handleIn, handleOut: handleOut))
            }
            let last = segments[segments.count - 1]
            built.append(PathAnchor(point: last.end, handleIn: (last.c2 == last.end) ? nil : last.c2, handleOut: nil))
            self.anchors = built
        }
    }

    /// Flattens back to the document representation (Codable via
    /// `MKBezierPathData`, task 1's accept criterion).
    public func bezierPathData() -> MKBezierPathData {
        guard anchors.count >= 2 else {
            // A single anchor (or none) has no segment to emit ، callers
            // should treat this as an invalid/degenerate path (`isValid`
            // below returns `false`); still fails safe rather than
            // crashing (§9.6-style degenerate-geometry discipline).
            return MKBezierPathData(segments: [], isClosed: isClosed)
        }
        var segments: [MKBezierSegment] = []
        let count = anchors.count
        let pairCount = isClosed ? count : count - 1
        segments.reserveCapacity(pairCount)
        for i in 0..<pairCount {
            let a = anchors[i]
            let b = anchors[(i + 1) % count]
            segments.append(MKBezierSegment(
                start: a.point,
                c1: a.handleOut ?? a.point,
                c2: b.handleIn ?? b.point,
                end: b.point))
        }
        return MKBezierPathData(segments: segments, isClosed: isClosed)
    }

    public func cgPath() -> CGPath { bezierPathData().cgPath() }

    /// ≥2 anchors open / ≥3 closed (task 10's structural-validity
    /// invariant ، `PathEditModel`'s delete/toggle-closed operations must
    /// never produce an invalid path).
    public var isValid: Bool {
        isClosed ? anchors.count >= 3 : anchors.count >= 2
    }

    // MARK: - Presets (task 1)

    /// A single straight segment.
    public static func line(from start: CGPoint, to end: CGPoint) -> BezierPathModel {
        BezierPathModel(anchors: [PathAnchor(point: start), PathAnchor(point: end)], isClosed: false)
    }

    /// An open circular arc from `startAngle` to `endAngle` (radians,
    /// standard CoreGraphics convention: 0 = +x axis, increasing
    /// counter-clockwise in a y-up frame / clockwise in a y-down screen
    /// frame ، this constructor is axis-convention-agnostic, it just
    /// evaluates `center + radius * (cos, sin)`). Subdivided into
    /// ≤90°-per-segment cubic chunks using the standard kappa
    /// (`4/3 · tan(Δ/4)`) circular-arc Bézier approximation, which is
    /// accurate to a small fraction of a point for spans this size ، see
    /// `ArcLengthLUTTests.circleAnalyticAccuracy` for the T-PTH-1 numeric
    /// gate this feeds.
    public static func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat) -> BezierPathModel {
        let totalSweep = endAngle - startAngle
        guard radius > 0, abs(totalSweep) > 1e-9 else {
            return BezierPathModel(anchors: [PathAnchor(point: center), PathAnchor(point: center)], isClosed: false)
        }
        // 45° per cubic chunk (not 90°): the kappa approximation's radial
        // error is ~2.7e-4·r for a 90° span ، 0.27 pt at r = 1000, OVER
        // T-PTH-1's <0.1 pt @1000 pt budget (caught by
        // `ArcLengthLUTTests.unitCircleAt1000ptScale` on the first run).
        // At 45° the error drops ~64x (≈4e-6·r → 0.004 pt at r = 1000).
        let maxChunk: CGFloat = .pi / 4
        let chunkCount = max(1, Int(ceil(abs(totalSweep) / maxChunk)))
        let chunk = totalSweep / CGFloat(chunkCount)
        func pointOn(_ angle: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        func tangentOn(_ angle: CGFloat) -> CGVector {
            CGVector(dx: -sin(angle), dy: cos(angle))
        }
        let kappa = (4.0 / 3.0) * tan(chunk / 4)
        let handleLen = radius * kappa
        var segments: [MKBezierSegment] = []
        segments.reserveCapacity(chunkCount)
        for i in 0..<chunkCount {
            let a0 = startAngle + CGFloat(i) * chunk
            let a1 = a0 + chunk
            let p0 = pointOn(a0)
            let p1 = pointOn(a1)
            let t0 = tangentOn(a0)
            let t1 = tangentOn(a1)
            let c1 = CGPoint(x: p0.x + t0.dx * handleLen, y: p0.y + t0.dy * handleLen)
            let c2 = CGPoint(x: p1.x - t1.dx * handleLen, y: p1.y - t1.dy * handleLen)
            segments.append(MKBezierSegment(start: p0, c1: c1, c2: c2, end: p1))
        }
        return BezierPathModel(MKBezierPathData(segments: segments, isClosed: false))
    }

    /// A full circle (closed arc, 0...2π) ، length ≈ 2πr within 0.1% (task
    /// 1 accept criterion), verified by `ArcLengthLUTTests`.
    public static func circle(center: CGPoint, radius: CGFloat) -> BezierPathModel {
        var model = arc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi)
        model.isClosed = true
        // Closing the loop: the arc constructor's last anchor duplicates
        // the first (both at angle 0/2π) ، merge them into one closed
        // anchor so `bezierPathData()` doesn't emit a zero-length closing
        // segment on top of a real one.
        if model.anchors.count > 1 {
            let first = model.anchors[0]
            let last = model.anchors[model.anchors.count - 1]
            model.anchors[0] = PathAnchor(id: first.id, point: first.point, handleIn: last.handleIn, handleOut: first.handleOut)
            model.anchors.removeLast()
        }
        return model
    }

    /// A decorative sine-like wave across `rect`'s width, `periods` full
    /// cycles, `amplitude` points of vertical excursion about `rect.midY`
    /// ، built from `periods * 4` quarter-cubic segments (horizontal
    /// tangent at each crest/trough, diagonal tangent at each midline
    /// crossing), a standard smooth-wave Bézier approximation (not an
    /// analytic sine ، adequate for a decorative preset; the LUT samples
    /// whatever curve results exactly, so downstream layout is unaffected
    /// by this choice).
    public static func wave(rect: CGRect, periods: Int, amplitude: CGFloat) -> BezierPathModel {
        let periods = max(1, periods)
        let quarters = periods * 4
        let quarterWidth = rect.width / CGFloat(quarters)
        let midY = rect.midY
        let kappa: CGFloat = 0.5523
        var anchors: [PathAnchor] = [PathAnchor(point: CGPoint(x: rect.minX, y: midY))]
        // Per-quarter target y and "shape" (0 = crossing→crest/trough with
        // zero exit slope, 1 = crest/trough→crossing with zero entry slope).
        for i in 0..<quarters {
            let x0 = rect.minX + CGFloat(i) * quarterWidth
            let x1 = x0 + quarterWidth
            let phase = i % 4
            let y0 = anchors[anchors.count - 1].point.y
            let y1: CGFloat
            switch phase {
            case 0: y1 = midY + amplitude   // crossing (rising) -> crest
            case 1: y1 = midY               // crest -> crossing (falling)
            case 2: y1 = midY - amplitude   // crossing (falling) -> trough
            default: y1 = midY              // trough -> crossing (rising)
            }
            let dx = quarterWidth * kappa
            let startsAtExtremum = (phase == 1 || phase == 3)
            let endsAtExtremum = (phase == 0 || phase == 2)
            let c1 = startsAtExtremum
                ? CGPoint(x: x0 + dx, y: y0)
                : CGPoint(x: x0 + dx, y: y0 + (y1 - y0) * 0.6)
            let c2 = endsAtExtremum
                ? CGPoint(x: x1 - dx, y: y1)
                : CGPoint(x: x1 - dx, y: y1 - (y1 - y0) * 0.6)
            anchors[anchors.count - 1].handleOut = c1
            anchors.append(PathAnchor(point: CGPoint(x: x1, y: y1), handleIn: c2, handleOut: nil))
        }
        return BezierPathModel(anchors: anchors, isClosed: false)
    }
}
