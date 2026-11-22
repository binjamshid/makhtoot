import CoreGraphics
import Foundation
import MKFoundation
import Testing
@testable import MKModel
@testable import MKPersistence

/// WS-02 packet §5 task 13 accept criteria: crash-recovery test ، apply 10
/// commands, simulate termination before autosave flush, reopen, all 10
/// mutations present. Durability gate (packet §7): 20/20 iterations.
@Suite("CommandJournal / CrashRecovery")
struct CommandJournalCrashRecoveryTests {
    private func makePackage() throws -> (DocumentPackage, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("mk-journal-tests-\(UUID().uuidString)", isDirectory: true)
        let url = root.appendingPathComponent("proj.makhtoot")
        let package = try DocumentPackage.create(
            at: url, projectID: MKProjectID(), title: "ت", canvas: MKCanvasSpec(size: CGSize(width: 10, height: 10))
        )
        return (package, root)
    }

    /// One full "apply 10 commands, crash before autosave flush, reopen"
    /// cycle. Returns the recovered scene and replay count for the caller
    /// to assert on.
    private func runOneCrashRecoveryCycle() async throws -> (recovered: MKScene, replayedCount: Int, root: URL) {
        let (package, root) = try makePackage()
        let journal = CommandJournal(journalURL: package.journalURL)

        var scene = try package.readScene()
        let node = MKNode.shape(MKShapeNode(core: MKNodeCore(name: "شكل"), geometry: .ellipse))
        scene = try MKInsertNodeCommand(node: node).apply(to: scene)
        try package.writeScene(scene) // this is the "last saved" baseline scene.json

        // Apply 10 MORE commands, journaling each (forward form) but NEVER
        // calling a full save ، simulating termination before the
        // debounced autosave flush ever fires.
        var currentScene = scene
        for i in 0..<10 {
            let baseRev = MKSceneRevision.hash(currentScene)
            let command = MKRenameCommand(nodeID: node.id, newName: "اسم \(i)")
            try await journal.append(command: command, baseRev: baseRev)
            currentScene = try command.apply(to: currentScene)
        }
        // NOTE: `journal.truncate()` is deliberately never called ، that's
        // the "crash before flush" simulation.

        // "Reopen": read the (still-old) saved scene.json + replay the
        // journal, exactly what `CrashRecovery.recover` does on open.
        let savedScene = try package.readScene()
        let recovery = try await CrashRecovery.recover(package: package, savedScene: savedScene, journal: journal)
        return (recovery.recoveredScene, recovery.replayedCommandCount, root)
    }

    @Test func crashRecoveryReplaysAllTenMutations20Of20Iterations() async throws {
        for iteration in 0..<20 {
            let (recovered, replayedCount, root) = try await runOneCrashRecoveryCycle()
            defer { try? FileManager.default.removeItem(at: root) }

            #expect(replayedCount == 10, "iteration \(iteration): expected 10 replayed commands")
            guard case .shape(let node) = recovered.nodes.first else {
                Issue.record("iteration \(iteration): expected the shape node to survive recovery")
                continue
            }
            #expect(node.core.name == "اسم 9", "iteration \(iteration): last rename should have won")
        }
    }

    @Test func recoveryWritesARescueSnapshot() async throws {
        let (recovered, _, root) = try await runOneCrashRecoveryCycle()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = recovered

        let package = DocumentPackage(rootURL: root.appendingPathComponent("proj.makhtoot"))
        let backups = try FileManager.default.contentsOfDirectory(atPath: package.backupsDirURL.path)
        #expect(backups.contains { $0.hasPrefix("rescue-") })
    }

    @Test func emptyJournalMeansNoRecoveryOccurred() async throws {
        let (package, root) = try makePackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = CommandJournal(journalURL: package.journalURL)
        let savedScene = try package.readScene()

        let recovery = try await CrashRecovery.recover(package: package, savedScene: savedScene, journal: journal)
        #expect(recovery.recoveryOccurred == false)
        #expect(recovery.replayedCommandCount == 0)
        #expect(recovery.recoveredScene == savedScene)
    }

    @Test func corruptTrailingJournalLineStopsReplayAtTheValidPrefix() async throws {
        let (package, root) = try makePackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = CommandJournal(journalURL: package.journalURL)
        let savedScene = try package.readScene()

        let baseRev = MKSceneRevision.hash(savedScene)
        try await journal.append(command: MKCanvasSpecCommand(newCanvas: MKCanvasSpec(size: CGSize(width: 99, height: 99))), baseRev: baseRev)

        // Append a deliberately corrupt (non-JSON) trailing line directly.
        let handle = try FileHandle(forWritingTo: package.journalURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{not valid json\n".utf8))
        try handle.close()

        let recovery = try await CrashRecovery.recover(package: package, savedScene: savedScene, journal: journal)
        #expect(recovery.replayedCommandCount == 1) // the one valid line before the corrupt one
        #expect(recovery.damagedTailPreserved != nil)
        if let damagedURL = recovery.damagedTailPreserved {
            #expect(FileManager.default.fileExists(atPath: damagedURL.path))
        }
    }

    @Test func truncateResetsTheJournalToEmpty() async throws {
        let (package, root) = try makePackage()
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = CommandJournal(journalURL: package.journalURL)

        try await journal.append(command: MKNoOpCommand(), baseRev: "r")
        #expect(await journal.isEmpty() == false)
        try await journal.truncate()
        #expect(await journal.isEmpty() == true)
    }
}
