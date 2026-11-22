import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 session 2 (coordinator-directed fix 2): every command in the
/// catalog ، including the three batch/text-edit primitives canonicalized
/// from WS-06's canvas lane ، must round-trip through `MKCommandCoder`, or
/// `CommandJournal.append` silently exempts that command type from
/// crash-recovery replay (the D-223/no-loss violation this session fixed).
@Suite("MKCommandCoder round-trips")
struct CommandCoderTests {
    private func roundTrip(_ command: any MKCommand) throws -> any MKCommand {
        let data = try MKCommandCoder.encode(command)
        return try MKCommandCoder.decode(data)
    }

    /// Behavioral equivalence check: decoded command applied to the same
    /// scene produces the same result as the original (command types are
    /// not Equatable across `any MKCommand`, so equality is asserted
    /// through effect + identity fields).
    private func assertSameEffect(_ original: any MKCommand, _ decoded: any MKCommand, on scene: MKScene) throws {
        #expect(decoded.id == original.id)
        #expect(decoded.coalescingKey == original.coalescingKey)
        #expect(try decoded.apply(to: scene) == (try original.apply(to: scene)))
    }

    @Test func batchTransformCommandRoundTrips() throws {
        let scene = FixtureScenes.flatNodesScene(count: 3)
        let command = MKBatchTransformCommand(gestureID: UUID(), newTransforms: [
            scene.nodes[0].id: MKTransform2D(position: CGPoint(x: 7, y: -2), rotation: 0.4),
            scene.nodes[2].id: MKTransform2D(position: CGPoint(x: 1, y: 1), scale: CGSize(width: 2, height: 2)),
        ])
        let decoded = try roundTrip(command)
        #expect(decoded is MKBatchTransformCommand)
        try assertSameEffect(command, decoded, on: scene)
    }

    @Test func batchCoreCommandRoundTrips() throws {
        let scene = FixtureScenes.flatNodesScene(count: 2)
        var core = scene.nodes[1].core
        core.opacity = 0.25
        core.name = "معدل"
        let command = MKBatchCoreCommand(gestureID: UUID(), newCores: [scene.nodes[1].id: core], label: "تحرير")
        let decoded = try roundTrip(command)
        #expect(decoded is MKBatchCoreCommand)
        #expect((decoded as? MKBatchCoreCommand)?.name == "تحرير")
        try assertSameEffect(command, decoded, on: scene)
    }

    @Test func textEditCommandRoundTrips() throws {
        let scene = FixtureScenes.arabicBasicScene()
        let nodeID = scene.nodes[0].id
        let replacement = MKNode.liveText(MKLiveTextNode(
            core: scene.nodes[0].core, text: MKSourceText(string: "بسم الله الرحمن الرحيم كاملة")
        ))
        let command = MKTextEditCommand(nodeID: nodeID, newNode: replacement, burstKey: "textEdit:\(nodeID):3")
        let decoded = try roundTrip(command)
        #expect(decoded is MKTextEditCommand)
        #expect(decoded.coalescingKey == "textEdit:\(nodeID):3")
        try assertSameEffect(command, decoded, on: scene)
    }

    /// The WS-04 adoption target (see CONTRACTS.md): an arrange derivation
    /// expressed as `MKReplaceNodesCommand` ، replace a `liveText` node
    /// with a full `.arranged` node payload ، must round-trip through the
    /// coder with label, coalescing key, and behavioral effect intact.
    /// The `.arranged` payload here is the real arranged-لا fixture, so
    /// this also proves the coder handles the deepest node payload in the
    /// model (glyph refs, provenance, ligature state, source backup).
    @Test func replaceNodesCommandRoundTripsAnArrangeDerivation() throws {
        let liveScene = FixtureScenes.arabicBasicScene()
        let liveNodeID = liveScene.nodes[0].id
        guard case .arranged(var arrangedNode) = FixtureScenes.arrangedLaScene().nodes[0] else {
            Issue.record("expected arranged fixture node")
            return
        }
        // Same core (task-4 style "same transform/z" derivation shape).
        arrangedNode.core = liveScene.nodes[0].core

        let command = MKReplaceNodesCommand(
            nodeID: liveNodeID, newNode: .arranged(arrangedNode), label: "تنسيق حر" // arrange
        )
        let decoded = try roundTrip(command)
        #expect(decoded is MKReplaceNodesCommand)
        #expect((decoded as? MKReplaceNodesCommand)?.name == "تنسيق حر")
        #expect(decoded.coalescingKey == nil) // one-shot structural default
        try assertSameEffect(command, decoded, on: liveScene)

        // Inverse restores the original liveText node exactly.
        let inverse = command.inverse(against: liveScene)
        let applied = try command.apply(to: liveScene)
        #expect(try inverse.apply(to: applied) == liveScene)
    }

