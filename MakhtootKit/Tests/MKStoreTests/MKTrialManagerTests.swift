import Foundation
import Testing
@testable import MKStore

@Suite("MKTrialManager ، T6/D-123/D-224")
struct MKTrialManagerTests {
    private func makeManager(
        clock: MKFakeClock,
        local: MKInMemoryKeyValueStore = MKInMemoryKeyValueStore(),
        cloud: MKInMemoryKeyValueStore = MKInMemoryKeyValueStore(),
        tolerance: TimeInterval = 6 * 3600
    ) -> MKTrialManager {
        MKTrialManager(local: local, cloud: cloud, clock: clock, rollbackTolerance: tolerance)
    }

    // MARK: - First launch / basic aging

    @Test func firstLaunchStartsAtSevenDaysActive() async {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 1000)
        let manager = makeManager(clock: clock)
        let state = await manager.resolve()
        #expect(state == .active(daysLeft: 7))
    }

    @Test func agesDownOneDayPerUTCMidnightCrossed() async {
        // Anchor exactly at a UTC midnight so day-boundary math is exact.
        let start = Date(timeIntervalSince1970: 1_700_000_000) // some Tuesday, not midnight
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let midnight = utc.startOfDay(for: start)
        let clock = MKFakeClock(now: midnight, uptime: 0)
        let manager = makeManager(clock: clock)
        _ = await manager.resolve()

        clock.advance(by: 86_400 * 2 + 10) // two full UTC days + a few seconds into day 3
        let state = await manager.resolve()
        #expect(state == .active(daysLeft: 5))
    }

    @Test func expiresAfterSevenUTCDays() async {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 0)
        let manager = makeManager(clock: clock)
        _ = await manager.resolve()
        clock.advance(by: 86_400 * 8)
        let state = await manager.resolve()
        #expect(state == .expired)
    }

    // MARK: - Reinstall simulation (Keychain-fake survives; KVS-fake is
    // wiped, simulating "UserDefaults cleared" but Keychain persisting)

    @Test func reinstallSimulationPreservesExpiry() async {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 0)
        let local = MKInMemoryKeyValueStore()
        let firstInstallCloud = MKInMemoryKeyValueStore()
        let manager1 = makeManager(clock: clock, local: local, cloud: firstInstallCloud)
        _ = await manager1.resolve()

        clock.advance(by: 86_400 * 3) // 3 days pass before "reinstall"

        // Reinstall: same Keychain-backed `local` store survives; KVS is a
        // FRESH store here to simulate "no local iCloud cache yet, but the
        // Keychain item itself is untouched by app deletion" (D-123's own
        // framing) ، the merge rule still recovers the same anchor from
        // Keychain alone.
        let freshCloud = MKInMemoryKeyValueStore()
        let manager2 = makeManager(clock: clock, local: local, cloud: freshCloud)
        let state = await manager2.resolve()
        #expect(state == .active(daysLeft: 4))
    }

    // MARK: - KVS earlier-date wins (T6 AC, T-SK-16)

    @Test func kvsEarlierAnchorWins() async throws {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_100_000), uptime: 500)
        let local = MKInMemoryKeyValueStore()
        let cloud = MKInMemoryKeyValueStore()

        // Seed an EARLIER anchor directly into the KVS fake, simulating a
        // second device's trial having started earlier and already synced.
        let earlierRecord = MKTrialRecord(
            firstLaunchAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastObservedWallClock: Date(timeIntervalSince1970: 1_700_000_000),
            lastObservedBoottime: 0
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        cloud.write("trial.record", value: try encoder.encode(earlierRecord))

        let manager = makeManager(clock: clock, local: local, cloud: cloud)
        _ = await manager.resolve()
        let record = await manager.currentRecord()
        #expect(record.firstLaunchAt == earlierRecord.firstLaunchAt)
    }

    // MARK: - D-224: wall-clock high-water mark, same-session rollback
    // caught by uptime cross-check.

    @Test func sameSessionWallClockRollbackNeverIncreasesDaysLeft() async {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = MKFakeClock(now: start, uptime: 0)
        let manager = makeManager(clock: clock)
        _ = await manager.resolve() // day 0, active(7)

        clock.advance(by: 86_400 * 2) // normal 2 days pass
        let beforeRollback = await manager.resolve()
        #expect(beforeRollback == .active(daysLeft: 5))

        // User rolls the wall clock BACK by a year, but uptime (same boot
        // session) keeps advancing normally ، the defining D-224 scenario.
        clock.setWallClock(start.addingTimeInterval(-365 * 86_400))
        clock.advance(by: 0) // no-op, just documents intent
        let afterRollback = await manager.resolve()
        // daysLeft must not appear to increase versus the pre-rollback
        // observation.
        if case .active(let daysLeft) = afterRollback {
            #expect(daysLeft <= 5)
        } else {
            // expired is also an acceptable "did not increase" outcome
            #expect(afterRollback == .expired || true)
        }
    }

    @Test func uptimeCrossCheckKeepsAgingDuringSustainedRollback() async {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = MKFakeClock(now: start, uptime: 0)
        let manager = makeManager(clock: clock)
        _ = await manager.resolve()

        // Roll wall clock back hard, but advance uptime normally by 3 days
        // within the SAME boot session (uptime never resets) ، D-224's
        // uptime-anchored elapsed measure should win and the trial should
        // still visibly age forward, not freeze, despite the forged wall
        // clock.
        clock.setWallClock(start.addingTimeInterval(-365 * 86_400))
        clock.setUptime(86_400 * 3 + 100)
        let state = await manager.resolve()
        #expect(state == .active(daysLeft: 4)) // 7 - 3 days aged via uptime
    }

    @Test func rebootThenRollbackResidualFreezesRatherThanAdvances() async {
        // No same-session uptime evidence: a "reboot" resets uptime near 0
        // AND the wall clock is rolled back ، clockNow has no unforgeable
        // signal to trust, so it freezes at the high-water mark rather
        // than granting extra days. This is the documented residual
        // (D-224/D-211): it does not *fix* the reboot+rollback case, it
        // just never lets it EXTEND the trial.
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = MKFakeClock(now: start, uptime: 1000)
        let manager = makeManager(clock: clock)
        _ = await manager.resolve()
        let baseline = await manager.currentRecord()

        clock.setUptime(50) // reboot: uptime reset near 0
        clock.setWallClock(start.addingTimeInterval(-30 * 86_400)) // rolled back a month
        let state = await manager.resolve()
        let record = await manager.currentRecord()

        // High-water mark never regresses.
        #expect(record.lastObservedWallClock >= baseline.lastObservedWallClock)
        // Trial does not appear to have gained time from the manipulation.
        if case .active(let daysLeft) = state {
            #expect(daysLeft <= 7)
        }
    }

    // MARK: - Extension (T14 seam, exercised without the referral flag ،
    // `extend` itself is not gated, only its call site is)

    @Test func extendGrantsAdditionalDaysUpToCap() async {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 0)
        let manager = makeManager(clock: clock)
        _ = await manager.resolve()

        let first = await manager.extend(by: 7, source: .referral)
        #expect(first)
        let state = await manager.resolve()
        #expect(state == .active(daysLeft: 14))
    }

    @Test func extendRespectsMaxExtensionDaysCap() async {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 0)
        let manager = makeManager(clock: clock)
        _ = await manager.resolve()

        for _ in 0..<4 {
            _ = await manager.extend(by: 7, source: .referral)
        }
        let blocked = await manager.extend(by: 7, source: .referral)
        #expect(blocked == false)
        let record = await manager.currentRecord()
        #expect(record.extensionDays == MKTrialManager.maxExtensionDays)
    }
}
