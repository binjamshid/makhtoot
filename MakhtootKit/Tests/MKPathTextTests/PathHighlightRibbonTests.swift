import CoreGraphics
import MKFoundation
import MKModel
@testable import MKPathText
import Testing

// Path-text highlight ribbon (pure geometry, render-agnostic). See
// `PathHighlightRibbon.swift`'s own file header for the bidi-contiguity
// argument this design rests on; these tests cover the geometric edge
// cases its doc comments call out: straight-line rectangle equivalence,
// perpendicular rungs on a curve, `.continueTangent` overflow extension,
// the closed-path full-loop case, and `baselineOffset`/`insideOut`
// sign behavior (the exact class of bug a sign flip in the ascent/descent
// direction would produce ، see `PathHighlightRibbon.path(...)`'s own
// `insideOut` doc comment for the derivation this pins down).
@Suite("PathHighlightRibbon")
struct PathHighlightRibbonTests {
    private func points(of path: CGPath) -> [CGPoint] {
        var result: [CGPoint] = []
        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint, .addLineToPoint:
                result.append(element.points[0])
            default:
                break
            }
        }
        return result
    }

    // MARK: - Straight-line rectangle equivalence

    @Test("Straight path: ribbon's bounding box is an axis-aligned rectangle whose X-extent matches the LUT's own frame lookup")
    func straightLineGivesRectangleAlignedWithLUT() {
        let path = Fixtures.straightLine(length: 2000)
        let lut = ArcLengthLUT(path: path)
        let ascent: CGFloat = 20
        let descent: CGFloat = 8

        guard let ribbon = PathHighlightRibbon.path(
            lut: lut, from: 100, to: 300, ascent: ascent, descent: descent,
            baselineOffset: 0, insideOut: false, overflow: .clip
        ) else {
            Issue.record("expected a non-nil ribbon")
            return
        }

        let box = ribbon.boundingBoxOfPath
        // The ribbon's rungs are seeded/appended at EXACTLY the requested
        // arc lengths (100, 300 ، see `PathHighlightRibbon`'s own "Endpoint
        // guarantee" doc comment) and placed via `lut.frame(atLength:)`.
        // That is the ribbon's entire contract: land its edge rungs at the
        // arc-length values it was asked for. It does NOT and cannot
        // promise those rungs sit at the analytic points `x == 100` /
        // `x == 300` on the underlying path, because `BezierPathModel
        // .bezierPathData()` gives a handle-less straight segment
        // degenerate control points, which makes `ArcLengthLUT` walk it
        // with a smoothstep parametrisation (`x(t) = L·(3t² − 2t³)`)
        // instead of a linear one. Arc length is then non-linear in `t`,
        // so `frame(atLength:)`'s piecewise-linear-in-`t` interpolation
        // errs by ~0.9pt at INTERIOR arc lengths like 100/300 (the
        // endpoints `0` and `totalLength` remain exact, since `t` is
        // pinned to 0/1 there regardless of parametrisation). That LUT
        // imprecision is a real, pre-existing, separately-tracked defect
        // (it affects glyph placement too) ، it is NOT something this
        // ribbon can or should compensate for, so this assertion compares
        // against the LUT's own answer rather than the analytic ideal.
        // Do not "simplify" this back to `100`/`300` ، that reintroduces
        // the exact conflation this comment exists to prevent.
        #expect(abs(box.minX - lut.frame(atLength: 100).point.x) < 0.01)
        #expect(abs(box.maxX - lut.frame(atLength: 300).point.x) < 0.01)
        // Horizontal path ، LEFT normal of tangent (1,0) is (0,1) (`+y`).
        // `insideOut == false` puts the glyphs' own ascent side at
        // `-normal` and descent side at `+normal` (see `path(...)`'s
        // `insideOut` doc comment derivation) ، top edge at `-ascent`,
        // bottom edge at `+descent`.
        #expect(abs(box.minY - (-ascent)) < 0.01)
        #expect(abs(box.maxY - descent) < 0.01)
        #expect(abs(box.height - (ascent + descent)) < 0.01)
    }

    @Test("baselineOffset shifts the whole ribbon by the same amount along the normal")
    func baselineOffsetShiftsRibbon() {
        let path = Fixtures.straightLine(length: 2000)
        let lut = ArcLengthLUT(path: path)
        let ascent: CGFloat = 20
        let descent: CGFloat = 8

        guard let plain = PathHighlightRibbon.path(lut: lut, from: 100, to: 300, ascent: ascent, descent: descent, baselineOffset: 0, insideOut: false, overflow: .clip),
              let shifted = PathHighlightRibbon.path(lut: lut, from: 100, to: 300, ascent: ascent, descent: descent, baselineOffset: 15, insideOut: false, overflow: .clip)
        else {
            Issue.record("expected non-nil ribbons")
            return
        }
        #expect(abs(shifted.boundingBoxOfPath.minY - plain.boundingBoxOfPath.minY - 15) < 0.01)
        #expect(abs(shifted.boundingBoxOfPath.maxY - plain.boundingBoxOfPath.maxY - 15) < 0.01)
    }

    @Test("insideOut flips which side of the curve is the ascent side")
    func insideOutFlipsExtent() {
        let path = Fixtures.straightLine(length: 2000)
        let lut = ArcLengthLUT(path: path)
        let ascent: CGFloat = 20
        let descent: CGFloat = 8

        guard let normal = PathHighlightRibbon.path(lut: lut, from: 100, to: 300, ascent: ascent, descent: descent, baselineOffset: 0, insideOut: false, overflow: .clip),
              let flipped = PathHighlightRibbon.path(lut: lut, from: 100, to: 300, ascent: ascent, descent: descent, baselineOffset: 0, insideOut: true, overflow: .clip)
        else {
            Issue.record("expected non-nil ribbons")
            return
        }
        // `insideOut == false`: top = -ascent, bottom = +descent.
        #expect(abs(normal.boundingBoxOfPath.minY - (-ascent)) < 0.01)
        #expect(abs(normal.boundingBoxOfPath.maxY - descent) < 0.01)
        // `insideOut == true`: the glyph rotation gains +π, which negates
        // the mapped ascent/descent direction ، top = -descent, bottom =
        // +ascent (the two edges swap which raw side of the curve they
        // sit on).
        #expect(abs(flipped.boundingBoxOfPath.minY - (-descent)) < 0.01)
        #expect(abs(flipped.boundingBoxOfPath.maxY - ascent) < 0.01)
    }

    // MARK: - Curved path: rungs stay perpendicular to the tangent

    @Test("Curved path (gentle arc): every rung is perpendicular to the local tangent")
    func curvedPathRungsStayPerpendicular() {
        let path = Fixtures.gentleArc(radius: 600)
        let lut = ArcLengthLUT(path: path)
        // Equal ascent/descent so each rung's own midpoint lands exactly
        // ON the curve (no perpendicular offset to account for), keeping
        // the `nearestLength(to:)` recovery below exact rather than
        // approximate.
        let ascent: CGFloat = 12
        let descent: CGFloat = 12

        guard let ribbon = PathHighlightRibbon.path(
            lut: lut, from: 0, to: lut.totalLength, ascent: ascent, descent: descent,
            baselineOffset: 0, insideOut: false, overflow: .clip
        ) else {
            Issue.record("expected a non-nil ribbon")
            return
        }

        let pts = points(of: ribbon)
        // Geometry is `[top_0...top_n, bottom_n...bottom_0]` (closed) ،
        // `pts.count` is `2n` for `n` samples (no duplicate close point
        // from `applyWithBlock`, `closeSubpath` emits no point).
        #expect(pts.count.isMultiple(of: 2))
        let n = pts.count / 2
        for i in 0..<n {
            let top = pts[i]
            let bottom = pts[pts.count - 1 - i]
            let rung = CGVector(dx: top.x - bottom.x, dy: top.y - bottom.y)
            // Recover the sample's own arc length by nearest-point lookup
            // and confirm the rung is perpendicular to that point's
            // tangent (dot product ~ 0) ، this is what "stays
            // perpendicular on a curve" means geometrically.
            let s = lut.nearestLength(to: CGPoint(x: (top.x + bottom.x) / 2, y: (top.y + bottom.y) / 2))
            let tangent = lut.frame(atLength: s).tangent
            let dot = rung.dx * tangent.dx + rung.dy * tangent.dy
            #expect(abs(dot) < 0.5, "rung \(i) not perpendicular to tangent at s=\(s): dot=\(dot)")
        }
    }

    // MARK: - Endpoint guarantee

    @Test("Endpoint guarantee: on a low-curvature path (the adaptive walk's largest steps), the ribbon's first and last rungs land exactly at `from`/`to`, not wherever the angular-tolerance walk's own last step happens to stop")
    func rungsLandExactlyOnRequestedSpanOnLowCurvaturePath() {
        // `gentleArc` has genuine but gentle curvature ، low enough that
        // the adaptive walk's angular-tolerance criterion (`path(...)`'s
        // own `maxJoinAngleDegrees`) takes its LARGEST possible steps
        // before it ever needs to subdivide, which is exactly the
        // condition that maximizes an unguaranteed-endpoint bug (see
        // `path(...)`'s own "Endpoint guarantee" doc comment).
        let path = Fixtures.gentleArc(radius: 600)
        let lut = ArcLengthLUT(path: path)
        let ascent: CGFloat = 12
        let descent: CGFloat = 12
        // Interior span, well clear of both `0` and `lut.totalLength` (so
        // this pins down the walk's own endpoint behavior, not the
        // already-covered full-span/full-loop cases).
        let from: CGFloat = lut.totalLength * 0.2
        let to: CGFloat = lut.totalLength * 0.8

        guard let ribbon = PathHighlightRibbon.path(
            lut: lut, from: from, to: to, ascent: ascent, descent: descent,
            baselineOffset: 0, insideOut: false, overflow: .clip
        ) else {
            Issue.record("expected a non-nil ribbon")
            return
        }

        let pts = points(of: ribbon)
        #expect(pts.count.isMultiple(of: 2))
        let n = pts.count / 2
        let firstTop = pts[0]
        let firstBottom = pts[pts.count - 1]
        let lastTop = pts[n - 1]
        let lastBottom = pts[n]

        // Ground truth: `path(...)`'s own per-rung edge formula
        // (`insideOut == false`: top = `-ascent` along the normal, bottom
        // = `+descent`), evaluated directly at `from`/`to` via the SAME
        // `lut.frame(atLength:)` query `path(...)` itself must use for
        // its own first/last rung ، comparing against this (rather than
        // an independently-derived analytic point) isolates the
        // rung-emission guarantee this test exists to pin down from
        // `ArcLengthLUT`'s own separate numeric budget (a different
        // concern, covered by `ArcLengthLUTTests`).
        func expectedEdge(at s: CGFloat) -> (top: CGPoint, bottom: CGPoint) {
            let frame = lut.frame(atLength: s)
            let top = CGPoint(x: frame.point.x - frame.normal.dx * ascent, y: frame.point.y - frame.normal.dy * ascent)
            let bottom = CGPoint(x: frame.point.x + frame.normal.dx * descent, y: frame.point.y + frame.normal.dy * descent)
            return (top, bottom)
        }
        let expectedFirst = expectedEdge(at: from)
        let expectedLast = expectedEdge(at: to)

        #expect(hypot(firstTop.x - expectedFirst.top.x, firstTop.y - expectedFirst.top.y) < 0.01)
        #expect(hypot(firstBottom.x - expectedFirst.bottom.x, firstBottom.y - expectedFirst.bottom.y) < 0.01)
        #expect(hypot(lastTop.x - expectedLast.top.x, lastTop.y - expectedLast.top.y) < 0.01)
        #expect(hypot(lastBottom.x - expectedLast.bottom.x, lastBottom.y - expectedLast.bottom.y) < 0.01)
    }

    // MARK: - `.continueTangent` overflow extension

    @Test(".continueTangent overflow extends the ribbon straight past the path's own end")
    func continueTangentExtendsPastTotalLength() {
        let path = Fixtures.straightLine(length: 100)
        let lut = ArcLengthLUT(path: path)
        #expect(abs(lut.totalLength - 100) < 0.01)

        guard let ribbon = PathHighlightRibbon.path(
            lut: lut, from: 0, to: 200, ascent: 10, descent: 4,
            baselineOffset: 0, insideOut: false, overflow: .continueTangent
        ) else {
            Issue.record("expected a non-nil ribbon")
            return
        }
        // The straight path's exit tangent is `(1,0)` ، the ribbon must
        // extend all the way to x=200, not stop at the path's own x=100.
        #expect(abs(ribbon.boundingBoxOfPath.maxX - 200) < 0.01)
    }

    @Test(".clip overflow never extends past the path's own end even if `to` asks for it")
    func clipOverflowClampsAtTotalLength() {
        let path = Fixtures.straightLine(length: 100)
        let lut = ArcLengthLUT(path: path)

        guard let ribbon = PathHighlightRibbon.path(
            lut: lut, from: 0, to: 200, ascent: 10, descent: 4,
            baselineOffset: 0, insideOut: false, overflow: .clip
        ) else {
            Issue.record("expected a non-nil ribbon")
            return
        }
        #expect(abs(ribbon.boundingBoxOfPath.maxX - 100) < 0.01)
    }

    // MARK: - Closed-path full loop

    @Test("Closed path, full-loop span [0, totalLength]: first and last rungs coincide")
    func closedPathFullLoopCoincides() {
        let path = Fixtures.circle(radius: 300)
        let lut = ArcLengthLUT(path: path)

        guard let ribbon = PathHighlightRibbon.path(
            lut: lut, from: 0, to: lut.totalLength, ascent: 15, descent: 5,
            baselineOffset: 0, insideOut: false, overflow: .clip
        ) else {
            Issue.record("expected a non-nil ribbon")
            return
        }
        let pts = points(of: ribbon)
        let n = pts.count / 2
        let firstTop = pts[0]
        let lastTop = pts[n - 1]
        // Arc length 0 and `totalLength` are the SAME physical point on a
        // closed curve ، the ribbon's first and last "top" rungs must
        // coincide (closing the ring with no visible seam gap).
        #expect(hypot(firstTop.x - lastTop.x, firstTop.y - lastTop.y) < 1.0)
    }

    // MARK: - Degenerate inputs

    @Test("Zero-length path returns nil")
    func zeroLengthPathReturnsNil() {
        let path = BezierPathModel.line(from: CGPoint(x: 5, y: 5), to: CGPoint(x: 5, y: 5))
        let lut = ArcLengthLUT(path: path)
        let ribbon = PathHighlightRibbon.path(lut: lut, from: 0, to: 10, ascent: 10, descent: 4, baselineOffset: 0, insideOut: false, overflow: .clip)
        #expect(ribbon == nil)
    }

    @Test("Zero-length span returns nil")
    func zeroLengthSpanReturnsNil() {
        let path = Fixtures.straightLine(length: 500)
        let lut = ArcLengthLUT(path: path)
        let ribbon = PathHighlightRibbon.path(lut: lut, from: 50, to: 50, ascent: 10, descent: 4, baselineOffset: 0, insideOut: false, overflow: .clip)
        #expect(ribbon == nil)
    }
}
