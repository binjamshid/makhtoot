import CoreGraphics
import Foundation
import MKModel

// WS-14 packet §5 task 1/3. `MKAssetGeometry` is the AUTHORING-time vector
// representation (subpaths + fill rule + styleable regions) the packet's
// task 1 literally names for `MKAssetDescriptor.pathData`. It is a richer,
// MKAssets-owned type layered ON TOP of `MKModel.MKBezierSegment` (reused
// directly, not re-invented ، `MKAssets` already depends on `MKModel`) ،
// `MKAssetGeometry.toPathData()` is the one-way lowering into
// `MKModel.MKPathData`, the flat op-stream `MKShapeGeometry.path(_:)`
// actually stores and `MKRender`'s already-shipped `ShapeDrawer` already
// knows how to draw (verified by reading `Sources/MKRender/Drawers/
// ShapeDrawer.swift`: `.path(let pathData): pathData.cgPath(at:
// pathData.unitsPerEm)`).
//
// **Fill-rule note (the crescent/hole problem, task 4's accept criterion
// "crescent renders correct even-odd fill").** `MKModel`/`MKRender` do not
// carry a fill-rule field anywhere in the shipped schema ، `StylePainting
// .paint` calls the CoreGraphics default `ctx.fillPath()`, i.e. the
// **nonzero winding** rule, always. Adding a fill-rule field is a `MKModel`
// schema change outside this run's fence (`MKAssets sources/tests/
// resources` only ، see this module's README "MKModel coordination note"
// section for the exact proposed addition). Rather than block on that,
// every asset in this library that needs a "hole" (crescent, rosette
// counters, mandorla, …) is authored so the nonzero rule ALONE produces the
// correct result: the outer subpath and any inner "hole" subpath are wound
// in OPPOSITE directions (`MKAssetPathBuilder.circle(..., reversed:)`), so
// their winding numbers cancel over the overlap (`+1` outer, `-1` inner ⇒
// `0` ⇒ excluded) exactly as the even-odd rule would have excluded it ،
// verified per-asset by `MKAssetThumbnailRendererTests`/`MKBasicShapesTests`
// rasterizing a known hole point and asserting it is NOT painted. The
// `fillRule` field below is still recorded (Codable, per task 1's literal
// field list) as authored INTENT/documentation and for a future consumer
// that does gain a real even-odd rule; `toPathData()` does not need to
// consult it because winding-direction discipline already makes nonzero
// fill produce the intended picture.
public enum MKAssetFillRule: String, Hashable, Sendable, Codable {
    case nonZero
    case evenOdd
}

/// One closed or open sub-path: an ordered list of cubic Bézier segments
/// (straight lines are represented the same way `MKBezierPathData`/
/// `MKPathData` already do ، `c1 == start` and `c2 == end` degenerates the
/// cubic formula to a line, OR `toPathData()` below emits a compact line-op
/// when it detects that degenerate case, whichever is more compact).
public struct MKAssetSubpath: Hashable, Sendable, Codable, Equatable {
    public var segments: [MKBezierSegment]
    public var isClosed: Bool

    public init(segments: [MKBezierSegment], isClosed: Bool) {
        self.segments = segments
        self.isClosed = isClosed
    }
}

/// A named group of subpath indices sharing one fill (task 1: "default
/// styleable regions"). v1 asset authoring is single-region only ، every
/// asset in this library's `regions` array has exactly one entry spanning
/// every subpath ، so it instantiates as ONE `MKShapeNode` with one
/// `MKStyle.fill` (matching how `MKAssetInstantiator.place(asset:)`, T3,
/// produces a single plain shape node). Multi-region (multi-color) assets
/// are a documented, modeled, but unauthored v1 seam: a hypothetical future
/// asset with >1 region would need to instantiate as a `.group` of several
/// `.shape` nodes (one per region) rather than one shape node ، the model
/// supports recording that need today; nothing in this library's v1 set
/// uses it (PRD R-11.3: "multi-color assets expose per-region fills where
/// authored as such" ، none are, in v1).
public struct MKAssetStyleableRegion: Hashable, Sendable, Codable, Equatable {
    public var name: String
    public var subpathIndices: [Int]
    public var fillRule: MKAssetFillRule

    public init(name: String, subpathIndices: [Int], fillRule: MKAssetFillRule = .nonZero) {
        self.name = name
        self.subpathIndices = subpathIndices
        self.fillRule = fillRule
    }
}

/// The full authored geometry for one asset (task 1's `MKAssetGeometry`):
/// subpaths + fill rule (recorded per-region) + default styleable regions,
/// plus the authored local bounding box (`localBounds`) that
/// `MKAssetDescriptor.defaultAspect` derives from and that
/// `MKAssetInstantiator` uses to size the placed node's default transform.
public struct MKAssetGeometry: Hashable, Sendable, Codable, Equatable {
    public var subpaths: [MKAssetSubpath]
    public var regions: [MKAssetStyleableRegion]
    public var localBounds: CGRect

