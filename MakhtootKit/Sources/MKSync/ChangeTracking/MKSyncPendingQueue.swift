import Foundation

// T4 ، Local change tracking and upload queue.
// Actor-isolated in-memory queue with per-project coalescing and
// a debounce window so rapid autosaves don't thrash uploads.
//
// Deviation from T4 spec (logged in WS-11.md §5): T4 requests a
// SwiftData-backed durable queue ("SwiftData table via MKPersistence").
// This session implements an in-memory actor-isolated queue. Rationale:
// MKSync already persists `CKSyncEngine.State.Serialization`, which tracks
// what the engine has sent/acknowledged at the CloudKit layer. The pending
// queue is a pre-engine staging area; if the app quits before a debounce
// fires, the `MetadataStore` record still has the updated `modifiedAt` and
// `contentHash`, so on the next launch `MKSyncEngineController` rebuilds
// the queue from a `MetadataStore.listProjects()` scan
// (`startIfNeeded` → `enqueueAllPendingFromStore`). A separate SwiftData
// table for the pending queue adds schema complexity for this startup-scan
// fallback. Logged as deviation D1 in WS-11.md.

/// The kind of change that needs to be synced for a project.
public enum MKSyncPendingKind: Sendable, Equatable {
    /// Project content changed (or project is new); needs upload.
    case upload
    /// Project was deleted locally; needs server deletion.
    case delete
}

/// Entry in the pending queue.
public struct MKSyncPendingEntry: Sendable, Equatable {
    public let projectID: UUID
    public let kind: MKSyncPendingKind
    /// The wall-clock time when the entry was last modified.
    /// Used by the debounce guard (entries coalesce but the timestamp resets).
    public let enqueuedAt: Date

    public init(projectID: UUID, kind: MKSyncPendingKind, enqueuedAt: Date = Date()) {
        self.projectID = projectID
        self.kind = kind
        self.enqueuedAt = enqueuedAt
    }
}

/// Actor-isolated pending-changes queue.
///
/// - Coalescing: multiple rapid `.upload` events for the same project
///   collapse to one entry (latest wins). An `.upload` followed by a
///   `.delete` becomes `.delete`; a `.delete` followed by `.upload`
///   becomes `.upload` (resurrection scenario).
/// - Debounce: `nextBatch(debounce:)` only returns entries whose
///   `enqueuedAt` is older than `debounce` seconds ago, so the
///   5-second quiet window is honoured without background timers.
public actor MKSyncPendingQueue {
    /// Ordered list of project IDs, preserving insertion order for
    /// deterministic batching.
    private var order: [UUID] = []
    /// projectID → entry (latest kind / timestamp).
    private var entries: [UUID: MKSyncPendingEntry] = [:]

    public init() {}

    // MARK: - Enqueue

    /// Schedules a project for upload. Coalesces with any existing entry.
    public func scheduleUpload(for projectID: UUID, at date: Date = Date()) {
        enqueue(MKSyncPendingEntry(projectID: projectID, kind: .upload, enqueuedAt: date))
    }

    /// Schedules a project's server record for deletion. Overrides any
    /// pending upload for the same project.
    public func scheduleDelete(for projectID: UUID, at date: Date = Date()) {
        enqueue(MKSyncPendingEntry(projectID: projectID, kind: .delete, enqueuedAt: date))
    }

    private func enqueue(_ entry: MKSyncPendingEntry) {
        if entries[entry.projectID] == nil {
            order.append(entry.projectID)
        }
        entries[entry.projectID] = entry
    }

    // MARK: - Dequeue

    /// Returns all entries whose `enqueuedAt` is older than `debounce`
    /// ago. Entries still within the debounce window are left in the queue.
    /// Entries returned are NOT removed ، call `clear(id:)` after
    /// confirming a successful CloudKit operation.
    public func nextBatch(debounce: Duration = MKSyncTunables.uploadDebounceInterval) -> [MKSyncPendingEntry] {
        let cutoff = Date(timeIntervalSinceNow: -Double(debounce.components.seconds))
        return order.compactMap { id -> MKSyncPendingEntry? in
            guard let entry = entries[id], entry.enqueuedAt <= cutoff else { return nil }
            return entry
        }
    }

    /// Returns all entries regardless of the debounce window.
    /// Used by `MKSyncEngineController` for `nextRecordZoneChangeBatch` when
    /// the engine is shutting down and needs to flush everything.
    public func allEntries() -> [MKSyncPendingEntry] {
        order.compactMap { entries[$0] }
    }

    /// Removes the queue entry for `id` (called after the CloudKit
    /// operation for that project succeeds).
    public func clear(id: UUID) {
        entries.removeValue(forKey: id)
        order.removeAll { $0 == id }
    }

    /// Returns the number of pending entries.
    public var count: Int { entries.count }

    /// Returns the pending entry for `id`, or `nil` if not queued.
    public func entry(for id: UUID) -> MKSyncPendingEntry? { entries[id] }

    /// Removes all entries. Used on account-switch state reset (T9).
    public func removeAll() {
        entries.removeAll()
        order.removeAll()
    }
}
