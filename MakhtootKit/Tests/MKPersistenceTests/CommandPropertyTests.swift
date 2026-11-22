import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §5 task 10 accept criterion: property test ، for random
/// command sequences, applying then applying inverses in reverse restores
/// the original scene (Equatable compare).
@Suite("MKCommand property tests")
struct CommandPropertyTests {
    private func randomScene(seed: inout SystemRandomNumberGenerator, nodeCount: Int = 4) -> MKScene {
        FixtureScenes.flatNodesScene(count: nodeCount)
    }

    private func randomCommand(for scene: MKScene, rng: inout SystemRandomNumberGenerator) -> any MKCommand {
        let targetID = scene.nodes.randomElement(using: &rng)?.id ?? scene.nodes[0].id
        switch Int.random(in: 0..<5, using: &rng) {
        case 0:
            return MKTransformCommand(
                nodeID: targetID,
                newTransform: MKTransform2D(position: CGPoint(x: .random(in: -50...50, using: &rng), y: .random(in: -50...50, using: &rng)))
            )
        case 1:
            return MKStyleCommand(nodeID: targetID, newStyle: MKStyle(fill: .solid(MKSolidColor(r: .random(in: 0...1, using: &rng), g: 0, b: 0))))
        case 2:
            return MKRenameCommand(nodeID: targetID, newName: "اسم-\(Int.random(in: 0...999, using: &rng))")
        case 3:
            return MKLockHideCommand(nodeID: targetID, isLocked: Bool.random(using: &rng), isHidden: Bool.random(using: &rng))
        default:
            let newNode = MKNode.shape(MKShapeNode(core: MKNodeCore(name: "مُدرَج"), geometry: .ellipse))
            return MKInsertNodeCommand(node: newNode, index: Int.random(in: 0...scene.nodes.count, using: &rng))
        }
    }

    @Test func applyThenApplyInversesInReverseRestoresTheOriginalScene() throws {
        var rng = SystemRandomNumberGenerator()
        for trial in 0..<25 {
            let original = randomScene(seed: &rng)
            var scene = original
            var appliedCommands: [(command: any MKCommand, preScene: MKScene)] = []

            let commandCount = Int.random(in: 1...8, using: &rng)
            for _ in 0..<commandCount {
                let command = randomCommand(for: scene, rng: &rng)
                let preScene = scene
                scene = try command.apply(to: scene)
                appliedCommands.append((command, preScene))
            }

            // Compute inverses AGAINST each command's pre-apply scene (the
            // documented contract), then apply them in REVERSE order.
            var restored = scene
            for (command, preScene) in appliedCommands.reversed() {
                let inverse = command.inverse(against: preScene)
                restored = try inverse.apply(to: restored)
            }

            #expect(restored == original, "trial \(trial) failed to restore original scene")
        }
    }

    @Test func removeThenInsertInverseRestoresExactPositionEvenNested() throws {
        let scene = FixtureScenes.flatNodesScene(count: 4)
        let grouped = scene.reparenting([scene.nodes[1].id, scene.nodes[2].id], intoGroupNamed: "مجموعة")
        guard case .group(let g) = grouped.nodes.first(where: { $0.children != nil }) else {
            Issue.record("expected a group node")
            return
        }
        let nestedID = g.children[0].id

        let removeCmd = MKRemoveNodeCommand(nodeID: nestedID)
        let inverse = removeCmd.inverse(against: grouped)
        let removed = try removeCmd.apply(to: grouped)
        #expect(removed.node(id: nestedID) == nil)

        let restored = try inverse.apply(to: removed)
        #expect(restored == grouped)
    }

    @Test func groupThenUngroupIsARoundTrip() throws {
        let scene = FixtureScenes.flatNodesScene(count: 3)
        let groupCmd = MKGroupCommand(nodeIDs: [scene.nodes[0].id, scene.nodes[1].id], groupName: "مجموعة")
        let groupInverse = groupCmd.inverse(against: scene)
        let grouped = try groupCmd.apply(to: scene)
        let ungrouped = try groupInverse.apply(to: grouped)
        #expect(ungrouped == scene)
    }

