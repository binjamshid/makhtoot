package net.binjamshid.makhtoot.mk.store.referral

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

enum class MkReferralRedemptionError {
    SELF_REFERRAL, ALREADY_REDEEMED, INVALID_FORMAT;
    val errorDescription: String?
        get() = throw MkNotYetPorted("mk-store.MkReferralRedemptionError.errorDescription")
}

object MkReferralRedemption {
    suspend fun redeem(enteredCode: String, myOwnCode: String, ledger: MkReferralLedger) { throw MkNotYetPorted("mk-store.MkReferralRedemption.redeem") }
}

