import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 task 5. ≥16 original Arabic ornaments (procedural
// constructions + hand-authored control points), free: 6, premium: rest
// (10). Every motif is aniconic geometry/floral abstraction ، no text, no
// Qur'anic content (§2 OUT, BRIEF Q67–68) ، and every construction is
// documented here (provenance construction notes live alongside each
// descriptor in `MKAssetProvenanceLibrary`, cross-referenced by `assetID`).
public enum MKOrnamentGenerator {
    private static let R = MKAssetUnits.half * 0.85

    public static func makeAll() -> [MKAssetDescriptor] {
        free() + premium()
    }

    private static func free() -> [MKAssetDescriptor] {
        [star6Rosette(), star8Rosette(), star10Rosette(), star12Rosette(), quatrefoilRosette(), medallionCircle()]
    }

    private static func premium() -> [MKAssetDescriptor] {
        [
            girihStrapworkMotif(), arabesqueScrollCorner(), palmetteBorderUnit(), mandorlaLozengeMedallion(),
            interlacedBandUnit(), muqarnasSilhouetteFriezeElement(), floralTawriqSpray(), simpleMihrabArchOutline(),
            starAndCrossTessellationUnit(), cornerFanOrnament(),
        ]
    }

    private static func descriptor(id: String, nameAr: String, tags: [String], isPremium: Bool, geometry: MKAssetGeometry) -> MKAssetDescriptor {
        MKAssetDescriptor(
            assetID: "ornament.\(id)", nameAr: nameAr, category: .ornaments, tags: tags,
            isPremium: isPremium, pathData: geometry, provenanceRef: "ornament.\(id)"
        )
    }

    // MARK: - Shared construction helpers

    /// A star polygon plus a thin outer ring (annulus) ، the classic
    /// "star rosette" silhouette. All subpaths share one region; the ring's
    /// two circles are opposite-wound (nonzero-rule annulus), the star is
    /// independently wound "positive" so it unions with the ring without
    /// canceling it (no overlap between the two by construction ، the ring
    /// sits strictly outside the star's outer radius).
    private static func starRosette(points: Int, outerRadius: Double, innerRatio: Double) -> [MKAssetSubpath] {
        let star = MKAssetPathBuilder.starPolygon(points: points, outerRadius: outerRadius, innerRatio: innerRatio)
        let ring = MKAssetPathBuilder.ring(center: .zero, outerRadius: outerRadius * 1.14, innerRadius: outerRadius * 1.05)
        return [star] + ring
    }

    /// A single elongated "petal" (teardrop-like leaf) with its base at the
    /// origin, pointing along `+x`, then rotated so its base sits at
    /// `basePoint` and its axis points along `angle`.
    private static func petal(basePoint: CGPoint, angle: Double, length: Double, width: Double) -> MKAssetSubpath {
        let tip = CGPoint(x: length, y: 0)
        let halfW = width / 2
        let c1a = CGPoint(x: length * 0.35, y: halfW)
        let c2a = CGPoint(x: length * 0.75, y: halfW * 0.6)
        let c1b = CGPoint(x: length * 0.75, y: -halfW * 0.6)
        let c2b = CGPoint(x: length * 0.35, y: -halfW)
        let segments = [
            MKBezierSegment(start: .zero, c1: c1a, c2: c2a, end: tip),
            MKBezierSegment(start: tip, c1: c1b, c2: c2b, end: .zero),
        ]
        let cosA = cos(angle), sinA = sin(angle)
        func transform(_ p: CGPoint) -> CGPoint {
            CGPoint(x: basePoint.x + p.x * cosA - p.y * sinA, y: basePoint.y + p.x * sinA + p.y * cosA)
        }
        let rotated = segments.map { seg in
            MKBezierSegment(start: transform(seg.start), c1: transform(seg.c1), c2: transform(seg.c2), end: transform(seg.end))
        }
        return MKAssetSubpath(segments: rotated, isClosed: true)
    }

    /// A fan of `count` petals radiating from `basePoint`, spread evenly
    /// across `spreadAngle` radians centered on `centerAngle`. Shared by
    /// the palmette border unit, floral spray, and corner fan.
    private static func petalFan(basePoint: CGPoint, centerAngle: Double, spreadAngle: Double, count: Int, length: Double, width: Double) -> [MKAssetSubpath] {
        guard count > 1 else { return [petal(basePoint: basePoint, angle: centerAngle, length: length, width: width)] }
        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1) - 0.5
            let angle = centerAngle + t * spreadAngle
            return petal(basePoint: basePoint, angle: angle, length: length, width: width)
        }
    }

    // MARK: - Free ornaments (6)

    private static func star6Rosette() -> MKAssetDescriptor {
        descriptor(id: "star-rosette-6", nameAr: "زخرفة نجمية سداسية", tags: ["نجمة", "هندسي", "إسلامي"], isPremium: false,
                   geometry: .singleRegionAutoBounds(subpaths: starRosette(points: 6, outerRadius: R, innerRatio: 0.5)))
    }

    /// The 8-point star (خاتم) named explicitly in the packet's task 5
    /// list.
    private static func star8Rosette() -> MKAssetDescriptor {
        descriptor(id: "star-rosette-8", nameAr: "خاتم", tags: ["نجمة ثمانية", "هندسي", "إسلامي"], isPremium: false,
                   geometry: .singleRegionAutoBounds(subpaths: starRosette(points: 8, outerRadius: R, innerRatio: 0.46)))
    }

    private static func star10Rosette() -> MKAssetDescriptor {
        descriptor(id: "star-rosette-10", nameAr: "زخرفة نجمية عشارية", tags: ["نجمة", "هندسي", "إسلامي"], isPremium: false,
                   geometry: .singleRegionAutoBounds(subpaths: starRosette(points: 10, outerRadius: R, innerRatio: 0.55)))
    }

    /// "12-point star rosette" (task 5's own example construction note:
    /// "12-fold rosette from {12/5} star polygon" ، `innerRatio` here is
    /// chosen to approximate the visual sharpness of a {12/5} star-polygon
    /// point, not a literal Schläfli-symbol construction).
    private static func star12Rosette() -> MKAssetDescriptor {
        descriptor(id: "star-rosette-12", nameAr: "وردة نجمية اثنا عشرية", tags: ["نجمة", "هندسي", "إسلامي"], isPremium: false,
                   geometry: .singleRegionAutoBounds(subpaths: starRosette(points: 12, outerRadius: R, innerRatio: 0.62)))
    }

    private static func quatrefoilRosette() -> MKAssetDescriptor {
        let lobeRadius = R * 0.42
        let offset = lobeRadius * 0.95
        let lobes = [0, 1, 2, 3].map { i -> MKAssetSubpath in
            let angle = Double(i) * .pi / 2
            let center = CGPoint(x: offset * cos(angle), y: offset * sin(angle))
            return MKAssetPathBuilder.circle(center: center, radius: lobeRadius)
        }
        let core = MKAssetPathBuilder.circle(center: .zero, radius: lobeRadius * 0.55)
        return descriptor(id: "quatrefoil-rosette", nameAr: "زخرفة رباعية الفصوص", tags: ["زهرة", "هندسي", "إسلامي"], isPremium: false,
                           geometry: .singleRegionAutoBounds(subpaths: lobes + [core]))
    }

    private static func medallionCircle() -> MKAssetDescriptor {
        let outerRing = MKAssetPathBuilder.ring(center: .zero, outerRadius: R, innerRadius: R * 0.82)
        let innerRing = MKAssetPathBuilder.ring(center: .zero, outerRadius: R * 0.6, innerRadius: R * 0.46)
        let core = MKAssetPathBuilder.circle(center: .zero, radius: R * 0.18)
        return descriptor(id: "medallion-circle", nameAr: "ميدالية دائرية", tags: ["ميدالية", "هندسي", "إسلامي"], isPremium: false,
                           geometry: .singleRegionAutoBounds(subpaths: outerRing + innerRing + [core]))
    }

    // MARK: - Premium ornaments (10)

    private static func girihStrapworkMotif() -> MKAssetDescriptor {
        let armLength = R * 0.85
        let armWidth = R * 0.16
        let arms = [0, 1, 2, 3].map { i -> MKAssetSubpath in
            let angle = Double(i) * .pi / 2 + .pi / 4
            let end = CGPoint(x: armLength * cos(angle), y: armLength * sin(angle))
            return MKAssetPathBuilder.ribbon(centerline: [.zero, end], widths: [armWidth, armWidth * 0.4])
        }
        let hub = MKAssetPathBuilder.regularPolygon(sides: 8, radius: armWidth * 1.1)
        return descriptor(id: "girih-strapwork", nameAr: "زخرفة قِرِيه المتشابكة", tags: ["قِرِيه", "تشابك", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: arms + [hub]))
    }

    private static func arabesqueScrollCorner() -> MKAssetDescriptor {
        // Sampled logarithmic-spiral centerline → variable-width ribbon.
        var centerline: [CGPoint] = []
        var widths: [Double] = []
        let turns = 1.3
        let steps = 40
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = t * turns * 2 * .pi
            let radius = R * 0.08 + t * R * 0.75
            centerline.append(CGPoint(x: radius * cos(angle) - R * 0.3, y: radius * sin(angle) - R * 0.3))
            widths.append(R * 0.16 * (1 - t * 0.6))
        }
        let subpath = MKAssetPathBuilder.ribbon(centerline: centerline, widths: widths)
        return descriptor(id: "arabesque-scroll-corner", nameAr: "زخرفة أرابيسك ركنية", tags: ["أرابيسك", "توريق", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func palmetteBorderUnit() -> MKAssetDescriptor {
        let petals = petalFan(basePoint: CGPoint(x: 0, y: R * 0.55), centerAngle: -.pi / 2, spreadAngle: .pi * 0.8, count: 5, length: R * 0.95, width: R * 0.28)
        let base = MKAssetPathBuilder.circle(center: CGPoint(x: 0, y: R * 0.55), radius: R * 0.12)
        return descriptor(id: "palmette-border-unit", nameAr: "وحدة نخيلية حدّية", tags: ["نخيلية", "زخرفة حدود", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: petals + [base]))
    }

    private static func mandorlaLozengeMedallion() -> MKAssetDescriptor {
        let top = CGPoint(x: 0, y: -R)
        let bottom = CGPoint(x: 0, y: R)
        let bulge = R * 0.55
        let segments = [
            MKBezierSegment(start: top, c1: CGPoint(x: bulge, y: -R * 0.45), c2: CGPoint(x: bulge, y: R * 0.45), end: bottom),
            MKBezierSegment(start: bottom, c1: CGPoint(x: -bulge, y: R * 0.45), c2: CGPoint(x: -bulge, y: -R * 0.45), end: top),
        ]
        let subpath = MKAssetSubpath(segments: segments, isClosed: true)
        return descriptor(id: "mandorla-lozenge-medallion", nameAr: "ميدالية لوزية (مندورلا)", tags: ["لوزة", "ميدالية", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func interlacedBandUnit() -> MKAssetDescriptor {
        let a = MKAssetPathBuilder.ribbon(centerline: [CGPoint(x: -R, y: -R * 0.5), CGPoint(x: R, y: R * 0.5)], widths: [R * 0.22, R * 0.22])
        let b = MKAssetPathBuilder.ribbon(centerline: [CGPoint(x: -R, y: R * 0.5), CGPoint(x: R, y: -R * 0.5)], widths: [R * 0.22, R * 0.22])
        return descriptor(id: "interlaced-band-unit", nameAr: "وحدة شريط متشابك", tags: ["تشابك", "شريط", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: [a, b]))
    }

    private static func muqarnasSilhouetteFriezeElement() -> MKAssetDescriptor {
        let stepCount = 4
        let stepWidth = 2 * R / Double(stepCount)
        var points: [CGPoint] = [CGPoint(x: -R, y: R)]
        for i in 0..<stepCount {
            let x0 = -R + Double(i) * stepWidth
            let x1 = x0 + stepWidth
            let y = R - R * (Double(i) + 1) / Double(stepCount) * 1.2
            points.append(CGPoint(x: x0, y: y))
            points.append(CGPoint(x: x1, y: y))
        }
        points.append(CGPoint(x: R, y: R))
        let subpath = MKAssetPathBuilder.polyline(points, closed: true)
        return descriptor(id: "muqarnas-frieze-element", nameAr: "عنصر إفريز مقرنص", tags: ["مقرنص", "إفريز", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func floralTawriqSpray() -> MKAssetDescriptor {
        let leaves = petalFan(basePoint: CGPoint(x: -R * 0.5, y: R * 0.5), centerAngle: -.pi / 4, spreadAngle: .pi * 0.9, count: 5, length: R * 1.1, width: R * 0.22)
        return descriptor(id: "floral-tawriq-spray", nameAr: "باقة توريق نباتية", tags: ["توريق", "نباتي", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: leaves))
    }

    private static func simpleMihrabArchOutline() -> MKAssetDescriptor {
        // Two-centered POINTED arch (`MKAssetPathBuilder.pointedArchSegments`
        // ، see that function's doc comment for why a smooth Bézier blend
        // was replaced with this construction after visual QA caught it
        // rendering as a rounded dome instead of a genuine point).
        let bodyWidth = R * 1.2
        let bodyHeight = R * 1.1
        let bodyTop = -R * 0.1
        let leftSpring = CGPoint(x: -bodyWidth / 2, y: bodyTop)
        let rightSpring = CGPoint(x: bodyWidth / 2, y: bodyTop)
        var segments = MKAssetPathBuilder.pointedArchSegments(leftSpring: leftSpring, rightSpring: rightSpring)
        let bottomRight = CGPoint(x: bodyWidth / 2, y: bodyTop + bodyHeight)
        let bottomLeft = CGPoint(x: -bodyWidth / 2, y: bodyTop + bodyHeight)
        segments.append(MKBezierSegment(start: rightSpring, c1: rightSpring, c2: bottomRight, end: bottomRight))
        segments.append(MKBezierSegment(start: bottomRight, c1: bottomRight, c2: bottomLeft, end: bottomLeft))
        segments.append(MKBezierSegment(start: bottomLeft, c1: bottomLeft, c2: leftSpring, end: leftSpring))
        let subpath = MKAssetSubpath(segments: segments, isClosed: true)
        return descriptor(id: "mihrab-arch-outline", nameAr: "محراب زخرفي (عقد مدبب)", tags: ["محراب", "عقد", "معماري", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func starAndCrossTessellationUnit() -> MKAssetDescriptor {
        let star = MKAssetPathBuilder.starPolygon(points: 8, outerRadius: R * 0.55, innerRatio: 0.42)
        let armLength = R
        let armWidth = R * 0.22
        let cross = [0, 1].map { i -> MKAssetSubpath in
            let horizontal = i == 0
            let a = horizontal ? CGPoint(x: -armLength, y: 0) : CGPoint(x: 0, y: -armLength)
            let b = horizontal ? CGPoint(x: armLength, y: 0) : CGPoint(x: 0, y: armLength)
            return MKAssetPathBuilder.ribbon(centerline: [a, b], widths: [armWidth, armWidth])
        }
        return descriptor(id: "star-cross-tessellation-unit", nameAr: "وحدة تجانب نجمة وصليب هندسي", tags: ["تجانب", "نجمة", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: [star] + cross))
    }

    private static func cornerFanOrnament() -> MKAssetDescriptor {
        let petals = petalFan(basePoint: CGPoint(x: -R, y: -R), centerAngle: .pi / 4, spreadAngle: .pi / 2, count: 3, length: R * 1.3, width: R * 0.3)
        return descriptor(id: "corner-fan-ornament", nameAr: "زخرفة مروحية ركنية", tags: ["ركنية", "مروحة", "إسلامي"], isPremium: true,
                           geometry: .singleRegionAutoBounds(subpaths: petals))
    }
}
