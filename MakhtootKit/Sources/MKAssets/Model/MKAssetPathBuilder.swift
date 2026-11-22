import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 tasks 4–8. Shared geometry-construction primitives every
// generator (`MKBasicShapeGenerator`, `MKOrnamentGenerator`, …) builds on ،
// one place implementing regular/star polygons, circular arcs (kappa-based
// cubic Bézier approximation), rounded rects, and variable-width "ribbon"
// outlines (T7's "variable-width outline baked as a filled path"), so every
// generator authors geometry the same, tested way instead of re-deriving
// trig per asset.
public enum MKAssetPathBuilder {
    /// Cubic-Bézier circular-arc approximation constant (4/3 × (√2 − 1)),
    /// the standard "kappa" factor for a 90° arc.
    private static let kappa90: Double = 4.0 / 3.0 * (2.0.squareRoot() - 1.0)

    // MARK: - Polylines (straight-edge shapes)

    /// A closed or open straight-edge subpath through `points`, encoded as
    /// degenerate cubics (`c1 == start`, `c2 == end`) ، `MKAssetGeometry
    /// .toPathData()` recognizes this shape and emits a compact line op.
    public static func polyline(_ points: [CGPoint], closed: Bool) -> MKAssetSubpath {
        guard points.count >= 2 else {
            return MKAssetSubpath(segments: [], isClosed: closed)
        }
        var segments: [MKBezierSegment] = []
        let count = closed ? points.count : points.count - 1
        for i in 0..<count {
            let start = points[i]
            let end = points[(i + 1) % points.count]
            segments.append(MKBezierSegment(start: start, c1: start, c2: end, end: end))
        }
        return MKAssetSubpath(segments: segments, isClosed: closed)
    }

    /// A regular `sides`-gon centered at the origin, vertex 0 at `rotation`
    /// radians (default: pointing "up", i.e. `-π/2`, so odd-sided shapes
    /// like triangles/pentagons look upright).
    public static func regularPolygon(sides: Int, radius: Double, rotation: Double = -.pi / 2) -> MKAssetSubpath {
        precondition(sides >= 3, "a polygon needs at least 3 sides")
        let points = (0..<sides).map { i -> CGPoint in
            let angle = rotation + Double(i) / Double(sides) * 2 * .pi
            return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
        }
        return polyline(points, closed: true)
    }

    /// A `points`-pointed star centered at the origin: outer vertices at
    /// `outerRadius`, inner (valley) vertices at `outerRadius * innerRatio`.
    /// This is also the standard construction for Islamic star-polygon
    /// rosettes (an "{n/k}" star polygon is a special case reachable by
    /// choosing `innerRatio` to match the desired point sharpness ،
    /// `MKOrnamentGenerator` documents the specific ratio used per motif).
    public static func starPolygon(points: Int, outerRadius: Double, innerRatio: Double, rotation: Double = -.pi / 2) -> MKAssetSubpath {
        precondition(points >= 3, "a star needs at least 3 points")
        let innerRadius = outerRadius * innerRatio
        var vertices: [CGPoint] = []
        vertices.reserveCapacity(points * 2)
        for i in 0..<(points * 2) {
            let angle = rotation + Double(i) / Double(points * 2) * 2 * .pi
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            vertices.append(CGPoint(x: radius * cos(angle), y: radius * sin(angle)))
        }
        return polyline(vertices, closed: true)
    }

    // MARK: - Circular arcs

