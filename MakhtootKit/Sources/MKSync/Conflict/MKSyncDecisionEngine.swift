import Foundation

// T6/T7 ، Remote change application decision logic.
// Pure static functions: no actors, no CloudKit, fully unit-testable.

// MARK: - Snapshot

/// The minimal state needed to make an LWW sync decision for one project.
public struct MKSyncSnapshot: Sendable, Equatable {
    /// SHA-256 hex content hash of the project's `scene.json`.
    public let contentHash: String
    /// Timestamp of the last content change.
    public let modifiedAt: Date

    public init(contentHash: String, modifiedAt: Date) {
        self.contentHash = contentHash
        self.modifiedAt = modifiedAt
    }
}

// MARK: - Decision result

/// The outcome of the LWW conflict resolution algorithm for one project.
public enum MKSyncDecisionResult: Sendable, Equatable {
    /// Remote is newer or local is unchanged ، apply remote over local.
    case applyRemote
    /// Local diverged from last sync but remote did not ، keep local, re-upload.
    case keepLocal
    /// Both sides diverged independently ، create a conflict copy and apply remote to original.
    case conflict
    /// Remote and local are identical (same hash) ، nothing to do.
    case noChange
    /// Remote `schemaVersion` exceeds this app's `supportedSchemaVersion`.
    /// Do not apply; do not overwrite remote. Surface `needsAppUpdate` status.
    case quarantine
    /// Remote signals deletion of this project. Local is unchanged → delete local.
    case applyRemoteDeletion
    /// Remote signals deletion but local has changed since last sync.
    /// User data wins: keep local, re-upload as a new record (resurrection rule ، T6.d).
    case resurrect
}

// MARK: - Decision engine (pure functions)

/// Stateless LWW (last-writer-wins) decision algorithm per T6 / T7.
///
/// All decisions are deterministic given the three inputs; no side effects.
public enum MKSyncDecisionEngine {
    // MARK: - Primary decision (T6)

    /// Determines what the sync engine should do when a remote record
    /// change arrives for a project.
    ///
    /// Corresponds to T6's four cases (a)–(d):
    /// - (a) No local project → `.applyRemote`
    /// - (b) Local unchanged since last sync → `.applyRemote`
    /// - (c) Local changed, remote unchanged → `.keepLocal`
    /// - (d) Both changed (divergence) → `.conflict`
    ///
    /// Schema-version quarantine (T14) takes precedence over all other cases.
    ///
    /// - Parameters:
    ///   - local: Snapshot of the local project, or `nil` if it doesn't exist yet.
    ///   - remote: Snapshot extracted from the remote `CKRecord`.
    ///   - lastSynced: The snapshot at the time of the last successful sync,
    ///     or `nil` if this project has never been synced.
    ///   - remoteSchemaVersion: `schemaVersion` from the remote record.
    ///   - supportedSchemaVersion: The highest schema version this app supports.
    public static func decide(
        local: MKSyncSnapshot?,
        remote: MKSyncSnapshot,
        lastSynced: MKSyncSnapshot?,
        remoteSchemaVersion: Int64 = 1,
        supportedSchemaVersion: Int64 = MKSyncTunables.supportedSchemaVersion
    ) -> MKSyncDecisionResult {
        // T14: Quarantine records from future app versions.
        if remoteSchemaVersion > supportedSchemaVersion {
            return .quarantine
        }

        // (a) No local project at all → apply remote.
        guard let local else {
            return .applyRemote
        }

        // Identical hashes → nothing to do.
        if local.contentHash == remote.contentHash {
            return .noChange
        }

        let localChangedSinceSync = lastSynced.map { local.contentHash != $0.contentHash } ?? true
        let remoteChangedSinceSync = lastSynced.map { remote.contentHash != $0.contentHash } ?? true

        switch (localChangedSinceSync, remoteChangedSinceSync) {
        case (false, true):
            // (b) Local unchanged, remote changed → apply remote (LWW).
            return .applyRemote
        case (true, false):
            // (c) Local changed, remote unchanged → keep local, re-upload.
            return .keepLocal
        case (true, true):
            // (d) Both changed → conflict.
            return .conflict
        case (false, false):
            // Hashes differ but neither changed since last sync?
            // Shouldn't happen; treat as no-change to be safe.
            return .noChange
        }
    }

    // MARK: - Deletion decision (T6.d resurrection rule)

    /// Determines what to do when a remote DELETE arrives for a project.
    ///
    /// - Parameters:
    ///   - local: Local snapshot, or `nil` if the project doesn't exist locally.
    ///   - lastSynced: Snapshot at last sync, or `nil` if never synced.
    public static func decideRemoteDeletion(
        local: MKSyncSnapshot?,
        lastSynced: MKSyncSnapshot?
    ) -> MKSyncDecisionResult {
        guard let local else {
            // Already gone locally; nothing to do (treat as applyRemoteDeletion
            // so callers clear any tombstone).
            return .applyRemoteDeletion
        }

        let localChangedSinceSync = lastSynced.map { local.contentHash != $0.contentHash } ?? true

        if localChangedSinceSync {
            // Resurrection rule (T6.d): user edited the project after the
            // remote deletion was issued. User data wins; re-upload as new.
            return .resurrect
        } else {
            // Local unchanged ، apply the deletion.
            return .applyRemoteDeletion
        }
    }
}
