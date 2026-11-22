import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 task 6. ≥8 frames, ≥3 free. Every frame is a hollow
// border silhouette (outer boundary minus an inset boundary, the two
// wound in opposite directions so the nonzero fill rule alone produces the
// hole ، same discipline `MKAssetGeometry`'s header documents for the
// crescent). Non-uniform scale ("stretch edges, keep corners fixed") is
// NOT implemented in v1 ، `MKFrameNineSliceInsets` records the seam per
// the task's accept criterion ("non-uniform-scale behavior documented");
// every frame here places/transforms correctly under UNIFORM scale only.
public enum MKFrameGenerator {
    private static let R = MKAssetUnits.half * 0.92

    public static func makeAll() -> [MKAssetDescriptor] {
        [
            rectSingleRule(), rectDoubleRule(), circularFrame(),
            rectThickThin(), cornerOrnamentedFrame(), archFrame(), ovalFrame(), cartoucheOutline(),
        ]
    }

    private static func descriptor(id: String, nameAr: String, tags: [String], isPremium: Bool, geometry: MKAssetGeometry, nineSlice: MKFrameNineSliceInsets? = nil) -> MKAssetDescriptor {
        MKAssetDescriptor(
            assetID: "frame.\(id)", nameAr: nameAr, category: .frames, tags: tags,
            isPremium: isPremium, pathData: geometry, provenanceRef: "frame.\(id)", nineSliceInsets: nineSlice
        )
    }

    /// Outer rect boundary (one winding direction) + an inset rect boundary
    /// (opposite winding) ، a rectangular "picture frame" ring of
    /// `thickness`.
    private static func rectRing(outer: CGRect, thickness: Double) -> [MKAssetSubpath] {
        let outerPath = MKAssetPathBuilder.polyline(
            [CGPoint(x: outer.minX, y: outer.minY), CGPoint(x: outer.maxX, y: outer.minY), CGPoint(x: outer.maxX, y: outer.maxY), CGPoint(x: outer.minX, y: outer.maxY)],
            closed: true
        )
        let inner = outer.insetBy(dx: thickness, dy: thickness)
        // Reversed point order (opposite winding) for the inset boundary.
        let innerPath = MKAssetPathBuilder.polyline(
            [CGPoint(x: inner.minX, y: inner.maxY), CGPoint(x: inner.maxX, y: inner.maxY), CGPoint(x: inner.maxX, y: inner.minY), CGPoint(x: inner.minX, y: inner.minY)],
            closed: true
        )
        return [outerPath, innerPath]
    }

    private static func ellipseRing(rx: Double, ry: Double, thickness: Double) -> [MKAssetSubpath] {
        func scaled(_ subpath: MKAssetSubpath, sx: Double, sy: Double) -> MKAssetSubpath {
            MKAssetSubpath(
                segments: subpath.segments.map {
                    MKBezierSegment(
                        start: CGPoint(x: $0.start.x * sx, y: $0.start.y * sy), c1: CGPoint(x: $0.c1.x * sx, y: $0.c1.y * sy),
                        c2: CGPoint(x: $0.c2.x * sx, y: $0.c2.y * sy), end: CGPoint(x: $0.end.x * sx, y: $0.end.y * sy)
                    )
                }, isClosed: subpath.isClosed
            )
        }
        let outer = scaled(MKAssetPathBuilder.circle(center: .zero, radius: 1), sx: rx, sy: ry)
        let inner = scaled(MKAssetPathBuilder.circle(center: .zero, radius: 1, reversed: true), sx: rx - thickness, sy: ry - thickness)
        return [outer, inner]
    }