    @Test func replaceNodesCommandCoalescingKeyIsOptInForContinuousGestures() throws {
        let scene = FixtureScenes.flatNodesScene(count: 1)
        let oneShot = MKReplaceNodesCommand(nodeID: scene.nodes[0].id, newNode: scene.nodes[0], label: "ت")
        #expect(oneShot.coalescingKey == nil)

        let gestureID = UUID()
        let continuous = MKReplaceNodesCommand(
            nodeID: scene.nodes[0].id, newNode: scene.nodes[0], label: "ت",
            coalescingKeySuffix: "style:\(gestureID)"
        )
        #expect(continuous.coalescingKey == "replaceNodes-style:\(gestureID)")
        let decoded = try roundTrip(continuous)
        #expect(decoded.coalescingKey == continuous.coalescingKey)
    }

    /// P6 Paste's primitive: multiple fresh nodes inserted in one undo
    /// entry ، round-trips through the coder and its inverse restores the
    /// pre-paste top-level array exactly (mirrors `MKGroupCommand`'s own
    /// inverse-restore coverage above).
    @Test func insertNodesCommandRoundTrips() throws {
        let scene = FixtureScenes.flatNodesScene(count: 2)
        let pasted = [
            MKNode.shape(MKShapeNode(core: MKNodeCore(name: "ملصق١"), geometry: .ellipse)),
            MKNode.shape(MKShapeNode(core: MKNodeCore(name: "ملصق٢"), geometry: .rect(cornerRadius: 0))),
        ]
        let command = MKInsertNodesCommand(nodes: pasted)
        let decoded = try roundTrip(command)
        #expect(decoded is MKInsertNodesCommand)
        #expect(decoded.coalescingKey == nil)
        try assertSameEffect(command, decoded, on: scene)

        let inverse = command.inverse(against: scene)
        let applied = try command.apply(to: scene)
        #expect(applied.nodes.count == scene.nodes.count + 2)
        #expect(try inverse.apply(to: applied) == scene)
    }

    @Test func ungroupCommandRoundTrips() throws {
        var scene = FixtureScenes.flatNodesScene(count: 3)
        let groupID = MKNodeID()
        scene = try MKGroupCommand(nodeIDs: [scene.nodes[0].id, scene.nodes[1].id], groupName: "مجموعة", groupID: groupID).apply(to: scene)
        scene = try MKTransformCommand(nodeID: groupID, newTransform: MKTransform2D(position: CGPoint(x: 50, y: 50), rotation: 0.5)).apply(to: scene)

        let command = MKUngroupCommand(groupID: groupID)
        let decoded = try roundTrip(command)
        #expect(decoded is MKUngroupCommand)
        // The decoded ungroup must produce the same (transform-composed)
        // result ، this doubles as coder-level coverage of the fix-1
        // semantics.
        try assertSameEffect(command, decoded, on: scene)
    }

