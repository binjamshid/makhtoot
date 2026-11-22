import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import MKPersistence

// WS-06 packet §5 task 5: "pan on selection → `beginGesture()`, per-frame
// transform commands (coalescing key `move-<gestureID>`), CALayer position
// updated by WS-07 fast-path (`applyTransientTransform(nodeID:transform:)`
// on the render tree ، no content redraw), `endGesture()` commits."
//
// Every frame this both (a) calls `session.perform(...)` with a
// `MKBatchTransformCommand` sharing one `coalescingKey` for the whole
// gesture (so `MKUndoStack` merges the run into exactly one undo entry ،
// task 5 accept: "one undo entry per drag") and (b) pushes the SAME new
// transforms straight to `session.renderBridge?.applyTransientTransform`
// so the visual update never waits on a scene-mutation → re-render round
// trip. The "no `draw(in:)` during drag" half of task 5's accept criterion
// is WS-07's fast-path contract to honor on the CALayer side; this file's
// job is to call that seam correctly every frame, which it does
// unconditionally (a `nil` `renderBridge`, i.e. no WS-07 conformer wired
// yet, degrades to "scene updates land, no fast-path preview" rather than
// crashing).
@MainActor
public final class MoveGesture {
    private var gestureID: UUID?
    private var startPoint: CGPoint = .zero
    private var startTransforms: [MKNodeID: MKTransform2D] = [:]
    private var startOBBs: [MKNodeID: MKOrientedRect] = [:]

    public init() {}

    public var isActive: Bool { gestureID != nil }

    /// Starts a move gesture over the current selection. No-op if the
    /// selection is empty.
    public func begin(session: CanvasSession, at point: CGPoint) {
        guard !session.selection.isEmpty else { return }
        let newGestureID = UUID()
        gestureID = newGestureID
        startPoint = point
        startTransforms.removeAll()
        startOBBs.removeAll()
        for id in session.selection.ids {
            if let node = session.scene.node(id: id) { startTransforms[id] = node.core.transform }
            if let obb = session.geometrySource?.worldOBB(for: id, in: session.scene) { startOBBs[id] = obb }
        }
        session.beginGesture()
    }

    /// Feeds the current drag point; applies snapping (when enabled) and
    /// emits the coalesced per-frame command + fast-path preview. Returns
    /// the effective (post-snap) delta, in case the caller wants to render
    /// snap guides itself.
    @discardableResult
    public func update(session: CanvasSession, to point: CGPoint, zoomScale: CGFloat) -> CGVector {
        guard let gestureID else { return .zero }
        var delta = CGVector(dx: point.x - startPoint.x, dy: point.y - startPoint.y)

        if session.snappingEnabled, let anchorOBB = startOBBs.values.first {
            let draggedBounds = anchorOBB.axisAlignedBounds.offsetBy(dx: delta.dx, dy: delta.dy)
            let candidates = snapCandidates(session: session, excludingIDs: Set(startOBBs.keys))
            let viewport = draggedBounds.insetBy(dx: -4000, dy: -4000)
            let snap = MKSnapEngine.snap(draggedBounds: draggedBounds, candidates: candidates, zoomScale: zoomScale, viewportExtent: viewport)
            delta.dx += snap.adjustment.dx
            delta.dy += snap.adjustment.dy
        }

        var newTransforms: [MKNodeID: MKTransform2D] = [:]
        newTransforms.reserveCapacity(startTransforms.count)
        for (id, startTransform) in startTransforms {
            var t = startTransform
            t.position.x += delta.dx
            t.position.y += delta.dy
            newTransforms[id] = t
            session.renderBridge?.applyTransientTransform(nodeID: id, transform: t.affineTransform)
        }
        try? session.perform(MKBatchTransformCommand(gestureID: gestureID, newTransforms: newTransforms))
        return delta
    }

    public func end(session: CanvasSession) {
        guard gestureID != nil else { return }
        session.renderBridge?.commitTransients()
        session.endGesture()
        gestureID = nil
        startTransforms.removeAll()
        startOBBs.removeAll()
    }

    public func cancel(session: CanvasSession) {
        guard gestureID != nil else { return }
        // Restore the pre-gesture transforms as a preview, then let
        // `endGesture()` finalize ، the coalesced undo entry (if any
        // frame's command was ever applied) still restores state exactly
        // via `session.undo()`, but callers that want an immediate visual
        // snap-back (Esc / two-finger cancel gesture) can call this.
        for (id, transform) in startTransforms {
            session.renderBridge?.applyTransientTransform(nodeID: id, transform: transform.affineTransform)
        }
        session.renderBridge?.commitTransients()
        session.endGesture()
        gestureID = nil
        startTransforms.removeAll()
        startOBBs.removeAll()
    }

    private func snapCandidates(session: CanvasSession, excludingIDs: Set<MKNodeID>) -> [MKSnapCandidate] {
        var candidates = MKSnapEngine.canvasCandidates(canvasSize: session.scene.canvas.size)
        guard let geometrySource = session.geometrySource else { return candidates }
        for node in session.scene.nodes
        where !excludingIDs.contains(node.id) && !node.core.isLocked && !node.core.isHidden {
            if let obb = geometrySource.worldOBB(for: node.id, in: session.scene) {
                candidates.append(contentsOf: MKSnapEngine.nodeCandidates(nodeID: node.id, obb: obb))
            }
        }
        return candidates
    }
}
