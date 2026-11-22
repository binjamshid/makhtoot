import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKPersistence

/// WS-04 packet §5 task 14 (D-106 §5.4).
@Suite struct RevertServiceTests {
    @Test func revertRestoresExactOriginalTextAndStyleAndUndoRestoresEdits() async throws {
        let text = "بسم الله"
        let style = ArrangeFixtures.systemStyle()
        let core = MKNodeCore(name: "نص", transform: MKTransform2D(position: CGPoint(x: 5, y: 5)), zOrder: 1)
        let capture = await ArrangeFixtures.capture(text, style: style)
        var composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)

        // Simulate a manual edit (move the first glyph) BEFORE reverting ،
        // undo of revert must restore this edit too.
        guard let firstID = composition.nodes.first?.id else {
            Issue.record("expected at least one node")
            return
        }
        composition.nodes = composition.nodes.map { child in
            guard case .glyph(var g) = child, g.id == firstID else { return child }
            g.transform.position = CGPoint(x: 3, y: 3)
            return .glyph(g)
        }

        let arrangedNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 200, height: 200)), nodes: [.arranged(arrangedNode)])

        let service = RevertService()
        let preflight = service.preflight(for: composition)
        #expect(preflight.editedNodeCount >= 1)
        #expect(preflight.willDiscard)

        let command = try service.revertCommand(arrangedNodeID: core.id, node: arrangedNode)
        let revertedScene = try command.apply(to: scene)

        guard case .liveText(let liveNode)? = revertedScene.node(id: core.id) else {
            Issue.record("expected the node to become .liveText after revert")
            return
        }
        #expect(liveNode.text.string == text, "revert must restore the exact original source string")
        #expect(liveNode.style == style, "revert must restore the exact original style")
        #expect(liveNode.core == core, "same transform/z preserved")

        let inverse = command.inverse(against: scene)
        let undoneScene = try inverse.apply(to: revertedScene)
        guard case .arranged(let restoredArranged)? = undoneScene.node(id: core.id) else {
            Issue.record("expected undo to restore the .arranged node")
            return
        }
        #expect(restoredArranged.composition == composition, "undo of revert must restore every manual edit")
    }

    @Test func corruptedBackupThrowsRatherThanSilentlyReverting() async throws {
        let text = "بسم"
        let style = ArrangeFixtures.systemStyle()
        let core = MKNodeCore(name: "نص")
        let capture = await ArrangeFixtures.capture(text, style: style)
        var composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)
        // Tamper with the backup directly (bypassing the normal derivation
        // path) ، simulates an INV-4 violation a bug elsewhere might cause.
        composition.sourceBackup.sourceString = "متلاعب به"

        let arrangedNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        #expect(throws: MKArrangeError.self) {
            _ = try RevertService().revertCommand(arrangedNodeID: core.id, node: arrangedNode)
        }
    }
}