    /// A full circle subpath (4 cubic-Bézier quadrants). `reversed` flips
    /// point-traversal order ، used to make an inner "hole" subpath wind
    /// OPPOSITE to its outer subpath so the nonzero fill rule alone
    /// produces the correct subtraction (`MKAssetGeometry`'s file-header
    /// note on the crescent/hole problem).
    public static func circle(center: CGPoint, radius: Double, reversed: Bool = false) -> MKAssetSubpath {
        let k = radius * kappa90
        // Four quadrant points, starting at 0° (east), going counter-clockwise
        // in standard math convention (increasing angle).
        let angles: [Double] = [0, .pi / 2, .pi, 3 * .pi / 2]
        var quadrantPoints = angles.map { angle in
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        var tangents = angles.map { angle in
            CGPoint(x: -sin(angle), y: cos(angle)) // unit tangent, CCW direction
        }
        if reversed {
            quadrantPoints.reverse()
            tangents = tangents.reversed().map { CGPoint(x: -$0.x, y: -$0.y) }
        }
        var segments: [MKBezierSegment] = []
        for i in 0..<4 {
            let start = quadrantPoints[i]
            let end = quadrantPoints[(i + 1) % 4]
            let tStart = tangents[i]
            let tEnd = tangents[(i + 1) % 4]
            let c1 = CGPoint(x: start.x + tStart.x * k, y: start.y + tStart.y * k)
            let c2 = CGPoint(x: end.x - tEnd.x * k, y: end.y - tEnd.y * k)
            segments.append(MKBezierSegment(start: start, c1: c1, c2: c2, end: end))
        }
        return MKAssetSubpath(segments: segments, isClosed: true)
    }

    /// An OPEN circular arc from `startAngle` to `endAngle` (radians,
    /// standard math convention, increasing = counter-clockwise), split
    /// into ≤90°-per-segment cubic Béziers for accuracy.
    public static func arcSegments(center: CGPoint, radius: Double, startAngle: Double, endAngle: Double) -> [MKBezierSegment] {
        let totalSweep = endAngle - startAngle
        guard totalSweep != 0 else { return [] }
        let stepCount = max(1, Int(ceil(abs(totalSweep) / (.pi / 2))))
        let step = totalSweep / Double(stepCount)
        var segments: [MKBezierSegment] = []
        for i in 0..<stepCount {
            let a0 = startAngle + Double(i) * step
            let a1 = a0 + step
            let start = CGPoint(x: center.x + radius * cos(a0), y: center.y + radius * sin(a0))
            let end = CGPoint(x: center.x + radius * cos(a1), y: center.y + radius * sin(a1))
            let k = radius * (4.0 / 3.0) * tan(step / 4)
            let t0 = CGPoint(x: -sin(a0), y: cos(a0))
            let t1 = CGPoint(x: -sin(a1), y: cos(a1))
            let c1 = CGPoint(x: start.x + t0.x * k, y: start.y + t0.y * k)
            let c2 = CGPoint(x: end.x - t1.x * k, y: end.y - t1.y * k)
            segments.append(MKBezierSegment(start: start, c1: c1, c2: c2, end: end))
        }
        return segments
    }

    /// A ring (annulus) formed by an outer circle minus an inner circle ،
    /// two opposite-wound subpaths, correct under nonzero fill.
    public static func ring(center: CGPoint, outerRadius: Double, innerRadius: Double) -> [MKAssetSubpath] {
        [circle(center: center, radius: outerRadius, reversed: false), circle(center: center, radius: innerRadius, reversed: true)]
    }

    /// Two circles (outer minus an off-center, fully-contained inner
    /// circle) ، the crescent (هلال) construction task 4 names explicitly.
    /// `offset` must satisfy `offset + innerRadius <= outerRadius` so the
    /// inner circle stays fully inside the outer one (no stray "inner-only"
    /// region, which the nonzero-cancellation trick does not handle).
    public static func crescent(outerRadius: Double, innerRadius: Double, offset: Double) -> [MKAssetSubpath] {
        precondition(offset + innerRadius <= outerRadius, "inner circle must stay fully inside the outer circle")
        let outer = circle(center: .zero, radius: outerRadius, reversed: false)
        let inner = circle(center: CGPoint(x: offset, y: 0), radius: innerRadius, reversed: true)
        return [outer, inner]
    }

    /// A two-centered "pointed arch" (equilateral construction): two
    /// circular arcs, each centered at the OPPOSITE spring point with
    /// radius equal to the full span, meeting at a genuinely SHARP apex
    /// directly above the springs' midpoint ، the classic Islamic/Gothic
    /// pointed-arch construction. `leftSpring`/`rightSpring` must be level
    /// (same y) with `rightSpring.x > leftSpring.x`. Returns segments
    /// ordered left-to-right (`leftSpring` → apex → `rightSpring`).
    ///
    /// **Why not a smooth Bézier blend from each spring straight to the
    /// apex point** (this module's first-draft approach for
    /// `simpleMihrabArchOutline`/`archFrame`): two cubic curves sharing an
    /// endpoint render with a SMOOTH, rounded transition at that shared
    /// point unless their tangent directions are deliberately made to meet
    /// at a sharp angle ، the first draft's control points didn't, and
    /// visual QA (`docs/impl-log/WS-14.md`, T11 contact-sheet review)
    /// showed a rounded dome/tombstone shape instead of a pointed arch.
    /// Two circular arcs meeting at a point where their tangent lines
    /// genuinely differ (60° apart here) produce an unambiguous corner ،
    /// no smoothing possible, matching the intended silhouette exactly.
    public static func pointedArchSegments(leftSpring: CGPoint, rightSpring: CGPoint) -> [MKBezierSegment] {
        precondition(rightSpring.x > leftSpring.x && leftSpring.y == rightSpring.y, "springs must be level, left before right")
        // Left arc: centered at rightSpring, radius = span, sweeping from
        // leftSpring (angle π relative to that center) up to the apex
        // (angle 4π/3 ، a further 60° sweep, the equilateral construction).
        let leftArc = arcSegments(center: rightSpring, radius: rightSpring.x - leftSpring.x, startAngle: .pi, endAngle: 4 * .pi / 3)
        // Right arc: centered at leftSpring, radius = span, sweeping from
        // the apex (angle −π/3 relative to that center) down to rightSpring
        // (angle 0).
        let rightArc = arcSegments(center: leftSpring, radius: rightSpring.x - leftSpring.x, startAngle: -.pi / 3, endAngle: 0)
        return leftArc + rightArc
    }

    // MARK: - Rounded rectangle

    public static func roundedRect(rect: CGRect, cornerRadius: Double) -> MKAssetSubpath {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        guard r > 0 else {
            return polyline(
                [
                    CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                    CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY),
                ], closed: true
            )
        }
        let path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        return subpath(from: path)
    }

