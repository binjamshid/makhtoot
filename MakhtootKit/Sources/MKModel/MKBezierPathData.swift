import CoreGraphics
import Foundation

// WS-02 packet §5 task 4 names this file for the Bézier path type consumed
// by `MKGlyphNode.outline` (per the packet's prose). ARCHITECTURE.md §3.6
// and the `scene.json` schema (§13.4) actually specify **two** distinct,
// non-interchangeable path encodings that this packet's node family needs:
//
// 1. `MKBezierPathData` ، anchor + control-point cubic curves (schema's
//    `bezierPath` def: `segments` of `{start,c1,c2,end}` + `isClosed`).
//    This is the *editable, live* path representation: `MKPathTextNode.path`
//    (a path the user drags control points on) and the `pathData` slot of
//    `MKSourceTextBackup` when an arranged node was derived from path text.
// 2. `MKPathData` ، a flat command-stream (schema's `pathData` def:
//    `commands: [Double]` + `unitsPerEm`). This is the *frozen, glyph-scale*
//    representation: `MKGlyphNode.outline`/ligature outlines (extracted via
//    `CTFontCreatePathForGlyph`, WS-03) and `MKShapeGeometry.path`.
//
// Both are declared here (rather than inventing an extra undeclared file)
// since they are the same "path data encoding" concern the packet's task 4
// groups together, and `MKPathData` has no consumer that isn't already a
// consumer of this file's `MKBezierPathData`.

/// One cubic Bézier segment: `start`→`end`, with control points `c1`
/// (leaving `start`) and `c2` (entering `end`).
public struct MKBezierSegment: Hashable, Sendable, Codable, Equatable {
    public var start: CGPoint
    public var c1: CGPoint
    public var c2: CGPoint
    public var end: CGPoint

    public init(start: CGPoint, c1: CGPoint, c2: CGPoint, end: CGPoint) {
        self.start = start
        self.c1 = c1
        self.c2 = c2
        self.end = end
    }
}

/// Editable cubic Bézier path (control points + anchors, open or closed) ،
/// the *document representation* for path-text paths (D-110) and for the
/// `pathData` slot of a path-derived `MKSourceTextBackup` (task 5). Owned by
/// `MKModel` (not `MKPathText`, WS-05) because `MKPathTextNode` ، one of
/// the seven D-111 node cases `MKModel` must define ، needs this type, and
/// `MKModel` cannot depend on `MKPathText` (DEPENDENCY_GRAPH.md: `MKPathText`
/// depends on `MKModel`, never the reverse). WS-05 builds the arc-length
/// layout engine (`ArcLengthLUT`, live-edit model) *on top of* this value
/// type; it does not own the type itself.
public struct MKBezierPathData: Hashable, Sendable, Codable, Equatable {
    public var segments: [MKBezierSegment]
    public var isClosed: Bool

    public init(segments: [MKBezierSegment] = [], isClosed: Bool = false) {
        self.segments = segments
        self.isClosed = isClosed
    }

    /// Builds a `CGPath` by walking `segments` as cubic curves (or a single
    /// line when `c1`/`c2` both equal their segment's endpoints, which is
    /// how straight sub-paths are still expressed as "cubic" without a
    /// separate line op ، the cubic formula degenerates to a line exactly
    /// in that case).
    public func cgPath() -> CGPath {
        let path = CGMutablePath()
        guard let first = segments.first else { return path }
        path.move(to: first.start)
        for segment in segments {
            path.addCurve(to: segment.end, control1: segment.c1, control2: segment.c2)
        }
        if isClosed { path.closeSubpath() }
        return path
    }
}

/// Flat, glyph-scale path command stream (§3.6): faithful to `CGPath`
/// element semantics, compact in JSON. Ops: `0`=move(2 coords),
/// `1`=line(2), `2`=quad(4), `3`=cubic(6), `4`=close(0). Coordinates are in
/// glyph units scaled to `unitsPerEm` (always `1000` in v1 encodes) so the
/// same outline renders correctly at any point size without re-extraction ،
/// the mechanism behind "arranged nodes stay render-complete even after the
/// source font locks" (§3.4 design notes, INV-13).
public struct MKPathData: Hashable, Sendable, Codable, Equatable {
    public var commands: [Double]
    public var unitsPerEm: Double

