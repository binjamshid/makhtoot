import CloudKit
import Foundation

// T9 ، Account state handling.
// Pure value-type state machine so tests don't need a live CKContainer.

/// The account states the sync engine can be in with respect to the
/// user's iCloud account.
public enum MKSyncAccountState: Sendable, Equatable {
    /// A valid iCloud account is available and sync may run.
    case available
    /// No iCloud account configured on this device.
    case noAccount
    /// iCloud access is restricted (parental controls, MDM, etc.).
    case restricted
    /// Account exists but is temporarily unavailable (network, server).
    case temporarilyUnavailable
    /// Initial state before the first status check completes.
    case unknown

    /// Whether this state permits the sync engine to run.
    public var allowsSync: Bool { self == .available }

    /// Maps to the corresponding UI pause reason, or `nil` when sync is allowed.
    public var pauseReason: MKSyncAccountReason? {
        switch self {
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .temporarilyUnavailable: return .temporarilyUnavailable
        case .available, .unknown: return nil
        }
    }

    // MARK: - CKAccountStatus mapping

    /// Derives an `MKSyncAccountState` from a CloudKit `CKAccountStatus`.
    public static func from(_ ckStatus: CKAccountStatus) -> MKSyncAccountState {
        switch ckStatus {
        case .available:              return .available
        case .noAccount:              return .noAccount
        case .restricted:             return .restricted
        case .temporarilyUnavailable: return .temporarilyUnavailable
        case .couldNotDetermine:      return .unknown
        @unknown default:             return .unknown
        }
    }
}

// MARK: - Account-switch detection

/// Tracks the most-recently-seen CloudKit user record ID so the engine
/// can detect when the signed-in account changes between launches.
///
/// Account switches require a full state reset (T9): local projects remain
/// (they belong to the device owner, not a CloudKit identity), but the sync
/// state serialization and per-project lastSyncedHash values are cleared to
/// prevent cross-account bleed.
public struct MKSyncAccountIdentity: Sendable, Equatable {
    /// A stable identifier for the currently-signed-in iCloud account,
    /// derived from `CKContainer.fetchUserRecordID()`. Stored in
    /// Application Support between launches.
    public let userRecordName: String

    public init(userRecordName: String) {
        self.userRecordName = userRecordName
    }

    /// Returns `true` if `other` is a DIFFERENT account, requiring a sync
    /// state reset.
    public func accountChanged(from other: MKSyncAccountIdentity?) -> Bool {
        guard let other else { return false } // first run, not a switch
        return self.userRecordName != other.userRecordName
    }
}
