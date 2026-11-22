import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 task 4. ≥10 basic shapes, ALL free tier. Every geometry
// is authored programmatically (task 4: "Generated at instantiation with
// parameters where sensible") within the shared `MKAssetUnits.em`×`em`
// authoring box via `MKAssetPathBuilder`.
public enum MKBasicShapeGenerator {
    private static let R = MKAssetUnits.half * 0.9 // a little inset from the box edge

    public static func makeAll() -> [MKAssetDescriptor] {
        [
            rectangle(), roundedRectangle(), ellipse(), triangle(),
            pentagon(), hexagon(), octagon(), star5(), star6(), star8(),
            line(), arrow(), crescent(), semicircle(), teardrop(),
        ]
    }

    private static func descriptor(id: String, nameAr: String, tags: [String], geometry: MKAssetGeometry) -> MKAssetDescriptor {
        MKAssetDescriptor(
            assetID: "shape.\(id)", nameAr: nameAr, category: .basicShapes, tags: tags,
            isPremium: false, pathData: geometry, provenanceRef: "shape.\(id)"
        )
    }

    private static func rectangle() -> MKAssetDescriptor {
        let rect = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)
        let subpath = MKAssetPathBuilder.polyline(
            [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY)],
            closed: true
        )
        return descriptor(id: "rectangle", nameAr: "مستطيل", tags: ["مستطيل", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func roundedRectangle() -> MKAssetDescriptor {
        let rect = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)
        let subpath = MKAssetPathBuilder.roundedRect(rect: rect, cornerRadius: R * 0.3)
        return descriptor(id: "rounded-rectangle", nameAr: "مستطيل مستدير الزوايا", tags: ["مستطيل", "زوايا مستديرة", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func ellipse() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.circle(center: .zero, radius: R)
        return descriptor(id: "ellipse", nameAr: "بيضاوي", tags: ["بيضاوي", "دائرة", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func triangle() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.regularPolygon(sides: 3, radius: R)
        return descriptor(id: "triangle", nameAr: "مثلث", tags: ["مثلث", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func pentagon() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.regularPolygon(sides: 5, radius: R)
        return descriptor(id: "pentagon", nameAr: "خماسي", tags: ["مضلع", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func hexagon() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.regularPolygon(sides: 6, radius: R)
        return descriptor(id: "hexagon", nameAr: "سداسي", tags: ["مضلع", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func octagon() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.regularPolygon(sides: 8, radius: R)
        return descriptor(id: "octagon", nameAr: "ثماني الأضلاع", tags: ["مضلع", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func star5() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.starPolygon(points: 5, outerRadius: R, innerRatio: 0.5)
        return descriptor(id: "star-5", nameAr: "نجمة خماسية", tags: ["نجمة", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func star6() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.starPolygon(points: 6, outerRadius: R, innerRatio: 0.55)
        return descriptor(id: "star-6", nameAr: "نجمة سداسية", tags: ["نجمة", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func star8() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.starPolygon(points: 8, outerRadius: R, innerRatio: 0.5)
        return descriptor(id: "star-8", nameAr: "نجمة ثمانية", tags: ["نجمة", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func line() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.ribbon(
            centerline: [CGPoint(x: -R, y: 0), CGPoint(x: R, y: 0)], widths: [2, 2]
        )
        return descriptor(id: "line", nameAr: "خط مستقيم", tags: ["خط", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func arrow() -> MKAssetDescriptor {
        // A leftward arrow silhouette (RTL-first default direction) as a
        // single closed polygon: shaft + triangular head.
        let shaftHalf = R * 0.18
        let headHalf = R * 0.45
        let headStartX = -R * 0.25
        let points: [CGPoint] = [
            CGPoint(x: R, y: -shaftHalf), CGPoint(x: headStartX, y: -shaftHalf),
            CGPoint(x: headStartX, y: -headHalf), CGPoint(x: -R, y: 0),
            CGPoint(x: headStartX, y: headHalf), CGPoint(x: headStartX, y: shaftHalf),
            CGPoint(x: R, y: shaftHalf),
        ]
        let subpath = MKAssetPathBuilder.polyline(points, closed: true)
        return descriptor(id: "arrow", nameAr: "سهم", tags: ["سهم", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func crescent() -> MKAssetDescriptor {
        let subpaths = MKAssetPathBuilder.crescent(outerRadius: R, innerRadius: R * 0.82, offset: R * 0.16)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: subpaths, fillRule: .evenOdd)
        return descriptor(id: "crescent", nameAr: "هلال", tags: ["هلال", "هندسي"], geometry: geometry)
    }

    private static func semicircle() -> MKAssetDescriptor {
        var segments = MKAssetPathBuilder.arcSegments(center: .zero, radius: R, startAngle: 0, endAngle: .pi)
        let closing = MKBezierSegment(start: CGPoint(x: -R, y: 0), c1: CGPoint(x: -R, y: 0), c2: CGPoint(x: R, y: 0), end: CGPoint(x: R, y: 0))
        segments.append(closing)
        let subpath = MKAssetSubpath(segments: segments, isClosed: true)
        return descriptor(id: "semicircle", nameAr: "نصف دائرة", tags: ["نصف دائرة", "قوس", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func teardrop() -> MKAssetDescriptor {
        let apex = CGPoint(x: 0, y: -R * 1.7)
        let radius = R * 0.75
        var segments = MKAssetPathBuilder.arcSegments(center: .zero, radius: radius, startAngle: -.pi / 3, endAngle: .pi + .pi / 3)
        // Close the two straight sides back to the apex.
        if let firstStart = segments.first?.start, let lastEnd = segments.last?.end {
            segments.append(MKBezierSegment(start: lastEnd, c1: lastEnd, c2: apex, end: apex))
            segments.append(MKBezierSegment(start: apex, c1: apex, c2: firstStart, end: firstStart))
        }
        let subpath = MKAssetSubpath(segments: segments, isClosed: true)
        return descriptor(id: "teardrop", nameAr: "دمعة", tags: ["دمعة", "هندسي"], geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }
}
