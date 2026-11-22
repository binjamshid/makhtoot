import CoreGraphics
import CoreText
import MKFoundation
import MKModel
import MKPathText
import MKTextEngine

// WS-07 packet §5 task 2 (`PathTextDrawer`). Originally a P4-scoped
// STAND-IN (self-contained polyline arc-length sampler, `MKPolylineArcLength`
// below) because `MKPathText` (WS-05, P7) didn't exist yet ، PLAN.md P4's
// own scope note ("Scope out... path text (P7)"). WS-05 has since shipped
// the real engine (`ArcLengthLUT` + `PathLayoutEngine`, D-110, published in
// `CONTRACTS.md`'s "WS-05 (`MKPathText`)" section and
// `Sources/MKPathText/README.md`'s "Seam WS-07 should adopt" note); this
// drawer now adopts it directly, per that note's exact adoption steps.
// `MKPolylineArcLength` itself is NOT removed ، `HitTester.pathProximity`
// still uses it for its own, separate stand-in reason (see that file); only
// this drawer's call site changed.
public struct PathTextDrawer: Sendable {
    private let fonts: any MKFontProviding
    private let engine: MKShapingEngine

    public init(fonts: any MKFontProviding = SystemFontStubProvider()) {
        self.fonts = fonts
        self.engine = MKShapingEngine(fonts: fonts)
    }

    public func draw(
        _ node: MKPathTextNode, into ctx: CGContext, quality: MKRenderQuality, report: inout MKRenderReportBuilder
    ) {
        guard !node.text.string.isEmpty else { return }
        let pathModel = BezierPathModel(node.path)
        let lut = ArcLengthLUT(path: pathModel)
        guard lut.totalLength > 0 else {
            report.recordSubstitution(nodeID: node.core.id, kind: .missingAsset, detail: "path text on a zero-length/degenerate path ، drawn at path start with no rotation")
            drawFallbackAtOrigin(node, into: ctx)
            return
        }

        let request = MKShapingRequest(text: node.text, style: node.style, frame: .singleLine)
        let line = engine.shapeSingleLine(request)

        if case .solid(let color) = node.core.style.fill {
            ctx.setFillColor(color.cgColor)
        }

        let options = PathLayoutOptions(node: node.layout)
        // P14 hardening pass (docs/impl-log/WS-07-p14-run3.md, item 2):
        // `pathRelayout` was declared in `MKRenderSignpost` (task 13) since
        // this drawer's own P4 pass, but never wired at the one call site
        // that actually performs a path relayout ، closing that gap.
        let result = MKRenderSignposts.interval(.pathRelayout) {
            node.path.isClosed
                ? PathLayoutEngine.layoutClosed(line: line, lut: lut, options: options)
                : PathLayoutEngine.layout(line: line, lut: lut, options: options)
        }

        // Highlight ribbon (path-text highlight painting): paints BEHIND
        // the glyph runs, mirroring `LiveTextDrawer.swift`'s own documented
        // ordering contract (`LiveTextDrawer.paintHighlight`'s call site,
        // "highlight paints behind the glyph runs and BEFORE the node's
        // own shadow is set, so a highlighted run's shadow falls on the
        // TEXT only, not on the highlight itself"). `PathTextDrawer` has no
        // per-node shadow handling of its own (unlike `LiveTextDrawer`),
        // so the only ordering requirement left is "behind the glyphs,"
        // satisfied by painting here, before the glyph loop below.
        if let highlight = node.style.highlightColor {
            paintHighlight(highlight, line: line, lut: lut, options: options, result: result, isClosed: node.path.isClosed, into: ctx)
        }

        for placement in result.placements {
            let run = line.runs[placement.address.run]
            let ctFont = fonts.resolve(MKFontHandle(postScriptName: run.font.postScriptName, pointSize: run.font.pointSize))
            var glyphs = [run.glyphs[placement.address.glyph]]
            var positions = [CGPoint.zero]
            ctx.saveGState()
            ctx.translateBy(x: placement.position.x, y: placement.position.y)
            ctx.rotate(by: placement.rotation)
            ctx.scaleBy(x: 1, y: -1)   // CoreText-native y-up glyph space, see LiveTextDrawer's convention note
            CTFontDrawGlyphs(ctFont, &glyphs, &positions, 1, ctx)
            ctx.restoreGState()
        }
    }

