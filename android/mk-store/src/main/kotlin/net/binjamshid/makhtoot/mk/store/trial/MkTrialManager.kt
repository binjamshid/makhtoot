package net.binjamshid.makhtoot.mk.store.trial

import net.binjamshid.makhtoot.mk.foundation.MkNotYetPorted

class MkTrialManager(
    val local: MkKeyValueStoring? = null,
    val cloud: MkKeyValueStoring = MkUbiquitousStore(),
    val clock: MkClockProviding = MkSystemClock(),
    val rollbackTolerance: Double = 21600.0
) {
    suspend fun resolve(): MkTrialState { throw MkNotYetPorted("mk-store.MkTrialManager.resolve") }
    fun peek(): MkTrialState { throw MkNotYetPorted("mk-store.MkTrialManager.peek") }
    suspend fun extend(days: Int, source: MkTrialExtensionSource): Boolean { throw MkNotYetPorted("mk-store.MkTrialManager.extend") }
    fun currentRecord(): MkTrialRecord { throw MkNotYetPorted("mk-store.MkTrialManager.currentRecord") }
    companion object {
        val trialDays: Int = 7
        val maxExtensionDays: Int = 28
    }
}

