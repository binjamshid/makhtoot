import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// FC-3 (AUDIT_2026-07-28.md): `MKRender.MKDegradationController`'s D-116
/// ladder calls `MKUndoStack.setMaxEntries(_:)` directly from its
/// stage1/stage2 branches, via the `MKUndoCapReclaiming` adapter seam
/// declared alongside that controller (`MKRender/DegradationController.swift`)
/// ، a SEPARATE reclaim path from the `MKMemoryAccountable`/governor
/// registration `MKUndoStack` also participates in (P-5).
///
/// This suite lives in `MKPersistenceTests`, which does not (and should
/// not, per the D-230/DEPENDENCY_GRAPH.md boundary `MKRender`'s own doc
/// comments cite) depend on `MKRender`, so it cannot drive a real
/// `MKDegradationController` end to end. Instead it exercises the CONSUMER
/// side of the FC-3 contract directly: `MKUndoStack.setMaxEntries(_:)`
/// itself, called with the kind of below-default cap a stage1/stage2
/// transition would apply, standing in for that call site.
@MainActor
@Suite("MKUndoStack degradation reclaim (FC-3)")
struct UndoStackDegradationTests {
    /// Builds a stack with `count` non-coalesced undo entries (default
    /// `maxEntries` of 500, so no eviction fires during buildup as long as
    /// `count` stays well under that). Returns the resulting scene and node
    /// ID too, so callers can keep performing further commands against the
    /// SAME node ، `FixtureScenes.flatNodesScene(_:)` mints a fresh random
    /// `MKNodeID` (`MKNodeCore.init`'s `id: MKNodeID = MKNodeID()` default)
    /// on every call, so a second, independent fixture scene would not
    /// contain this stack's node.
    private func buildStack(entries count: Int) throws -> (stack: MKUndoStack, scene: MKScene, nodeID: MKNodeID) {
        let stack = MKUndoStack()
        var scene = FixtureScenes.flatNodesScene(count: 1)
        let nodeID = scene.nodes[0].id
        for i in 0..<count {
            scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "n\(i)"), currentScene: scene)
        }
        return (stack, scene, nodeID)
    }

    @Test func stage1StyleCapReclaimsBelowTheDefault() throws {
        let (stack, _, _) = try buildStack(entries: 20)
        #expect(stack.undo.count == 20)
        #expect(stack.maxEntries == 500)   // the default, unchanged so far

        // Simulated D-116 stage1 branch: the ladder shrinks the cap well
        // below the 500 default.
        let stage1Cap = 16
        #expect(stage1Cap < 500)
        stack.setMaxEntries(stage1Cap)

        #expect(stack.maxEntries == stage1Cap)
        #expect(stack.undo.count <= stage1Cap)
    }

    /// Stage2 is the more severe pre-critical stage (D-116): its reclaim
    /// must be strictly tighter than stage1's, applied on top of an
    /// already-reduced stack.
    @Test func stage2StyleCapIsStrictlyTighterThanStage1() throws {
        let (stack, _, _) = try buildStack(entries: 20)

        let stage1Cap = 16
        let stage2Cap = 12
        #expect(stage2Cap < stage1Cap)

        stack.setMaxEntries(stage1Cap)
        #expect(stack.undo.count <= stage1Cap)

        stack.setMaxEntries(stage2Cap)
        #expect(stack.maxEntries == stage2Cap)
        #expect(stack.undo.count <= stage2Cap)
    }

    /// The cap reduction must not be a one-time trim that later drifts back
    /// above budget as new commands are performed ، `evictIfNeeded()` keeps
    /// enforcing the (now smaller) `maxEntries` on every subsequent
    /// `perform(_:currentScene:)` call, same as it already does for a cap
    /// set at construction time (`evictionDropsOldestEntriesAt25PercentWhenOverBudget`
    /// in `UndoStackTests.swift`).
    @Test func capReductionStaysInEffectAcrossSubsequentCommands() throws {
        let (stack, initialScene, nodeID) = try buildStack(entries: 20)

        let reducedCap = 10
        stack.setMaxEntries(reducedCap)
        #expect(stack.maxEntries == reducedCap)

        // Keep performing NEW commands (against the SAME node, continuing
        // from the buildup scene above) after the reduced cap takes hold ،
        // `evictIfNeeded()` must keep enforcing it, not just trim once.
        var scene = initialScene
        for i in 0..<40 {
            scene = try stack.perform(MKRenameCommand(nodeID: nodeID, newName: "later-\(i)"), currentScene: scene)
        }

        #expect(stack.undo.count <= reducedCap)
    }
}