    @Test func everyCatalogCommandTypeHasACoderCase() throws {
        let scene = FixtureScenes.flatNodesScene(count: 2)
        let node = MKNode.shape(MKShapeNode(core: MKNodeCore(name: "ش"), geometry: .ellipse))
        let commands: [any MKCommand] = [
            MKInsertNodeCommand(node: node),
            MKInsertNodesCommand(nodes: [node]),
            MKRemoveNodeCommand(nodeID: scene.nodes[0].id),
            MKReorderCommand(nodeID: scene.nodes[0].id, toIndex: 1),
            MKTransformCommand(nodeID: scene.nodes[0].id, newTransform: .identity),
            MKStyleCommand(nodeID: scene.nodes[0].id, newStyle: .default),
            MKLockHideCommand(nodeID: scene.nodes[0].id, isLocked: true, isHidden: false),
            MKRenameCommand(nodeID: scene.nodes[0].id, newName: "اسم"),
            MKCanvasSpecCommand(newCanvas: MKCanvasSpec(size: CGSize(width: 5, height: 5))),
            MKRestoreTopLevelNodesCommand(previousNodes: scene.nodes),
            MKGroupCommand(nodeIDs: [scene.nodes[0].id], groupName: "م"),
            MKUngroupCommand(groupID: scene.nodes[0].id),
            MKReplaceNodeCommand(nodeID: scene.nodes[0].id, newNode: node),
            MKReplaceNodesCommand(nodeID: scene.nodes[0].id, newNode: node, label: "استبدال"),
            MKBatchTransformCommand(gestureID: UUID(), newTransforms: [:]),
            MKBatchCoreCommand(gestureID: UUID(), newCores: [:]),
            MKTextEditCommand(nodeID: scene.nodes[0].id, newNode: node, burstKey: "k"),
            MKNoOpCommand(),
        ]
        for command in commands {
            let decoded = try roundTrip(command)
            #expect(type(of: decoded) == type(of: command), "coder changed type for \(type(of: command))")
        }
    }

    /// End-to-end journal-replay coverage including a batch command ، the
    /// exact gesture class (multi-select drag) that was silently exempt
    /// from replay before this session's fix.
    @Test func journalReplayRecoversABatchTransformGesture() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-coder-journal-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("proj.makhtoot")
        let package = try DocumentPackage.create(
            at: url, projectID: MKProjectID(), title: "ت", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
        )
        let journal = CommandJournal(journalURL: package.journalURL)

        // Baseline scene with three nodes, saved to disk.
        var scene = try package.readScene()
        let nodes = (0..<3).map { i in
            MKNode.shape(MKShapeNode(core: MKNodeCore(name: "عنصر \(i)"), geometry: .ellipse))
        }
        for n in nodes { scene = try MKInsertNodeCommand(node: n).apply(to: scene) }
        try package.writeScene(scene)

        // Journal (never flush): a batch multi-select drag end-state, a
        // text edit, and an arrange-shaped structural replace ، the
        // formerly journal-invisible command classes.
        guard case .arranged(var arrangedNode) = FixtureScenes.arrangedLaScene().nodes[0] else {
            Issue.record("expected arranged fixture node")
            return
        }
        arrangedNode.core = nodes[1].core

        var current = scene
        let gestureID = UUID()
        let commands: [any MKCommand] = [
            MKBatchTransformCommand(gestureID: gestureID, newTransforms: [
                nodes[0].id: MKTransform2D(position: CGPoint(x: 40, y: 40)),
                nodes[1].id: MKTransform2D(position: CGPoint(x: 40, y: 60), rotation: 0.1),
            ]),
            MKTextEditCommand(
                nodeID: nodes[2].id,
                newNode: MKNode.liveText(MKLiveTextNode(core: nodes[2].core, text: MKSourceText(string: "مرحبا"))),
                burstKey: "textEdit:\(nodes[2].id):0"
            ),
            // WS-04-shaped structural op: "derive" nodes[1] into an
            // arranged node via the canonical replace command.
            MKReplaceNodesCommand(nodeID: nodes[1].id, newNode: .arranged(arrangedNode), label: "تنسيق حر"),
        ]
        for command in commands {
            let baseRev = MKSceneRevision.hash(current)
            try await journal.append(command: command, baseRev: baseRev)
            current = try command.apply(to: current)
        }

        // "Reopen" and recover.
        let savedScene = try package.readScene()
        let recovery = try await CrashRecovery.recover(package: package, savedScene: savedScene, journal: journal)

        #expect(recovery.replayedCommandCount == 3)
        #expect(recovery.recoveredScene == current)
        #expect(recovery.recoveredScene.node(id: nodes[0].id)?.core.transform.position == CGPoint(x: 40, y: 40))
        guard case .liveText(let lt) = recovery.recoveredScene.node(id: nodes[2].id) else {
            Issue.record("expected the text-edited node to survive replay as liveText")
            return
        }
        #expect(lt.text.string == "مرحبا")
    }
}
