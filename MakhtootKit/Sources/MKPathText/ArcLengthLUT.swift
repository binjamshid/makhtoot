import CoreGraphics
import MKModel

// WS-05 packet §5 task 2 (D-110's core numeric machinery; ARCHITECTURE §9.3
// `MKArcLengthTable`). Adaptive per-cubic-segment subdivision (flatness
// tolerance 0.05 pt, 16...512 samples per segment) building a cumulative
// arc-length table; `point(atLength:)`/`tangent(atLength:)`/`frame(atLength:)`
// do a binary search over the cumulative table for the bracketing samples,
// linearly interpolate the *parameter* `t` between them proportional to the
// arc-length fraction, then evaluate the exact analytic cubic
// point/derivative at that interpolated `t` (not a linear blend of the
// bracketing points/tangents themselves) ، this is what keeps circle
// accuracy well inside T-PTH-1's <0.1 pt / <0.5° budget even though the
// underlying arc-length↔parameter map is only piecewise-linear: the fine
// (0.05 pt-flat) subdivision makes that piecewise-linear approximation
// error tiny, and the final point/tangent themselves are always exact
// analytic evaluations, never interpolated.
public struct ArcLengthLUT: Sendable {
    /// One subdivision sample: `globalT = segmentIndex + localT` and the
    /// cumulative arc length from the path start up to it.
    struct Sample: Sendable {
        var globalT: Double
        var arcLength: CGFloat
    }

    private let segments: [MKBezierSegment]
    private let samples: [Sample]
    public let totalLength: CGFloat
    public let segmentCount: Int

    public init(path: BezierPathModel) {
        self.init(segments: path.bezierPathData().segments)
    }

    public init(segments: [MKBezierSegment]) {
        self.segments = segments
        self.segmentCount = segments.count
        guard !segments.isEmpty else {
            self.samples = []
            self.totalLength = 0
            return
        }
        var built: [Sample] = [Sample(globalT: 0, arcLength: 0)]
        var cumulative: CGFloat = 0
        for (segIndex, seg) in segments.enumerated() {
            let n = Self.adaptiveSampleCount(seg)
            var prevPoint = seg.start
            for i in 1...n {
                let t = CGFloat(i) / CGFloat(n)
                let p = Self.point(seg, at: t)
                cumulative += hypot(p.x - prevPoint.x, p.y - prevPoint.y)
                built.append(Sample(globalT: Double(segIndex) + Double(t), arcLength: cumulative))
                prevPoint = p
            }
        }
        self.samples = built
        self.totalLength = cumulative
    }

    // MARK: - Adaptive subdivision (task 2: 0.05 pt flatness, 16...512 samples/segment)

    private static func adaptiveSampleCount(
        _ seg: MKBezierSegment, tolerance: CGFloat = 0.05, minSamples: Int = 16, maxSamples: Int = 512
    ) -> Int {
        var n = minSamples
        var prevLength = polylineLength(seg, samples: n)
        while n < maxSamples {
            let n2 = min(n * 2, maxSamples)
            let newLength = polylineLength(seg, samples: n2)
            if abs(newLength - prevLength) < tolerance { return n2 }
            prevLength = newLength
            n = n2
        }
        return maxSamples
    }

    private static func polylineLength(_ seg: MKBezierSegment, samples n: Int) -> CGFloat {
        var length: CGFloat = 0
        var prev = seg.start
        for i in 1...n {
            let t = CGFloat(i) / CGFloat(n)
            let p = point(seg, at: t)
            length += hypot(p.x - prev.x, p.y - prev.y)
            prev = p
        }
        return length
    }

    // MARK: - Analytic cubic evaluation

    static func point(_ seg: MKBezierSegment, at t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let t2 = t * t
        let x = mt2 * mt * seg.start.x + 3 * mt2 * t * seg.c1.x + 3 * mt * t2 * seg.c2.x + t2 * t * seg.end.x
        let y = mt2 * mt * seg.start.y + 3 * mt2 * t * seg.c1.y + 3 * mt * t2 * seg.c2.y + t2 * t * seg.end.y
        return CGPoint(x: x, y: y)
    }