    /// Builds and fills the swept-ribbon highlight (`PathHighlightRibbon`,
    /// `MKPathText`) over `result`'s pen span.
    ///
    /// **COORDINATE-SPACE WARNING (matches this file's own `draw` glyph
    /// loop, do not "fix" only one of the two):** path-text geometry
    /// (`placement.position`/`result.penStartArcLength`/`.penEndArcLength`,
    /// all derived from `lut`) is baked in ABSOLUTE CANVAS coordinates,
    /// while `node.core.transform.position` stays `.zero`
    /// (`EditorViewModel.addPathText`'s own `at: .zero` default, confirmed
    /// correct by that method's doc comment referencing this very file).
    /// This is a known OPEN DEFECT (rotate/scale pivot about the canvas
    /// origin instead of the node's own local origin, not this task's to
    /// fix). The highlight ribbon is built here in PLACEMENT space ، the
    /// exact same space the glyph loop above already draws in ، and must
    /// NEVER be re-based into node-local box space (e.g. via
    /// `MKNodeLocalBounds`). If a later fix moves glyph placement into
    /// local space, this ribbon must move with it in the SAME change; if
    /// only one of the two moves, the highlight visibly detaches from its
    /// glyphs the instant the node rotates or scales.
    ///
    /// **GState trap:** `draw(...)` above sets the glyph fill color
    /// (`ctx.setFillColor(color.cgColor)`, this file's own `:43-45`)
    /// BEFORE the glyph loop. This function sets its OWN fill color for
    /// the highlight, so it must save/restore GState around that so the
    /// glyph loop's fill color is untouched afterward ، see
    /// `PathTextHighlightTests` (`MKRenderTests`) for the pixel-level
    /// regression this trap protects against.
    private func paintHighlight(
        _ color: MKSolidColor, line: MKShapedLine, lut: ArcLengthLUT, options: PathLayoutOptions,
        result: PathLayoutResult, isClosed: Bool, into ctx: CGContext
    ) {
        guard lut.totalLength > 0 else { return }
        let ascent = line.typographicBounds.ascent
        let descent = line.typographicBounds.descent
        let baselineOffset = CGFloat(options.signedBaselineOffset)

        let combined = CGMutablePath()

        if isClosed {
            // Closed-path wrap (task 4e): `result.penStartArcLength`/
            // `.penEndArcLength` are the UNWRAPPED cumulative pen values
            // (see `PathLayoutEngine.layoutClosed`'s own doc comment on
            // its return statement) ، resolve them against the cycle
            // here, the same way `layoutClosed`'s own per-glyph `wrap(_:)`
            // does.
            let cycleLength = lut.totalLength + CGFloat(options.closedPathGap)
            let effectiveTotal = result.penEndArcLength - result.penStartArcLength
            if cycleLength <= 0 || effectiveTotal >= lut.totalLength {
                // The laid text wraps the full loop (or more) ، a wrapped
                // partial span would be meaningless (or would double-cover
                // the ring); emit the whole closed curve once instead.
                if let ring = PathHighlightRibbon.path(
                    lut: lut, from: 0, to: lut.totalLength, ascent: ascent, descent: descent,
                    baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: .clip
                ) {
                    combined.addPath(ring)
                }
            } else {
                let wrappedStart = Self.wrapClosedArcLength(result.penStartArcLength, cycleLength: cycleLength, totalLength: lut.totalLength)
                let wrappedEnd = Self.wrapClosedArcLength(result.penEndArcLength, cycleLength: cycleLength, totalLength: lut.totalLength)
                if wrappedStart <= wrappedEnd {
                    if let seg = PathHighlightRibbon.path(
                        lut: lut, from: wrappedStart, to: wrappedEnd, ascent: ascent, descent: descent,
                        baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: .clip
                    ) {
                        combined.addPath(seg)
                    }
                } else {
                    // The span crosses the loop's seam (wraps past the
                    // cycle's own end back to its start) ، two contiguous
                    // sub-ribbons, unioned into one path.
                    if let seg1 = PathHighlightRibbon.path(
                        lut: lut, from: wrappedStart, to: lut.totalLength, ascent: ascent, descent: descent,
                        baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: .clip
                    ) {
                        combined.addPath(seg1)
                    }
                    if let seg2 = PathHighlightRibbon.path(
                        lut: lut, from: 0, to: wrappedEnd, ascent: ascent, descent: descent,
                        baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: .clip
                    ) {
                        combined.addPath(seg2)
                    }
                }
            }
        } else {
            var penEnd = result.penEndArcLength
            if options.overflow == .clip, result.overflow.isOverflowing {
                // `.clip`: a glyph past `lut.totalLength` produced NO
                // placement at all (`PathLayoutEngine.layout`'s own
                // `.clip` branch `continue`s past it), so the theoretical
                // full pen span (`result.penEndArcLength`) can overstate
                // where the glyphs actually stopped. Clamp to the last
                // ACTUALLY EMITTED placement's own span end instead.
                var lastSpanEnd = result.penStartArcLength
                for placement in result.placements where !placement.isMark {
                    let advance = line.runs[placement.address.run].advances[placement.address.glyph].width
                    lastSpanEnd = max(lastSpanEnd, placement.arcLength + advance / 2)
                }
                penEnd = lastSpanEnd
            }
            if let ribbon = PathHighlightRibbon.path(
                lut: lut, from: result.penStartArcLength, to: penEnd, ascent: ascent, descent: descent,
                baselineOffset: baselineOffset, insideOut: options.insideOut, overflow: options.overflow
            ) {
                combined.addPath(ribbon)
            }
        }

        guard !combined.isEmpty else { return }
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.addPath(combined)
        ctx.fillPath(using: .winding)
        ctx.restoreGState()
    }

