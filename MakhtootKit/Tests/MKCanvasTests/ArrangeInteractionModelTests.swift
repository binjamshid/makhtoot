import CoreGraphics
import Foundation
import MKFoundation
import MKModel
import Testing
@testable import MKCanvas

// WS-06 packet §5 task 15 ("Arrange mode UX", this run). Exercises
// `MKArrangeInteractionModel`'s wiring against `FakeArrangeEngine`/
// `FakeArrangeGeometrySource` (`ArrangeInteractionTestSupport.swift`) ، mode
// transitions, selection routing (glyph/letter granularity, R-6.14 bidi
// split), move/mark/join/form-selector/decompose-recompose/revert command
// dispatch, and undo coalescing. `MKArrange`'s own algorithms are covered
// by `MKArrangeTests` ، these tests are about THIS module's interaction
// layer only.

@MainActor
@Suite("MKArrangeInteractionModel ، task 15 gate")
struct ArrangeInteractionModelTests {
    private func makeModel() throws -> (session: CanvasSession, model: MKArrangeInteractionModel, engine: FakeArrangeEngine, geometry: FakeArrangeGeometrySource) {
        let session = try CanvasTestSupport.makeSession()
        let geometry = FakeArrangeGeometrySource()
        session.geometrySource = geometry
        let engine = FakeArrangeEngine()
        let model = MKArrangeInteractionModel(session: session)
        model.engine = engine
        return (session, model, engine, geometry)
    }

    // MARK: - Entry (R-6.1)

    @Test("entering Arrange Mode on a Live Text node derives once and swaps to .arranged")
    func entryDerivesFromLiveText() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let id = try ArrangeFixture.addLiveTextNode(to: session)

        await model.enterArrangeMode(nodeID: id)