    /// Normalized first derivative w.r.t. `t`. §9.6 degenerate-geometry
    /// fallback: when the analytic derivative is (near-)zero ، coincident
    /// control points, a cusp ، falls back to the secant direction over a
    /// small `t` window instead of producing a NaN/zero-magnitude vector
    /// (T-PTH-1's "degenerate segments do not produce NaN/infinite
    /// tangents" gate). A fully degenerate (point) segment returns a fixed,
    /// stable direction rather than NaN.
    static func tangent(_ seg: MKBezierSegment, at t: CGFloat) -> CGVector {
        let mt = 1 - t
        let dx = 3 * mt * mt * (seg.c1.x - seg.start.x) + 6 * mt * t * (seg.c2.x - seg.c1.x) + 3 * t * t * (seg.end.x - seg.c2.x)
        let dy = 3 * mt * mt * (seg.c1.y - seg.start.y) + 6 * mt * t * (seg.c2.y - seg.c1.y) + 3 * t * t * (seg.end.y - seg.c2.y)
        let mag = hypot(dx, dy)
        if mag > 1e-9 {
            return CGVector(dx: dx / mag, dy: dy / mag)
        }
        let tLow = max(0, t - 0.01)
        let tHigh = min(1, t + 0.01)
        let pLow = point(seg, at: tLow)
        let pHigh = point(seg, at: tHigh)
        let sdx = pHigh.x - pLow.x
        let sdy = pHigh.y - pLow.y
        let smag = hypot(sdx, sdy)
        guard smag > 1e-9 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: sdx / smag, dy: sdy / smag)
    }

    // MARK: - Public queries (task 2)

    public func point(atLength length: CGFloat) -> CGPoint { frame(atLength: length).point }
    public func tangent(atLength length: CGFloat) -> CGVector { frame(atLength: length).tangent }

    /// `(point, tangent, normal)` at arc length `length` (clamped to
    /// `[0, totalLength]`). `normal` is the LEFT normal of `tangent`
    /// (`(-tangent.dy, tangent.dx)`) ، the convention `PathLayoutEngine`
    /// uses for baseline-side offsets.
    public func frame(atLength length: CGFloat) -> (point: CGPoint, tangent: CGVector, normal: CGVector) {
        let (segIndex, localT) = segmentAndLocalT(atLength: length)
        guard segIndex >= 0, segIndex < segments.count else {
            return (.zero, CGVector(dx: 1, dy: 0), CGVector(dx: 0, dy: 1))
        }
        let seg = segments[segIndex]
        let p = Self.point(seg, at: localT)
        let tan = Self.tangent(seg, at: localT)
        let normal = CGVector(dx: -tan.dy, dy: tan.dx)
        return (p, tan, normal)
    }

    /// The `(segmentIndex, localT)` pair a given arc length maps to ،
    /// exposed for `PathEditModel.insertAnchor(atLength:)`, which needs the
    /// exact split point for a lossless de Casteljau subdivision, not just
    /// the evaluated point.
    public func segmentAndLocalT(atLength length: CGFloat) -> (segmentIndex: Int, localT: CGFloat) {
        guard !samples.isEmpty, !segments.isEmpty else { return (0, 0) }
        guard totalLength > 0 else { return (0, 0) }
        let clamped = min(max(length, 0), totalLength)
        let (i0, i1) = bracket(for: clamped)
        let s0 = samples[i0], s1 = samples[i1]
        let span = s1.arcLength - s0.arcLength
        let frac = span > 0 ? Double((clamped - s0.arcLength) / span) : 0
        let globalT = s0.globalT + (s1.globalT - s0.globalT) * frac
        let segIndex = min(max(Int(globalT), 0), segments.count - 1)
        let localT = CGFloat(globalT - Double(segIndex))
        return (segIndex, min(max(localT, 0), 1))
    }

    /// Binary search over the monotonically non-decreasing `arcLength`
    /// column for the bracketing sample indices.
    private func bracket(for length: CGFloat) -> (Int, Int) {
        var lo = 0
        var hi = samples.count - 1
        if length <= samples[0].arcLength { return (0, min(1, hi)) }
        if length >= samples[hi].arcLength { return (max(0, hi - 1), hi) }
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if samples[mid].arcLength <= length { lo = mid } else { hi = mid }
        }
        return (lo, hi)
    }

    /// Nearest arc length to `query` (task 2's hit-mapping accept
    /// criterion): a coarse pass over every LUT sample followed by a fine
    /// local refinement (20 sub-steps either side of the coarse winner,
    /// exact analytic evaluation) so `PathEditModel.insertAnchor`'s
    /// "lands within 1 pt of the tapped location" bound holds even when
    /// the coarse sample spacing is wider than that.
    public func nearestLength(to query: CGPoint) -> CGFloat {
        guard !samples.isEmpty, !segments.isEmpty else { return 0 }
        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (i, s) in samples.enumerated() {
            let (segIndex, localT) = segmentAndLocalT(atLength: s.arcLength)
            let p = Self.point(segments[segIndex], at: localT)
            let d = hypot(p.x - query.x, p.y - query.y)
            if d < bestDistance {
                bestDistance = d
                bestIndex = i
            }
        }
        let coarseLength = samples[bestIndex].arcLength
        let windowLow = samples[max(0, bestIndex - 1)].arcLength
        let windowHigh = samples[min(samples.count - 1, bestIndex + 1)].arcLength
        var bestLength = coarseLength
        var bestFineDistance = bestDistance
        let steps = 40
        if windowHigh > windowLow {
            for i in 0...steps {
                let s = windowLow + (windowHigh - windowLow) * CGFloat(i) / CGFloat(steps)
                let (segIndex, localT) = segmentAndLocalT(atLength: s)
                let p = Self.point(segments[segIndex], at: localT)
                let d = hypot(p.x - query.x, p.y - query.y)
                if d < bestFineDistance {
                    bestFineDistance = d
                    bestLength = s
                }
            }
        }
        return bestLength
    }
}
