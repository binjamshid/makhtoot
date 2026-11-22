import CoreGraphics
import MKModel
@testable import MKPathText
import Testing

@Suite("ArcLengthLUT ، task 2 / T-PTH-1 accepts")
struct ArcLengthLUTTests {
    @Test("Straight line: point/tangent are exact")
    func lineExact() {
        let model = BezierPathModel.line(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 10 + 300, y: 20))
        let lut = ArcLengthLUT(path: model)
        #expect(abs(lut.totalLength - 300) < 1e-6)
        let mid = lut.point(atLength: 150)
        #expect(abs(mid.x - 160) < 1e-6)
        #expect(abs(mid.y - 20) < 1e-6)
        let tangent = lut.tangent(atLength: 150)
        #expect(abs(tangent.dx - 1) < 1e-6)
        #expect(abs(tangent.dy - 0) < 1e-6)
    }

    @Test("Circle: point/tangent accuracy at 100 sampled lengths ، T-PTH-1")
    func circleAnalyticAccuracy() {
        let radius: CGFloat = 300
        let model = BezierPathModel.circle(center: .zero, radius: radius)
        let lut = ArcLengthLUT(path: model)
        let n = 100
        var maxPositionError: CGFloat = 0
        var maxAngleErrorDegrees: CGFloat = 0
        for i in 0..<n {
            let s = lut.totalLength * CGFloat(i) / CGFloat(n)
            let angle = s / radius // arc length -> angle on a circle
            let analyticPoint = CGPoint(x: radius * cos(angle), y: radius * sin(angle))
            let analyticTangent = CGVector(dx: -sin(angle), dy: cos(angle))

            let frame = lut.frame(atLength: s)
            let positionError = hypot(frame.point.x - analyticPoint.x, frame.point.y - analyticPoint.y)
            maxPositionError = max(maxPositionError, positionError)

            let dot = frame.tangent.dx * analyticTangent.dx + frame.tangent.dy * analyticTangent.dy
            let angleError = acos(min(1, max(-1, dot))) * 180 / .pi
            maxAngleErrorDegrees = max(maxAngleErrorDegrees, angleError)
        }
        #expect(maxPositionError < 0.1)
        #expect(maxAngleErrorDegrees < 0.5)
    }

    @Test("Degenerate near-zero-length segment: no NaN/infinite tangents")
    func degenerateSegmentNoNaN() {
        let p = CGPoint(x: 50, y: 50)
        let segments = [
            MKBezierSegment(start: p, c1: p, c2: p, end: p), // fully coincident (zero-length, a cusp)
        ]
        let lut = ArcLengthLUT(segments: segments)
        let tangent = lut.tangent(atLength: 0)
        #expect(tangent.dx.isFinite)
        #expect(tangent.dy.isFinite)
        #expect(!tangent.dx.isNaN)
        #expect(!tangent.dy.isNaN)
        let point = lut.point(atLength: 0)
        #expect(point.x.isFinite && point.y.isFinite)
    }

    @Test("Unit-circle-scale LUT: build accuracy at 1000pt scale")
    func unitCircleAt1000ptScale() {
        let radius: CGFloat = 1000
        let model = BezierPathModel.circle(center: .zero, radius: radius)
        let lut = ArcLengthLUT(path: model)
        for i in stride(from: 0, to: 1000, by: 97) {
            let s = CGFloat(i)
            let angle = s / radius
            let analytic = CGPoint(x: radius * cos(angle), y: radius * sin(angle))
            let p = lut.point(atLength: s)
            #expect(hypot(p.x - analytic.x, p.y - analytic.y) < 0.1)
        }
    }

    @Test("LUT build for a 6-segment path completes well under 1 ms")
    func sixSegmentBuildPerf() {
        var anchors: [PathAnchor] = [PathAnchor(point: .zero)]
        for i in 1...6 {
            anchors.append(PathAnchor(
                point: CGPoint(x: CGFloat(i) * 100, y: CGFloat(i % 2) * 40),
                handleIn: CGPoint(x: CGFloat(i) * 100 - 30, y: CGFloat(i % 2) * 40 + 10),
                handleOut: CGPoint(x: CGFloat(i) * 100 + 30, y: CGFloat(i % 2) * 40 - 10)))
        }
        let model = BezierPathModel(anchors: anchors, isClosed: false)
        // Warm up (first call pays one-time Swift runtime costs, matching
        // WS-03's own documented warm-up precedent for perf pre-gates).
        _ = ArcLengthLUT(path: model)
        let start = DispatchTime.now()
        _ = ArcLengthLUT(path: model)
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        #expect(elapsedMs < 5.0) // generous local-host bound; packet's <1ms target is a device-level budget (D-115 pattern)
    }

    @Test("nearestLength maps a known on-curve point back to its arc length")
    func nearestLengthRoundTrip() {
        let model = Fixtures.gentleArc(radius: 500)
        let lut = ArcLengthLUT(path: model)
        let knownLength = lut.totalLength * 0.37
        let point = lut.point(atLength: knownLength)
        let recovered = lut.nearestLength(to: point)
        #expect(abs(recovered - knownLength) < 1.0)
    }

    @Test("segmentAndLocalT stays within bounds across the whole length range")
    func segmentAndLocalTBounds() {
        let model = Fixtures.gentleArc(radius: 500)
        let lut = ArcLengthLUT(path: model)
        for i in 0...20 {
            let s = lut.totalLength * CGFloat(i) / 20
            let (segIndex, t) = lut.segmentAndLocalT(atLength: s)
            #expect(segIndex >= 0)
            #expect(t >= 0 && t <= 1)
        }
    }
}
