import CoreGraphics
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

@MainActor
@Suite("LayersModel")
struct LayersModelTests {
    @Test func rowsAreOrderedTopFirst() throws {
        let session = try CanvasTestSupport.makeSession()
        let bottom = try CanvasTestSupport.addShapeNode(to: session, name: "الأسفل", position: .zero)
        let top = try CanvasTestSupport.addShapeNode(to: session, name: "الأعلى", position: CGPoint(x: 10, y: 0))
        let model = LayersModel(session: session)
        let ids = model.flattenedRows.map(\.id)
        // `top` was inserted LAST, so it is index 1 in `scene.nodes`
        // (backmost-first array) ، the panel shows it FIRST (top-first).
        #expect(ids.first == top)
        #expect(ids.contains(bottom))
    }

    @Test func backgroundRowIsAlwaysLastAndNeverReorderable() throws {
        let session = try CanvasTestSupport.makeSession()
        _ = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        let model = LayersModel(session: session)
        #expect(model.flattenedRows.last?.isBackground == true)
    }

    @Test func collapsedGroupsDoNotMaterializeChildRows() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 10, y: 0))
        session.setSelection([a, b])
        let groupID = try session.group()!
        let model = LayersModel(session: session)
        let rowsCollapsed = model.flattenedRows
        // group row + background row only ، children not expanded.
        #expect(rowsCollapsed.count == 2)
        model.toggleExpanded(groupID)
        let rowsExpanded = model.flattenedRows
        #expect(rowsExpanded.count == 4) // group + 2 children + background
    }

    @Test func toggleVisibilityAndLockEmitCommands() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        let model = LayersModel(session: session)
        try model.toggleVisibility(a)
        #expect(session.scene.node(id: a)?.core.isHidden == true)
        try model.toggleLock(a)
        #expect(session.scene.node(id: a)?.core.isLocked == true)
    }

    @Test func duplicateInsertsAFreshIDAboveTheSourceAndSelectsIt() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, name: "شكل", position: CGPoint(x: 5, y: 5))
        let model = LayersModel(session: session)
        let countBefore = session.scene.nodes.count
        try model.duplicate(a)
        #expect(session.scene.nodes.count == countBefore + 1)
        #expect(session.selection.single != a)
        #expect(session.selection.single != nil)
        let duplicateID = session.selection.single!
        #expect(session.scene.node(id: duplicateID)?.core.transform.position == CGPoint(x: 5, y: 5))
    }

    @Test func reorderMovesATopLevelNodeToANewIndex() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        _ = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 10, y: 0))
        let model = LayersModel(session: session)
        try model.reorder(a, toIndex: 1)
        #expect(session.scene.nodes.last?.id == a)
    }

    @Test func windowedRowsSliceMatchesTheFullList() throws {
        let session = try CanvasTestSupport.makeSession()
        for i in 0..<10 {
            _ = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: CGFloat(i), y: 0))
        }
        let model = LayersModel(session: session)
        let all = model.flattenedRows
        let window = model.rows(in: 2..<5)
        #expect(window.map(\.id) == Array(all[2..<5]).map(\.id))
    }

    @Test func lockedNodeIsSelectableFromTheLayersPanelButNotFromCanvasTap() throws {
        // PRD R-4.6 (coordinator gate ruling, docs/impl-log/WS-06.md):
        // "locked nodes are skipped by tap selection but selectable from
        // the layers panel (with lock badge)" ، both halves asserted here.
        let session = try CanvasTestSupport.makeSession()
        let geometry = FakeGeometrySource()
        session.geometrySource = geometry
        let locked = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 10, y: 10), size: CGSize(width: 20, height: 20), locked: true)

        // Canvas tap: skipped (falls through to nothing here → deselect).
        session.tap(at: CGPoint(x: 10, y: 10), zoomScale: 1)
        #expect(session.selection.isEmpty)

        // Layers panel: selectable, and the row carries the lock badge.
        let model = LayersModel(session: session)
        model.select(locked)
        #expect(session.selection.ids == [locked])
        #expect(model.flattenedRows.first(where: { $0.id == locked })?.isLocked == true)
    }

    @Test func kindLabelsUseTheDocumentedArabicDefaults() {
        let node = MKNode.shape(MKShapeNode(core: MKNodeCore(name: "شكل"), geometry: .ellipse))
        #expect(LayersModel.kindLabel(for: node) == "شكل")
    }
}
