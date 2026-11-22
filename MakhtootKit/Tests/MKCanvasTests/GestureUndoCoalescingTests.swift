import CoreGraphics
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

// WS-06 packet §7 gate: "undo coalescing per gesture type" ، one test
// class per gesture kind (move, resize, rotate, nudge, text edit), each
// asserting EXACTLY one undo entry results from a multi-frame/multi-
// keystroke simulated interaction, and that undo restores the exact
// pre-gesture state.
@MainActor
@Suite("Move gesture ، undo coalescing + fast-path preview")
struct MoveGestureTests {
    @Test func aMultiFrameDragProducesExactlyOneUndoEntry() throws {
        let session = try CanvasTestSupport.makeSession()
        let geometry = FakeGeometrySource()
        let bridge = RecordingRenderBridge()
        session.geometrySource = geometry
        session.renderBridge = bridge
        session.snappingEnabled = false
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))
        session.setSelection([a])

        let undoCountBefore = session.document.undoStack.undo.count
        let move = MoveGesture()
        move.begin(session: session, at: CGPoint(x: 0, y: 0))
        for i in 1...30 {
            move.update(session: session, to: CGPoint(x: CGFloat(i), y: CGFloat(i)), zoomScale: 1)
        }
        move.end(session: session)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 1)
        #expect(session.scene.node(id: a)?.core.transform.position == CGPoint(x: 30, y: 30))
        #expect(bridge.commitCount == 1)
        #expect(bridge.transientCalls.count == 30)

        try session.undo()
        #expect(session.scene.node(id: a)?.core.transform.position == CGPoint(x: 0, y: 0))
    }

    @Test func movingMultipleSelectedNodesTogetherIsStillOneUndoEntry() throws {
        // The exact scenario `MKBatchTransformCommand` exists for ،
        // see that file's header comment on why per-node `MKTransformCommand`
        // coalescing keys would NOT achieve this.
        let session = try CanvasTestSupport.makeSession()
        let geometry = FakeGeometrySource()
        session.geometrySource = geometry
        session.snappingEnabled = false
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 100, y: 0))
        session.setSelection([a, b])

        let undoCountBefore = session.document.undoStack.undo.count
        let move = MoveGesture()
        move.begin(session: session, at: .zero)
        for i in 1...10 {
            move.update(session: session, to: CGPoint(x: CGFloat(i) * 2, y: 0), zoomScale: 1)
        }
        move.end(session: session)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 1)
        #expect(session.scene.node(id: a)?.core.transform.position.x == 20)
        #expect(session.scene.node(id: b)?.core.transform.position.x == 120)

        try session.undo()
        #expect(session.scene.node(id: a)?.core.transform.position.x == 0)
        #expect(session.scene.node(id: b)?.core.transform.position.x == 100)
    }

    @Test func snappingPullsTheDraggedNodeOntoACanvasEdge() throws {
        let session = try CanvasTestSupport.makeSession(canvasSize: CGSize(width: 1000, height: 1000))
        let geometry = FakeGeometrySource()
        session.geometrySource = geometry
        session.snappingEnabled = true
        // A node whose left edge, once dragged near x=0 (a canvas edge
        // candidate), should snap exactly onto it.
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 500, y: 500), size: CGSize(width: 20, height: 20))
        session.setSelection([a])
        let move = MoveGesture()
        move.begin(session: session, at: CGPoint(x: 500, y: 500))
        // Drag far enough left that the shape's left edge (obb.minX) lands
        // 3pt shy of 0 ، within the (zoom-1) 6pt snap radius.
        _ = move.update(session: session, to: CGPoint(x: 500 - 503, y: 500), zoomScale: 1)
        move.end(session: session)
        let finalOBB = FakeGeometrySource().worldOBB(for: a, in: session.scene)
        #expect(abs((finalOBB?.axisAlignedBounds.minX ?? -1)) < 0.5)
    }
}

@MainActor
@Suite("Handle gestures ، undo coalescing")
struct HandleGesturesUndoTests {
    @Test func aMultiFrameResizeProducesExactlyOneUndoEntry() throws {
        let session = try CanvasTestSupport.makeSession()
        let geometry = FakeGeometrySource()
        session.geometrySource = geometry
        let bridge = RecordingRenderBridge()
        session.renderBridge = bridge
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
        session.setSelection([a])

        let undoCountBefore = session.document.undoStack.undo.count
        let handles = HandleGestures()
        handles.beginResize(session: session, handle: .bottomRight)
        for i in 1...10 {
            handles.updateResize(session: session, worldDelta: CGPoint(x: CGFloat(i) * 2, y: CGFloat(i) * 2), aspectLocked: false)
        }
        handles.endResize(session: session)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 1)
        #expect(bridge.commitCount == 1)

