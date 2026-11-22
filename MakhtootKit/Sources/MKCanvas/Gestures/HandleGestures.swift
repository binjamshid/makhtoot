import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 task 6: "handle drags compute anchored scaling (opposite
// handle/center with option), aspect lock (corner default proportional;
// edge free), rotation about selection center with angle snap (5°
// increments while snapping on, plus exact 0/45/90 magnetics); pinch/
// rotate two-finger equivalents on selection. All coalesced." Single-node
// resize/rotate operates in that node's own rotated local space (via
// `MKOrientedRect`/`MKAnchoredResize`, "anchor math in node-local space").
// Multi-select resize/rotate operates about the (always axis-aligned)
/// selection union bounds, matching every mainstream canvas editor's
// "resize/rotate the group as a rigid whole" behavior.
@MainActor
public final class HandleGestures {
    private var gestureID: UUID?
    private var handle: MKHandleRole?
    private var startOBBs: [MKNodeID: MKOrientedRect] = [:]
    private var startTransforms: [MKNodeID: MKTransform2D] = [:]
    private var intrinsicBounds: [MKNodeID: CGRect] = [:]
    private var groupBounds: CGRect = .zero
    private var rotationCenter: CGPoint = .zero
    private var startPointerAngle: CGFloat = 0

    public init() {}

    public var isActive: Bool { gestureID != nil }

    // MARK: - Resize

    public func beginResize(session: CanvasSession, handle: MKHandleRole) {
        guard !session.selection.isEmpty, let geometrySource = session.geometrySource else { return }
        gestureID = UUID()
        self.handle = handle
        startOBBs.removeAll()
        startTransforms.removeAll()
        intrinsicBounds.removeAll()
        for id in session.selection.ids {
            guard let obb = geometrySource.worldOBB(for: id, in: session.scene),
                  let transform = session.scene.node(id: id)?.core.transform else { continue }
            startOBBs[id] = obb
            startTransforms[id] = transform
            intrinsicBounds[id] = Self.intrinsicBounds(
                for: id, obb: obb, transform: transform, geometrySource: geometrySource, scene: session.scene)
        }
        groupBounds = MKOrientedRect.unionBounds(of: Array(startOBBs.values)) ?? .zero
        session.beginGesture()
    }

    /// `worldDelta` is the drag vector since gesture start, in canvas
    /// space. `fromCenter`/`aspectLocked` mirror the packet's "opposite
    /// handle/center with option" and "corner default proportional; edge
    /// free" ، callers pass the live modifier-key/UI-toggle state each
    /// frame.
    public func updateResize(session: CanvasSession, worldDelta: CGPoint, fromCenter: Bool = false, aspectLocked: Bool? = nil) {
        guard let gestureID, let handle else { return }
        var newTransforms: [MKNodeID: MKTransform2D] = [:]

        if startOBBs.count == 1, let onlyID = startOBBs.keys.first, let obb = startOBBs[onlyID] {
            let locked = aspectLocked ?? true // task 6: "corner default proportional"
            let newOBB = MKAnchoredResize.resize(obb, handle: handle, worldDelta: worldDelta, fromCenter: fromCenter, aspectLocked: locked, minimumSize: 1)
            let localBounds = intrinsicBounds[onlyID] ?? CGRect(x: 0, y: 0, width: 1, height: 1)
            newTransforms[onlyID] = Self.preservingFlipSign(
                newOBB.derivingTransform(localBounds: localBounds), from: startTransforms[onlyID]
            )
        } else {
            // Multi-select: resize the axis-aligned union bounds as a
            // rigid whole (rotation 0), then re-derive each child's OBB
            // by mapping its old center/size through the same scale+
            // translate the group bounds underwent.
            let groupOBB = MKOrientedRect(center: CGPoint(x: groupBounds.midX, y: groupBounds.midY), size: groupBounds.size, rotation: 0)
            let locked = aspectLocked ?? false // multi-select group resize defaults free unless the caller asks
            let newGroupOBB = MKAnchoredResize.resize(groupOBB, handle: handle, worldDelta: worldDelta, fromCenter: fromCenter, aspectLocked: locked, minimumSize: 1)
            let scaleX = groupBounds.width > 0 ? newGroupOBB.size.width / groupBounds.width : 1
            let scaleY = groupBounds.height > 0 ? newGroupOBB.size.height / groupBounds.height : 1
            for (id, obb) in startOBBs {
                let relativeX = obb.center.x - groupBounds.midX
                let relativeY = obb.center.y - groupBounds.midY
                let newCenter = CGPoint(x: newGroupOBB.center.x + relativeX * scaleX, y: newGroupOBB.center.y + relativeY * scaleY)
                let newSize = CGSize(width: obb.size.width * scaleX, height: obb.size.height * scaleY)
                let newChildOBB = MKOrientedRect(center: newCenter, size: newSize, rotation: obb.rotation)
                let localBounds = intrinsicBounds[id] ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                newTransforms[id] = Self.preservingFlipSign(
                    newChildOBB.derivingTransform(localBounds: localBounds), from: startTransforms[id]
                )
            }
        }

        for (id, transform) in newTransforms { session.renderBridge?.applyTransientTransform(nodeID: id, transform: transform.affineTransform) }
        try? session.perform(MKBatchTransformCommand(gestureID: gestureID, newTransforms: newTransforms))
    }

