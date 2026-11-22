import CoreGraphics
import Foundation
import MKModel

// P10-COMPLETION (Run-3, packet §5 tasks 13-16). Low-level XML/path-data
// helpers the hand-rolled serializer needs ، no third-party XML library
// (D-101), matching task 13's own "hand-rolled XML writer (escaping,
// indent, no deps)" instruction.
public enum SVGXML {
    /// XML-escapes the five required characters. Arabic text is emitted
    /// RAW (§16.6 rule: "Arabic strings raw... except XML-required
    /// escapes") ، this function does not touch non-XML-special
    /// characters, so Arabic letters/tashkeel/Arabic-Indic digits survive
    /// verbatim.
    public static func escape(_ string: String) -> String {
        var result = ""
        result.reserveCapacity(string.count)
        for scalar in string.unicodeScalars {
            switch scalar {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&apos;"
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// §16.6: "Numeric formatting: 3 decimals max, no scientific
    /// notation." Trims trailing zeros/dot for compactness (still ≤3
    /// decimals, never scientific ، `String(format:)` with `%f` never
    /// emits scientific notation).
    public static func number(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "0" }
        var formatted = String(format: "%.3f", value)
        while formatted.hasSuffix("0") { formatted.removeLast() }
        if formatted.hasSuffix(".") { formatted.removeLast() }
        if formatted == "-0" { formatted = "0" }
        return formatted
    }

    public static func number(_ value: CGFloat) -> String { number(Double(value)) }

    /// `data-mk-codepoints` ، space-separated hex Unicode scalars (D-227(2)
    /// canonical schema ، "space-separated hex... never comma-separated").
    public static func hexCodepoints(_ codepoints: [UInt32]) -> String {
        codepoints.map { String($0, radix: 16, uppercase: false) }.joined(separator: " ")
    }

    /// CSS/SVG `matrix(a,b,c,d,e,f)` from a `CGAffineTransform` ،
    /// component order matches CG's own `(a,b,c,d,tx,ty)` exactly (SVG's
    /// `matrix()` maps `x'=a*x+c*y+e; y'=b*x+d*y+f`, identical to
    /// `CGAffineTransform`'s own `x'=a*x+c*y+tx; y'=b*x+d*y+ty`).
    public static func matrix(_ t: CGAffineTransform) -> String {
        "matrix(\(number(t.a)),\(number(t.b)),\(number(t.c)),\(number(t.d)),\(number(t.tx)),\(number(t.ty)))"
    }

    /// `#rrggbb` from an `MKSolidColor`'s (extended, possibly out-of-range)
    /// sRGB components, clamped to `0...255` at serialize time (§15.4:
    /// "clamp at serialize" for the SVG surface).
    public static func hexColor(_ color: MKSolidColor) -> String {
        func byte(_ v: Double) -> String {
            let clamped = max(0, min(1, v))
            return String(format: "%02x", Int((clamped * 255).rounded()))
        }
        return "#\(byte(color.r))\(byte(color.g))\(byte(color.b))"
    }

    /// A `CGPath` → SVG `d` attribute string (moveTo/lineTo/quad/cubic/
    /// close ، every `CGPathElement` case `MKPathData`'s own `from(_:)`
    /// already enumerates, same op set, so this is a direct sibling of
    /// that function rather than a novel traversal).
    public static func pathData(_ path: CGPath) -> String {
        var d = ""
        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                d += "M\(number(element.points[0].x)) \(number(element.points[0].y)) "
            case .addLineToPoint:
                d += "L\(number(element.points[0].x)) \(number(element.points[0].y)) "
            case .addQuadCurveToPoint:
                d += "Q\(number(element.points[0].x)) \(number(element.points[0].y)) \(number(element.points[1].x)) \(number(element.points[1].y)) "
            case .addCurveToPoint:
                d += "C\(number(element.points[0].x)) \(number(element.points[0].y)) \(number(element.points[1].x)) \(number(element.points[1].y)) \(number(element.points[2].x)) \(number(element.points[2].y)) "
            case .closeSubpath:
                d += "Z "
            @unknown default:
                break
            }
        }
        return d.trimmingCharacters(in: .whitespaces)
    }
}

/// `MKShapeGeometry` → local-unit-space `CGPath`, replicating
/// `MKRender.ShapeDrawer.localPath(for:)`'s exact geometry (that function
/// is package-internal to `MKRender`, not exported ، see this type's own
/// note). Kept as a SEPARATE, independent implementation rather than
/// requesting a visibility change to `MKRender` (out of this packet's
/// fence) ، the geometry itself is tiny/stable (rect/ellipse/polygon/path
/// are all pure `MKModel` data, no font/asset resolution needed), so
/// duplicating ~15 lines here is a far smaller risk than editing another
/// packet's module.
public enum SVGShapeGeometry {
    public static func localPath(for geometry: MKShapeGeometry) -> CGPath? {
        switch geometry {
        case .rect(let cornerRadius):
            let rect = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)
            return CGPath(roundedRect: rect, cornerWidth: CGFloat(cornerRadius), cornerHeight: CGFloat(cornerRadius), transform: nil)
        case .ellipse:
            let rect = CGRect(x: -0.5, y: -0.5, width: 1, height: 1)
            return CGPath(ellipseIn: rect, transform: nil)
        case .line:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -0.5, y: 0))
            path.addLine(to: CGPoint(x: 0.5, y: 0))
            return path
        case .polygon(let points):
            guard let first = points.first else { return nil }
            let path = CGMutablePath()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            path.closeSubpath()
            return path
        case .path(let pathData):
            return pathData.cgPath(at: pathData.unitsPerEm)
        case .asset:
            return nil
        }
    }
}
