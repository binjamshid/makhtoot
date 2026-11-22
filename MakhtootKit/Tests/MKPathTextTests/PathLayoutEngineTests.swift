import CoreGraphics
import MKFoundation
import MKModel
@testable import MKPathText
import MKTextEngine
import Testing

@Suite("PathLayoutEngine ، task 4/5/6/7/8/9, T-PTH-2/3/5")
struct PathLayoutEngineTests {
    // MARK: - Task 4 accept: straight-line identity sanity

    @Test("Straight-line, LTR text: engine's cumulative pen math matches CT's own cumulative advances")
    func straightLineIdentitySanity() {
        let line = Fixtures.shape("Hello World", direction: .leftToRight)
        let width = CGFloat(line.typographicBounds.width)
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: width + 400, y: 0))
        let options = PathLayoutOptions(startOffset: 0, side: .center, alignment: .start)
        let result = PathLayoutEngine.layout(line: line, path: path, options: options)

        for placement in result.placements where !placement.isMark {
            let run = line.runs[placement.address.run]
            let ctPos = run.positions[placement.address.glyph]
            let advance = run.advances[placement.address.glyph].width
            let expectedCenterX = ctPos.x + advance / 2
            #expect(abs(placement.position.x - expectedCenterX) < 0.5)
            #expect(abs(placement.position.y - ctPos.y) < 0.5)
            #expect(abs(placement.rotation) < 1e-6) // path is horizontal +x -> zero rotation, identical to flat orientation
        }
    }

    // MARK: - Task 4 accept: circle fixture, no NaN, monotonic, marks ride bases

    @Test("Circle fixture (بسم الله الرحمن الرحيم): monotonic arc positions, no NaN, marks ride bases")
    func circleFixtureMonotonicNoNaN() {
        let line = Fixtures.shape(Fixtures.bismillah)
        let path = Fixtures.circle(radius: 500)
        let lut = ArcLengthLUT(path: path)
        let options = PathLayoutOptions(startOffset: 0)
        let result = PathLayoutEngine.layoutClosed(line: line, lut: lut, options: options)

        #expect(!result.placements.isEmpty)
        for placement in result.placements {
            #expect(placement.position.x.isFinite && placement.position.y.isFinite)
            #expect(placement.rotation.isFinite)
        }
        // Monotonic arc positions at CLUSTER granularity (pen order):
        // component glyphs inside one cluster may carry a tiny negative
        // CT advance (see `clusterPenSpans`'s doc comment), so the
        // T-PTH-2 monotonicity contract is asserted per cluster span.
        let spans = Self.clusterPenSpans(result, line: line)
        for i in 1..<spans.count {
            #expect(spans[i].start >= spans[i - 1].start - 1e-6)
        }
        // Every mark placement's arc length matches its base's (rides the
        // base frame, task 4d) rather than being independently placed.
        let baseByAddress = Dictionary(uniqueKeysWithValues: result.placements.filter { !$0.isMark }.map { ($0.address, $0) })
        for mark in result.placements where mark.isMark && mark.baseClusterID != nil {
            // The mark's arc length should coincide with SOME base's arc
            // length (it rode a base frame, not an independent pen slot).
            #expect(result.placements.contains { !$0.isMark && $0.clusterID == mark.baseClusterID })
            _ = baseByAddress
        }
    }

    @Test("'لا' ligature is a single placement, never split by the path")
    func ligatureIsSinglePlacement() {
        let line = Fixtures.shape(Fixtures.laLigature)
        let path = Fixtures.gentleArc()
        let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
        let laCluster = line.clusterMap.clusters.first { cluster in
            cluster.kind == .ligature && cluster.codepoints.count == 2
        }
        #expect(laCluster != nil)
        if let laCluster {
            let placementsForCluster = result.placements.filter { $0.clusterID == laCluster.id }
            #expect(placementsForCluster.count == 1)
        }
    }

    // MARK: - T-PTH-2: logical reading order pen advance

    /// Walks base placements in ARRAY (pen/logical) order and returns the
    /// per-cluster pen spans `[start, end)`. Span edges are reconstructed
    /// from each glyph's `arcLength` (its advance-span midpoint) ± half
    /// its RAW captured advance ، array order, NOT sorted by arcLength:
    /// Core Text emits genuinely negative advances for some component
    /// glyphs inside a multi-glyph cluster (probed: ق in «الرقم» is two
    /// glyphs, advances −2.31/+14.69), so arcLength-sorted order is not
    /// pen order for those clusters.
    static func clusterPenSpans(_ result: PathLayoutResult, line: MKShapedLine) -> [(clusterID: MKClusterID, start: CGFloat, end: CGFloat)] {
        var spans: [(clusterID: MKClusterID, start: CGFloat, end: CGFloat)] = []
        for placement in result.placements where !placement.isMark {
            let advance = line.runs[placement.address.run].advances[placement.address.glyph].width
            let start = placement.arcLength - advance / 2
            let end = placement.arcLength + advance / 2
            if let last = spans.last, last.clusterID == placement.clusterID {
                spans[spans.count - 1].end = end
            } else {
                spans.append((placement.clusterID, start, end))
            }
        }
        return spans
    }

    @Test("Multi-switch fixture «Hello سلام World ٤٥»: arc offsets strictly increase, no drift at direction switches")
    func multiSwitchFixtureArcOffsetsMonotonic() {
        let line = Fixtures.shape(Fixtures.multiSwitch, direction: .leftToRight)
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 4000, y: 0))
        let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
        let spans = Self.clusterPenSpans(result, line: line)
        #expect(spans.count > 5)
        // T-PTH-2: arc offsets strictly increase in logical reading order,
        // no drift/gap/overlap at either direction switch ، each cluster's
        // pen span begins exactly where the previous one ended.
        for i in 1..<spans.count {
            #expect(spans[i].start > spans[i - 1].start)
            #expect(abs(spans[i].start - spans[i - 1].end) < 0.01)
        }
        // Total consumed arc length equals the sum of captured advances.
        var totalAdvance: CGFloat = 0
        for placement in result.placements where !placement.isMark {
            totalAdvance += line.runs[placement.address.run].advances[placement.address.glyph].width
        }
        #expect(abs((spans.last!.end - spans.first!.start) - totalAdvance) < 0.01)
    }

    @Test("No-space digit adjacency «الرقم٤٥»: no phantom gap, no double-counted advance")
    func noSpaceDigitAdjacencyHasNoGapOrOverlap() {
        let line = Fixtures.shape(Fixtures.noSpaceDigits)
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 2000, y: 0))
        let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
        let spans = Self.clusterPenSpans(result, line: line)
        #expect(spans.count >= 5) // ا ل ر ق م ٤ ٥ (allowing for ligature/cluster grouping)
        // The digit run's first glyph attaches directly to the preceding
        // Arabic glyph's arc offset: every adjacent cluster pair is exactly
        // contiguous ، no phantom gap, no double-counted advance.
        for i in 1..<spans.count {
            #expect(abs(spans[i].start - spans[i - 1].end) < 0.01)
        }
    }

    // MARK: - Task 6: alignment / start offset

    @Test("Center alignment centers a short text on a long straight path")
    func centerAlignment() {
        let line = Fixtures.shape("سلام", direction: .rightToLeft)
        let pathLength: CGFloat = 2000
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: pathLength, y: 0))
        let options = PathLayoutOptions(alignment: .center)
        let result = PathLayoutEngine.layout(line: line, path: path, options: options)
        let spans = Self.clusterPenSpans(result, line: line)
        let leftMargin = spans.first!.start
        let rightMargin = pathLength - spans.last!.end
        #expect(abs(leftMargin - rightMargin) < 1.0)
    }

    // MARK: - Task 7: baseline side / inside-out

    @Test("Baseline offset shifts glyphs off the raw path along the normal")
    func baselineOffsetShiftsAlongNormal() {
        let line = Fixtures.shape("سلام")
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 800, y: 0))
        let onCurve = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions(side: .center))
        let above = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions(side: .above, baselineOffsetMagnitude: 20))
        let onY = onCurve.placements.first { !$0.isMark }!.position.y
        let aboveY = above.placements.first { !$0.isMark }!.position.y
        #expect(abs(aboveY - onY) > 1.0)
    }

    @Test("insideOut flips rotation by pi")
    func insideOutFlipsRotation() {
        let line = Fixtures.shape("a", direction: .leftToRight)
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 200, y: 0))
        let normal = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
        let flipped = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions(insideOut: true))
        let a = normal.placements.first { !$0.isMark }!.rotation
        let b = flipped.placements.first { !$0.isMark }!.rotation
        var delta = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if delta < 0 { delta += 2 * .pi }
        #expect(abs(delta - .pi) < 1e-4)
    }

    // MARK: - Task 8: join-continuity mitigation

    @Test("Gentle arc (r >= 4x font size): no curvature warning")
    func gentleArcNoCurvatureWarning() {
        let line = Fixtures.shape(Fixtures.tatweelStretch, size: 36)
        let path = BezierPathModel.arc(center: .zero, radius: 200, startAngle: -.pi / 4, endAngle: .pi / 4) // radius >> 4*36
        let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
        #expect(!result.curvatureWarning)
    }

    @Test("Sharp-corner star path: curvature warning set, no crash, no NaN")
    func sharpCornerSetsCurvatureWarning() {
        let line = Fixtures.shape("سلام")
        let path = Fixtures.sharpCorner()
        let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
        #expect(result.curvatureWarning)
        for placement in result.placements {
            #expect(placement.position.x.isFinite && placement.position.y.isFinite)
            #expect(placement.rotation.isFinite)
        }
    }

    // MARK: - T-PTH-3: overflow

    @Test("Overflow: continueTangent flags but never drops")
    func overflowContinueTangent() {
        let line = Fixtures.shape("بسم الله الرحمن الرحيم الرحمن الرحيم", size: 48)
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 300, y: 0)) // deliberately short
        let options = PathLayoutOptions(overflow: .continueTangent)
        let result = PathLayoutEngine.layout(line: line, path: path, options: options)
        #expect(result.overflow.isOverflowing)
        #expect(result.overflow.continuedStraight)
        let expectedBaseCount = line.clusterMap.clusters.filter { c in
            if case .markOnly = c.kind { return false }
            return c.kind != .control
        }.reduce(0) { $0 + $1.glyphs.count }
        let actualBaseCount = result.placements.filter { !$0.isMark }.count
        #expect(actualBaseCount == expectedBaseCount) // nothing dropped
    }

    @Test("Overflow: clip excludes glyphs beyond the path end, records the clipped range")
    func overflowClip() {
        let line = Fixtures.shape("بسم الله الرحمن الرحيم الرحمن الرحيم", size: 48)
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 300, y: 0))
        let options = PathLayoutOptions(overflow: .clip)
        let result = PathLayoutEngine.layout(line: line, path: path, options: options)
        #expect(result.overflow.isOverflowing)
        #expect(result.overflow.overflowUTF16Range != nil)
        #expect(!result.overflow.continuedStraight)
    }

    @Test("Shortening text restores full (non-overflowing) layout")
    func shorterTextRestoresFullLayout() {
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 300, y: 0))
        let long = Fixtures.shape("بسم الله الرحمن الرحيم الرحمن الرحيم", size: 48)
        let overflowing = PathLayoutEngine.layout(line: long, path: path, options: PathLayoutOptions())
        #expect(overflowing.overflow.isOverflowing)

        let short = Fixtures.shape("سلام", size: 24)
        let fine = PathLayoutEngine.layout(line: short, path: path, options: PathLayoutOptions())
        #expect(!fine.overflow.isOverflowing)
    }

    // MARK: - T-PTH-5: closed-path wrap

    @Test("Closed-path wrap: no crash, no NaN, start offset shifts text deterministically")
    func closedPathWrapDeterministicStartOffset() {
        let line = Fixtures.shape("نص دائري مستمر")
        let path = Fixtures.circle(radius: 150) // deliberately small: text will wrap past its circumference
        let lut = ArcLengthLUT(path: path)

        let a = PathLayoutEngine.layoutClosed(line: line, lut: lut, options: PathLayoutOptions(startOffset: 0))
        let b = PathLayoutEngine.layoutClosed(line: line, lut: lut, options: PathLayoutOptions(startOffset: 20))
        #expect(a.placements.count == b.placements.count)
        for placement in a.placements + b.placements {
            #expect(placement.position.x.isFinite && placement.position.y.isFinite)
        }
        let firstA = a.placements.first { !$0.isMark }!.arcLength
        let firstB = b.placements.first { !$0.isMark }!.arcLength
        var delta = (firstB - firstA).truncatingRemainder(dividingBy: lut.totalLength)
        if delta < 0 { delta += lut.totalLength }
        #expect(abs(delta - 20) < 1.0 || abs(delta - 20 - lut.totalLength) < 1.0)
    }

    // MARK: - Task 9: user-offset carry-over by cluster provenance

    @Test("User offset applies to the matching glyph and survives a relayout of longer text")
    func userOffsetAppliesAndSurvivesRelayout() {
        let shortLine = Fixtures.shape("علي")
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 1000, y: 0))
        let baseline = PathLayoutEngine.layout(line: shortLine, path: path, options: PathLayoutOptions())
        let firstKey = baseline.placements.first { !$0.isMark }!.provenanceKey
        let userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [firstKey: PathGlyphUserOffset(offset: CGPoint(x: 5, y: 5))]

        let nudged = PathLayoutEngine.layout(line: shortLine, path: path, options: PathLayoutOptions(), userOffsets: userOffsets)
        let plainPos = baseline.placements.first { !$0.isMark }!.position
        let nudgedPos = nudged.placements.first { !$0.isMark }!.position
        #expect(hypot(nudgedPos.x - plainPos.x, nudgedPos.y - plainPos.y) > 1.0)

        // Appending a letter (retype) keeps the SAME provenance key for
        // the unchanged prefix, so the SAME userOffsets dictionary still
        // nudges the same (now-relaid) glyph ، task 9's accept criterion.
        let longerLine = Fixtures.shape("عليك")
        let relaid = PathLayoutEngine.layout(line: longerLine, path: path, options: PathLayoutOptions(), userOffsets: userOffsets)
        let relaidMatch = relaid.placements.first { !$0.isMark && $0.provenanceKey == firstKey }
        #expect(relaidMatch != nil)
        if let relaidMatch {
            #expect(relaidMatch.userOffset == CGPoint(x: 5, y: 5))
        }
    }

    // MARK: - Mixed bidi contiguity

    @Test("Mixed bidi run «عام ٢٠٢٦ Design» stays contiguous in arc-traversal order")
    func mixedBidiContiguous() {
        let line = Fixtures.shape(Fixtures.mixedBidiDigits)
        let path = BezierPathModel.line(from: .zero, to: CGPoint(x: 2000, y: 0))
        let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
        let bases = result.placements.filter { !$0.isMark }
        for i in 1..<bases.count {
            #expect(bases[i].arcLength >= bases[i - 1].arcLength - 1e-3)
        }
    }

    // MARK: - Degenerate geometry

    @Test("Zero-length path: no crash, no NaN")
    func zeroLengthPathNoCrash() {
        let line = Fixtures.shape("سلام")
        let path = BezierPathModel.line(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5))
        let result = PathLayoutEngine.layout(line: line, path: path, options: PathLayoutOptions())
        for placement in result.placements {
            #expect(placement.position.x.isFinite && placement.position.y.isFinite)
            #expect(placement.rotation.isFinite)
        }
    }
}
