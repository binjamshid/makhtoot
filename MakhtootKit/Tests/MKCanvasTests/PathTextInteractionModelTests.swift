import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import Testing
@testable import MKCanvas

// WS-06 packet §5 task 16 ("Path-edit mode UX", this run). Exercises
// `MKPathTextInteractionModel`'s wiring against `FakePathTextEngine`
// (`PathTextInteractionTestSupport.swift`) ، mode transitions, hit-test/tap
// routing, anchor-drag/glyph-offset-drag command dispatch and undo
// coalescing (D-112), insert/delete/toggle-closed, path-level options
// edits, and the pure `reversedPath` geometry function. `MKPathText`'s own
// algorithms (`PathEditModel`, `PathLayoutEngine`) are covered by
// `MKPathTextTests` ، these tests are about THIS module's interaction
// layer only (mirrors `ArrangeInteractionModelTests.swift`'s own framing
// exactly).

@MainActor
@Suite("MKPathTextInteractionModel ، task 16 gate")
struct PathTextInteractionModelTests {
    private func makeModel() throws -> (session: CanvasSession, model: MKPathTextInteractionModel, engine: FakePathTextEngine) {
        let session = try CanvasTestSupport.makeSession()
        let engine = FakePathTextEngine()
        let model = MKPathTextInteractionModel(session: session)
        model.engine = engine
        return (session, model, engine)
    }

    // MARK: - Entry / exit (task 16: "'تحرير المسار' toggles pathEdit mode")