    public init(commands: [Double] = [], unitsPerEm: Double = 1000) {
        self.commands = commands
        self.unitsPerEm = unitsPerEm
    }

    /// Scales `1000/em`-normalized coordinates up to `pointSize` and builds
    /// a `CGPath`. Malformed command streams (truncated argument lists,
    /// unknown op codes) stop decoding at the last complete op rather than
    /// trapping ، outline data is regenerable (WS-03 can re-extract from the
    /// font when available), so a partially-corrupt cache should degrade,
    /// not crash the app.
    public func cgPath(at pointSize: Double) -> CGPath {
        let path = CGMutablePath()
        let scale = pointSize / unitsPerEm
        var i = 0
        func point(_ offset: Int) -> CGPoint {
            CGPoint(x: commands[i + offset] * scale, y: commands[i + offset + 1] * scale)
        }
        while i < commands.count {
            let op = Int(commands[i])
            let argsStart = i + 1
            switch op {
            case 0 where argsStart + 2 <= commands.count:
                path.move(to: point(1)); i = argsStart + 2
            case 1 where argsStart + 2 <= commands.count:
                path.addLine(to: point(1)); i = argsStart + 2
            case 2 where argsStart + 4 <= commands.count:
                let c = CGPoint(x: commands[argsStart] * scale, y: commands[argsStart + 1] * scale)
                let e = CGPoint(x: commands[argsStart + 2] * scale, y: commands[argsStart + 3] * scale)
                path.addQuadCurve(to: e, control: c)
                i = argsStart + 4
            case 3 where argsStart + 6 <= commands.count:
                let c1 = CGPoint(x: commands[argsStart] * scale, y: commands[argsStart + 1] * scale)
                let c2 = CGPoint(x: commands[argsStart + 2] * scale, y: commands[argsStart + 3] * scale)
                let e = CGPoint(x: commands[argsStart + 4] * scale, y: commands[argsStart + 5] * scale)
                path.addCurve(to: e, control1: c1, control2: c2)
                i = argsStart + 6
            case 4:
                path.closeSubpath(); i = argsStart
            default:
                return path
            }
        }
        return path
    }

    /// Builds an `MKPathData` from a `CGPath`, rounding coordinates to 2
    /// decimals in glyph-unit space (JSON size discipline, §3.6: "≤0.1% of
    /// em ، invisible at 300 DPI print for realistic sizes").
    public static func from(_ cgPath: CGPath, pointSize: Double, unitsPerEm: Double = 1000) -> MKPathData {
        guard pointSize > 0 else { return MKPathData(commands: [], unitsPerEm: unitsPerEm) }
        let scale = unitsPerEm / pointSize
        func round2(_ v: CGFloat) -> Double { (Double(v * scale) * 100).rounded() / 100 }
        var commands: [Double] = []
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                commands.append(contentsOf: [0, round2(element.points[0].x), round2(element.points[0].y)])
            case .addLineToPoint:
                commands.append(contentsOf: [1, round2(element.points[0].x), round2(element.points[0].y)])
            case .addQuadCurveToPoint:
                commands.append(contentsOf: [
                    2, round2(element.points[0].x), round2(element.points[0].y),
                    round2(element.points[1].x), round2(element.points[1].y),
                ])
            case .addCurveToPoint:
                commands.append(contentsOf: [
                    3, round2(element.points[0].x), round2(element.points[0].y),
                    round2(element.points[1].x), round2(element.points[1].y),
                    round2(element.points[2].x), round2(element.points[2].y),
                ])
            case .closeSubpath:
                commands.append(4)
            @unknown default:
                break
            }
        }
        return MKPathData(commands: commands, unitsPerEm: unitsPerEm)
    }
}