    private static func rectSingleRule() -> MKAssetDescriptor {
        let outer = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)
        let thickness = R * 0.06
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: rectRing(outer: outer, thickness: thickness))
        return descriptor(id: "rect-single-rule", nameAr: "إطار مستطيل بخط واحد", tags: ["إطار", "مستطيل", "هندسي"], isPremium: false, geometry: geometry, nineSlice: .uniform(thickness))
    }

    private static func rectDoubleRule() -> MKAssetDescriptor {
        let outer = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)
        let ringA = rectRing(outer: outer, thickness: R * 0.05)
        let ringB = rectRing(outer: outer.insetBy(dx: R * 0.12, dy: R * 0.12), thickness: R * 0.05)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: ringA + ringB)
        return descriptor(id: "rect-double-rule", nameAr: "إطار مستطيل بخطين", tags: ["إطار", "مستطيل", "هندسي"], isPremium: false, geometry: geometry, nineSlice: .uniform(R * 0.17))
    }

    private static func circularFrame() -> MKAssetDescriptor {
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: MKAssetPathBuilder.ring(center: .zero, outerRadius: R, innerRadius: R * 0.9))
        return descriptor(id: "circular", nameAr: "إطار دائري", tags: ["إطار", "دائري", "هندسي"], isPremium: false, geometry: geometry)
    }

    private static func rectThickThin() -> MKAssetDescriptor {
        let outer = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)
        let thick = rectRing(outer: outer, thickness: R * 0.12)
        let thin = rectRing(outer: outer.insetBy(dx: R * 0.2, dy: R * 0.2), thickness: R * 0.03)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: thick + thin)
        return descriptor(id: "rect-thick-thin", nameAr: "إطار مستطيل سميك ورفيع", tags: ["إطار", "مستطيل", "هندسي"], isPremium: true, geometry: geometry, nineSlice: .uniform(R * 0.23))
    }

    private static func cornerOrnamentedFrame() -> MKAssetDescriptor {
        let outer = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)
        let thickness = R * 0.06
        var subpaths = rectRing(outer: outer, thickness: thickness)
        let cornerRadius = R * 0.16
        for (dx, dy) in [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)] {
            let center = CGPoint(x: dx * R, y: dy * R)
            subpaths.append(MKAssetPathBuilder.circle(center: center, radius: cornerRadius))
            subpaths.append(contentsOf: MKAssetPathBuilder.ring(center: center, outerRadius: cornerRadius * 1.6, innerRadius: cornerRadius * 1.4))
        }
        // composition at authoring time (packet's own wording, task 6): the
        // corner motifs are baked into this ONE asset's path data ، this is
        // still a single placeable object, never a multi-object template.
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: subpaths)
        return descriptor(id: "corner-ornamented", nameAr: "إطار بزخارف ركنية", tags: ["إطار", "زخرفة ركنية", "إسلامي"], isPremium: true, geometry: geometry, nineSlice: .uniform(R * 0.3))
    }

    private static func archFrame() -> MKAssetDescriptor {
        // Two-centered POINTED arch (`MKAssetPathBuilder.pointedArchSegments`
        // ، see that function's doc comment; the first-draft smooth-Bézier
        // blend rendered as a rounded dome, not a point, caught by visual
        // QA, `docs/impl-log/WS-14.md`).
        let bodyWidth = R * 1.3
        let bodyTop = -R * 0.05
        func archOutline(scale: Double) -> [MKBezierSegment] {
            let w = bodyWidth * scale
            let top = bodyTop * scale
            let leftSpring = CGPoint(x: -w / 2, y: top)
            let rightSpring = CGPoint(x: w / 2, y: top)
            let bottom = R * scale
            var segments = MKAssetPathBuilder.pointedArchSegments(leftSpring: leftSpring, rightSpring: rightSpring)
            let bottomRight = CGPoint(x: w / 2, y: bottom)
            let bottomLeft = CGPoint(x: -w / 2, y: bottom)
            segments.append(MKBezierSegment(start: rightSpring, c1: rightSpring, c2: bottomRight, end: bottomRight))
            segments.append(MKBezierSegment(start: bottomRight, c1: bottomRight, c2: bottomLeft, end: bottomLeft))
            segments.append(MKBezierSegment(start: bottomLeft, c1: bottomLeft, c2: leftSpring, end: leftSpring))
            return segments
        }
        let outerSubpath = MKAssetSubpath(segments: archOutline(scale: 1.0), isClosed: true)
        let innerSubpath = MKAssetSubpath(segments: archOutline(scale: 0.85).reversed().map { MKBezierSegment(start: $0.end, c1: $0.c2, c2: $0.c1, end: $0.start) }, isClosed: true)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [outerSubpath, innerSubpath])
        return descriptor(id: "arch", nameAr: "إطار عقد مدبب", tags: ["إطار", "عقد", "معماري", "إسلامي"], isPremium: true, geometry: geometry)
    }

    private static func ovalFrame() -> MKAssetDescriptor {
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: ellipseRing(rx: R, ry: R * 0.68, thickness: R * 0.07))
        return descriptor(id: "oval", nameAr: "إطار بيضاوي", tags: ["إطار", "بيضاوي", "هندسي"], isPremium: true, geometry: geometry)
    }

    private static func cartoucheOutline() -> MKAssetDescriptor {
        let left = CGPoint(x: -R, y: 0)
        let right = CGPoint(x: R, y: 0)
        func lens(halfWidth: Double, bulge: Double) -> [MKBezierSegment] {
            let l = CGPoint(x: -halfWidth, y: 0)
            let r = CGPoint(x: halfWidth, y: 0)
            return [
                MKBezierSegment(start: l, c1: CGPoint(x: -halfWidth * 0.5, y: -bulge), c2: CGPoint(x: halfWidth * 0.5, y: -bulge), end: r),
                MKBezierSegment(start: r, c1: CGPoint(x: halfWidth * 0.5, y: bulge), c2: CGPoint(x: -halfWidth * 0.5, y: bulge), end: l),
            ]
        }
        _ = left; _ = right
        let outer = MKAssetSubpath(segments: lens(halfWidth: R, bulge: R * 0.42), isClosed: true)
        let innerSegments = lens(halfWidth: R * 0.86, bulge: R * 0.3).reversed().map { MKBezierSegment(start: $0.end, c1: $0.c2, c2: $0.c1, end: $0.start) }
        let inner = MKAssetSubpath(segments: innerSegments, isClosed: true)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [outer, inner])
        return descriptor(id: "cartouche", nameAr: "إطار مخطوطة (كارتوش)", tags: ["كارتوش", "مخطوطة", "زخرفة"], isPremium: true, geometry: geometry)
    }
}