    public func endResize(session: CanvasSession) {
        guard gestureID != nil else { return }
        session.renderBridge?.commitTransients()
        session.endGesture()
        resetResizeState()
    }

    private func resetResizeState() {
        gestureID = nil
        handle = nil
        startOBBs.removeAll()
        startTransforms.removeAll()
        intrinsicBounds.removeAll()
        groupBounds = .zero
    }

    // MARK: - Intrinsic local bounds

    /// The rect to hand `MKOrientedRect.derivingTransform(localBounds:)`
    /// for `id`: the geometry source's own answer when it has one, else
    /// the historical origin-anchored reconstruction from the OBB and the
    /// transform's scale.
    ///
    /// `derivingTransform` anchors the derived `position` on
    /// `localBounds.midX/.midY`, so this rect must be the SAME one
    /// `MKOrientedRect.init(localBounds:transform:)` consumed on the way
    /// in ، see `MKCanvasGeometrySource.localBounds(for:in:)` for the list
    /// of node kinds the old reconstruction got wrong (everything whose
    /// local bounds are not origin-anchored: shapes, images, path text,
    /// arranged compositions) and what the user saw when it did.
    static func intrinsicBounds(
        for id: MKNodeID,
        obb: MKOrientedRect,
        transform: MKTransform2D,
        geometrySource: any MKCanvasGeometrySource,
        scene: MKScene
    ) -> CGRect {
        if let real = geometrySource.localBounds(for: id, in: scene), real.width > 0, real.height > 0 {
            return real
        }
        let sx = transform.scale.width == 0 ? 1 : abs(transform.scale.width)
        let sy = transform.scale.height == 0 ? 1 : abs(transform.scale.height)
        return CGRect(x: 0, y: 0, width: obb.size.width / sx, height: obb.size.height / sy)
    }

    // MARK: - Rotate

    public func beginRotate(session: CanvasSession, pointerStart: CGPoint) {
        guard !session.selection.isEmpty, let geometrySource = session.geometrySource else { return }
        gestureID = UUID()
        startOBBs.removeAll()
        startTransforms.removeAll()
        intrinsicBounds.removeAll()
        for id in session.selection.ids {
            guard let obb = geometrySource.worldOBB(for: id, in: session.scene),
                  let transform = session.scene.node(id: id)?.core.transform else { continue }
            startOBBs[id] = obb
            startTransforms[id] = transform
            intrinsicBounds[id] = Self.intrinsicBounds(
                for: id, obb: obb, transform: transform, geometrySource: geometrySource, scene: session.scene)
        }
        let bounds = MKOrientedRect.unionBounds(of: Array(startOBBs.values)) ?? .zero
        rotationCenter = startOBBs.count == 1 ? (startOBBs.values.first?.center ?? .zero) : CGPoint(x: bounds.midX, y: bounds.midY)
        groupBounds = bounds
        startPointerAngle = atan2(pointerStart.y - rotationCenter.y, pointerStart.x - rotationCenter.x)
        session.beginGesture()
    }

