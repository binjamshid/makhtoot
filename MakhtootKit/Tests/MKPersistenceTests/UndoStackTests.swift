import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §5 task 11 accept criterion: 60 Hz simulated drag of 120
/// transform updates yields exactly 1 undo entry; undo restores the
/// pre-drag transform.
@MainActor
@Suite("MKUndoStack")
struct UndoStackTests {
    @Test func coalescedDragProducesExactlyOneUndoEntry() throws {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id
        let preDragTransform = scene.node(id: nodeID)!.core.transform

        stack.beginGesture()
        for i in 1...120 { // simulated 60 Hz drag, 2 seconds
            let command = MKTransformCommand(nodeID: nodeID, newTransform: MKTransform2D(position: CGPoint(x: Double(i), y: Double(i))))
            scene = try stack.perform(command, currentScene: scene)
        }
        stack.endGesture()

        #expect(stack.undo.count == 1)
        #expect(scene.node(id: nodeID)!.core.transform.position == CGPoint(x: 120, y: 120))

        let undone = try stack.undoLast(currentScene: scene)
        #expect(undone != nil)
        #expect(undone!.node(id: nodeID)!.core.transform.position == preDragTransform.position)
    }

    @Test func nonCoalescedCommandsEachGetTheirOwnUndoEntry() throws {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id

        for i in 0..<3 {
            let command = MKRenameCommand(nodeID: nodeID, newName: "اسم \(i)")
            scene = try stack.perform(command, currentScene: scene)
        }
        #expect(stack.undo.count == 3)
    }

    @Test func performClearsTheRedoStack() throws {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id

        scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "أ"), currentScene: scene)
        scene = try stack.undoLast(currentScene: scene) ?? scene
        #expect(stack.canRedo)

        scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "ب"), currentScene: scene)
        #expect(stack.canRedo == false)
    }

    @Test func redoReappliesTheUndoneCommand() throws {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id

        scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "جديد"), currentScene: scene)
        let afterApply = scene
        scene = try stack.undoLast(currentScene: scene) ?? scene
        scene = try stack.redoLast(currentScene: scene) ?? scene
        #expect(scene == afterApply)
    }

    @Test func evictionDropsOldestEntriesAt25PercentWhenOverBudget() throws {
        let stack = MKUndoStack(maxEntries: 4)
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id
        for i in 0..<10 {
            scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "n\(i)"), currentScene: scene)
        }
        #expect(stack.undo.count <= 4)
    }

    // MARK: - P-5 (AUDIT_2026-07-28.md): MKMemoryAccountable conformance

    @Test func accountedBytesIsZeroForAnEmptyStack() {
        let stack = MKUndoStack()
        #expect(stack.accountedBytes() == 0)
    }

    @Test func accountedBytesIsPositiveOnceEntriesExist() throws {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id
        for i in 0..<5 {
            scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "n\(i)"), currentScene: scene)
        }
        #expect(stack.accountedBytes() > 0)
    }

    /// Verify text: "pushing >maxEntries then evictOffscreen() drops count
    /// by ~half." Pushes exactly up to `maxEntries` (never exceeding it, so
    /// no incremental per-`perform` eviction fires first), then
    /// `evictOffscreen()` halves the cap in one shot ، `evictIfNeeded()`'s
    /// loop (not a single 25% slice) is what makes the resulting count
    /// actually converge under the NEW, halved cap rather than merely
    /// removing one slice relative to the old one.
    @Test func evictOffscreenHalvesTheCapAndConvergesUnderIt() throws {
        let stack = MKUndoStack(maxEntries: 100)
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id
        for i in 0..<100 {
            scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "n\(i)"), currentScene: scene)
        }
        #expect(stack.undo.count == 100)

        stack.evictOffscreen()

        #expect(stack.maxEntries == 50)
        #expect(stack.undo.count <= 50, "evictOffscreen() must converge fully under the halved cap, not just remove one 25% slice")
        #expect(stack.undo.count >= 30, "evictOffscreen() dropping the stack to near-empty would be a far more aggressive reclaim than \"halves the cap\" calls for")
    }

    @Test func evictAllClearsBothUndoAndRedo() throws {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id
        for i in 0..<10 {
            scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "n\(i)"), currentScene: scene)
        }
        scene = try stack.undoLast(currentScene: scene) ?? scene
        #expect(stack.canRedo)

        stack.evictAll()

        #expect(stack.undo.isEmpty)
        #expect(stack.redo.isEmpty)
        #expect(stack.accountedBytes() == 0)
    }

    /// Regression guard for the governor registration itself
    /// (`EditorViewModel.init`'s `governor.register(document.undoStack,
    /// priority: .standard)`): confirms `MKUndoStack` is usable through the
    /// `any MKMemoryAccountable` existential a real `MKMemoryGovernor`
    /// holds, not just callable via its own concrete methods.
    @Test func conformsToMKMemoryAccountableForGovernorRegistration() async throws {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id
        for i in 0..<5 {
            scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "n\(i)"), currentScene: scene)
        }

        let governor = MKMemoryGovernor()
        await governor.register(stack, priority: .standard)
        let total = await governor.totalAccountedBytes()
        #expect(total > 0)

        await governor.evictOffscreen()
        #expect(stack.maxEntries < 500, "evictOffscreen() reaching the stack through the governor must actually shrink its cap")
    }
}