    /// Regression test for the WS-06-reported `MKUngroupCommand` bug
    /// (docs/impl-log/WS-06.md "real bugs" item 3, fixed in WS-02 session
    /// 2): group two nodes → move AND rotate the group → ungroup → each
    /// child must retain its effective WORLD transform (the group's
    /// transform composed into the child's stored local transform), not
    /// snap back to its pre-group-move position.
    @Test func ungroupAfterMovingAndRotatingTheGroupPreservesChildWorldTransforms() throws {
        var scene = FixtureScenes.flatNodesScene(count: 3)
        let childAID = scene.nodes[0].id
        let childBID = scene.nodes[1].id

        // Give child A a non-trivial starting transform so composition
        // (not just translation-passthrough) is exercised.
        scene = try MKTransformCommand(
            nodeID: childAID,
            newTransform: MKTransform2D(position: CGPoint(x: 10, y: 20), rotation: 0.3, scale: CGSize(width: 1, height: 1))
        ).apply(to: scene)

        // Group A + B (group starts with identity transform, so at this
        // moment child-local == child-world).
        let groupID = MKNodeID()
        scene = try MKGroupCommand(nodeIDs: [childAID, childBID], groupName: "مجموعة", groupID: groupID).apply(to: scene)

        // Record each child's world transform BEFORE the group moves:
        // local ∘ identity == local.
        guard case .group(let g) = scene.node(id: groupID) else {
            Issue.record("expected a group node")
            return
        }
        let preMoveWorld = Dictionary(uniqueKeysWithValues: g.children.map { ($0.id, $0.core.transform) })

        // Move AND rotate the group itself.
        let groupTransform = MKTransform2D(position: CGPoint(x: 100, y: -40), rotation: .pi / 4, scale: CGSize(width: 1, height: 1))
        scene = try MKTransformCommand(nodeID: groupID, newTransform: groupTransform).apply(to: scene)

        // Ungroup. Children must land at local ∘ groupTransform.
        let preUngroupScene = scene
        let ungroupCmd = MKUngroupCommand(groupID: groupID)
        let ungroupInverse = ungroupCmd.inverse(against: preUngroupScene)
        scene = try ungroupCmd.apply(to: scene)

        #expect(scene.node(id: groupID) == nil)
        for (childID, localBefore) in preMoveWorld {
            guard let child = scene.node(id: childID) else {
                Issue.record("child \(childID) missing after ungroup")
                continue
            }
            let expectedWorld = localBefore.concatenating(groupTransform)
            let actual = child.core.transform
            // Compare via the affine matrices with a small epsilon (the
            // decompose/re-compose in `concatenating` is float math).
            let e = expectedWorld.affineTransform
            let a = actual.affineTransform
            for (lhs, rhs) in [(e.a, a.a), (e.b, a.b), (e.c, a.c), (e.d, a.d), (e.tx, a.tx), (e.ty, a.ty)] {
                #expect(abs(lhs - rhs) < 1e-9, "child \(childID) world transform drifted: expected \(e), got \(a)")
            }
        }

        // And the recorded inverse still restores the exact pre-ungroup tree.
        let restored = try ungroupInverse.apply(to: scene)
        #expect(restored == preUngroupScene)
    }

    @Test func batchTransformAndBatchCoreAndTextEditInversesRestoreOriginal() throws {
        let original = FixtureScenes.flatNodesScene(count: 3)
        let gestureID = UUID()

        // Batch transform over two nodes.
        let batchTransform = MKBatchTransformCommand(gestureID: gestureID, newTransforms: [
            original.nodes[0].id: MKTransform2D(position: CGPoint(x: 5, y: 5)),
            original.nodes[1].id: MKTransform2D(position: CGPoint(x: -3, y: 9), rotation: 0.2),
        ])
        let btInverse = batchTransform.inverse(against: original)
        let afterBT = try batchTransform.apply(to: original)
        #expect(try btInverse.apply(to: afterBT) == original)

        // Batch core over two nodes.
        var newCore0 = original.nodes[0].core
        newCore0.opacity = 0.5
        var newCore2 = original.nodes[2].core
        newCore2.isHidden = true
        let batchCore = MKBatchCoreCommand(gestureID: gestureID, newCores: [
            original.nodes[0].id: newCore0,
            original.nodes[2].id: newCore2,
        ])
        let bcInverse = batchCore.inverse(against: original)
        let afterBC = try batchCore.apply(to: original)
        #expect(try bcInverse.apply(to: afterBC) == original)

        // Text edit (opaque node replace with a burst key).
        let replacement = MKNode.liveText(MKLiveTextNode(
            core: original.nodes[0].core, text: MKSourceText(string: "نص جديد")
        ))
        let textEdit = MKTextEditCommand(nodeID: original.nodes[0].id, newNode: replacement, burstKey: "textEdit:test:0")
        let teInverse = textEdit.inverse(against: original)
        let afterTE = try textEdit.apply(to: original)
        #expect(try teInverse.apply(to: afterTE) == original)
        #expect(textEdit.coalescingKey == "textEdit:test:0")
    }

    /// The per-gesture coalescing contract the batch commands exist for:
    /// a multi-select drag emitting N batch commands with one shared
    /// gestureID coalesces to exactly ONE undo entry (the failure mode
    /// that motivated `MKCanvasMultiTransformCommand` ، N per-node
    /// `MKTransformCommand` keys inside one gesture bracket do NOT
    /// coalesce).
    @MainActor
    @Test func multiSelectDragViaBatchTransformIsOneUndoEntry() throws {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 2)
        let idA = scene.nodes[0].id
        let idB = scene.nodes[1].id
        let preDragA = scene.node(id: idA)!.core.transform
        let preDragB = scene.node(id: idB)!.core.transform
        let gestureID = UUID()

        stack.beginGesture()
        for frame in 1...30 {
            let cmd = MKBatchTransformCommand(gestureID: gestureID, newTransforms: [
                idA: MKTransform2D(position: CGPoint(x: Double(frame), y: 0)),
                idB: MKTransform2D(position: CGPoint(x: Double(frame), y: 10)),
            ])
            scene = try stack.perform(cmd, currentScene: scene)
        }
        stack.endGesture()

        #expect(stack.undo.count == 1)
        let undone = try stack.undoLast(currentScene: scene)
        #expect(undone?.node(id: idA)?.core.transform == preDragA)
        #expect(undone?.node(id: idB)?.core.transform == preDragB)
    }
}
