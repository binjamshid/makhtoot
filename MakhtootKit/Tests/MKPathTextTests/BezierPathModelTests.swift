import CoreGraphics
import MKModel
@testable import MKPathText
import Testing

@Suite("BezierPathModel ، task 1 accepts")
struct BezierPathModelTests {
    @Test("Anchors <-> MKBezierPathData round-trips (open)")
    func openRoundTrip() {
        let model = BezierPathModel(anchors: [
            PathAnchor(point: CGPoint(x: 0, y: 0), handleOut: CGPoint(x: 30, y: 0)),
            PathAnchor(point: CGPoint(x: 100, y: 0), handleIn: CGPoint(x: 70, y: 0), handleOut: CGPoint(x: 130, y: 50)),
            PathAnchor(point: CGPoint(x: 200, y: 100), handleIn: CGPoint(x: 170, y: 100)),
        ], isClosed: false)
        let data = model.bezierPathData()
        let reconstructed = BezierPathModel(data)
        #expect(reconstructed.bezierPathData() == data)
        #expect(data.segments.count == model.anchors.count - 1)
    }

    @Test("Anchors <-> MKBezierPathData round-trips (closed)")
    func closedRoundTrip() {
        let model = BezierPathModel.circle(center: CGPoint(x: 50, y: 50), radius: 80)
        let data = model.bezierPathData()
        #expect(data.isClosed)
        let reconstructed = BezierPathModel(data)
        let data2 = reconstructed.bezierPathData()
        #expect(data2.isClosed)
        #expect(data.segments.count == data2.segments.count)
        for (a, b) in zip(data.segments, data2.segments) {
            #expect(abs(a.start.x - b.start.x) < 1e-6)
            #expect(abs(a.end.y - b.end.y) < 1e-6)
        }
    }

    @Test("CGPath segment count matches anchors (open line)")
    func cgPathSegmentCountLine() {
        let model = BezierPathModel.line(from: .zero, to: CGPoint(x: 500, y: 0))
        let data = model.bezierPathData()
        #expect(data.segments.count == 1)
        #expect(!model.cgPath().isEmpty)
    }

    @Test("Circle circumference within 0.1% of 2*pi*r")
    func circleCircumference() {
        let radius: CGFloat = 250
        let model = BezierPathModel.circle(center: .zero, radius: radius)
        let lut = ArcLengthLUT(path: model)
        let analytic = 2 * CGFloat.pi * radius
        let error = abs(lut.totalLength - analytic) / analytic
        #expect(error < 0.001)
    }

    @Test("Arc preset sweeps the requested angle")
    func arcSweep() {
        let radius: CGFloat = 400
        let sweep = CGFloat.pi / 3
        let model = BezierPathModel.arc(center: .zero, radius: radius, startAngle: 0, endAngle: sweep)
        let lut = ArcLengthLUT(path: model)
        let analytic = radius * sweep
        let error = abs(lut.totalLength - analytic) / analytic
        #expect(error < 0.001)
    }

    @Test("Wave preset produces a valid, non-empty path spanning the rect width")
    func wavePreset() {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 200)
        let model = BezierPathModel.wave(rect: rect, periods: 3, amplitude: 60)
        #expect(model.isValid)
        #expect(model.anchors.first?.point.x == rect.minX)
        #expect(model.anchors.last?.point.x == rect.maxX)
        let lut = ArcLengthLUT(path: model)
        #expect(lut.totalLength > rect.width) // a wave is always longer than its flat span
    }

    @Test("isValid enforces minimum anchor counts")
    func validity() {
        #expect(!BezierPathModel(anchors: [PathAnchor(point: .zero)], isClosed: false).isValid)
        #expect(BezierPathModel(anchors: [PathAnchor(point: .zero), PathAnchor(point: CGPoint(x: 1, y: 0))], isClosed: false).isValid)
        #expect(!BezierPathModel(anchors: [PathAnchor(point: .zero), PathAnchor(point: CGPoint(x: 1, y: 0))], isClosed: true).isValid)
    }
}
