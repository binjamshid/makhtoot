import CoreGraphics
import MKFoundation

// WS-06 packet §5 task 6. Pure numeric math for the 8 resize handles + 1
// rotate handle: "handle drags compute anchored scaling (opposite
// handle/center with option), aspect lock (corner default proportional;
// edge free), rotation about selection center with angle snap." Everything
// here operates on `MKOrientedRect` (world-space OBB) and returns a NEW
// `MKOrientedRect` ، no UIKit, no gesture-recognizer types, so it is
// directly unit-testable (packet §7 gate: "handle transforms (numeric)").

/// The 8 resize handles (ARCHITECTURE §10.4) + the rotate knob. Placement
/// is RTL-agnostic (packet task 4: canvas geometry never mirrors) ، roles
/// are named by screen position in the node's own local (unrotated) frame.
public enum MKHandleRole: String, CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    case rotate

    /// Position of this handle on a unit square centered at the origin
    /// (`x`,`y` each in `-0.5...0.5`), before scaling by the OBB's actual
    /// size. The rotate knob sits above top-center (ARCHITECTURE §10.4: "1
    /// rotate knob"; packet task 4: "rotate handle above-top-center"),
    /// offset further out by `MKAnchoredResize.rotateKnobOffset` at render
    /// time ، the unit position here is only used to seed that offset
    /// direction.
    public var localUnitPosition: CGPoint {
        switch self {
        case .topLeft: return CGPoint(x: -0.5, y: -0.5)
        case .top: return CGPoint(x: 0, y: -0.5)
        case .topRight: return CGPoint(x: 0.5, y: -0.5)
        case .right: return CGPoint(x: 0.5, y: 0)
        case .bottomRight: return CGPoint(x: 0.5, y: 0.5)
        case .bottom: return CGPoint(x: 0, y: 0.5)
        case .bottomLeft: return CGPoint(x: -0.5, y: 0.5)
        case .left: return CGPoint(x: -0.5, y: 0)
        case .rotate: return CGPoint(x: 0, y: -0.5)
        }
    }

    public var affectsX: Bool {
        switch self {
        case .top, .bottom, .rotate: return false
        default: return true
        }
    }

    public var affectsY: Bool {
        switch self {
        case .left, .right, .rotate: return false
        default: return true
        }
    }

    /// Corner handles default to proportional (aspect-locked) resize; edge
    /// handles are free (packet task 6: "aspect lock (corner default
    /// proportional; edge free)").
    public var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft: return true
        default: return false
        }
    }
}

public enum MKAnchoredResize {
    /// SCREEN-space distance the rotate knob sits beyond the top edge.
    /// `MKSelectionHandleLayout.worldPosition(of:on:zoomScale:)` divides
    /// this by the live zoom scale, so the gap reads as a constant on
    /// screen at every zoom level (ARCHITECTURE §10.4 "handles
    /// scale-invariant") ، which is what this constant always claimed and
    /// never did.
    ///
    /// Bug fix (2026-07-29, user report: "rotate handle is too close to
    /// the middle top handle and doesn't work reliably"). This used to be
    /// applied as a flat WORLD offset, so zooming out collapsed the knob
    /// onto the top-center handle: at 0.3× the two sat ~8 screen points
    /// apart while each claimed a ≥32-point grab box, making which one you
    /// got a coin flip. Raised from 28 to 44 at the same time ، one full
    /// minimum touch target of clear space between the two, so their grab
    /// boxes no longer overlap at all now that both are screen-constant.
    public static let rotateKnobOffset: CGFloat = 44