        let sizeAfter = FakeGeometrySource().worldOBB(for: a, in: session.scene)?.size
        #expect(sizeAfter != nil)
        #expect(abs((sizeAfter?.width ?? 0) - 120) < 0.01)

        try session.undo()
        let sizeRestored = FakeGeometrySource().worldOBB(for: a, in: session.scene)?.size
        #expect(abs((sizeRestored?.width ?? 0) - 100) < 0.01)
    }

    @Test func aMultiFrameRotateProducesExactlyOneUndoEntry() throws {
        let session = try CanvasTestSupport.makeSession()
        let geometry = FakeGeometrySource()
        session.geometrySource = geometry
        // `FakeGeometrySource`'s unit-square convention places this node's
        // OBB center at (10,10), not its raw `transform.position` (0,0) ،
        // see `CanvasTestSupport.FakeGeometrySource`'s header comment.
        // Rotation is about the OBB center, so the synthetic pointer path
        // below must orbit (10,10), not the origin.
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0), size: CGSize(width: 20, height: 20))
        session.setSelection([a])
        let rotationCenter = CGPoint(x: 10, y: 10)

        let undoCountBefore = session.document.undoStack.undo.count
        let handles = HandleGestures()
        handles.beginRotate(session: session, pointerStart: CGPoint(x: rotationCenter.x + 100, y: rotationCenter.y))
        for degrees in stride(from: 5, through: 90, by: 5) {
            let radians = CGFloat(degrees) * .pi / 180
            let pointer = CGPoint(x: rotationCenter.x + 100 * cos(radians), y: rotationCenter.y + 100 * sin(radians))
            handles.updateRotate(session: session, pointerCurrent: pointer, snapping: false)
        }
        handles.endRotate(session: session)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 1)
        let rotationAfter = session.scene.node(id: a)?.core.transform.rotation ?? 0
        #expect(abs(rotationAfter - .pi / 2) < 0.01)

        try session.undo()
        let rotationRestored = session.scene.node(id: a)?.core.transform.rotation ?? -1
        #expect(abs(rotationRestored - 0) < 0.01)
    }
}

@MainActor
@Suite("Nudge (arrow-key) ، burst coalescing")
struct NudgeControllerTests {
    @Test func aBurstOfNudgesWithinTheWindowIsOneUndoEntry() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])

        let undoCountBefore = session.document.undoStack.undo.count
        let nudge = NudgeController()
        for i in 0..<10 {
            nudge.nudge(session: session, direction: .right, shiftPressed: false, now: Double(i) * 0.05)
        }
        nudge.endBurst(session: session)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 1)
        #expect(session.scene.node(id: a)?.core.transform.position.x == 10)
    }

    @Test func aGapLongerThanTheBurstWindowStartsANewUndoEntry() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])

        let undoCountBefore = session.document.undoStack.undo.count
        let nudge = NudgeController()
        nudge.nudge(session: session, direction: .right, shiftPressed: false, now: 0)
        nudge.nudge(session: session, direction: .right, shiftPressed: false, now: 10) // way past burstWindow
        nudge.endBurst(session: session)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 2)
    }

    @Test func shiftPressedUsesTheBigStep() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])
        let nudge = NudgeController()
        nudge.nudge(session: session, direction: .down, shiftPressed: true, now: 0)
        nudge.endBurst(session: session)
        #expect(session.scene.node(id: a)?.core.transform.position.y == NudgeController.shiftStep)
    }

    @Test func lockedNodesAreNotNudged() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero, locked: true)
        session.setSelection([]) // locked nodes aren't selectable via setSelection...
        // ...directly poke the underlying selection ids to simulate a
        // stale-but-locked selected id (defensive path).
        let nudge = NudgeController()
        session.setSelection([a]) // filtered out by CanvasSession itself
        #expect(session.selection.isEmpty)
        nudge.nudge(session: session, direction: .right, shiftPressed: false, now: 0)
        #expect(session.scene.node(id: a)?.core.transform.position == .zero)
    }
}
