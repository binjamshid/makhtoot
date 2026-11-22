import Foundation

/// App-side 7-day trial (D-123), clock guard hardened per D-224 (T6). An
/// `actor`: every read-merge-write cycle against the two backing stores is
/// serialized, so concurrent `resolve()`/`extend(_:)` calls (foreground +
/// KVS-change-notification firing close together, say) can't race each
/// other's writes.
public actor MKTrialManager {
    public static let trialDays = 7
    /// D-124 abuse cap: 4 × 7-day referral extensions.
    public static let maxExtensionDays = 28

    private let local: any MKKeyValueStoring
    private let cloud: any MKKeyValueStoring
    private let clock: any MKClockProviding
    private let rollbackTolerance: TimeInterval

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public init(
        local: any MKKeyValueStoring = MKKeychainStore(service: MKSecureStoreKeys.trialKeychainService),
        cloud: any MKKeyValueStoring = MKUbiquitousStore(),
        clock: any MKClockProviding = MKSystemClock(),
        rollbackTolerance: TimeInterval = 6 * 3600
    ) {
        self.local = local
        self.cloud = cloud
        self.clock = clock
        self.rollbackTolerance = rollbackTolerance
    }

    private func readRecord(_ store: any MKKeyValueStoring, key: String) -> MKTrialRecord? {
        guard let data = store.read(key) else { return nil }
        return try? decoder.decode(MKTrialRecord.self, from: data)
    }

    private func writeRecord(_ record: MKTrialRecord, to store: any MKKeyValueStoring, key: String) {
        guard let data = try? encoder.encode(record) else { return }
        store.write(key, value: data)
    }

    /// Merge rule (T6, ARCHITECTURE §19.2): earliest `firstLaunchAt` wins
    /// (earliest-wins across devices/stores); latest observed
    /// wall-clock/boottime wins (high-water mark); highest `extensionDays`
    /// wins, capped. Neither store populated ⇒ genuine first launch: seed
    /// both with `now`.
    private func mergedRecord() -> MKTrialRecord {
        let wall = clock.now()
        let uptime = clock.systemUptime()
        let a = readRecord(local, key: MKSecureStoreKeys.trialRecordKey)
        let b = readRecord(cloud, key: MKSecureStoreKeys.trialKVSKey)
        switch (a, b) {
        case (nil, nil):
            return MKTrialRecord(firstLaunchAt: wall, lastObservedWallClock: wall, lastObservedBoottime: uptime)
        case (let x?, nil):
            return x
        case (nil, let y?):
            return y
        case (let x?, let y?):
            return MKTrialRecord(
                firstLaunchAt: min(x.firstLaunchAt, y.firstLaunchAt),
                lastObservedWallClock: max(x.lastObservedWallClock, y.lastObservedWallClock),
                lastObservedBoottime: max(x.lastObservedBoottime, y.lastObservedBoottime),
                extensionDays: min(Self.maxExtensionDays, max(x.extensionDays, y.extensionDays)),
                recordVersion: max(x.recordVersion, y.recordVersion),
                deviceFirstSeen: x.deviceFirstSeen
            )
        }
    }

    /// D-224 wall-clock high-water-mark + uptime-cross-check guard,
    /// verbatim algorithm from ARCHITECTURE §19.2's `clockNow(_:)`:
    ///
    /// 1. If uptime has advanced further than the wall clock admits since
    ///    the last observation (beyond `rollbackTolerance`), AND that
    ///    uptime delta is non-negative (same boot session ، a reboot would
    ///    make it negative), the wall clock was rolled back **mid-session**.
    ///    Uptime-elapsed is authoritative: advance the high-water mark by
    ///    the unforgeable same-session uptime delta instead.
    /// 2. Otherwise, if the raw wall clock is still behind the high-water
    ///    mark (rollback with no same-session uptime evidence ، e.g. a
    ///    reboot preceded the rollback), freeze at the high-water mark.
    ///    This is the documented residual (D-224/D-211): a reboot-then-
    ///    rollback sequence within a single prior session is caught by (1)
    ///    only if observed before the reboot; a rollback that happens
    ///    entirely *before* the very first observation of a new boot has
    ///    no same-session uptime evidence to catch it, so it falls through
    ///    to this freeze branch, which still never *advances* the trial ،
    ///    the residual is "doesn't age the trial further", never "grants
    ///    extra time".
    /// 3. Otherwise, the wall clock is trustworthy (advanced normally):
    ///    use it as-is.
    private func clockNow(_ record: MKTrialRecord) -> Date {
        let wall = clock.now()
        let uptime = clock.systemUptime()
        let uptimeDelta = uptime - record.lastObservedBoottime
        let wallDelta = wall.timeIntervalSince(record.lastObservedWallClock)
        if uptimeDelta >= 0, uptimeDelta > wallDelta + rollbackTolerance {
            return record.lastObservedWallClock.addingTimeInterval(uptimeDelta)
        }
        if wall < record.lastObservedWallClock {
            return record.lastObservedWallClock
        }
        return wall
    }

    /// Day-boundary policy (T6 AC: "document choice"): calendar days in
    /// UTC, not raw 24h buckets from the exact `firstLaunchAt` timestamp.
    /// A trial that starts at 23:50 UTC "uses up" its first day at the very
    /// next UTC midnight, 10 minutes later ، chosen for determinism (no
    /// dependency on the device's local time zone, which can itself be
    /// changed by the user) over maximal per-user fairness.
    private func daysElapsed(from start: Date, to now: Date) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .init(secondsFromGMT: 0)!
        let startDay = utc.startOfDay(for: start)
        let nowDay = utc.startOfDay(for: now)
        let components = utc.dateComponents([.day], from: startDay, to: nowDay)
        return max(0, components.day ?? 0)
    }

    private func state(for record: MKTrialRecord, effectiveNow: Date) -> MKTrialState {
        let elapsedDays = daysElapsed(from: record.firstLaunchAt, to: effectiveNow)
        let totalDays = Self.trialDays + record.extensionDays
        let daysLeft = totalDays - elapsedDays
        return daysLeft > 0 ? .active(daysLeft: daysLeft) : .expired
    }

    /// Main entry point (ARCHITECTURE §19.3: "evaluated on: launch,
    /// foreground, KVS change, midnight local-time crossing"). Merges both
    /// stores, applies the D-224 guard, persists the observed high-water
    /// mark back to BOTH stores, returns the resolved state.
    @discardableResult
    public func resolve() async -> MKTrialState {
        var record = mergedRecord()
        let effectiveNow = clockNow(record)
        record.lastObservedWallClock = max(record.lastObservedWallClock, effectiveNow)
        record.lastObservedBoottime = clock.systemUptime()
        writeRecord(record, to: local, key: MKSecureStoreKeys.trialRecordKey)
        writeRecord(record, to: cloud, key: MKSecureStoreKeys.trialKVSKey)
        return state(for: record, effectiveNow: effectiveNow)
    }

    /// Read-only peek: resolves without persisting an observation. Used by
    /// previews/diagnostics that shouldn't perturb the high-water mark.
    public func peek() -> MKTrialState {
        let record = mergedRecord()
        let effectiveNow = clockNow(record)
        return state(for: record, effectiveNow: effectiveNow)
    }

    /// T14 ، the ONLY mutator of `extensionDays` anywhere in the module
    /// (packet T14: "`TrialManager.extend(by: 7, source: .referral)` ، the
    /// ONLY caller, itself only reachable inside the `#if`"). Returns
    /// `false` (no-op, not an error) once the cap is reached ، callers
    /// (referral redemption UI) surface that as "no more invitations
    /// count" rather than throwing.
    @discardableResult
    public func extend(by days: Int, source: MKTrialExtensionSource) async -> Bool {
        var record = mergedRecord()
        guard record.extensionDays < Self.maxExtensionDays else { return false }
        record.extensionDays = min(Self.maxExtensionDays, record.extensionDays + days)
        writeRecord(record, to: local, key: MKSecureStoreKeys.trialRecordKey)
        writeRecord(record, to: cloud, key: MKSecureStoreKeys.trialKVSKey)
        return true
    }

    /// Diagnostic accessor (Settings/debug UI, previews) ، the raw merged
    /// record without mutating anything.
    public func currentRecord() -> MKTrialRecord {
        mergedRecord()
    }
}
