import CloudKit
import Foundation
import Testing
@testable import MKSync

// T9 ، Account state machine: CKAccountStatus mapping, allowsSync flag,
// pause reason, account-switch detection.

struct MKSyncAccountStateTests {
    // MARK: - CKAccountStatus mapping

    @Test("CKAccountStatus.available → .available")
    func available() {
        #expect(MKSyncAccountState.from(.available) == .available)
    }

    @Test("CKAccountStatus.noAccount → .noAccount")
    func noAccount() {
        #expect(MKSyncAccountState.from(.noAccount) == .noAccount)
    }

    @Test("CKAccountStatus.restricted → .restricted")
    func restricted() {
        #expect(MKSyncAccountState.from(.restricted) == .restricted)
    }

    @Test("CKAccountStatus.temporarilyUnavailable → .temporarilyUnavailable")
    func temporarilyUnavailable() {
        #expect(MKSyncAccountState.from(.temporarilyUnavailable) == .temporarilyUnavailable)
    }

    // MARK: - allowsSync

    @Test("Only .available allows sync")
    func allowsSync() {
        #expect(MKSyncAccountState.available.allowsSync == true)
        #expect(MKSyncAccountState.noAccount.allowsSync == false)
        #expect(MKSyncAccountState.restricted.allowsSync == false)
        #expect(MKSyncAccountState.temporarilyUnavailable.allowsSync == false)
        #expect(MKSyncAccountState.unknown.allowsSync == false)
    }

    // MARK: - Pause reasons

    @Test("noAccount pause reason is .noAccount")
    func noAccountReason() {
        #expect(MKSyncAccountState.noAccount.pauseReason == .noAccount)
    }

    @Test("restricted pause reason is .restricted")
    func restrictedReason() {
        #expect(MKSyncAccountState.restricted.pauseReason == .restricted)
    }

    @Test("temporarilyUnavailable pause reason is .temporarilyUnavailable")
    func temporarilyUnavailableReason() {
        #expect(MKSyncAccountState.temporarilyUnavailable.pauseReason == .temporarilyUnavailable)
    }

    @Test("available has no pause reason")
    func availableNoPauseReason() {
        #expect(MKSyncAccountState.available.pauseReason == nil)
    }

    @Test("unknown has no pause reason")
    func unknownNoPauseReason() {
        #expect(MKSyncAccountState.unknown.pauseReason == nil)
    }

    // MARK: - Account-switch detection (T9)

    @Test("Same identity → no switch")
    func sameIdentityNoSwitch() {
        let a = MKSyncAccountIdentity(userRecordName: "alice")
        let b = MKSyncAccountIdentity(userRecordName: "alice")
        #expect(a.accountChanged(from: b) == false)
    }

    @Test("Different identity → switch detected")
    func differentIdentitySwitch() {
        let a = MKSyncAccountIdentity(userRecordName: "alice")
        let b = MKSyncAccountIdentity(userRecordName: "bob")
        #expect(a.accountChanged(from: b) == true)
    }

    @Test("No previous identity → not a switch (first run)")
    func noPreviousIdentityNotASwitch() {
        let a = MKSyncAccountIdentity(userRecordName: "alice")
        #expect(a.accountChanged(from: nil) == false)
    }

    // MARK: - Arabic UI messages non-empty

    @Test("All account reasons have non-empty messages")
    func accountReasonMessages() {
        let reasons: [MKSyncAccountReason] = [.noAccount, .restricted, .temporarilyUnavailable]
        for reason in reasons {
            #expect(!reason.localizedMessage.isEmpty,
                    "Empty message for \(reason)")
        }
    }

    @Test("Global pausedAccount state messages are non-empty")
    func globalPausedMessages() {
        for reason in [MKSyncAccountReason.noAccount, .restricted, .temporarilyUnavailable] {
            let state = MKSyncGlobalState.pausedAccount(reason: reason)
            #expect(!state.localizedMessage.isEmpty)
        }
    }
}