        #expect(engine.deriveCallCount == 1)
        #expect(session.mode == .arrange(nodeID: id))
        if case .arranged? = session.scene.node(id: id) {} else { Issue.record("expected .arranged node after entry") }
    }

    @Test("re-entering Arrange Mode on an already-arranged node is a pure mode transition (R-6.10) ، no re-derivation")
    func reEntryDoesNotRederive() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)

        await model.enterArrangeMode(nodeID: fixture.nodeID)

        #expect(engine.deriveCallCount == 0)
        #expect(session.mode == .arrange(nodeID: fixture.nodeID))
    }

    @Test("exiting Arrange Mode returns to browse and clears the composition-scoped selection")
    func exitReturnsToBrowse() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        session.setArrangeChildSelection([fixture.baaID], granularity: .glyph, compositionScope: fixture.nodeID)

        model.exitArrangeMode()

        #expect(session.mode == .browse)
        #expect(session.selection.isEmpty)
        #expect(session.selection.compositionScope == nil)
    }

    // MARK: - Tap select / cycling (R-6.9)

    @Test("tap inside the composition selects the topmost child at glyph granularity")
    func tapSelectsGlyph() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)

        let hit = model.tap(at: CGPoint(x: 0, y: 0), zoomScale: 1)

        #expect(hit == fixture.baaID)
        #expect(session.selection.ids == [fixture.baaID])
        #expect(session.selection.compositionScope == fixture.nodeID)
    }

    @Test("tap at letter granularity expands the hit glyph to its whole letter-level covering set (base + attached mark)")
    func tapAtLetterGranularityExpandsToMark() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        model.setGranularity(.letter)

        model.tap(at: CGPoint(x: 0, y: 0), zoomScale: 1)

        #expect(session.selection.ids.contains(fixture.baaID))
        #expect(session.selection.ids.contains(fixture.fathaID))
    }

    @Test("tap on empty composition space clears the selection")
    func tapEmptyClears() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        session.setArrangeChildSelection([fixture.baaID], granularity: .glyph, compositionScope: fixture.nodeID)

        model.tap(at: CGPoint(x: 999, y: 999), zoomScale: 1)

        #expect(session.selection.isEmpty)
    }

    // MARK: - Granularity switch preserves meaning (R-6.4)

    @Test("switching glyph → letter → glyph round-trips the selection through LevelMapping without loss")
    func granularityRoundTrips() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        session.setArrangeChildSelection([fixture.baaID], granularity: .glyph, compositionScope: fixture.nodeID)

        model.setGranularity(.letter)
        #expect(session.selection.ids.contains(fixture.baaID))
        #expect(session.selection.ids.contains(fixture.fathaID))

        model.setGranularity(.glyph)
        #expect(session.selection.ids.contains(fixture.baaID))
    }

    // MARK: - R-6.14 bidi-run split

    @Test("letter-level range selection crossing a bidi-run boundary splits into per-run sub-selections")
    func letterLevelRangeSplitsAtBidiBoundary() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session, mixedBidi: true)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        guard let node = model.activeOwnerNode else { Issue.record("no active owner node"); return }

        let subSelections = model.letterLevelSubSelections(coveringChildIDs: [fixture.baaID, fixture.raaID], in: node)

        #expect(subSelections.count == 2, "باء (level 1) and راء (level 0) must split into separate sub-selections")
    }

    // MARK: - Move (R-6.5, R-7.4) ، one undo entry per drag

    @Test("a multi-frame drag of a selected glyph produces exactly one undo entry")
    func moveCoalescesToOneUndoEntry() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        session.setArrangeChildSelection([fixture.baaID], granularity: .glyph, compositionScope: fixture.nodeID)
        let undoCountBefore = session.document.undoStack.canUndo

        model.beginMove()
        for _ in 0..<10 {
            model.updateMove(byDelta: CGSize(width: 1, height: 0))
        }
        model.endMove()

        #expect(session.document.undoStack.canUndo)
        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .glyph(let baa)? = node.composition.child(id: fixture.baaID) else {
            Issue.record("expected moved glyph"); return
        }
        #expect(baa.transform.position.x == 10)   // 10 frames × 1pt
        try session.undo()
        guard case .arranged(let restored)? = session.scene.node(id: fixture.nodeID), case .glyph(let restoredBaa)? = restored.composition.child(id: fixture.baaID) else {
            Issue.record("expected restored glyph"); return
        }
        #expect(restoredBaa.transform.position == .zero)
        _ = undoCountBefore
    }

    @Test("moving a mark uses the same nudge primitive as moving a glyph")
    func moveMarkUsesSamePrimitive() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        session.setArrangeChildSelection([fixture.fathaID], granularity: .glyph, compositionScope: fixture.nodeID)

        model.beginMove()
        model.updateMove(byDelta: CGSize(width: 3, height: 4))
        model.endMove()

        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .mark(let mark)? = node.composition.child(id: fixture.fathaID) else {
            Issue.record("expected moved mark"); return
        }
        #expect(mark.transform.position == CGPoint(x: 3, y: 4))
    }

    // MARK: - Mark detach/reattach (R-7.5)

    @Test("detaching a mark clears its attachment")
    func detachMark() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        session.setArrangeChildSelection([fixture.fathaID], granularity: .glyph, compositionScope: fixture.nodeID)

        try model.detachSelectedMark()

        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .mark(let mark)? = node.composition.child(id: fixture.fathaID) else {
            Issue.record("expected mark"); return
        }
        #expect(mark.attachedTo == nil)
        #expect(!mark.followsBase)
    }

    @Test("re-attaching a mark to a base restores the attachment")
    func reattachMark() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        session.setArrangeChildSelection([fixture.fathaID], granularity: .glyph, compositionScope: fixture.nodeID)
        try model.detachSelectedMark()

        try model.reattachMark(fixture.fathaID, toBase: fixture.raaID)

        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .mark(let mark)? = node.composition.child(id: fixture.fathaID) else {
            Issue.record("expected mark"); return
        }
        #expect(mark.attachedTo == fixture.raaID)
        #expect(mark.followsBase)
    }

    // MARK: - Join break/restore + boundary picking (§8.1)

    @Test("logical glyph neighbors resolve باء↔راء adjacency for join-break boundary picking")
    func logicalNeighbors() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)

        let neighborsOfBaa = model.logicalGlyphNeighbors(of: fixture.baaID)
        #expect(neighborsOfBaa.previous == nil)
        #expect(neighborsOfBaa.next?.id == fixture.raaID)

        let neighborsOfRaa = model.logicalGlyphNeighbors(of: fixture.raaID)
        #expect(neighborsOfRaa.previous?.id == fixture.baaID)
    }

    @Test("breaking the join with the next neighbor calls through to the engine and applies the command")
    func breakJoinWithNext() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)

        try await model.breakJoinWithNext(fixture.baaID)

        #expect(engine.breakJoinCalls.count == 1)
        #expect(engine.breakJoinCalls.first?.0 == fixture.baaID)
        #expect(engine.breakJoinCalls.first?.1 == fixture.raaID)
        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .glyph(let baa)? = node.composition.child(id: fixture.baaID) else {
            Issue.record("expected glyph"); return
        }
        #expect(baa.joining.brokenByUser)
    }

    @Test("restoring the join with the next neighbor is undo-able back to the broken state")
    func restoreJoinRoundTrips() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        try await model.breakJoinWithNext(fixture.baaID)

        try await model.restoreJoinWithNext(fixture.baaID)

        #expect(engine.restoreJoinCalls.count == 1)
        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .glyph(let baa)? = node.composition.child(id: fixture.baaID) else {
            Issue.record("expected glyph"); return
        }
        #expect(!baa.joining.brokenByUser)
    }

    // MARK: - Form selector (R-8.3)

    @Test("form selector model loads 4 options and selecting one applies the command")
    func formSelectorSelectApplies() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)

        let formModel = await model.loadFormSelector(for: fixture.baaID)
        #expect(formModel?.options.count == 4)

        try model.selectForm(.final, for: fixture.baaID)

        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .glyph(let baa)? = node.composition.child(id: fixture.baaID) else {
            Issue.record("expected glyph"); return
        }
        #expect(baa.joining.form == .final)
    }

    // MARK: - Ligature decompose/recompose (§8.2, D-221 dirty check)

    @Test("decomposing a ligature group produces its constituent components")
    func decompose() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        #expect(model.canDecompose(fixture.ligatureID))

        let autoRefused = try await model.decompose(fixture.ligatureID, fidelity: true)

        #expect(!autoRefused)
        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .ligature(let group)? = node.composition.child(id: fixture.ligatureID) else {
            Issue.record("expected ligature group"); return
        }
        guard case .decomposed(let d) = group.state else { Issue.record("expected decomposed state"); return }
        #expect(d.components.count == 2)
    }

    @Test("recomposing without edits needs no confirmation and restores the original glyph")
    func recomposeWithoutEditsNoConfirmation() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        _ = try await model.decompose(fixture.ligatureID, fidelity: true)

        let preflight = model.recomposePreflight(fixture.ligatureID)
        #expect(preflight?.requiresConfirmation == false)

        try model.recompose(fixture.ligatureID, force: false)

        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .ligature(let group)? = node.composition.child(id: fixture.ligatureID) else {
            Issue.record("expected ligature group"); return
        }
        guard case .composed = group.state else { Issue.record("expected re-composed state"); return }
    }

    @Test("recomposing after editing a component requires confirmation (D-221, R-8.12)")
    func recomposeAfterEditRequiresConfirmation() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        _ = try await model.decompose(fixture.ligatureID, fidelity: true)
        guard case .arranged(let node)? = session.scene.node(id: fixture.nodeID), case .ligature(let group)? = node.composition.child(id: fixture.ligatureID),
              case .decomposed(let d) = group.state, let firstComponentID = d.components.first?.id
        else { Issue.record("expected decomposed components"); return }
        let command = engine.setTransformCommand(MKTransform2D(rotation: 0.3), forChildID: firstComponentID, ownerNode: node, gestureID: UUID())
        try session.perform(command)

        let preflight = model.recomposePreflight(fixture.ligatureID)
        #expect(preflight?.requiresConfirmation == true)
        #expect(preflight?.editedComponentCount == 1)

        #expect(throws: (any Error).self) {
            try model.recompose(fixture.ligatureID, force: false)
        }

        // Forced recompose discards the edit and restores the original.
        try model.recompose(fixture.ligatureID, force: true)
        guard case .arranged(let finalNode)? = session.scene.node(id: fixture.nodeID), case .ligature(let finalGroup)? = finalNode.composition.child(id: fixture.ligatureID) else {
            Issue.record("expected ligature group"); return
        }
        guard case .composed = finalGroup.state else { Issue.record("expected re-composed state"); return }
    }

    // MARK: - Revert (R-6.12, FL-13)

    @Test("revert preflight reports edited-node count and always willDiscard")
    func revertPreflightReportsEdits() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        session.setArrangeChildSelection([fixture.baaID], granularity: .glyph, compositionScope: fixture.nodeID)
        model.beginMove()
        model.updateMove(byDelta: CGSize(width: 5, height: 0))
        model.endMove()

        let preflight = model.revertPreflight()
        #expect(preflight?.editedNodeCount == 1)
        #expect(preflight?.willDiscard == true)
    }

    @Test("revert restores a Live Text node from the source backup; undo restores the full arrangement byte-identically (R-4.19)")
    func revertRoundTripsThroughUndo() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)
        let beforeRevert = session.scene.node(id: fixture.nodeID)

        try model.revert()

        #expect(session.mode == .browse)
        if case .liveText? = session.scene.node(id: fixture.nodeID) {} else { Issue.record("expected .liveText after revert") }

        try session.undo()
        #expect(session.scene.node(id: fixture.nodeID) == beforeRevert)
    }

    @Test("revert-and-edit reverts then opens the text-editing overlay (R-6.11)")
    func revertAndEdit() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)

        _ = try model.revertAndEdit()

        #expect(session.mode == .editText(nodeID: fixture.nodeID))
    }

    @Test("duplicate-then-revert-for-editing leaves the original arranged composition untouched")
    func duplicateThenRevert() async throws {
        let (session, model, engine, geometry) = try makeModel()
        _ = (engine, geometry)   // keep the weakly-held engine/geometry doubles alive for the test's duration
        let fixture = try ArrangeFixture.addArrangedNode(to: session)
        await model.enterArrangeMode(nodeID: fixture.nodeID)

        let duplicateID = try model.duplicateThenRevertForEditing()

        #expect(duplicateID != nil)
        #expect(duplicateID != fixture.nodeID)
        if case .arranged? = session.scene.node(id: fixture.nodeID) {} else { Issue.record("original must remain .arranged") }
        if let duplicateID, case .liveText? = session.scene.node(id: duplicateID) {} else { Issue.record("duplicate must be reverted to .liveText") }
        #expect(session.mode == .editText(nodeID: duplicateID ?? MKNodeID()))
    }
}
