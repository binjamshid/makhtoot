#if MAKHTOOT_REFERRAL_ENABLED
import Foundation
import Testing
@testable import MKStore

/// T14 AC: "a Debug/internal build with `MAKHTOOT_REFERRAL_ENABLED` set
/// enforces cap + self-referral + duplicate rules." Run via:
/// `swift test -Xswiftc -DMAKHTOOT_REFERRAL_ENABLED`.
@Suite("Referral module ، T14 (flag ON)")
struct ReferralTests {
    private func makeLedger(clock: MKFakeClock = MKFakeClock()) -> (MKTrialManager, MKReferralLedger) {
        let trialManager = MKTrialManager(local: MKInMemoryKeyValueStore(), cloud: MKInMemoryKeyValueStore(), clock: clock)
        let ledger = MKReferralLedger(store: MKInMemoryKeyValueStore(), trialManager: trialManager)
        return (trialManager, ledger)
    }

    @Test func codeGenerationIsDeterministicAndPrefixed() {
        let code1 = MKReferralCodeGenerator.code(installUUID: "abc-123", salt: "salt")
        let code2 = MKReferralCodeGenerator.code(installUUID: "abc-123", salt: "salt")
        #expect(code1 == code2)
        #expect(code1.hasPrefix("MK-"))
        #expect(code1.count == 11) // "MK-" + 8 chars
    }

    @Test func selfReferralRejected() async {
        let (_, ledger) = makeLedger()
        let myCode = MKReferralCodeGenerator.code(installUUID: "me", salt: "s")
        await #expect(throws: MKReferralRedemptionError.selfReferral) {
            try await MKReferralRedemption.redeem(enteredCode: myCode, myOwnCode: myCode, ledger: ledger)
        }
    }

    @Test func duplicateRedemptionRejected() async throws {
        let (_, ledger) = makeLedger()
        let myCode = "MK-AAAAAAAA"
        let friendCode = "MK-BBBBBBBB"
        try await MKReferralRedemption.redeem(enteredCode: friendCode, myOwnCode: myCode, ledger: ledger)
        await #expect(throws: MKReferralRedemptionError.alreadyRedeemed) {
            try await MKReferralRedemption.redeem(enteredCode: friendCode, myOwnCode: myCode, ledger: ledger)
        }
    }

    @Test func invalidFormatRejected() async {
        let (_, ledger) = makeLedger()
        await #expect(throws: MKReferralRedemptionError.invalidFormat) {
            try await MKReferralRedemption.redeem(enteredCode: "not-a-code", myOwnCode: "MK-AAAAAAAA", ledger: ledger)
        }
    }

    @Test func redemptionGrantsSevenDayExtension() async throws {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 0)
        let (trialManager, ledger) = makeLedger(clock: clock)
        _ = await trialManager.resolve() // active(7)
        try await MKReferralRedemption.redeem(enteredCode: "MK-CCCCCCCC", myOwnCode: "MK-AAAAAAAA", ledger: ledger)
        let state = await trialManager.resolve()
        #expect(state == .active(daysLeft: 14))
    }

    @Test func capEnforcedAtFourExtensions() async throws {
        let clock = MKFakeClock(now: Date(timeIntervalSince1970: 1_700_000_000), uptime: 0)
        let (trialManager, ledger) = makeLedger(clock: clock)
        _ = await trialManager.resolve()
        let codes = ["MK-11111111", "MK-22222222", "MK-33333333", "MK-44444444", "MK-55555555"]
        for code in codes {
            try await MKReferralRedemption.redeem(enteredCode: code, myOwnCode: "MK-AAAAAAAA", ledger: ledger)
        }
        #expect(await ledger.extensionsGranted() == MKReferralLedger.maxExtensions)
        let state = await trialManager.resolve()
        #expect(state == .active(daysLeft: 7 + 28)) // capped at 28 additional days
    }
}
#endif
