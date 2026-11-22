import CoreGraphics
import MKModel

// Path-text highlight painting (render + export). Pure geometry only ، no
// `CGContext` ، so this is unit-testable directly and, per its own design
// note, SHARED by `MKRender/Drawers/PathTextDrawer.swift` and (separately,
// out of this task's fence) `MKExport`'s path-text export path, rather than
// becoming a fifth silently-drifting copy of "walk an `ArcLengthLUT` and
// build glyph-adjacent geometry" (the repo already has four: this engine's
// own per-glyph placement math, `PathPlacementProvider`'s arrange-on-path
// seam, `HitTester.pathProximity`'s stand-in sampler, and
// `PathEditModel.insertAnchor`'s split-point math).
//
// **Why one contiguous ribbon is correct for ANY bidi mix (the crux of this
// design, not an implementation detail):** `MKTextStyle.highlightColor`
// (`MKModel/MKTextStyle.swift:91`) is ONE optional color per node ، there
// is no ranged/per-run highlight in the model at all. And
// `PathLayoutEngine.layout`/`layoutClosed` walk `line.clusterMap.clusters`
// in LOGICAL order (pre-sorted by UTF-16 `lowerBound`), advancing the pen
// monotonically with no direction-switch special-casing
// (`PathLayoutEngine.swift`'s own file-header note, lines ~10-39). So arc
// length is monotonic in logical order **regardless of script direction**
// ، locked by `MKPathTextTests/PathLayoutEngineTests.swift`'s
// `mixedBidiContiguous` and `multiSwitchFixtureArcOffsetsMonotonic` tests.
// One ribbon over `[penStart, penEnd]` therefore covers every glyph
// exactly once, no gaps, no double-cover, for any bidi mix. This is
// UNLIKE live text, where `LiveTextDrawer` draws `line.runs` in VISUAL
// order, so a single logical highlight range can be visually split into
// disjoint rects ، a hazard that simply cannot arise here because path
// text has no "visual order" distinct from the pen's own arc-length walk.
public enum PathHighlightRibbon {

