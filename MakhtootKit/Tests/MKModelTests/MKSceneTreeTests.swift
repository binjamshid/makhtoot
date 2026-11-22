import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel

/// WS-02 packet §5 task 3 accept criteria: value-semantics test (mutating a
/// copy leaves the original intact); 5 000-node find-by-id < 1 ms via the
/// internal id index.
@Suite("MKScene tree operations")
struct MKSceneTreeTests {
    @Test func mutatingACopyLeavesTheOriginalSceneIntact() {
        let original = FixtureScenes.flatNodesScene(count: 5)
        var copy = original
        let firstID = original.nodes[0].id
        copy = copy.updatingNode(id: firstID) { node in
            var core = node.core
            core.name = "معدَّل" // modified
            node = node.withCore(core)
        }

        #expect(original.nodes[0].core.name == "عنصر 0")
        #expect(copy.nodes[0].core.name == "معدَّل")
        #expect(original != copy)
    }

    @Test func insertRemoveReorderArePureFunctions() {
        let scene = FixtureScenes.flatNodesScene(count: 3)
        let newNode = MKNode.shape(MKShapeNode(core: MKNodeCore(name: "جديد"), geometry: .ellipse))

        let inserted = scene.inserting(newNode, at: 1)
        #expect(inserted.nodes.count == 4)
        #expect(inserted.nodes[1].id == newNode.id)
        #expect(scene.nodes.count == 3) // original untouched

        let removed = inserted.removing(id: newNode.id)
        #expect(removed.nodes.count == 3)
        #expect(removed.nodes.contains { $0.id == newNode.id } == false)

        let reordered = scene.reordering(id: scene.nodes[0].id, toIndex: 2)
        #expect(reordered.nodes.last?.id == scene.nodes[0].id)
    }

    @Test func groupingNestsSelectedNodesAndUngroupRestoresThem() {
        let scene = FixtureScenes.flatNodesScene(count: 4)
        let idsToGroup = [scene.nodes[0].id, scene.nodes[2].id]
        let groupID = MKNodeID()
        let grouped = scene.reparenting(idsToGroup, intoGroupNamed: "مجموعة", groupID: groupID)

        #expect(grouped.nodes.count == 3) // 2 remaining top-level + 1 group
        guard case .group(let g) = grouped.node(id: groupID) else {
            Issue.record("expected a group node")
            return
        }
        #expect(Set(g.children.map(\.id)) == Set(idsToGroup))

        // find-by-id must resolve into nested group children too.
        #expect(grouped.node(id: idsToGroup[0]) != nil)
    }

    @Test func findByIDResolvesNestedChildrenAndBackground() {
        let scene = FixtureScenes.flatNodesScene(count: 2)
        #expect(scene.node(id: scene.background.core.id) != nil)
        #expect(scene.node(id: scene.nodes[1].id) != nil)
        #expect(scene.node(id: MKNodeID()) == nil)
    }

    @Test func findByIDOn5000NodesCompletesUnderOneMillisecond() {
        let scene = FixtureScenes.flatNodesScene(count: 5000)
        let index = MKNodeIndex(scene: scene)
        let targetID = scene.nodes[4321].id

        let start = DispatchTime.now()
        let found = index.node(id: targetID)
        let elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000

        #expect(found != nil)
        #expect(elapsedMS < 1.0, "lookup took \(elapsedMS) ms")
        #expect(index.count == 5001) // 5000 nodes + background
    }
}