    /// Anchored resize: `handle` is dragged by `worldDelta` (a translation
    /// vector in world/canvas space, already zoom-normalized by the
    /// caller). The point opposite `handle` (or the OBB's own center, when
    /// `fromCenter` is set ، the packet's "with option" alternate anchor)
    /// stays fixed. Corner handles honor `aspectLocked`; edge handles never
    /// change the perpendicular dimension regardless of `aspectLocked`
    /// (task 6: "edge free"). `minimumSize` floors both dimensions so a
    /// drag can never collapse/invert a node.
    public static func resize(
        _ obb: MKOrientedRect,
        handle: MKHandleRole,
        worldDelta: CGPoint,
        fromCenter: Bool = false,
        aspectLocked: Bool = false,
        minimumSize: CGFloat = 1
    ) -> MKOrientedRect {
        guard handle != .rotate else { return obb }

        let localDelta = rotateVector(worldDelta, by: -obb.rotation)
        let unitHandle = handle.localUnitPosition

        if fromCenter {
            var newWidth = obb.size.width
            var newHeight = obb.size.height
            if handle.affectsX { newWidth = max(minimumSize, abs(obb.size.width / 2 * sign(unitHandle.x) + localDelta.x) * 2) }
            if handle.affectsY { newHeight = max(minimumSize, abs(obb.size.height / 2 * sign(unitHandle.y) + localDelta.y) * 2) }
            if aspectLocked, handle.isCorner, obb.size.width > 0, obb.size.height > 0 {
                let scale = max(newWidth / obb.size.width, newHeight / obb.size.height)
                newWidth = max(minimumSize, obb.size.width * scale)
                newHeight = max(minimumSize, obb.size.height * scale)
            }
            return MKOrientedRect(center: obb.center, size: CGSize(width: newWidth, height: newHeight), rotation: obb.rotation)
        }

        let unitAnchor = CGPoint(x: -unitHandle.x, y: -unitHandle.y)
        let anchorLocal = CGPoint(x: unitAnchor.x * obb.size.width, y: unitAnchor.y * obb.size.height)
        let oldHandleLocal = CGPoint(x: unitHandle.x * obb.size.width, y: unitHandle.y * obb.size.height)

        var newHandleLocal = oldHandleLocal
        if handle.affectsX { newHandleLocal.x += localDelta.x }
        if handle.affectsY { newHandleLocal.y += localDelta.y }

        var newWidth = handle.affectsX ? abs(newHandleLocal.x - anchorLocal.x) : obb.size.width
        var newHeight = handle.affectsY ? abs(newHandleLocal.y - anchorLocal.y) : obb.size.height

        if aspectLocked, handle.isCorner, obb.size.width > 0, obb.size.height > 0 {
            let scaleX = newWidth / obb.size.width
            let scaleY = newHeight / obb.size.height
            let scale = max(scaleX, scaleY)
            newWidth = obb.size.width * scale
            newHeight = obb.size.height * scale
        }

        newWidth = max(minimumSize, newWidth)
        newHeight = max(minimumSize, newHeight)

        // Reconstruct the handle's final local position on the SAME side of
        // the anchor it started on, using the (possibly aspect-adjusted,
        // clamped) final size ، this is what keeps the anchor exactly fixed
        // regardless of aspect-lock/clamping adjustments.
        let dirX: CGFloat = unitHandle.x == 0 ? 0 : (unitHandle.x > 0 ? 1 : -1)
        let dirY: CGFloat = unitHandle.y == 0 ? 0 : (unitHandle.y > 0 ? 1 : -1)
        let finalHandleLocal = CGPoint(x: anchorLocal.x + dirX * newWidth, y: anchorLocal.y + dirY * newHeight)
        let newCenterLocal = CGPoint(x: (anchorLocal.x + finalHandleLocal.x) / 2, y: (anchorLocal.y + finalHandleLocal.y) / 2)
        let newWorldCenter = obb.localToWorld(newCenterLocal)

        return MKOrientedRect(center: newWorldCenter, size: CGSize(width: newWidth, height: newHeight), rotation: obb.rotation)
    }

    /// Rotation about the OBB's own center: `startPointerAngle`/
    /// `currentPointerAngle` are the world-space angles (radians, CCW
    /// positive, `atan2(dy, dx)` convention) from `obb.center` to the
    /// pointer at gesture-start and now; `startRotation` is the node's
    /// rotation when the gesture began. When `snapping` is enabled, the
    /// result snaps to 5° increments with magnetic pull toward the 0/45/90°
    /// family (task 6: "angle snap (5° increments while snapping on, plus
    /// exact 0/45/90 magnetics)").
    public static func rotate(
        startRotation: CGFloat,
        startPointerAngle: CGFloat,
        currentPointerAngle: CGFloat,
        snapping: Bool
    ) -> CGFloat {
        let delta = currentPointerAngle - startPointerAngle
        let raw = startRotation + delta
        return snapping ? snappedAngle(raw) : raw
    }

    /// Snaps `angle` (radians) to 5° grid increments, with a tighter
    /// magnetic pull toward the eight 45°-family cardinal/diagonal angles.
    public static func snappedAngle(
        _ angle: CGFloat,
        gridStep: CGFloat = 5 * .pi / 180,
        magneticThreshold: CGFloat = 2 * .pi / 180
    ) -> CGFloat {
        let normalized = MKGeometryMath.normalizeAngle(angle)
        let magneticAngles: [CGFloat] = (0..<8).map { CGFloat($0) * .pi / 4 }
        for magnet in magneticAngles {
            if abs(shortestAngleDelta(normalized, magnet)) <= magneticThreshold {
                return magnet
            }
        }
        let steps = (normalized / gridStep).rounded()
        return MKGeometryMath.normalizeAngle(steps * gridStep)
    }

    /// Shortest signed angular distance from `a` to `b`, both assumed
    /// already normalized to `[0, 2π)`, result in `(-π, π]`.
    static func shortestAngleDelta(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var diff = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
        if diff > .pi { diff -= 2 * .pi }
        if diff < -.pi { diff += 2 * .pi }
        return diff
    }

    /// Rotates a free vector (no translation) by `angle` radians, CCW
    /// positive ، used to bring a world-space drag delta into a node's
    /// local (unrotated) frame.
    static func rotateVector(_ v: CGPoint, by angle: CGFloat) -> CGPoint {
        let cosTheta = cos(angle)
        let sinTheta = sin(angle)
        return CGPoint(x: v.x * cosTheta - v.y * sinTheta, y: v.x * sinTheta + v.y * cosTheta)
    }

    private static func sign(_ v: CGFloat) -> CGFloat { v == 0 ? 0 : (v > 0 ? 1 : -1) }
}