    /// Converts a `CGPath` (assumed single-subpath, as produced by CG's own
    /// primitive constructors like `CGPath(roundedRect:...)` or
    /// `CGPath(ellipseIn:...)`) into one `MKAssetSubpath` by walking its
    /// elements.
    public static func subpath(from cgPath: CGPath) -> MKAssetSubpath {
        var segments: [MKBezierSegment] = []
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var closed = false
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                current = element.points[0]
                subpathStart = current
            case .addLineToPoint:
                let end = element.points[0]
                segments.append(MKBezierSegment(start: current, c1: current, c2: end, end: end))
                current = end
            case .addQuadCurveToPoint:
                let c = element.points[0]
                let end = element.points[1]
                // Elevate quadratic → cubic (exact conversion).
                let c1 = CGPoint(x: current.x + 2.0 / 3.0 * (c.x - current.x), y: current.y + 2.0 / 3.0 * (c.y - current.y))
                let c2 = CGPoint(x: end.x + 2.0 / 3.0 * (c.x - end.x), y: end.y + 2.0 / 3.0 * (c.y - end.y))
                segments.append(MKBezierSegment(start: current, c1: c1, c2: c2, end: end))
                current = end
            case .addCurveToPoint:
                let c1 = element.points[0], c2 = element.points[1], end = element.points[2]
                segments.append(MKBezierSegment(start: current, c1: c1, c2: c2, end: end))
                current = end
            case .closeSubpath:
                closed = true
                current = subpathStart
            @unknown default:
                break
            }
        }
        return MKAssetSubpath(segments: segments, isClosed: closed)
    }

    // MARK: - Variable-width ribbon (calligraphic strokes, T7)

    /// Builds a single closed, filled outline approximating a
    /// variable-width stroke along `centerline` ، "variable-width outlines
    /// baked as filled paths," task 7's explicit non-font construction for
    /// calligraphic dividers/flourishes. `widths[i]` is the full stroke
    /// width at `centerline[i]` (must be the same count). Offsets each
    /// centerline point perpendicular to its local tangent by half the
    /// local width, producing a "left" rail forward and a "right" rail
    /// backward, joined into one closed polygon subpath.
    public static func ribbon(centerline: [CGPoint], widths: [Double]) -> MKAssetSubpath {
        precondition(centerline.count == widths.count && centerline.count >= 2, "ribbon needs matching centerline/widths, ≥2 points")
        let n = centerline.count
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in 0..<n {
            let prev = centerline[max(0, i - 1)]
            let next = centerline[min(n - 1, i + 1)]
            var tangent = CGPoint(x: next.x - prev.x, y: next.y - prev.y)
            let length = (tangent.x * tangent.x + tangent.y * tangent.y).squareRoot()
            if length > 0 { tangent = CGPoint(x: tangent.x / length, y: tangent.y / length) } else { tangent = CGPoint(x: 1, y: 0) }
            let normal = CGPoint(x: -tangent.y, y: tangent.x)
            let half = widths[i] / 2
            let p = centerline[i]
            left.append(CGPoint(x: p.x + normal.x * half, y: p.y + normal.y * half))
            right.append(CGPoint(x: p.x - normal.x * half, y: p.y - normal.y * half))
        }
        let outline = left + right.reversed()
        return polyline(outline, closed: true)
    }
}