    /// Builds the swept-ribbon `CGPath` covering arc length span
    /// `[from, to]` (order-independent; `nil` for a degenerate/zero-length
    /// span or a zero-length path). Both `from` and `to` may exceed
    /// `lut.totalLength` under `.continueTangent` overflow ، see that
    /// case's own handling below.
    ///
    /// - Parameters:
    ///   - ascent/descent: the shaped line's own `MKLineMetrics` (the SAME
    ///     values `PathTextDrawer` already reads off `engine
    ///     .shapeSingleLine(...)` for every glyph's own vertical extent),
    ///     not a font's whole-font metrics.
    ///   - baselineOffset: pass `PathLayoutOptions.signedBaselineOffset`
    ///     VERBATIM ، do not re-derive `side`/`baselineOffsetMagnitude`/
    ///     `insideOut` into your own offset number here, or this ribbon
    ///     can silently drift from `PathLayoutEngine`'s own placement math
    ///     the next time that resolution logic changes in one place and
    ///     not the other.
    ///   - insideOut: needed SEPARATELY from `baselineOffset`, even though
    ///     `signedBaselineOffset` already folds `insideOut` into its own
    ///     sign. Working through `PathTextDrawer`'s own glyph-draw
    ///     composition (`translate(position) → rotate(rotation) →
    ///     scale(1,-1) → CTFontDrawGlyphs`) shows a glyph's own ascent
    ///     direction in world space is `-frame.normal` when
    ///     `rotation == tangent angle` (`insideOut == false`) but
    ///     `+frame.normal` once `insideOut` adds its extra `+π` to every
    ///     glyph's rotation (negating the mapped direction). Hardcoding
    ///     one sign here would make the ribbon hug the WRONG side of the
    ///     glyphs' own ascent/descent for whichever `insideOut` state
    ///     wasn't the one this file was written against ، verified by
    ///     `PathHighlightRibbonTests.insideOutFlipsExtent`.
    ///   - overflow: `.continueTangent` extends the ribbon in a straight
    ///     line past `lut.totalLength` along the exit tangent, mirroring
    ///     `PathLayoutEngine.swift`'s own per-glyph `straightExtension`
    ///     (the "Pass 2" `evalLength != mid` branch). `.clip` clamps `to`
    ///     at `lut.totalLength` here as a DEFENSIVE second clamp ، the
    ///     primary one is the caller's: `PathTextDrawer` is expected to
    ///     have already resolved `to` down to the last actually-emitted
    ///     placement's own span end for `.clip` (a clipped glyph produced
    ///     NO placement at all, per `OverflowInfo`, so the ribbon must
    ///     stop where the glyphs actually stopped, not at the path's own
    ///     geometric end).
    ///   - maxJoinAngleDegrees: the SAME per-glyph rotation-smoothing knob
    ///     `PathLayoutOptions.maxJoinAngleDegrees` already governs
    ///     (`PathLayoutEngine.swift`'s join-continuity mitigation) ،
    ///     reusing it here (instead of inventing a fixed sampling step)
    ///     means the ribbon can never look "chunkier" or "smoother" than
    ///     the glyph rotations it exists to back.
    public static func path(
        lut: ArcLengthLUT,
        from: CGFloat,
        to: CGFloat,
        ascent: CGFloat,
        descent: CGFloat,
        baselineOffset: CGFloat,
        insideOut: Bool,
        overflow: PathOverflowPolicy,
        maxJoinAngleDegrees: Double = 25
    ) -> CGPath? {
        guard lut.totalLength > 0 else { return nil }
        let sStart = max(0, min(from, to))
        let sEnd = max(from, to)
        guard sEnd > sStart else { return nil }

        // On-curve portion: [sStart, curveEnd] ، adaptively subdivided so
        // consecutive rungs never disagree in tangent by more than
        // `maxJoinAngleDegrees`. `.clip` is enforced right here via this
        // `min(..., lut.totalLength)`, independent of the `overflow`
        // branch below (which only ever ADDS an extension rung, never
        // removes the clamp).
        let curveEnd = min(sEnd, lut.totalLength)

        // Endpoint guarantee: the emitted rung list must begin at EXACTLY
        // `sStart` and end at EXACTLY `curveEnd` (further extended to
        // exactly `sEnd` below under `.continueTangent`), regardless of
        // where the adaptive walk's own interior steps land ، a ribbon
        // that starts or ends wherever the angular-tolerance criterion
        // happened to take its last step, instead of precisely at the
        // requested span, visibly detaches from the glyphs' own pen span
        // on low-curvature paths where that step is largest (see this
        // function's own doc comment; `PathHighlightRibbonTests
        // .rungsLandExactlyOnRequestedSpanOnLowCurvaturePath` pins this
        // down directly). `sStart` is seeded unconditionally up front;
        // `curveEnd`/`sEnd` are appended (or, if the walk's own last
        // sample is already there, snapped onto exactly rather than
        // duplicated ، see `appendEndpoint`'s own doc comment) below.
        var samples: [CGFloat] = [sStart]
        if sStart < curveEnd {
            // `subdivide` itself already starts at `sStart` (its own `a`)
            // ، drop that duplicate leading value, since it was just
            // seeded above.
            samples.append(contentsOf: subdivide(lut: lut, from: sStart, to: curveEnd, maxJoinAngleDegrees: maxJoinAngleDegrees).dropFirst())
            appendEndpoint(curveEnd, to: &samples)
        }
        // else: entire span sits at/after the path's own end (e.g. a
        // large `startOffset` on a very short path under
        // `.continueTangent`) ، `samples` stays `[sStart]`; the extension
        // branch below appends `sEnd`, giving the required 2-point
        // straight rung.

        if overflow == .continueTangent, sEnd > lut.totalLength {
            appendEndpoint(sEnd, to: &samples)
        }
        guard samples.count >= 2 else { return nil }

        let insideOutSign: CGFloat = insideOut ? 1 : -1
        var tops: [CGPoint] = []
        var bottoms: [CGPoint] = []
        tops.reserveCapacity(samples.count)
        bottoms.reserveCapacity(samples.count)
        for s in samples {
            let edge = edgePoints(
                lut: lut, at: s, ascent: ascent, descent: descent,
                baselineOffset: baselineOffset, insideOutSign: insideOutSign)
            tops.append(edge.top)
            bottoms.append(edge.bottom)
        }

        let cgPath = CGMutablePath()
        cgPath.move(to: tops[0])
        for p in tops.dropFirst() { cgPath.addLine(to: p) }
        for p in bottoms.reversed() { cgPath.addLine(to: p) }
        cgPath.closeSubpath()
        return cgPath
    }

    // MARK: - Endpoint guarantee

