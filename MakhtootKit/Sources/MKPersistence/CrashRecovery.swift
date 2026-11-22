import Foundation
import MKModel

// WS-02 packet §5 task 13 / ARCHITECTURE §14.5. On open: if `journal.mkj`
// is non-empty, decode+verify lines, replay the valid prefix onto the
// last-saved scene (stopping at the first `baseRev` chain mismatch, in
// addition to `CommandJournal`'s own per-line CRC/structural checks),
// write the recovered scene as a rescue snapshot, and report the count of
// mutations recovered.

public struct MKCrashRecoveryResult: Sendable {
    public let recoveredScene: MKScene
    public let replayedCommandCount: Int
    public let recoveryOccurred: Bool
    /// Non-nil if the journal had a structurally-damaged tail beyond the
    /// valid/replayed prefix ، the caller should surface "unsaved changes
    /// recovered" regardless, since SOME recovery still happened.
    public let damagedTailPreserved: URL?
}

public enum CrashRecovery {
    /// Timestamp formatter shared with `AutosaveController` rescue-file
    /// naming, so `backups/rescue-<ts>.json` sorts and reads consistently
    /// regardless of which mechanism wrote it.
    static func rescueTimestamp(_ date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        // Filesystem-safe: ':' is legal in POSIX paths but awkward in
        // practice on some tooling/exports ، replace with '-' per
        // ARCHITECTURE §13.1's example filename
        // ("rescue-2026-07-17T09-31-04Z.scene.json").
        return formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
    }

    /// Runs recovery for one already-open `DocumentPackage` + its
    /// `CommandJournal`. `savedScene` is the scene as last read from
    /// `scene.json` (i.e. what `journal.mkj`'s records replay ON TOP OF).
    public static func recover(
        package: DocumentPackage,
        savedScene: MKScene,
        journal: CommandJournal
    ) async throws -> MKCrashRecoveryResult {
        let (records, damagedTail) = try await journal.readValidRecords()

        var damagedTailURL: URL?
        if let damagedTail, !damagedTail.isEmpty {
            let damagedURL = package.journalURL.appendingPathExtension("damaged-\(rescueTimestamp())")
            try? damagedTail.write(to: damagedURL)
            damagedTailURL = damagedURL
        }

        guard !records.isEmpty else {
            return MKCrashRecoveryResult(
                recoveredScene: savedScene, replayedCommandCount: 0,
                recoveryOccurred: false, damagedTailPreserved: damagedTailURL
            )
        }

        var scene = savedScene
        var expectedBaseRev = MKSceneRevision.hash(savedScene)
        var replayedCount = 0

        for record in records {
            // §14.5: "verify... baseRev chain starting from the persisted
            // scene's hash; replay valid prefix, stop at first mismatch."
            guard record.baseRev == expectedBaseRev else { break }
            scene = try record.command.apply(to: scene)
            expectedBaseRev = MKSceneRevision.hash(scene)
            replayedCount += 1
        }

        guard replayedCount > 0 else {
            return MKCrashRecoveryResult(
                recoveredScene: savedScene, replayedCommandCount: 0,
                recoveryOccurred: false, damagedTailPreserved: damagedTailURL
            )
        }

        // Write the recovered scene as a rescue snapshot BEFORE handing it
        // back ، if the caller's subsequent normal save also fails, the
        // recovered state is still safe on disk.
        try FileManager.default.createDirectory(at: package.backupsDirURL, withIntermediateDirectories: true)
        let rescueURL = package.backupsDirURL.appendingPathComponent("rescue-\(rescueTimestamp()).scene.json")
        let sceneData = try MKSceneCodec.encode(scene)
        try MKAtomicIO.write(sceneData, to: rescueURL)

        return MKCrashRecoveryResult(
            recoveredScene: scene, replayedCommandCount: replayedCount,
            recoveryOccurred: true, damagedTailPreserved: damagedTailURL
        )
    }
}