    public func updateRotate(session: CanvasSession, pointerCurrent: CGPoint, snapping: Bool) {
        guard let gestureID else { return }
        let currentAngle = atan2(pointerCurrent.y - rotationCenter.y, pointerCurrent.x - rotationCenter.x)
        var rotationDelta = currentAngle - startPointerAngle
        if snapping, startOBBs.count == 1, let obb = startOBBs.values.first {
            let snappedTotal = MKAnchoredResize.rotate(startRotation: obb.rotation, startPointerAngle: startPointerAngle, currentPointerAngle: currentAngle, snapping: true)
            rotationDelta = snappedTotal - obb.rotation
        } else if snapping {
            rotationDelta = MKAnchoredResize.snappedAngle(rotationDelta)
        }

        var newTransforms: [MKNodeID: MKTransform2D] = [:]
        for (id, obb) in startOBBs {
            guard let startTransform = startTransforms[id] else { continue }
            var newTransform = startTransform
            if startOBBs.count == 1 {
                newTransform.rotation = obb.rotation + rotationDelta
            } else {
                // Rigid rotation of the whole group about `rotationCenter`:
                // each child's center orbits the pivot, and each child
                // spins by the same delta.
                let dx = obb.center.x - rotationCenter.x
                let dy = obb.center.y - rotationCenter.y
                let cosT = cos(rotationDelta)
                let sinT = sin(rotationDelta)
                let newCenter = CGPoint(x: rotationCenter.x + dx * cosT - dy * sinT, y: rotationCenter.y + dx * sinT + dy * cosT)
                let newRotation = obb.rotation + rotationDelta
                let localBounds = intrinsicBounds[id] ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                let newOBB = MKOrientedRect(center: newCenter, size: obb.size, rotation: newRotation)
                newTransform = Self.preservingFlipSign(newOBB.derivingTransform(localBounds: localBounds), from: startTransform)
            }
            newTransforms[id] = newTransform
            session.renderBridge?.applyTransientTransform(nodeID: id, transform: newTransform.affineTransform)
        }
        try? session.perform(MKBatchTransformCommand(gestureID: gestureID, newTransforms: newTransforms))
    }

    public func endRotate(session: CanvasSession) {
        guard gestureID != nil else { return }
        session.renderBridge?.commitTransients()
        session.endGesture()
        resetResizeState()
    }

    // MARK: - P6 flip-sign preservation

    /// `MKOrientedRect.derivingTransform(localBounds:)` (`Geometry/
    /// MKOrientedRect.swift`) reconstructs `scale` purely from a size
    /// RATIO (`size.width / localBounds.width`), which is always ≥ 0 since
    /// both operands are always ≥ 0 (`MKAnchoredResize.resize` floors both
    /// OBB dimensions at `minimumSize`/uses `abs(...)` throughout ، this
    /// codebase's resize math has never let a drag "flip through" an
    /// anchor, by design). That was harmless before P6 (`scale` was always
    /// non-negative anyway, so there was no sign to lose) but P6's Flip
    /// (`CanvasSession.flipSelection(axis:)`, `EditingOperations.swift`)
    /// introduces the first-ever negative `scale` component in this
    /// codebase ، and every resize/rotate-drag call site above feeds a
    /// freshly `derivingTransform`-synthesized (always non-negative)
    /// transform straight into `MKBatchTransformCommand`, which would
    /// SILENTLY discard a prior flip the instant the user next drags a
    /// resize handle or the rotate knob (verified: `resize`/`rotate`'s own
    /// math never depends on the CURRENT transform's scale sign, only on
    /// OBB geometry, so re-applying the ORIGINAL gesture-start sign here
    /// cannot reintroduce any of the bugs those functions guard against ،
    /// it only restores information `derivingTransform` structurally can't
    /// carry).
    ///
    /// Restores whichever axis `startTransform` had negative, onto
    /// `derived`'s corresponding (always non-negative) axis, leaving
    /// magnitude untouched ، exactly "the flip survives the gesture,
    /// nothing else about the resize/rotate changes."
    private static func preservingFlipSign(_ derived: MKTransform2D, from startTransform: MKTransform2D?) -> MKTransform2D {
        guard let startTransform else { return derived }
        var result = derived
        if startTransform.scale.width < 0 { result.scale.width = -abs(result.scale.width) }
        if startTransform.scale.height < 0 { result.scale.height = -abs(result.scale.height) }
        return result
    }
}
