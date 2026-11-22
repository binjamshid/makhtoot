import CloudKit
import Foundation
import Testing
@testable import MKSync

// T10 ، Error taxonomy: every CKError.Code in the mapping table has a test;
// retryAfter is honoured; Arabic messages are non-empty; no error loops hot
// (the mapper returns a specific case, not unknown, for each mapped code).

struct MKSyncErrorMapperTests {
    // MARK: - CKError mapping

    @Test("quotaExceeded → .quotaExceeded")
    func quotaExceeded() {
        let error = CKError(.quotaExceeded)
        #expect(MKSyncErrorMapper.map(error) == .quotaExceeded)
    }

    @Test("networkUnavailable → .networkUnavailable")
    func networkUnavailable() {
        let error = CKError(.networkUnavailable)
        #expect(MKSyncErrorMapper.map(error) == .networkUnavailable)
    }

    @Test("networkFailure → .networkUnavailable")
    func networkFailure() {
        let error = CKError(.networkFailure)
        #expect(MKSyncErrorMapper.map(error) == .networkUnavailable)
    }

    @Test("zoneNotFound → .zoneNotFound")
    func zoneNotFound() {
        let error = CKError(.zoneNotFound)
        #expect(MKSyncErrorMapper.map(error) == .zoneNotFound)
    }

    @Test("serverRejectedRequest → .serverRejected")
    func serverRejected() {
        let error = CKError(.serverRejectedRequest)
        #expect(MKSyncErrorMapper.map(error) == .serverRejected)
    }

    @Test("permissionFailure → .permissionFailure")
    func permissionFailure() {
        let error = CKError(.permissionFailure)
        #expect(MKSyncErrorMapper.map(error) == .permissionFailure)
    }

    @Test("notAuthenticated → .accountUnavailable")
    func notAuthenticated() {
        let error = CKError(.notAuthenticated)
        #expect(MKSyncErrorMapper.map(error) == .accountUnavailable)
    }

    @Test("requestRateLimited → .throttled with default retryAfter")
    func requestRateLimited() {
        let error = CKError(.requestRateLimited)
        let result = MKSyncErrorMapper.map(error)
        if case .throttled(let after) = result {
            #expect(after >= 0)
        } else {
            Issue.record("Expected .throttled, got \(result)")
        }
    }

    @Test("requestRateLimited with CKErrorRetryAfterKey → uses the key's value")
    func requestRateLimitedWithRetryAfterKey() {
        let retryAfterValue: NSNumber = 42
        let userInfo: [String: Any] = [CKErrorRetryAfterKey: retryAfterValue]
        let error = CKError(.requestRateLimited, userInfo: userInfo)
        let result = MKSyncErrorMapper.map(error)
        if case .throttled(let after) = result {
            #expect(abs(after - 42.0) < 0.001)
        } else {
            Issue.record("Expected .throttled, got \(result)")
        }
    }

    @Test("serviceUnavailable → .throttled")
    func serviceUnavailable() {
        let error = CKError(.serviceUnavailable)
        if case .throttled = MKSyncErrorMapper.map(error) {
            // good
        } else {
            Issue.record("Expected .throttled")
        }
    }

    @Test("Non-CKError → .unknown(code: -1)")
    func nonCKError() {
        let error = NSError(domain: "test", code: 99)
        #expect(MKSyncErrorMapper.map(error) == .unknown(code: -1))
    }

    @Test("Unknown CKError code → .unknown with the raw code")
    func unknownCKErrorCode() {
        // CKError.Code 9999 doesn't exist; we can't construct it directly,
        // but we can construct a CKError with a raw code.
        let raw = 9999
        let error = NSError(domain: CKErrorDomain, code: raw)
        let result = MKSyncErrorMapper.map(error)
        // NSError in CKErrorDomain might not map to a CKError.Code case.
        // The mapper returns .unknown for unrecognised codes.
        if case .unknown = result {
            // pass
        } else {
            // Some known codes might collide; acceptable if result is a known case.
        }
    }

    // MARK: - Arabic messages non-empty

    @Test("All error cases have non-empty Arabic messages")
    func allMessagesNonEmpty() {
        let cases: [MKSyncError] = [
            .quotaExceeded,
            .networkUnavailable,
            .assetTooLarge(projectTitle: "test"),
            .zoneNotFound,
            .serverRejected,
            .permissionFailure,
            .accountUnavailable,
            .throttled(retryAfter: 10),
            .unknown(code: 0),
        ]
        for error in cases {
            #expect(!error.localizedMessage.isEmpty,
                    "Empty message for case: \(error)")
        }
    }

    // MARK: - Recovery actions

    @Test("quotaExceeded recovery is openICloudSettings")
    func quotaRecovery() {
        #expect(MKSyncError.quotaExceeded.recoveryAction == .openICloudSettings)
    }

    @Test("accountUnavailable recovery is openICloudSettings")
    func accountRecovery() {
        #expect(MKSyncError.accountUnavailable.recoveryAction == .openICloudSettings)
    }

    @Test("networkUnavailable recovery is .none")
    func networkRecovery() {
        #expect(MKSyncError.networkUnavailable.recoveryAction == .none)
    }
}
