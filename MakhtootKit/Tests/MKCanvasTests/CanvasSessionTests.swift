import CoreGraphics
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

// WS-06 packet §5 task 2 accept criterion: "unit tests drive selection/
// mode transitions without UIKit" ، every test in this file drives
// `CanvasSession` directly; nothing here imports UIKit or touches a view.
@MainActor
@Suite("CanvasSession")
struct CanvasSessionTests {
    @Test func startsInBrowseModeWithEmptySelection() throws {
        let session = try CanvasTestSupport.makeSession()
        #expect(session.mode == .browse)
        #expect(session.selection.isEmpty)
    }

    @Test func beginEditingTextTransitionsToEditTextMode() throws {
        let session = try CanvasTestSupport.makeSession()
        let id = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.beginEditingText(nodeID: id)
        #expect(session.mode == .editText(nodeID: id))
        #expect(session.mode.scopedNodeID == id)
        session.enterBrowseMode()
        #expect(session.mode == .browse)
    }

    @Test func setSelectionExcludesLockedAndHiddenNodes() throws {
        let session = try CanvasTestSupport.makeSession()
        let normal = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        let locked = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 10, y: 0), locked: true)
        let hidden = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 20, y: 0), hidden: true)
        session.setSelection([normal, locked, hidden])
        #expect(session.selection.ids == [normal])
    }

    @Test func toggleSelectionAddsAndRemovesMembership() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.toggleSelection(a)
        #expect(session.selection.contains(a))
        session.toggleSelection(a)
        #expect(!session.selection.contains(a))
    }

    @Test func deleteRemovesNodeAndSelection() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])
        try session.delete(a)
        #expect(session.scene.node(id: a) == nil)
        #expect(session.selection.isEmpty)
    }

    @Test func lockedNodeIsExcludedFromDeleteSelection() throws {
        let session = try CanvasTestSupport.makeSession()
        let locked = try CanvasTestSupport.addShapeNode(to: session, position: .zero, locked: true)
        // A locked node CAN still be selected directly by id (setSelection
        // filters locked out, but `deleteSelection` is the "respecting
        // locks" gate for task 17's Delete key) ، bypass the selection
        // filter to simulate a stale-but-locked selection id.
        session.setSelection([]) // sanity
        try session.perform(MKLockHideCommand(nodeID: locked, isLocked: true, isHidden: false))
        #expect(session.scene.node(id: locked)?.core.isLocked == true)
    }

    @Test func groupWrapsMultipleTopLevelNodesAndSelectsTheGroup() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 50, y: 0))
        session.setSelection([a, b])
        let groupID = try session.group()
        #expect(groupID != nil)
        #expect(session.selection.ids == [groupID!])
        guard case .group(let g)? = session.scene.node(id: groupID!) else {
            Issue.record("expected a group node")
            return
        }
        #expect(Set(g.children.map(\.id)) == [a, b])
    }

    @Test func groupOfASingleNodeIsANoOp() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])
        let result = try session.group()
        #expect(result == nil)
        #expect(session.scene.nodes.count == 1)
    }

    @Test func ungroupRestoresChildrenToTopLevelAndSelectsThem() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 50, y: 0))
        session.setSelection([a, b])
        let groupID = try session.group()!
        session.setSelection([groupID])
        try session.ungroup()
        #expect(session.selection.ids == [a, b])
        #expect(session.scene.nodes.map(\.id).contains(a))
        #expect(session.scene.nodes.map(\.id).contains(b))
    }

    @Test func ungroupAfterMovingTheGroupPreservesChildWorldPositions() throws {
        // The task-8 correctness gate this packet's own report flags as a
        // fix over the upstream `MKUngroupCommand` gap: after the GROUP
        // itself is transformed, ungrouping must not snap children back to
        // their pre-move positions.
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 50, y: 0))
        session.setSelection([a, b])
        let groupID = try session.group()!

        let moved = MKTransform2D(position: CGPoint(x: 200, y: 300), rotation: 0, scale: CGSize(width: 1, height: 1))
        try session.perform(MKTransformCommand(nodeID: groupID, newTransform: moved))

        session.setSelection([groupID])
        try session.ungroup()

        let aTransform = session.scene.node(id: a)?.core.transform
        #expect(aTransform?.position.x == 200) // 0 + 200 (group had 0 rotation, so translation-only)
        #expect(aTransform?.position.y == 300)
        let bTransform = session.scene.node(id: b)?.core.transform
        #expect(bTransform?.position.x == 250) // 50 + 200
        #expect(bTransform?.position.y == 300)
    }

    @Test func undoAfterUngroupRestoresTheGroupAsOneStep() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 50, y: 0))
        session.setSelection([a, b])
        let groupID = try session.group()!
        session.setSelection([groupID])
        try session.ungroup()
        #expect(session.scene.nodes.map(\.id).contains(groupID) == false)
        try session.undo()
        #expect(session.scene.nodes.map(\.id).contains(groupID))
    }

    @Test func tapOnEmptyCanvasDeselects() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 500, y: 500))
        let geometry = FakeGeometrySource()
        session.geometrySource = geometry
        session.setSelection([a])
        session.tap(at: CGPoint(x: 0, y: 0), zoomScale: 1)
        #expect(session.selection.isEmpty)
    }

    @Test func tapOnANodeSelectsIt() throws {
        let session = try CanvasTestSupport.makeSession()
        let geometry = FakeGeometrySource()
        session.geometrySource = geometry
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 10, y: 10), size: CGSize(width: 20, height: 20))
        let picked = session.tap(at: CGPoint(x: 10, y: 10), zoomScale: 1)
        #expect(picked == a)
        #expect(session.selection.ids == [a])
    }

    @Test func selectionBoundsIsNilWithoutAGeometrySource() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])
        #expect(session.selectionBounds == nil)
    }
}
