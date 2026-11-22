import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 task 7. ≥10 calligraphic divider/flourish elements ،
// DRAWN paths evoking calligraphic strokes (variable-width outlines baked
// as filled paths via `MKAssetPathBuilder.ribbon`), never font glyphs and
// never derived from any font file (sidesteps OFL reserved-name/scope
// questions entirely, per the task's own framing). Every provenance note
// for this category explicitly states "no font file consulted" ،
// `AssetProvenanceAudit`'s T7 sub-check greps for exactly that absence
// (see `Tests/MKAssetsTests/AssetProvenanceAuditTests.swift`).
public enum MKCalligraphicGenerator {
    private static let R = MKAssetUnits.half * 0.9

    public static func makeAll() -> [MKAssetDescriptor] {
        free() + premium()
    }

    private static func free() -> [MKAssetDescriptor] {
        [tarwisaSwashDivider(), ornamentalRule(), dotClusterMotif(), waveDivider(), diamondDotDivider(), vineDivider()]
    }

    private static func premium() -> [MKAssetDescriptor] {
        [teardropFinial(), knotMotif(), swashFlourish(mirrored: false), swashFlourish(mirrored: true)]
    }

    private static func descriptor(id: String, nameAr: String, tags: [String], isPremium: Bool, geometry: MKAssetGeometry) -> MKAssetDescriptor {
        MKAssetDescriptor(
            assetID: "calligraphic.\(id)", nameAr: nameAr, category: .calligraphicElements, tags: tags,
            isPremium: isPremium, pathData: geometry, provenanceRef: "calligraphic.\(id)"
        )
    }

