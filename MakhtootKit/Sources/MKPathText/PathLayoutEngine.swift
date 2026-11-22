import CoreGraphics
import MKFoundation
import MKModel
import MKTextEngine

// WS-05 packet §5 task 4 (D-110's core algorithm) + task 8 (join-continuity
// mitigation) + task 5/6/7 (tracking, alignment/start-offset, baseline
// side/inside-out).
//
// **DF-6a note (governs this file, overriding the packet's own task 4a/4b
// prose).** The packet's task 4a/4b describe the pen order as "visual
// order (RTL-aware)" with an elaborate `flowDirection` (`rtlNatural` /
// `pathForward`) option computing arc position from
// `lineWidth − glyphVisualRightEdge(i)`. That naming was a corrected
// misnomer (DF-6a, `ARCHITECTURE.md` §9.4 / `TEST_MATRIX.md` T-PTH-2): the
// pen order is **LOGICAL READING ORDER**, not visual order ، "each bidi
// run advances in its own internal order (the RTL Arabic run
// right-to-left through its glyphs, LTR Latin/digit runs left-to-right
// through theirs), chained run-by-run in the paragraph's LOGICAL sequence"
// (T-PTH-2's own wording). This file implements exactly that, and drops
// the `flowDirection` option entirely ، there is one pen order, not two.
//
// **Implementation finding (not a deviation from DF-6a, a simplification
// of HOW to realize it).** `MKClusterMap.clusters` (`MKTextEngine
// /ClusterMap.swift`, WS03-A2) is *already* built by sorting every raw
// cluster ، from every run, across the whole line ، by UTF-16
// `utf16Range.lowerBound` ascending. UTF-16 offset IS the logical (typed)
// position in the source string, by definition, regardless of script
// direction. So walking `line.clusterMap.clusters` in its given array
// order is *already* exactly DF-6a's "logical reading order, chained
// run-by-run" sequence ، for a single RTL run this means increasing
// UTF-16 offset (= increasing typed position = "right-to-left through its
// own glyphs" in the run's *visual* sense, but that's just what "logical
// order within an RTL run" reduces to), and across runs it's a pure global
// sort, which automatically interleaves LTR/RTL sub-runs in typed
// sequence. No separate per-run reversal/re-chaining pass is needed ، one
// array walk realizes DF-6a directly, verified by
// `PathLayoutEngineTests.multiSwitchFixtureArcOffsetsMonotonic` (the
// packet's own "Hello سلام World ٤٥" / "الرقم٤٥" T-PTH-2 fixtures).
public enum PathLayoutEngine {
    /// Convenience overload: builds the `ArcLengthLUT` from `path` and
    /// delegates.
    public static func layout(
        line: MKShapedLine, lineIndex: Int = 0, path: BezierPathModel, options: PathLayoutOptions,
        userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [:]
    ) -> PathLayoutResult {
        layout(line: line, lineIndex: lineIndex, lut: ArcLengthLUT(path: path), options: options, userOffsets: userOffsets)
    }

