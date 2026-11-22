import Foundation

/// Persisted trial anchor (T6, ARCHITECTURE §19.2). Codable so it can be
/// serialized into both the Keychain item and the iCloud KVS mirror as raw
/// `Data` (JSON) via `MKKeyValueStoring`.
public struct MKTrialRecord: Codable, Equatable, Sendable {
    /// Trial anchor ، earliest-wins across stores/devices (D-123).
    public var firstLaunchAt: Date

    /// Wall-clock high-water mark (D-224/D-123 INV-10): the latest wall
    /// clock ever observed. `clockNow` never returns a date before this.
    public var lastObservedWallClock: Date

    /// `ProcessInfo.systemUptime` at the last observation (D-224's
    /// previously-reserved field, now wired). Used to detect a same-boot-
    /// session wall-clock rollback: if uptime has advanced more than the
    /// wall clock admits since this was recorded, the wall clock was
    /// rolled back mid-session.
    public var lastObservedBoottime: TimeInterval

    /// Referral-granted extension days (T14; 0 while the referral flag/
    /// compile condition is off). Capped at 28 (4 × 7) by the ledger, not
    /// re-validated here ، `MKTrialManager` trusts its own writes.
    public var extensionDays: Int

    /// Schema version (ARCHITECTURE §19.2: "1").
    public var recordVersion: Int

    /// Random per-record UUID ، NOT a device identifier, dedup-only
    /// diagnostic per ARCHITECTURE §19.2 ("deviceFirstSeen... NOT a device
    /// id; dedup only").
    public var deviceFirstSeen: String

    public init(
        firstLaunchAt: Date,
        lastObservedWallClock: Date,
        lastObservedBoottime: TimeInterval,
        extensionDays: Int = 0,
        recordVersion: Int = 1,
        deviceFirstSeen: String = UUID().uuidString
    ) {
        self.firstLaunchAt = firstLaunchAt
        self.lastObservedWallClock = lastObservedWallClock
        self.lastObservedBoottime = lastObservedBoottime
        self.extensionDays = extensionDays
        self.recordVersion = recordVersion
        self.deviceFirstSeen = deviceFirstSeen
    }
}

/// Derived, never stored (ARCHITECTURE §19.3: "`trialState`... derived,
/// never stored").
public enum MKTrialState: Equatable, Sendable {
    case active(daysLeft: Int)
    case expired
}

/// Where a trial extension came from (T14 ، currently only `.referral`,
/// but keeping this a named source rather than a bare `Int` bump keeps the
/// single mutation entry point self-documenting and gives tests something
/// to assert on).
public enum MKTrialExtensionSource: Sendable, Equatable {
    case referral
}
