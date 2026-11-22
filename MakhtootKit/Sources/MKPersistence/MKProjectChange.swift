import Foundation

// WS-11 addition: local mutation events emitted by MetadataStore so the
// sync engine (MKSync) can track which projects need to be uploaded.
// Lives in MKPersistence per CONTRACTS.md principle: the source of truth
// for project mutation is the store; the change stream belongs next to it.

/// A local mutation event published by `MetadataStore.changes`.
///
/// MKSync subscribes to this stream (single consumer) and enqueues
/// pending uploads/deletes when events arrive. The `.deleted` case does
/// NOT carry a tombstone itself ، `MetadataStore.tombstones()` is the
/// authoritative tombstone registry; the event is a push notification only.
public enum MKProjectChange: Sendable, Equatable {
    /// A new project was added to the metadata store.
    case created(MKProjectSummary)
    /// An existing project's content hash / modifiedAt changed (e.g. autosave).
    case modified(MKProjectSummary)
    /// A project was renamed (title-only change, no content hash change).
    case renamed(UUID, newTitle: String)
    /// A project was deleted from the metadata store. A tombstone has been
    /// recorded; clear it via `MetadataStore.clearTombstone(id:)` after the
    /// upstream deletion is confirmed.
    case deleted(UUID)
}