    /// Core algorithm (task 4). All coordinates are in whatever space the
    /// caller's `lut`/`line` positions already share ، this function makes
    /// no assumption about y-up vs y-down (see `PathPlacementProvider
    /// .swift`'s file header for the one place that DOES need to reconcile
    /// two different conventions, the WS-04 arrange-on-path seam).
    public static func layout(
        line: MKShapedLine, lineIndex: Int = 0, lut: ArcLengthLUT, options: PathLayoutOptions,
        userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [:]
    ) -> PathLayoutResult {
        guard lut.totalLength > 0 else {
            // §9.6-style degenerate geometry: place everything at the
            // (single, coincident) path point with zero rotation rather
            // than crash or emit NaNs.
            let frame = lut.frame(atLength: 0)
            var placements: [PathGlyphPlacement] = []
            var occurrence: [String: Int] = [:]
            for cluster in line.clusterMap.clusters where cluster.kind != .control {
                let key = provenanceKey(for: cluster, occurrence: &occurrence)
                for address in cluster.glyphs {
                    placements.append(PathGlyphPlacement(
                        address: address, clusterID: cluster.id, provenanceKey: key,
                        arcLength: 0, position: frame.point, rotation: 0,
                        isMark: isMarkKind(cluster.kind)))
                }
            }
            return PathLayoutResult(placements: placements, overflow: .none, pathLength: 0, curvatureWarning: false, penStartArcLength: 0, penEndArcLength: 0)
        }

        let attachments = MKMarkAttacher.attachments(in: line)
        var attachmentByMarkCluster: [Int: MKMarkAttachment] = [:]
        for a in attachments { attachmentByMarkCluster[a.markClusterIndex] = a }

        let clusters = line.clusterMap.clusters

        // MARK: Pass 1 ، natural pen-advancing width, for alignment
        // (task 6) and justify spacing (task 5's spacingMode).
        //
        // Advances are used RAW (Core Text emits genuinely NEGATIVE
        // advances for some component glyphs inside a multi-glyph cluster
        // ، probed empirically: «الرقم» realizes ق as two glyphs with
        // advances −2.31 and +14.69 pt; clamping the negative one to 0
        // drifts the pen +2.31 pt off CT's own flat layout and broke the
        // no-space digit-adjacency contiguity gate on the first test run).
        // `letterSpacingExtra` and justify spacing apply BETWEEN CLUSTER
        // SPANS (the packet task 5's literal wording ، "applied between
        // cluster spans"), never between the component glyphs of one
        // cluster (which would pull a letter's own components apart).

        var penClusterCount = 0
        var naturalTotal: CGFloat = 0
        for cluster in clusters where !isMarkKind(cluster.kind) && cluster.kind != .control {
            penClusterCount += 1
            for address in cluster.glyphs {
                naturalTotal += line.runs[address.run].advances[address.glyph].width
            }
        }
        naturalTotal += CGFloat(options.letterSpacingExtra) * CGFloat(max(0, penClusterCount - 1))

        let availableSpan = lut.totalLength - CGFloat(options.startOffset)
        var extraPerCluster: CGFloat = 0
        if options.spacingMode == .justify, penClusterCount > 1, availableSpan > naturalTotal {
            extraPerCluster = (availableSpan - naturalTotal) / CGFloat(penClusterCount - 1)
        }
        let effectiveTotal = naturalTotal + extraPerCluster * CGFloat(max(0, penClusterCount - 1))

        let penStart: CGFloat
        switch options.alignment {
        case .start:
            penStart = CGFloat(options.startOffset)
        case .center:
            penStart = CGFloat(options.startOffset) + max(0, (availableSpan - effectiveTotal) / 2)
        case .end:
            penStart = CGFloat(options.startOffset) + max(0, availableSpan - effectiveTotal)
        }

        // MARK: Pass 2 ، single walk over `clusters` in (already-logical)
        // array order, building pen placements and mark placements
        // together so the output array stays in full traversal order.

        var placements: [PathGlyphPlacement] = []
        placements.reserveCapacity(clusters.count)
        var basePlacementByAddress: [MKGlyphAddress: PathGlyphPlacement] = [:]
        var occurrence: [String: Int] = [:]
        var cursor = penStart
        var emittedFirstPenCluster = false
        var previousChosenRotation: CGFloat?
        var curvatureWarning = false
        var overflowRange: Range<Int>?
        var overflowContinuedStraight = false

        for (clusterIndex, cluster) in clusters.enumerated() {
            switch cluster.kind {
            case .control:
                continue
            case .markOnly:
                guard let attachment = attachmentByMarkCluster[clusterIndex] else { continue }
                let key = provenanceKey(for: cluster, occurrence: &occurrence)
                if let baseAddress = attachment.baseGlyph, let base = basePlacementByAddress[baseAddress] {
                    let rotatedOffset = rotate(attachment.relativeOffsetOrZero, by: base.rotation)
                    let markAddress = attachment.markGlyph ?? baseAddress
                    var mark = PathGlyphPlacement(
                        address: markAddress, clusterID: cluster.id, provenanceKey: key,
                        arcLength: base.arcLength, position: CGPoint(x: base.position.x + rotatedOffset.x, y: base.position.y + rotatedOffset.y),
                        rotation: base.rotation, isMark: true, baseClusterID: base.clusterID)
                    if let userDelta = userOffsets[key] {
                        mark.userOffset = userDelta.offset
                        mark.userRotation = userDelta.rotation
                        let rotatedUser = rotate(userDelta.offset, by: mark.rotation)
                        mark.position.x += rotatedUser.x
                        mark.position.y += rotatedUser.y
                        mark.rotation += userDelta.rotation
                    }
                    placements.append(mark)
                } else {
                    // Free mark (§6.3): no preceding base ، place at the
                    // current pen cursor's frame rather than dropping it.
                    let s = lut.segmentCount > 0 ? min(max(cursor, 0), lut.totalLength) : 0
                    let frame = lut.frame(atLength: s)
                    let mark = PathGlyphPlacement(
                        address: attachment.markGlyph ?? MKGlyphAddress(run: 0, glyph: 0), clusterID: cluster.id, provenanceKey: key,
                        arcLength: s, position: frame.point, rotation: atan2(frame.tangent.dy, frame.tangent.dx), isMark: true)
                    placements.append(mark)
                }
            default:
                let key = provenanceKey(for: cluster, occurrence: &occurrence)
                if emittedFirstPenCluster {
                    // Between-cluster spacing (task 5 ، see the pass-1
                    // comment for why between clusters, not glyphs).
                    cursor += CGFloat(options.letterSpacingExtra) + extraPerCluster
                }
                emittedFirstPenCluster = true
                for address in cluster.glyphs {
                    // RAW advance, may be slightly negative for a
                    // component glyph ، see the pass-1 comment.
                    let advance = line.runs[address.run].advances[address.glyph].width
                    let spanStart = cursor
                    let spanEnd = cursor + advance
                    let mid = (spanStart + spanEnd) / 2
                    cursor = spanEnd

                    // Overflow (task 4e) ، this entry point is for OPEN
                    // paths; closed-path wrap is `layoutClosed` below.
                    var evalLength = mid
                    if mid > lut.totalLength {
                        switch options.overflow {
                        case .clip:
                            if overflowRange == nil {
                                overflowRange = cluster.utf16Range
                            } else if let existing = overflowRange {
                                overflowRange = existing.lowerBound..<max(existing.upperBound, cluster.utf16Range.upperBound)
                            }
                            continue
                        case .continueTangent:
                            overflowContinuedStraight = true
                            if overflowRange == nil {
                                overflowRange = cluster.utf16Range
                            } else if let existing = overflowRange {
                                overflowRange = existing.lowerBound..<max(existing.upperBound, cluster.utf16Range.upperBound)
                            }
                            evalLength = lut.totalLength
                        }
                    }

                    let midFrame = lut.frame(atLength: min(max(evalLength, 0), lut.totalLength))
                    var rotationSource = midFrame.tangent
                    if evalLength <= lut.totalLength, mid <= lut.totalLength {
                        let startFrame = lut.frame(atLength: min(max(spanStart, 0), lut.totalLength))
                        let endFrame = lut.frame(atLength: min(max(spanEnd, 0), lut.totalLength))
                        let deltaWithinGlyph = angleDegrees(between: startFrame.tangent, and: endFrame.tangent)
                        if deltaWithinGlyph > CGFloat(options.maxJoinAngleDegrees) {
                            rotationSource = averageDirection(startFrame.tangent, endFrame.tangent)
                        }
                    }
                    var straightExtension = CGPoint.zero
                    if evalLength != mid {
                        // `.continueTangent` overflow: extend straight
                        // along the exit tangent past the path's end.
                        let extra = mid - evalLength
                        straightExtension = CGPoint(x: rotationSource.dx * extra, y: rotationSource.dy * extra)
                    }

                    var rotation = atan2(rotationSource.dy, rotationSource.dx)
                    if options.insideOut { rotation += .pi }
                    if let previousChosenRotation {
                        let delta = angleDegrees(between: CGVector(dx: cos(previousChosenRotation), dy: sin(previousChosenRotation)),
                                                  and: CGVector(dx: cos(rotation), dy: sin(rotation)))
                        if delta > CGFloat(options.curvatureWarningThresholdDegrees) { curvatureWarning = true }
                    }
                    previousChosenRotation = rotation

                    let normal = midFrame.normal
                    let baselineShift = CGFloat(options.signedBaselineOffset)
                    var position = CGPoint(
                        x: midFrame.point.x + straightExtension.x + normal.dx * baselineShift,
                        y: midFrame.point.y + straightExtension.y + normal.dy * baselineShift)

                    var placement = PathGlyphPlacement(
                        address: address, clusterID: cluster.id, provenanceKey: key,
                        arcLength: mid, position: position, rotation: rotation, isMark: false)

                    if let userDelta = userOffsets[key] {
                        placement.userOffset = userDelta.offset
                        placement.userRotation = userDelta.rotation
                        let rotatedUser = rotate(userDelta.offset, by: placement.rotation)
                        position.x += rotatedUser.x
                        position.y += rotatedUser.y
                        placement.position = position
                        placement.rotation += userDelta.rotation
                    }

                    basePlacementByAddress[address] = placement
                    placements.append(placement)
                }
            }
        }

        let overflow = OverflowInfo(
            isOverflowing: overflowRange != nil,
            overflowUTF16Range: overflowRange,
            continuedStraight: overflowContinuedStraight)

        return PathLayoutResult(
            placements: placements, overflow: overflow, pathLength: lut.totalLength, curvatureWarning: curvatureWarning,
            penStartArcLength: penStart, penEndArcLength: penStart + effectiveTotal)
    }