    /// Mirrors `PathLayoutEngine.layoutClosed`'s own private `wrap(_:)`
    /// exactly (duplicated here rather than exposed across the module
    /// boundary, since it's a 3-line arithmetic primitive): negative/
    /// gap-region values clamp to the path's own start/end rather than
    /// wrapping backward or sitting in the (visually non-existent) gap ،
    /// see that function's own comment for why.
    private static func wrapClosedArcLength(_ s: CGFloat, cycleLength: CGFloat, totalLength: CGFloat) -> CGFloat {
        guard cycleLength > 0 else { return 0 }
        var w = max(0, s).truncatingRemainder(dividingBy: cycleLength)
        if w < 0 { w += cycleLength }
        return min(w, totalLength)
    }

    /// Degenerate-path fallback: draws the text un-rotated at the path's
    /// start point (or the node origin if the path has no points at all)
    /// rather than producing no output ، §9.6-equivalent "degenerate
    /// geometry" handling, simplified for this stand-in.
    private func drawFallbackAtOrigin(_ node: MKPathTextNode, into ctx: CGContext) {
        let liveTextDrawer = LiveTextDrawer(fonts: fonts)
        let asLiveText = MKLiveTextNode(core: node.core, text: node.text, style: node.style, frame: .singleLine)
        var scratch = MKRenderReportBuilder()
        liveTextDrawer.draw(asLiveText, into: ctx, quality: .exportQuality, report: &scratch)
    }
}

/// Self-contained polyline arc-length sampler. `PathTextDrawer` no longer
/// uses this (it adopted WS-05's real `ArcLengthLUT`/`PathLayoutEngine`,
/// see the file comment above) ، kept for `HitTester.pathProximity`'s own,
/// separate stand-in use (see that file), which is outside this task's
/// drawer-only scope.
public enum MKPolylineArcLength {
    public struct Placement: Sendable {
        public var point: CGPoint
        public var tangentAngle: CGFloat
    }

    public struct Table: Sendable {
        fileprivate var points: [CGPoint]
        fileprivate var cumulativeLengths: [CGFloat]
        public var totalLength: CGFloat { cumulativeLengths.last ?? 0 }