    public init(subpaths: [MKAssetSubpath], regions: [MKAssetStyleableRegion], localBounds: CGRect) {
        self.subpaths = subpaths
        self.regions = regions
        self.localBounds = localBounds
    }

    /// Single-region convenience: every subpath in one region named
    /// "الكل" (all), the shape every v1-authored asset actually uses.
    public static func singleRegion(subpaths: [MKAssetSubpath], localBounds: CGRect, fillRule: MKAssetFillRule = .nonZero) -> MKAssetGeometry {
        MKAssetGeometry(
            subpaths: subpaths,
            regions: [MKAssetStyleableRegion(name: "الكل", subpathIndices: Array(subpaths.indices), fillRule: fillRule)],
            localBounds: localBounds
        )
    }

    /// Same as `singleRegion(subpaths:localBounds:fillRule:)` but computes
    /// `localBounds` from the subpaths' own painted-path bounding box
    /// (`CGPath.boundingBoxOfPath`) instead of requiring the caller to
    /// state it ، every generator (`MKBasicShapeGenerator`,
    /// `MKOrnamentGenerator`, …) uses this so a hand-tuned radius/offset
    /// never silently drifts out of sync with a manually-typed bounds rect.
    public static func singleRegionAutoBounds(subpaths: [MKAssetSubpath], fillRule: MKAssetFillRule = .nonZero) -> MKAssetGeometry {
        let probe = MKAssetGeometry(subpaths: subpaths, regions: [], localBounds: .zero)
        let bounds = probe.cgPath().boundingBoxOfPath
        return singleRegion(subpaths: subpaths, localBounds: bounds, fillRule: fillRule)
    }

    /// Lowers this authoring-time geometry into `MKModel.MKPathData` ، the
    /// flat op-stream `MKShapeGeometry.path(_:)` stores and the already-shipped
    /// `MKRender.ShapeDrawer` already draws (§3.6/`ShapeDrawer.localPath`:
    /// `pathData.cgPath(at: pathData.unitsPerEm)`, i.e. rendered 1:1 at
    /// `unitsPerEm`). `unitsPerEm` is the authoring canvas size in points ،
    /// every generator in this module authors within a
    /// `unitsPerEm`×`unitsPerEm` local box (v1 constant, `MKAssetUnits.em`)
    /// so a placed asset's default on-canvas footprint is exactly
    /// `localBounds.size` points before any user transform scale.
    public func toPathData(unitsPerEm: Double = MKAssetUnits.em) -> MKPathData {
        var commands: [Double] = []
        for subpath in subpaths {
            guard let first = subpath.segments.first else { continue }
            commands.append(contentsOf: [0, first.start.x, first.start.y]) // move
            for segment in subpath.segments {
                if segment.c1 == segment.start, segment.c2 == segment.end {
                    commands.append(contentsOf: [1, segment.end.x, segment.end.y]) // line
                } else {
                    commands.append(contentsOf: [
                        3, segment.c1.x, segment.c1.y, segment.c2.x, segment.c2.y, segment.end.x, segment.end.y,
                    ]) // cubic
                }
            }
            if subpath.isClosed { commands.append(4) } // close
        }
        return MKPathData(commands: commands.map { (($0 * 100).rounded()) / 100 }, unitsPerEm: unitsPerEm)
    }

    /// Builds a `CGPath` directly (used by the internal thumbnail
    /// rasterizer, `MKAssetThumbnailRenderer`, and by tests that need to
    /// pixel-verify winding/hole behavior without going through
    /// `MKModel`/`MKRender` at all).
    public func cgPath() -> CGPath {
        let path = CGMutablePath()
        for subpath in subpaths {
            guard let first = subpath.segments.first else { continue }
            path.move(to: first.start)
            for segment in subpath.segments {
                path.addCurve(to: segment.end, control1: segment.c1, control2: segment.c2)
            }
            if subpath.isClosed { path.closeSubpath() }
        }
        return path
    }
}

/// The authoring-canvas convention every generator in this module shares:
/// paths are authored inside a `em`×`em` local box centered at the origin
/// (`-em/2 ... em/2` on both axes), matching `MKBezierPathData`/`MKPathData`'s
/// existing `unitsPerEm = 1000` glyph-scale CONVENTION in spirit, but at a
/// smaller constant (`100`) appropriate for a directly-placed shape (not a
/// glyph outline scaled by point size) ، chosen so a freshly placed asset's
/// default on-canvas footprint is a comfortable ~100×100pt box before the
/// user resizes it via the node transform's `scale` (§WS-07 "unit-square
/// local space, size via transform.scale" convention ، this module's analog
/// for non-unit-square freeform paths, whose OWN absolute local points
/// already carry footprint size per `ShapeDrawer`'s documented case split).
public enum MKAssetUnits {
    public static let em: Double = 100
    public static let half: Double = em / 2
}
