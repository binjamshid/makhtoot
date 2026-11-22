package net.binjamshid.makhtoot.mk.store.referral

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted
import net.binjamshid.makhtoot.mk.store.trial.MkKeyValueStoring
import net.binjamshid.makhtoot.mk.store.trial.MkTrialManager

class MkReferralLedger(
    val store: MkKeyValueStoring? = null,
    val trialManager: MkTrialManager
) {
    fun extensionsGranted(): Int { throw MkNotYetPorted("mk-store.MkReferralLedger.extensionsGranted") }
    fun hasRedeemed(code: String): Boolean { throw MkNotYetPorted("mk-store.MkReferralLedger.hasRedeemed") }
    suspend fun recordRedemption(code: String): Boolean { throw MkNotYetPorted("mk-store.MkReferralLedger.recordRedemption") }
    companion object {
        val maxExtensions: Int = 4
        val maxExpiredRevivalWindowDays: Double = 30.0
    }
}