    // MARK: - Closed-path entry point (task 4e closed-path wrap)

    /// Same algorithm, but arc length wraps modulo `totalLength +
    /// closedPathGap` (task 4e: "closed path → wrap modulo length with
    /// optional gap"). Kept as a distinct entry point (rather than
    /// inferring closedness from the LUT) because the open-path algorithm
    /// above already has to reason about `mid > totalLength` as
    /// *overflow*; a closed path's "overflow" is instead a wrap, a
    /// different code path entirely ، mixing the two into one branchy
    /// function was worse for both readability and testability than two
    /// clearly-named entry points sharing every other helper.
    public static func layoutClosed(
        line: MKShapedLine, lineIndex: Int = 0, lut: ArcLengthLUT, options: PathLayoutOptions,
        userOffsets: [PathClusterProvenanceKey: PathGlyphUserOffset] = [:]
    ) -> PathLayoutResult {
        guard lut.totalLength > 0 else {
            return layout(line: line, lineIndex: lineIndex, lut: lut, options: options, userOffsets: userOffsets)
        }
        let cycleLength = lut.totalLength + CGFloat(options.closedPathGap)
        func wrap(_ s: CGFloat) -> CGFloat {
            guard cycleLength > 0 else { return 0 }
            // `max(0, s)`: a component glyph's slightly-negative raw
            // advance (see `layout`'s pass-1 comment) can pull the pen a
            // fraction of a point below the start ، wrapping that to
            // `cycleLength − ε` would teleport the glyph to the far end
            // of the loop for a sub-point artifact, so negative pen
            // values clamp to the start instead of wrapping backward.
            var w = max(0, s).truncatingRemainder(dividingBy: cycleLength)
            if w < 0 { w += cycleLength }
            return min(w, lut.totalLength)
        }

        let attachments = MKMarkAttacher.attachments(in: line)
        var attachmentByMarkCluster: [Int: MKMarkAttachment] = [:]
        for a in attachments { attachmentByMarkCluster[a.markClusterIndex] = a }
        let clusters = line.clusterMap.clusters

        let penStart = CGFloat(options.startOffset)
        var placements: [PathGlyphPlacement] = []
        var basePlacementByAddress: [MKGlyphAddress: PathGlyphPlacement] = [:]
        var occurrence: [String: Int] = [:]
        var cursor = penStart
        var emittedFirstPenCluster = false
        var previousChosenRotation: CGFloat?
        var curvatureWarning = false

        for (clusterIndex, cluster) in clusters.enumerated() {
            switch cluster.kind {
            case .control:
                continue
            case .markOnly:
                guard let attachment = attachmentByMarkCluster[clusterIndex] else { continue }
                let key = provenanceKey(for: cluster, occurrence: &occurrence)
                if let baseAddress = attachment.baseGlyph, let base = basePlacementByAddress[baseAddress] {
                    let rotatedOffset = rotate(attachment.relativeOffsetOrZero, by: base.rotation)
                    let markAddress = attachment.markGlyph ?? baseAddress
                    placements.append(PathGlyphPlacement(
                        address: markAddress, clusterID: cluster.id, provenanceKey: key,
                        arcLength: base.arcLength, position: CGPoint(x: base.position.x + rotatedOffset.x, y: base.position.y + rotatedOffset.y),
                        rotation: base.rotation, isMark: true, baseClusterID: base.clusterID))
                } else {
                    let s = wrap(cursor)
                    let frame = lut.frame(atLength: s)
                    placements.append(PathGlyphPlacement(
                        address: attachment.markGlyph ?? MKGlyphAddress(run: 0, glyph: 0), clusterID: cluster.id, provenanceKey: key,
                        arcLength: s, position: frame.point, rotation: atan2(frame.tangent.dy, frame.tangent.dx), isMark: true))
                }
            default:
                let key = provenanceKey(for: cluster, occurrence: &occurrence)
                if emittedFirstPenCluster {
                    cursor += CGFloat(options.letterSpacingExtra)
                }
                emittedFirstPenCluster = true
                for address in cluster.glyphs {
                    // RAW advance, may be slightly negative for a
                    // component glyph ، see `layout`'s pass-1 comment.
                    let advance = line.runs[address.run].advances[address.glyph].width
                    let spanStart = cursor
                    let mid = cursor + advance / 2
                    cursor += advance

                    let wrappedStart = wrap(spanStart)
                    let wrappedMid = wrap(mid)
                    let wrappedEnd = wrap(cursor)

                    let midFrame = lut.frame(atLength: wrappedMid)
                    var rotationSource = midFrame.tangent
                    let startFrame = lut.frame(atLength: wrappedStart)
                    let endFrame = lut.frame(atLength: wrappedEnd)
                    let deltaWithinGlyph = angleDegrees(between: startFrame.tangent, and: endFrame.tangent)
                    if deltaWithinGlyph > CGFloat(options.maxJoinAngleDegrees), deltaWithinGlyph < 170 {
                        rotationSource = averageDirection(startFrame.tangent, endFrame.tangent)
                    }
                    var rotation = atan2(rotationSource.dy, rotationSource.dx)
                    if options.insideOut { rotation += .pi }
                    if let previousChosenRotation {
                        let delta = angleDegrees(
                            between: CGVector(dx: cos(previousChosenRotation), dy: sin(previousChosenRotation)),
                            and: CGVector(dx: cos(rotation), dy: sin(rotation)))
                        if delta > CGFloat(options.curvatureWarningThresholdDegrees) { curvatureWarning = true }
                    }
                    previousChosenRotation = rotation

                    let normal = midFrame.normal
                    let baselineShift = CGFloat(options.signedBaselineOffset)
                    var position = CGPoint(x: midFrame.point.x + normal.dx * baselineShift, y: midFrame.point.y + normal.dy * baselineShift)

                    var placement = PathGlyphPlacement(
                        address: address, clusterID: cluster.id, provenanceKey: key,
                        arcLength: wrappedMid, position: position, rotation: rotation, isMark: false)
                    if let userDelta = userOffsets[key] {
                        placement.userOffset = userDelta.offset
                        placement.userRotation = userDelta.rotation
                        let rotatedUser = rotate(userDelta.offset, by: placement.rotation)
                        position.x += rotatedUser.x
                        position.y += rotatedUser.y
                        placement.position = position
                        placement.rotation += userDelta.rotation
                    }
                    basePlacementByAddress[address] = placement
                    placements.append(placement)
                }
            }
        }

        // `cursor`'s final value here is the UNWRAPPED cumulative pen
        // position (task 9e's own per-glyph `wrap(...)` calls only clamp
        // each SAMPLE point, never the running `cursor` itself) ، exactly
        // the "penEnd" a highlight ribbon needs to tell whether the laid
        // text wraps the full loop (`penEnd − penStart >= lut.totalLength`)
        // or only a partial arc, see `PathHighlightRibbon`'s doc comment.
        return PathLayoutResult(
            placements: placements, overflow: .none, pathLength: lut.totalLength, curvatureWarning: curvatureWarning,
            penStartArcLength: penStart, penEndArcLength: cursor)
    }