    /// Appends `target` to `samples` UNLESS the last emitted rung is
    /// already (numerically) at `target`, in which case it snaps that
    /// last rung to the exact value in place instead of appending a
    /// second, near-coincident one ، guards against a near-zero-length
    /// final span producing two coincident rungs, which would create a
    /// degenerate (zero-area) quad segment at the ribbon's own end.
    private static func appendEndpoint(_ target: CGFloat, to samples: inout [CGFloat]) {
        if let last = samples.last, abs(last - target) < 1e-6 {
            samples[samples.count - 1] = target
        } else {
            samples.append(target)
        }
    }

    // MARK: - Adaptive sampling

    /// Recursively bisects `[a, b]` until every consecutive pair of
    /// samples' tangents differ by no more than `maxJoinAngleDegrees`
    /// (reusing `PathLayoutEngine.angleDegrees`, task 8's own per-glyph
    /// join-continuity threshold), or a depth cap is hit ، a genuine
    /// cusp/near-180° corner (e.g. `Fixtures.sharpCorner()`) would
    /// otherwise recurse toward the bisection's floating-point limit;
    /// `PathLayoutEngine.averageDirection` has an analogous near-180°
    /// fallback for the same reason. Returns a strictly increasing array
    /// starting at `a` and ending at `b`.
    static func subdivide(lut: ArcLengthLUT, from a: CGFloat, to b: CGFloat, maxJoinAngleDegrees: Double) -> [CGFloat] {
        var result: [CGFloat] = [a]
        recurse(lut: lut, from: a, to: b, maxJoinAngleDegrees: maxJoinAngleDegrees, depth: 0, into: &result)
        return result
    }

    private static func recurse(
        lut: ArcLengthLUT, from a: CGFloat, to b: CGFloat, maxJoinAngleDegrees: Double, depth: Int, into result: inout [CGFloat]
    ) {
        let tangentA = lut.frame(atLength: a).tangent
        let tangentB = lut.frame(atLength: b).tangent
        let delta = PathLayoutEngine.angleDegrees(between: tangentA, and: tangentB)
        if delta > CGFloat(maxJoinAngleDegrees), depth < 14, (b - a) > 0.01 {
            let mid = (a + b) / 2
            recurse(lut: lut, from: a, to: mid, maxJoinAngleDegrees: maxJoinAngleDegrees, depth: depth + 1, into: &result)
            recurse(lut: lut, from: mid, to: b, maxJoinAngleDegrees: maxJoinAngleDegrees, depth: depth + 1, into: &result)
        } else {
            result.append(b)
        }
    }

    // MARK: - Per-rung geometry

    /// One rung's `(top, bottom)` edge points at arc length `s`. `s` may
    /// exceed `lut.totalLength` (`.continueTangent` extension only): in
    /// that case the frame is the CLAMPED exit frame walked further along
    /// its own (now-fixed) tangent by `s - lut.totalLength`, exactly
    /// mirroring `PathLayoutEngine.swift`'s per-glyph `straightExtension`
    /// (the `evalLength != mid` branch in "Pass 2").
    ///
    /// `top` is the glyphs' own ascent-side edge, `bottom` the
    /// descent-side edge ، see `insideOutSign`'s derivation in this
    /// function's caller-facing doc comment above (`path(...)`'s
    /// `insideOut` parameter).
    private static func edgePoints(
        lut: ArcLengthLUT, at s: CGFloat, ascent: CGFloat, descent: CGFloat,
        baselineOffset: CGFloat, insideOutSign: CGFloat
    ) -> (top: CGPoint, bottom: CGPoint) {
        let frame: (point: CGPoint, tangent: CGVector, normal: CGVector)
        if s <= lut.totalLength {
            frame = lut.frame(atLength: s)
        } else {
            let exit = lut.frame(atLength: lut.totalLength)
            let extra = s - lut.totalLength
            let point = CGPoint(x: exit.point.x + exit.tangent.dx * extra, y: exit.point.y + exit.tangent.dy * extra)
            frame = (point, exit.tangent, exit.normal)
        }
        let top = CGPoint(
            x: frame.point.x + frame.normal.dx * (insideOutSign * ascent + baselineOffset),
            y: frame.point.y + frame.normal.dy * (insideOutSign * ascent + baselineOffset))
        let bottom = CGPoint(
            x: frame.point.x + frame.normal.dx * (-insideOutSign * descent + baselineOffset),
            y: frame.point.y + frame.normal.dy * (-insideOutSign * descent + baselineOffset))
        return (top, bottom)
    }
}
