import Testing
import CoreGraphics
import Foundation
import MKArrange
import MKFoundation
import MKModel
import MKPersistence

/// Run-3 session: WS-04's own gap, resolved per `CONTRACTS.md`'s
/// "WS-04 (`MKArrange`) ، arrange-engine contract" adoption row and
/// `docs/impl-log/WS-02.md` session 3 ، every arrange operation (derive,
/// revert, join break/restore, ligature decompose/recompose, mark attach/
/// detach/move, style/transform edits) must be journal-replayable through
/// `MKPersistence.MKCommandCoder`'s closed catalog, since a crash before
/// the next autosave flush must not silently lose an in-flight arrange
/// edit (D-223/no-loss). `MKArrangedCompositionCommand` (the module-local
/// type this session retires) could never be named by `MKCommandCoder`'s
/// switch (`MKArrange` depends on `MKPersistence`, never the reverse) ،
/// `CommandJournal.append` threw `unknownCommandType` for it, silently
/// swallowed by `MakhtootDocument.apply`'s `try?`.
///
/// These tests don't touch `CommandJournal`/`CrashRecovery` directly
/// (those live in `MKPersistence`, outside this packet's fence, and are
/// already covered by that module's own durability-gate tests) ، they
/// isolate exactly the seam this session's fix lives in:
/// `MKCommandCoder.encode`/`.decode` round-tripping every command this
/// module hands to the undo stack / journal, then REPLAYING the decoded
/// command against a fresh copy of the pre-edit scene (simulating exactly
/// what `CrashRecovery.recover` does: replay the journaled forward form
/// onto the last-saved scene) and asserting the replayed result is
/// byte-identical (`MKScene: Equatable`) to the real, in-memory forward
/// application.
@Suite struct JournalRoundTripTests {
    /// The task's own required gate: a full derive→revert sequence,
    /// encoded via `MKCommandCoder`, replayed, and asserted scene-equal.
    /// (`arrangeCommand`/`revertCommand` already went through the
    /// pre-existing, already-codable `MKReplaceNodeCommand` ، this is the
    /// end-to-end proof that the FULL lifecycle survives an actual
    /// encode/decode/replay pass, not just an in-memory apply/inverse
    /// round trip.)
    @Test func deriveThenRevertRoundTripsThroughMKCommandCoderReplay() async throws {
        let text = "بسم الله"
        let style = ArrangeFixtures.systemStyle()
        let core = MKNodeCore(name: "نص", transform: MKTransform2D(position: CGPoint(x: 10, y: 20)), zOrder: 2, opacity: 0.9)
        let originalNode = MKNode.liveText(MKLiveTextNode(core: core, text: MKSourceText(string: text), style: style))
        let originalScene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 300, height: 300)), nodes: [originalNode])

        // Forward path (in-memory, no journal involved) ، the "truth" the
        // journal replay below must reproduce exactly.
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)
        let arrangeCommand = ArrangeCommands.arrangeCommand(sourceNodeID: core.id, core: core, composition: composition, derivedFrom: .liveText)
        let arrangedScene = try arrangeCommand.apply(to: originalScene)
        guard case .arranged(let arrangedNode)? = arrangedScene.node(id: core.id) else {
            Issue.record("expected the node to become .arranged")
            return
        }
        let revertCommand = try RevertService().revertCommand(arrangedNodeID: core.id, node: arrangedNode)
        let revertedScene = try revertCommand.apply(to: arrangedScene)

        // Journal path: encode BOTH commands via MKCommandCoder (the exact
        // serializer CommandJournal/CrashRecovery use in production),
        // decode them back, and REPLAY against a fresh copy of the
        // pre-edit scene ، simulating a crash-recovery replay of an
        // in-flight derive→revert sequence that never reached a flush.
        let encodedArrange = try MKCommandCoder.encode(arrangeCommand)
        let encodedRevert = try MKCommandCoder.encode(revertCommand)
        let decodedArrange = try MKCommandCoder.decode(encodedArrange)
        let decodedRevert = try MKCommandCoder.decode(encodedRevert)

        let replayedArrangedScene = try decodedArrange.apply(to: originalScene)
        let replayedFinalScene = try decodedRevert.apply(to: replayedArrangedScene)

        #expect(replayedArrangedScene == arrangedScene, "replayed derive step must match the in-memory forward apply exactly")
        #expect(replayedFinalScene == revertedScene, "replayed revert step must match the in-memory forward apply exactly")
        #expect(replayedFinalScene == originalScene, "derive→revert round-trips back to the byte-identical original scene")
    }

    /// Regression coverage for the ACTUAL bug this session fixes: a
    /// composition-INTERNAL mutation (style edit ، one representative of
    /// join-break/decompose/mark-attach/etc., all built through the same
    /// `ArrangeCommands.replaceComposition` primitive) must ALSO survive
    /// encode→decode→replay now that it constructs a `MKReplaceNodesCommand`
    /// rather than the non-codable, now-retired `MKArrangedCompositionCommand`.
    /// Before this session's fix, `MKCommandCoder.encode` would have thrown
    /// `unknownCommandType` for this exact command.
    @Test func compositionInternalEditRoundTripsThroughMKCommandCoderReplay() async throws {
        let text = "بسم"
        let style = ArrangeFixtures.systemStyle()
        let capture = await ArrangeFixtures.capture(text, style: style)
        let composition = await ArrangeDeriver().derive(sourceText: text, style: style, capture: capture)
        let core = MKNodeCore(name: "نص")
        let ownerNode = MKArrangedTextNode(core: core, composition: composition, derivedFrom: .liveText)
        let scene = MKScene(canvas: MKCanvasSpec(size: CGSize(width: 200, height: 200)), nodes: [.arranged(ownerNode)])

        let glyphIDs = Set(composition.nodes.compactMap { child -> MKNodeID? in
            if case .glyph(let g) = child { return g.id }
            return nil
        })
        #expect(!glyphIDs.isEmpty, "بسم should derive at least one glyph node")
        let redFill = MKStyle(fill: .solid(MKSolidColor(r: 1, g: 0, b: 0)))
        let command = ArrangeStyleEditor.setStyle(redFill, forChildIDs: glyphIDs, ownerNode: ownerNode)
        let editedScene = try command.apply(to: scene)

        let encoded = try MKCommandCoder.encode(command)
        let decoded = try MKCommandCoder.decode(encoded)
        let replayedScene = try decoded.apply(to: scene)

        #expect(replayedScene == editedScene, "a composition-internal edit must replay identically through MKCommandCoder")

        // Undo must equally be a codable canonical command (the retired
        // type's inverse would never have reached the journal either).
        let inverse = command.inverse(against: scene)
        let encodedInverse = try MKCommandCoder.encode(inverse)
        let decodedInverse = try MKCommandCoder.decode(encodedInverse)
        let undoneScene = try decodedInverse.apply(to: editedScene)
        #expect(undoneScene == scene, "undo of a composition-internal edit must also replay identically through MKCommandCoder")
    }
}
