import CoreGraphics
import MKModel
@testable import MKPathText
import MKTextEngine
import Testing

// WS-05 packet §5 task 13. Wall-clock host-toolchain perf checks (same
// pattern `MKArrangeTests/PerfTests.swift` and WS-03's D-115 pre-gate
// established: a warm-up call before the timed measurement, generous local
// bounds ، these are NOT the authoritative device numbers D-115 budgets
// against, just a fast local regression guard; device-level signpost
// measurement is WS-07's `pathRelayout` signpost integration, flagged as a
// follow-up since no live `MKCanvas` render loop exists yet to attach it
// to end-to-end).
//
// SIMULATOR-INDICATIVE: the elapsedMs numbers below are measured on the
// swift-test host (Xcode Simulator or macOS host process running `swift
// test`, never real device hardware) and stand in for the real D-115
// device budgets noted per test ، see docs/impl-log/WS-07-p14.md's
// "T-PRF budget sweep vs D-115" section for the measured-margin table and
// the full device-gated list.
@Suite("PathLayoutEngine ، task 13 perf pre-gates")
struct PerfTests {
    static func eightSegmentPath() -> BezierPathModel {
        var anchors: [PathAnchor] = [PathAnchor(point: .zero)]
        for i in 1...8 {
            anchors.append(PathAnchor(
                point: CGPoint(x: CGFloat(i) * 150, y: CGFloat(i % 2) * 60),
                handleIn: CGPoint(x: CGFloat(i) * 150 - 40, y: CGFloat(i % 2) * 60),
                handleOut: CGPoint(x: CGFloat(i) * 150 + 40, y: CGFloat(i % 2) * 60)))
        }
        return BezierPathModel(anchors: anchors, isClosed: false)
    }

    @Test("Relayout (no reshape) of a ~60-glyph string on an 8-segment path is fast")
    func relayoutBudget() {
        let text = String(repeating: "بسم الله الرحمن الرحيم ", count: 3)
        let line = Fixtures.shape(text, size: 24)
        let path = Self.eightSegmentPath()
        let lut = ArcLengthLUT(path: path) // built once, reused (relayout doesn't rebuild the LUT unless the path changed)
        let options = PathLayoutOptions()

        // Warm-up.
        _ = PathLayoutEngine.layout(line: line, lut: lut, options: options)

        let start = DispatchTime.now()
        _ = PathLayoutEngine.layout(line: line, lut: lut, options: options)
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        #expect(elapsedMs < 20.0) // generous host bound; packet's <2ms is a device budget
    }

    @Test("Full reshape+relayout of a typical path-text string is fast")
    func fullReshapeAndRelayoutBudget() {
        let path = Self.eightSegmentPath()
        let options = PathLayoutOptions()

        func reshapeAndLayout() {
            let line = Fixtures.shape(Fixtures.bismillah, size: 30)
            _ = PathLayoutEngine.layout(line: line, path: path, options: options)
        }

        reshapeAndLayout() // warm-up

        let start = DispatchTime.now()
        reshapeAndLayout()
        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        #expect(elapsedMs < 30.0) // generous host bound; packet's <6ms is a device budget
    }
}
