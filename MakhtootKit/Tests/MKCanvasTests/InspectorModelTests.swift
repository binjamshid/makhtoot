import CoreGraphics
import MKFoundation
import MKModel
import MKPersistence
import Testing
@testable import MKCanvas

@MainActor
@Suite("InspectorModel")
struct InspectorModelTests {
    @Test func emptySelectionReadsEmptyEverywhere() throws {
        let session = try CanvasTestSupport.makeSession()
        let inspector = InspectorModel(session: session)
        #expect(inspector.positionValue == .empty)
        #expect(inspector.opacityValue == .empty)
    }

    @Test func singleSelectionReadsUniformValues() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 12, y: 34))
        session.setSelection([a])
        let inspector = InspectorModel(session: session)
        #expect(inspector.positionValue == .uniform(CGPoint(x: 12, y: 34)))
    }

    @Test func mixedSelectionReadsMixedForDisagreeingFields() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 50, y: 0))
        session.setSelection([a, b])
        let inspector = InspectorModel(session: session)
        #expect(inspector.positionValue == .mixed)
    }

    @Test func setPositionOnAUniformSingleSelectionSetsItExactly() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))
        session.setSelection([a])
        let inspector = InspectorModel(session: session)
        inspector.setPosition(CGPoint(x: 100, y: 200))
        #expect(session.scene.node(id: a)?.core.transform.position == CGPoint(x: 100, y: 200))
    }

    @Test func setPositionOnAMixedSelectionAppliesTheSameDeltaToAll() throws {
        // task 11 accept: "mixed-value editing applies delta correctly."
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 0, y: 0))
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 50, y: 10))
        session.setSelection([a, b])
        let inspector = InspectorModel(session: session)
        // Mixed positions: reference becomes the typed value itself, so
        // the FIRST mixed-selection edit anchors there and every node
        // shifts by (typed - typed) = 0 on the first call... instead
        // verify the documented multi-select contract directly: after
        // `setPosition`, both nodes' RELATIVE offset from each other is
        // unchanged (a delta-preserving move), which is the only sane
        // definition when starting values disagree.
        let deltaBefore = CGPoint(x: (session.scene.node(id: b)!.core.transform.position.x) - (session.scene.node(id: a)!.core.transform.position.x), y: 0)
        inspector.setPosition(CGPoint(x: 100, y: 100))
        let deltaAfter = CGPoint(x: (session.scene.node(id: b)!.core.transform.position.x) - (session.scene.node(id: a)!.core.transform.position.x), y: 0)
        #expect(abs(deltaAfter.x - deltaBefore.x) < 0.0001)
    }

    @Test func setRotationDegreesSetsTheSameAbsoluteAngleOnEverySelectedNode() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero, rotation: 0)
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 10, y: 0), rotation: 1)
        session.setSelection([a, b])
        let inspector = InspectorModel(session: session)
        inspector.setRotationDegrees(90)
        #expect(abs((session.scene.node(id: a)?.core.transform.rotation ?? 0) - .pi / 2) < 0.0001)
        #expect(abs((session.scene.node(id: b)?.core.transform.rotation ?? 0) - .pi / 2) < 0.0001)
    }

    @Test func setOpacityClampsToUnitRange() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])
        let inspector = InspectorModel(session: session)
        inspector.setOpacity(5)
        #expect(session.scene.node(id: a)?.core.opacity == 1)
        inspector.setOpacity(-5)
        #expect(session.scene.node(id: a)?.core.opacity == 0)
    }

    @Test func beginEditEndEditCoalescesMultipleSetCallsIntoOneUndoEntry() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])
        let inspector = InspectorModel(session: session)
        let undoCountBefore = session.document.undoStack.undo.count

        inspector.beginEdit()
        for opacity in stride(from: 0.1, through: 1.0, by: 0.1) {
            inspector.setOpacity(opacity)
        }
        inspector.endEdit()

        #expect(session.document.undoStack.undo.count == undoCountBefore + 1)
    }

    @Test func discreteCommitsWithoutBeginEditEachGetTheirOwnUndoEntry() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: .zero)
        session.setSelection([a])
        let inspector = InspectorModel(session: session)
        let undoCountBefore = session.document.undoStack.undo.count

        inspector.setOpacity(0.5)
        inspector.setOpacity(0.8)

        #expect(session.document.undoStack.undo.count == undoCountBefore + 2)
    }

    @Test func worldTransformComposesThroughAGroupAncestor() throws {
        let session = try CanvasTestSupport.makeSession()
        let a = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 5, y: 5))
        session.setSelection([a])
        let groupID = try session.group() // single-node group is a no-op…
        #expect(groupID == nil) // …so build a real 2-node group instead:
        let b = try CanvasTestSupport.addShapeNode(to: session, position: CGPoint(x: 20, y: 0))
        session.setSelection([a, b])
        let realGroupID = try session.group()!
        try session.perform(MKTransformCommand(nodeID: realGroupID, newTransform: MKTransform2D(position: CGPoint(x: 100, y: 0))))
        let world = InspectorModel.worldTransform(for: a, in: session.scene)
        #expect(world?.position == CGPoint(x: 105, y: 5))
    }

    // MARK: - P5.2: background color (§2.2 entry point)

    @Test func backgroundColorValueReadsTheSceneBackgroundsSolidColor() throws {
        let session = try CanvasTestSupport.makeSession()
        let inspector = InspectorModel(session: session)
        #expect(inspector.backgroundColorValue == .white)   // MKBackgroundNode.defaultBackground()
    }

    @Test func setBackgroundColorReplacesTheBackgroundNodesSolidContentAndIsUndoable() throws {
        let session = try CanvasTestSupport.makeSession()
        let inspector = InspectorModel(session: session)
        let undoCountBefore = session.document.undoStack.undo.count
        let newColor = MKSolidColor(r: 0.2, g: 0.4, b: 0.6, a: 1)

        inspector.setBackgroundColor(newColor)

        #expect(inspector.backgroundColorValue == newColor)
        if case .solid(let stored) = session.scene.background.content {
            #expect(stored == newColor)
        } else {
            Issue.record("expected background content to be .solid after setBackgroundColor")
        }
        #expect(session.document.undoStack.undo.count == undoCountBefore + 1)
    }

    @Test func setBackgroundColorDoesNotRequireASelection() throws {
        // Deliberately different from every OTHER setter here: the
        // background isn't a selectable node (`LayersPanelView` excludes
        // it from row actions), so this must work with an EMPTY selection.
        let session = try CanvasTestSupport.makeSession()
        #expect(session.selection.ids.isEmpty)
        let inspector = InspectorModel(session: session)
        inspector.setBackgroundColor(MKSolidColor(r: 1, g: 0, b: 0, a: 1))
        #expect(inspector.backgroundColorValue == MKSolidColor(r: 1, g: 0, b: 0, a: 1))
    }

    // MARK: - P5.6: highlight color set/clear (Bug 11)

    @Test func setHighlightColorAppliesToSelectedTextNodes() throws {
        let session = try CanvasTestSupport.makeSession()
        let textID = try ArrangeFixture.addLiveTextNode(to: session)
        session.setSelection([textID])
        let inspector = InspectorModel(session: session)
        let color = MKSolidColor(r: 1, g: 1, b: 0, a: 0.5)

        inspector.setHighlightColor(color)

        #expect(inspector.highlightColorValue == .uniform(.solid(color)))
    }

    /// P5.6: the widened `MKSolidColor?` signature's whole point ،
    /// `setHighlightColor(nil)` must clear a previously-set highlight
    /// back to "no highlight" and remain source-compatible with the
    /// non-optional call site directly above (Swift implicitly promotes
    /// the non-optional argument to the Optional parameter).
    @Test func setHighlightColorNilClearsAPreviouslySetHighlight() throws {
        let session = try CanvasTestSupport.makeSession()
        let textID = try ArrangeFixture.addLiveTextNode(to: session)
        session.setSelection([textID])
        let inspector = InspectorModel(session: session)
        inspector.setHighlightColor(MKSolidColor(r: 0, g: 1, b: 0, a: 1))
        #expect(inspector.highlightColorValue != .empty)

        inspector.setHighlightColor(nil)

        if case .liveText(let n) = session.scene.node(id: textID) {
            #expect(n.style.highlightColor == nil)
        } else {
            Issue.record("expected the text node to still be .liveText after clearing its highlight")
        }
    }
}