    /// A tapered calligraphic swash: a shallow S-curve centerline with
    /// width tapering to a point at both ends (the "brush stroke" look, no
    /// font glyph involved).
    private static func tarwisaSwashDivider() -> MKAssetDescriptor {
        let points = [CGPoint(x: -R, y: 0), CGPoint(x: -R * 0.3, y: -R * 0.25), CGPoint(x: R * 0.3, y: R * 0.25), CGPoint(x: R, y: 0)]
        let widths = [0.0, R * 0.22, R * 0.22, 0.0]
        let subpath = MKAssetPathBuilder.ribbon(centerline: points, widths: widths)
        return descriptor(id: "tarwisa-swash-divider", nameAr: "فاصلة ترويسة", tags: ["فاصلة", "زخرفة خطية"], isPremium: false, geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    /// A plain ornamental rule sized like a line of Arabic body text
    /// (packet's own naming: "bismillah-LENGTH rule... plain ornamental
    /// rule ، NO text, aniconic") ، a straight, gently tapered bar.
    private static func ornamentalRule() -> MKAssetDescriptor {
        let subpath = MKAssetPathBuilder.ribbon(
            centerline: [CGPoint(x: -R, y: 0), CGPoint(x: -R * 0.85, y: 0), CGPoint(x: R * 0.85, y: 0), CGPoint(x: R, y: 0)],
            widths: [0, R * 0.05, R * 0.05, 0]
        )
        return descriptor(id: "ornamental-rule", nameAr: "فاصلة زخرفية بطول السطر", tags: ["فاصلة", "خط زخرفي"], isPremium: false, geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    /// ثلاث نقاط (three dots) ، a small triangular dot cluster, a very
    /// common Arabic-manuscript paragraph-end mark (aniconic, geometric).
    private static func dotClusterMotif() -> MKAssetDescriptor {
        let dotRadius = R * 0.12
        let centers = [CGPoint(x: 0, y: -R * 0.3), CGPoint(x: -R * 0.26, y: R * 0.2), CGPoint(x: R * 0.26, y: R * 0.2)]
        let dots = centers.map { MKAssetPathBuilder.circle(center: $0, radius: dotRadius) }
        return descriptor(id: "dot-cluster", nameAr: "ثلاث نقاط", tags: ["نقاط", "فاصلة"], isPremium: false, geometry: .singleRegionAutoBounds(subpaths: dots))
    }

    private static func waveDivider() -> MKAssetDescriptor {
        var centerline: [CGPoint] = []
        var widths: [Double] = []
        let steps = 24
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let x = -R + t * 2 * R
            let y = sin(t * 2 * .pi) * R * 0.15
            centerline.append(CGPoint(x: x, y: y))
            widths.append(R * 0.06 * sin(.pi * t) + R * 0.02)
        }
        let subpath = MKAssetPathBuilder.ribbon(centerline: centerline, widths: widths)
        return descriptor(id: "wave-divider", nameAr: "فاصلة متموجة", tags: ["فاصلة", "زخرفة خطية"], isPremium: false, geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func diamondDotDivider() -> MKAssetDescriptor {
        let diamond = MKAssetPathBuilder.starPolygon(points: 4, outerRadius: R * 0.14, innerRatio: 0.35, rotation: 0)
        let leftLine = MKAssetPathBuilder.ribbon(centerline: [CGPoint(x: -R, y: 0), CGPoint(x: -R * 0.22, y: 0)], widths: [0, R * 0.035])
        let rightLine = MKAssetPathBuilder.ribbon(centerline: [CGPoint(x: R * 0.22, y: 0), CGPoint(x: R, y: 0)], widths: [R * 0.035, 0])
        return descriptor(id: "diamond-dot-divider", nameAr: "فاصلة معينية منقطة", tags: ["فاصلة", "معين"], isPremium: false, geometry: .singleRegionAutoBounds(subpaths: [leftLine, diamond, rightLine]))
    }

    private static func vineDivider() -> MKAssetDescriptor {
        var centerline: [CGPoint] = []
        var widths: [Double] = []
        let steps = 30
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let x = -R + t * 2 * R
            let y = sin(t * 3 * .pi) * R * 0.1
            centerline.append(CGPoint(x: x, y: y))
            widths.append(R * 0.045)
        }
        var subpaths: [MKAssetSubpath] = [MKAssetPathBuilder.ribbon(centerline: centerline, widths: widths)]
        // Small leaf accents along the vine.
        for t in stride(from: 0.15, through: 0.85, by: 0.35) {
            let x = -R + t * 2 * R
            let y = sin(t * 3 * .pi) * R * 0.1
            let leafCenter = CGPoint(x: x, y: y - R * 0.12)
            subpaths.append(MKAssetPathBuilder.circle(center: leafCenter, radius: R * 0.05))
        }
        return descriptor(id: "vine-divider", nameAr: "فاصلة نباتية متعرشة", tags: ["فاصلة", "نباتي"], isPremium: false, geometry: .singleRegionAutoBounds(subpaths: subpaths))
    }

    private static func teardropFinial() -> MKAssetDescriptor {
        let apex = CGPoint(x: -R * 0.7, y: 0)
        let radius = R * 0.35
        var segments = MKAssetPathBuilder.arcSegments(center: CGPoint(x: R * 0.1, y: 0), radius: radius, startAngle: -.pi * 0.75, endAngle: .pi * 0.75)
        if let firstStart = segments.first?.start, let lastEnd = segments.last?.end {
            segments.append(MKBezierSegment(start: lastEnd, c1: lastEnd, c2: apex, end: apex))
            segments.append(MKBezierSegment(start: apex, c1: apex, c2: firstStart, end: firstStart))
        }
        let subpath = MKAssetSubpath(segments: segments, isClosed: true)
        return descriptor(id: "teardrop-finial", nameAr: "زخرفة نهاية دمعية", tags: ["زخرفة نهاية", "دمعة"], isPremium: true, geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }

    private static func knotMotif() -> MKAssetDescriptor {
        let radius = R * 0.32
        let loops = [CGPoint(x: -radius * 0.6, y: 0), CGPoint(x: radius * 0.6, y: 0)].map {
            MKAssetPathBuilder.ring(center: $0, outerRadius: radius, innerRadius: radius * 0.62)
        }.flatMap { $0 }
        return descriptor(id: "knot-motif", nameAr: "زخرفة عقدة", tags: ["عقدة", "تشابك"], isPremium: true, geometry: .singleRegionAutoBounds(subpaths: loops))
    }

    private static func swashFlourish(mirrored: Bool) -> MKAssetDescriptor {
        var centerline: [CGPoint] = []
        var widths: [Double] = []
        let steps = 30
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = t * .pi * 1.4
            let radius = R * 0.9 * (1 - t * 0.55)
            let sign: Double = mirrored ? -1 : 1
            centerline.append(CGPoint(x: sign * radius * cos(angle), y: radius * sin(angle) - R * 0.2))
            widths.append(R * 0.14 * (1 - t) + R * 0.01)
        }
        let subpath = MKAssetPathBuilder.ribbon(centerline: centerline, widths: widths)
        let id = mirrored ? "swash-flourish-right" : "swash-flourish-left"
        let name = mirrored ? "زخرفة تطريز يمنى" : "زخرفة تطريز يسرى"
        return descriptor(id: id, nameAr: name, tags: ["تطريز", "زخرفة خطية"], isPremium: true, geometry: .singleRegionAutoBounds(subpaths: [subpath]))
    }
}
