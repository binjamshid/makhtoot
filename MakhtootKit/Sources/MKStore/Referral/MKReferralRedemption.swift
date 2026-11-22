#if MAKHTOOT_REFERRAL_ENABLED
import Foundation

/// Arabic-localized errors for manual code entry (T14 anti-abuse).
public enum MKReferralRedemptionError: Error, LocalizedError, Sendable, Equatable {
    case selfReferral
    case alreadyRedeemed
    case invalidFormat

    public var errorDescription: String? {
        switch self {
        case .selfReferral: return "لا يمكنك استخدام رمز الدعوة الخاص بك."
        case .alreadyRedeemed: return "تم استخدام هذا الرمز من قبل."
        case .invalidFormat: return "رمز الدعوة غير صالح."
        }
    }
}

/// Invitee-side manual code entry (T14). Honor-based local attribution ،
/// documented weakness: with no server, this cannot verify the invitee
/// took any real qualifying action. The qualifying event recorded here
/// (`codeEntered`) is a v1-design placeholder for a real qualifying action
/// (a future server-backed design would gate the referrer's reward on
/// something harder to fake, e.g. a confirmed purchase ، see
/// `REVIEW_RISK_MEMO.md`'s attribution-design section).
public enum MKReferralRedemption {
    /// Validates + records `enteredCode` against `ledger`. Self-referral
    /// (entering your own code) and duplicate redemption are rejected;
    /// everything else routes through `MKReferralLedger.recordRedemption`,
    /// which is the only path that can call `TrialManager.extend(by:source:)`
    /// (T14: "the ONLY caller").
    public static func redeem(
        enteredCode: String,
        myOwnCode: String,
        ledger: MKReferralLedger
    ) async throws {
        let normalized = enteredCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard normalized.hasPrefix("MK-"), normalized.count == 11 else {
            throw MKReferralRedemptionError.invalidFormat
        }
        guard normalized != myOwnCode.uppercased() else {
            throw MKReferralRedemptionError.selfReferral
        }
        let isNew = await ledger.recordRedemption(code: normalized)
        guard isNew else {
            throw MKReferralRedemptionError.alreadyRedeemed
        }
    }
}
#endif
