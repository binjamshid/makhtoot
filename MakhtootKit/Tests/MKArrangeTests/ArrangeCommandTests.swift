import Testing
import CoreGraphics
import MKArrange
import MKFoundation
import MKModel
import MKPersistence

/// WS-04 packet §5 task 4: `arrangeCommand` replaces a `liveText`/`pathText`
/// node with `arranged` at the same transform/z; undo restores the exact
/// original node (Equatable).
@Suite struct ArrangeCommandTests {
    @Test func arrangeThenUndoRestoresByteIdenticalSourceNode() async throws {
        let text = "بسم الله"
        let style = ArrangeFixtures.systemStyle()
        let core = MKNodeCore(name: "نص", transform: MKTransform2D(position: CGPoint(x: 10, y: 20)), zOrder: 3, opacity: 0.8)
        let originalNode = MKNode.liveText(MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style))

        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 300, height: 300)), nodes: [originalNode])

        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)
        let command = ArrangeCommands.arrangeCommand(sourceNodeID: core.id, core: core, composition: composition, derivedFrom: .liveText)

        let arrangedScene = try command.apply(to: scene)
        guard case .arranged(let arrangedNode)? = arrangedScene.node(id: core.id) else {
            Issue.record("expected the node to become .arranged")
            return
        }
        #expect(arrangedNode.core == core, "same transform/z/opacity preserved verbatim")

        let inverse = command.inverse(against: scene)
        let undoneScene = try inverse.apply(to: arrangedScene)
        #expect(undoneScene.node(id: core.id) == originalNode, "undo must restore the exact original node (Equatable)")
    }
}