    @Test("entering Path-Edit Mode on a pathText node succeeds")
    func entrySucceedsOnPathText() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)

        model.enterPathEditMode(nodeID: fixture.nodeID)

        #expect(session.mode == .pathEdit(nodeID: fixture.nodeID))
        #expect(model.isActive)
        #expect(model.activeNodeID == fixture.nodeID)
    }

    @Test("entering Path-Edit Mode on a non-pathText node is refused (R-9.3: editable in live path-text mode only)")
    func entryRefusedOnNonPathText() throws {
        let (session, model, engine) = try makeModel()
        _ = engine
        let shapeID = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))

        model.enterPathEditMode(nodeID: shapeID)

        #expect(session.mode == .browse)
        #expect(model.lastErrorMessage != nil)
    }

    @Test("exiting Path-Edit Mode returns to browse and clears the handle selection")
    func exitReturnsToBrowse() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)
        _ = model.tap(at: CGPoint(x: 0, y: 0), tolerance: 10)
        #expect(model.selectedHandle != nil)

        model.exitPathEditMode()

        #expect(session.mode == .browse)
        #expect(model.selectedHandle == nil)
    }

    // MARK: - Hit-test / tap-select (R-9.1)

    @Test("tap selects the nearest handle within tolerance")
    func tapSelectsHandle() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0))
        model.enterPathEditMode(nodeID: fixture.nodeID)

        let hit = model.tap(at: CGPoint(x: 2, y: 1), tolerance: 10)

        #expect(hit?.anchorID == fixture.startAnchorID)
        #expect(hit?.kind == .anchor)
        #expect(model.selectedHandle?.anchorID == fixture.startAnchorID)
    }

    @Test("tap on empty path-edit space clears the handle selection")
    func tapEmptyClearsSelection() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)
        _ = model.tap(at: CGPoint(x: 0, y: 0), tolerance: 10)

        let hit = model.tap(at: CGPoint(x: 999, y: 999), tolerance: 10)

        #expect(hit == nil)
        #expect(model.selectedHandle == nil)
    }

    // MARK: - Anchor drag (R-9.1, R-9.3) ، one coalesced undo entry per drag (D-112)

    @Test("an anchor drag commits one coalesced undo entry per drag, not one per frame")
    func anchorDragCoalescesToOneUndoEntry() throws {
        let (session, model, engine) = try makeModel()
        _ = engine
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0))
        model.enterPathEditMode(nodeID: fixture.nodeID)

        model.beginHandleDrag(MKPathHandleID(anchorID: fixture.startAnchorID, kind: .anchor))
        for i in 1...10 {
            model.updateHandleDrag(to: CGPoint(x: CGFloat(i) * 2, y: 0))
        }
        model.endHandleDrag()

        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.path.segments.first?.start == CGPoint(x: 20, y: 0))

        // A single `undo()` fully reverting 10 frames of drag is the
        // coalescing proof (same idiom `ArrangeInteractionModelTests
        // .moveCoalescesToOneUndoEntry` uses) ، 10 separate undo entries
        // would require 10 `undo()` calls to reach the original state.
        try session.undo()
        guard case .pathText(let restored)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(restored.path.segments.first?.start == CGPoint(x: 0, y: 0))
    }

    @Test("dragging a handle (not the anchor itself) reshapes the curve without moving the anchor point")
    func handleDragMovesOnlyTheHandle() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0))
        engine.seedAnchors([
            FakePathTextEngine.AnchorState(id: fixture.startAnchorID, point: CGPoint(x: 0, y: 0), handleIn: nil, handleOut: CGPoint(x: 20, y: 0)),
            FakePathTextEngine.AnchorState(id: fixture.endAnchorID, point: CGPoint(x: 100, y: 0), handleIn: CGPoint(x: 80, y: 0), handleOut: nil),
        ], for: fixture.nodeID)
        model.enterPathEditMode(nodeID: fixture.nodeID)

        model.beginHandleDrag(MKPathHandleID(anchorID: fixture.startAnchorID, kind: .handleOut), mode: .free)
        model.updateHandleDrag(to: CGPoint(x: 20, y: 15))
        model.endHandleDrag()

        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.path.segments.first?.start == CGPoint(x: 0, y: 0))   // anchor unmoved
        #expect(node.path.segments.first?.c1 == CGPoint(x: 20, y: 15))   // handle moved
    }

    // MARK: - Insert / delete / toggle-closed (R-9.1)

    @Test("insertAnchor adds a new anchor and selects it")
    func insertAnchorAddsAndSelects() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)

        try model.insertAnchor(near: CGPoint(x: 50, y: 0))

        #expect(engine.insertCallCount == 1)
        #expect(model.selectedHandle?.kind == .anchor)
        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.path.segments.count == 2)
    }

    @Test("deleteAnchor removes an anchor when the result stays structurally valid")
    func deleteAnchorRemoves() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)
        try model.insertAnchor(near: CGPoint(x: 50, y: 0))   // 3 anchors now

        try model.deleteAnchor(fixture.startAnchorID)

        #expect(engine.deleteCallCount == 1)
        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.path.segments.count == 1)
    }

    @Test("deleteAnchor is a no-op when it would violate the minimum-anchor floor (2 open)")
    func deleteAnchorRefusesBelowFloor() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)   // exactly 2 anchors, open
        model.enterPathEditMode(nodeID: fixture.nodeID)

        try model.deleteAnchor(fixture.startAnchorID)

        #expect(engine.deleteCallCount == 0)
        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.path.segments.count == 1)
    }

    @Test("toggleClosed flips the path's open/closed state")
    func toggleClosedFlips() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)
        try model.insertAnchor(near: CGPoint(x: 50, y: 0))   // 3 anchors, now closable

        try model.toggleClosed()

        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.path.isClosed)
    }

    // MARK: - Curvature warning (task 16 accept: "curvature warning banner when WS-05 reports it")

    @Test("curvatureWarningActive reflects the engine's live reported state for the active node")
    func curvatureWarningReflectsEngine() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)
        #expect(!model.curvatureWarningActive)

        engine.setCurvatureWarning(true, for: fixture.nodeID)

        #expect(model.curvatureWarningActive)
    }

    // MARK: - Per-glyph offset drag (R-9.4, live path text)

    @Test("a glyph-offset drag commits and is inspectable afterward via the test double's recorded calls")
    func glyphOffsetDragCommitsAndRecords() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)
        let key = MKPathGlyphOffsetKey(codepoints: [0x0645], occurrenceOrdinal: 0)
        engine.seedGlyph(key, at: CGPoint(x: 50, y: 0), for: fixture.nodeID)

        let hitKey = model.beginGlyphOffsetDrag(at: CGPoint(x: 50, y: 0))
        #expect(hitKey == key)
        model.updateGlyphOffsetDrag(byDelta: CGSize(width: 3, height: 4))
        model.updateGlyphOffsetDrag(byDelta: CGSize(width: 1, height: 0))
        model.endGlyphOffsetDrag()

        #expect(engine.glyphOffsetCalls.count == 2)   // one command per frame, still ONE undo entry (below)
        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.glyphOffsets[key]?.offset == CGPoint(x: 4, y: 4))

        try session.undo()
        guard case .pathText(let restored)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect((restored.glyphOffsets[key] ?? .zero) == .zero)
    }

    @Test("a glyph-offset drag on empty path-text space begins nothing")
    func glyphOffsetDragMissBeginsNothing() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)

        let hitKey = model.beginGlyphOffsetDrag(at: CGPoint(x: 500, y: 500))

        #expect(hitKey == nil)
        #expect(engine.glyphOffsetCalls.isEmpty)
    }

    // MARK: - Path-level options (R-9.4) ، plain `MKModel` types, no engine seam

    @Test("setStartOffset coalesces multiple updates within one gesture to one undo entry")
    func setStartOffsetCoalesces() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)
        let gestureID = UUID()

        // BOTH halves of the D-112 contract, the way real slider chrome
        // will drive it: a stable coalescing key AND an open gesture
        // transaction ، `UndoStack.perform` only consults the key while
        // `gestureActive == true` (see `beginOptionsGesture`'s doc
        // comment), so the wrap is load-bearing, not decoration.
        model.beginOptionsGesture()
        for i in 1...5 {
            try model.setStartOffset(Double(i) * 2, gestureID: gestureID)
        }
        model.endOptionsGesture()

        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.layout.startOffset == 10)

        try session.undo()
        guard case .pathText(let restored)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(restored.layout.startOffset == 0)
    }

    @Test("toggleAboveBelow flips side between above and below (R-9.4's baseline flip)")
    func toggleAboveBelowFlips() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)
        guard case .pathText(let initial)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(initial.layout.side == .above)   // MKPathLayoutOptions' own default

        try model.toggleAboveBelow()
        guard case .pathText(let flipped)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(flipped.layout.side == .below)

        try model.toggleAboveBelow()
        guard case .pathText(let flippedBack)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(flippedBack.layout.side == .above)
    }

    @Test("setSpacingMode commits the persisted spacing-mode slice")
    func setSpacingModeCommits() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine)
        model.enterPathEditMode(nodeID: fixture.nodeID)

        try model.setSpacingMode(.justify)

        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.layout.spacingMode == .justify)
    }

    // MARK: - Reverse direction (R-9.4 "قلب الاتجاه") ، pure geometry, no `MKPathText` needed

    @Test("reversedPath reverses segment traversal order and swaps each segment's start/end and control points")
    func reversedPathReversesSegments() {
        let seg0 = MKBezierSegment(start: CGPoint(x: 0, y: 0), c1: CGPoint(x: 10, y: 0), c2: CGPoint(x: 20, y: 0), end: CGPoint(x: 30, y: 0))
        let seg1 = MKBezierSegment(start: CGPoint(x: 30, y: 0), c1: CGPoint(x: 40, y: 0), c2: CGPoint(x: 50, y: 0), end: CGPoint(x: 60, y: 0))
        let path = MKBezierPathData(segments: [seg0, seg1], isClosed: false)

        let reversed = MKPathTextInteractionModel.reversedPath(path)

        #expect(reversed.isClosed == false)
        #expect(reversed.segments == [
            MKBezierSegment(start: seg1.end, c1: seg1.c2, c2: seg1.c1, end: seg1.start),
            MKBezierSegment(start: seg0.end, c1: seg0.c2, c2: seg0.c1, end: seg0.start),
        ])
    }

    @Test("reverseDirection() commits the reversed path through session.perform and undoes cleanly")
    func reverseDirectionCommand() throws {
        let (session, model, engine) = try makeModel()
        _ = engine
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0))
        model.enterPathEditMode(nodeID: fixture.nodeID)
        let before = session.scene.node(id: fixture.nodeID)

        try model.reverseDirection()

        guard case .pathText(let node)? = session.scene.node(id: fixture.nodeID) else { Issue.record("expected pathText node"); return }
        #expect(node.path.segments.first?.start == CGPoint(x: 100, y: 0))
        #expect(node.path.segments.first?.end == CGPoint(x: 0, y: 0))

        try session.undo()
        #expect(session.scene.node(id: fixture.nodeID) == before)
    }

    // MARK: - Chrome geometry (task 16 "anchors/handles drawn in chrome layer" ، pure half, `PathEditChromeGeometry`)

    @Test("guidePath projects the node-local path into world space through the node's transform")
    func guidePathAppliesNodeTransform() {
        let segment = MKBezierSegment(start: CGPoint(x: 0, y: 0), c1: CGPoint(x: 0, y: 0), c2: CGPoint(x: 100, y: 0), end: CGPoint(x: 100, y: 0))
        let path = MKBezierPathData(segments: [segment], isClosed: false)
        let transform = MKTransform2D(position: CGPoint(x: 40, y: 30))

        let world = PathEditChromeGeometry.guidePath(path, transform: transform)

        // A pure translation maps the local (0,0)-(100,0) line's bounds to
        // (40,30)-(140,30) exactly.
        #expect(world.boundingBox == CGRect(x: 40, y: 30, width: 100, height: 0))
    }

    @Test("connectorSegments pairs each present Bézier handle with its own anchor's position")
    func connectorSegmentsPairHandlesToAnchors() {
        let anchorA = UUID()
        let anchorB = UUID()
        let targets = [
            MKPathHitTarget(id: MKPathHandleID(anchorID: anchorA, kind: .anchor), position: CGPoint(x: 0, y: 0)),
            MKPathHitTarget(id: MKPathHandleID(anchorID: anchorA, kind: .handleOut), position: CGPoint(x: 20, y: 10)),
            MKPathHitTarget(id: MKPathHandleID(anchorID: anchorB, kind: .anchor), position: CGPoint(x: 100, y: 0)),
            MKPathHitTarget(id: MKPathHandleID(anchorID: anchorB, kind: .handleIn), position: CGPoint(x: 80, y: -10)),
        ]

        let segments = PathEditChromeGeometry.connectorSegments(in: targets)

        #expect(segments.count == 2)   // one per handle, none for the two anchors themselves
        #expect(segments[0].from == CGPoint(x: 0, y: 0))
        #expect(segments[0].to == CGPoint(x: 20, y: 10))
        #expect(segments[1].from == CGPoint(x: 100, y: 0))
        #expect(segments[1].to == CGPoint(x: 80, y: -10))
    }

    @Test("dotRect compensates by 1/zoomScale so dots keep a constant screen size across zoom")
    func dotRectIsZoomCompensated() {
        let at1x = PathEditChromeGeometry.dotRect(center: CGPoint(x: 50, y: 50), diameter: 10, zoomScale: 1)
        let at2x = PathEditChromeGeometry.dotRect(center: CGPoint(x: 50, y: 50), diameter: 10, zoomScale: 2)

        #expect(at1x.width == 10)
        #expect(at2x.width == 5)   // half the world size at 2× zoom = same screen size
        #expect(at1x.midX == 50 && at1x.midY == 50)
        #expect(at2x.midX == 50 && at2x.midY == 50)
    }

    @Test("currentHitTargets forwards the engine's full target set for the active node, and is empty outside path-edit mode")
    func currentHitTargetsForwardsFromEngine() throws {
        let (session, model, engine) = try makeModel()
        let fixture = try PathTextFixture.addLineNode(to: session, engine: engine, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0))

        #expect(model.currentHitTargets().isEmpty)   // not in path-edit mode yet

        model.enterPathEditMode(nodeID: fixture.nodeID)
        let targets = model.currentHitTargets()

        #expect(targets.count == 2)   // the fixture's two handle-less anchors
        #expect(targets.allSatisfy { $0.id.kind == .anchor })
        #expect(Set(targets.map(\.id.anchorID)) == [fixture.startAnchorID, fixture.endAnchorID])
    }
}
