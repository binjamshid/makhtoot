import Testing
import CoreGraphics
import Foundation
import MKArrange
import MKFoundation
import MKModel
import MKPersistence

/// WS-04 packet §5 task 13: per-node style/transform edit helpers, group
/// operations across a selection collapse to one undo step.
@Suite struct ArrangeStyleEditorTests {
    @Test func multiSelectRecolorOfThreeGlyphNodesIsOneCommand() async throws {
        let text = "بسم"
        let style = ArrangeFixtures.systemStyle()
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)

        let glyphIDs = Set(composition.nodes.compactMap { child -> MKNodeID? in
            if case .glyph(let g) = child { return g.id }
            return nil
        })
        #expect(glyphIDs.count >= 3, "بسم should derive at least 3 glyph nodes")

        let ownerID = MKNodeID()
        let arrangedNode = MKArrangedTextNode(core: MKNodeCore(id: ownerID, name: "نص"), composition: composition, derivedFrom: .liveText)
        let redFill = MKStyle(fill: .solid(MKSolidColor(r: 1, g: 0, b: 0)))
        let command = ArrangeStyleEditor.setStyle(redFill, forChildIDs: glyphIDs, ownerNode: arrangedNode)

        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 200, height: 200)), nodes: [.arranged(arrangedNode)])

        let after = try command.apply(to: scene)
        guard case .arranged(let updated)? = after.node(id: ownerID) else {
            Issue.record("expected arranged node")
            return
        }
        for child in updated.composition.nodes {
            guard glyphIDs.contains(child.id), case .glyph(let g) = child else { continue }
            #expect(g.style == redFill)
        }
        // ONE command = one undo step, regardless of selection size.
        let inverse = command.inverse(against: scene)
        let undone = try inverse.apply(to: after)
        #expect(undone == scene, "a single inverse command must fully restore the pre-edit scene")
    }

    @Test func nudgeAndBaselineShiftAreCoalescableByKey() {
        let ownerID = MKNodeID()
        let childID = MKNodeID()
        let gestureID = UUID()
        let composition = ArrangedComposition(nodes: [], sourceBackup: MKSourceTextBackup(sourceString: "", style: .default), originFrame: .zero)
        let ownerNode = MKArrangedTextNode(core: MKNodeCore(id: ownerID, name: "نص"), composition: composition, derivedFrom: .liveText)
        let a = ArrangeStyleEditor.nudgePosition(by: CGSize(width: 1, height: 0), forChildID: childID, ownerNode: ownerNode, gestureID: gestureID)
        let b = ArrangeStyleEditor.setTransform(.identity, forChildID: childID, ownerNode: ownerNode, gestureID: gestureID)
        #expect(a.coalescingKey != nil)
        #expect(b.coalescingKey != nil)
        #expect(a.coalescingKey != b.coalescingKey, "different operation kinds must not accidentally share a coalescing key")
    }
}