    // MARK: - Small pure helpers

    static func isMarkKind(_ kind: MKCluster.Kind) -> Bool {
        if case .markOnly = kind { return true }
        return false
    }

    /// Task 9's stable carry-over key: codepoints + occurrence ordinal
    /// among clusters sharing the exact same codepoint sequence, scanned
    /// in traversal order.
    static func provenanceKey(for cluster: MKCluster, occurrence: inout [String: Int]) -> PathClusterProvenanceKey {
        let codepoints = cluster.codepoints
        let bucketKey = codepoints.map(String.init).joined(separator: ",")
        let ordinal = occurrence[bucketKey, default: 0]
        occurrence[bucketKey] = ordinal + 1
        return PathClusterProvenanceKey(codepoints: codepoints, occurrenceOrdinal: ordinal)
    }

    static func rotate(_ v: CGPoint, by angle: CGFloat) -> CGPoint {
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: v.x * c - v.y * s, y: v.x * s + v.y * c)
    }

    static func angleDegrees(between a: CGVector, and b: CGVector) -> CGFloat {
        let angleA = atan2(a.dy, a.dx)
        let angleB = atan2(b.dy, b.dx)
        var delta = (angleB - angleA) * 180 / .pi
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return abs(delta)
    }

    /// Normalized average of two direction vectors; falls back to `a` if
    /// they're near-opposite (sum ≈ zero ، a genuine 180° cusp, where
    /// "average direction" is undefined) rather than producing a
    /// zero-magnitude/NaN result.
    static func averageDirection(_ a: CGVector, _ b: CGVector) -> CGVector {
        let sx = a.dx + b.dx
        let sy = a.dy + b.dy
        let mag = hypot(sx, sy)
        guard mag > 1e-6 else { return a }
        return CGVector(dx: sx / mag, dy: sy / mag)
    }
}

private extension MKMarkAttachment {
    var relativeOffsetOrZero: CGPoint {
        guard let o = relativeOffset else { return .zero }
        return CGPoint(x: o.width, y: o.height)
    }
}
