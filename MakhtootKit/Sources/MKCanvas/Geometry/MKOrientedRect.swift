import CoreGraphics
import MKFoundation

// WS-06 packet §5 tasks 4/6/9. `MKCanvas`'s canonical oriented-bounding-box
// (OBB) type: every selection outline, resize/rotate handle, marquee
// candidate, and snap candidate is expressed in this shape. `MKModel`
// doesn't carry a node "size" field (D-111's `MKNodeCore` is transform +
// z-order + opacity + style only ، content extent is a rendering concern),
// so `MKCanvas` treats world-space size as data supplied by whichever
// geometry source produced the OBB (in production, WS-07's render-tree
// geometry via `MKCanvasGeometrySource`, §`Geometry/MKCanvasGeometrySource.swift`;
// in tests, synthetic values) rather than trying to derive it from `MKNode`
// itself.
//
// Convention: `rotation` is radians, counter-clockwise positive (matches
// `MKTransform2D.rotation`, CoreGraphics convention, D-111/ARCHITECTURE
// §10.4's "الاتجاه الموجب عكس عقارب الساعة" inspector note).
public struct MKOrientedRect: Hashable, Sendable {
    public var center: CGPoint
    public var size: CGSize
    public var rotation: CGFloat

    public init(center: CGPoint, size: CGSize, rotation: CGFloat) {
        self.center = center
        self.size = size
        self.rotation = rotation
    }

    /// Builds the OBB a node with `localBounds` (in the node's own
    /// unrotated local space, typically `CGRect(origin: .zero, size: ...)`)
    /// occupies after `transform` maps it into parent/world space.
    public init(localBounds: CGRect, transform: MKTransform2D) {
        let localCenter = CGPoint(x: localBounds.midX, y: localBounds.midY)
        self.center = transform.apply(to: localCenter)
        self.size = CGSize(
            width: localBounds.width * abs(transform.scale.width),
            height: localBounds.height * abs(transform.scale.height)
        )
        self.rotation = transform.rotation
    }

    /// The four corners in world space, in a fixed winding order starting
    /// from the local top-left (`(-w/2, -h/2)`) and proceeding clockwise in
    /// the local (pre-rotation) frame: topLeft, topRight, bottomRight,
    /// bottomLeft.
    public var corners: [CGPoint] {
        let hw = size.width / 2
        let hh = size.height / 2
        let local: [CGPoint] = [
            CGPoint(x: -hw, y: -hh), // topLeft
            CGPoint(x: hw, y: -hh),  // topRight
            CGPoint(x: hw, y: hh),   // bottomRight
            CGPoint(x: -hw, y: hh),  // bottomLeft
        ]
        let cosTheta = cos(rotation)
        let sinTheta = sin(rotation)
        return local.map { p in
            CGPoint(
                x: center.x + p.x * cosTheta - p.y * sinTheta,
                y: center.y + p.x * sinTheta + p.y * cosTheta
            )
        }
    }

    /// Axis-aligned bounding box of `corners` ، the cheap-reject / marquee-
    /// intersection shape (ARCHITECTURE §10.3 step 2: "cheap reject: local-
    /// space bounding box").
    public var axisAlignedBounds: CGRect {
        let pts = corners
        let xs = pts.map(\.x)
        let ys = pts.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else {
            return .zero
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Maps a world-space point into this OBB's local (unrotated,
    /// center-origin) frame ، the standard trick for exact point-in-
    /// rotated-rect tests and anchor-preserving resize math (ARCHITECTURE
    /// §10.3 step 1: "transform `p` by the inverse affine into node-local
    /// space").
    public func worldToLocal(_ p: CGPoint) -> CGPoint {
        let dx = p.x - center.x
        let dy = p.y - center.y
        let cosTheta = cos(-rotation)
        let sinTheta = sin(-rotation)
        return CGPoint(x: dx * cosTheta - dy * sinTheta, y: dx * sinTheta + dy * cosTheta)
    }

    /// Maps a point in this OBB's local (unrotated, center-origin) frame
    /// back into world space ، the inverse of `worldToLocal`.
    public func localToWorld(_ p: CGPoint) -> CGPoint {
        let cosTheta = cos(rotation)
        let sinTheta = sin(rotation)
        return CGPoint(x: center.x + p.x * cosTheta - p.y * sinTheta, y: center.y + p.x * sinTheta + p.y * cosTheta)
    }

    /// Exact rotated-rect hit test with a screen-space `tolerance` inflation
    /// (ARCHITECTURE §10.3: "44 pt minimum touch slop", tolerance supplied
    /// by the caller already zoom-adjusted).
    public func contains(_ p: CGPoint, tolerance: CGFloat = 0) -> Bool {
        let local = worldToLocal(p)
        let hw = size.width / 2 + tolerance
        let hh = size.height / 2 + tolerance
        return abs(local.x) <= hw && abs(local.y) <= hh
    }

    /// The inverse of `init(localBounds:transform:)`: given the node's
    /// INTRINSIC (unscaled) local bounds, returns the `MKTransform2D` that
    /// would produce `self` as that node's world OBB. Used by
    /// `HandleGestures` to turn a resized/rotated OBB back into a concrete
    /// node transform ، `localBounds` only needs to be consistent between
    /// calls (callers typically derive it once at gesture-start as
    /// `currentOBB.size / currentTransform.scale`, at the local origin),
    /// not any particular render-defined content rect.
    public func derivingTransform(localBounds: CGRect) -> MKTransform2D {
        let scaleWidth = localBounds.width > 0 ? size.width / localBounds.width : 1
        let scaleHeight = localBounds.height > 0 ? size.height / localBounds.height : 1
        let scale = CGSize(width: scaleWidth, height: scaleHeight)
        let localCenter = CGPoint(x: localBounds.midX, y: localBounds.midY)
        let scaledLocalCenter = CGPoint(x: localCenter.x * scale.width, y: localCenter.y * scale.height)
        let cosTheta = cos(rotation)
        let sinTheta = sin(rotation)
        let rotated = CGPoint(
            x: scaledLocalCenter.x * cosTheta - scaledLocalCenter.y * sinTheta,
            y: scaledLocalCenter.x * sinTheta + scaledLocalCenter.y * cosTheta
        )
        let position = CGPoint(x: center.x - rotated.x, y: center.y - rotated.y)
        return MKTransform2D(position: position, rotation: rotation, scale: scale)
    }

    /// Smallest axis-aligned rect containing every OBB's corners ، used for
    /// multi-selection union bounds (ARCHITECTURE §10.4: "derived
    /// `selectionBounds` (union of world-space OBBs)"). Multi-selection
    /// bounds are always reported axis-aligned (never itself rotated),
    /// matching how every mainstream canvas editor shows a multi-select
    /// bounding box.
    public static func unionBounds(of rects: [MKOrientedRect]) -> CGRect? {
        guard !rects.isEmpty else { return nil }
        return rects.reduce(CGRect?.none) { partial, rect in
            let bounds = rect.axisAlignedBounds
            guard let partial else { return bounds }
            return partial.union(bounds)
        }
    }
}
