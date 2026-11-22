import MKFoundation
import MKSync

/// Per-project sync badge state the browser grid renders (WS-13 packet §3:
/// "MKSync (WS-11): status publisher for badges. Stub: static publisher.").
enum SyncBadgeState: Sendable {
    case none
    case syncing
    case synced
    case error
}

protocol SyncStatusProviding: Sendable {
    @MainActor func badge(for id: MKProjectID) -> SyncBadgeState
}

/// Adapts the real `MKSyncStatusPublisher` to the `SyncStatusProviding`
/// protocol consumed by the project browser badge system.
@MainActor
final class MKSyncStatusAdapter: SyncStatusProviding, @unchecked Sendable {
    private let publisher: MKSyncStatusPublisher

    init(publisher: MKSyncStatusPublisher) {
        self.publisher = publisher
    }

    func badge(for id: MKProjectID) -> SyncBadgeState {
        switch publisher.projectState(for: id.rawValue) {
        case .localOnly, .pendingUpload:
            return .none
        case .syncing:
            return .syncing
        case .synced:
            return .synced
        case .conflictCopy, .error, .needsAppUpdate:
            return .error
        }
    }
}

/// The WS-13 EARLY-SLICE stub: a static publisher that always reports
/// `.none`. Replacement owner: WS-11 `MKSync`.
struct StaticSyncStatusPublisher: SyncStatusProviding {
    func badge(for id: MKProjectID) -> SyncBadgeState { .none }
}
