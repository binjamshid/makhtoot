import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 task 8. ≥8 pattern-background tiles. ALL premium
// (D-215/T8: BRIEF Q34 "free tier = solid colors only" extends to pattern
// backgrounds ، see `Resources/ASSET_SOURCING_RULES.md` and
// `docs/impl-log/WS-14.md` ADR WS-14-A2). Each tile is authored twice over:
// as an `MKAssetDescriptor` (category `.patternBackgrounds`, `pathData` =
// ONE tile unit's geometry ، feeds the browser grid + thumbnail's "2×2 tile
// preview," T10) and as a companion `MKPatternFill` (tile size, repeat
// mode, default colors ، T8's literal model) keyed by the same `assetID` in
// `MKPatternFillLibrary`. `MKPatternInstantiator` (T3/T8) joins the two at
// placement time.
public enum MKPatternTileGenerator {
    private static let tile: Double = 40

    /// `(descriptor, fill)` pairs ، one per tile, in this file's declared
    /// order (matches the packet's task 8 listing order).
    public static func makeAll() -> [(descriptor: MKAssetDescriptor, fill: MKPatternFill)] {
        [
            hexagonalLattice(), star8Tessellation(), zellijInterlock(), diagonalQanatLines(),
            dotGrid(), chevron(), scallop(), khatamRepeat(),
        ]
    }

    private static func make(id: String, nameAr: String, tags: [String], geometry: MKAssetGeometry, repeatMode: MKPatternRepeatMode) -> (MKAssetDescriptor, MKPatternFill) {
        let descriptor = MKAssetDescriptor(
            assetID: "pattern.\(id)", nameAr: nameAr, category: .patternBackgrounds, tags: tags,
            isPremium: true, pathData: geometry, provenanceRef: "pattern.\(id)"
        )
        let fill = MKPatternFill(
            tile: MKPatternTile(geometry: geometry, tileSize: CGSize(width: tile, height: tile)),
            repeatMode: repeatMode,
            backgroundColor: .white,
            motifColor: .defaultInk
        )
        return (descriptor, fill)
    }

    private static func hexagonalLattice() -> (MKAssetDescriptor, MKPatternFill) {
        let radius = tile * 0.46
        let outer = MKAssetPathBuilder.regularPolygon(sides: 6, radius: radius, rotation: 0)
        let inner = MKAssetPathBuilder.regularPolygon(sides: 6, radius: radius * 0.86, rotation: 0)
        let reversedInner = MKAssetSubpath(segments: inner.segments.reversed().map { MKBezierSegment(start: $0.end, c1: $0.c2, c2: $0.c1, end: $0.start) }, isClosed: true)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [outer, reversedInner])
        return make(id: "hexagonal-lattice", nameAr: "شبكة سداسية", tags: ["نمط", "سداسي", "هندسي"], geometry: geometry, repeatMode: .grid)
    }

    private static func star8Tessellation() -> (MKAssetDescriptor, MKPatternFill) {
        let star = MKAssetPathBuilder.starPolygon(points: 8, outerRadius: tile * 0.46, innerRatio: 0.42)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [star])
        return make(id: "star-8-tessellation", nameAr: "تجانب نجمي ثماني", tags: ["نمط", "نجمة", "إسلامي"], geometry: geometry, repeatMode: .grid)
    }

    private static func zellijInterlock() -> (MKAssetDescriptor, MKPatternFill) {
        let a = MKAssetPathBuilder.ribbon(centerline: [CGPoint(x: -tile / 2, y: -tile / 2), CGPoint(x: tile / 2, y: tile / 2)], widths: [tile * 0.14, tile * 0.14])
        let b = MKAssetPathBuilder.ribbon(centerline: [CGPoint(x: -tile / 2, y: tile / 2), CGPoint(x: tile / 2, y: -tile / 2)], widths: [tile * 0.14, tile * 0.14])
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [a, b])
        return make(id: "zellij-interlock", nameAr: "تشابك زليج", tags: ["نمط", "زليج", "تشابك"], geometry: geometry, repeatMode: .halfDrop)
    }

    private static func diagonalQanatLines() -> (MKAssetDescriptor, MKPatternFill) {
        let lines = [-0.5, 0.0, 0.5].map { offset -> MKAssetSubpath in
            let o = offset * tile
            return MKAssetPathBuilder.ribbon(
                centerline: [CGPoint(x: -tile / 2 + o, y: -tile / 2), CGPoint(x: tile / 2 + o, y: tile / 2)], widths: [tile * 0.05, tile * 0.05]
            )
        }
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: lines)
        return make(id: "diagonal-qanat-lines", nameAr: "خطوط قناة قطرية", tags: ["نمط", "خطوط", "هندسي"], geometry: geometry, repeatMode: .grid)
    }

    private static func dotGrid() -> (MKAssetDescriptor, MKPatternFill) {
        let dot = MKAssetPathBuilder.circle(center: .zero, radius: tile * 0.09)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [dot])
        return make(id: "dot-grid", nameAr: "شبكة نقاط", tags: ["نمط", "نقاط", "هندسي"], geometry: geometry, repeatMode: .grid)
    }

    private static func chevron() -> (MKAssetDescriptor, MKPatternFill) {
        let points = [
            CGPoint(x: -tile / 2, y: -tile * 0.2), CGPoint(x: 0, y: tile * 0.25), CGPoint(x: tile / 2, y: -tile * 0.2),
        ]
        let subpath = MKAssetPathBuilder.ribbon(centerline: points, widths: [tile * 0.09, tile * 0.09, tile * 0.09])
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [subpath])
        return make(id: "chevron", nameAr: "نمط متعرج (شيفرون)", tags: ["نمط", "متعرج", "هندسي"], geometry: geometry, repeatMode: .grid)
    }

    /// فلس (scallop/fish-scale) ، a stack of overlapping shallow arcs.
    private static func scallop() -> (MKAssetDescriptor, MKPatternFill) {
        let radius = tile * 0.5
        var segments = MKAssetPathBuilder.arcSegments(center: CGPoint(x: 0, y: tile * 0.35), radius: radius, startAngle: .pi, endAngle: 2 * .pi)
        if let firstStart = segments.first?.start, let lastEnd = segments.last?.end {
            segments.append(MKBezierSegment(start: lastEnd, c1: lastEnd, c2: firstStart, end: firstStart))
        }
        let subpath = MKAssetSubpath(segments: segments, isClosed: true)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [subpath])
        return make(id: "scallop", nameAr: "نمط الفلس", tags: ["نمط", "فلس", "هندسي"], geometry: geometry, repeatMode: .halfDrop)
    }

    /// ختم (khatam) repeat ، an 8-fold star medallion with a bounding ring,
    /// the classic khatam-style tessellation unit.
    private static func khatamRepeat() -> (MKAssetDescriptor, MKPatternFill) {
        let star = MKAssetPathBuilder.starPolygon(points: 8, outerRadius: tile * 0.38, innerRatio: 0.55)
        let ring = MKAssetPathBuilder.ring(center: .zero, outerRadius: tile * 0.48, innerRadius: tile * 0.44)
        let geometry = MKAssetGeometry.singleRegionAutoBounds(subpaths: [star] + ring)
        return make(id: "khatam-repeat", nameAr: "تكرار ختامي", tags: ["نمط", "ختم", "إسلامي"], geometry: geometry, repeatMode: .grid)
    }
}