        /// Nearest sampled point/tangent at arc length `length` along the
        /// path (clamped to `[0, totalLength]`), linearly interpolated
        /// between the two bracketing samples.
        public func point(atLength length: CGFloat) -> Placement {
            guard points.count > 1 else {
                return Placement(point: points.first ?? .zero, tangentAngle: 0)
            }
            let clamped = min(max(length, 0), totalLength)
            var upper = 1
            while upper < cumulativeLengths.count - 1, cumulativeLengths[upper] < clamped {
                upper += 1
            }
            let lower = upper - 1
            let segStart = cumulativeLengths[lower]
            let segEnd = cumulativeLengths[upper]
            let segLength = segEnd - segStart
            let t = segLength > 0 ? (clamped - segStart) / segLength : 0
            let p0 = points[lower]
            let p1 = points[upper]
            let point = CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t)
            let angle = atan2(p1.y - p0.y, p1.x - p0.x)
            return Placement(point: point, tangentAngle: angle)
        }

        /// Nearest arc length + perpendicular distance for a query point ،
        /// `HitTester.pathProximity`'s stand-in for WS-05's `nearestLength`.
        public func nearest(to query: CGPoint) -> (length: CGFloat, distance: CGFloat) {
            guard points.count > 1 else {
                guard let only = points.first else { return (0, .greatestFiniteMagnitude) }
                return (0, hypot(query.x - only.x, query.y - only.y))
            }
            var bestLength: CGFloat = 0
            var bestDistance = CGFloat.greatestFiniteMagnitude
            for i in 0..<(points.count - 1) {
                let p0 = points[i]
                let p1 = points[i + 1]
                let segVector = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let segLengthSquared = segVector.x * segVector.x + segVector.y * segVector.y
                let t: CGFloat
                if segLengthSquared > 0 {
                    let toQuery = CGPoint(x: query.x - p0.x, y: query.y - p0.y)
                    t = min(max((toQuery.x * segVector.x + toQuery.y * segVector.y) / segLengthSquared, 0), 1)
                } else {
                    t = 0
                }
                let closest = CGPoint(x: p0.x + segVector.x * t, y: p0.y + segVector.y * t)
                let distance = hypot(query.x - closest.x, query.y - closest.y)
                if distance < bestDistance {
                    bestDistance = distance
                    bestLength = cumulativeLengths[i] + segLengthSquared.squareRoot() * t
                }
            }
            return (bestLength, bestDistance)
        }
    }

    /// Flattens `path` into a polyline (fixed subdivision per Bézier
    /// segment ، dense enough for typical canvas-scale paths; not adaptive
    /// like a real arc-length LUT would be) and builds a cumulative-length
    /// table over it.
    public static func sample(_ path: CGPath, segmentsPerCurve: Int = 32) -> Table {
        var points: [CGPoint] = []
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                current = element.points[0]
                subpathStart = current
                points.append(current)
            case .addLineToPoint:
                current = element.points[0]
                points.append(current)
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let end = element.points[1]
                for step in 1...segmentsPerCurve {
                    let t = CGFloat(step) / CGFloat(segmentsPerCurve)
                    points.append(quadPoint(current, control, end, t))
                }
                current = end
            case .addCurveToPoint:
                let c1 = element.points[0]
                let c2 = element.points[1]
                let end = element.points[2]
                for step in 1...segmentsPerCurve {
                    let t = CGFloat(step) / CGFloat(segmentsPerCurve)
                    points.append(cubicPoint(current, c1, c2, end, t))
                }
                current = end
            case .closeSubpath:
                points.append(subpathStart)
                current = subpathStart
            @unknown default:
                break
            }
        }

        var cumulative: [CGFloat] = []
        var total: CGFloat = 0
        for (i, point) in points.enumerated() {
            if i == 0 {
                cumulative.append(0)
            } else {
                total += hypot(point.x - points[i - 1].x, point.y - points[i - 1].y)
                cumulative.append(total)
            }
        }
        return Table(points: points, cumulativeLengths: cumulative)
    }

    private static func quadPoint(_ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * p0.x + 2 * mt * t * c.x + t * t * p1.x
        let y = mt * mt * p0.y + 2 * mt * t * c.y + t * t * p1.y
        return CGPoint(x: x, y: y)
    }

    private static func cubicPoint(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * mt * p0.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * p1.x
        let y = mt * mt * mt * p0.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * p1.y
        return CGPoint(x: x, y: y)
    }
}
