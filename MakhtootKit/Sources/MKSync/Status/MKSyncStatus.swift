import Foundation
import MKFoundation

// T11 ، Sync status UI contract.
// These types are the ONLY surface WS-12 (settings) and WS-13 (project
// browser badges) consume from MKSync. No rendering logic lives here;
// strings are in Arabic ready for RTL layout.

/// Global sync-engine state. Published by `MKSyncEngineController` via
/// `MKSyncStatusPublisher.globalStateStream`.
public enum MKSyncGlobalState: Sendable, Equatable {
    /// Sync is disabled by the user toggle.
    case disabled
    /// Entitlement lapsed (free/expired). Engine is stopped but no data
    /// is deleted. UI string: see `localizedMessage`.
    case pausedEntitlement
    /// iCloud account unavailable. Reason identifies the specific issue.
    case pausedAccount(reason: MKSyncAccountReason)
    /// Engine is running but idle. `lastSyncDate` is nil until the first
    /// successful sync completes.
    case idle(lastSyncDate: Date?)
    /// Actively uploading/downloading. `uploaded` and `total` are
    /// record-count based (no fake percentages).
    case syncing(uploaded: Int, total: Int)
    /// Engine stopped due to a persistent error.
    case error(MKSyncError)

    /// Arabic string for display in the Settings sync row.
    public var localizedMessage: String {
        switch self {
        case .disabled:
            return "المزامنة معطّلة"
        case .pausedEntitlement:
            return "المزامنة عبر iCloud ميزة مميزة ، اشترك لاستئنافها"
        case .pausedAccount(let reason):
            return reason.localizedMessage
        case .idle(let date):
            if let date {
                let formatter = RelativeDateTimeFormatter()
                formatter.locale = Locale(identifier: "ar")
                return "آخر مزامنة: \(formatter.localizedString(for: date, relativeTo: Date()))"
            }
            return "المزامنة مفعّلة"
        case .syncing(let uploaded, let total):
            // N8-1: Arabic-Indic digits per the app-wide convention (the
            // `.idle` case above already formats via the `ar` locale);
            // N8-2: the counter fragment is FSI/PDI-isolated so its weak
            // digit-slash-digit run resolves independently of the
            // surrounding Arabic sentence.
            let counter = MKRTLUtilities.isolated(
                MKRTLUtilities.toArabicIndicDigits("\(uploaded)/\(total)")
            )
            return "جارٍ المزامنة (\(counter))"
        case .error(let error):
            return error.localizedMessage
        }
    }
}

/// Reason the engine is paused due to account state.
public enum MKSyncAccountReason: Sendable, Equatable {
    case noAccount
    case restricted
    case temporarilyUnavailable

    public var localizedMessage: String {
        switch self {
        case .noAccount:
            return "سجّل الدخول إلى iCloud من الإعدادات لتفعيل المزامنة"
        case .restricted:
            return "المزامنة عبر iCloud مقيّدة على هذا الجهاز"
        case .temporarilyUnavailable:
            return "iCloud غير متاح مؤقتًا ، ستُستأنف المزامنة تلقائيًا"
        }
    }
}

/// Per-project sync state. Published per-project from
/// `MKSyncStatusPublisher.projectState(for:)`.
public enum MKSyncProjectState: Sendable, Equatable {
    /// Project exists only on this device; not yet uploaded.
    case localOnly
    /// Upload is queued (debounce window or engine paused).
    case pendingUpload
    /// Currently uploading or downloading this project's records.
    case syncing
    /// Synced with the server; hashes agree.
    case synced
    /// A conflict copy was created from this project during a divergence
    /// resolution. The original received the remote version.
    case conflictCopy
    /// Per-project sync error.
    case error(MKSyncError)
    /// A remote version of this project requires a newer app version.
    /// Prevents overwriting the server record with older-schema data.
    case needsAppUpdate

    /// Arabic badge label for the project browser (WS-13).
    public var badgeLabel: String? {
        switch self {
        case .localOnly: return nil
        case .pendingUpload: return "في الانتظار"
        case .syncing: return "جارٍ المزامنة"
        case .synced: return nil
        case .conflictCopy: return "نسخة متعارضة"
        case .error: return "خطأ في المزامنة"
        case .needsAppUpdate: return "يتطلب تحديث التطبيق"
        }
    }
}

// MARK: - Status publisher contract

/// Observable sync-status model consumed by WS-12 and WS-13 views.
/// All published values are on the main actor to simplify SwiftUI binding.
///
/// `@unchecked Sendable`: all mutable state is @MainActor-guarded;
/// `@Observable`'s registrar is internally thread-safe. The controller
/// crosses into @MainActor when calling update methods.
@MainActor
@Observable
public final class MKSyncStatusPublisher: @unchecked Sendable {
    /// Current global engine state.
    public private(set) var globalState: MKSyncGlobalState = .disabled

    /// Per-project state dictionary. Keyed by project UUID.
    /// Absent entry means the project state is unknown / not yet tracked.
    public private(set) var projectStates: [UUID: MKSyncProjectState] = [:]

    /// Most-recently-created conflict copy IDs since last status reset.
    public private(set) var recentConflictCopies: [(original: UUID, copy: UUID)] = []

    public init() {}

    // MARK: - Internal mutation API (called by MKSyncEngineController)

    public func update(globalState: MKSyncGlobalState) {
        self.globalState = globalState
    }

    public func update(projectID: UUID, state: MKSyncProjectState) {
        projectStates[projectID] = state
    }

    public func recordConflictCopy(original: UUID, copy: UUID) {
        recentConflictCopies.append((original: original, copy: copy))
        projectStates[copy] = .conflictCopy
    }

    /// Convenience: returns the state for a specific project, defaulting to
    /// `.localOnly` if the project has never been tracked.
    public func projectState(for id: UUID) -> MKSyncProjectState {
        projectStates[id] ?? .localOnly
    }
}
